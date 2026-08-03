import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/onboarding_bootstrap.dart';
import '../models/onboarding_option.dart';
import '../models/paged_lookup_response.dart';
import '../widgets/onboarding_picker_field.dart';
import 'onboarding_step_helpers.dart';
import 'onboarding_step_scaffold.dart';
import '../../../core/app_language.dart';
import '../../../core/horoscope/horoscope_rules.dart';

class AstroStep extends StatefulWidget {
  const AstroStep({
    super.key,
    required this.data,
    required this.bootstrap,
    required this.locale,
    required this.loading,
    required this.onSave,
    required this.onBack,
  });

  final Map<String, dynamic> data;
  final OnboardingBootstrap bootstrap;
  final String locale;
  final bool loading;
  final OnboardingStepSaver onSave;
  final VoidCallback onBack;

  @override
  State<AstroStep> createState() => _AstroStepState();
}

class _AstroStepState extends State<AstroStep> {
  OnboardingOption? _mangalDosh;
  OnboardingOption? _nakshatra;
  OnboardingOption? _rashi;
  int? _charan;

  // Derived from the nakshatra and sent with the step payload, but never
  // rendered — only Edit Profile exposes gan/nadi/yoni pickers.
  int? _ganId;
  int? _nadiId;
  int? _yoniId;

  // Derived from the rashi, same source of truth Edit Profile uses. Also never
  // rendered here — onboarding shows nakshatra / rashi / charan / mangal dosh.
  int? _varnaId;
  int? _vashyaId;
  int? _rashiLordId;

  HoroscopeRules get _rules => HoroscopeRules(widget.bootstrap.horoscopeRules);

