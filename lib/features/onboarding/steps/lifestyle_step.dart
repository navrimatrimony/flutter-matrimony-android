import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../models/onboarding_bootstrap.dart';
import '../models/onboarding_option.dart';
import '../models/paged_lookup_response.dart';
import '../widgets/onboarding_picker_field.dart';
import 'onboarding_step_helpers.dart';
import 'onboarding_step_scaffold.dart';
import '../../../core/app_language.dart';

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
  OnboardingOption? _physicalBuild;
  OnboardingOption? _spectaclesLens;

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
    _physicalBuild =
        optionFromData(widget.data['physical_build_option']) ??
        optionById(
          widget.bootstrap.physicalBuilds,
          widget.data['physical_build_id'],
        );
    _spectaclesLens =
        optionFromData(widget.data['spectacles_lens_option']) ??
        optionByKey(
          widget.bootstrap.spectaclesLensOptions,
          widget.data['spectacles_lens'],
        );
  }

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
        'physical_build_id': _physicalBuild?.intId,
        if (_physicalBuild?.intId != null)
          'physical_build_option': _physicalBuild!.toJson(),
        'spectacles_lens': _spectaclesLens?.key,
        if (_spectaclesLens?.key != null)
          'spectacles_lens_option': _spectaclesLens!.toJson(),
      }),
      saveProfile: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingStepScaffold(
      title: '',
      loading: widget.loading,
      continueLabel: appText.continueLabel,
      onBack: widget.onBack,
      onContinue: _save,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            appText.lifestyleAllOptional,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        _optionGroup(
          label: appText.diet,
          options: widget.bootstrap.diets,
          lookupType: 'diet',
          selected: _diet,
          onChanged: (option) => setState(() => _diet = option),
        ),
        const SizedBox(height: 10),
        _optionGroup(
          label: appText.smoking,
          options: widget.bootstrap.smokingOptions,
          lookupType: 'smoking',
          selected: _smoking,
          onChanged: (option) => setState(() => _smoking = option),
        ),
        const SizedBox(height: 10),
        _optionGroup(
          label: appText.drinking,
          options: widget.bootstrap.drinkingOptions,
          lookupType: 'drinking',
          selected: _drinking,
          onChanged: (option) => setState(() => _drinking = option),
        ),
        const SizedBox(height: 10),
        _optionGroup(
          label: appText.physicalBuild,
          options: widget.bootstrap.physicalBuilds,
          lookupType: 'physical-builds',
          selected: _physicalBuild,
          onChanged: (option) => setState(() => _physicalBuild = option),
        ),
        const SizedBox(height: 10),
        _optionGroup(
          label: appText.spectaclesLens,
          options: widget.bootstrap.spectaclesLensOptions,
          lookupType: 'spectacles-lens',
          selected: _spectaclesLens,
          onChanged: (option) => setState(() => _spectaclesLens = option),
        ),
      ],
    );
  }

  Widget _optionGroup({
    required String label,
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
      children: [
        _LifestyleEqualChipGrid(
          options: options,
          selected: selected,
          onChanged: onChanged,
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
      placeholder: appText.select,
      loadPage: loadPage,
      onChanged: (items) => onChanged(items.isEmpty ? null : items.first),
    );
  }
}

/// Equal-width soft-square chips — not stadium Wrap pills.
class _LifestyleEqualChipGrid extends StatelessWidget {
  const _LifestyleEqualChipGrid({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<OnboardingOption> options;
  final OnboardingOption? selected;
  final ValueChanged<OnboardingOption?> onChanged;

  @override
  Widget build(BuildContext context) {
    final count = options.length;
    final columns = count <= 1
        ? 1
        : count == 3
            ? 3
            : 2;

    return Column(
      children: [
        for (var rowStart = 0; rowStart < count; rowStart += columns)
          Padding(
            padding: EdgeInsets.only(
              bottom: rowStart + columns < count ? 6 : 0,
            ),
            child: Row(
              children: [
                for (var col = 0; col < columns; col++) ...[
                  if (col > 0) const SizedBox(width: 6),
                  Expanded(
                    child: rowStart + col < count
                        ? OnboardingSelectablePill(
                            label: options[rowStart + col].label,
                            selected: selected?.identity ==
                                options[rowStart + col].identity,
                            onTap: () => onChanged(options[rowStart + col]),
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

class _OptionGroupShell extends StatelessWidget {
  const _OptionGroupShell({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: Colors.grey.shade900,
              ),
            ),
            const SizedBox(height: 6),
            ...children,
          ],
        ),
      ),
    );
  }
}
