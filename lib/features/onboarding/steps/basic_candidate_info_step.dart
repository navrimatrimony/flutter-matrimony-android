import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/onboarding_bootstrap.dart';
import '../models/onboarding_option.dart';
import '../models/paged_lookup_response.dart';
import '../widgets/onboarding_error_highlight.dart';
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
    required this.fieldErrors,
    required this.locale,
    required this.loading,
    this.showHeader = true,
    required this.onSave,
    required this.onBack,
    required this.onMessage,
    required this.onFieldEdited,
  });

  final Map<String, dynamic> data;
  final OnboardingBootstrap bootstrap;
  final Map<String, dynamic> account;
  final OnboardingOption? profileForWhom;
  final OnboardingOption? warmupGender;
  final Map<String, String> fieldErrors;
  final String locale;
  final bool loading;
  final bool showHeader;
  final OnboardingStepSaver onSave;
  final VoidCallback onBack;
  final ValueChanged<String> onMessage;
  final VoidCallback onFieldEdited;

  @override
  State<BasicCandidateInfoStep> createState() => _BasicCandidateInfoStepState();
}

class _BasicCandidateInfoStepState extends State<BasicCandidateInfoStep> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();

  OnboardingOption? _gender;
  OnboardingOption? _height;
  int _errorPulseToken = 0;
  bool _nameEdited = false;
  bool _dobEdited = false;
  bool _heightEdited = false;
  bool _nameError = false;
  bool _dobError = false;
  bool _heightError = false;

  bool get _mr => widget.locale == 'mr';

  List<OnboardingOption> get _heightOptions {
    final backendOptions = widget.bootstrap.heightOptions;
    final options = backendOptions.isNotEmpty
        ? _collapseHeightOptionsByInch(backendOptions)
        : _laravelHeightOptions;
    return _prioritizeCommonHeights(options);
  }

  static final List<OnboardingOption> _laravelHeightOptions =
      List<OnboardingOption>.unmodifiable(<OnboardingOption>[
        const OnboardingOption(
          id: 136,
          key: '136',
          label: 'Below 4ft 6in (136 cm)',
          meta: <String, dynamic>{'cm': 136},
        ),
        ...List<OnboardingOption>.generate(31, (index) {
          final totalInches = 54 + index;
          final cm = (totalInches * 2.54).round();
          return OnboardingOption(
            id: cm,
            key: cm.toString(),
            label: _heightLabelFromInches(totalInches, cm),
            meta: <String, dynamic>{'cm': cm, 'total_inches': totalInches},
          );
        }),
        const OnboardingOption(
          id: 214,
          key: '214',
          label: 'Above 7ft (214 cm)',
          meta: <String, dynamic>{'cm': 214},
        ),
      ]);

  @override
  void initState() {
    super.initState();
    _prefill(initial: true);
  }

  @override
  void didUpdateWidget(covariant BasicCandidateInfoStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!mapEquals(oldWidget.data, widget.data) ||
        oldWidget.bootstrap != widget.bootstrap ||
        !mapEquals(oldWidget.account, widget.account) ||
        oldWidget.profileForWhom?.identity != widget.profileForWhom?.identity ||
        oldWidget.warmupGender?.identity != widget.warmupGender?.identity) {
      _prefill(initial: false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  void _prefill({required bool initial}) {
    final data = widget.data;
    final incomingName = onboardingText(data['full_name']) ?? '';
    final incomingDob =
        _formatDobForDisplay(
          _parseDob(onboardingText(data['date_of_birth'])),
        ) ??
        '';
    final incomingHeight = _resolveHeightOption(
      optionFromData(data['height_option']),
      data['height_cm'],
    );

    _applyTextFromServer(
      controller: _nameController,
      value: incomingName,
      initial: initial,
      edited: _nameEdited,
      hasFocus: _nameFocusNode.hasFocus,
    );
    _applyTextFromServer(
      controller: _dobController,
      value: incomingDob,
      initial: initial,
      edited: _dobEdited,
      hasFocus: false,
    );
    if (initial || !_heightEdited) {
      _height = incomingHeight;
    }
    _gender =
        optionFromData(data['gender_option']) ??
        optionById(widget.bootstrap.genders, data['gender_id']) ??
        _lockedGenderOption() ??
        _warmupGenderOption();
  }

  void _applyTextFromServer({
    required TextEditingController controller,
    required String value,
    required bool initial,
    required bool edited,
    required bool hasFocus,
  }) {
    if (!initial && (edited || hasFocus)) return;
    if (controller.text == value) return;

    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  OnboardingOption? _resolveHeightOption(
    OnboardingOption? stored,
    dynamic heightCm,
  ) {
    final cm =
        onboardingInt(heightCm) ??
        stored?.metaInt('cm') ??
        stored?.intId ??
        onboardingInt(stored?.key);
    if (cm != null) {
      return optionById(_heightOptions, cm) ??
          optionByKey(_heightOptions, cm.toString()) ??
          _heightOptionFromCm(cm);
    }
    return stored == null ? null : _heightDisplayOption(stored);
  }

  static OnboardingOption _heightDisplayOption(OnboardingOption option) {
    final cm =
        option.metaInt('cm') ?? option.intId ?? onboardingInt(option.key);
    if (cm == null) return option;
    if (cm <= 136) {
      return const OnboardingOption(
        id: 136,
        key: '136',
        label: 'Below 4ft 6in (136 cm)',
        meta: <String, dynamic>{'cm': 136},
      );
    }
    if (cm >= 214) {
      return const OnboardingOption(
        id: 214,
        key: '214',
        label: 'Above 7ft (214 cm)',
        meta: <String, dynamic>{'cm': 214},
      );
    }
    final totalInches = (cm / 2.54).round().clamp(54, 84);
    final displayCm = (totalInches * 2.54).round();
    return OnboardingOption(
      id: displayCm,
      key: displayCm.toString(),
      label: _heightLabelFromInches(totalInches, displayCm),
      translationMissing: option.translationMissing,
      popular: option.popular,
      meta: <String, dynamic>{
        ...option.meta,
        'cm': displayCm,
        'total_inches': totalInches,
      },
      raw: option.raw,
    );
  }

  static List<OnboardingOption> _collapseHeightOptionsByInch(
    List<OnboardingOption> options,
  ) {
    final byCm = <int, OnboardingOption>{};
    for (final option in options) {
      final display = _heightDisplayOption(option);
      final cm = display.metaInt('cm') ?? display.intId;
      if (cm != null) byCm[cm] = display;
    }

    final merged = <OnboardingOption>[..._laravelHeightOptions, ...byCm.values];
    final unique = <int, OnboardingOption>{};
    for (final option in merged) {
      final cm = option.metaInt('cm') ?? option.intId;
      if (cm != null) unique[cm] = option;
    }
    final sorted = unique.values.toList()
      ..sort((a, b) {
        final aCm = a.metaInt('cm') ?? a.intId ?? 0;
        final bCm = b.metaInt('cm') ?? b.intId ?? 0;
        return aCm.compareTo(bCm);
      });
    return sorted;
  }

  static List<OnboardingOption> _prioritizeCommonHeights(
    List<OnboardingOption> options,
  ) {
    final common = <OnboardingOption>[];
    final lower = <OnboardingOption>[];
    final higher = <OnboardingOption>[];

    for (final option in options) {
      final cm = option.metaInt('cm') ?? option.intId ?? 0;
      if (cm >= 150 && cm <= 168) {
        common.add(option);
      } else if (cm < 150) {
        lower.add(option);
      } else {
        higher.add(option);
      }
    }

    return <OnboardingOption>[...common, ...lower, ...higher];
  }

  static OnboardingOption _heightOptionFromCm(int cm) {
    return OnboardingOption(
      id: cm,
      key: cm.toString(),
      label: _heightLabelFromCm(cm),
      meta: <String, dynamic>{'cm': cm},
    );
  }

  static String _heightLabelFromCm(int cm) {
    final inches = (cm / 2.54).round();
    return _heightLabelFromInches(inches, cm);
  }

  static String _heightLabelFromInches(int totalInches, int cm) {
    final feet = totalInches ~/ 12;
    final inch = totalInches % 12;
    if (inch == 0) return '${feet}ft ($cm cm)';
    return '${feet}ft ${inch}in ($cm cm)';
  }

  String _t(String en, String mr) => _mr ? mr : en;

  String? get _genderMode =>
      widget.profileForWhom?.metaText('gender_mode') ??
      widget.profileForWhom?.raw['gender_mode']?.toString();

  String get _relationKey => widget.profileForWhom?.key?.toLowerCase() ?? '';

  bool get _hasName => _nameController.text.trim().isNotEmpty;

  bool get _hasDob => _dobController.text.trim().isNotEmpty;

  bool get _hasHeight => _height != null;

  bool get _canContinue => _hasName && _hasDob && _hasHeight;

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
    final keyed = optionByKey(widget.bootstrap.genders, mode);
    if (keyed != null) return keyed;

    for (final option in widget.bootstrap.genders) {
      final label = option.label.toLowerCase();
      if (mode == 'female' && label.contains('female')) return option;
      if (mode == 'male' &&
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

  String get _detailsTitle {
    switch (_relationKey) {
      case 'self':
        return _t('Your details', 'तुमची माहिती');
      case 'son':
        return _t('Son’s details', 'मुलाची माहिती');
      case 'daughter':
        return _t('Daughter’s details', 'मुलीची माहिती');
      case 'brother':
        return _t('Brother’s details', 'भावाची माहिती');
      case 'sister':
        return _t('Sister’s details', 'बहिणीची माहिती');
      case 'friend':
        return _isFemaleProfile
            ? _t('Friend’s details', 'मैत्रिणीची माहिती')
            : _t('Friend’s details', 'मित्राची माहिती');
      case 'relative':
        if (_isFemaleProfile) {
          return _t('Bride relative’s details', 'नातेवाईक वधूची माहिती');
        }
        if (_isMaleProfile) {
          return _t('Groom relative’s details', 'नातेवाईक वराची माहिती');
        }
        return _t('Relative’s details', 'नातेवाईकाची माहिती');
      default:
        return _t('Basic details', 'मूलभूत माहिती');
    }
  }

  String get _nameFieldLabel {
    switch (_relationKey) {
      case 'self':
        return _t('Your full name *', 'तुमचे पूर्ण नाव *');
      case 'son':
        return _t('Son’s full name *', 'मुलाचे पूर्ण नाव *');
      case 'daughter':
        return _t('Daughter’s full name *', 'मुलीचे पूर्ण नाव *');
      case 'brother':
        return _t('Brother’s full name *', 'भावाचे पूर्ण नाव *');
      case 'sister':
        return _t('Sister’s full name *', 'बहिणीचे पूर्ण नाव *');
      case 'friend':
        return _isFemaleProfile
            ? _t('Friend’s full name *', 'मैत्रिणीचे पूर्ण नाव *')
            : _t('Friend’s full name *', 'मित्राचे पूर्ण नाव *');
      case 'relative':
        if (_isFemaleProfile) {
          return _t(
            'Bride relative’s full name *',
            'नातेवाईक वधूचे पूर्ण नाव *',
          );
        }
        if (_isMaleProfile) {
          return _t(
            'Groom relative’s full name *',
            'नातेवाईक वराचे पूर्ण नाव *',
          );
        }
        return _t('Relative’s full name *', 'नातेवाईकाचे पूर्ण नाव *');
      default:
        return _t('Full name *', 'पूर्ण नाव *');
    }
  }

  String get _dobLabel {
    return _t('Date of birth *', 'जन्मतारीख *');
  }

  String get _heightLabel {
    return _t('Height *', 'उंची *');
  }

  static DateTime? _parseDob(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return null;

    final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(text);
    if (iso != null) {
      return _dateFromParts(
        year: int.parse(iso.group(1)!),
        month: int.parse(iso.group(2)!),
        day: int.parse(iso.group(3)!),
      );
    }

    final display = RegExp(r'^(\d{2})-(\d{2})-(\d{4})$').firstMatch(text);
    if (display != null) {
      return _dateFromParts(
        day: int.parse(display.group(1)!),
        month: int.parse(display.group(2)!),
        year: int.parse(display.group(3)!),
      );
    }

    return DateTime.tryParse(text);
  }

  static DateTime? _dateFromParts({
    required int year,
    required int month,
    required int day,
  }) {
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }

  static String? _formatDobForDisplay(DateTime? date) {
    if (date == null) return null;
    return '${_twoDigits(date.day)}-${_twoDigits(date.month)}-${date.year.toString().padLeft(4, '0')}';
  }

  static String _formatDobForPayload(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${_twoDigits(date.month)}-${_twoDigits(date.day)}';
  }

  static String _twoDigits(int value) => value.toString().padLeft(2, '0');

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
    final pageRows = start >= rows.length
        ? <OnboardingOption>[]
        : rows.skip(start).take(limit).toList();
    return PagedLookupResponse(
      success: true,
      results: pageRows,
      pagination: LookupPagination(
        page: page,
        perPage: limit,
        total: rows.length,
        hasMore: start + pageRows.length < rows.length,
      ),
    );
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final existing = _parseDob(_dobController.text);
    final picked = await showDatePicker(
      context: context,
      initialDate: existing ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() {
      _dobEdited = true;
      _dobError = false;
      _dobController.text = _formatDobForDisplay(picked) ?? '';
    });
    widget.onFieldEdited();
  }

  Future<void> _save() async {
    final missingName = _nameController.text.trim().isEmpty;
    final dob = onboardingText(_dobController.text);
    final date = _parseDob(dob);
    final invalidDob = date == null || date.isAfter(DateTime.now());
    final missingHeight = _height == null;

    setState(() {
      _nameError = missingName;
      _dobError = invalidDob;
      _heightError = missingHeight;
      if (missingName || invalidDob || missingHeight) {
        _errorPulseToken++;
      }
    });

    if (_nameController.text.trim().isEmpty) {
      widget.onMessage(_t('Enter full name.', 'पूर्ण नाव भरा.'));
      return;
    }
    if (invalidDob) {
      widget.onMessage(_t('Enter a valid DOB.', 'वैध जन्मतारीख भरा.'));
      return;
    }
    if (missingHeight) {
      widget.onMessage(_t('Select height.', 'उंची निवडा.'));
      return;
    }
    if (_gender == null) {
      widget.onMessage(
        _t('Choose gender before continuing.', 'पुढे जाण्यापूर्वी लिंग निवडा.'),
      );
      return;
    }

    final payloadDob = _formatDobForPayload(date);
    final heightCm = _height?.metaInt('cm') ?? _height?.intId;
    final payload = compactPayload({
      'full_name': _nameController.text.trim(),
      'gender_id': _gender?.intId,
      'date_of_birth': payloadDob,
      'height_cm': heightCm,
    });

    await widget.onSave('basic_info', payload, saveProfile: true);
  }

  @override
  Widget build(BuildContext context) {
    final fullNameError = onboardingFieldErrorText(
      widget.fieldErrors,
      'full_name',
    );
    final dobFieldError = onboardingFieldErrorText(
      widget.fieldErrors,
      'date_of_birth',
    );
    final dobHasError = _dobError || dobFieldError != null;
    final heightFieldError = onboardingFieldErrorText(
      widget.fieldErrors,
      'height_cm',
    );

    return OnboardingStepScaffold(
      title: widget.showHeader ? _detailsTitle : '',
      loading: widget.loading,
      onBack: widget.onBack,
      onContinue: _save,
      continueEnabled: _canContinue,
      continueLabel: _t('Continue', 'पुढे जा'),
      children: [
        OnboardingErrorHighlight.forField(
          field: 'full_name',
          fieldErrors: widget.fieldErrors,
          localError: _nameError,
          pulseToken: _errorPulseToken,
          child: TextField(
            controller: _nameController,
            focusNode: _nameFocusNode,
            textInputAction: TextInputAction.next,
            decoration: onboardingErrorInputDecoration(
              labelText: _nameFieldLabel,
              errorText: _nameError
                  ? _t('Enter full name.', 'पूर्ण नाव भरा.')
                  : fullNameError,
            ),
            onChanged: (_) {
              setState(() {
                _nameEdited = true;
                _nameError = false;
              });
              widget.onFieldEdited();
            },
          ),
        ),
        if (_hasName) ...[
          const SizedBox(height: 12),
          OnboardingErrorHighlight.forField(
            field: 'date_of_birth',
            fieldErrors: widget.fieldErrors,
            localError: _dobError,
            pulseToken: _errorPulseToken,
            child: TextField(
              controller: _dobController,
              readOnly: true,
              onTap: _pickDob,
              decoration:
                  onboardingErrorInputDecoration(
                    labelText: _dobLabel,
                    errorText: _dobError
                        ? _t('Select DOB.', 'जन्मतारीख निवडा.')
                        : dobFieldError,
                    suffixIcon: const Icon(Icons.calendar_today),
                  ).copyWith(
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade400),
                    ),
                    floatingLabelStyle: dobHasError
                        ? null
                        : TextStyle(color: Colors.grey.shade700),
                  ),
            ),
          ),
        ],
        if (_hasDob) ...[
          const SizedBox(height: 12),
          OnboardingErrorHighlight.forField(
            field: 'height_cm',
            fieldErrors: widget.fieldErrors,
            localError: _heightError,
            pulseToken: _errorPulseToken,
            child: OnboardingPickerField(
              label: _heightLabel,
              selectedItems: _height == null ? const [] : [_height!],
              placeholder: _t('Select height', 'उंची निवडा'),
              errorText: _heightError
                  ? _t('Select height.', 'उंची निवडा.')
                  : heightFieldError,
              showDividers: true,
              loadPage: (query, page, limit) =>
                  _staticPage(_heightOptions, query, page, limit),
              onChanged: (items) {
                setState(() {
                  _heightEdited = true;
                  _heightError = false;
                  _height = items.isEmpty ? null : items.first;
                });
                widget.onFieldEdited();
              },
            ),
          ),
        ],
      ],
    );
  }
}
