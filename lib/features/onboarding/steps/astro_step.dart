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
  void _reconcile() {
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
    final valid = _rules.charansForNakshatra(_nakshatra?.intId);

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
        child: Text(appText.skipAstroDetails),
      ),
      children: [
        _mangalDoshGroup(context),
        const SizedBox(height: 14),
        _picker(
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
        ),
        const SizedBox(height: 12),
        _picker(
          label: appText.rashi,
          selected: _rashi,
          options: _rashiOptionsForSelection,
          onChanged: (option) => setState(() {
            _rashi = option;
            _reconcile();
          }),
        ),
        const SizedBox(height: 14),
        _charanGroup(context),
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
      subtitle: appText.selectIfKnown,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final itemWidth = width >= 300 ? (width - 10) / 2 : width;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final option in options)
                SizedBox(
                  width: itemWidth,
                  child: OnboardingSelectablePill(
                    label: option.label,
                    selected: _mangalDosh?.identity == option.identity,
                    onTap: () => setState(() => _mangalDosh = option),
                    minHeight: 48,
                    fontSize: 14,
                    maxLines: 2,
                    horizontalPadding: 12,
                    verticalPadding: 10,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _charanGroup(BuildContext context) {
    return _AstroSectionCard(
      title: appText.charan,
      subtitle: appText.optional,
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final option in _charanOptions)
            SizedBox(
              width: 64,
              child: OnboardingSelectablePill(
                label: option.label,
                selected: _charan != null && _charan == _charanValue(option),
                onTap: () => setState(() {
                  _charan = _charanValue(option);
                  _reconcile();
                }),
                minHeight: 46,
                fontSize: 15,
                horizontalPadding: 10,
                verticalPadding: 8,
              ),
            ),
        ],
      ),
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
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: Colors.grey.shade900,
                    ),
                  ),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}
