import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../models/onboarding_option.dart';
import '../models/paged_lookup_response.dart';
import '../widgets/onboarding_picker_field.dart';
import 'onboarding_step_helpers.dart';
import 'onboarding_step_scaffold.dart';

class FamilyOptionalStep extends StatefulWidget {
  const FamilyOptionalStep({
    super.key,
    required this.data,
    required this.locale,
    required this.loading,
    required this.onSave,
    required this.onBack,
  });

  final Map<String, dynamic> data;
  final String locale;
  final bool loading;
  final OnboardingStepSaver onSave;
  final VoidCallback onBack;

  @override
  State<FamilyOptionalStep> createState() => _FamilyOptionalStepState();
}

class _FamilyOptionalStepState extends State<FamilyOptionalStep> {
  final TextEditingController _fatherNameController = TextEditingController();
  final TextEditingController _fatherInfoController = TextEditingController();
  final TextEditingController _motherNameController = TextEditingController();
  final TextEditingController _motherInfoController = TextEditingController();
  final TextEditingController _brothersCountController =
      TextEditingController();
  final TextEditingController _sistersCountController = TextEditingController();

  OnboardingOption? _fatherOccupation;
  OnboardingOption? _motherOccupation;
  bool get _mr => widget.locale == 'mr';

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  @override
  void didUpdateWidget(covariant FamilyOptionalStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) _prefill();
  }

  @override
  void dispose() {
    _fatherNameController.dispose();
    _fatherInfoController.dispose();
    _motherNameController.dispose();
    _motherInfoController.dispose();
    _brothersCountController.dispose();
    _sistersCountController.dispose();
    super.dispose();
  }

  void _prefill() {
    final data = widget.data;
    _fatherNameController.text = onboardingText(data['father_name']) ?? '';
    _fatherInfoController.text =
        onboardingText(data['father_extra_info']) ?? '';
    _motherNameController.text = onboardingText(data['mother_name']) ?? '';
    _motherInfoController.text =
        onboardingText(data['mother_extra_info']) ?? '';
    _brothersCountController.text =
        onboardingInt(data['brothers_count'])?.toString() ?? '';
    _sistersCountController.text =
        onboardingInt(data['sisters_count'])?.toString() ?? '';
    _fatherOccupation =
        optionFromData(data['father_occupation_option']) ??
        _placeholder(data['father_occupation_master_id'], 'Occupation');
    _motherOccupation =
        optionFromData(data['mother_occupation_option']) ??
        _placeholder(data['mother_occupation_master_id'], 'Occupation');
  }

  String _t(String en, String mr) => _mr ? mr : en;

  OnboardingOption? _placeholder(dynamic id, String label) {
    final intId = onboardingInt(id);
    if (intId == null) return null;
    return OnboardingOption(id: intId, label: '$label #$intId');
  }

  Future<PagedLookupResponse> _occupationPage(
    String query,
    int page,
    int limit,
  ) async {
    return PagedLookupResponse.fromJson(
      await ApiClient.searchOccupations(
        query: query,
        page: page,
        limit: limit,
        locale: widget.locale,
      ),
    );
  }

  Future<void> _save() async {
    await widget.onSave(
      'family',
      compactPayload({
        'father_name': _fatherNameController.text.trim(),
        'father_occupation_master_id': _fatherOccupation?.intId,
        'father_extra_info': _fatherInfoController.text.trim(),
        'mother_name': _motherNameController.text.trim(),
        'mother_occupation_master_id': _motherOccupation?.intId,
        'mother_extra_info': _motherInfoController.text.trim(),
        'brothers_count': onboardingInt(_brothersCountController.text),
        'sisters_count': onboardingInt(_sistersCountController.text),
      }),
      saveProfile: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingStepScaffold(
      title: _t('Family details', 'कुटुंब माहिती'),
      subtitle: _t(
        'This is optional. You can skip it now.',
        'ही माहिती optional आहे. सध्या skip करू शकता.',
      ),
      loading: widget.loading,
      onBack: widget.onBack,
      onContinue: _save,
      continueLabel: _t('Save optional details', 'Optional तपशील save करा'),
      secondary: TextButton(
        onPressed: widget.loading
            ? null
            : () => widget.onSave('family', const {}, saveProfile: false),
        child: Text(
          _t('Skip optional family details', 'Optional family skip करा'),
        ),
      ),
      children: [
        TextField(
          controller: _fatherNameController,
          decoration: InputDecoration(
            labelText: _t('Father name optional', 'वडिलांचे नाव optional'),
          ),
        ),
        const SizedBox(height: 12),
        _occupationPicker(
          label: _t('Father occupation', 'वडिलांचा व्यवसाय'),
          selected: _fatherOccupation,
          onChanged: (option) => setState(() => _fatherOccupation = option),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _fatherInfoController,
          decoration: InputDecoration(
            labelText: _t('Father notes optional', 'वडिलांची माहिती optional'),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _motherNameController,
          decoration: InputDecoration(
            labelText: _t('Mother name optional', 'आईचे नाव optional'),
          ),
        ),
        const SizedBox(height: 12),
        _occupationPicker(
          label: _t('Mother occupation', 'आईचा व्यवसाय'),
          selected: _motherOccupation,
          onChanged: (option) => setState(() => _motherOccupation = option),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _motherInfoController,
          decoration: InputDecoration(
            labelText: _t('Mother notes optional', 'आईची माहिती optional'),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _brothersCountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _t('Brothers count', 'भावांची संख्या'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _sistersCountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _t('Sisters count', 'बहिणींची संख्या'),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _t(
            'Detailed sibling information can be added later from Edit Profile.',
            'भावंडांची सविस्तर माहिती नंतर Edit Profile मधून भरू शकता.',
          ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _occupationPicker({
    required String label,
    required OnboardingOption? selected,
    required ValueChanged<OnboardingOption?> onChanged,
  }) {
    return OnboardingPickerField(
      label: label,
      selectedItems: selected == null ? const [] : [selected],
      placeholder: _t('Search occupation', 'Occupation शोधा'),
      loadPage: _occupationPage,
      itemSubtitleBuilder: (option) => option.metaText('category_label'),
      onChanged: (items) => onChanged(items.isEmpty ? null : items.first),
    );
  }
}
