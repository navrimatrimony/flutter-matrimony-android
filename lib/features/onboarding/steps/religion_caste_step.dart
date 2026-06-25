import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../models/onboarding_option.dart';
import '../models/paged_lookup_response.dart';
import '../widgets/onboarding_picker_field.dart';
import 'onboarding_step_helpers.dart';
import 'onboarding_step_scaffold.dart';

enum CommunityStrictness { open, preferred, required }

class ReligionCasteStep extends StatefulWidget {
  const ReligionCasteStep({
    super.key,
    required this.data,
    required this.locale,
    required this.loading,
    required this.onSave,
    required this.onBack,
    required this.onMessage,
  });

  final Map<String, dynamic> data;
  final String locale;
  final bool loading;
  final OnboardingStepSaver onSave;
  final VoidCallback onBack;
  final ValueChanged<String> onMessage;

  @override
  State<ReligionCasteStep> createState() => _ReligionCasteStepState();
}

class _ReligionCasteStepState extends State<ReligionCasteStep> {
  OnboardingOption? _religion;
  OnboardingOption? _caste;
  OnboardingOption? _subCaste;
  CommunityStrictness _religionStrictness = CommunityStrictness.preferred;
  CommunityStrictness _casteStrictness = CommunityStrictness.preferred;
  CommunityStrictness _subCasteStrictness = CommunityStrictness.open;

