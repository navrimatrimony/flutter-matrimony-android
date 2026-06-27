import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_client.dart';
import '../../core/app_language.dart';
import '../../core/app_storage.dart';
import 'models/mobile_otp_models.dart';
import 'models/onboarding_field_error_map.dart';
import 'models/onboarding_bootstrap.dart';
import 'models/onboarding_option.dart';
import 'models/onboarding_status.dart';
import 'models/paged_lookup_response.dart';
import 'steps/activation_checklist_step.dart';
import 'steps/astro_step.dart';
import 'steps/basic_candidate_info_step.dart';
import 'steps/education_career_step.dart';
import 'steps/family_optional_step.dart';
import 'steps/lifestyle_step.dart';
import 'steps/location_step.dart';
import 'steps/marital_status_step.dart';
import 'steps/onboarding_step_helpers.dart';
import 'steps/photo_step.dart';
import 'steps/religion_caste_step.dart';
import 'widgets/onboarding_error_highlight.dart';
import 'widgets/onboarding_picker_field.dart';

enum SmartOnboardingInitialMode { normal, mobileOtp }

enum _SmartOnboardingStep {
  profileForWhom,
  mobileOtp,
  maritalStatus,
  basicInfo,
  religionCaste,
  location,
  education,
  motherTongue,
  lifestyle,
  family,
  astro,
  photo,
  activation,
}

enum _OnboardingMessageType { success, info, warning }

class SmartOnboardingScreen extends StatefulWidget {
  const SmartOnboardingScreen({
    super.key,
    this.initialMode = SmartOnboardingInitialMode.normal,
    this.pendingEmail,
    this.initialMobile,
  });

  final SmartOnboardingInitialMode initialMode;
  final String? pendingEmail;
  final String? initialMobile;

  @override
  State<SmartOnboardingScreen> createState() => _SmartOnboardingScreenState();
}

class _SmartOnboardingScreenState extends State<SmartOnboardingScreen> {
  static const String _consentVersion = '2026-06-24';

  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  _SmartOnboardingStep _step = _SmartOnboardingStep.profileForWhom;
  AppLanguage _language = currentAppLanguage;
  OnboardingBootstrap _bootstrap = OnboardingBootstrap.fallbackProfileForWhom();
  OnboardingStatus? _status;
  OnboardingOption? _profileForWhom;
  OnboardingOption? _warmupGender;
  OnboardingOption? _motherTongue;
  MobileOtpSendResponse? _otpChallenge;
  Map<String, dynamic> _serverDraftData = <String, dynamic>{};
  Map<String, dynamic> _clientDraftData = <String, dynamic>{};
  List<OnboardingOption> _motherTongues = const <OnboardingOption>[];
  List<OnboardingOption> _childLivingWithOptions = const <OnboardingOption>[];
  DateTime? _resendAvailableAt;
  Timer? _resendTimer;
  Timer? _messageTimer;

