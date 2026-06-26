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
import 'steps/basic_candidate_info_step.dart';
import 'steps/career_step.dart';
import 'steps/education_step.dart';
import 'steps/family_optional_step.dart';
import 'steps/lifestyle_step.dart';
import 'steps/location_step.dart';
import 'steps/onboarding_step_helpers.dart';
import 'steps/photo_step.dart';
import 'steps/religion_caste_step.dart';
import 'widgets/onboarding_error_highlight.dart';
import 'widgets/onboarding_picker_field.dart';

enum SmartOnboardingInitialMode { normal, mobileOtp }

enum _SmartOnboardingStep {
  profileForWhom,
  mobileOtp,
  basicInfo,
  religionCaste,
  location,
  education,
  career,
  lifestyle,
  family,
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
  static const Color _selectedGreen = Color(0xFF0F8F5F);
  static const Color _selectedGreenSurface = Color(0xFFE7F6ED);
  static const List<_SmartOnboardingStep> _progressSteps =
      <_SmartOnboardingStep>[
        _SmartOnboardingStep.religionCaste,
        _SmartOnboardingStep.location,
        _SmartOnboardingStep.education,
        _SmartOnboardingStep.career,
        _SmartOnboardingStep.lifestyle,
        _SmartOnboardingStep.family,
        _SmartOnboardingStep.photo,
        _SmartOnboardingStep.activation,
      ];

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
  DateTime? _resendAvailableAt;
  Timer? _resendTimer;
  Timer? _messageTimer;