  bool get _mr => widget.locale == 'mr';

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  @override
  void didUpdateWidget(covariant ReligionCasteStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) _prefill();
  }

  void _prefill() {
    final data = widget.data;
    _religion =
        optionFromData(data['religion_option']) ??
        _placeholderOption(data['religion_id'], 'Religion');
    _caste =
        optionFromData(data['caste_option']) ??
        _placeholderOption(data['caste_id'], 'Caste');
    _subCaste =
        optionFromData(data['sub_caste_option']) ??
        _placeholderOption(data['sub_caste_id'], 'Sub-caste');
    _religionStrictness = _strictnessFromValue(
      data['religion_strictness'] ??
          data['same_religion_required'] ??
          data['same_religion_expected'],
      CommunityStrictness.preferred,
    );
    _casteStrictness = _strictnessFromValue(
      data['caste_strictness'] ??
          data['same_caste_required'] ??
          data['same_caste_expected'],
      CommunityStrictness.preferred,
    );
    _subCasteStrictness = _strictnessFromValue(
      data['sub_caste_strictness'] ?? data['same_sub_caste_required'],
      CommunityStrictness.open,
    );
  }

  String _t(String en, String mr) => _mr ? mr : en;

  OnboardingOption? _placeholderOption(dynamic id, String label) {
    final intId = onboardingInt(id);
    if (intId == null) return null;
    return OnboardingOption(id: intId, label: '$label #$intId');
  }

  CommunityStrictness _strictnessFromValue(
    dynamic value,
    CommunityStrictness fallback,
  ) {
    if (value == null) return fallback;
    final text = onboardingText(value)?.toLowerCase().replaceAll('-', '_');
    switch (text) {
      case 'required':
      case 'must_match':
        return CommunityStrictness.required;
      case 'preferred':
        return CommunityStrictness.preferred;
      case 'open':
        return CommunityStrictness.open;
    }
    return onboardingBool(value) == true
        ? CommunityStrictness.required
        : CommunityStrictness.open;
  }

  String _strictnessToBackend(CommunityStrictness value) {
    switch (value) {
      case CommunityStrictness.required:
        return 'required';
      case CommunityStrictness.open:
        return 'open';
      case CommunityStrictness.preferred:
        return 'preferred';
    }
  }

  Future<PagedLookupResponse> _religionPage(
    String query,
    int page,
    int limit,
  ) async {
    return PagedLookupResponse.fromJson(
      await ApiClient.searchReligions(
        query: query,
        page: page,
        limit: limit,
        locale: widget.locale,
      ),
    );
  }

  Future<PagedLookupResponse> _castePage(
    String query,
    int page,
    int limit,
  ) async {
    final religionId = _religion?.intId;
    if (religionId == null) return PagedLookupResponse.fromOptions(const []);
    return PagedLookupResponse.fromJson(
      await ApiClient.searchCastes(
        religionId: religionId,
        query: query,
        page: page,
        limit: limit,
        locale: widget.locale,
      ),
    );
  }

  Future<PagedLookupResponse> _subCastePage(
    String query,
    int page,
    int limit,
  ) async {
    final casteId = _caste?.intId;
    if (casteId == null) return PagedLookupResponse.fromOptions(const []);
    return PagedLookupResponse.fromJson(
      await ApiClient.searchSubCastesForOnboarding(
        casteId: casteId,
        query: query,
        page: page,
        limit: limit,
        locale: widget.locale,
      ),
    );
  }

  Future<void> _save() async {
    final payload = <String, dynamic>{
      'religion_id': _religion?.intId,
      'caste_id': _caste?.intId,
      'sub_caste_id': _subCaste?.intId,
      'religion_strictness': _strictnessToBackend(_religionStrictness),
      'caste_strictness': _strictnessToBackend(_casteStrictness),
      'sub_caste_strictness': _strictnessToBackend(_subCasteStrictness),
    };

    await widget.onSave('religion_caste', payload, saveProfile: true);
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingStepScaffold(
      title: _t('Religion / Caste', 'धर्म / जात'),
      subtitle: _t(
        'Choose religion first, then caste and sub-caste.',
        'आधी धर्म, नंतर जात आणि पोटजात निवडा.',
      ),
      loading: widget.loading,
      onBack: widget.onBack,
      onContinue: _save,
      children: [
        _picker(
          label: _t('Religion', 'धर्म'),
          selected: _religion,
          loadPage: _religionPage,
          onChanged: (option) => setState(() {
            if (_religion?.identity == option?.identity) return;
            _religion = option;
            _caste = null;
            _subCaste = null;
            _casteStrictness = CommunityStrictness.preferred;
            _subCasteStrictness = CommunityStrictness.open;
          }),
        ),
        const SizedBox(height: 12),
        _strictnessControl(
          label: _t('Partner religion expectation', 'जोडीदार धर्म अपेक्षा'),
          value: _religionStrictness,
          onChanged: (value) => setState(() => _religionStrictness = value),
        ),
        const SizedBox(height: 16),
        _picker(
          label: _t('Caste', 'जात'),
          selected: _caste,
          enabled: _religion != null,
          loadPage: _castePage,
          onChanged: (option) => setState(() {
            if (_caste?.identity == option?.identity) return;
            _caste = option;
            _subCaste = null;
            _subCasteStrictness = CommunityStrictness.open;
          }),
        ),
        const SizedBox(height: 12),
        _strictnessControl(
          label: _t('Partner caste expectation', 'जोडीदार जात अपेक्षा'),
          value: _casteStrictness,
          onChanged: (value) => setState(() => _casteStrictness = value),
        ),
        const SizedBox(height: 16),
        _picker(
          label: _t('Sub-caste', 'पोटजात'),
          selected: _subCaste,
          enabled: _caste != null,
          loadPage: _subCastePage,
          onChanged: (option) => setState(() => _subCaste = option),
        ),
        const SizedBox(height: 12),
        _strictnessControl(
          label: _t('Partner sub-caste expectation', 'जोडीदार पोटजात अपेक्षा'),
          value: _subCasteStrictness,
          onChanged: (value) => setState(() => _subCasteStrictness = value),
        ),
      ],
    );
  }

  Widget _picker({
    required String label,
    required OnboardingOption? selected,
    required Future<PagedLookupResponse> Function(String, int, int) loadPage,
    required ValueChanged<OnboardingOption?> onChanged,
    bool enabled = true,
  }) {
    return OnboardingPickerField(
      label: label,
      selectedItems: selected == null ? const [] : [selected],
      placeholder: _t('Select', 'निवडा'),
      searchHint: _t('Search', 'शोधा'),
      enabled: enabled,
      loadPage: loadPage,
      onChanged: (items) => onChanged(items.isEmpty ? null : items.first),
    );
  }

  Widget _strictnessControl({
    required String label,
    required CommunityStrictness value,
    required ValueChanged<CommunityStrictness> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        SegmentedButton<CommunityStrictness>(
          segments: [
            ButtonSegment(
              value: CommunityStrictness.open,
              label: Text(_t('Open', 'Open')),
            ),
            ButtonSegment(
              value: CommunityStrictness.preferred,
              label: Text(_t('Preferred', 'Preferred')),
            ),
            ButtonSegment(
              value: CommunityStrictness.required,
              label: Text(_t('Required', 'Required')),
            ),
          ],
          selected: {value},
          onSelectionChanged: (values) => onChanged(values.first),
          showSelectedIcon: false,
        ),
      ],
    );
  }
}
