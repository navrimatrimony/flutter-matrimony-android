import 'package:flutter/material.dart';

import '../models/onboarding_bootstrap.dart';
import '../models/onboarding_option.dart';
import '../models/paged_lookup_response.dart';
import '../widgets/onboarding_picker_field.dart';
import 'onboarding_step_helpers.dart';
import 'onboarding_step_scaffold.dart';

class BasicCandidateInfoStep extends StatefulWidget {
  const BasicCandidateInfoStep({
    super.key,
    required this.data,
    required this.bootstrap,
    required this.account,
    required this.profileForWhom,
    required this.warmupGender,
    required this.locale,
    required this.loading,
    required this.onSave,
    required this.onBack,
    required this.onMessage,
  });

  final Map<String, dynamic> data;
  final OnboardingBootstrap bootstrap;
  final Map<String, dynamic> account;
  final OnboardingOption? profileForWhom;
  final OnboardingOption? warmupGender;
  final String locale;
  final bool loading;
  final OnboardingStepSaver onSave;
  final VoidCallback onBack;
  final ValueChanged<String> onMessage;

  @override
  State<BasicCandidateInfoStep> createState() => _BasicCandidateInfoStepState();
}

class _BasicCandidateInfoStepState extends State<BasicCandidateInfoStep> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _childrenCountController =
      TextEditingController();
  final TextEditingController _childrenLivingWithController =
      TextEditingController();

  OnboardingOption? _gender;
  OnboardingOption? _height;
  OnboardingOption? _maritalStatus;
  bool _hasChildren = false;
  int _page = 0;

  bool get _mr => widget.locale == 'mr';

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  @override
  void didUpdateWidget(covariant BasicCandidateInfoStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data ||
        oldWidget.bootstrap != widget.bootstrap ||
        oldWidget.profileForWhom?.identity != widget.profileForWhom?.identity ||
        oldWidget.warmupGender?.identity != widget.warmupGender?.identity) {
      _prefill();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    _childrenCountController.dispose();
    _childrenLivingWithController.dispose();
    super.dispose();
  }

  void _prefill() {
    final data = widget.data;
    _nameController.text = onboardingText(data['full_name']) ?? '';
    _dobController.text = onboardingText(data['date_of_birth']) ?? '';
    _childrenCountController.text =
        onboardingText(data['children_count']) ?? '';
    _childrenLivingWithController.text =
        onboardingText(data['children_living_with']) ?? '';
    _hasChildren = onboardingBool(data['has_children']) ?? false;

    _gender =
        optionFromData(data['gender_option']) ??
        optionById(widget.bootstrap.genders, data['gender_id']);
    _height =
        optionFromData(data['height_option']) ??
        optionById(widget.bootstrap.heightOptions, data['height_cm']);
    _maritalStatus =
        optionFromData(data['marital_status_option']) ??
        optionById(widget.bootstrap.maritalStatuses, data['marital_status_id']);
    _gender ??= _warmupGenderOption();

    final lockedGender = _lockedGenderOption();
    if (lockedGender != null) {
      _gender = lockedGender;
    }
    if (_isNeverMarried) {
      _hasChildren = false;
      _childrenCountController.clear();
      _childrenLivingWithController.clear();
    }
  }

  String _t(String en, String mr) => _mr ? mr : en;

  String? get _creatorName =>
      onboardingText(widget.account['creator_name'] ?? widget.account['name']);

  String? get _genderMode =>
      widget.profileForWhom?.metaText('gender_mode') ??
      widget.profileForWhom?.raw['gender_mode']?.toString();

  bool get _genderLocked => _lockedGenderOption() != null;

  OnboardingOption? _warmupGenderOption() {
    final warmup = widget.warmupGender;
    if (warmup == null) return null;
    final byId = optionById(widget.bootstrap.genders, warmup.id);
    if (byId != null) return byId;
    final byKey = optionByKey(widget.bootstrap.genders, warmup.key);
    if (byKey != null) return byKey;

    final wanted = warmup.label.toLowerCase();
    for (final option in widget.bootstrap.genders) {
      final label = option.label.toLowerCase();
      if (label == wanted) return option;
      if (wanted.contains('female') && label.contains('female')) return option;
      if (!wanted.contains('female') &&
          wanted.contains('male') &&
          label.contains('male') &&
          !label.contains('female')) {
        return option;
      }
    }

    return warmup;
  }

  OnboardingOption? _lockedGenderOption() {
    final mode = _genderMode;
    if (mode != 'male' && mode != 'female') return null;
    final lockedMode = mode!;
    final keyed = optionByKey(widget.bootstrap.genders, lockedMode);
    if (keyed != null) return keyed;

    for (final option in widget.bootstrap.genders) {
      final label = option.label.toLowerCase();
      if (label == lockedMode) return option;
      if (lockedMode == 'female' && label.contains('female')) return option;
      if (lockedMode == 'male' &&
          label.contains('male') &&
          !label.contains('female')) {
        return option;
      }
    }
    return null;
  }

  bool get _isFemaleProfile {
    final mode = _genderMode;
    if (mode == 'female') return true;
    final text = '${_gender?.key ?? ''} ${_gender?.label ?? ''}'.toLowerCase();
    return text.contains('female') ||
        text.contains('bride') ||
        text.contains('स्त्री') ||
        text.contains('वधू');
  }

  bool get _isMaleProfile {
    final mode = _genderMode;
    if (mode == 'male') return true;
    final text = '${_gender?.key ?? ''} ${_gender?.label ?? ''}'.toLowerCase();
    return text.contains('male') && !text.contains('female') ||
        text.contains('groom') ||
        text.contains('पुरुष') ||
        text.contains('वर');
  }

  String get _relationKey => widget.profileForWhom?.key ?? '';

  String get _possessiveEn {
    if (_relationKey == 'self') return 'Your';
    if (_isFemaleProfile) return 'Her';
    if (_isMaleProfile) return 'His';
    return 'Their';
  }

  String get _possessiveMr {
    if (_relationKey == 'self') return 'तुमचे';
    if (_isFemaleProfile) return 'तिचे';
    if (_isMaleProfile) return 'त्याचे';
    return 'त्यांची';
  }

  String get _detailsTitle {
    if (_relationKey == 'self') {
      return _t('Your details', 'तुमची माहिती');
    }
    if (_relationKey == 'son') return _t('His details', 'मुलाची माहिती');
    if (_relationKey == 'daughter') return _t('Her details', 'मुलीची माहिती');
    if (_relationKey == 'brother') return _t('His details', 'भावाची माहिती');
    if (_relationKey == 'sister') return _t('Her details', 'बहिणीची माहिती');
    if (_isFemaleProfile) return _t('Her details', 'तिची माहिती');
    if (_isMaleProfile) return _t('His details', 'त्याची माहिती');
    return _t('Basic details', 'मूलभूत माहिती');
  }

  bool get _isNeverMarried {
    final key = _maritalStatus?.key?.replaceAll('-', '_').toLowerCase();
    if (key == 'never_married') return true;
    return _maritalStatus?.label.toLowerCase().contains('never') == true ||
        _maritalStatus?.label.contains('अविवाहित') == true;
  }

  bool get _childrenAllowed {
    if (_maritalStatus == null || _isNeverMarried) return false;
    final showFor = widget.bootstrap.childrenRules['show_for_keys'];
    if (showFor is List && _maritalStatus?.key != null) {
      return showFor
          .map((value) => value?.toString().replaceAll('-', '_'))
          .contains(_maritalStatus!.key!.replaceAll('-', '_'));
    }
    return true;
  }

  Future<PagedLookupResponse> _staticPage(
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

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final existing = DateTime.tryParse(_dobController.text.trim());
    final picked = await showDatePicker(
      context: context,
      initialDate: existing ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
    );
    if (picked == null) return;
    _dobController.text = picked.toIso8601String().substring(0, 10);
  }

  Future<void> _save() async {
    final dob = onboardingText(_dobController.text);
    if (dob != null) {
      final date = DateTime.tryParse(dob);
      if (date == null || date.isAfter(DateTime.now())) {
        widget.onMessage(_t('Enter a valid DOB.', 'वैध जन्मतारीख भरा.'));
        return;
      }
    }

    final payload = compactPayload({
      'full_name': _nameController.text.trim(),
      'gender_id': _gender?.intId,
      'date_of_birth': dob,
      'height_cm': _height?.metaInt('cm') ?? _height?.intId,
      'marital_status_id': _maritalStatus?.intId,
      'has_children': _childrenAllowed ? _hasChildren : false,
      'children_count': _childrenAllowed && _hasChildren
          ? onboardingInt(_childrenCountController.text)
          : null,
      'children_living_with': _childrenAllowed && _hasChildren
          ? _childrenLivingWithController.text.trim()
          : null,
      if (!_childrenAllowed || _isNeverMarried) 'children': <dynamic>[],
      if (_gender != null) 'gender_option': optionDraft(_gender!),
      if (_height != null) 'height_option': optionDraft(_height!),
      if (_maritalStatus != null)
        'marital_status_option': optionDraft(_maritalStatus!),
    });

    await widget.onSave('basic_info', payload, saveProfile: true);
  }

  Future<void> _continue() async {
    if (_page < 2) {
      setState(() => _page += 1);
      return;
    }

    await _save();
  }

  void _back() {
    if (_page > 0) {
      setState(() => _page -= 1);
      return;
    }

    widget.onBack();
  }

  String get _pageTitle {
    switch (_page) {
      case 0:
        return _detailsTitle;
      case 1:
        return _t('Birth and height', 'जन्मतारीख आणि उंची');
      default:
        return _t('Marital status', 'वैवाहिक स्थिती');
    }
  }

  String? get _pageSubtitle {
    switch (_page) {
      case 0:
        return _t(
          'Name and gender are used for the profile.',
          'नाव आणि लिंग प्रोफाइलसाठी वापरले जाईल.',
        );
      case 1:
        return _t('Add birth date and height.', 'जन्मतारीख आणि उंची भरा.');
      default:
        return _t(
          'Children details appear only when needed.',
          'गरज असेल तेव्हाच मुलांची माहिती दिसेल.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingStepScaffold(
      title: _pageTitle,
      subtitle: _pageSubtitle,
      loading: widget.loading,
      onBack: _back,
      onContinue: _continue,
      continueLabel: _page < 2
          ? _t('Continue', 'पुढे जा')
          : _t('Save and continue', 'Save करून पुढे जा'),
      children: switch (_page) {
        0 => [
          TextField(
            controller: _nameController,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: _t(
                '$_possessiveEn full name *',
                '$_possessiveMr पूर्ण नाव *',
              ),
              suffixIcon:
                  _creatorName == null || widget.profileForWhom?.key != 'self'
                  ? null
                  : TextButton(
                      onPressed: () => _nameController.text = _creatorName!,
                      child: Text(_t('Use my name', 'माझे नाव वापरा')),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          OnboardingPickerField(
            label: _t('Gender', 'लिंग'),
            selectedItems: _gender == null ? const [] : [_gender!],
            enabled: !_genderLocked,
            placeholder: _genderLocked
                ? _t('Set from relation', 'नात्यानुसार निवडले')
                : _t('Select gender', 'लिंग निवडा'),
            loadPage: (query, page, limit) =>
                _staticPage(widget.bootstrap.genders, query, page, limit),
            onChanged: (items) => setState(() {
              _gender = items.isEmpty ? null : items.first;
            }),
          ),
        ],
        1 => [
          TextField(
            controller: _dobController,
            readOnly: true,
            onTap: _pickDob,
            decoration: InputDecoration(
              labelText: _t(
                '$_possessiveEn date of birth',
                '$_possessiveMr जन्मतारीख',
              ),
              suffixIcon: const Icon(Icons.calendar_today),
            ),
          ),
          const SizedBox(height: 12),
          OnboardingPickerField(
            label: _t('Height', 'उंची'),
            selectedItems: _height == null ? const [] : [_height!],
            placeholder: _t('Select height', 'उंची निवडा'),
            loadPage: (query, page, limit) =>
                _staticPage(widget.bootstrap.heightOptions, query, page, limit),
            onChanged: (items) => setState(() {
              _height = items.isEmpty ? null : items.first;
            }),
          ),
        ],
        _ => [
          OnboardingPickerField(
            label: _t('Marital status', 'वैवाहिक स्थिती'),
            selectedItems: _maritalStatus == null
                ? const []
                : [_maritalStatus!],
            placeholder: _t('Select marital status', 'वैवाहिक स्थिती निवडा'),
            loadPage: (query, page, limit) => _staticPage(
              widget.bootstrap.maritalStatuses,
              query,
              page,
              limit,
            ),
            onChanged: (items) => setState(() {
              _maritalStatus = items.isEmpty ? null : items.first;
              if (_isNeverMarried || !_childrenAllowed) {
                _hasChildren = false;
                _childrenCountController.clear();
                _childrenLivingWithController.clear();
              }
            }),
          ),
          if (_childrenAllowed) ...[
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_t('Children', 'मुले')),
              subtitle: Text(
                _hasChildren
                    ? _t('Add simple child details', 'मुलांची साधी माहिती भरा')
                    : _t('No children', 'मुले नाहीत'),
              ),
              value: _hasChildren,
              onChanged: (value) => setState(() => _hasChildren = value),
            ),
            if (_hasChildren) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _childrenCountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _t('Children count', 'मुलांची संख्या'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _childrenLivingWithController,
                decoration: InputDecoration(
                  labelText: _t('Children living with', 'मुले कोणासोबत राहतात'),
                ),
              ),
            ],
          ],
        ],
      },
    );
  }
}