  RashiAshtakootaRules get _ashtakoota =>
      RashiAshtakootaRules(widget.bootstrap.rashiAshtakoota);

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  @override
  void didUpdateWidget(covariant AstroStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!mapEquals(oldWidget.data, widget.data) ||
        oldWidget.bootstrap != widget.bootstrap) {
      _prefill();
    }
  }

  void _prefill() {
    _mangalDosh =
        optionFromData(widget.data['mangal_dosh_type_option']) ??
        optionById(
          widget.bootstrap.mangalDoshTypes,
          widget.data['mangal_dosh_type_id'],
        );
    _nakshatra =
        optionFromData(widget.data['nakshatra_option']) ??
        optionById(widget.bootstrap.nakshatras, widget.data['nakshatra_id']);
    _rashi =
        optionFromData(widget.data['rashi_option']) ??
        optionById(widget.bootstrap.rashis, widget.data['rashi_id']);
    _charan = onboardingInt(widget.data['charan']);
    _ganId = onboardingInt(widget.data['gan_id']);
    _nadiId = onboardingInt(widget.data['nadi_id']);
    _yoniId = onboardingInt(widget.data['yoni_id']);
    _reconcile();
  }

  /// Repairs every dependent astro selection through the shared rule engine —
  /// the exact same reconciliation Edit Profile runs.
  /// Which corner the last reconciliation filled in by itself.
  ///
  /// Only meaningful right after [_reconcile]; the note above the box reads
  /// them so a value the member never typed never appears unexplained.
  bool _nakshatraWasDerived = false;
  bool _rashiWasDerived = false;
  bool _charanWasDerived = false;

  void _reconcile() {
    final beforeNakshatra = _nakshatra?.intId;
    final beforeRashi = _rashi?.intId;
    final beforeCharan = _charan;

    final result = _rules.reconcile(
      HoroscopeSelection(
        nakshatraId: _nakshatra?.intId,
        rashiId: _rashi?.intId,
        charan: _charan,
        ganId: _ganId,
        nadiId: _nadiId,
        yoniId: _yoniId,
      ),
    );

    if (result.nakshatraId != _nakshatra?.intId) {
      _nakshatra = result.nakshatraId == null
          ? null
          : optionById(widget.bootstrap.nakshatras, result.nakshatraId) ??
                _nakshatra;
    }
    if (result.rashiId != _rashi?.intId) {
      _rashi = result.rashiId == null
          ? null
          : optionById(widget.bootstrap.rashis, result.rashiId) ?? _rashi;
    }
    _charan = result.charan;
    _ganId = result.ganId;
    _nadiId = result.nadiId;
    _yoniId = result.yoniId;

    _nakshatraWasDerived =
        result.nakshatraId != null && result.nakshatraId != beforeNakshatra;
    _rashiWasDerived = result.rashiId != null && result.rashiId != beforeRashi;
    _charanWasDerived = result.charan != null && result.charan != beforeCharan;

    final ashtakoota = _ashtakoota.forRashi(result.rashiId);
    _varnaId = ashtakoota.varnaId;
    _vashyaId = ashtakoota.vashyaId;
    _rashiLordId = ashtakoota.rashiLordId;
  }

  List<OnboardingOption> _optionsMatchingIds(
    List<OnboardingOption> options,
    List<int> allowedIds,
  ) {
    if (allowedIds.isEmpty) return options;
    final allowed = allowedIds.toSet();

    return options
        .where(
          (option) => option.intId != null && allowed.contains(option.intId),
        )
        .toList();
  }

  List<OnboardingOption> get _nakshatraOptionsForSelection {
    return _optionsMatchingIds(
      widget.bootstrap.nakshatras,
      _rules.nakshatraIdsFor(rashiId: _rashi?.intId, charan: _charan),
    );
  }

  List<OnboardingOption> get _rashiOptionsForSelection {
    return _optionsMatchingIds(
      widget.bootstrap.rashis,
      _rules.allowedRashiIds(_nakshatra?.intId),
    );
  }

  List<OnboardingOption> get _charanOptions {
    final valid = _rules.validCharans(
      nakshatraId: _nakshatra?.intId,
      rashiId: _rashi?.intId,
    );

    if (widget.bootstrap.charanOptions.isNotEmpty) {
      final filtered = widget.bootstrap.charanOptions.where((option) {
        final value = _charanValue(option);
        return value != null && valid.contains(value);
      }).toList();

      return filtered.isEmpty ? widget.bootstrap.charanOptions : filtered;
    }

    return valid
        .map(
          (charan) => OnboardingOption(
            key: charan.toString(),
            label: charan.toString(),
          ),
        )
        .toList();
  }

  int? _charanValue(OnboardingOption option) {
    return onboardingInt(option.id) ?? onboardingInt(option.key);
  }

  Future<PagedLookupResponse> _pageOptions(
    List<OnboardingOption> options,
    String query,
    int page,
    int limit,
  ) async {
    final q = query.trim().toLowerCase();
    final rows = options
        .where(
          (option) =>
              q.isEmpty ||
              option.label.toLowerCase().contains(q) ||
              (option.key?.toLowerCase().contains(q) ?? false),
        )
        .toList();
    final start = (page - 1) * limit;
    return PagedLookupResponse.fromOptions(
      start >= rows.length ? const [] : rows.skip(start).take(limit).toList(),
    );
  }

  Future<void> _save({bool skip = false}) async {
    await widget.onSave(
      'astro',
      skip
          ? const <String, dynamic>{}
          : compactPayload({
              'mangal_dosh_type_id': _mangalDosh?.intId,
              if (_mangalDosh?.intId != null)
                'mangal_dosh_type_option': _mangalDosh!.toJson(),
              'nakshatra_id': _nakshatra?.intId,
              if (_nakshatra?.intId != null)
                'nakshatra_option': _nakshatra!.toJson(),
              'rashi_id': _rashi?.intId,
              if (_rashi?.intId != null) 'rashi_option': _rashi!.toJson(),
              'charan': _charan,
              // Derived behind the scenes from the nakshatra; not rendered
              // here, but sent so onboarding and Edit Profile agree.
              'gan_id': _ganId,
              'nadi_id': _nadiId,
              'yoni_id': _yoniId,
              // Derived behind the scenes from the rashi, same rule Edit
              // Profile applies; also not rendered here.
              'varna_id': _varnaId,
              'vashya_id': _vashyaId,
              'rashi_lord_id': _rashiLordId,
            }),
      saveProfile: !skip,
    );
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingStepScaffold(
      title: appText.astroDetails,
      subtitle: appText.thisIsOptionalAddOnlyWhat,
      loading: widget.loading,
      onBack: widget.onBack,
      onContinue: _save,
      continueLabel: appText.saveAndContinue2,
      secondary: TextButton(
        onPressed: widget.loading ? null : () => _save(skip: true),
        style: TextButton.styleFrom(
          foregroundColor: Colors.grey.shade700,
        ),
        child: Text(appText.skipAstroDetails),
      ),
      children: [
        // Said once. It used to sit under each question, which cost lines and
        // still left the step reading like something that must be completed.
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            appText.astroAllOptional,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        _mangalDoshGroup(context),
        const SizedBox(height: 10),
        _triangleGroup(context),
      ],
    );
  }

  Widget _mangalDoshGroup(BuildContext context) {
    final options = widget.bootstrap.mangalDoshTypes;
    if (options.isEmpty) {
      return _picker(
        label: appText.mangalDosh,
        selected: _mangalDosh,
        options: options,
        onChanged: (option) => setState(() => _mangalDosh = option),
      );
    }

    return _AstroSectionCard(
      title: appText.mangalDosh,
      child: _AstroEqualChipGrid(
        options: options,
        isSelected: (option) => _mangalDosh?.identity == option.identity,
        onSelected: (option) => setState(() => _mangalDosh = option),
      ),
    );
  }

  /// Nakshatra, rashi and charan in one box, because they are one question
  /// asked three ways — any two of them name the third.
  ///
  /// They used to sit apart, looking exactly as independent as mangal dosh
  /// above them. The rules engine has known the relationship since the start;
  /// nothing on screen ever said so, so nobody knew they could stop after two.
  Widget _triangleGroup(BuildContext context) {
    final theme = Theme.of(context);
    final derived = _derivedNote();

    final anyFilled =
        _nakshatra != null || _rashi != null || _charan != null;

    return _AstroSectionCard(
      title: appText.astroTriangleLabel,
      accent: true,
      // Offered only once something is filled: a clear button over three empty
      // fields is noise, and it is the one action that always works — see
      // [_clearTriangle].
      trailing: anyFilled
          ? TextButton.icon(
              onPressed: _clearTriangle,
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(appText.astroClearAll),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.compact,
              ),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _pickerRow(
            label: appText.nakshatra,
            selected: _nakshatra,
            options: _nakshatraOptionsForSelection,
            onChanged: (option) => setState(() {
              _nakshatra = option;
              if (option == null) {
                _charan = null;
              }
              _reconcile();
            }),
            onClear: () => setState(() => _nakshatra = null),
          ),
          const SizedBox(height: 8),
          _pickerRow(
            label: appText.rashi,
            selected: _rashi,
            options: _rashiOptionsForSelection,
            onChanged: (option) => setState(() {
              _rashi = option;
              _reconcile();
            }),
            onClear: () => setState(() => _rashi = null),
          ),
          const SizedBox(height: 8),
          _charanRow(context),
          if (derived != null) ...[
            const SizedBox(height: 8),
            Text(
              derived,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.blue.shade800,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Empties all three corners at once.
  ///
  /// The only clear that is guaranteed to hold. Clearing a single corner while
  /// the other two remain leaves the rules able to derive it straight back, so
  /// a member who filled the set wrongly needs this to start over.
  ///
  /// Deliberately does not run the reconciler afterwards — with nothing left to
  /// reason from it has nothing to restore, and calling it would only invite
  /// the question of what it might put back.
  void _clearTriangle() {
    setState(() {
      _nakshatra = null;
      _rashi = null;
      _charan = null;
      _nakshatraWasDerived = false;
      _rashiWasDerived = false;
      _charanWasDerived = false;
    });
  }

  /// A picker with a clear button once it holds something.
  ///
  /// Clearing one field does NOT reconcile: reconciling here would use the
  /// remaining two to put the value straight back, and the field would look
  /// like it refused to be emptied.
  Widget _pickerRow({
    required String label,
    required OnboardingOption? selected,
    required List<OnboardingOption> options,
    required ValueChanged<OnboardingOption?> onChanged,
    required VoidCallback onClear,
  }) {
    final field = _picker(
      label: label,
      selected: selected,
      options: options,
      onChanged: onChanged,
    );

    if (selected == null) return field;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: field),
        IconButton(
          onPressed: onClear,
          icon: const Icon(Icons.close, size: 18),
          tooltip: appText.astroClearField,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
      ],
    );
  }

  /// Names whichever corner the rules just filled in.
  ///
  /// Without it a value appears in a field the member never touched, and the
  /// app looks like it is changing their answers behind their back.
  String? _derivedNote() {
    if (_rashiWasDerived) return appText.astroDerivedRashi;
    if (_nakshatraWasDerived) return appText.astroDerivedNakshatra;
    if (_charanWasDerived) return appText.astroDerivedCharan;
    return null;
  }

  Widget _charanRow(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 58,
          child: Text(
            appText.charan,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Expanded(
          child: _AstroEqualChipGrid(
            options: _charanOptions,
            isSelected: (option) =>
                _charan != null && _charan == _charanValue(option),
            onSelected: (option) => setState(() {
              _charan = _charanValue(option);
              _reconcile();
            }),
            columns: _charanOptions.length <= 4
                ? _charanOptions.length
                : 2,
          ),
        ),
      ],
    );
  }

  Widget _picker({
    required String label,
    required OnboardingOption? selected,
    required List<OnboardingOption> options,
    required ValueChanged<OnboardingOption?> onChanged,
  }) {
    return OnboardingPickerField(
      label: label,
      selectedItems: selected == null ? const [] : [selected],
      placeholder: appText.select,
      loadPage: (query, page, limit) =>
          _pageOptions(options, query, page, limit),
      onChanged: (items) => onChanged(items.isEmpty ? null : items.first),
      emptyTitle: appText.noOptionsFound2,
      emptyMessage: appText.tryAgainAfterTheLatestServer,
    );
  }
}

