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
  bool _intercasteAccepted = false;

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
    final explicitIntercaste = onboardingBool(data['intercaste_accepted']);
    final casteStrictness = _strictnessFromValue(
      data['caste_strictness'] ??
          data['same_caste_required'] ??
          data['same_caste_expected'],
      CommunityStrictness.preferred,
    );
    final subCasteStrictness = _strictnessFromValue(
      data['sub_caste_strictness'] ?? data['same_sub_caste_required'],
      CommunityStrictness.open,
    );
    _intercasteAccepted =
        explicitIntercaste ??
        (casteStrictness == CommunityStrictness.open &&
            subCasteStrictness == CommunityStrictness.open);
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
    final casteStrictness = _intercasteAccepted
        ? CommunityStrictness.open
        : CommunityStrictness.preferred;

    final payload = <String, dynamic>{
      'religion_id': _religion?.intId,
      'caste_id': _caste?.intId,
      'sub_caste_id': _subCaste?.intId,
      'religion_strictness': _strictnessToBackend(
        CommunityStrictness.preferred,
      ),
      'caste_strictness': _strictnessToBackend(casteStrictness),
      'sub_caste_strictness': _strictnessToBackend(CommunityStrictness.open),
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
          }),
        ),
        if (_religion != null) ...[
          const SizedBox(height: 16),
          _picker(
            label: _t('Caste', 'जात'),
            selected: _caste,
            loadPage: _castePage,
            onChanged: (option) => setState(() {
              if (_caste?.identity == option?.identity) return;
              _caste = option;
              _subCaste = null;
            }),
          ),
        ],
        if (_caste != null) ...[
          const SizedBox(height: 16),
          _picker(
            label: _t('Sub-caste', 'पोटजात'),
            selected: _subCaste,
            loadPage: _subCastePage,
            onChanged: (option) => setState(() => _subCaste = option),
          ),
        ],
        const SizedBox(height: 18),
        CheckboxListTile(
          value: _intercasteAccepted,
          onChanged: widget.loading
              ? null
              : (value) => setState(
                  () => _intercasteAccepted = value ?? false,
                ),
          title: Text(
            _t('Intercaste accepted.', 'जातिबंधन नाही'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          dense: true,
          visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
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
      searchHint: _t('Search', 'शोधा'),
      loadPage: loadPage,
      onChanged: (items) => onChanged(items.isEmpty ? null : items.first),
    );
  }
}