  bool _loading = false;
  bool _childLivingWithLoading = false;
  bool _profileForWhomChangedAfterMaritalSelection = false;
  bool _whatsappAlertsOptIn = true;
  bool _debugOtpAutoVerifyQueued = false;
  bool _messageGapVisible = false;
  int _resendSecondsRemaining = 0;
  String? _error;
  String? _message;
  String? _motherTongueError;
  String? _childLivingWithError;
  Map<String, String> _fieldErrors = const <String, String>{};
  _OnboardingMessageType _messageType = _OnboardingMessageType.info;
  int _fieldErrorPulseToken = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialMode == SmartOnboardingInitialMode.mobileOtp) {
      _step = _SmartOnboardingStep.mobileOtp;
      final mobile = widget.initialMobile?.trim();
      if (mobile != null && mobile.isNotEmpty) {
        _mobileController.text = _displayMobileDigits(mobile);
      }
    }
    _initialize();
  }

  @override
  void dispose() {
    _mobileController.dispose();
    _otpController.dispose();
    _emailController.dispose();
    _resendTimer?.cancel();
    _messageTimer?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    final savedLanguage = await AppStorage.instance.readLanguage();
    await ApiClient.restoreSessionFromStorage();
    await _restoreLocalDraft();
    final pendingEmail = widget.pendingEmail?.trim();
    if (pendingEmail != null &&
        pendingEmail.isNotEmpty &&
        _emailController.text.trim().isEmpty) {
      _emailController.text = pendingEmail;
    }

    if (!mounted) return;
    final language = savedLanguage ?? _language;
    setState(() {
      _language = language;
      setAppLanguage(language);
    });

    if (ApiClient.authToken != null) {
      await _loadBootstrap();
      await _loadStatus(goToStatus: false);
      final status = _status;
      if (!mounted || status == null) return;

      setState(() {
        if (status.draft == null && !status.hasProfile) {
          _step = _SmartOnboardingStep.profileForWhom;
        } else {
          _step = _stepFromStatus(status);
        }
      });
      return;
    }

    await _loadBootstrap();
    if (!mounted) return;
    setState(() {
      _step = widget.initialMode == SmartOnboardingInitialMode.mobileOtp
          ? _SmartOnboardingStep.mobileOtp
          : _SmartOnboardingStep.profileForWhom;
    });
    await _saveLocalDraft();
  }

  String _t(String english, String marathi) {
    return _language == AppLanguage.marathi ? marathi : english;
  }

  void _showOnboardingMessage(
    String message, {
    _OnboardingMessageType type = _OnboardingMessageType.info,
    bool autoHide = true,
  }) {
    _messageTimer?.cancel();
    setState(() {
      _message = message;
      _messageType = type;
      _error = null;
      _messageGapVisible = false;
      _motherTongueError = null;
      _fieldErrors = const <String, String>{};
    });

    if (!autoHide) return;
    _messageTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted || _message != message) return;
      setState(() {
        _message = null;
        _messageGapVisible = true;
      });
      _messageTimer = Timer(const Duration(seconds: 1), () {
        if (!mounted || !_messageGapVisible) return;
        setState(() {
          _messageGapVisible = false;
        });
      });
    });
  }

  void _clearCurrentFeedback() {
    _messageTimer?.cancel();
    setState(() {
      _error = null;
      _message = null;
      _messageGapVisible = false;
      _motherTongueError = null;
      _fieldErrors = const <String, String>{};
    });
  }

  String _friendlySaveError(Map<String, dynamic> response, String fallback) {
    final raw = readableApiError(response, fallback);
    if (_isTechnicalOnboardingError(raw)) {
      return _genericSaveFailureMessage();
    }

    return raw;
  }

  String _friendlyFieldError(String field, String raw) {
    switch (field) {
      case 'full_name':
        return _t('Please enter full name.', 'कृपया पूर्ण नाव भरा.');
      case 'date_of_birth':
        return _t('Please check Date of birth.', 'कृपया जन्मतारीख तपासा.');
      case 'height_cm':
        return _t('Please check Height.', 'कृपया उंची तपासा.');
      case 'mother_tongue_id':
      case 'mother_tongue':
        return _t(
          'Please select mother tongue again.',
          'कृपया मातृभाषा पुन्हा निवडा.',
        );
      case 'has_children':
        return _t(
          'Please select whether there are children.',
          'मुलं आहेत का ते निवडा.',
        );
      case 'children':
        return _t('Please check child details.', 'कृपया मुलांची माहिती तपासा.');
    }

    if (field.startsWith('children.')) {
      if (field.endsWith('.gender')) {
        return _t('Select child gender.', 'मुलाचे/मुलीचे लिंग निवडा.');
      }
      if (field.endsWith('.age')) {
        return _t('Enter valid child age.', 'मुलाचे/मुलीचे योग्य वय भरा.');
      }
      if (field.endsWith('.child_living_with_id')) {
        return _t(
          'Please select living with again.',
          'कोणासोबत राहते ते पुन्हा निवडा.',
        );
      }
      return _t('Please check child details.', 'कृपया मुलांची माहिती तपासा.');
    }

    if (_isTechnicalOnboardingError(raw)) {
      return _t('Please check this field.', 'कृपया ही निवड तपासा.');
    }

    return raw;
  }

  String _genericSaveFailureMessage() {
    return _t(
      'We could not save this information. Please check the highlighted field.',
      'ही माहिती सेव्ह करता आली नाही. कृपया highlight केलेले field तपासा.',
    );
  }

  String? _firstFieldErrorSummary(Map<String, String> fieldErrors) {
    return onboardingFirstFieldError(
      fieldErrors,
      OnboardingFieldErrorMap.ownershipPriority,
    );
  }

  Map<String, String> _responseFieldErrors(
    Map<String, dynamic> response,
    Iterable<String> fields,
  ) {
    final errors = response['errors'];
    if (errors is! Map) return const <String, String>{};
    final out = <String, String>{};
    for (final field in fields) {
      final value = errors[field];
      final text = _validationErrorText(value);
      if (text != null) out[field] = _friendlyFieldError(field, text);
    }
    for (final entry in errors.entries) {
      final field = entry.key.toString();
      if (out.containsKey(field)) continue;
      if (OnboardingFieldErrorMap.targetFor(field) == null) continue;
      final text = _validationErrorText(entry.value);
      if (text != null) out[field] = _friendlyFieldError(field, text);
    }

    return out;
  }

  String _stepKeyForOnboardingStep(_SmartOnboardingStep step) {
    return switch (step) {
      _SmartOnboardingStep.profileForWhom =>
        OnboardingFieldErrorMap.profileForWhomStep,
      _SmartOnboardingStep.maritalStatus =>
        OnboardingFieldErrorMap.basicInfoStep,
      _SmartOnboardingStep.basicInfo => OnboardingFieldErrorMap.basicInfoStep,
      _SmartOnboardingStep.religionCaste => 'religion_caste',
      _SmartOnboardingStep.location => 'location',
      _SmartOnboardingStep.education => 'education',
      _SmartOnboardingStep.motherTongue =>
        OnboardingFieldErrorMap.communityStep,
      _SmartOnboardingStep.lifestyle => 'lifestyle',
      _SmartOnboardingStep.family => 'family',
      _SmartOnboardingStep.astro => OnboardingFieldErrorMap.astroStep,
      _SmartOnboardingStep.photo => 'photo',
      _SmartOnboardingStep.mobileOtp => 'mobile_otp',
      _SmartOnboardingStep.activation => 'activation',
    };
  }

  _SmartOnboardingStep? _onboardingStepForStepKey(String step) {
    return switch (step) {
      OnboardingFieldErrorMap.profileForWhomStep =>
        _SmartOnboardingStep.profileForWhom,
      OnboardingFieldErrorMap.basicInfoStep => _SmartOnboardingStep.basicInfo,
      'religion_caste' => _SmartOnboardingStep.religionCaste,
      'location' => _SmartOnboardingStep.location,
      'education' => _SmartOnboardingStep.education,
      'career' => _SmartOnboardingStep.education,
      'lifestyle' => _SmartOnboardingStep.lifestyle,
      'family' => _SmartOnboardingStep.family,
      OnboardingFieldErrorMap.astroStep => _SmartOnboardingStep.astro,
      'photo' => _SmartOnboardingStep.photo,
      _ => null,
    };
  }

  _SmartOnboardingStep _stepForFieldErrors(
    Map<String, String> fieldErrors,
    String fallbackOwnerStep,
  ) {
    for (final field in fieldErrors.keys) {
      final uiField = OnboardingFieldErrorMap.targetFor(field)?.uiField;
      if (uiField == 'marital_status' ||
          uiField == 'has_children' ||
          uiField == 'children') {
        return _SmartOnboardingStep.maritalStatus;
      }
      if (uiField == 'mother_tongue') {
        return _SmartOnboardingStep.religionCaste;
      }
    }

    return _onboardingStepForStepKey(fallbackOwnerStep) ?? _step;
  }

  Map<String, String> _fieldErrorsForStep(String step) {
    return OnboardingFieldErrorMap.forStep(_fieldErrors, step);
  }

  String? _motherTongueFieldError(Map<String, String> fieldErrors) {
    return onboardingFirstFieldError(fieldErrors, const <String>[
      'mother_tongue_id',
      'mother_tongue',
    ]);
  }

  String? _firstFieldErrorForStep(
    Map<String, String> fieldErrors,
    String step,
  ) {
    return onboardingFirstFieldError(
      OnboardingFieldErrorMap.forStep(fieldErrors, step),
      OnboardingFieldErrorMap.ownershipPriority,
    );
  }

  void _showMappedFieldError(String field) {
    final message = _friendlyFieldError(field, '');
    final target = OnboardingFieldErrorMap.targetFor(field);
    final ownerStep = target?.ownerStep ?? _stepKeyForOnboardingStep(_step);
    final fieldErrors = <String, String>{field: message};
    final nextStep = _stepForFieldErrors(fieldErrors, ownerStep);
    setState(() {
      _loading = false;
      _step = nextStep;
      _fieldErrors = fieldErrors;
      _fieldErrorPulseToken++;
      _motherTongueError = _motherTongueFieldError(fieldErrors);
      _error = message;
      _message = null;
    });
  }

  void _applySaveFailure({
    required String attemptedStep,
    required Map<String, dynamic> response,
  }) {
    final fieldErrors = _responseFieldErrors(
      response,
      OnboardingFieldErrorMap.knownBackendFields,
    );
    final ownerStep =
        OnboardingFieldErrorMap.ownerStepFor(fieldErrors) ?? attemptedStep;
    final nextStep = _stepForFieldErrors(fieldErrors, ownerStep);
    final message =
        _firstFieldErrorForStep(fieldErrors, ownerStep) ??
        _firstFieldErrorSummary(fieldErrors) ??
        _friendlySaveError(response, _genericSaveFailureMessage());

    setState(() {
      _loading = false;
      _step = nextStep;
      _fieldErrors = fieldErrors;
      _fieldErrorPulseToken++;
      _motherTongueError = _motherTongueFieldError(fieldErrors);
      _error = message;
      _message = null;
    });
  }

  void _debugLogSaveAttempt(String step, Map<String, dynamic> payload) {
    if (!kDebugMode) return;
    final keys = payload.keys.map((key) => key.toString()).toList()..sort();
    debugPrint('SmartOnboarding save step=$step payloadKeys=$keys');
  }

  void _debugLogMotherTongueSelection(
    String phase, {
    Map<String, dynamic>? payload,
  }) {
    if (!kDebugMode) return;
    final selected = _motherTongue;
    final payloadKeys =
        payload?.keys.map((key) => key.toString()).toList() ?? <String>[];
    payloadKeys.sort();
    final payloadValue = payload?['mother_tongue_id'];
    final payloadType = payloadValue == null
        ? 'null'
        : payloadValue.runtimeType.toString();
    debugPrint(
      'SmartOnboarding mother_tongue phase=$phase '
      'selected=${selected?.toJson()} '
      'selectedId=${selected?.intId} selectedRawId=${selected?.id} '
      'selectedKey=${selected?.key} selectedLabel=${selected?.label} '
      'payloadKeys=$payloadKeys '
      'payloadMotherTongueId=$payloadValue '
      'payloadMotherTongueIdType=$payloadType',
    );
  }

  void _debugLogBackendError(String phase, Map<String, dynamic> response) {
    if (!kDebugMode) return;
    final errors = response['errors'];
    final keys = <String>[];
    if (errors is Map) {
      keys.addAll(errors.keys.map((key) => key.toString()));
      keys.sort();
    }
    final message = onboardingText(response['message']);
    debugPrint(
      'SmartOnboarding $phase failed status=${response['statusCode']} '
      'errorKeys=$keys message=$message',
    );
  }

  String? _validationErrorText(dynamic value) {
    if (value is List && value.isNotEmpty) {
      return onboardingText(value.first);
    }
    return onboardingText(value);
  }

  bool _isTechnicalOnboardingError(String message) {
    final text = message.toLowerCase();
    return text.contains('not accepted in onboarding phase 2') ||
        text.contains('not supported for this onboarding step') ||
        text.contains('direct custom education or occupation text');
  }

  String get _localeCode => appLanguageCode(_language);

  bool get _isAuthenticated =>
      ApiClient.authToken != null && ApiClient.authToken!.isNotEmpty;

  String? get _profileForWhomKey => _profileForWhom?.key?.trim();

  bool get _basicInfoHasMaritalStatus =>
      onboardingInt(_draftStepData('basic_info')['marital_status_id']) != null;

  bool get _hasMotherTongueSelection =>
      _motherTongue?.intId != null || _draftMotherTongueId() != null;

  bool get _canContinueProfileForWhom =>
      _profileForWhom != null && (!_needsGenderWarmup || _warmupGender != null);

  String get _genderMode {
    final explicit =
        _profileForWhom?.metaText('gender_mode') ??
        _profileForWhom?.raw['gender_mode']?.toString().trim();
    if (explicit != null && explicit.isNotEmpty) {
      return explicit.toLowerCase();
    }

    switch (_profileForWhomKey) {
      case 'son':
      case 'brother':
        return 'male';
      case 'daughter':
      case 'sister':
        return 'female';
      default:
        return 'ask';
    }
  }

  bool get _needsGenderWarmup =>
      _genderMode != 'male' && _genderMode != 'female';

  String _effectiveProfileGenderKey() {
    final mode = _genderMode;
    if (mode == 'male' || mode == 'female') return mode;
    return _genderOptionKey(_warmupGender);
  }

  bool get _canShowOnboardingBack =>
      _step != _SmartOnboardingStep.profileForWhom;

  bool get _showCreateProfileChrome => _step != _SmartOnboardingStep.mobileOtp;

  bool get _canStepBackWithinOnboarding {
    if (_loading) return false;
    if (_step == _SmartOnboardingStep.profileForWhom) return false;
    if (_step == _SmartOnboardingStep.mobileOtp) {
      return _otpChallenge?.challengeId != null ||
          widget.initialMode != SmartOnboardingInitialMode.mobileOtp ||
          _profileForWhom != null;
    }
    return true;
  }

  _SmartOnboardingStep _stepFromStatus(OnboardingStatus status) {
    final next = status.nextStep ?? status.draft?.currentStep;
    if (_statusHasCompletedEducation(status)) {
      if (!_hasMotherTongueSelection) {
        return _SmartOnboardingStep.religionCaste;
      }
      if (_isServerStepBeforeLifestyle(next)) {
        return _SmartOnboardingStep.lifestyle;
      }
    }
    return _stepFromServerName(next);
  }

  bool _statusHasCompletedEducation(OnboardingStatus status) {
    final steps = status.draft?.completedSteps ?? const <String>[];
    return steps.contains('education') || steps.contains('career');
  }

  bool _isServerStepBeforeLifestyle(String? step) {
    final normalized = step?.trim().toLowerCase();
    return normalized == 'basic_info' ||
        normalized == 'religion_caste' ||
        normalized == 'location' ||
        normalized == 'education' ||
        normalized == 'career';
  }

  bool get _supportsAstroStep {
    return _bootstrap.steps.contains('astro') ||
        _bootstrap.mangalDoshTypes.isNotEmpty ||
        _bootstrap.nakshatras.isNotEmpty ||
        _bootstrap.rashis.isNotEmpty;
  }

  _SmartOnboardingStep _stepFromServerName(String? step) {
    switch (step) {
      case 'account':
        return _SmartOnboardingStep.profileForWhom;
      case 'profile_for_whom':
        return _SmartOnboardingStep.profileForWhom;
      case 'basic_info':
        return _basicInfoHasMaritalStatus
            ? _SmartOnboardingStep.basicInfo
            : _SmartOnboardingStep.maritalStatus;
      case 'religion_caste':
        return _SmartOnboardingStep.religionCaste;
      case 'location':
        return _SmartOnboardingStep.location;
      case 'education':
        return _SmartOnboardingStep.education;
      case 'career':
        return _SmartOnboardingStep.education;
      case 'lifestyle':
        return _hasMotherTongueSelection
            ? _SmartOnboardingStep.lifestyle
            : _SmartOnboardingStep.religionCaste;
      case 'family':
        return _SmartOnboardingStep.family;
      case 'astro':
        return _SmartOnboardingStep.astro;
      case 'photo':
        return _SmartOnboardingStep.photo;
      case 'activation':
        return _SmartOnboardingStep.activation;
    }

    return _SmartOnboardingStep.activation;
  }

  _SmartOnboardingStep _nextProfileStep(_SmartOnboardingStep step) {
    switch (step) {
      case _SmartOnboardingStep.profileForWhom:
        return _SmartOnboardingStep.maritalStatus;
      case _SmartOnboardingStep.maritalStatus:
        return _SmartOnboardingStep.basicInfo;
      case _SmartOnboardingStep.basicInfo:
        return _SmartOnboardingStep.religionCaste;
      case _SmartOnboardingStep.religionCaste:
        return _SmartOnboardingStep.location;
      case _SmartOnboardingStep.location:
        return _SmartOnboardingStep.education;
      case _SmartOnboardingStep.education:
        return _SmartOnboardingStep.lifestyle;
      case _SmartOnboardingStep.motherTongue:
        return _SmartOnboardingStep.lifestyle;
      case _SmartOnboardingStep.lifestyle:
        return _SmartOnboardingStep.family;
      case _SmartOnboardingStep.family:
        return _supportsAstroStep
            ? _SmartOnboardingStep.astro
            : _SmartOnboardingStep.photo;
      case _SmartOnboardingStep.astro:
        return _SmartOnboardingStep.photo;
      case _SmartOnboardingStep.photo:
        return _SmartOnboardingStep.activation;
      default:
        return step;
    }
  }

  _SmartOnboardingStep _previousProfileStep(_SmartOnboardingStep step) {
    switch (step) {
      case _SmartOnboardingStep.mobileOtp:
        return _SmartOnboardingStep.profileForWhom;
      case _SmartOnboardingStep.maritalStatus:
        return _SmartOnboardingStep.profileForWhom;
      case _SmartOnboardingStep.basicInfo:
        return _SmartOnboardingStep.maritalStatus;
      case _SmartOnboardingStep.religionCaste:
        return _SmartOnboardingStep.basicInfo;
      case _SmartOnboardingStep.location:
        return _SmartOnboardingStep.religionCaste;
      case _SmartOnboardingStep.education:
        return _SmartOnboardingStep.location;
      case _SmartOnboardingStep.lifestyle:
        return _SmartOnboardingStep.education;
      case _SmartOnboardingStep.motherTongue:
        return _SmartOnboardingStep.religionCaste;
      case _SmartOnboardingStep.family:
        return _SmartOnboardingStep.lifestyle;
      case _SmartOnboardingStep.astro:
        return _SmartOnboardingStep.family;
      case _SmartOnboardingStep.photo:
        return _supportsAstroStep
            ? _SmartOnboardingStep.astro
            : _SmartOnboardingStep.family;
      case _SmartOnboardingStep.activation:
        return _SmartOnboardingStep.photo;
      default:
        return step;
    }
  }

  String _normalizeMobile(String value) {
    final digits = _displayMobileDigits(value);
    return digits;
  }

  String _displayMobileDigits(String value) {
    var digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 12 && digits.startsWith('91')) {
      digits = digits.substring(2);
    }
    if (digits.length > 10) {
      digits = digits.substring(digits.length - 10);
    }
    return digits;
  }

  String _maskedMobile() {
    final mobile = _normalizeMobile(_mobileController.text);
    if (mobile.length < 4) return '';
    return '******${mobile.substring(mobile.length - 4)}';
  }

  Future<void> _restoreLocalDraft() async {
    final raw = await AppStorage.instance.readOnboardingDraftJson();
    if (raw == null || raw.trim().isEmpty) return;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final draft = Map<String, dynamic>.from(decoded);
      _emailController.text = draft['email']?.toString() ?? '';
      final profileForWhom = onboardingText(draft['profile_for_whom']);
      if (profileForWhom != null) {
        _profileForWhom = _profileOptionFromKey(profileForWhom);
      }
      _warmupGender = optionFromData(draft['warmup_gender']);
      _motherTongue = optionFromData(draft['mother_tongue_option']);
      final clientDraft = draft['client_draft_data'];
      if (clientDraft is Map) {
        _clientDraftData = Map<String, dynamic>.from(clientDraft);
      }
      final language = appLanguageFromCode(draft['locale']?.toString());
      if (language != null) {
        _language = language;
        setAppLanguage(language);
      }
    } catch (_) {
      return;
    }
  }

  Future<void> _saveLocalDraft() async {
    final motherTongue = _motherTongue;
    final draft = <String, dynamic>{
      'locale': _localeCode,
      'step': _step.name,
      'mobile_masked': _maskedMobile(),
      'email': _emailController.text.trim(),
      'profile_for_whom': _profileForWhom?.key,
      if (_warmupGender != null) 'warmup_gender': _warmupGender!.toJson(),
      if (motherTongue?.intId != null)
        'mother_tongue_option': motherTongue!.toJson(),
      if (_clientDraftData.isNotEmpty) 'client_draft_data': _clientDraftData,
    };
    await AppStorage.instance.saveOnboardingDraftJson(jsonEncode(draft));
  }

  Future<void> _setLanguage(AppLanguage next) async {
    if (_language == next) return;
    setState(() {
      _language = next;
      _error = null;
      _message = null;
      _motherTongueError = null;
    });
    setAppLanguage(next);
    await AppStorage.instance.saveLanguage(next);
    await _saveLocalDraft();
    await _loadBootstrap();
  }

  Future<void> _sendOtp() async {
    final mobile = _normalizeMobile(_mobileController.text);
    if (mobile.length != 10) {
      setState(() {
        _error = _t(
          'Enter a valid 10 digit mobile number.',
          'वैध 10 अंकी मोबाइल नंबर भरा.',
        );
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _message = null;
      _motherTongueError = null;
      _fieldErrors = const <String, String>{};
    });

    final data = await ApiClient.sendMobileOtp(
      mobile: mobile,
      locale: _localeCode,
      termsAccepted: true,
      privacyAccepted: true,
      termsVersion: _consentVersion,
      privacyVersion: _consentVersion,
      whatsappAlertsOptIn: _whatsappAlertsOptIn,
    );

    if (!mounted) return;
    final response = MobileOtpSendResponse.fromJson(data);
    final debugOtp = kReleaseMode ? null : response.debugOtp;
    setState(() {
      _loading = false;
      _otpChallenge = response;
      if (response.success && response.challengeId != null) {
        if (debugOtp != null && debugOtp.length == 6) {
          _otpController.text = debugOtp;
          _debugOtpAutoVerifyQueued = true;
          _message = null;
        } else {
          _debugOtpAutoVerifyQueued = false;
          _message = null;
        }
      } else {
        _debugOtpAutoVerifyQueued = false;
        _error =
            response.message ??
            _t('Could not send OTP.', 'OTP पाठवता आला नाही.');
      }
    });

    if (response.success && response.challengeId != null) {
      _startResendCooldown(response.resendAfter);
      await _saveLocalDraft();
      if (debugOtp != null && debugOtp.length == 6) {
        unawaited(_autoVerifyDebugOtp(response.challengeId!, debugOtp));
      }
    }
  }

  void _startResendCooldown(int? seconds) {
    _resendTimer?.cancel();
    final waitSeconds = seconds == null || seconds <= 0 ? 15 : seconds;
    _resendAvailableAt = DateTime.now().add(Duration(seconds: waitSeconds));
    setState(() {
      _resendSecondsRemaining = waitSeconds;
    });
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final target = _resendAvailableAt;
      if (!mounted || target == null) {
        timer.cancel();
        return;
      }
      final remaining = target.difference(DateTime.now()).inSeconds;
      if (remaining <= 0) {
        timer.cancel();
        setState(() {
          _resendSecondsRemaining = 0;
        });
        return;
      }
      setState(() {
        _resendSecondsRemaining = remaining;
      });
    });
  }

  Future<void> _autoVerifyDebugOtp(String challengeId, String otp) async {
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted || kReleaseMode || !_debugOtpAutoVerifyQueued || _loading) {
      return;
    }
    if (_otpChallenge?.challengeId != challengeId ||
        _otpController.text.trim() != otp) {
      return;
    }

    _debugOtpAutoVerifyQueued = false;
    await _verifyOtp();
  }

  Future<void> _verifyOtp() async {
    final mobile = _normalizeMobile(_mobileController.text);
    final challengeId = _otpChallenge?.challengeId;
    final otp = _otpController.text.trim();

    if (challengeId == null || challengeId.isEmpty) {
      setState(() {
        _error = _t('Send OTP first.', 'आधी OTP पाठवा.');
      });
      return;
    }
    if (otp.length != 6) {
      setState(() {
        _error = _t('Enter the 6 digit OTP.', '6 अंकी OTP भरा.');
      });
      return;
    }

    setState(() {
      _loading = true;
      _debugOtpAutoVerifyQueued = false;
      _error = null;
      _message = null;
    });

    try {
      final data = await ApiClient.verifyMobileOtp(
        challengeId: challengeId,
        mobile: mobile,
        otp: otp,
      );

      if (!mounted) return;
      final response = MobileOtpVerifyResponse.fromJson(data);
      if (!response.success) {
        setState(() {
          _loading = false;
          _error =
              response.message ??
              _t('OTP verification failed.', 'OTP पडताळणी अयशस्वी झाली.');
        });
        return;
      }

      final nextAction = response.accountState?.nextAction;
      await _loadBootstrap();
      await _loadStatus(goToStatus: false);

      if (!mounted) return;
      setState(() {
        _loading = false;
        _otpController.clear();
        _message = null;
      });

      if (!mounted) return;
      if (nextAction == 'account_details') {
        setState(() => _step = _SmartOnboardingStep.profileForWhom);
      } else if (nextAction == 'resume_onboarding' ||
          response.accountState?.hasProfile == true) {
        setState(() {
          _step = _status == null
              ? _SmartOnboardingStep.activation
              : _stepFromStatus(_status!);
        });
      } else if (_profileForWhom != null) {
        await _startOnboardingAfterAuth();
        return;
      } else {
        setState(() => _step = _SmartOnboardingStep.profileForWhom);
      }
      await _saveLocalDraft();
    } catch (error) {
      if (!mounted) return;
      final message = error.toString();
      setState(() {
        _loading = false;
        _error = _isTechnicalOnboardingError(message)
            ? _t('OTP verification failed.', 'OTP पडताळणी अयशस्वी झाली.')
            : message;
      });
    }
  }

  Future<void> _loadBootstrap() async {
    try {
      final data = await ApiClient.getOnboardingBootstrap(locale: _localeCode);
      final parsed = OnboardingBootstrap.fromJson(data);
      final genders = parsed.genders.isEmpty
          ? await _loadGenderOptions()
          : parsed.genders;
      final motherTongues = _validMotherTongueOptions(
        parsed.motherTongues.isEmpty
            ? await _loadMotherTongueOptions()
            : parsed.motherTongues,
      );
      if (!mounted) return;
      final baseBootstrap = parsed.profileForWhom.isEmpty
          ? OnboardingBootstrap.fallbackProfileForWhom()
          : parsed;
      setState(() {
        _bootstrap = _bootstrapWithGenders(baseBootstrap, genders);
        _motherTongues = motherTongues;
        _motherTongue = _resolveSelectedMotherTongue(
          _motherTongue,
          motherTongues,
        );
      });
    } catch (_) {
      final genders = await _loadGenderOptions();
      if (!mounted) return;
      setState(() {
        _bootstrap = _bootstrapWithGenders(
          OnboardingBootstrap.fallbackProfileForWhom(),
          genders,
        );
        _motherTongues = _validMotherTongueOptions(_motherTongues);
        _motherTongue = _resolveSelectedMotherTongue(
          _motherTongue,
          _motherTongues,
        );
      });
    }

    if (_isAuthenticated) {
      await _loadChildLivingWithOptions(showLoading: false);
    }
  }

  Future<void> _loadChildLivingWithOptions({bool showLoading = true}) async {
    if (!_isAuthenticated) return;
    if (showLoading && mounted) {
      setState(() {
        _childLivingWithLoading = true;
        _childLivingWithError = null;
      });
    }

    try {
      final results = await ApiClient.getProfileMaritalLifestyleOptions();
      if (!mounted) return;
      setState(() {
        _childLivingWithOptions = OnboardingOption.listFrom(
          results['child_living_with'],
        );
        _childLivingWithError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _childLivingWithError = _t(
          'Child living-with options could not be loaded.',
          'मुलं कोणासोबत राहतात याचे पर्याय लोड झाले नाहीत.',
        );
      });
    } finally {
      if (mounted && showLoading) {
        setState(() {
          _childLivingWithLoading = false;
        });
      }
    }
  }

  Future<void> _retryBootstrapLookups() async {
    setState(() {
      _loading = true;
      _error = null;
      _message = null;
    });
    await _loadBootstrap();
    if (!mounted) return;
    setState(() {
      _loading = false;
    });
  }

  OnboardingBootstrap _bootstrapWithGenders(
    OnboardingBootstrap source,
    List<OnboardingOption> genders,
  ) {
    return OnboardingBootstrap(
      profileForWhom: source.profileForWhom,
      genders: genders,
      motherTongues: source.motherTongues,
      maritalStatuses: source.maritalStatuses,
      heightOptions: source.heightOptions,
      diets: source.diets,
      smokingOptions: source.smokingOptions,
      drinkingOptions: source.drinkingOptions,
      mangalDoshTypes: source.mangalDoshTypes,
      nakshatras: source.nakshatras,
      rashis: source.rashis,
      charanOptions: source.charanOptions,
      childrenRules: source.childrenRules,
      agePolicy: source.agePolicy,
      steps: source.steps,
      raw: source.raw,
    );
  }

  Future<List<OnboardingOption>> _loadGenderOptions() async {
    try {
      final rows = await ApiClient.getGenders();
      return OnboardingOption.listFrom(rows);
    } catch (_) {
      return const <OnboardingOption>[];
    }
  }

  Future<List<OnboardingOption>> _loadMotherTongueOptions() async {
    try {
      final data = await ApiClient.getOnboardingBootstrap(locale: _localeCode);
      final options = _validMotherTongueOptions(
        OnboardingBootstrap.fromJson(data).motherTongues,
      );
      if (options.isNotEmpty) return options;
    } catch (_) {
      // Fall through to the older authenticated lookup if bootstrap is unavailable.
    }

    if (!_isAuthenticated) return const <OnboardingOption>[];

    try {
      final data = await ApiClient.getProfileBasicPhysicalOptions();
      final rows = data['mother_tongues'] ?? <Map<String, dynamic>>[];
      final options = OnboardingOption.listFrom(rows);
      return _validMotherTongueOptions(
        options.map(_localizedMotherTongueOption).toList(),
      );
    } catch (_) {
      return const <OnboardingOption>[];
    }
  }

  Future<void> _startOnboardingAfterAuth({
    bool keepLoadingState = false,
  }) async {
    final option = _profileForWhom;
    final profileForWhom = option?.key;
    if (profileForWhom == null || profileForWhom.isEmpty) {
      setState(() {
        _error = _t(
          'Choose who this profile is for.',
          'हे profile कोणासाठी आहे ते निवडा.',
        );
        _motherTongueError = null;
        _fieldErrors = const <String, String>{};
      });
      return;
    }

    final genderId = _resolvedProfileGenderOption()?.intId;
    final startPayload = <String, dynamic>{
      'profile_for_whom': profileForWhom,
      if (genderId != null) 'gender_id': genderId,
    };
    _debugLogMotherTongueSelection(
      'start_onboarding_payload',
      payload: startPayload,
    );

    if (!keepLoadingState) {
      setState(() {
        _loading = true;
        _error = null;
        _message = null;
        _motherTongueError = null;
        _fieldErrors = const <String, String>{};
      });
    }

    try {
      final data = await ApiClient.startOnboarding(
        profileForWhom: profileForWhom,
        genderId: genderId,
      );
      if (!mounted) return;
      if (data['success'] != true) {
        _debugLogBackendError('start onboarding', data);
        _applySaveFailure(attemptedStep: 'profile_for_whom', response: data);
        return;
      }

      await _loadStatus(goToStatus: false);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _step = _SmartOnboardingStep.maritalStatus;
      });
      _showOnboardingMessage(
        _t('Saved. Choose marital status.', 'Save झाले. वैवाहिक स्थिती निवडा.'),
        type: _OnboardingMessageType.success,
      );
      await _saveLocalDraft();
    } catch (error) {
      if (!mounted) return;
      final message = error.toString();
      setState(() {
        _loading = false;
        _fieldErrors = const <String, String>{};
        _motherTongueError = null;
        _error = _isTechnicalOnboardingError(message)
            ? _genericSaveFailureMessage()
            : message;
      });
    }
  }

  Future<void> _loadStatus({required bool goToStatus}) async {
    try {
      final data = await ApiClient.getOnboardingStatus(locale: _localeCode);
      if (!mounted) return;
      final status = OnboardingStatus.fromJson(data);
      setState(() {
        _status = status;
        _serverDraftData = status.draft?.data ?? <String, dynamic>{};
        _syncProfileForWhomFromDraft();
        if (_profileForWhomChangedAfterMaritalSelection) {
          _clearMaritalStatusDraftData();
        }
        if (goToStatus) _step = _stepFromStatus(status);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
      });
    }
  }

  Map<String, dynamic> _draftStepData(String step) {
    final server = _serverStepData(step);
    final client = _clientDisplayStepData(step, server);
    return <String, dynamic>{...server, ...client};
  }

  Map<String, dynamic> _serverStepData(String step) {
    final data = _serverDraftData[step];
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }

  Map<String, dynamic> _clientStepData(String step) {
    final data = _clientDraftData[step];
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }

  Map<String, dynamic> _clientDisplayStepData(
    String step,
    Map<String, dynamic> server,
  ) {
    final client = _clientStepData(step);
    if (client.isEmpty || server.isEmpty) return const <String, dynamic>{};

    if (step == 'religion_caste') {
      return <String, dynamic>{
        if (_clientOptionMatchesServer(
          client,
          server,
          optionKey: 'religion_option',
          idKey: 'religion_id',
        ))
          'religion_option': client['religion_option'],
        if (_clientOptionMatchesServer(
          client,
          server,
          optionKey: 'caste_option',
          idKey: 'caste_id',
        ))
          'caste_option': client['caste_option'],
        if (_clientOptionMatchesServer(
          client,
          server,
          optionKey: 'sub_caste_option',
          idKey: 'sub_caste_id',
        ))
          'sub_caste_option': client['sub_caste_option'],
      };
    }

    if (step == 'location') {
      final locationMatches = _clientOptionMatchesServer(
        client,
        server,
        optionKey: 'location_option',
        idKey: 'location_id',
      );
      if (!locationMatches) return const <String, dynamic>{};
      return <String, dynamic>{
        'location_option': client['location_option'],
        for (final key in const [
          'country_option',
          'state_option',
          'district_option',
          'local_area_option',
          'village_option',
        ])
          if (client.containsKey(key)) key: client[key],
      };
    }

    return client;
  }

  bool _clientOptionMatchesServer(
    Map<String, dynamic> client,
    Map<String, dynamic> server, {
    required String optionKey,
    required String idKey,
  }) {
    final id = onboardingInt(server[idKey]);
    if (id == null) return false;
    return optionFromData(client[optionKey])?.intId == id;
  }

  Map<String, dynamic> _accountWithPendingEmail() {
    final account = Map<String, dynamic>.from(
      _status?.account ?? const <String, dynamic>{},
    );
    final existingEmail = onboardingText(account['email']);
    final pendingEmail = _emailController.text.trim();
    if (existingEmail == null && pendingEmail.isNotEmpty) {
      account['email'] = pendingEmail;
    }
    return account;
  }

  void _mergeDraftStepData(String step, Map<String, dynamic> data) {
    _serverDraftData = <String, dynamic>{
      ..._serverDraftData,
      step: <String, dynamic>{..._serverStepData(step), ...data},
    };
  }

  static const Set<String> _maritalBasicInfoDraftKeys = <String>{
    'marital_status_id',
    'marital_status_key',
    'marital_status_option',
    'has_children',
    'children',
    'children_count',
    'children_living_with',
    'children_living_with_id',
  };

  void _clearMaritalStatusDraftData() {
    _serverDraftData = _withoutDraftStepKeys(
      _serverDraftData,
      'basic_info',
      _maritalBasicInfoDraftKeys,
    );
    _clientDraftData = _withoutDraftStepKeys(
      _clientDraftData,
      'basic_info',
      _maritalBasicInfoDraftKeys,
    );
  }

  Map<String, dynamic> _withoutDraftStepKeys(
    Map<String, dynamic> source,
    String step,
    Set<String> keys,
  ) {
    final data = source[step];
    if (data is! Map) return source;

    final nextStep = Map<String, dynamic>.from(data)
      ..removeWhere((key, _) => keys.contains(key));
    final next = Map<String, dynamic>.from(source);
    if (nextStep.isEmpty) {
      next.remove(step);
    } else {
      next[step] = nextStep;
    }
    return next;
  }

  void _mergeClientDraftStepData(String step, Map<String, dynamic> data) {
    final clientOnly = _clientOnlyStepData(data);
    if (clientOnly.isEmpty) return;
    _clientDraftData = <String, dynamic>{
      ..._clientDraftData,
      step: <String, dynamic>{..._clientStepData(step), ...clientOnly},
    };
  }

  Map<String, dynamic> _stripClientOnlyStepData(Map<String, dynamic> data) {
    final payload = Map<String, dynamic>.from(data);
    payload.removeWhere((key, _) => _isClientOnlyStepKey(key));
    return payload;
  }

  Map<String, dynamic> _clientOnlyStepData(Map<String, dynamic> data) {
    return Map<String, dynamic>.fromEntries(
      data.entries.where((entry) => _isClientOnlyStepKey(entry.key)),
    );
  }

  bool _isClientOnlyStepKey(String key) => key.endsWith('_option');

  Future<bool> _saveOnboardingStep(
    String step,
    Map<String, dynamic> data, {
    bool saveProfile = true,
    bool advance = true,
  }) async {
    if (!_isAuthenticated) {
      setState(() {
        _step = _SmartOnboardingStep.mobileOtp;
        _error = _t('Please verify mobile first.', 'आधी mobile verify करा.');
        _motherTongueError = null;
        _fieldErrors = const <String, String>{};
      });
      return false;
    }

    final payloadData = await _dataForOnboardingStep(
      step,
      _stripClientOnlyStepData(data),
    );
    if (payloadData == null) return false;
    _debugLogSaveAttempt(step, payloadData);

    setState(() {
      _loading = true;
      _error = null;
      _message = null;
      _motherTongueError = null;
      _fieldErrors = const <String, String>{};
    });

    try {
      final draftResponse = await ApiClient.saveOnboardingDraftStep(
        step: step,
        data: payloadData,
      );
      if (!mounted) return false;
      if (draftResponse['statusCode'] == 401) {
        setState(() {
          _loading = false;
          _step = _SmartOnboardingStep.mobileOtp;
          _error = _t(
            'Session expired. Verify mobile again.',
            'Session expired. Mobile पुन्हा verify करा.',
          );
        });
        return false;
      }
      if (draftResponse['success'] != true) {
        _debugLogBackendError('draft save', draftResponse);
        _applySaveFailure(attemptedStep: step, response: draftResponse);
        return false;
      }

      _mergeDraftStepData(step, payloadData);
      final draft = draftResponse['draft'];
      if (draft is Map && draft['data'] is Map) {
        _serverDraftData = Map<String, dynamic>.from(draft['data'] as Map);
      }

      Map<String, dynamic>? profileResponse;
      if (saveProfile && step != 'photo') {
        profileResponse = await ApiClient.saveOnboardingProfileStep(
          step: step,
          data: payloadData,
        );
        if (!mounted) return false;
        if (profileResponse['success'] != true) {
          _debugLogBackendError('profile save', profileResponse);
          _applySaveFailure(attemptedStep: step, response: profileResponse);
          return false;
        }
        final profileDraft = profileResponse['draft'];
        if (profileDraft is Map && profileDraft['data'] is Map) {
          _serverDraftData = Map<String, dynamic>.from(
            profileDraft['data'] as Map,
          );
        }
      }
      await _loadStatus(goToStatus: false);
      if (!mounted) return false;
      _mergeClientDraftStepData(step, data);
      setState(() {
        _loading = false;
        if (advance) {
          _step = step == 'photo'
              ? _SmartOnboardingStep.activation
              : _nextProfileStep(_step);
        }
      });
      _showOnboardingMessage(
        _t('Saved.', 'Save झाले.'),
        type: _OnboardingMessageType.success,
      );
      await _saveLocalDraft();
      return true;
    } catch (error) {
      if (!mounted) return false;
      final message = error.toString();
      setState(() {
        _loading = false;
        _error = _isTechnicalOnboardingError(message)
            ? _genericSaveFailureMessage()
            : message;
        _message = null;
      });
      return false;
    }
  }

  Future<bool> _saveMaritalStatusStep(Map<String, dynamic> payload) async {
    final saved = await _saveOnboardingStep(
      'basic_info',
      payload,
      saveProfile: true,
      advance: false,
    );
    if (!mounted || !saved) return false;
    setState(() {
      _profileForWhomChangedAfterMaritalSelection = false;
      _step = _SmartOnboardingStep.basicInfo;
    });
    await _saveLocalDraft();
    return true;
  }

  void _selectMotherTongue(OnboardingOption? option) {
    final selected = option?.intId == null
        ? null
        : _resolveSelectedMotherTongue(option, _motherTongueOptions());
    setState(() {
      _motherTongue = selected?.intId == null ? null : selected;
      _error = null;
      _message = null;
      _motherTongueError = null;
      _fieldErrors = const <String, String>{};
    });
    unawaited(_saveLocalDraft());
  }

  Future<bool> _saveCommunityMotherTongue(OnboardingOption? option) async {
    final selected = option?.intId == null
        ? null
        : _resolveSelectedMotherTongue(option, _motherTongueOptions());
    if (selected == null) {
      _showMappedFieldError('mother_tongue_id');
      return false;
    }

    if (_motherTongue?.identity != selected.identity) {
      setState(() {
        _motherTongue = selected;
        _error = null;
        _message = null;
        _motherTongueError = null;
        _fieldErrors = const <String, String>{};
      });
      await _saveLocalDraft();
    }

    final motherTongueId = await _requireMotherTongueId();
    if (!mounted || motherTongueId == null) return false;

    return _saveOnboardingStep(
      'basic_info',
      <String, dynamic>{'mother_tongue_id': motherTongueId},
      saveProfile: true,
      advance: false,
    );
  }

  Future<void> _continueFromMotherTongue() async {
    if (!_isAuthenticated) {
      setState(() {
        _step = _SmartOnboardingStep.mobileOtp;
        _error = _t('Please verify mobile first.', 'आधी mobile verify करा.');
        _motherTongueError = null;
        _fieldErrors = const <String, String>{};
      });
      return;
    }

    if (_motherTongue == null) {
      _showMappedFieldError('mother_tongue_id');
      return;
    }

    final motherTongueId = await _requireMotherTongueId();
    if (!mounted || motherTongueId == null) return;

    final saved = await _saveOnboardingStep(
      'basic_info',
      <String, dynamic>{'mother_tongue_id': motherTongueId},
      saveProfile: true,
      advance: false,
    );
    if (!mounted || !saved) return;

    setState(() {
      _step = _SmartOnboardingStep.lifestyle;
    });
    await _saveLocalDraft();
  }

  Future<Map<String, dynamic>?> _dataForOnboardingStep(
    String step,
    Map<String, dynamic> data,
  ) async {
    if (step != 'basic_info') {
      return data;
    }

    int? motherTongueId;
    if (_motherTongue != null || _draftMotherTongueId() != null) {
      motherTongueId = await _resolveMotherTongueId();
      if (!mounted) return null;
    }

    final payload = <String, dynamic>{
      ...data,
      if (motherTongueId != null) 'mother_tongue_id': motherTongueId,
    };
    if (motherTongueId != null) {
      _debugLogMotherTongueSelection('basic_info_payload', payload: payload);
    }
    return payload;
  }

  int? _draftMotherTongueId() {
    return onboardingInt(
          _draftStepData('profile_for_whom')['mother_tongue_id'],
        ) ??
        onboardingInt(_draftStepData('basic_info')['mother_tongue_id']);
  }

  Future<int?> _resolveMotherTongueId() async {
    var motherTongue = _motherTongue;
    final selectedId = motherTongue?.intId;
    if (selectedId != null) {
      return selectedId;
    }

    final draftId = _draftMotherTongueId();
    if (draftId != null) {
      final existing = optionById(_motherTongueOptions(), draftId);
      if (existing != null && mounted) {
        setState(() {
          _motherTongue = existing;
        });
      }
      _debugLogMotherTongueSelection(
        'resolved_from_server_draft',
        payload: <String, dynamic>{'mother_tongue_id': draftId},
      );
      return draftId;
    }

    final options = await _loadMotherTongueOptions();
    motherTongue = _resolveSelectedMotherTongue(motherTongue, options);
    if (mounted) {
      setState(() {
        _motherTongues = options;
        _motherTongue = motherTongue;
      });
    }

    final resolvedId = motherTongue?.intId;
    if (resolvedId != null) {
      _debugLogMotherTongueSelection(
        'resolved_from_lookup',
        payload: <String, dynamic>{'mother_tongue_id': resolvedId},
      );
      return resolvedId;
    }

    if (mounted && _motherTongue != null) {
      setState(() {
        _motherTongue = null;
      });
    }
    return null;
  }

  void _syncMotherTongueFromDraft() {
    final draftId = _draftMotherTongueId();
    if (draftId == null) {
      _motherTongue = _resolveSelectedMotherTongue(
        _motherTongue,
        _motherTongueOptions(),
      );
      return;
    }

    final motherTongue = optionById(_motherTongueOptions(), draftId);
    if (motherTongue != null) {
      _motherTongue = motherTongue;
      return;
    }

    final current = _motherTongue;
    if (current?.intId == draftId) {
      return;
    }

    _motherTongue = OnboardingOption(
      id: draftId,
      key: current?.key,
      label:
          current?.label ??
          (_motherTongueOptions().isEmpty
              ? onboardingSelectedLoadingLabel(_localeCode)
              : onboardingSelectedFailureLabel(_localeCode)),
      translationMissing: current?.translationMissing ?? false,
      popular: current?.popular ?? false,
      meta: current?.meta ?? const <String, dynamic>{},
      raw: current?.raw ?? const <String, dynamic>{},
    );
  }

  Future<int?> _requireMotherTongueId() async {
    final motherTongueId = await _resolveMotherTongueId();
    if (!mounted) return null;
    if (motherTongueId == null) {
      _showMappedFieldError('mother_tongue_id');
      return null;
    }
    return motherTongueId;
  }

  void _goBackOneStep() {
    if (_step == _SmartOnboardingStep.mobileOtp &&
        _otpChallenge?.challengeId != null) {
      _editMobileNumber();
      return;
    }

    setState(() {
      _error = null;
      _message = null;
      _motherTongueError = null;
      _fieldErrors = const <String, String>{};
      _step = _previousProfileStep(_step);
    });
  }

  Future<bool> _handleRouteBack() async {
    if (_loading) return false;

    if (_canStepBackWithinOnboarding) {
      _goBackOneStep();
      return false;
    }

    return true;
  }

  void _handleAppBarBack() {
    if (_canShowOnboardingBack) {
      _goBackOneStep();
      return;
    }

    Navigator.of(context).maybePop();
  }

  void _showStepMessage(String message) {
    _showOnboardingMessage(message, type: _OnboardingMessageType.warning);
  }

  void _syncProfileForWhomFromDraft() {
    final data = _draftStepData('profile_for_whom');
    final value = onboardingText(data['profile_for_whom']);
    if (value != null) {
      _profileForWhom = _profileOptionFromKey(value);
    }

    final gender = optionById(_bootstrap.genders, data['gender_id']);
    if (gender != null) {
      _warmupGender = gender;
    }

    _syncMotherTongueFromDraft();
  }

  String _profileDetailsTitle() {
    switch (_profileForWhomKey?.toLowerCase()) {
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
      case 'relative':
        switch (_effectiveProfileGenderKey()) {
          case 'female':
            return _t('Bride relative’s details', 'नातेवाईक वधूची माहिती');
          case 'male':
            return _t('Groom relative’s details', 'नातेवाईक वराची माहिती');
        }
        return _t('Relative’s details', 'नातेवाईकाची माहिती');
      case 'friend':
        switch (_effectiveProfileGenderKey()) {
          case 'female':
            return _t('Friend’s details', 'मैत्रिणीची माहिती');
          case 'male':
            return _t('Friend’s details', 'मित्राची माहिती');
        }
        return _t('Friend’s details', 'मित्र/मैत्रिणीची माहिती');
    }

    return _t('Basic details', 'मूलभूत माहिती');
  }

  Future<void> _continueFromProfileForWhom() async {
    if (_profileForWhom == null) {
      setState(() {
        _error = _t(
          'Choose who this profile is for.',
          'ही प्रोफाइल कोणासाठी आहे ते निवडा.',
        );
        _motherTongueError = null;
        _fieldErrors = const <String, String>{};
      });
      return;
    }

    final resolvedGender = _resolvedProfileGenderOption();
    if (_needsGenderWarmup && _warmupGender == null) {
      setState(() {
        _error = _genderPromptLabel();
        _motherTongueError = null;
        _fieldErrors = const <String, String>{};
      });
      return;
    }
    if (resolvedGender == null) {
      setState(() {
        _error = _t('Select gender again.', 'लिंग पुन्हा निवडा.');
        _motherTongueError = null;
        _fieldErrors = const <String, String>{};
      });
      return;
    }

    _debugLogMotherTongueSelection(
      'profile_for_whom_continue',
      payload: <String, dynamic>{
        'profile_for_whom': _profileForWhom!.key,
        if (resolvedGender.intId != null) 'gender_id': resolvedGender.intId,
      },
    );

    if (_needsGenderWarmup) {
      _warmupGender = resolvedGender;
    }
    await _saveLocalDraft();
    await _continueAfterWarmup();
  }

  OnboardingOption? _resolvedProfileGenderOption() {
    final desired = _genderMode == 'male' || _genderMode == 'female'
        ? _genderMode
        : _genderOptionKey(_warmupGender);
    if (desired != 'male' && desired != 'female') return null;

    final byKey = optionByKey(_bootstrap.genders, desired);
    if (byKey?.intId != null) return byKey;

    for (final option in _bootstrap.genders) {
      final key = _genderOptionKey(option);
      if (key == desired && option.intId != null) return option;
    }
    return null;
  }

  Future<void> _continueAfterWarmup() async {
    if (_isAuthenticated) {
      await _startOnboardingAfterAuth();
      return;
    }

    setState(() {
      _error = null;
      _message = null;
      _motherTongueError = null;
      _fieldErrors = const <String, String>{};
      _step = _SmartOnboardingStep.mobileOtp;
    });
  }

  void _startExistingMobileFlow() {
    setState(() {
      _error = null;
      _message = null;
      _motherTongueError = null;
      _fieldErrors = const <String, String>{};
      _step = _SmartOnboardingStep.mobileOtp;
    });
  }

  void _editMobileNumber() {
    setState(() {
      _otpChallenge = null;
      _otpController.clear();
      _debugOtpAutoVerifyQueued = false;
      _resendTimer?.cancel();
      _resendAvailableAt = null;
      _resendSecondsRemaining = 0;
      _error = null;
      _message = null;
    });
  }

  List<OnboardingOption> _profileForWhomOptions() {
    final options = _bootstrap.profileForWhom;
    return options.isEmpty
        ? OnboardingBootstrap.fallbackProfileForWhom().profileForWhom
        : options;
  }

  OnboardingOption _profileOptionFromKey(String key) {
    return optionByKey(_profileForWhomOptions(), key) ??
        OnboardingOption(key: key, label: _relationLabelForKey(key));
  }

  String _relationLabel(OnboardingOption option) {
    return _relationLabelForKey(option.key ?? option.label);
  }

  String _relationLabelForKey(String key) {
    switch (key.toLowerCase()) {
      case 'self':
        return _t('Myself', 'स्वतःसाठी');
      case 'son':
        return _t('Son', 'मुलगा');
      case 'daughter':
        return _t('Daughter', 'मुलगी');
      case 'brother':
        return _t('Brother', 'भाऊ');
      case 'sister':
        return _t('Sister', 'बहीण');
      case 'relative':
        return _t('Relative', 'नातेवाईक');
      case 'friend':
        return _t('Friend', 'मित्र / मैत्रीण');
    }

    return key;
  }

  List<OnboardingOption> _profileGenderOptions() {
    final genders = _bootstrap.genders;
    OnboardingOption? male = optionByKey(genders, 'male');
    OnboardingOption? female = optionByKey(genders, 'female');

    for (final option in genders) {
      final label = option.label.toLowerCase();
      if (male == null && (label == 'male' || label.contains('male'))) {
        male = option;
      }
      if (female == null && (label == 'female' || label.contains('female'))) {
        female = option;
      }
    }

    return <OnboardingOption>[
      male ?? OnboardingOption(key: 'male', label: _t('Male', 'पुरुष')),
      female ?? OnboardingOption(key: 'female', label: _t('Female', 'स्त्री')),
    ];
  }

  String _genderOptionKey(OnboardingOption? option) {
    final key = option?.key?.trim().toLowerCase();
    if (key == 'male' || key == 'female') return key!;

    final label = option?.label.trim().toLowerCase() ?? '';
    if (label.contains('female') ||
        label.contains('स्त्री') ||
        label.contains('महिला') ||
        label.contains('मुलगी') ||
        label.contains('वधू')) {
      return 'female';
    }
    if (label.contains('male') ||
        label.contains('पुरुष') ||
        label.contains('मुलगा') ||
        label.contains('वर')) {
      return 'male';
    }

    return key ?? label;
  }

  String _genderPromptLabel() {
    switch (_profileForWhomKey?.toLowerCase()) {
      case 'self':
        return _t('Select your gender', 'तुमचे लिंग निवडा');
      case 'relative':
        return _t("Select relative's gender", 'नातेवाईकाचे लिंग निवडा');
      case 'friend':
        return _t("Select friend's gender", 'मित्र/मैत्रिणीचे लिंग निवडा');
    }

    return _t('Select gender', 'लिंग निवडा');
  }

  String _motherTongueLabel() {
    switch (_profileForWhomKey?.toLowerCase()) {
      case 'self':
        return _t('Your mother tongue', 'तुमची मातृभाषा');
      case 'son':
      case 'brother':
        return _t('His mother tongue', 'त्याची मातृभाषा');
      case 'daughter':
      case 'sister':
        return _t('Her mother tongue', 'तिची मातृभाषा');
      case 'relative':
      case 'friend':
        switch (_genderOptionKey(_warmupGender)) {
          case 'male':
            return _t('His mother tongue', 'त्याची मातृभाषा');
          case 'female':
            return _t('Her mother tongue', 'तिची मातृभाषा');
        }
    }

    return _t('Select mother tongue', 'मातृभाषा निवडा');
  }

  List<OnboardingOption> _motherTongueOptions() {
    return _validMotherTongueOptions(_motherTongues);
  }

  List<OnboardingOption> _validMotherTongueOptions(
    List<OnboardingOption> options,
  ) {
    return options.where((option) => option.intId != null).toList();
  }

  OnboardingOption _localizedMotherTongueOption(OnboardingOption option) {
    if (_language != AppLanguage.marathi) return option;

    final direct = onboardingText(option.raw['label_mr']);
    final mapped =
        direct ??
        _motherTongueMarathiLabel(option.key) ??
        _motherTongueMarathiLabel(option.label);
    if (mapped == null || mapped == option.label) return option;

    return OnboardingOption(
      id: option.id,
      key: option.key,
      label: mapped,
      translationMissing: option.translationMissing,
      popular: option.popular,
      meta: option.meta,
      raw: option.raw,
    );
  }

  String? _motherTongueMarathiLabel(String? value) {
    final key = value?.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]+'),
      '_',
    );
    if (key == null || key.isEmpty) return null;

    const labels = <String, String>{
      'marathi': 'मराठी',
      'hindi': 'हिंदी',
      'english': 'इंग्रजी',
      'gujarati': 'गुजराती',
      'tamil': 'तमिळ',
      'telugu': 'तेलुगू',
      'kannada': 'कन्नड',
      'bengali': 'बंगाली',
      'malayalam': 'मल्याळम',
      'punjabi': 'पंजाबी',
      'other': 'इतर',
    };
    return labels[key];
  }

  OnboardingOption? _resolveSelectedMotherTongue(
    OnboardingOption? selected,
    List<OnboardingOption> options,
  ) {
    if (selected == null) return null;
    final validOptions = _validMotherTongueOptions(options);
    if (selected.intId != null) {
      return optionById(validOptions, selected.intId) ?? selected;
    }
    if (validOptions.isEmpty) return null;

    final byKey = optionByKey(validOptions, selected.key);
    if (byKey != null) return byKey;

    final localizedLabel = _motherTongueMarathiLabel(selected.label);
    if (localizedLabel != null) {
      for (final option in validOptions) {
        if (option.label == localizedLabel) return option;
      }
    }

    final wanted = _normalizeLookupLabel(selected.label);
    for (final option in validOptions) {
      if (_normalizeLookupLabel(option.label) == wanted) {
        return option;
      }
    }

    return null;
  }

  String _normalizeLookupLabel(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[\s\-_]+'), '');
  }

  Future<PagedLookupResponse> _staticOptionsPage(
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

  @override
  Widget build(BuildContext context) {
    final showChrome = _showCreateProfileChrome;
    final showBack = showChrome && _canShowOnboardingBack;

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _handleRouteBack();
        if (shouldPop && context.mounted) {
          Navigator.of(context).maybePop();
        }
      },
      child: Scaffold(
        appBar: showChrome
            ? AppBar(
                automaticallyImplyLeading: false,
                titleSpacing: 0,
                title: _CreateProfileTopBar(
                  title: _t('Create Profile', 'प्रोफाइल तयार करा'),
                  showBack: showBack,
                  onBack: _handleAppBarBack,
                  backTooltip: MaterialLocalizations.of(
                    context,
                  ).backButtonTooltip,
                  languageToggle: _LanguageToggle(
                    isMarathi: _language == AppLanguage.marathi,
                    onEnglish: _loading
                        ? null
                        : () {
                            _setLanguage(AppLanguage.english);
                          },
                    onMarathi: _loading
                        ? null
                        : () {
                            _setLanguage(AppLanguage.marathi);
                          },
                  ),
                ),
              )
            : null,
        body: SafeArea(
          child: Stack(
            children: [
              ListView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  _step == _SmartOnboardingStep.profileForWhom ? 72 : 16,
                ),
                children: [
                  if (showChrome) ...[
                    _buildHeader(context),
                    const SizedBox(height: 10),
                  ],
                  _buildStepCard(context),
                  if (_step == _SmartOnboardingStep.mobileOtp &&
                      _otpChallenge?.challengeId == null) ...[
                    const SizedBox(height: 28),
                    _TermsPrivacyFooter(
                      isMarathi: _language == AppLanguage.marathi,
                    ),
                  ],
                ],
              ),
              if (_step == _SmartOnboardingStep.profileForWhom)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 10,
                  child: _AlreadyRegisteredLink(
                    text: _t(
                      'Already registered? Verify mobile to continue',
                      'आधीच नोंदणी केली आहे? मोबाइल पडताळून पुढे जा',
                    ),
                    onPressed: _loading ? null : _startExistingMobileFlow,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return _HeaderMessageBand(
      key: const ValueKey('header_message_band'),
      data: _headerMessageData(context),
    );
  }

  _HeaderMessageData _headerMessageData(BuildContext context) {
    final error = _error;
    if (error != null) {
      return _HeaderMessageData(
        key: 'error:$error',
        icon: Icons.error_outline,
        color: Colors.red.shade700,
        title: _t('Please check this information.', 'कृपया ही माहिती तपासा.'),
        subline: error,
      );
    }

    final message = _message;
    if (message != null) {
      final color = switch (_messageType) {
        _OnboardingMessageType.success => Colors.green.shade700,
        _OnboardingMessageType.warning => Colors.amber.shade800,
        _OnboardingMessageType.info => Colors.grey.shade700,
      };
      final icon = switch (_messageType) {
        _OnboardingMessageType.success => Icons.check_circle_outline,
        _OnboardingMessageType.warning => Icons.info_outline,
        _OnboardingMessageType.info => Icons.info_outline,
      };

      return _HeaderMessageData(
        key: 'message:${_messageType.name}:$message',
        icon: icon,
        color: color,
        title: message,
        subline: '',
      );
    }

    if (_messageGapVisible) {
      return const _HeaderMessageData(
        key: 'message-gap',
        icon: Icons.notifications_none,
        color: Colors.transparent,
        title: '',
        subline: '',
        visible: false,
      );
    }

    if (_loading) {
      return _HeaderMessageData(
        key: 'guidance-hold:${_step.name}',
        icon: Icons.notifications_none,
        color: Colors.transparent,
        title: '',
        subline: '',
        visible: false,
      );
    }

    return _HeaderMessageData(
      key:
          'guidance:${_step.name}:${_profileForWhomKey ?? ''}:${_effectiveProfileGenderKey()}',
      icon: Icons.notifications_active_outlined,
      color: Colors.grey.shade700,
      title: _guidanceTitleForStep(),
      subline: _guidanceSublineForStep(),
      centerTitle: _step == _SmartOnboardingStep.maritalStatus,
    );
  }

  String _guidanceTitleForStep() {
    switch (_step) {
      case _SmartOnboardingStep.profileForWhom:
        return _t('Start with profile owner', 'प्रोफाइल कोणासाठी आहे ते निवडा');
      case _SmartOnboardingStep.mobileOtp:
        return _t('Verify mobile number', 'मोबाइल नंबर verify करा');
      case _SmartOnboardingStep.maritalStatus:
        return _t('Marital status', 'वैवाहिक स्थिती');
      case _SmartOnboardingStep.basicInfo:
        return _profileDetailsTitle();
      case _SmartOnboardingStep.religionCaste:
        return _t('Choose community details', 'समुदायाची माहिती निवडा');
      case _SmartOnboardingStep.location:
        return _t('Location details', 'राहण्याचे ठिकाण');
      case _SmartOnboardingStep.education:
        return _t('Education & Career', 'शिक्षण आणि करिअर');
      case _SmartOnboardingStep.motherTongue:
        return _motherTongueLabel();
      case _SmartOnboardingStep.lifestyle:
        return _t('Lifestyle details', 'Lifestyle माहिती');
      case _SmartOnboardingStep.family:
        return _t('Family details', 'कुटुंबाची माहिती');
      case _SmartOnboardingStep.astro:
        return _t('Astro details', 'ज्योतिष माहिती');
      case _SmartOnboardingStep.photo:
        return _t('Profile photo', 'Profile photo');
      case _SmartOnboardingStep.activation:
        return _t('Final checklist', 'Final checklist');
    }
  }

  String _guidanceSublineForStep() {
    final subjectEn = _profileSubjectPossessiveEnglish();
    final subjectMr = _profileSubjectPossessiveMarathi();

    switch (_step) {
      case _SmartOnboardingStep.profileForWhom:
        return _t(
          'This keeps every next question relevant to the right person.',
          'या निवडीवरून पुढचे प्रश्न योग्य नात्यानुसार दिसतील.',
        );
      case _SmartOnboardingStep.mobileOtp:
        return _t(
          'Verification keeps $subjectEn profile safe and recoverable.',
          'Mobile verify केल्याने $subjectMr profile सुरक्षित राहते.',
        );
      case _SmartOnboardingStep.maritalStatus:
        return _t(
          'This helps avoid irrelevant questions and match filters.',
          '$subjectMr वैवाहिक स्थिती योग्य matches filter करायला मदत करते.',
        );
      case _SmartOnboardingStep.basicInfo:
        return _t(
          'Accurate basics improve $subjectEn match recommendations.',
          '$subjectMr अचूक माहिती योग्य matches सुचवायला मदत करते.',
        );
      case _SmartOnboardingStep.religionCaste:
        return _t(
          'Community preferences help keep suggestions relevant.',
          'समुदायाची माहिती suggestions अधिक relevant ठेवते.',
        );
      case _SmartOnboardingStep.location:
        return _t(
          'Location helps us show nearby and practical matches.',
          '$subjectMr राहण्याचे ठिकाण nearby matches दाखवायला मदत करते.',
        );
      case _SmartOnboardingStep.education:
        return _t(
          'Education and career details improve match quality.',
          '$subjectMr शिक्षण आणि कामाची माहिती match quality वाढवते.',
        );
      case _SmartOnboardingStep.motherTongue:
        return _t(
          'Language comfort can make conversations easier.',
          '$subjectMr मातृभाषा संवाद सोपा करायला मदत करते.',
        );
      case _SmartOnboardingStep.lifestyle:
        return _t(
          'Lifestyle choices help compare day-to-day compatibility.',
          '$subjectMr सवयी आणि lifestyle जुळवायला मदत करतात.',
        );
      case _SmartOnboardingStep.family:
        return _t(
          'Family context builds trust before conversations begin.',
          '$subjectMr कुटुंबाची माहिती विश्वास वाढवते.',
        );
      case _SmartOnboardingStep.astro:
        return _t(
          'Astro details can help families who prefer horoscope matching.',
          '$subjectMr ज्योतिष माहिती horoscope matching साठी उपयोगी ठरते.',
        );
      case _SmartOnboardingStep.photo:
        return _t(
          'A clear photo usually improves response quality.',
          'स्पष्ट profile photo response quality वाढवू शकतो.',
        );
      case _SmartOnboardingStep.activation:
        return _t(
          'Complete the checklist to make the profile ready.',
          'Checklist पूर्ण केल्यावर profile पुढील टप्प्यासाठी तयार होईल.',
        );
    }
  }

  String _profileSubjectPossessiveEnglish() {
    switch (_profileForWhomKey?.toLowerCase()) {
      case 'self':
        return 'your';
      case 'son':
        return "your son's";
      case 'daughter':
        return "your daughter's";
      case 'brother':
        return "your brother's";
      case 'sister':
        return "your sister's";
      case 'relative':
        switch (_effectiveProfileGenderKey()) {
          case 'female':
            return "your bride relative's";
          case 'male':
            return "your groom relative's";
        }
        return "your relative's";
      case 'friend':
        switch (_effectiveProfileGenderKey()) {
          case 'female':
            return "your female friend's";
          case 'male':
            return "your male friend's";
        }
        return "your friend's";
    }
    return 'this';
  }

  String _profileSubjectPossessiveMarathi() {
    switch (_profileForWhomKey?.toLowerCase()) {
      case 'self':
        return 'तुमची';
      case 'son':
        return 'मुलाची';
      case 'daughter':
        return 'मुलीची';
      case 'brother':
        return 'भावाची';
      case 'sister':
        return 'बहिणीची';
      case 'relative':
        switch (_effectiveProfileGenderKey()) {
          case 'female':
            return 'नातेवाईक वधूची';
          case 'male':
            return 'नातेवाईक वराची';
        }
        return 'नातेवाईकाची';
      case 'friend':
        switch (_effectiveProfileGenderKey()) {
          case 'male':
            return 'मित्राची';
          case 'female':
            return 'मैत्रिणीची';
        }
        return 'मित्र/मैत्रिणीची';
    }
    return 'या profile ची';
  }

  Widget _buildStepCard(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: switch (_step) {
            _SmartOnboardingStep.profileForWhom => _buildProfileForWhomStep(
              context,
            ),
            _SmartOnboardingStep.mobileOtp => _buildMobileOtpStep(context),
            _SmartOnboardingStep.maritalStatus => MaritalStatusStep(
              title: '',
              data: _draftStepData('basic_info'),
              maritalStatuses: _bootstrap.maritalStatuses,
              childrenRules: _bootstrap.childrenRules,
              childLivingWithOptions: _childLivingWithOptions,
              childLivingWithLoading: _childLivingWithLoading,
              childLivingWithError: _childLivingWithError,
              profileForWhom: _profileForWhom,
              gender: _resolvedProfileGenderOption(),
              fieldErrors: _fieldErrorsForStep(
                OnboardingFieldErrorMap.basicInfoStep,
              ),
              locale: _localeCode,
              loading: _loading,
              onSave: _saveMaritalStatusStep,
              onBack: _goBackOneStep,
              onMessage: _showStepMessage,
              onRetryLookups: _retryBootstrapLookups,
              onFieldEdited: _clearCurrentFeedback,
            ),
            _SmartOnboardingStep.basicInfo => BasicCandidateInfoStep(
              data: _draftStepData('basic_info'),
              bootstrap: _bootstrap,
              account: _status?.account ?? const <String, dynamic>{},
              profileForWhom: _profileForWhom,
              warmupGender: _warmupGender,
              fieldErrors: _fieldErrorsForStep(
                OnboardingFieldErrorMap.basicInfoStep,
              ),
              locale: _localeCode,
              loading: _loading,
              showHeader: false,
              onSave: _saveOnboardingStep,
              onBack: _goBackOneStep,
              onMessage: _showStepMessage,
              onFieldEdited: _clearCurrentFeedback,
            ),
            _SmartOnboardingStep.religionCaste => ReligionCasteStep(
              data: _draftStepData('religion_caste'),
              motherTongues: _motherTongueOptions(),
              selectedMotherTongue: _motherTongue,
              motherTongueError:
                  _motherTongueError ??
                  _motherTongueFieldError(
                    _fieldErrorsForStep(OnboardingFieldErrorMap.communityStep),
                  ),
              locale: _localeCode,
              loading: _loading,
              onSave: _saveOnboardingStep,
              onSaveMotherTongue: _saveCommunityMotherTongue,
              onMotherTongueChanged: _selectMotherTongue,
              onBack: _goBackOneStep,
              onMessage: _showStepMessage,
            ),
            _SmartOnboardingStep.location => LocationStep(
              data: _draftStepData('location'),
              locale: _localeCode,
              loading: _loading,
              onSave: _saveOnboardingStep,
              onBack: _goBackOneStep,
              onMessage: _showStepMessage,
            ),
            _SmartOnboardingStep.education => EducationCareerStep(
              educationData: _draftStepData('education'),
              careerData: _draftStepData('career'),
              locale: _localeCode,
              loading: _loading,
              onSave: _saveOnboardingStep,
              onBack: _goBackOneStep,
              onMessage: _showStepMessage,
            ),
            _SmartOnboardingStep.motherTongue => _buildMotherTongueStep(
              context,
            ),
            _SmartOnboardingStep.lifestyle => LifestyleStep(
              data: _draftStepData('lifestyle'),
              bootstrap: _bootstrap,
              locale: _localeCode,
              loading: _loading,
              onSave: _saveOnboardingStep,
              onBack: _goBackOneStep,
            ),
            _SmartOnboardingStep.family => FamilyOptionalStep(
              data: _draftStepData('family'),
              locale: _localeCode,
              loading: _loading,
              onSave: _saveOnboardingStep,
              onBack: _goBackOneStep,
            ),
            _SmartOnboardingStep.astro => AstroStep(
              data: _draftStepData('astro'),
              bootstrap: _bootstrap,
              locale: _localeCode,
              loading: _loading,
              onSave: _saveOnboardingStep,
              onBack: _goBackOneStep,
            ),
            _SmartOnboardingStep.photo => PhotoStep(
              status: _status,
              locale: _localeCode,
              loading: _loading,
              onSave: _saveOnboardingStep,
              onBack: _goBackOneStep,
              onRefresh: () => _loadStatus(goToStatus: false),
            ),
            _SmartOnboardingStep.activation => ActivationChecklistStep(
              status: _status,
              account: _accountWithPendingEmail(),
              locale: _localeCode,
              loading: _loading,
              onSaveEmail: _saveOptionalEmail,
              onRefresh: () => _loadStatus(goToStatus: false),
              onBack: _goBackOneStep,
            ),
          },
        ),
      ),
    );
  }

  Widget _buildMobileOtpStep(BuildContext context) {
    final otpSent = _otpChallenge?.challengeId != null;
    return otpSent
        ? _buildOtpVerificationStep(context)
        : _buildMobileNumberEntryStep(context);
  }

  Widget _buildMobileNumberEntryStep(BuildContext context) {
    return AutofillGroup(
      key: const ValueKey('mobile_number'),
      child: _StepContent(
        title: _t('Verify mobile number', 'मोबाइल नंबर verify करा'),
        children: [
          Text(
            _t(
              'We will send a 6 digit code to continue.',
              'पुढे जाण्यासाठी ६ अंकी code पाठवू.',
            ),
          ),
          const SizedBox(height: 12),
          _mobileNumberField(context),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: _whatsappAlertsOptIn,
            dense: true,
            visualDensity: VisualDensity.compact,
            onChanged: _loading
                ? null
                : (value) =>
                      setState(() => _whatsappAlertsOptIn = value ?? false),
            title: Text(
              _t(
                'Send profile alerts on WhatsApp',
                'WhatsApp वर profile alerts पाठवा',
              ),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _loading ? null : _sendOtp,
            child: _loading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_t('Get OTP', 'OTP मिळवा')),
          ),
        ],
      ),
    );
  }

  Widget _mobileNumberField(BuildContext context) {
    final borderColor = Colors.grey.shade300;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t('Mobile number *', 'मोबाइल नंबर *'),
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Container(
                height: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(10),
                  ),
                  border: Border(right: BorderSide(color: borderColor)),
                ),
                child: const Text(
                  '+91',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _mobileController,
                  enabled: !_loading,
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  inputFormatters: const [_OnboardingMobileInputFormatter()],
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintText: _t('Mobile number', 'मोबाइल नंबर'),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOtpVerificationStep(BuildContext context) {
    final mobile = _normalizeMobile(_mobileController.text);
    final debugOtpAvailable = !kReleaseMode && _otpChallenge?.debugOtp != null;

    return AutofillGroup(
      key: const ValueKey('otp_verification'),
      child: _StepContent(
        title: _t('Verify Mobile Number', 'मोबाइल नंबर verify करा'),
        children: [
          Text(
            _t(
              'We’ve sent a verification code to',
              'verification code पाठवला आहे',
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Text(
                '+91 $mobile',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              TextButton(
                onPressed: _loading ? null : _editMobileNumber,
                child: Text(_t('Edit', 'Edit')),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _otpCodeField(context),
          if (debugOtpAvailable) ...[
            const SizedBox(height: 8),
            Text(
              _t('Test OTP filled automatically.', 'Test OTP आपोआप भरला आहे.'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.green.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _loading ? null : _verifyOtp,
            child: _loading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_t('Verify and continue', 'पडताळून पुढे जा')),
          ),
          const SizedBox(height: 12),
          _buildResendControl(context),
        ],
      ),
    );
  }

  Widget _otpCodeField(BuildContext context) {
    final theme = Theme.of(context);
    final focusedColor = Theme.of(context).colorScheme.primary;
    final filledDigits = _otpController.text.trim().length.clamp(0, 6);

    return Container(
      height: 76,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 24,
            right: 24,
            bottom: 14,
            child: Row(
              children: List.generate(6, (index) {
                final active = index < filledDigits;
                return Expanded(
                  child: Container(
                    height: 3,
                    margin: EdgeInsets.only(right: index == 5 ? 0 : 10),
                    decoration: BoxDecoration(
                      color: active ? focusedColor : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                );
              }),
            ),
          ),
          TextField(
            controller: _otpController,
            enabled: !_loading,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            maxLength: 6,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: 12,
              color: Colors.grey.shade900,
              height: 1,
            ),
            cursorColor: focusedColor,
            cursorWidth: 2.2,
            decoration: const InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              counterText: '',
              contentPadding: EdgeInsets.only(left: 18, right: 6, bottom: 10),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }

  Widget _buildResendControl(BuildContext context) {
    if (_resendSecondsRemaining > 0) {
      return Text(
        _t(
          'Didn’t get the code yet? Resend in ${_resendSecondsRemaining}s',
          'Code मिळाला नाही? ${_resendSecondsRemaining}s नंतर पुन्हा पाठवा',
        ),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(_t('Didn’t get the code yet?', 'Code मिळाला नाही?')),
        TextButton(
          onPressed: _loading ? null : _sendOtp,
          child: Text(_t('Resend code', 'पुन्हा पाठवा')),
        ),
      ],
    );
  }

  Widget _buildGenderSegmentedControl(BuildContext context) {
    final options = _profileGenderOptions();

    return Row(
      children: List.generate(options.length, (index) {
        final option = options[index];
        final selected = _warmupGender?.identity == option.identity;
        final key = _genderOptionKey(option);
        final label = key == 'male'
            ? _t('Male', 'पुरुष')
            : key == 'female'
            ? _t('Female', 'स्त्री')
            : option.label;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: index == 0 ? 0 : 10),
            child: _buildSelectableOptionCard(
              context,
              label: label,
              selected: selected,
              minHeight: 52,
              onTap: _loading
                  ? null
                  : () {
                      setState(() {
                        _warmupGender = option;
                        _error = null;
                        _message = null;
                        _motherTongueError = null;
                        _fieldErrors = const <String, String>{};
                      });
                      _saveLocalDraft();
                    },
            ),
          ),
        );
      }),
    );
  }

  Widget _buildProfileForWhomStep(BuildContext context) {
    final options = _orderedProfileForWhomOptions();
    final primary = options.isEmpty ? null : options.first;
    final secondary = primary == null
        ? const <OnboardingOption>[]
        : options.skip(1).toList();

    return _StepContent(
      key: const ValueKey('profile_for_whom'),
      title: _t(
        'I am creating this profile for',
        'कोणासाठी प्रोफाइल तयार करत आहात',
      ),
      titleStyle: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: Colors.grey.shade800,
        fontWeight: FontWeight.w800,
      ),
      children: [
        if (primary != null)
          _buildProfileChoiceCard(context, primary, primary: true),
        if (secondary.isNotEmpty) ...[
          const SizedBox(height: 12),
          ..._buildProfileChoiceRows(context, secondary),
        ],
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: _profileForWhom != null && _needsGenderWarmup
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 22),
                    Text(
                      _genderPromptLabel(),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildGenderSegmentedControl(context),
                  ],
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 16),
        OnboardingContinueButton(
          label: _t('Continue', 'पुढे जा'),
          loading: _loading,
          enabled: _canContinueProfileForWhom,
          onPressed: _continueFromProfileForWhom,
        ),
      ],
    );
  }

  Widget _buildMotherTongueStep(BuildContext context) {
    return _StepContent(
      key: const ValueKey('mother_tongue'),
      title: _motherTongueLabel(),
      titleStyle: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      children: [
        OnboardingErrorHighlight(
          hasError: _motherTongueError != null,
          pulseKey: 'mother_tongue:$_fieldErrorPulseToken:$_motherTongueError',
          child: OnboardingPickerField(
            label: _t('Mother tongue *', 'मातृभाषा *'),
            selectedItems: _motherTongue?.intId == null
                ? const []
                : [_motherTongue!],
            placeholder: _t('Select mother tongue', 'मातृभाषा निवडा'),
            searchHint: _t('Search mother tongue', 'मातृभाषा शोधा'),
            errorText: _motherTongueError,
            loadPage: (query, page, limit) =>
                _staticOptionsPage(_motherTongueOptions(), query, page, limit),
            onChanged: (items) {
              final selected = items.isEmpty
                  ? null
                  : _resolveSelectedMotherTongue(
                      items.first,
                      _motherTongueOptions(),
                    );
              setState(() {
                _motherTongue = selected?.intId == null ? null : selected;
                _error = null;
                _message = null;
                _motherTongueError = null;
                _fieldErrors = const <String, String>{};
              });
              _saveLocalDraft();
            },
          ),
        ),
        const SizedBox(height: 16),
        OnboardingContinueButton(
          label: _t('Continue', 'पुढे जा'),
          loading: _loading,
          enabled: _motherTongue?.intId != null,
          onPressed: _continueFromMotherTongue,
        ),
      ],
    );
  }

  List<OnboardingOption> _orderedProfileForWhomOptions() {
    final options = _profileForWhomOptions();
    final ordered = <OnboardingOption>[];
    final used = <String>{};

    for (final key in const <String>[
      'self',
      'son',
      'daughter',
      'brother',
      'sister',
      'relative',
      'friend',
    ]) {
      for (final option in options) {
        final optionKey = (option.key ?? option.label).trim().toLowerCase();
        if (optionKey == key && used.add(option.identity)) {
          ordered.add(option);
          break;
        }
      }
    }

    for (final option in options) {
      if (used.add(option.identity)) {
        ordered.add(option);
      }
    }

    return ordered;
  }

  Widget _buildProfileChoiceCard(
    BuildContext context,
    OnboardingOption option, {
    bool primary = false,
  }) {
    final selected = _profileForWhom?.identity == option.identity;
    return _buildSelectableOptionCard(
      context,
      label: _relationLabel(option),
      selected: selected,
      primary: primary,
      minHeight: primary ? 58 : 54,
      onTap: _loading
          ? null
          : () {
              final relationChanged =
                  _profileForWhom != null &&
                  _profileForWhom!.identity != option.identity;
              setState(() {
                if (relationChanged) {
                  _profileForWhomChangedAfterMaritalSelection = true;
                  _clearMaritalStatusDraftData();
                }
                _profileForWhom = option;
                _warmupGender = null;
                _error = null;
                _message = null;
                _motherTongueError = null;
                _fieldErrors = const <String, String>{};
              });
              _saveLocalDraft();
            },
    );
  }

  List<Widget> _buildProfileChoiceRows(
    BuildContext context,
    List<OnboardingOption> options,
  ) {
    final rows = <Widget>[];
    for (var index = 0; index < options.length; index += 2) {
      final first = options[index];
      final second = index + 1 < options.length ? options[index + 1] : null;
      rows.add(
        Padding(
          padding: EdgeInsets.only(top: index == 0 ? 0 : 10),
          child: Row(
            children: [
              Expanded(child: _buildProfileChoiceCard(context, first)),
              const SizedBox(width: 10),
              Expanded(
                child: second == null
                    ? const SizedBox.shrink()
                    : _buildProfileChoiceCard(context, second),
              ),
            ],
          ),
        ),
      );
    }
    return rows;
  }

  Widget _buildSelectableOptionCard(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback? onTap,
    bool primary = false,
    double minHeight = 54,
  }) {
    return OnboardingSelectablePill(
      label: label,
      selected: selected,
      onTap: onTap,
      prominent: primary,
      minHeight: minHeight,
      fontSize: primary ? 16.5 : null,
    );
  }

  Future<String?> _saveOptionalEmail(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty) return null;
    final creatorName =
        onboardingText(_status?.account['creator_name']) ??
        onboardingText(_status?.account['name']);
    if (creatorName == null) {
      return _t(
        'Add your name before saving email.',
        'Email save करण्याआधी नाव भरा.',
      );
    }

    final response = await ApiClient.updateAccountDetails(
      creatorName: creatorName,
      email: trimmed,
      locale: _localeCode,
      whatsappAlertsOptIn: _whatsappAlertsOptIn,
    );
    if (response['success'] != true) {
      return readableApiError(
        response,
        _t('Could not save email.', 'Email save झाला नाही.'),
      );
    }

    await _loadStatus(goToStatus: false);
    return null;
  }
}