class _AstroSectionCard extends StatelessWidget {
  const _AstroSectionCard({
    required this.title,
    required this.child,
    this.accent = false,
    this.trailing,
  });

  final String title;
  final Widget child;

  /// Sits beside the title — the clear action for the box.
  final Widget? trailing;

  /// Marks the box holding fields that depend on each other, so it reads as one
  /// question rather than three unrelated ones.
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: accent ? Colors.blue.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: accent ? Colors.blue.shade200 : Colors.grey.shade300,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: accent
                          ? Colors.blue.shade800
                          : Colors.grey.shade900,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 6),
            child,
          ],
        ),
      ),
    );
  }
}

/// Equal-width soft-square chips for astro option rows.
class _AstroEqualChipGrid extends StatelessWidget {
  const _AstroEqualChipGrid({
    required this.options,
    required this.isSelected,
    required this.onSelected,
    this.columns,
  });

  final List<OnboardingOption> options;
  final bool Function(OnboardingOption option) isSelected;
  final ValueChanged<OnboardingOption> onSelected;
  final int? columns;

  @override
  Widget build(BuildContext context) {
    final count = options.length;
    if (count == 0) return const SizedBox.shrink();

    final cols = columns ??
        (count <= 1
            ? 1
            : count == 3
                ? 3
                : 2);

    return Column(
      children: [
        for (var rowStart = 0; rowStart < count; rowStart += cols)
          Padding(
            padding: EdgeInsets.only(
              bottom: rowStart + cols < count ? 6 : 0,
            ),
            child: Row(
              children: [
                for (var col = 0; col < cols; col++) ...[
                  if (col > 0) const SizedBox(width: 6),
                  Expanded(
                    child: rowStart + col < count
                        ? OnboardingSelectablePill(
                            label: options[rowStart + col].label,
                            selected: isSelected(options[rowStart + col]),
                            onTap: () => onSelected(options[rowStart + col]),
                            expandWidth: true,
                            cornerRadius: 8,
                            minHeight: 40,
                            fontSize: 13,
                            maxLines: 1,
                            horizontalPadding: 8,
                            verticalPadding: 8,
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
