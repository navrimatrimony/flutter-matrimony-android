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
      title: _t('Lifestyle', 'जीवनशैली'),
      subtitle: _t(
        'Diet is useful for matching. Smoking and drinking are optional.',
        'Diet matching साठी उपयोगी आहे. Smoking/drinking optional आहेत.',
      ),
      loading: widget.loading,
      onBack: widget.onBack,
      onContinue: _save,
      children: [
        _picker(
          label: _t('Diet', 'आहार'),
          selected: _diet,
          loadPage: (query, page, limit) =>
              _page('diet', widget.bootstrap.diets, query, page, limit),
          onChanged: (option) => setState(() => _diet = option),
        ),
        const SizedBox(height: 12),
        _picker(
          label: _t('Smoking optional', 'Smoking optional'),
          selected: _smoking,
          loadPage: (query, page, limit) => _page(
            'smoking',
            widget.bootstrap.smokingOptions,
            query,
            page,
            limit,
          ),
          onChanged: (option) => setState(() => _smoking = option),
        ),
        const SizedBox(height: 12),
        _picker(
          label: _t('Drinking optional', 'Drinking optional'),
          selected: _drinking,
          loadPage: (query, page, limit) => _page(
            'drinking',
            widget.bootstrap.drinkingOptions,
            query,
            page,
            limit,
          ),
          onChanged: (option) => setState(() => _drinking = option),
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
