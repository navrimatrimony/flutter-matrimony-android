import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/onboarding_bootstrap.dart';
import '../models/onboarding_option.dart';
import '../models/paged_lookup_response.dart';
import '../widgets/onboarding_picker_field.dart';
import 'onboarding_step_helpers.dart';
import 'onboarding_step_scaffold.dart';

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

  bool get _mr => widget.locale == 'mr';

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
  }

  String _t(String en, String mr) => _mr ? mr : en;

  List<OnboardingOption> get _charanOptions {
    if (widget.bootstrap.charanOptions.isNotEmpty) {
      return widget.bootstrap.charanOptions;
    }

    return const [1, 2, 3, 4]
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
            }),
      saveProfile: !skip,
    );
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingStepScaffold(
      title: _t('Astro details', 'ज्योतिष माहिती'),
      subtitle: _t(
        'This is optional. Add only what you know now.',
        'ही माहिती optional आहे. आत्ता जे माहिती आहे तेवढेच भरा.',
      ),
      loading: widget.loading,
      onBack: widget.onBack,
      onContinue: _save,
      continueLabel: _t('Save and continue', 'सेव्ह करून पुढे जा'),
      secondary: TextButton(
        onPressed: widget.loading ? null : () => _save(skip: true),
        child: Text(_t('Skip astro details', 'ज्योतिष माहिती skip करा')),
      ),
      children: [
        _mangalDoshGroup(context),
        const SizedBox(height: 14),
        _picker(
          label: _t('Nakshatra', 'नक्षत्र'),
          selected: _nakshatra,
          options: widget.bootstrap.nakshatras,
          onChanged: (option) => setState(() => _nakshatra = option),
        ),
        const SizedBox(height: 12),
        _picker(
          label: _t('Rashi', 'राशी'),
          selected: _rashi,
          options: widget.bootstrap.rashis,
          onChanged: (option) => setState(() => _rashi = option),
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
        label: _t('Mangal dosh', 'मंगळ दोष'),
        selected: _mangalDosh,
        options: options,
        onChanged: (option) => setState(() => _mangalDosh = option),
      );
    }

    return _AstroSectionCard(
      title: _t('Mangal dosh', 'मंगळ दोष'),
      subtitle: _t('Select if known', 'माहित असल्यास निवडा'),
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
      title: _t('Charan', 'चरण'),
      subtitle: _t('Optional', 'Optional'),
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
                onTap: () => setState(() => _charan = _charanValue(option)),
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
      placeholder: _t('Select', 'निवडा'),
      loadPage: (query, page, limit) =>
          _pageOptions(options, query, page, limit),
      onChanged: (items) => onChanged(items.isEmpty ? null : items.first),
      emptyTitle: _t('No options found', 'पर्याय मिळाले नाहीत'),
      emptyMessage: _t(
        'Try again after the latest server update.',
        'Server update नंतर पुन्हा प्रयत्न करा.',
      ),
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