  bool _loading = false;
  bool _whatsappAlertsOptIn = true;
  bool _debugOtpAutoVerifyQueued = false;
  int _resendSecondsRemaining = 0;
  String? _error;
  String? _message;
  String? _motherTongueError;
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
      _motherTongueError = null;
      _fieldErrors = const <String, String>{};
    });

    if (!autoHide) return;
    _messageTimer = Timer(const Duration(seconds: 5), () {
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

    return out;
  }

  String _stepKeyForOnboardingStep(_SmartOnboardingStep step) {
    return switch (step) {
      _SmartOnboardingStep.profileForWhom =>
        OnboardingFieldErrorMap.profileForWhomStep,
      _SmartOnboardingStep.basicInfo => OnboardingFieldErrorMap.basicInfoStep,
      _SmartOnboardingStep.religionCaste => 'religion_caste',
      _SmartOnboardingStep.location => 'location',
      _SmartOnboardingStep.education => 'education',
      _SmartOnboardingStep.career => 'career',
      _SmartOnboardingStep.lifestyle => 'lifestyle',
      _SmartOnboardingStep.family => 'family',
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
      'career' => _SmartOnboardingStep.career,
      'lifestyle' => _SmartOnboardingStep.lifestyle,
      'family' => _SmartOnboardingStep.family,
      'photo' => _SmartOnboardingStep.photo,
      _ => null,
    };
  }

  Map<String, String> _fieldErrorsForStep(String step) {
    return OnboardingFieldErrorMap.forStep(_fieldErrors, step);
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
    final nextStep = _onboardingStepForStepKey(ownerStep) ?? _step;
    final fieldErrors = <String, String>{field: message};
    setState(() {
      _loading = false;
      _step = nextStep;
      _fieldErrors = fieldErrors;
      _fieldErrorPulseToken++;
      _motherTongueError =
          ownerStep == OnboardingFieldErrorMap.profileForWhomStep
          ? message
          : null;
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
    final nextStep = _onboardingStepForStepKey(ownerStep) ?? _step;
    final message =
        _firstFieldErrorForStep(fieldErrors, ownerStep) ??
        _firstFieldErrorSummary(fieldErrors) ??
        _friendlySaveError(response, _genericSaveFailureMessage());

    setState(() {
      _loading = false;
      _step = nextStep;
      _fieldErrors = fieldErrors;
      _fieldErrorPulseToken++;
      _motherTongueError =
          ownerStep == OnboardingFieldErrorMap.profileForWhomStep
          ? onboardingFirstFieldError(fieldErrors, const <String>[
              'mother_tongue_id',
              'mother_tongue',
            ])
          : null;
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

  int get _progressIndex => _progressSteps.indexOf(_step);

  bool get _showProgress => _progressIndex >= 0;

  String? get _profileForWhomKey => _profileForWhom?.key?.trim();

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
    return _stepFromServerName(next);
  }

  _SmartOnboardingStep _stepFromServerName(String? step) {
    switch (step) {
      case 'account':
        return _SmartOnboardingStep.profileForWhom;
      case 'profile_for_whom':
        return _SmartOnboardingStep.profileForWhom;
      case 'basic_info':
        return _SmartOnboardingStep.basicInfo;
      case 'religion_caste':
        return _SmartOnboardingStep.religionCaste;
      case 'location':
        return _SmartOnboardingStep.location;
      case 'education':
        return _SmartOnboardingStep.education;
      case 'career':
        return _SmartOnboardingStep.career;
      case 'lifestyle':
        return _SmartOnboardingStep.lifestyle;
      case 'family':
        return _SmartOnboardingStep.family;
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
        return _SmartOnboardingStep.basicInfo;
      case _SmartOnboardingStep.basicInfo:
        return _SmartOnboardingStep.religionCaste;
      case _SmartOnboardingStep.religionCaste:
        return _SmartOnboardingStep.location;
      case _SmartOnboardingStep.location:
        return _SmartOnboardingStep.education;
      case _SmartOnboardingStep.education:
        return _SmartOnboardingStep.career;
      case _SmartOnboardingStep.career:
        return _SmartOnboardingStep.lifestyle;
      case _SmartOnboardingStep.lifestyle:
        return _SmartOnboardingStep.family;
      case _SmartOnboardingStep.family:
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
      case _SmartOnboardingStep.basicInfo:
        return _SmartOnboardingStep.profileForWhom;
      case _SmartOnboardingStep.religionCaste:
        return _SmartOnboardingStep.basicInfo;
      case _SmartOnboardingStep.location:
        return _SmartOnboardingStep.religionCaste;
      case _SmartOnboardingStep.education:
        return _SmartOnboardingStep.location;
      case _SmartOnboardingStep.career:
        return _SmartOnboardingStep.education;
      case _SmartOnboardingStep.lifestyle:
        return _SmartOnboardingStep.career;
      case _SmartOnboardingStep.family:
        return _SmartOnboardingStep.lifestyle;
      case _SmartOnboardingStep.photo:
        return _SmartOnboardingStep.family;
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

    final motherTongueId = await _requireMotherTongueId();
    if (!mounted || motherTongueId == null) return;
    final genderId = _resolvedProfileGenderOption()?.intId;
    final startPayload = <String, dynamic>{
      'profile_for_whom': profileForWhom,
      if (genderId != null) 'gender_id': genderId,
      'mother_tongue_id': motherTongueId,
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
        motherTongueId: motherTongueId,
      );
      if (!mounted) return;
      if (data['success'] != true) {
        _debugLogBackendError('start onboarding', data);
        _applySaveFailure(attemptedStep: 'profile_for_whom', response: data);
        return;
      }

      await _loadStatus(goToStatus: false);
      if (!mounted) return;
      var nextStep = _SmartOnboardingStep.basicInfo;
      final status = _status;
      if (status != null &&
          (status.hasProfile ||
              status.nextStep != null ||
              status.draft?.currentStep != null)) {
        nextStep = _stepFromStatus(status);
      }
      if (nextStep == _SmartOnboardingStep.profileForWhom ||
          nextStep == _SmartOnboardingStep.mobileOtp) {
        nextStep = _SmartOnboardingStep.basicInfo;
      }
      setState(() {
        _loading = false;
        _step = nextStep;
      });
      _showOnboardingMessage(
        _t('Saved. Add basic details.', 'Save झाले. थोडी माहिती भरा.'),
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

  Future<Map<String, dynamic>?> _dataForOnboardingStep(
    String step,
    Map<String, dynamic> data,
  ) async {
    if (step != 'basic_info') {
      return data;
    }

    final motherTongueId = await _requireMotherTongueId();
    if (motherTongueId == null) {
      return null;
    }

    final payload = <String, dynamic>{
      ...data,
      'mother_tongue_id': motherTongueId,
    };
    _debugLogMotherTongueSelection('basic_info_payload', payload: payload);
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
    if (_canStepBackWithinOnboarding) {
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
    if (_motherTongue == null) {
      setState(() {
        _motherTongueError = _t('Select mother tongue.', 'मातृभाषा निवडा.');
        _error = _motherTongueError;
        _fieldErrors = <String, String>{
          'mother_tongue_id': _motherTongueError!,
        };
        _fieldErrorPulseToken++;
      });
      return;
    }

    final motherTongueId = await _requireMotherTongueId();
    if (!mounted || motherTongueId == null) return;
    _debugLogMotherTongueSelection(
      'profile_for_whom_continue',
      payload: <String, dynamic>{
        'profile_for_whom': _profileForWhom!.key,
        if (resolvedGender.intId != null) 'gender_id': resolvedGender.intId,
        'mother_tongue_id': motherTongueId,
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
    final showBack = _canStepBackWithinOnboarding || Navigator.canPop(context);

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
        appBar: AppBar(
          centerTitle: false,
          leading: showBack
              ? IconButton(
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _loading ? null : _handleAppBarBack,
                )
              : null,
          title: Text(_t('Create Profile', 'प्रोफाइल तयार करा')),
          actions: [
            if (_step != _SmartOnboardingStep.profileForWhom)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _LanguageToggle(
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
          ],
        ),
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
                  _buildHeader(context),
                  const SizedBox(height: 14),
                  if (_showProgress &&
                      _step != _SmartOnboardingStep.religionCaste &&
                      _step != _SmartOnboardingStep.location) ...[
                    _StepIndicator(
                      currentStep: _progressIndex,
                      totalSteps: _progressSteps.length,
                    ),
                    const SizedBox(height: 14),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          height: 78,
          child: Align(
            alignment: Alignment.centerLeft,
            child: _buildHeaderMessage(context),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderMessage(BuildContext context) {
    final error = _error;
    if (error != null) {
      return _ErrorBanner(message: error);
    }

    final message = _message;
    if (message != null) {
      return _MessageBanner(message: message, type: _messageType);
    }

    String fallback;
    if (_step == _SmartOnboardingStep.religionCaste) {
      fallback = _t('Choose community details', 'समुदायाची माहिती निवडा');
    } else if (_showProgress) {
      fallback = _t('Almost done', 'थोडी माहिती पूर्ण करा');
    } else {
      fallback = _t('Let’s create a profile', 'चला, प्रोफाइल तयार करूया');
    }

    return Text(
      fallback,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(
        context,
      ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
    );
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
              onSave: _saveOnboardingStep,
              onBack: _goBackOneStep,
              onMessage: _showStepMessage,
              onFieldEdited: _clearCurrentFeedback,
            ),
            _SmartOnboardingStep.religionCaste => ReligionCasteStep(
              data: _draftStepData('religion_caste'),
              locale: _localeCode,
              loading: _loading,
              onSave: _saveOnboardingStep,
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
            _SmartOnboardingStep.education => EducationStep(
              data: _draftStepData('education'),
              locale: _localeCode,
              loading: _loading,
              onSave: _saveOnboardingStep,
              onBack: _goBackOneStep,
              onMessage: _showStepMessage,
            ),
            _SmartOnboardingStep.career => CareerStep(
              data: _draftStepData('career'),
              locale: _localeCode,
              loading: _loading,
              onSave: _saveOnboardingStep,
              onBack: _goBackOneStep,
              onMessage: _showStepMessage,
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
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: const InputDecoration(
              hintText: '_ _ _ _ _ _',
              counterText: '',
            ),
            maxLength: 6,
          ),
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

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: options.map((option) {
          final selected = _warmupGender?.identity == option.identity;
          final key = _genderOptionKey(option);
          final label = key == 'male'
              ? _t('Male', 'पुरुष')
              : key == 'female'
              ? _t('Female', 'स्त्री')
              : option.label;

          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
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
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? _selectedGreen : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: selected ? _selectedGreen : Colors.transparent,
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.grey.shade800,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildProfileForWhomStep(BuildContext context) {
    final options = _profileForWhomOptions();
    return _StepContent(
      key: const ValueKey('profile_for_whom'),
      title: _t(
        'I am creating this profile for',
        'कोणासाठी प्रोफाइल तयार करत आहात',
      ),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: options.map((option) {
            final selected = _profileForWhom?.identity == option.identity;
            return ChoiceChip(
              label: Text(_relationLabel(option)),
              selected: selected,
              selectedColor: _selectedGreenSurface,
              checkmarkColor: _selectedGreen,
              labelStyle: TextStyle(
                color: selected ? _selectedGreen : Colors.grey.shade900,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(
                  color: selected ? _selectedGreen : Colors.grey.shade300,
                  width: selected ? 1.5 : 1,
                ),
              ),
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              onSelected: _loading
                  ? null
                  : (_) {
                      setState(() {
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
          }).toList(),
        ),
        if (_profileForWhom != null) ...[
          if (_needsGenderWarmup) ...[
            const SizedBox(height: 20),
            Text(
              _genderPromptLabel(),
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            _buildGenderSegmentedControl(context),
          ],
          const SizedBox(height: 20),
          OnboardingErrorHighlight(
            hasError: _motherTongueError != null,
            pulseKey:
                'mother_tongue:$_fieldErrorPulseToken:$_motherTongueError',
            child: OnboardingPickerField(
              label: '${_motherTongueLabel()} *',
              selectedItems: _motherTongue?.intId == null
                  ? const []
                  : [_motherTongue!],
              placeholder: _t('Select mother tongue', 'मातृभाषा निवडा'),
              searchHint: _t('Search mother tongue', 'मातृभाषा शोधा'),
              errorText: _motherTongueError,
              loadPage: (query, page, limit) => _staticOptionsPage(
                _motherTongueOptions(),
                query,
                page,
                limit,
              ),
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
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _loading ? null : _continueFromProfileForWhom,
          child: _loading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_t('Continue', 'पुढे जा')),
        ),
      ],
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
  const _StepContent({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 14),
        ...children,
      ],
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.currentStep, required this.totalSteps});

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: List.generate(totalSteps, (index) {
        final active = index <= currentStep;
        return Expanded(
          child: Container(
            height: 5,
            margin: EdgeInsets.only(right: index == totalSteps - 1 ? 0 : 6),
            decoration: BoxDecoration(
              color: active ? colorScheme.primary : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        );
      }),
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
class _MessageBanner extends StatelessWidget {
  const _MessageBanner({required this.message, required this.type});

  final String message;
  final _OnboardingMessageType type;

  @override
  Widget build(BuildContext context) {
    final color = switch (type) {
      _OnboardingMessageType.success => Colors.green.shade700,
      _OnboardingMessageType.warning => Colors.amber.shade800,
      _OnboardingMessageType.info => Theme.of(context).colorScheme.primary,
    };
    final icon = switch (type) {
      _OnboardingMessageType.success => Icons.check_circle_outline,
      _OnboardingMessageType.warning => Icons.info_outline,
      _OnboardingMessageType.info => Icons.info_outline,
    };

    return _Banner(message: message, icon: icon, color: color);
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return _Banner(
      message: message,
      icon: Icons.error_outline,
      color: Colors.red.shade700,
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.message,
    required this.icon,
    required this.color,
  });

  final String message;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