class _TermsPrivacyFooter extends StatelessWidget {
  const _TermsPrivacyFooter({required this.isMarathi});

  final bool isMarathi;

  String _t(String english, String marathi) => isMarathi ? marathi : english;

  void _showUnavailable(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _t(
            '$label link is not available yet.',
            '$label link अजून उपलब्ध नाही.',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Colors.grey.shade700,
      fontSize: 11,
      height: 1.2,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _t('By registering, I agree to the ', 'नोंदणी करून मी '),
                style: textStyle,
              ),
              _FooterLink(
                label: 'T & C',
                onTap: () => _showUnavailable(context, 'T & C'),
              ),
              Text(_t(' and ', ' आणि '), style: textStyle),
              _FooterLink(
                label: 'Privacy Policy',
                onTap: () => _showUnavailable(context, 'Privacy Policy'),
              ),
              Text(_t('.', ' मान्य करतो/करते.'), style: textStyle),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.blue,
          decoration: TextDecoration.underline,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CreateProfileTopBar extends StatelessWidget {
  const _CreateProfileTopBar({
    required this.title,
    required this.showBack,
    required this.onBack,
    required this.backTooltip,
    required this.languageToggle,
  });

  final String title;
  final bool showBack;
  final VoidCallback onBack;
  final String backTooltip;
  final Widget languageToggle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kToolbarHeight,
      width: double.infinity,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 56,
            child: Center(
              child: showBack
                  ? IconButton(
                      tooltip: backTooltip,
                      icon: const Icon(Icons.arrow_back),
                      onPressed: onBack,
                    )
                  : const SizedBox(width: 48, height: 48),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    title,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 138,
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: languageToggle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderMessageData {
  const _HeaderMessageData({
    required this.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subline,
    this.visible = true,
    this.centerTitle = false,
  });

  final String key;
  final IconData icon;
  final Color color;
  final String title;
  final String subline;
  final bool visible;
  final bool centerTitle;
}

class _HeaderMessageBand extends StatelessWidget {
  const _HeaderMessageBand({super.key, required this.data});

  final _HeaderMessageData data;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      width: double.infinity,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.06, 0),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
        child: data.visible
            ? Container(
                key: ValueKey<String>(
                  '${data.key}:${data.title}:${data.subline}',
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: data.color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: data.color.withValues(alpha: 0.24)),
                ),
                child: Row(
                  children: [
                    Container(
                      height: 34,
                      width: 34,
                      decoration: BoxDecoration(
                        color: data.color.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(data.icon, color: data.color, size: 19),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final titleStyle = Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: Colors.grey.shade900,
                                fontSize: data.centerTitle ? 15.5 : null,
                                fontWeight: data.centerTitle
                                    ? FontWeight.w900
                                    : FontWeight.w800,
                                height: 1.08,
                                decoration: TextDecoration.none,
                              );
                          final titleAlignment = data.centerTitle
                              ? Alignment.center
                              : Alignment.centerLeft;
                          final titleTextAlign = data.centerTitle
                              ? TextAlign.center
                              : TextAlign.left;
                          final subline = data.subline.trim();
                          final sublineStyle = Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                                height: 1.14,
                                decoration: TextDecoration.none,
                              );

                          if (subline.isEmpty) {
                            return Align(
                              alignment: titleAlignment,
                              child: Text(
                                data.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: titleTextAlign,
                                style: titleStyle,
                              ),
                            );
                          }

                          final availableHeight = constraints.maxHeight;
                          const titleHeight = 20.0;
                          const lineGap = 6.0;
                          final sublineHeight =
                              (availableHeight - titleHeight - lineGap)
                                  .clamp(16.0, 22.0)
                                  .toDouble();

                          return ClipRect(
                            child: Stack(
                              clipBehavior: Clip.hardEdge,
                              children: [
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  top: 0,
                                  height: titleHeight,
                                  child: Align(
                                    alignment: titleAlignment,
                                    child: Text(
                                      data.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: titleTextAlign,
                                      style: titleStyle,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  height: sublineHeight,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: _LoopingSublineText(
                                      text: subline,
                                      style: sublineStyle,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              )
            : const SizedBox(key: ValueKey<String>('message-gap')),
      ),
    );
  }
}

class _LoopingSublineText extends StatefulWidget {
  const _LoopingSublineText({required this.text, this.style});

  final String text;
  final TextStyle? style;

  @override
  State<_LoopingSublineText> createState() => _LoopingSublineTextState();
}

class _LoopingSublineTextState extends State<_LoopingSublineText>
    with SingleTickerProviderStateMixin {
  static const double _gap = 48;
  static const double _pixelsPerSecond = 64;

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant _LoopingSublineText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _controller
        ..reset()
        ..repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = (widget.style ?? DefaultTextStyle.of(context).style).copyWith(
      decoration: TextDecoration.none,
    );
    final direction = Directionality.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.maxWidth.isFinite) {
          return Text(
            widget.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          );
        }

        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: 1,
          textDirection: direction,
        )..layout();
        final textWidth = painter.width;
        final lineHeight = painter.height.ceilToDouble() + 2;
        if (textWidth <= constraints.maxWidth) {
          return SizedBox(
            height: lineHeight,
            width: constraints.maxWidth,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
          );
        }

        final travel = textWidth + _gap;
        final durationMs = ((travel / _pixelsPerSecond) * 1000)
            .clamp(7000, 18000)
            .round();
        final duration = Duration(milliseconds: durationMs);
        if (_controller.duration != duration) {
          _controller.duration = duration;
          if (!_controller.isAnimating) {
            _controller.repeat();
          }
        }

        return ClipRect(
          child: SizedBox(
            height: lineHeight,
            width: constraints.maxWidth,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final offset = -travel * _controller.value;
                return Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Positioned(
                      left: offset,
                      top: 0,
                      height: lineHeight,
                      child: Text(widget.text, maxLines: 1, style: style),
                    ),
                    Positioned(
                      left: offset + travel,
                      top: 0,
                      height: lineHeight,
                      child: Text(widget.text, maxLines: 1, style: style),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _LanguageToggle extends StatelessWidget {
  const _LanguageToggle({
    required this.isMarathi,
    required this.onEnglish,
    required this.onMarathi,
  });

  final bool isMarathi;
  final VoidCallback? onEnglish;
  final VoidCallback? onMarathi;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LanguageToggleItem(
            label: 'English',
            active: !isMarathi,
            onPressed: onEnglish,
          ),
          _LanguageToggleItem(
            label: 'मराठी',
            active: isMarathi,
            onPressed: onMarathi,
          ),
        ],
      ),
    );
  }
}

class _LanguageToggleItem extends StatelessWidget {
  const _LanguageToggleItem({
    required this.label,
    required this.active,
    required this.onPressed,
  });

  final String label;
  final bool active;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: active ? null : onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          boxShadow: active
              ? const [BoxShadow(color: Colors.black12, blurRadius: 3)]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? const Color(0xFFB91C1C) : Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _AlreadyRegisteredLink extends StatelessWidget {
  const _AlreadyRegisteredLink({required this.text, required this.onPressed});

  final String text;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: Colors.grey.shade600,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        child: FittedBox(fit: BoxFit.scaleDown, child: Text(text, maxLines: 1)),
      ),
    );
  }
}

class _StepContent extends StatelessWidget {
  const _StepContent({
    super.key,
    required this.title,
    required this.children,
    this.titleStyle,
  });

  final String title;
  final List<Widget> children;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style:
              titleStyle ??
              Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 14),
        ...children,
      ],
    );
  }
}

class _OnboardingMobileInputFormatter extends TextInputFormatter {
  const _OnboardingMobileInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final selectionEnd = newValue.selection.end
        .clamp(0, newValue.text.length)
        .toInt();
    var selectionDigits = newValue.text
        .substring(0, selectionEnd)
        .replaceAll(RegExp(r'\D'), '')
        .length;

    if (digits.length == 12 && digits.startsWith('91')) {
      digits = digits.substring(2);
      selectionDigits = (selectionDigits - 2).clamp(0, digits.length).toInt();
    }

    if (digits.length > 10) {
      return oldValue;
    }

    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(
        offset: selectionDigits.clamp(0, digits.length).toInt(),
      ),
    );
  }
}
