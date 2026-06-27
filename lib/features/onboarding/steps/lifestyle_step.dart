import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../models/onboarding_bootstrap.dart';
import '../models/onboarding_option.dart';
import '../models/paged_lookup_response.dart';
import '../widgets/onboarding_picker_field.dart';
import 'onboarding_step_helpers.dart';
import 'onboarding_step_scaffold.dart';

class LifestyleStep extends StatefulWidget {
  const LifestyleStep({
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
  State<LifestyleStep> createState() => _LifestyleStepState();
}

class _LifestyleStepState extends State<LifestyleStep> {
  OnboardingOption? _diet;
  OnboardingOption? _smoking;
  OnboardingOption? _drinking;

  bool get _mr => widget.locale == 'mr';

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  @override
  void didUpdateWidget(covariant LifestyleStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!mapEquals(oldWidget.data, widget.data) ||
        oldWidget.bootstrap != widget.bootstrap) {
      _prefill();
    }
  }

  void _prefill() {
    _diet =
        optionFromData(widget.data['diet_option']) ??
        optionById(widget.bootstrap.diets, widget.data['diet_id']);
    _smoking =
        optionFromData(widget.data['smoking_option']) ??
        optionById(
          widget.bootstrap.smokingOptions,
          widget.data['smoking_status_id'],
        );
    _drinking =
        optionFromData(widget.data['drinking_option']) ??
        optionById(
          widget.bootstrap.drinkingOptions,
          widget.data['drinking_status_id'],
        );
  }

  String _t(String en, String mr) => _mr ? mr : en;

  Future<PagedLookupResponse> _page(
    String type,
    List<OnboardingOption> fallback,
    String query,
    int page,
    int limit,
  ) async {
    if (fallback.isNotEmpty) {
      final q = query.trim().toLowerCase();
      final rows = fallback
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

    return PagedLookupResponse.fromJson(
      await ApiClient.getLifestyleLookup(
        type: type,
        query: query,
        page: page,
        limit: limit,
        locale: widget.locale,
      ),
    );
  }

  Future<void> _save() async {
    await widget.onSave(
      'lifestyle',
      compactPayload({
        'diet_id': _diet?.intId,
        if (_diet?.intId != null) 'diet_option': _diet!.toJson(),
        'smoking_status_id': _smoking?.intId,
        if (_smoking?.intId != null) 'smoking_option': _smoking!.toJson(),
        'drinking_status_id': _drinking?.intId,
        if (_drinking?.intId != null) 'drinking_option': _drinking!.toJson(),
      }),
      saveProfile: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingStepScaffold(
      title: _t('Lifestyle details', 'जीवनशैली माहिती'),
      subtitle: _t(
        'Choose what you want to share now. You can change it later.',
        'आता जी माहिती द्यायची आहे ती निवडा. नंतर बदलता येईल.',
      ),
      loading: widget.loading,
      onBack: widget.onBack,
      onContinue: _save,
      children: [
        _optionGroup(
          label: _t('Diet', 'आहार'),
          helper: _t(
            'Useful for day-to-day compatibility.',
            'दैनंदिन जुळवणीसाठी उपयोगी.',
          ),
          options: widget.bootstrap.diets,
          lookupType: 'diet',
          selected: _diet,
          onChanged: (option) => setState(() => _diet = option),
        ),
        const SizedBox(height: 16),
        _optionGroup(
          label: _t('Smoking', 'Smoking'),
          helper: _t('Optional', 'Optional'),
          options: widget.bootstrap.smokingOptions,
          lookupType: 'smoking',
          selected: _smoking,
          onChanged: (option) => setState(() => _smoking = option),
        ),
        const SizedBox(height: 16),
        _optionGroup(
          label: _t('Drinking', 'Drinking'),
          helper: _t('Optional', 'Optional'),
          options: widget.bootstrap.drinkingOptions,
          lookupType: 'drinking',
          selected: _drinking,
          onChanged: (option) => setState(() => _drinking = option),
        ),
      ],
    );
  }

  Widget _optionGroup({
    required String label,
    required String helper,
    required List<OnboardingOption> options,
    required String lookupType,
    required OnboardingOption? selected,
    required ValueChanged<OnboardingOption?> onChanged,
  }) {
    if (options.isEmpty) {
      return _picker(
        label: label,
        selected: selected,
        loadPage: (query, page, limit) =>
            _page(lookupType, options, query, page, limit),
        onChanged: onChanged,
      );
    }

    return _OptionGroupShell(
      title: label,
      helper: helper,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final available = constraints.maxWidth;
            final twoColumn = available >= 300;
            final itemWidth = twoColumn ? (available - 10) / 2 : available;

            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final option in options)
                  SizedBox(
                    width: itemWidth,
                    child: OnboardingSelectablePill(
                      label: option.label,
                      selected: selected?.identity == option.identity,
                      onTap: () => onChanged(option),
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
      ],
    );
  }

  Widget _picker({
    required String label,
    required OnboardingOption? selected,
    required Future<PagedLookupResponse> Function(String, int, int) loadPage,
    required ValueChanged<OnboardingOption?> onChanged,
  }) {
    return OnboardingPickerField(
      label: label,
      selectedItems: selected == null ? const [] : [selected],
      placeholder: _t('Select', 'निवडा'),
      loadPage: loadPage,
      onChanged: (items) => onChanged(items.isEmpty ? null : items.first),
    );
  }
}

class _OptionGroupShell extends StatelessWidget {
  const _OptionGroupShell({
    required this.title,
    required this.helper,
    required this.children,
  });

  final String title;
  final String helper;
  final List<Widget> children;

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
                  helper,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}
