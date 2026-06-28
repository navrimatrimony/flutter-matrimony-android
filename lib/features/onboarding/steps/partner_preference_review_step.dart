import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../models/onboarding_status.dart';
import 'onboarding_step_helpers.dart';
import 'onboarding_step_scaffold.dart';

enum PreferenceReviewMode { strict, normal }

enum _PreferenceSection {
  basics,
  community,
  location,
  career,
  lifestyle,
  other,
}

class PartnerPreferenceReviewStep extends StatefulWidget {
  const PartnerPreferenceReviewStep({
    super.key,
    required this.status,
    required this.locale,
    required this.loading,
    required this.onBack,
    required this.onSaved,
  });

  final OnboardingStatus? status;
  final String locale;
  final bool loading;
  final VoidCallback onBack;
  final Future<void> Function() onSaved;

  @override
  State<PartnerPreferenceReviewStep> createState() =>
      _PartnerPreferenceReviewStepState();
}

class _PartnerPreferenceReviewStepState
    extends State<PartnerPreferenceReviewStep> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _message;
  PreferenceReviewMode _mode = PreferenceReviewMode.strict;

  Map<String, dynamic> _saved = <String, dynamic>{};
  Map<String, dynamic> _strict = <String, dynamic>{};
  Map<String, dynamic> _draft = <String, dynamic>{};
  Map<String, List<Map<String, dynamic>>> _options =
      <String, List<Map<String, dynamic>>>{};
  final Map<_PreferenceSection, Map<String, dynamic>> _sectionOverrides =
      <_PreferenceSection, Map<String, dynamic>>{};
  bool _candidateNeverMarried = false;

  bool get _mr => widget.locale == 'mr';

  bool get _busy => widget.loading || _loading || _saving;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _t(String en, String mr) => _mr ? mr : en;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _message = null;
    });

    try {
      final profileResponse = await ApiClient.getMyProfile();
      final profile = profileResponse['profile'] is Map
          ? Map<String, dynamic>.from(profileResponse['profile'] as Map)
          : Map<String, dynamic>.from(ApiClient.currentUserProfile ?? {});

      final preview = await ApiClient.previewAutoPreferenceDraft(
        locale: widget.locale,
      );
      if (preview['success'] != true) {
        throw Exception(
          readableApiError(
            preview,
            _t(
              'Partner preference preview is not ready.',
              'जोडीदार पसंती preview तयार नाही.',
            ),
          ),
        );
      }

      Map<String, List<Map<String, dynamic>>> options =
          <String, List<Map<String, dynamic>>>{};
      try {
        options = await ApiClient.getProfilePartnerPreferenceOptions();
      } catch (_) {
        options = <String, List<Map<String, dynamic>>>{};
      }

      final strict = _cleanPreferenceMap(
        preview['preferences'] is Map
            ? Map<String, dynamic>.from(preview['preferences'] as Map)
            : <String, dynamic>{},
      );

      if (!mounted) return;
      setState(() {
        _saved = _savedPreferencesFromProfile(profile);
        _strict = strict;
        _options = options;
        _candidateNeverMarried = _isNeverMarriedCandidate(profile, options);
        _draft = _baseForMode(_mode);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Map<String, dynamic> _savedPreferencesFromProfile(
    Map<String, dynamic> profile,
  ) {
    return _cleanPreferenceMap(<String, dynamic>{
      'preferred_age_min': profile['preferred_age_min'],
      'preferred_age_max': profile['preferred_age_max'],
      'preferred_height_min_cm': profile['preferred_height_min_cm'],
      'preferred_height_max_cm': profile['preferred_height_max_cm'],
      'preferred_income_min': profile['preferred_income_min'],
      'preferred_income_max': profile['preferred_income_max'],
      'marriage_type_preference_id': profile['marriage_type_preference_id'],
      'partner_profile_with_children': profile['partner_profile_with_children'],
      'preferred_profile_managed_by': profile['preferred_profile_managed_by'],
      'willing_to_relocate': profile['willing_to_relocate'],
      'preferred_intercaste': profile['preferred_intercaste'],
      'preferred_marital_status_ids':
          profile['preferred_marital_status_ids'] ??
          profile['preferred_marital_statuses'],
      'preferred_diet_ids':
          profile['preferred_diet_ids'] ?? profile['preferred_diets'],
      'preferred_religion_ids':
          profile['preferred_religion_ids'] ?? profile['preferred_religions'],
      'preferred_caste_ids':
          profile['preferred_caste_ids'] ?? profile['preferred_castes'],
      'preferred_mother_tongue_ids':
          profile['preferred_mother_tongue_ids'] ??
          profile['preferred_mother_tongues'],
      'preferred_education_degree_ids':
          profile['preferred_education_degree_ids'] ??
          profile['preferred_education_degrees'],
      'preferred_occupation_master_ids':
          profile['preferred_occupation_master_ids'] ??
          profile['preferred_occupations'],
      'preferred_country_ids':
          profile['preferred_country_ids'] ?? profile['preferred_countries'],
      'preferred_state_ids':
          profile['preferred_state_ids'] ?? profile['preferred_states'],
      'preferred_district_ids':
          profile['preferred_district_ids'] ?? profile['preferred_districts'],
      'preferred_taluka_ids':
          profile['preferred_taluka_ids'] ?? profile['preferred_talukas'],
    });
  }

  Map<String, dynamic> _cleanPreferenceMap(
    Map<String, dynamic> source, {
    bool fillMissingLists = true,
  }) {
    final out = <String, dynamic>{};
    for (final key in _preferenceKeys) {
      if (!source.containsKey(key)) continue;
      final value = source[key];
      if (_listKeys.contains(key)) {
        out[key] = _readIntList(value);
      } else if (_intKeys.contains(key)) {
        out[key] = onboardingInt(value);
      } else if (_boolKeys.contains(key)) {
        out[key] = onboardingBool(value);
      } else {
        out[key] = onboardingText(value);
      }
    }

    if (fillMissingLists) {
      for (final key in _listKeys) {
        out.putIfAbsent(key, () => <int>[]);
      }
    }
    return out;
  }

  List<int> _readIntList(dynamic value) {
    final raw = value is List ? value : const <dynamic>[];
    final ids = <int>[];
    for (final item in raw) {
      final id = item is Map
          ? onboardingInt(item['id'] ?? item['value'])
          : onboardingInt(item);
      if (id != null && id > 0 && !ids.contains(id)) ids.add(id);
    }
    return ids;
  }

  bool _isNeverMarriedCandidate(
    Map<String, dynamic> profile,
    Map<String, List<Map<String, dynamic>>> options,
  ) {
    for (final value in [
      profile['marital_status_key'],
      profile['marital_status'],
      profile['marital_status_label'],
    ]) {
      if (_looksNeverMarried(value)) return true;
    }

    final option = profile['marital_status_option'];
    if (option is Map && _optionLooksNeverMarried(option)) {
      return true;
    }

    final maritalStatusId = onboardingInt(profile['marital_status_id']);
    if (maritalStatusId == null) return false;
    for (final row
        in options['marital_statuses'] ?? const <Map<String, dynamic>>[]) {
      if (onboardingInt(row['id']) == maritalStatusId) {
        return _optionLooksNeverMarried(row);
      }
    }
    return false;
  }

  bool _optionLooksNeverMarried(Map<dynamic, dynamic> row) {
    for (final key in [
      'key',
      'value',
      'slug',
      'label',
      'label_en',
      'label_mr',
      'name',
      'display_label',
    ]) {
      if (_looksNeverMarried(row[key])) return true;
    }
    return false;
  }

  bool _looksNeverMarried(dynamic value) {
    final text = onboardingText(value)?.toLowerCase();
    if (text == null) return false;
    final compact = text.replaceAll(RegExp(r'[\s_-]+'), '');
    return compact == 'nevermarried' ||
        compact == 'unmarried' ||
        compact == 'single' ||
        text.contains('अविवाहित') ||
        text.contains('अविवाहीत');
  }

  Map<String, dynamic> _baseForMode(PreferenceReviewMode mode) {
    final base = Map<String, dynamic>.from(
      mode == PreferenceReviewMode.strict ? _strict : _normalFromStrict(),
    );
    base.putIfAbsent(
      'preferred_intercaste',
      () => mode == PreferenceReviewMode.normal ? true : false,
    );
    for (final override in _sectionOverrides.values) {
      base.addAll(override);
    }
    return _cleanPreferenceMap(base);
  }

  Map<String, dynamic> _normalFromStrict() {
    final normal = Map<String, dynamic>.from(_strict);
    final ageMin = onboardingInt(normal['preferred_age_min']);
    final ageMax = onboardingInt(normal['preferred_age_max']);
    if (ageMin != null) {
      normal['preferred_age_min'] = (ageMin - 2).clamp(18, 80);
    }
    if (ageMax != null) {
      normal['preferred_age_max'] = (ageMax + 2).clamp(18, 80);
    }

    final heightMin = onboardingInt(normal['preferred_height_min_cm']);
    final heightMax = onboardingInt(normal['preferred_height_max_cm']);
    if (heightMin != null) {
      normal['preferred_height_min_cm'] = (heightMin - 5).clamp(120, 220);
    }
    if (heightMax != null) {
      normal['preferred_height_max_cm'] = (heightMax + 5).clamp(120, 220);
    }

    final incomeMin = onboardingInt(normal['preferred_income_min']);
    final incomeMax = onboardingInt(normal['preferred_income_max']);
    if (incomeMin != null) {
      normal['preferred_income_min'] = (incomeMin * 0.6).round();
    }
    if (incomeMax != null) {
      normal['preferred_income_max'] = (incomeMax * 1.25).round();
    }

    normal['preferred_caste_ids'] = <int>[];
    normal['preferred_intercaste'] = true;
    normal['preferred_mother_tongue_ids'] = <int>[];
    normal['preferred_education_degree_ids'] = <int>[];
    normal['preferred_occupation_master_ids'] = <int>[];
    normal['preferred_diet_ids'] = <int>[];
    normal['preferred_taluka_ids'] = <int>[];
    return normal;
  }

  void _setMode(PreferenceReviewMode mode) {
    setState(() {
      _mode = mode;
      _draft = _baseForMode(mode);
      _message = mode == PreferenceReviewMode.normal
          ? _t(
              'Normal mode selected. Some preferences are wider for more matches.',
              'Normal mode निवडला. जास्त matches साठी काही पसंती wide केली आहे.',
            )
          : _t(
              'Strict mode selected. Preferences are focused from your profile.',
              'Strict mode निवडला. पसंती तुमच्या प्रोफाइलनुसार focused आहे.',
            );
    });
  }

  Future<void> _editSection(_PreferenceSection section) async {
    final edited = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return _PreferenceSectionEditor(
          section: section,
          draft: _draft,
          strict: _strict,
          options: _options,
          locale: widget.locale,
          hideChildrenPreference: _candidateNeverMarried,
        );
      },
    );
    if (edited == null) return;

    setState(() {
      _sectionOverrides[section] = _cleanPreferenceMap(
        edited,
        fillMissingLists: false,
      );
      _draft = _baseForMode(_mode);
      _message = _t('Section updated.', 'Section update झाले.');
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
      _message = null;
    });

    try {
      final response = await ApiClient.updateMatrimonyProfile(
        _payloadFromDraft(_draft),
      );
      if (!mounted) return;
      if (response['success'] != true) {
        setState(() {
          _saving = false;
          _error = readableApiError(
            response,
            _t(
              'Partner preference save failed.',
              'जोडीदार पसंती save झाली नाही.',
            ),
          );
        });
        return;
      }
      setState(() => _saving = false);
      await widget.onSaved();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _t(
          'Partner preference save करताना problem आला.',
          'Partner preference save करताना problem आला.',
        );
      });
    }
  }

  Map<String, dynamic> _payloadFromDraft(Map<String, dynamic> draft) {
    final payload = <String, dynamic>{};
    for (final key in _preferenceKeys) {
      if (!_supportedSaveKeys.contains(key)) continue;
      if (_candidateNeverMarried && key == 'partner_profile_with_children') {
        payload[key] = null;
      } else if (_listKeys.contains(key)) {
        payload[key] = _readIntList(draft[key]);
      } else {
        payload[key] = draft[key];
      }
    }
    return payload;
  }

  int get _changedCount {
    var count = 0;
    for (final field in _visibleFields) {
      if (_hasSavedValue(field.key) &&
          !_sameValue(_saved[field.key], _draft[field.key])) {
        count++;
      }
    }
    return count;
  }

  bool _hasSavedValue(String key) {
    final value = _saved[key];
    if (value is List) return value.isNotEmpty;
    return value != null && value.toString().trim().isNotEmpty;
  }

  bool _sameValue(dynamic first, dynamic second) {
    if (first is List || second is List) {
      final a = _readIntList(first)..sort();
      final b = _readIntList(second)..sort();
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (a[i] != b[i]) return false;
      }
      return true;
    }
    return (first ?? '').toString() == (second ?? '').toString();
  }

  @override
  Widget build(BuildContext context) {
    final changes = _changedCount;
    return OnboardingStepScaffold(
      title: _t('Partner Preference', 'जोडीदार पसंती'),
      subtitle: _t(
        'Review the preference prepared from your profile. You can widen it for more matches.',
        'तुमच्या माहितीवरून तयार केलेली पसंती तपासा. जास्त matches साठी ती wide करू शकता.',
      ),
      loading: _busy,
      onBack: widget.onBack,
      onContinue: _save,
      continueEnabled: !_loading && _error == null,
      continueLabel: _mode == PreferenceReviewMode.normal
          ? _t(
              'Save normal preference and finish setup',
              'Normal पसंती save करून setup पूर्ण करा',
            )
          : _t(
              'Save strict preference and finish setup',
              'Strict पसंती save करून setup पूर्ण करा',
            ),
      secondary: TextButton.icon(
        onPressed: _busy ? null : _load,
        icon: const Icon(Icons.refresh),
        label: Text(_t('Refresh preference', 'Preference refresh करा')),
      ),
      children: [
        _noticePanel(context, changes),
        if (_error != null) ...[
          const SizedBox(height: 12),
          _feedbackPanel(context, _error!, Colors.red.shade700),
        ] else if (_message != null) ...[
          const SizedBox(height: 12),
          _feedbackPanel(context, _message!, Colors.green.shade700),
        ],
        const SizedBox(height: 14),
        _modeSelector(context),
        const SizedBox(height: 14),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else
          ..._PreferenceSection.values.map(_sectionCard),
      ],
    );
  }

  Widget _noticePanel(BuildContext context, int changes) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.notifications_active_outlined, color: colors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                changes > 0
                    ? _t(
                        '$changes saved values differ from this preference. Old and new values are highlighted below.',
                        '$changes आधीच्या values या preference पेक्षा वेगळ्या आहेत. खाली आधीची आणि नवीन value वेगळ्या रंगात दाखवली आहे.',
                      )
                    : _t(
                        'This preference is based on the information you filled. You can edit any section now or change it later.',
                        'तुम्ही भरलेल्या माहितीनुसार ही partner preference दाखवत आहोत. हवे असल्यास section edit करू शकता किंवा नंतर बदलू शकता.',
                      ),
                style: TextStyle(color: colors.onSurfaceVariant, height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _feedbackPanel(BuildContext context, String text, Color color) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Text(text, style: TextStyle(color: color, height: 1.3)),
      ),
    );
  }

  Widget _modeSelector(BuildContext context) {
    return SegmentedButton<PreferenceReviewMode>(
      segments: [
        ButtonSegment(
          value: PreferenceReviewMode.strict,
          icon: const Icon(Icons.center_focus_strong_outlined),
          label: Text(_t('Strict', 'Strict')),
        ),
        ButtonSegment(
          value: PreferenceReviewMode.normal,
          icon: const Icon(Icons.open_in_full_outlined),
          label: Text(_t('Normal', 'Normal')),
        ),
      ],
      selected: {_mode},
      onSelectionChanged: _busy
          ? null
          : (selection) => _setMode(selection.first),
    );
  }

  Widget _sectionCard(_PreferenceSection section) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final rows = _visibleFields
        .where((field) => field.section == section)
        .toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(_sectionIcon(section), color: colors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _sectionTitle(section),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _busy ? null : () => _editSection(section),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: Text(_t('Edit', 'Edit')),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final field in rows) _preferenceRow(field),
            ],
          ),
        ),
      ),
    );
  }

  Widget _preferenceRow(_PreferenceField field) {
    final changed =
        _hasSavedValue(field.key) &&
        !_sameValue(_saved[field.key], _draft[field.key]);
    final current = _displayValue(field.key, _draft);
    final saved = _displayValue(field.key, _saved);
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              field.label(_mr),
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: changed
                ? Wrap(
                    runSpacing: 6,
                    spacing: 6,
                    children: [
                      _valueChip(
                        _t('Before', 'आधी'),
                        saved,
                        Colors.amber.shade800,
                      ),
                      _valueChip(
                        _t('New', 'नवीन'),
                        current,
                        Colors.green.shade700,
                      ),
                    ],
                  )
                : Text(
                    current,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
          ),
        ],
      ),
    );
  }

  Iterable<_PreferenceField> get _visibleFields {
    return _fields.where((field) {
      return !_hidePreferenceField(field.key);
    });
  }

  bool _hidePreferenceField(String key) {
    return _candidateNeverMarried && key == 'partner_profile_with_children';
  }

  Widget _valueChip(String label, String value, Color color) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(
          '$label: $value',
          style: TextStyle(color: color, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  String _displayValue(String key, Map<String, dynamic> source) {
    switch (key) {
      case 'preferred_age_min':
        return _rangeLabel(
          source['preferred_age_min'],
          source['preferred_age_max'],
          suffix: _t(' years', ' वर्षे'),
        );
      case 'preferred_height_min_cm':
        return _heightRangeLabel(
          onboardingInt(source['preferred_height_min_cm']),
          onboardingInt(source['preferred_height_max_cm']),
        );
      case 'preferred_income_min':
        return _incomeRangeLabel(
          onboardingInt(source['preferred_income_min']),
          onboardingInt(source['preferred_income_max']),
        );
      case 'marriage_type_preference_id':
        return _singleOptionLabel(
          'marriage_type_preferences',
          source['marriage_type_preference_id'],
        );
      case 'partner_profile_with_children':
        return _childrenPreferenceLabel(onboardingText(source[key]));
      case 'preferred_profile_managed_by':
        return _singleOptionLabel('preferred_profile_managed_by', source[key]);
      case 'preferred_intercaste':
        final value = onboardingBool(source[key]);
        if (value == true) return _t('Yes', 'होय');
        return _t('No', 'नाही');
      case 'willing_to_relocate':
        final value = onboardingBool(source[key]);
        if (value == true) return _t('Yes', 'होय');
        return _openLabel;
      case 'preferred_marital_status_ids':
        return _multiOptionLabel('marital_statuses', source[key]);
      case 'preferred_diet_ids':
        return _multiOptionLabel('diets', source[key]);
      case 'preferred_religion_ids':
        return _multiOptionLabel('religions', source[key]);
      case 'preferred_caste_ids':
        return _multiOptionLabel('castes', source[key]);
      case 'preferred_mother_tongue_ids':
        return _multiOptionLabel('mother_tongues', source[key]);
      case 'preferred_education_degree_ids':
        return _multiOptionLabel('education_degrees', source[key]);
      case 'preferred_occupation_master_ids':
        return _multiOptionLabel('occupations', source[key]);
      case 'preferred_country_ids':
        return _locationSummary(source);
    }
    return _openLabel;
  }

  String get _openLabel => _t('Open', 'Open');

  String _rangeLabel(dynamic min, dynamic max, {String suffix = ''}) {
    final minValue = onboardingInt(min);
    final maxValue = onboardingInt(max);
    if (minValue == null && maxValue == null) return _openLabel;
    if (minValue != null && maxValue != null) {
      return '$minValue - $maxValue$suffix';
    }
    if (minValue != null) return '$minValue+$suffix';
    return _t('Up to $maxValue$suffix', '$maxValue$suffix पर्यंत');
  }

  String _heightRangeLabel(int? min, int? max) {
    if (min == null && max == null) return _openLabel;
    if (min != null && max != null) {
      return '${_heightLabel(min)} - ${_heightLabel(max)}';
    }
    if (min != null) return '${_heightLabel(min)}+';
    final maxValue = max;
    if (maxValue == null) return _openLabel;
    return _t(
      'Up to ${_heightLabel(maxValue)}',
      '${_heightLabel(maxValue)} पर्यंत',
    );
  }

  String _heightLabel(int cm) {
    final totalInches = (cm / 2.54).round();
    final feet = totalInches ~/ 12;
    final inches = totalInches % 12;
    return '$feet\'$inches"';
  }

  String _incomeRangeLabel(int? min, int? max) {
    if (min == null && max == null) return _openLabel;
    final minText = min == null ? null : _moneyLabel(min);
    final maxText = max == null ? null : _moneyLabel(max);
    if (minText != null && maxText != null) return '$minText - $maxText';
    if (minText != null) return '$minText+';
    return _t('Up to $maxText', '$maxText पर्यंत');
  }

  String _moneyLabel(int value) {
    if (value >= 100000) {
      final lakhs = value / 100000;
      final text = lakhs == lakhs.roundToDouble()
          ? lakhs.toStringAsFixed(0)
          : lakhs.toStringAsFixed(1);
      return _t('Rs $text L', '$text लाख');
    }
    return _t('Rs $value', 'Rs $value');
  }

  String _singleOptionLabel(String optionKey, dynamic idOrKey) {
    final text = onboardingText(idOrKey);
    if (text == null) return _openLabel;
    final intId = onboardingInt(idOrKey);
    for (final row in _options[optionKey] ?? const <Map<String, dynamic>>[]) {
      if (intId != null && onboardingInt(row['id']) == intId) {
        return _optionLabel(row);
      }
      final rowKey = onboardingText(row['key'] ?? row['value']);
      if (rowKey != null && rowKey == text) return _optionLabel(row);
    }
    return text;
  }

  String _multiOptionLabel(String optionKey, dynamic value) {
    final ids = _readIntList(value);
    if (ids.isEmpty) return _openLabel;
    final labels = <String>[];
    for (final id in ids) {
      final label = _singleOptionLabel(optionKey, id);
      if (label != _openLabel) labels.add(label);
    }
    if (labels.isEmpty) {
      return _t('${ids.length} selected', '${ids.length} निवडले');
    }
    if (labels.length <= 2) return labels.join(', ');
    return '${labels.take(2).join(', ')} +${labels.length - 2}';
  }

  String _locationSummary(Map<String, dynamic> source) {
    final talukas = _readIntList(source['preferred_taluka_ids']);
    final districts = _readIntList(source['preferred_district_ids']);
    final states = _readIntList(source['preferred_state_ids']);
    final countries = _readIntList(source['preferred_country_ids']);
    if (talukas.isNotEmpty) {
      return _t(
        '${talukas.length} nearby taluka',
        '${talukas.length} nearby taluka',
      );
    }
    if (districts.isNotEmpty) {
      return _t('${districts.length} district', '${districts.length} district');
    }
    if (states.isNotEmpty) {
      return _t('${states.length} state', '${states.length} state');
    }
    if (countries.isNotEmpty) {
      return _t('${countries.length} country', '${countries.length} country');
    }
    return _openLabel;
  }

  String _childrenPreferenceLabel(String? value) {
    return switch (value) {
      'no' => _t('No children', 'मुले नसलेली profile'),
      'yes_if_live_separate' => _t(
        'Accepted if children live separately',
        'मुले वेगळी राहत असतील तर चालेल',
      ),
      'yes' => _t('Accepted', 'चालेल'),
      _ => _openLabel,
    };
  }

  String _optionLabel(Map<String, dynamic> row) {
    final localized = _localizedMapValue(row, _mr);
    if (localized != null) return localized;
    for (final key in ['label', 'label_en', 'name', 'display_label', 'key']) {
      final text = onboardingText(row[key]);
      if (text != null) return text;
    }
    return _openLabel;
  }

  String _sectionTitle(_PreferenceSection section) {
    return switch (section) {
      _PreferenceSection.basics => _t('Basics', 'Basic'),
      _PreferenceSection.community => _t('Community', 'समुदाय'),
      _PreferenceSection.location => _t('Location', 'ठिकाण'),
      _PreferenceSection.career => _t('Education & Career', 'शिक्षण आणि करिअर'),
      _PreferenceSection.lifestyle => _t('Lifestyle', 'Lifestyle'),
      _PreferenceSection.other => _t('Other', 'इतर'),
    };
  }

  IconData _sectionIcon(_PreferenceSection section) {
    return switch (section) {
      _PreferenceSection.basics => Icons.tune_outlined,
      _PreferenceSection.community => Icons.groups_2_outlined,
      _PreferenceSection.location => Icons.location_on_outlined,
      _PreferenceSection.career => Icons.school_outlined,
      _PreferenceSection.lifestyle => Icons.restaurant_outlined,
      _PreferenceSection.other => Icons.more_horiz_outlined,
    };
  }
}

class _PreferenceSectionEditor extends StatefulWidget {
  const _PreferenceSectionEditor({
    required this.section,
    required this.draft,
    required this.strict,
    required this.options,
    required this.locale,
    required this.hideChildrenPreference,
  });

  final _PreferenceSection section;
  final Map<String, dynamic> draft;
  final Map<String, dynamic> strict;
  final Map<String, List<Map<String, dynamic>>> options;
  final String locale;
  final bool hideChildrenPreference;

  @override
  State<_PreferenceSectionEditor> createState() =>
      _PreferenceSectionEditorState();
}

class _PreferenceSectionEditorState extends State<_PreferenceSectionEditor> {
  late Map<String, dynamic> _values;
  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};

  bool get _mr => widget.locale == 'mr';

  @override
  void initState() {
    super.initState();
    _values = Map<String, dynamic>.from(widget.draft);
    for (final key in [
      'preferred_age_min',
      'preferred_age_max',
      'preferred_height_min_cm',
      'preferred_height_max_cm',
      'preferred_income_min',
      'preferred_income_max',
    ]) {
      _controllers[key] = TextEditingController(
        text: onboardingText(_values[key]) ?? '',
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _t(String en, String mr) => _mr ? mr : en;

  void _syncNumericFields() {
    for (final entry in _controllers.entries) {
      _values[entry.key] = onboardingInt(entry.value.text);
    }
  }

  void _save() {
    _syncNumericFields();
    Navigator.pop(
      context,
      _sectionSubset(
        widget.section,
        _values,
        hideChildrenPreference: widget.hideChildrenPreference,
      ),
    );
  }

  void _toggleId(String key, int id) {
    final ids = _readIntList(_values[key]);
    setState(() {
      if (ids.contains(id)) {
        ids.remove(id);
      } else {
        ids.add(id);
      }
      _values[key] = ids;
    });
  }

  void _setSingle(String key, dynamic value) {
    setState(() => _values[key] = value);
  }

  List<int> _readIntList(dynamic value) {
    final raw = value is List ? value : const <dynamic>[];
    return raw
        .map(onboardingInt)
        .whereType<int>()
        .where((id) => id > 0)
        .toSet()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _sectionTitle(widget.section),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ..._editorFields(widget.section),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: Text(_t('Save section', 'Section save करा')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _editorFields(_PreferenceSection section) {
    return switch (section) {
      _PreferenceSection.basics => [
        _numberPair(
          'preferred_age_min',
          'preferred_age_max',
          _t('Age range', 'वय range'),
        ),
        _numberPair(
          'preferred_height_min_cm',
          'preferred_height_max_cm',
          _t('Height range cm', 'उंची range cm'),
        ),
        _choiceWrap(
          'preferred_marital_status_ids',
          'marital_statuses',
          _t('Marital status', 'वैवाहिक स्थिती'),
        ),
        if (!widget.hideChildrenPreference) _childrenChoices(),
      ],
      _PreferenceSection.community => [
        _choiceWrap(
          'preferred_religion_ids',
          'religions',
          _t('Religion', 'धर्म'),
        ),
        _choiceWrap('preferred_caste_ids', 'castes', _t('Caste', 'जात')),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(_t('Open to intercaste', 'आंतरजातीय चालेल')),
          value: onboardingBool(_values['preferred_intercaste']) == true,
          onChanged: (value) =>
              setState(() => _values['preferred_intercaste'] = value),
        ),
        _choiceWrap(
          'preferred_mother_tongue_ids',
          'mother_tongues',
          _t('Mother tongue', 'मातृभाषा'),
        ),
      ],
      _PreferenceSection.location => [_locationChoices()],
      _PreferenceSection.career => [
        _choiceWrap(
          'preferred_education_degree_ids',
          'education_degrees',
          _t('Education', 'शिक्षण'),
        ),
        _choiceWrap(
          'preferred_occupation_master_ids',
          'occupations',
          _t('Occupation', 'व्यवसाय'),
        ),
        _numberPair(
          'preferred_income_min',
          'preferred_income_max',
          _t('Income range', 'उत्पन्न range'),
        ),
      ],
      _PreferenceSection.lifestyle => [
        _choiceWrap('preferred_diet_ids', 'diets', _t('Diet', 'आहार')),
      ],
      _PreferenceSection.other => [
        _singleChoice(
          'marriage_type_preference_id',
          'marriage_type_preferences',
          _t('Marriage type', 'विवाह प्रकार'),
        ),
        _singleChoice(
          'preferred_profile_managed_by',
          'preferred_profile_managed_by',
          _t('Profile managed by', 'Profile कोणाद्वारे'),
          byKey: true,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(_t('Willing to relocate', 'स्थलांतर चालेल')),
          value: onboardingBool(_values['willing_to_relocate']) == true,
          onChanged: (value) => setState(
            () => _values['willing_to_relocate'] = value ? true : null,
          ),
        ),
      ],
    };
  }

  Widget _numberPair(String minKey, String maxKey, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controllers[minKey],
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: _t('Min', 'Min')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _controllers[maxKey],
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: _t('Max', 'Max')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _choiceWrap(String key, String optionsKey, String label) {
    final options =
        (widget.options[optionsKey] ?? const <Map<String, dynamic>>[])
            .take(18)
            .toList();
    final selected = _readIntList(_values[key]);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (options.isEmpty)
            Text(_t('Options not loaded.', 'Options load झाले नाहीत.'))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.clear, size: 16),
                  label: Text(_t('Open', 'Open')),
                  onPressed: () => setState(() => _values[key] = <int>[]),
                ),
                for (final option in options)
                  FilterChip(
                    label: Text(_optionLabel(option)),
                    selected: selected.contains(onboardingInt(option['id'])),
                    onSelected: (_) {
                      final id = onboardingInt(option['id']);
                      if (id != null) _toggleId(key, id);
                    },
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _singleChoice(
    String key,
    String optionsKey,
    String label, {
    bool byKey = false,
  }) {
    final options =
        widget.options[optionsKey] ?? const <Map<String, dynamic>>[];
    final current = onboardingText(_values[key]);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text(_t('Open', 'Open')),
                selected: current == null,
                onSelected: (_) => _setSingle(key, null),
              ),
              for (final option in options.take(12))
                ChoiceChip(
                  label: Text(_optionLabel(option)),
                  selected:
                      current ==
                      (byKey
                          ? onboardingText(option['key'] ?? option['value'])
                          : onboardingText(option['id'])),
                  onSelected: (_) => _setSingle(
                    key,
                    byKey
                        ? onboardingText(option['key'] ?? option['value'])
                        : onboardingInt(option['id']),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _childrenChoices() {
    final current = onboardingText(_values['partner_profile_with_children']);
    final rows = [
      ['no', _t('No children', 'मुले नसलेली profile')],
      [
        'yes_if_live_separate',
        _t('Children separate', 'मुले वेगळी राहत असतील तर'),
      ],
      ['yes', _t('Accepted', 'चालेल')],
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t('Partner profile with children', 'मुले असलेली profile'),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text(_t('Open', 'Open')),
                selected: current == null,
                onSelected: (_) =>
                    _setSingle('partner_profile_with_children', null),
              ),
              for (final row in rows)
                ChoiceChip(
                  label: Text(row[1]),
                  selected: current == row[0],
                  onSelected: (_) =>
                      _setSingle('partner_profile_with_children', row[0]),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _locationChoices() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t('Location preference', 'ठिकाण पसंती'),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            _t(
              'Use nearby keeps backend suggested country/state/district. Open removes location filters.',
              'Nearby मध्ये backend suggested country/state/district राहते. Open केल्यास location filter काढला जाईल.',
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.restore, size: 16),
                label: Text(_t('Use nearby', 'Nearby वापरा')),
                onPressed: () {
                  setState(() {
                    for (final key in _locationKeys) {
                      _values[key] = widget.strict[key] ?? <int>[];
                    }
                  });
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.public, size: 16),
                label: Text(_t('Open location', 'Location open ठेवा')),
                onPressed: () {
                  setState(() {
                    for (final key in _locationKeys) {
                      _values[key] = <int>[];
                    }
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _sectionTitle(_PreferenceSection section) {
    return switch (section) {
      _PreferenceSection.basics => _t('Basics', 'Basic'),
      _PreferenceSection.community => _t('Community', 'समुदाय'),
      _PreferenceSection.location => _t('Location', 'ठिकाण'),
      _PreferenceSection.career => _t('Education & Career', 'शिक्षण आणि करिअर'),
      _PreferenceSection.lifestyle => _t('Lifestyle', 'Lifestyle'),
      _PreferenceSection.other => _t('Other', 'इतर'),
    };
  }

  String _optionLabel(Map<String, dynamic> row) {
    final localized = _localizedMapValue(row, _mr);
    if (localized != null) return localized;
    for (final key in ['label', 'label_en', 'name', 'display_label', 'key']) {
      final text = onboardingText(row[key]);
      if (text != null) return text;
    }
    return 'Option';
  }
}

class _PreferenceField {
  const _PreferenceField(this.key, this.section, this.en, this.mr);

  final String key;
  final _PreferenceSection section;
  final String en;
  final String mr;

  String label(bool isMr) => isMr ? mr : en;
}

Map<String, dynamic> _sectionSubset(
  _PreferenceSection section,
  Map<String, dynamic> source, {
  required bool hideChildrenPreference,
}) {
  final keys = _fields
      .where((field) => field.section == section)
      .map((field) => field.key)
      .toSet();
  if (section == _PreferenceSection.basics) {
    keys
      ..add('preferred_age_max')
      ..add('preferred_height_max_cm');
    if (!hideChildrenPreference) {
      keys.add('partner_profile_with_children');
    } else {
      keys.remove('partner_profile_with_children');
    }
  }
  if (section == _PreferenceSection.career) {
    keys.add('preferred_income_max');
  }
  if (section == _PreferenceSection.location) {
    keys.addAll(_locationKeys);
  }

  return {
    for (final key in keys)
      if (source.containsKey(key)) key: source[key],
  };
}

const _fields = <_PreferenceField>[
  _PreferenceField('preferred_age_min', _PreferenceSection.basics, 'Age', 'वय'),
  _PreferenceField(
    'preferred_height_min_cm',
    _PreferenceSection.basics,
    'Height',
    'उंची',
  ),
  _PreferenceField(
    'preferred_marital_status_ids',
    _PreferenceSection.basics,
    'Marital',
    'वैवाहिक',
  ),
  _PreferenceField(
    'partner_profile_with_children',
    _PreferenceSection.basics,
    'Children',
    'मुले',
  ),
  _PreferenceField(
    'preferred_religion_ids',
    _PreferenceSection.community,
    'Religion',
    'धर्म',
  ),
  _PreferenceField(
    'preferred_caste_ids',
    _PreferenceSection.community,
    'Caste',
    'जात',
  ),
  _PreferenceField(
    'preferred_intercaste',
    _PreferenceSection.community,
    'Intercaste',
    'आंतरजातीय',
  ),
  _PreferenceField(
    'preferred_mother_tongue_ids',
    _PreferenceSection.community,
    'Language',
    'भाषा',
  ),
  _PreferenceField(
    'preferred_country_ids',
    _PreferenceSection.location,
    'Area',
    'ठिकाण',
  ),
  _PreferenceField(
    'preferred_education_degree_ids',
    _PreferenceSection.career,
    'Education',
    'शिक्षण',
  ),
  _PreferenceField(
    'preferred_occupation_master_ids',
    _PreferenceSection.career,
    'Occupation',
    'व्यवसाय',
  ),
  _PreferenceField(
    'preferred_income_min',
    _PreferenceSection.career,
    'Income',
    'उत्पन्न',
  ),
  _PreferenceField(
    'preferred_diet_ids',
    _PreferenceSection.lifestyle,
    'Diet',
    'आहार',
  ),
  _PreferenceField(
    'marriage_type_preference_id',
    _PreferenceSection.other,
    'Marriage',
    'विवाह',
  ),
  _PreferenceField(
    'preferred_profile_managed_by',
    _PreferenceSection.other,
    'Managed by',
    'कोणाद्वारे',
  ),
  _PreferenceField(
    'willing_to_relocate',
    _PreferenceSection.other,
    'Relocate',
    'स्थलांतर',
  ),
];

const _preferenceKeys = <String>[
  'preferred_age_min',
  'preferred_age_max',
  'preferred_height_min_cm',
  'preferred_height_max_cm',
  'preferred_income_min',
  'preferred_income_max',
  'marriage_type_preference_id',
  'partner_profile_with_children',
  'preferred_profile_managed_by',
  'willing_to_relocate',
  'preferred_intercaste',
  'preferred_marital_status_ids',
  'preferred_diet_ids',
  'preferred_religion_ids',
  'preferred_caste_ids',
  'preferred_mother_tongue_ids',
  'preferred_education_degree_ids',
  'preferred_occupation_master_ids',
  'preferred_country_ids',
  'preferred_state_ids',
  'preferred_district_ids',
  'preferred_taluka_ids',
];

const _supportedSaveKeys = <String>{
  'preferred_age_min',
  'preferred_age_max',
  'preferred_height_min_cm',
  'preferred_height_max_cm',
  'preferred_income_min',
  'preferred_income_max',
  'marriage_type_preference_id',
  'partner_profile_with_children',
  'preferred_profile_managed_by',
  'willing_to_relocate',
  'preferred_intercaste',
  'preferred_marital_status_ids',
  'preferred_diet_ids',
  'preferred_religion_ids',
  'preferred_caste_ids',
  'preferred_mother_tongue_ids',
  'preferred_education_degree_ids',
  'preferred_occupation_master_ids',
  'preferred_country_ids',
  'preferred_state_ids',
  'preferred_district_ids',
  'preferred_taluka_ids',
};

const _listKeys = <String>{
  'preferred_marital_status_ids',
  'preferred_diet_ids',
  'preferred_religion_ids',
  'preferred_caste_ids',
  'preferred_mother_tongue_ids',
  'preferred_education_degree_ids',
  'preferred_occupation_master_ids',
  'preferred_country_ids',
  'preferred_state_ids',
  'preferred_district_ids',
  'preferred_taluka_ids',
};

const _locationKeys = <String>[
  'preferred_country_ids',
  'preferred_state_ids',
  'preferred_district_ids',
  'preferred_taluka_ids',
];

const _intKeys = <String>{
  'preferred_age_min',
  'preferred_age_max',
  'preferred_height_min_cm',
  'preferred_height_max_cm',
  'preferred_income_min',
  'preferred_income_max',
  'marriage_type_preference_id',
};

const _boolKeys = <String>{'willing_to_relocate', 'preferred_intercaste'};

String? _localizedMapValue(Map<String, dynamic> row, bool isMr) {
  final keys = isMr
      ? const ['label_mr', 'name_mr', 'display_label_mr', 'mr_label']
      : const ['label_en', 'name_en', 'display_label_en', 'en_label'];
  for (final key in keys) {
    final text = onboardingText(row[key]);
    if (text != null) return text;
  }
  return null;
}
