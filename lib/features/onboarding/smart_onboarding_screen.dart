import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_client.dart';
import '../../core/app_consent.dart';
import '../../core/app_language.dart';
import '../../core/app_storage.dart';
import '../../core/email_hint_service.dart';
import '../../core/mobile_number.dart';
import '../../core/member_entry_route.dart';
import '../../main.dart';
import 'models/mobile_otp_models.dart';
import 'models/onboarding_field_error_map.dart';
import 'models/onboarding_bootstrap.dart';
import 'models/onboarding_option.dart';
import 'models/onboarding_status.dart';
import 'models/paged_lookup_response.dart';
import 'steps/astro_step.dart';
import 'steps/basic_candidate_info_step.dart';
import 'steps/education_career_step.dart';
import 'steps/family_optional_step.dart';
import 'about_voice_ssot.dart';
import 'steps/lifestyle_step.dart';
import 'steps/location_step.dart';
import 'steps/marital_status_step.dart';
import 'steps/onboarding_step_helpers.dart';
import 'steps/onboarding_step_scaffold.dart';
import 'steps/partner_preference_review_step.dart';
import 'steps/photo_step.dart';
import 'steps/religion_caste_step.dart';
import 'steps/registration_success_step.dart';
import 'steps/set_password_step.dart';
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
  astro,
  family,
  registrationComplete,
  photo,
  partnerPreference,
  setPassword,
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
  /// How long the post-verification lookups may take before the member is let
  /// in regardless. See [_prepareAfterVerification].
  static const Duration _postVerificationBudget = Duration(seconds: 12);

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
  Timer? _otpAutoVerifyTimer;
  Timer? _resendTimer;
  Timer? _messageTimer;
  String? _lastOtpAutoVerifyAttempt;

  bool _loading = false;
  bool _childLivingWithLoading = false;
  bool _profileForWhomChangedAfterMaritalSelection = false;
  bool _whatsappAlertsOptIn = true;
  bool _otpAutoAdvancePending = false;
  int _resendSecondsRemaining = 0;
  String? _error;
  String? _message;
  String? _profileForWhomError;
  String? _warmupGenderError;
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
        _mobileController.text = MobileNumberInput.normalize(mobile);
      }
    }
    _initialize();
  }

  @override
  void dispose() {
    _mobileController.dispose();
    _otpController.dispose();
    _emailController.dispose();
    _otpAutoVerifyTimer?.cancel();
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
      _profileForWhomError = null;
      _warmupGenderError = null;
      _motherTongueError = null;
      _fieldErrors = const <String, String>{};
    });

    if (!autoHide) return;
    // Clear straight into step guidance — no blank gap frame.
    _messageTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted || _message != message) return;
      setState(() {
        _message = null;
      });
    });
  }

  void _clearCurrentFeedback() {
    _messageTimer?.cancel();
    setState(() {
      _error = null;
      _message = null;
      _profileForWhomError = null;
      _warmupGenderError = null;
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
        return appText.pleaseEnterFullName;
      case 'date_of_birth':
        return appText.pleaseCheckDateOfBirth;
      case 'height_cm':
        return appText.pleaseCheckHeight;
      case 'mother_tongue_id':
      case 'mother_tongue':
        return appText.pleaseSelectMotherTongueAgain;
      case 'has_children':
        return appText.pleaseSelectWhetherThereAreChildren;
      case 'children':
        return appText.pleaseCheckChildDetails;
    }

    if (field.startsWith('children.')) {
      if (field.endsWith('.gender')) {
        return appText.selectChildGender;
      }
      if (field.endsWith('.age')) {
        return appText.enterValidChildAge;
      }
      if (field.endsWith('.child_living_with_id')) {
        return appText.pleaseSelectLivingWithAgain;
      }
      return appText.pleaseCheckChildDetails;
    }

    if (_isTechnicalOnboardingError(raw)) {
      return appText.pleaseCheckThisField;
    }

    return raw;
  }

  String _genericSaveFailureMessage() {
    return appText.weCouldNotSaveThisInformation;
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
      _SmartOnboardingStep.registrationComplete => 'registration_complete',
      _SmartOnboardingStep.partnerPreference => 'partner_preferences',
      _SmartOnboardingStep.setPassword => 'set_password',
      _SmartOnboardingStep.photo => 'photo',
      _SmartOnboardingStep.mobileOtp => 'mobile_otp',
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
      'registration_complete' => _SmartOnboardingStep.registrationComplete,
      'partner_preferences' => _SmartOnboardingStep.partnerPreference,
      'set_password' => _SmartOnboardingStep.setPassword,
      'photo' => _SmartOnboardingStep.photo,
      'activation' => _SmartOnboardingStep.partnerPreference,
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

  bool get _isPostRegistrationStep =>
      _step == _SmartOnboardingStep.registrationComplete ||
      _step == _SmartOnboardingStep.photo ||
      _step == _SmartOnboardingStep.partnerPreference ||
      _step == _SmartOnboardingStep.setPassword;

  bool get _showCreateProfileChrome =>
      _step != _SmartOnboardingStep.mobileOtp && !_isPostRegistrationStep;

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

  bool _hasCompletedServerStep(String step) {
    return _status?.draft?.completedSteps.contains(step) == true;
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
        if (_supportsAstroStep && !_hasCompletedServerStep('astro')) {
          return _SmartOnboardingStep.astro;
        }
        return _SmartOnboardingStep.family;
      case 'astro':
        if (!_supportsAstroStep) {
          return _hasCompletedServerStep('family')
              ? _SmartOnboardingStep.registrationComplete
              : _SmartOnboardingStep.family;
        }
        if (_hasCompletedServerStep('astro') &&
            _hasCompletedServerStep('family')) {
          return _SmartOnboardingStep.registrationComplete;
        }
        return _SmartOnboardingStep.astro;
      case 'photo':
        if (!_hasCompletedServerStep('family')) {
          return _SmartOnboardingStep.family;
        }
        return _SmartOnboardingStep.registrationComplete;
      case 'activation':
        if (_hasCompletedServerStep('photo') &&
            !_hasReviewedPartnerPreference()) {
          return _SmartOnboardingStep.partnerPreference;
        }
        return _SmartOnboardingStep.partnerPreference;
    }

    return _SmartOnboardingStep.partnerPreference;
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
        return _supportsAstroStep
            ? _SmartOnboardingStep.astro
            : _SmartOnboardingStep.family;
      case _SmartOnboardingStep.astro:
        return _SmartOnboardingStep.family;
      case _SmartOnboardingStep.family:
        return _SmartOnboardingStep.registrationComplete;
      case _SmartOnboardingStep.registrationComplete:
        return _SmartOnboardingStep.photo;
      case _SmartOnboardingStep.photo:
        return _SmartOnboardingStep.partnerPreference;
      case _SmartOnboardingStep.partnerPreference:
        return _SmartOnboardingStep.setPassword;
      case _SmartOnboardingStep.setPassword:
        return _SmartOnboardingStep.setPassword;
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
      case _SmartOnboardingStep.astro:
        return _SmartOnboardingStep.lifestyle;
      case _SmartOnboardingStep.family:
        return _supportsAstroStep
            ? _SmartOnboardingStep.astro
            : _SmartOnboardingStep.lifestyle;
      case _SmartOnboardingStep.registrationComplete:
        return _SmartOnboardingStep.family;
      case _SmartOnboardingStep.photo:
        return _SmartOnboardingStep.registrationComplete;
      case _SmartOnboardingStep.partnerPreference:
        return _SmartOnboardingStep.photo;
      case _SmartOnboardingStep.setPassword:
        return _SmartOnboardingStep.partnerPreference;
      default:
        return step;
    }
  }

  String _maskedMobile() {
    final mobile = MobileNumberInput.normalize(_mobileController.text);
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
    final mobile = MobileNumberInput.normalize(_mobileController.text);
    if (mobile.length != 10) {
      setState(() {
        _error = appText.enterAValid10DigitMobile;
      });
      return;
    }
    setState(() {
      _loading = true;
      _otpAutoAdvancePending = false;
      _lastOtpAutoVerifyAttempt = null;
      _error = null;
      _message = null;
      _motherTongueError = null;
      _fieldErrors = const <String, String>{};
    });
    _otpAutoVerifyTimer?.cancel();

    final Map<String, dynamic> data;
    try {
      data = await ApiClient.sendMobileOtp(
        mobile: mobile,
        locale: _localeCode,
        termsAccepted: true,
        privacyAccepted: true,
        termsVersion: AppConsent.version,
        privacyVersion: AppConsent.version,
        whatsappAlertsOptIn: _whatsappAlertsOptIn,
      );
    } catch (error) {
      // This call used to have no catch at all. A dropped connection or a
      // stalled socket threw past it, so `_loading` was never cleared and the
      // member was left holding a "Sending OTP…" spinner that never resolved
      // and never said anything had gone wrong.
      if (!mounted) return;
      final message = error.toString();
      setState(() {
        _loading = false;
        _error = _isTechnicalOnboardingError(message)
            ? appText.couldNotSendOtp
            : message;
      });
      return;
    }

    if (!mounted) return;
    final response = MobileOtpSendResponse.fromJson(data);
    final debugOtp = response.debugOtp;
    setState(() {
      _loading = false;
      _otpChallenge = response;
      if (response.success && response.challengeId != null) {
        if (debugOtp != null && debugOtp.length == 6) {
          _otpController.text = debugOtp;
        }
        _message = null;
      } else {
        _error =
            response.message ??
            appText.couldNotSendOtp;
      }
    });

    if (response.success && response.challengeId != null) {
      _startResendCooldown(response.resendAfter);
      _scheduleOtpAutoVerify();
      await _saveLocalDraft();
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

  void _handleOtpChanged(String value) {
    final otp = value.trim();
    if (otp.length != 6 || otp != _lastOtpAutoVerifyAttempt) {
      _lastOtpAutoVerifyAttempt = null;
    }
    setState(() {
      _error = null;
      _message = null;
      _otpAutoAdvancePending = false;
    });
    _scheduleOtpAutoVerify();
  }

  void _scheduleOtpAutoVerify() {
    _otpAutoVerifyTimer?.cancel();
    final otp = _otpController.text.trim();
    if (_loading ||
        _otpAutoAdvancePending ||
        _otpChallenge?.challengeId == null ||
        otp.length != 6 ||
        _lastOtpAutoVerifyAttempt == otp) {
      return;
    }

    _otpAutoVerifyTimer = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted || _loading || _otpAutoAdvancePending) return;
      final currentOtp = _otpController.text.trim();
      if (currentOtp != otp || _otpChallenge?.challengeId == null) return;
      _lastOtpAutoVerifyAttempt = otp;
      unawaited(_verifyOtp(autoTriggered: true));
    });
  }

  Future<void> _verifyOtp({bool autoTriggered = false}) async {
    if (_loading || _otpAutoAdvancePending) return;
    _otpAutoVerifyTimer?.cancel();
    final mobile = MobileNumberInput.normalize(_mobileController.text);
    final challengeId = _otpChallenge?.challengeId;
    final otp = _otpController.text.trim();

    if (challengeId == null || challengeId.isEmpty) {
      setState(() {
        _error = appText.sendOtpFirst;
      });
      return;
    }
    if (otp.length != 6) {
      setState(() {
        _error = appText.enterThe6DigitOtp;
      });
      return;
    }

    setState(() {
      _loading = true;
      _otpAutoAdvancePending = false;
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
          _otpAutoAdvancePending = false;
          _error =
              response.message ??
              appText.otpVerificationFailed;
        });
        return;
      }

      if (autoTriggered) {
        setState(() {
          _otpAutoAdvancePending = true;
        });
        await Future<void>.delayed(const Duration(milliseconds: 900));
        if (!mounted) return;
        if (_otpController.text.trim() != otp) {
          // The code changed under us during the hand-off pause. This used to
          // `return` with `_loading` and `_otpAutoAdvancePending` both still
          // true, which disables the OTP field, disables the verify button and
          // makes `_handleRouteBack` refuse to pop — a dead screen with a
          // spinner on it, while the token from this very call was already
          // stored and the member was signed in. Release the screen instead.
          setState(() {
            _loading = false;
            _otpAutoAdvancePending = false;
          });
          return;
        }
      }

      final nextAction = response.accountState?.nextAction;
      // The token is stored by now, so the member IS signed in. What follows
      // only decides WHICH step to land on, so it gets a hard time budget: a
      // slow lookup must never be the reason a verified member is left staring
      // at a spinner they cannot back out of.
      await _prepareAfterVerification();

      if (!mounted) return;
      setState(() {
        _loading = false;
        _otpAutoAdvancePending = false;
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
              ? _SmartOnboardingStep.partnerPreference
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
        _otpAutoAdvancePending = false;
        _error = _isTechnicalOnboardingError(message)
            ? appText.otpVerificationFailed
            : message;
      });
    } finally {
      // Last line of defence. Whatever route this method took out, it must not
      // leave the verify spinner turning: that state disables the whole step
      // and blocks Back, so there is no way for the member to recover from it.
      if (mounted && (_loading || _otpAutoAdvancePending)) {
        setState(() {
          _loading = false;
          _otpAutoAdvancePending = false;
        });
      }
    }
  }

  /// Loads what the first post-verification step needs, under a hard ceiling.
  ///
  /// Both calls already swallow their own errors, but they are still network
  /// calls, and until this budget existed they were awaited unbounded while
  /// `_loading` was true — up to six round trips between a successful verify
  /// and the screen moving. That is the gap where a member with a perfectly
  /// good session sat watching a spinner "for a long time".
  Future<void> _prepareAfterVerification() async {
    try {
      await Future<void>(() async {
        await _loadBootstrap();
        await _loadStatus(goToStatus: false);
      }).timeout(_postVerificationBudget);
    } catch (_) {
      // Deliberately ignored. The step resolver below copes with a missing or
      // stale `_status`, and getting in beats getting the perfect first step.
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
        _childLivingWithError = appText.childLivingWithOptionsCouldNot;
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
    // One field replaced, the rest carried. Listing them by hand here is what
    // dropped horoscopeRules and rashiAshtakoota, which silently turned off the
    // astro step's nakshatra / rashi / charan filtering.
    return source.copyWith(genders: genders);
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
        final message = appText.chooseWhoThisProfileIsFor;
        _profileForWhomError = message;
        _warmupGenderError = null;
        _fieldErrorPulseToken++;
        _error = message;
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
        _profileForWhomError = null;
        _warmupGenderError = null;
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
        appText.savedChooseMaritalStatus,
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
      // Keep client hierarchy for UI restore when navigating back. Previously
      // a failed location_id match dropped district+ while country/state still
      // showed via defaults — looking like "everything below district vanished".
      return <String, dynamic>{
        for (final key in const [
          'country_option',
          'state_option',
          'district_option',
          'local_area_option',
          'village_option',
          'location_option',
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

  String? _profileAboutText() {
    final profile = _status?.profile?.raw ?? const <String, dynamic>{};
    return onboardingText(profile['narrative_about_me']) ??
        onboardingText(ApiClient.currentUserProfile?['narrative_about_me']);
  }

  AboutVoice get _aboutVoice => AboutVoice.resolve(
        profileForWhom: _profileForWhomKey,
        genderKey: _effectiveProfileGenderKey(),
      );

  List<AboutTemplateSuggestion> _aboutTemplateSuggestions() {
    final voice = _aboutVoice;
    final facts = <String>[
      if (_ageFact() case final value?) value,
      if (_heightFact() case final value?) value,
      if (_maritalFact() case final value?) value,
      if (_communityFact() case final value?) value,
      if (_educationFact() case final value?) value,
      if (_careerFact() case final value?) value,
    ];
    final factText = facts.take(4).join(' ');
    return voice.templates(factText: factText);
  }

  String? _optionLabelFromDraft(Map<String, dynamic> data, String key) {
    return optionFromData(data[key])?.label;
  }

  String? _ageFact() {
    final dob = onboardingText(_draftStepData('basic_info')['date_of_birth']);
    if (dob == null) return null;
    final parsed = DateTime.tryParse(dob);
    if (parsed == null) return null;
    final now = DateTime.now();
    var age = now.year - parsed.year;
    if (now.month < parsed.month ||
        (now.month == parsed.month && now.day < parsed.day)) {
      age--;
    }
    if (age < 18 || age > 90) return null;
    return _aboutVoice.ageFact(age);
  }

  String? _heightFact() {
    final cm = onboardingInt(_draftStepData('basic_info')['height_cm']);
    if (cm == null || cm <= 0) return null;
    final inches = (cm / 2.54).round();
    final feet = inches ~/ 12;
    final remaining = inches % 12;
    return appText.aboutFactHeight(feet, remaining);
  }

  String? _maritalFact() {
    final basic = _draftStepData('basic_info');
    final label =
        _optionLabelFromDraft(basic, 'marital_status_option') ??
        onboardingText(basic['marital_status_key']);
    return label == null ? null : appText.aboutFactMaritalStatus(label);
  }

  String? _communityFact() {
    final community = _draftStepData('religion_caste');
    final religion = _optionLabelFromDraft(community, 'religion_option');
    final caste = _optionLabelFromDraft(community, 'caste_option');
    final parts = [religion, caste].whereType<String>().toList();
    if (parts.isEmpty) return null;
    return appText.aboutFactCommunity(parts.join(', '));
  }

  String? _educationFact() {
    final education = _draftStepData('education');
    final slots = education['education_slots'];
    if (slots is! List) return null;
    final labels = slots
        .whereType<Map>()
        .map((row) => onboardingText(row['label']))
        .whereType<String>()
        .take(2)
        .toList();
    if (labels.isEmpty) return null;
    return appText.aboutFactEducation(labels.join(', '));
  }

  String? _careerFact() {
    final career = _draftStepData('career');
    final occupation = _optionLabelFromDraft(career, 'occupation_option');
    final workingWith = _optionLabelFromDraft(career, 'working_with_option');
    final label = occupation ?? workingWith;
    return label == null ? null : _aboutVoice.careerFact(label);
  }

  bool _hasReviewedPartnerPreference() {
    final local = _clientStepData('partner_preferences');
    if (onboardingBool(local['saved']) == true) return true;
    final preferences = _status?.preferences;
    if (preferences == null) return false;
    return onboardingBool(preferences['has_auto_draft']) == true ||
        onboardingText(preferences['generated_at']) != null;
  }

  void _markPartnerPreferenceReviewed() {
    _clientDraftData = <String, dynamic>{
      ..._clientDraftData,
      'partner_preferences': <String, dynamic>{
        ..._clientStepData('partner_preferences'),
        'saved': true,
      },
    };
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

  _SmartOnboardingStep? _serverNextStepFromResponse(
    Map<String, dynamic>? profileResponse,
    Map<String, dynamic> draftResponse,
  ) {
    String? stepFrom(Map<String, dynamic>? response) {
      if (response == null) return null;
      final directNext = onboardingText(response['next_step']);
      if (directNext != null) return directNext;

      final draft = response['draft'];
      if (draft is Map) {
        return onboardingText(draft['next_step']);
      }
      return null;
    }

    final serverStep =
        stepFrom(profileResponse) ??
        stepFrom(draftResponse) ??
        _status?.nextStep ??
        _status?.draft?.currentStep;
    if (serverStep == null) return null;
    return _stepFromServerName(serverStep);
  }

  /// Bounces back to mobile OTP when the session is gone.
  ///
  /// Extracted so the optional-step path, which may legitimately skip
  /// `_saveOnboardingStep` entirely, can reuse this guard instead of carrying
  /// a second copy of it.
  bool _requireOnboardingSession() {
    if (_isAuthenticated) return true;
    setState(() {
      _step = _SmartOnboardingStep.mobileOtp;
      _error = appText.pleaseVerifyMobileFirst;
      _profileForWhomError = null;
      _warmupGenderError = null;
      _motherTongueError = null;
      _fieldErrors = const <String, String>{};
    });
    return false;
  }

  Future<bool> _saveOnboardingStep(
    String step,
    Map<String, dynamic> data, {
    bool saveProfile = true,
    bool advance = true,
  }) async {
    if (!_requireOnboardingSession()) return false;

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
          _error = appText.sessionExpiredVerifyMobileAgain;
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
      final serverNextStep = _serverNextStepFromResponse(
        profileResponse,
        draftResponse,
      );
      setState(() {
        _loading = false;
        if (advance) {
          _step = step == 'photo'
              ? _SmartOnboardingStep.partnerPreference
              : serverNextStep ?? _nextProfileStep(_step);
        }
      });
      _showOnboardingMessage(
        appText.saved,
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
      _profileForWhomError = null;
      _warmupGenderError = null;
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
        _error = appText.pleaseVerifyMobileFirst;
        _profileForWhomError = null;
        _warmupGenderError = null;
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

  /// Saves the Family/About step, which the blueprint (§11) defines as optional.
  ///
  /// A member may arrive here and press Continue having filled nothing, so both
  /// writes are conditional. That is not "skipping the save": each write fires
  /// whenever there is something to write, and only genuinely empty input is
  /// left out.
  ///
  /// The family write in particular *must* be skipped when empty rather than
  /// posted as `{}`. `MobileOnboardingController` validates the step body as
  /// `'data' => ['required', 'array']`, and Laravel's `required` rejects an
  /// empty array — so posting an empty family payload would 422 the member out
  /// of a step they are explicitly allowed to skip.
  Future<bool> _saveFamilyStatusAboutStep(
    Map<String, dynamic> familyData,
    String aboutText,
  ) async {
    if (!_requireOnboardingSession()) return false;

    if (familyData.isNotEmpty) {
      final saved = await _saveOnboardingStep(
        'family',
        familyData,
        saveProfile: true,
        advance: false,
      );
      if (!mounted || !saved) return false;
    }

    final about = aboutText.trim();
    // Only persist when the user typed or picked a suggestion. An empty box
    // must not wipe an existing about just because the UI starts blank.
    final writeAbout = about.isNotEmpty;

    setState(() {
      _loading = true;
      _error = null;
      _message = null;
      _fieldErrors = const <String, String>{};
    });

    try {
      if (writeAbout) {
        final response = await ApiClient.updateMatrimonyProfile({
          'narrative_about_me': about,
        });
        if (!mounted) return false;
        if (response['success'] != true) {
          setState(() {
            _loading = false;
            _error = readableApiError(
              response,
              appText.couldNotSaveTheAboutSection,
            );
          });
          return false;
        }
      }

      await _loadStatus(goToStatus: false);
      if (!mounted) return false;
      setState(() {
        _loading = false;
        _step = _SmartOnboardingStep.registrationComplete;
        _error = null;
        _message = null;
        _fieldErrors = const <String, String>{};
      });
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
      });
      return false;
    }
  }

  void _continueFromRegistrationComplete() {
    setState(() {
      _error = null;
      _message = null;
      _fieldErrors = const <String, String>{};
      _step = _SmartOnboardingStep.photo;
    });
    unawaited(_saveLocalDraft());
  }

  void _verifyMobileFromRegistrationComplete() {
    _startExistingMobileFlow();
  }

  Future<void> _handlePartnerPreferenceSaved() async {
    await _loadStatus(goToStatus: false);
    if (!mounted) return;
    _markPartnerPreferenceReviewed();
    setState(() {
      _error = null;
      _message = null;
      _fieldErrors = const <String, String>{};
      _step = _SmartOnboardingStep.setPassword;
    });
    await _saveLocalDraft();
  }

  String? _accountCreatorName() {
    final account = _accountWithPendingEmail();
    for (final key in const ['creator_name', 'name']) {
      final value = onboardingText(account[key]);
      if (value != null) return value;
    }

    final basicInfoName = onboardingText(
      _draftStepData('basic_info')['full_name'],
    );
    if (basicInfoName != null) return basicInfoName;

    final profile = _status?.profile?.raw ?? ApiClient.currentUserProfile;
    if (profile != null) {
      for (final key in const ['full_name', 'name']) {
        final value = onboardingText(profile[key]);
        if (value != null) return value;
      }
    }

    return null;
  }

  Future<String?> _saveOptionalPassword({
    required String password,
    required String passwordConfirmation,
  }) async {
    if (!_isAuthenticated) {
      final message = appText.sessionExpiredVerifyMobileAgain;
      setState(() {
        _step = _SmartOnboardingStep.mobileOtp;
        _error = message;
      });
      return message;
    }

    final creatorName = _accountCreatorName();
    if (creatorName == null) {
      return appText.couldNotReadAccountNamePlease;
    }

    setState(() {
      _loading = true;
      _error = null;
      _message = null;
      _fieldErrors = const <String, String>{};
    });

    try {
      final response = await ApiClient.updateAccountDetails(
        creatorName: creatorName,
        locale: _localeCode,
        password: password,
        passwordConfirmation: passwordConfirmation,
      );
      if (!mounted) return null;

      if (response['statusCode'] == 401) {
        final message = appText.sessionExpiredVerifyMobileAgain;
        setState(() {
          _loading = false;
          _step = _SmartOnboardingStep.mobileOtp;
          _error = message;
        });
        return message;
      }

      if (response['success'] != true) {
        final message = readableApiError(
          response,
          appText.couldNotSavePassword,
        );
        setState(() {
          _loading = false;
        });
        return message;
      }

      setState(() {
        _loading = false;
      });
      await _finishOnboardingAfterPasswordStep();
      return null;
    } catch (error) {
      if (!mounted) return null;
      final message = error.toString();
      setState(() {
        _loading = false;
      });
      return _isTechnicalOnboardingError(message)
          ? appText.couldNotSavePassword
          : message;
    }
  }

  /// The single way out of this screen and into the app, for both a brand-new
  /// member and one who signed in with a one-time code.
  ///
  /// This used to be `pushReplacementNamed`, which swaps only the top route.
  /// The landing screen PUSHES this screen, so the stack ended up as
  /// `[/landing, /matches]` — and a signed-in member pressing Back once on the
  /// match list was dropped onto the signed-out Register/Login page.
  Future<void> _finishOnboardingAfterPasswordStep() async {
    await AppStorage.instance.clearOnboardingDraftJson();
    if (!mounted) return;
    final route = await resolveCompletedMemberRoute();
    if (!mounted) return;
    enterMemberApp(
      Navigator.of(context),
      route,
      arguments: route == '/matches'
          ? const {'showRecommendationDeck': true}
          : null,
    );
  }

  void _skipOptionalPassword() {
    unawaited(_finishOnboardingAfterPasswordStep());
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
        return appText.yourDetails;
      case 'son':
        return appText.sonSDetails;
      case 'daughter':
        return appText.daughterSDetails;
      case 'brother':
        return appText.brotherSDetails;
      case 'sister':
        return appText.sisterSDetails;
      case 'relative':
        switch (_effectiveProfileGenderKey()) {
          case 'female':
            return appText.brideRelativeSDetails;
          case 'male':
            return appText.groomRelativeSDetails;
        }
        return appText.relativeSDetails;
      case 'friend':
        switch (_effectiveProfileGenderKey()) {
          case 'female':
            return appText.friendSDetails;
          case 'male':
            return appText.friendSDetails2;
        }
        return appText.friendSDetails3;
    }

    return appText.basicDetails;
  }

  Future<void> _continueFromProfileForWhom() async {
    if (_profileForWhom == null) {
      setState(() {
        final message = appText.chooseWhoThisProfileIsFor2;
        _profileForWhomError = message;
        _warmupGenderError = null;
        _fieldErrorPulseToken++;
        _error = message;
        _motherTongueError = null;
        _fieldErrors = const <String, String>{};
      });
      return;
    }

    final resolvedGender = _resolvedProfileGenderOption();
    if (_needsGenderWarmup && _warmupGender == null) {
      setState(() {
        final message = _genderPromptLabel();
        _profileForWhomError = null;
        _warmupGenderError = message;
        _fieldErrorPulseToken++;
        _error = message;
        _motherTongueError = null;
        _fieldErrors = const <String, String>{};
      });
      return;
    }
    if (resolvedGender == null) {
      setState(() {
        final message = appText.selectGenderAgain;
        _profileForWhomError = null;
        _warmupGenderError = message;
        _fieldErrorPulseToken++;
        _error = message;
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
      _profileForWhomError = null;
      _warmupGenderError = null;
      _motherTongueError = null;
      _fieldErrors = const <String, String>{};
      _step = _SmartOnboardingStep.mobileOtp;
    });
  }

  void _startExistingMobileFlow() {
    setState(() {
      _error = null;
      _message = null;
      _profileForWhomError = null;
      _warmupGenderError = null;
      _motherTongueError = null;
      _fieldErrors = const <String, String>{};
      _step = _SmartOnboardingStep.mobileOtp;
    });
  }

  void _editMobileNumber() {
    _otpAutoVerifyTimer?.cancel();
    setState(() {
      _otpChallenge = null;
      _otpController.clear();
      _lastOtpAutoVerifyAttempt = null;
      _otpAutoAdvancePending = false;
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
        return appText.myself;
      case 'son':
        return appText.son;
      case 'daughter':
        return appText.daughter;
      case 'brother':
        return appText.brother;
      case 'sister':
        return appText.sister;
      case 'relative':
        return appText.relative;
      case 'friend':
        return appText.friend;
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
      male ?? OnboardingOption(key: 'male', label: appText.male),
      female ?? OnboardingOption(key: 'female', label: appText.female),
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
        return appText.selectYourGender;
      case 'relative':
        return appText.selectRelativeSGender;
      case 'friend':
        return appText.selectFriendSGender;
    }

    return appText.selectGender;
  }

  String _motherTongueLabel() {
    switch (_profileForWhomKey?.toLowerCase()) {
      case 'self':
        return appText.yourMotherTongue;
      case 'son':
      case 'brother':
        return appText.hisMotherTongue;
      case 'daughter':
      case 'sister':
        return appText.herMotherTongue;
      case 'relative':
      case 'friend':
        switch (_genderOptionKey(_warmupGender)) {
          case 'male':
            return appText.hisMotherTongue;
          case 'female':
            return appText.herMotherTongue;
        }
    }

    return appText.selectMotherTongue;
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
                  title: appText.dashboardCreateProfile,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The header band is the ONLY place any step reports an
              // error. The mobile/OTP step hides the chrome on purpose, so
              // it was setting `_error` and showing nothing whatsoever: a
              // failed send or a rejected code simply re-enabled the button
              // with no explanation of what had gone wrong.
              if (showChrome || _error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                  child: _buildHeader(context),
                )
              else
                const SizedBox(height: 8),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    _step == _SmartOnboardingStep.mobileOtp ||
                            _isPostRegistrationStep
                        ? 0
                        : 16,
                    0,
                    _step == _SmartOnboardingStep.mobileOtp ||
                            _isPostRegistrationStep
                        ? 0
                        : 16,
                    0,
                  ),
                  child: _buildStepCard(context),
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
        accent: Colors.red.shade700,
        title: appText.pleaseCheckThisInformation,
        subline: error,
      );
    }

    final message = _message;
    if (message != null) {
      final accent = switch (_messageType) {
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
        accent: accent,
        title: message,
        subline: '',
      );
    }

    // Keep guidance visible during loading so the shell never blanks.
    return _HeaderMessageData(
      key:
          'guidance:${_step.name}:${_profileForWhomKey ?? ''}:${_effectiveProfileGenderKey()}',
      icon: Icons.notifications_active_outlined,
      accent: Colors.grey.shade700,
      title: _guidanceTitleForStep(),
      subline: _guidanceSublineForStep(),
      centerTitle: _step == _SmartOnboardingStep.maritalStatus,
    );
  }

  String _guidanceTitleForStep() {
    switch (_step) {
      case _SmartOnboardingStep.profileForWhom:
        return appText.startWithProfileOwner;
      case _SmartOnboardingStep.mobileOtp:
        return appText.verifyMobileNumber;
      case _SmartOnboardingStep.maritalStatus:
        return appText.maritalStatus;
      case _SmartOnboardingStep.basicInfo:
        return _profileDetailsTitle();
      case _SmartOnboardingStep.religionCaste:
        return appText.chooseCommunityDetails;
      case _SmartOnboardingStep.location:
        return appText.locationDetails;
      case _SmartOnboardingStep.education:
        return appText.educationCareer;
      case _SmartOnboardingStep.motherTongue:
        return _motherTongueLabel();
      case _SmartOnboardingStep.lifestyle:
        return appText.lifestyleDetails;
      case _SmartOnboardingStep.family:
        return appText.familyDetails;
      case _SmartOnboardingStep.astro:
        return appText.astroDetails;
      case _SmartOnboardingStep.registrationComplete:
        return appText.registrationComplete;
      case _SmartOnboardingStep.partnerPreference:
        return appText.partnerPreference;
      case _SmartOnboardingStep.setPassword:
        return appText.setPassword;
      case _SmartOnboardingStep.photo:
        return appText.profilePhoto;
    }
  }

  String _guidanceSublineForStep() {
    final subjectEn = _profileSubjectPossessiveEnglish();
    final subjectMr = _profileSubjectPossessiveMarathi();

    switch (_step) {
      case _SmartOnboardingStep.profileForWhom:
        return appText.thisKeepsEveryNextQuestionRelevant;
      case _SmartOnboardingStep.mobileOtp:
        return _t(
          'Verification keeps $subjectEn profile safe and recoverable.',
          'मोबाइल पडताळणीमुळे $subjectMr प्रोफाइल सुरक्षित आणि परत मिळवता येण्याजोगे राहते.',
        );
      case _SmartOnboardingStep.maritalStatus:
        return _t(
          'This helps avoid irrelevant questions and match filters.',
          '$subjectMr वैवाहिक स्थिती अप्रासंगिक प्रश्न आणि जुळणी टाळायला मदत करते.',
        );
      case _SmartOnboardingStep.basicInfo:
        return _t(
          'Accurate basics improve $subjectEn match recommendations.',
          '$subjectMr अचूक माहिती योग्य स्थळे सुचवायला मदत करते.',
        );
      case _SmartOnboardingStep.religionCaste:
        return appText.communityPreferencesHelpKeepSuggestionsRelevant;
      case _SmartOnboardingStep.location:
        return _t(
          'Location helps us show nearby and practical matches.',
          '$subjectMr राहण्याचे ठिकाण जवळची आणि व्यवहार्य स्थळे दाखवायला मदत करते.',
        );
      case _SmartOnboardingStep.education:
        return _t(
          'Education and career details improve match quality.',
          '$subjectMr शिक्षण आणि कामाची माहिती जुळणीचा दर्जा वाढवते.',
        );
      case _SmartOnboardingStep.motherTongue:
        return _t(
          'Language comfort can make conversations easier.',
          '$subjectMr मातृभाषा संवाद सोपा करायला मदत करते.',
        );
      case _SmartOnboardingStep.lifestyle:
        return _t(
          'Lifestyle choices help compare day-to-day compatibility.',
          '$subjectMr सवयी आणि जीवनशैली रोजची सुसंगती तपासायला मदत करतात.',
        );
      case _SmartOnboardingStep.family:
        return _t(
          'Family context builds trust before conversations begin.',
          '$subjectMr कुटुंबाची माहिती विश्वास वाढवते.',
        );
      case _SmartOnboardingStep.astro:
        return _t(
          'Astro details can help families who prefer horoscope matching.',
          '$subjectMr ज्योतिष माहिती पत्रिका जुळवणीला प्राधान्य देणाऱ्या कुटुंबांसाठी उपयोगी ठरते.',
        );
      case _SmartOnboardingStep.registrationComplete:
        return appText.registrationIsCompleteNextSettingsImprove;
      case _SmartOnboardingStep.partnerPreference:
        return appText.wePreparedThisFromTheInformation;
      case _SmartOnboardingStep.setPassword:
        return appText.createAPasswordNowIfYou;
      case _SmartOnboardingStep.photo:
        return appText.aClearPhotoUsuallyImprovesResponse;
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
    return appText.ofThisProfile;
  }

  Widget _buildStepCard(BuildContext context) {
    final stepContent = AnimatedSwitcher(
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
        _SmartOnboardingStep.motherTongue => _buildMotherTongueStep(context),
        _SmartOnboardingStep.lifestyle => LifestyleStep(
          data: _draftStepData('lifestyle'),
          bootstrap: _bootstrap,
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
        _SmartOnboardingStep.family => FamilyOptionalStep(
          data: _draftStepData('family'),
          initialAbout: _profileAboutText(),
          aboutSuggestions: _aboutTemplateSuggestions(),
          aboutVoice: _aboutVoice,
          locale: _localeCode,
          loading: _loading,
          onSaveFamilyAbout: _saveFamilyStatusAboutStep,
          onBack: _goBackOneStep,
        ),
        _SmartOnboardingStep.registrationComplete => RegistrationSuccessStep(
          account: _accountWithPendingEmail(),
          locale: _localeCode,
          loading: _loading,
          onVerifyGoogleEmail: _verifyGoogleEmailFromRegistration,
          onSendEmailOtp: _sendEmailOtpFromRegistration,
          onVerifyEmailOtp: _verifyEmailOtpFromRegistration,
          onSkipEmail: _continueFromRegistrationComplete,
          onVerifyMobile: _verifyMobileFromRegistrationComplete,
          onContinue: _continueFromRegistrationComplete,
        ),
        _SmartOnboardingStep.partnerPreference => PartnerPreferenceReviewStep(
          status: _status,
          locale: _localeCode,
          loading: _loading,
          onBack: _goBackOneStep,
          onSaved: _handlePartnerPreferenceSaved,
        ),
        _SmartOnboardingStep.setPassword => SetPasswordStep(
          locale: _localeCode,
          loading: _loading,
          onBack: _goBackOneStep,
          onSave: _saveOptionalPassword,
          onSkip: _skipOptionalPassword,
        ),
        _SmartOnboardingStep.photo => PhotoStep(
          status: _status,
          locale: _localeCode,
          loading: _loading,
          onSave: _saveOnboardingStep,
          onBack: _goBackOneStep,
          onRefresh: () => _loadStatus(goToStatus: false),
        ),
      },
    );

    if (_step == _SmartOnboardingStep.mobileOtp || _isPostRegistrationStep) {
      return stepContent;
    }

    // Do NOT wrap the whole step (including sticky CTA) in a Card.
    // That made Continue look like the bottom of one big panel. Each step's
    // OnboardingStepScaffold owns a content card; CTA sits outside on the
    // scaffold background (same pattern as photo / post-registration).
    return stepContent;
  }

  Widget _buildMobileOtpStep(BuildContext context) {
    final otpSent = _otpChallenge?.challengeId != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: otpSent
          ? _buildOtpVerificationStep(context)
          : _buildMobileNumberEntryStep(context),
    );
  }

  Widget _buildMobileNumberEntryStep(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return AutofillGroup(
      key: const ValueKey('mobile_number'),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Spacers + keyboard caused BOTTOM OVERFLOWED yellow/black strip.
          // Scroll when short; center when there is room.
          return SingleChildScrollView(
            padding: EdgeInsets.zero,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colors.primary.withValues(alpha: 0.18),
                          width: 8,
                        ),
                      ),
                      child: Icon(
                        Icons.verified_user_outlined,
                        size: 34,
                        color: colors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  Text(
                    appText.verifyMobileNumber,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: colors.onSurface,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    appText.enterYourMobileNumberToReceive,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 34),
                  _mobileNumberField(context),
                  const SizedBox(height: 14),
                  CheckboxListTile(
                    value: _whatsappAlertsOptIn,
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    onChanged: _loading
                        ? null
                        : (value) => setState(
                              () => _whatsappAlertsOptIn = value ?? false,
                            ),
                    title: Text(
                      appText.sendProfileAlertsOnWhatsapp,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _sendOtp,
                      icon: _loading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.arrow_forward_rounded),
                      label: Text(
                        _loading ? appText.sendingOtp : appText.getOtp,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _TermsPrivacyFooter(
                    isMarathi: _language == AppLanguage.marathi,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _mobileNumberField(BuildContext context) {
    final borderColor = Colors.grey.shade300;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          appText.mobileNumber,
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
                    hintText: appText.mobileNumber2,
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final mobile = MobileNumberInput.normalize(_mobileController.text);
    final debugOtp = _otpChallenge?.debugOtp;
    final debugOtpAvailable = debugOtp != null && debugOtp.length == 6;

    return AutofillGroup(
      key: const ValueKey('otp_verification'),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: (_loading || _otpAutoAdvancePending)
                            ? null
                            : _editMobileNumber,
                        icon: const Icon(Icons.arrow_back_rounded),
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).backButtonTooltip,
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: (_loading || _otpAutoAdvancePending)
                            ? null
                            : _editMobileNumber,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: Text(appText.edit),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 76,
                      height: 76,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colors.primary.withValues(alpha: 0.18),
                          width: 8,
                        ),
                      ),
                      child: Icon(
                        Icons.sms_outlined,
                        size: 34,
                        color: colors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    appText.verifyMobileNumber2,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: colors.onSurface,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    appText.weVeSentAVerificationCode,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '+91 $mobile',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _otpCodeField(context),
                  if (debugOtpAvailable) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.bolt_rounded,
                            size: 18,
                            color: Colors.green.shade700,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              appText.testOtpLabel(debugOtp),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.green.shade800,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: (_loading || _otpAutoAdvancePending)
                          ? null
                          : _verifyOtp,
                      icon: (_loading || _otpAutoAdvancePending)
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.verified_rounded),
                      label: Text(
                        _otpAutoAdvancePending
                            ? appText.continuing
                            : _loading
                            ? appText.verifying
                            : appText.verifyAndContinue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildResendControl(context),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _otpCodeField(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final digits = _otpController.text.trim().split('').take(6).toList();

    return Container(
      height: 74,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.primary.withValues(alpha: 0.22)),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: List.generate(6, (index) {
                final digit = index < digits.length ? digits[index] : '_';
                final active = index < digits.length;
                return Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    height: 52,
                    margin: EdgeInsets.only(right: index == 5 ? 0 : 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: active
                          ? colors.primary.withValues(alpha: 0.08)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: active
                            ? colors.primary.withValues(alpha: 0.55)
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Text(
                      digit,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: active ? colors.onSurface : Colors.grey.shade500,
                        height: 1,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0.01,
              child: TextField(
                controller: _otpController,
                enabled: !_loading && !_otpAutoAdvancePending,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                maxLength: 6,
                style: theme.textTheme.headlineSmall,
                cursorColor: Colors.transparent,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  counterText: '',
                ),
                onChanged: _handleOtpChanged,
              ),
            ),
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
          'कोड मिळाला नाही? ${_resendSecondsRemaining}s नंतर पुन्हा पाठवा',
        ),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(appText.didnTGetTheCodeYet),
        TextButton(
          onPressed: (_loading || _otpAutoAdvancePending) ? null : _sendOtp,
          child: Text(appText.resendCode),
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
            ? appText.male
            : key == 'female'
            ? appText.female
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
                        _profileForWhomError = null;
                        _warmupGenderError = null;
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
    final choiceWidgets = <Widget>[
      if (primary != null)
        _buildProfileChoiceCard(context, primary, primary: true),
      if (secondary.isNotEmpty) ...[
        const SizedBox(height: 12),
        ..._buildProfileChoiceRows(context, secondary),
      ],
    ];

    return OnboardingStepScaffold(
      key: const ValueKey('profile_for_whom'),
      title: appText.iAmCreatingThisProfileFor,
      titleStyle: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: Colors.grey.shade800,
        fontWeight: FontWeight.w800,
      ),
      loading: _loading,
      continueLabel: appText.continueLabel,
      onContinue: _continueFromProfileForWhom,
      secondary: _AlreadyRegisteredLink(
        prompt: appText.pleaseLogin,
        linkLabel: appText.login,
        onPressed: _loading
            ? null
            : () {
                Navigator.of(context).pushNamed('/login');
              },
      ),
      children: [
        OnboardingErrorHighlight(
          hasError: _profileForWhomError != null,
          pulseKey:
              'profile_for_whom:$_fieldErrorPulseToken:$_profileForWhomError',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: choiceWidgets,
          ),
        ),
        if (_profileForWhomError != null) ...[
          const SizedBox(height: 8),
          Text(
            _profileForWhomError!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.red.shade700,
              fontWeight: FontWeight.w700,
            ),
          ),
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
                    OnboardingErrorHighlight(
                      hasError: _warmupGenderError != null,
                      pulseKey:
                          'warmup_gender:$_fieldErrorPulseToken:$_warmupGenderError',
                      child: _buildGenderSegmentedControl(context),
                    ),
                    if (_warmupGenderError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _warmupGenderError!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildMotherTongueStep(BuildContext context) {
    return OnboardingStepScaffold(
      key: const ValueKey('mother_tongue'),
      title: _motherTongueLabel(),
      titleStyle: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      loading: _loading,
      continueLabel: appText.continueLabel,
      onContinue: _continueFromMotherTongue,
      children: [
        OnboardingErrorHighlight(
          hasError: _motherTongueError != null,
          pulseKey: 'mother_tongue:$_fieldErrorPulseToken:$_motherTongueError',
          child: OnboardingPickerField(
            label: appText.motherTongue,
            selectedItems: _motherTongue?.intId == null
                ? const []
                : [_motherTongue!],
            placeholder: appText.selectMotherTongue,
            searchHint: appText.searchMotherTongue,
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
                _profileForWhomError = null;
                _warmupGenderError = null;
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

  Future<String?> _verifyGoogleEmailFromRegistration(
    GoogleEmailCredential credential,
  ) async {
    final email = credential.email.trim();
    final idToken = credential.idToken?.trim() ?? '';
    if (email.isEmpty) {
      return appText.couldNotReadEmailFromGoogle;
    }
    if (idToken.isEmpty) {
      return appText.googleVerificationIsNotReadyWe;
    }

    final response = await ApiClient.verifyGoogleEmail(
      email: email,
      idToken: idToken,
    );
    if (response['success'] != true) {
      return readableApiError(
        response,
        appText.googleVerificationFailedWeWillVerify,
      );
    }

    await _loadStatus(goToStatus: false);
    return null;
  }

  Future<Map<String, dynamic>> _sendEmailOtpFromRegistration(
    String email,
  ) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty) {
      return {
        'success': false,
        'message': appText.enterAValidEmailAddress,
      };
    }

    return ApiClient.sendEmailOtp(email: trimmed);
  }

  Future<String?> _verifyEmailOtpFromRegistration({
    required String challengeId,
    required String email,
    required String otp,
  }) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty) {
      return appText.enterAValidEmailAddress;
    }

    final response = await ApiClient.verifyEmailOtp(
      challengeId: challengeId,
      email: trimmed,
      otp: otp,
    );
    if (response['success'] != true) {
      return readableApiError(
        response,
        appText.couldNotVerifyEmail,
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
            '$label दुवा अजून उपलब्ध नाही.',
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
                appText.byRegisteringIAgreeToThe,
                style: textStyle,
              ),
              _FooterLink(
                label: appText.termsAndConditionsShort,
                onTap: () =>
                    _showUnavailable(context, appText.termsAndConditionsShort),
              ),
              Text(appText.and, style: textStyle),
              _FooterLink(
                label: appText.privacyPolicy,
                onTap: () => _showUnavailable(context, appText.privacyPolicy),
              ),
              Text(appText.str, style: textStyle),
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
    required this.accent,
    required this.title,
    required this.subline,
    this.centerTitle = false,
  });

  final String key;
  final IconData icon;
  final Color accent;
  final String title;
  final String subline;
  final bool centerTitle;
}

class _HeaderMessageBand extends StatelessWidget {
  const _HeaderMessageBand({super.key, required this.data});

  final _HeaderMessageData data;

  @override
  Widget build(BuildContext context) {
    // One stable shell — only icon + text crossfade inside.
    return SizedBox(
      height: 60,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            layoutBuilder: (currentChild, previousChildren) {
              return Stack(
                alignment: Alignment.centerLeft,
                children: <Widget>[
                  ...previousChildren,
                  if (currentChild != null) currentChild,
                ],
              );
            },
            child: KeyedSubtree(
              key: ValueKey<String>(
                '${data.key}:${data.title}:${data.subline}',
              ),
              child: Row(
                children: [
                  Container(
                    height: 34,
                    width: 34,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(data.icon, color: data.accent, size: 19),
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
            ),
          ),
        ),
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
  const _AlreadyRegisteredLink({
    required this.prompt,
    required this.linkLabel,
    required this.onPressed,
  });

  final String prompt;
  final String linkLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.center,
        children: [
          Text(
            prompt,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          TextButton(
            onPressed: onPressed,
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                decoration: TextDecoration.underline,
              ),
            ),
            child: Text(linkLabel),
          ),
        ],
      ),
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
