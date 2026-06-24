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
        oldWidget.profileForWhom?.identity != widget.profileForWhom?.identity) {
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

  OnboardingOption? _lockedGenderOption() {
    final mode = _genderMode;
    if (mode != 'male' && mode != 'female') return null;
    final lockedMode = mode!;
    final keyed = optionByKey(widget.bootstrap.genders, lockedMode);
    if (keyed != null) return keyed;

    for (final option in widget.bootstrap.genders) {
      final label = option.label.toLowerCase();
      if (label == lockedMode || label.contains(lockedMode)) return option;
    }
    return null;
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

  @override
  Widget build(BuildContext context) {
    return OnboardingStepScaffold(
      title: _t('Basic Candidate Info', 'मूलभूत उमेदवार माहिती'),
      subtitle: _t(
        'Candidate name is separate from account creator name.',
        'Candidate चे नाव account creator नावापेक्षा वेगळे आहे.',
      ),
      loading: widget.loading,
      onBack: widget.onBack,
      onContinue: _save,
      children: [
        TextField(
          controller: _nameController,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: _t('Candidate full name *', 'Candidate पूर्ण नाव *'),
            suffixIcon:
                _creatorName == null || widget.profileForWhom?.key != 'self'
                ? null
                : TextButton(
                    onPressed: () => _nameController.text = _creatorName!,
                    child: Text(_t('Use account name', 'Account नाव वापरा')),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        OnboardingPickerField(
          label: _t('Gender', 'लिंग'),
          selectedItems: _gender == null ? const [] : [_gender!],
          enabled: !_genderLocked,
          placeholder: _genderLocked
              ? _t('Set from profile relation', 'Relation वरून set')
              : _t('Select gender', 'लिंग निवडा'),
          loadPage: (query, page, limit) =>
              _staticPage(widget.bootstrap.genders, query, page, limit),
          onChanged: (items) => setState(() {
            _gender = items.isEmpty ? null : items.first;
          }),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _dobController,
          readOnly: true,
          onTap: _pickDob,
          decoration: InputDecoration(
            labelText: _t('Date of birth', 'जन्मतारीख'),
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
        const SizedBox(height: 12),
        OnboardingPickerField(
          label: _t('Marital status', 'वैवाहिक स्थिती'),
          selectedItems: _maritalStatus == null ? const [] : [_maritalStatus!],
          placeholder: _t('Select marital status', 'वैवाहिक स्थिती निवडा'),
          loadPage: (query, page, limit) =>
              _staticPage(widget.bootstrap.maritalStatuses, query, page, limit),
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
    );
  }
}
