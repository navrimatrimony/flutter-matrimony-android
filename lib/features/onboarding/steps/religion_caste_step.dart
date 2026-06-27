import 'dart:async';

import 'package:flutter/foundation.dart';
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
  static final Map<String, OnboardingOption> _resolvedOptionCache =
      <String, OnboardingOption>{};

  OnboardingOption? _religion;
  OnboardingOption? _caste;
  OnboardingOption? _subCaste;
  bool _intercasteAccepted = false;
  int _hydrationToken = 0;

  bool get _mr => widget.locale == 'mr';

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  @override
  void didUpdateWidget(covariant ReligionCasteStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!mapEquals(oldWidget.data, widget.data)) {
      _prefill();
    } else if (oldWidget.locale != widget.locale) {
      unawaited(_hydrateSelectedOptions());
    }
  }

  void _prefill() {
    final data = widget.data;
    _religion =
        optionFromData(data['religion_option']) ??
        _placeholderOption(data['religion_id']);
    _caste =
        optionFromData(data['caste_option']) ??
        _placeholderOption(data['caste_id']);
    _subCaste =
        optionFromData(data['sub_caste_option']) ??
        _placeholderOption(data['sub_caste_id']);
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
    unawaited(_hydrateSelectedOptions());
  }

  String _t(String en, String mr) => _mr ? mr : en;

  OnboardingOption? _placeholderOption(dynamic id, {bool failed = false}) {
    return selectedValuePlaceholderOption(id, widget.locale, failed: failed);
  }

  Future<void> _hydrateSelectedOptions() async {
    final token = ++_hydrationToken;
    final locale = widget.locale;
    final religionId = _religion?.intId;
    final casteId = _caste?.intId;
    final subCasteId = _subCaste?.intId;

    if (religionId != null) {
      final option = await _resolveReligion(religionId, locale);
      if (!_canApplyHydratedOption(token, religionId, _religion)) return;
      setState(() {
        _religion = option ?? _placeholderOption(religionId, failed: true);
      });
    }

    if (casteId != null && religionId != null) {
      final option = await _resolveCaste(casteId, religionId, locale);
      if (!_canApplyHydratedOption(token, casteId, _caste)) return;
      setState(() {
        _caste = option ?? _placeholderOption(casteId, failed: true);
      });
    }

    if (subCasteId != null && casteId != null) {
      final option = await _resolveSubCaste(subCasteId, casteId, locale);
      if (!_canApplyHydratedOption(token, subCasteId, _subCaste)) return;
      setState(() {
        _subCaste = option ?? _placeholderOption(subCasteId, failed: true);
      });
    }
  }

  bool _canApplyHydratedOption(int token, int id, OnboardingOption? current) {
    return mounted && token == _hydrationToken && current?.intId == id;
  }

  Future<OnboardingOption?> _resolveReligion(int id, String locale) {
    return _resolveSelectedOption(
      cacheKey: 'religion:$locale:$id',
      id: id,
      loadPage: (page, limit) async => PagedLookupResponse.fromJson(
        await ApiClient.searchReligions(
          query: '',
          page: page,
          limit: limit,
          locale: locale,
        ),
      ),
    );
  }

  Future<OnboardingOption?> _resolveCaste(
    int id,
    int religionId,
    String locale,
  ) {
    return _resolveSelectedOption(
      cacheKey: 'caste:$locale:$religionId:$id',
      id: id,
      loadPage: (page, limit) async => PagedLookupResponse.fromJson(
        await ApiClient.searchCastes(
          religionId: religionId,
          query: '',
          page: page,
          limit: limit,
          locale: locale,
        ),
      ),
    );
  }

  Future<OnboardingOption?> _resolveSubCaste(
    int id,
    int casteId,
    String locale,
  ) {
    return _resolveSelectedOption(
      cacheKey: 'sub_caste:$locale:$casteId:$id',
      id: id,
      loadPage: (page, limit) async => PagedLookupResponse.fromJson(
        await ApiClient.searchSubCastesForOnboarding(
          casteId: casteId,
          query: '',
          page: page,
          limit: limit,
          locale: locale,
        ),
      ),
    );
  }

  Future<OnboardingOption?> _resolveSelectedOption({
    required String cacheKey,
    required int id,
    required Future<PagedLookupResponse> Function(int page, int limit) loadPage,
  }) async {
    final cached = _resolvedOptionCache[cacheKey];
    if (cached != null) return cached;

    const limit = 50;
    try {
      for (var page = 1; page <= 10; page++) {
        final response = await loadPage(page, limit);
        final option = optionById(<OnboardingOption>[
          ...response.popular,
          ...response.results,
        ], id);
        if (option != null) {
          _resolvedOptionCache[cacheKey] = option;
          return option;
        }
        if (!response.hasMore) break;
      }
    } catch (_) {
      return null;
    }

    return null;
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
      if (_religion?.intId != null) 'religion_option': _religion!.toJson(),
      if (_caste?.intId != null) 'caste_option': _caste!.toJson(),
      if (_subCaste?.intId != null) 'sub_caste_option': _subCaste!.toJson(),
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
              : (value) => setState(() => _intercasteAccepted = value ?? false),
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
