import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_language.dart';
import '../../core/app_storage.dart';
import '../../core/app_strings.dart';
import 'models/mobile_otp_models.dart';
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
import 'widgets/onboarding_picker_field.dart';

enum _SmartOnboardingStep {
  language,
  profileForWhom,
  mobileOtp,
  accountDetails,
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

class SmartOnboardingScreen extends StatefulWidget {
  const SmartOnboardingScreen({super.key});

  @override
  State<SmartOnboardingScreen> createState() => _SmartOnboardingScreenState();
}

class _SmartOnboardingScreenState extends State<SmartOnboardingScreen> {
  static const String _consentVersion = '2026-06-24';
  static const Color _selectedGreen = Color(0xFF0F8F5F);
  static const Color _selectedGreenSurface = Color(0xFFE7F6ED);
  static const List<_SmartOnboardingStep> _progressSteps =
      <_SmartOnboardingStep>[
        _SmartOnboardingStep.basicInfo,
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
  final TextEditingController _creatorNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  _SmartOnboardingStep _step = _SmartOnboardingStep.language;
  AppLanguage _language = currentAppLanguage;
  OnboardingBootstrap _bootstrap = OnboardingBootstrap.fallbackProfileForWhom();
  OnboardingStatus? _status;
  OnboardingOption? _profileForWhom;
  OnboardingOption? _warmupGender;
  OnboardingOption? _motherTongue;
  MobileOtpSendResponse? _otpChallenge;
  Map<String, dynamic> _serverDraftData = <String, dynamic>{};
  List<OnboardingOption> _motherTongues = const <OnboardingOption>[];

  bool _loading = false;
  bool _termsAccepted = false;
  bool _privacyAccepted = false;
  bool _whatsappAlertsOptIn = false;
  String? _error;
  String? _message;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _mobileController.dispose();
    _otpController.dispose();
    _creatorNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    final savedLanguage = await AppStorage.instance.readLanguage();
    await ApiClient.restoreSessionFromStorage();
    await _restoreLocalDraft();

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
        if (status.account['creator_name_present'] == false) {
          _step = _SmartOnboardingStep.accountDetails;
        } else if (status.draft == null && !status.hasProfile) {
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
      _step = savedLanguage == null
          ? _SmartOnboardingStep.language
          : _SmartOnboardingStep.profileForWhom;
    });
  }

  String _t(String english, String marathi) {
    return _language == AppLanguage.marathi ? marathi : english;
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

  _SmartOnboardingStep _stepFromStatus(OnboardingStatus status) {
    final next = status.nextStep ?? status.draft?.currentStep;
    return _stepFromServerName(next);
  }

  _SmartOnboardingStep _stepFromServerName(String? step) {
    switch (step) {
      case 'account':
        return _SmartOnboardingStep.accountDetails;
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
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 12 && digits.startsWith('91')) {
      return digits.substring(2);
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
      _creatorNameController.text = draft['creator_name']?.toString() ?? '';
      _emailController.text = draft['email']?.toString() ?? '';
      final profileForWhom = onboardingText(draft['profile_for_whom']);
      if (profileForWhom != null) {
        _profileForWhom = _profileOptionFromKey(profileForWhom);
      }
      _warmupGender = optionFromData(draft['warmup_gender']);
      _motherTongue = optionFromData(draft['mother_tongue_option']);
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
    final draft = <String, dynamic>{
      'locale': _localeCode,
      'step': _step.name,
      'mobile_masked': _maskedMobile(),
      'creator_name': _creatorNameController.text.trim(),
      'email': _emailController.text.trim(),
      'profile_for_whom': _profileForWhom?.key,
      if (_warmupGender != null) 'warmup_gender': _warmupGender!.toJson(),
      if (_motherTongue != null)
        'mother_tongue_option': _motherTongue!.toJson(),
    };
    await AppStorage.instance.saveOnboardingDraftJson(jsonEncode(draft));
  }

  Future<void> _selectLanguage(AppLanguage language) async {
    setState(() {
      _language = language;
      _error = null;
      _message = null;
      _step = _SmartOnboardingStep.profileForWhom;
    });
    setAppLanguage(language);
    await AppStorage.instance.saveLanguage(language);
    await _saveLocalDraft();
  }

  Future<void> _setLanguage(AppLanguage next) async {
    if (_language == next) return;
    setState(() {
      _language = next;
      _error = null;
      _message = null;
    });
    setAppLanguage(next);
    await AppStorage.instance.saveLanguage(next);
    await _saveLocalDraft();
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
    if (!_termsAccepted || !_privacyAccepted) {
      setState(() {
        _error = _t(
          'Accept Terms and Privacy Policy to receive OTP.',
          'OTP मिळण्यासाठी Terms आणि Privacy Policy स्वीकारा.',
        );
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _message = null;
    });

    final data = await ApiClient.sendMobileOtp(
      mobile: mobile,
      locale: _localeCode,
      termsAccepted: _termsAccepted,
      privacyAccepted: _privacyAccepted,
      termsVersion: _consentVersion,
      privacyVersion: _consentVersion,
      whatsappAlertsOptIn: _whatsappAlertsOptIn,
    );

    if (!mounted) return;
    final response = MobileOtpSendResponse.fromJson(data);
    setState(() {
      _loading = false;
      _otpChallenge = response;
      if (response.success && response.challengeId != null) {
        _message =
            response.message ?? _t('OTP sent successfully.', 'OTP पाठवला आहे.');
      } else {
        _error =
            response.message ??
            _t('Could not send OTP.', 'OTP पाठवता आला नाही.');
      }
    });

    if (response.success && response.challengeId != null) {
      await _saveLocalDraft();
    }
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
      _error = null;
      _message = null;
    });

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
      _message = _t('Mobile verified.', 'मोबाइल पडताळणी पूर्ण झाली.');
    });

    if (!mounted) return;
    if (nextAction == 'account_details') {
      setState(() => _step = _SmartOnboardingStep.accountDetails);
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
  }

  Future<void> _routeAfterAccountDetailsSaved() async {
    await _loadBootstrap();
    if (!mounted) return;
    if (_profileForWhom != null) {
      setState(() => _loading = false);
      await _startOnboardingAfterAuth();
      return;
    }

    setState(() {
      _loading = false;
      _step = _SmartOnboardingStep.profileForWhom;
      _message = _t('Details saved.', 'माहिती save झाली.');
    });
    await _saveLocalDraft();
  }

  Future<void> _saveAccountDetails() async {
    final creatorName = _creatorNameController.text.trim();
    if (creatorName.isEmpty) {
      setState(() {
        _error = _t('Enter your name.', 'तुमचे नाव भरा.');
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _message = null;
    });

    final data = await ApiClient.updateAccountDetails(
      creatorName: creatorName,
      email: null,
      locale: _localeCode,
      whatsappAlertsOptIn: _whatsappAlertsOptIn,
    );

    if (!mounted) return;
    final success = data['success'] == true;
    final statusCode = data['statusCode'];
    if (!success) {
      setState(() {
        _loading = false;
        _error = statusCode == 409
            ? _t(
                'This email is already linked to another account.',
                'हा email दुसऱ्या account ला जोडलेला आहे.',
              )
            : data['message']?.toString() ??
                  _t('Could not save details.', 'माहिती save झाली नाही.');
      });
      return;
    }

    await _routeAfterAccountDetailsSaved();
  }

  Future<void> _loadBootstrap() async {
    try {
      final data = await ApiClient.getOnboardingBootstrap(locale: _localeCode);
      final parsed = OnboardingBootstrap.fromJson(data);
      final motherTongues = parsed.motherTongues.isEmpty
          ? await _loadMotherTongueOptions()
          : parsed.motherTongues;
      if (!mounted) return;
      setState(() {
        _bootstrap = parsed.profileForWhom.isEmpty
            ? OnboardingBootstrap.fallbackProfileForWhom()
            : parsed;
        _motherTongues = motherTongues;
        _motherTongue = _resolveSelectedMotherTongue(
          _motherTongue,
          motherTongues,
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _bootstrap = OnboardingBootstrap.fallbackProfileForWhom();
        if (_motherTongues.isEmpty) {
          _motherTongues = _fallbackMotherTongues();
        }
      });
    }
  }

  Future<List<OnboardingOption>> _loadMotherTongueOptions() async {
    if (!_isAuthenticated) return _fallbackMotherTongues();

    try {
      final data = await ApiClient.getProfileBasicPhysicalOptions();
      final rows = data['mother_tongues'] ?? <Map<String, dynamic>>[];
      final options = OnboardingOption.listFrom(rows);
      return options.isEmpty ? _fallbackMotherTongues() : options;
    } catch (_) {
      return _fallbackMotherTongues();
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
      });
      return;
    }

    if (!keepLoadingState) {
      setState(() {
        _loading = true;
        _error = null;
        _message = null;
      });
    }

    final data = await ApiClient.startOnboarding(
      profileForWhom: profileForWhom,
    );
    if (!mounted) return;
    if (data['success'] != true) {
      setState(() {
        _loading = false;
        _error =
            data['message']?.toString() ??
            _t('Could not continue.', 'पुढे जाता आले नाही.');
      });
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
    if (nextStep == _SmartOnboardingStep.language ||
        nextStep == _SmartOnboardingStep.profileForWhom ||
        nextStep == _SmartOnboardingStep.mobileOtp) {
      nextStep = _SmartOnboardingStep.basicInfo;
    }
    setState(() {
      _loading = false;
      _step = nextStep;
      _message = _t('Saved. Add basic details.', 'Save झाले. थोडी माहिती भरा.');
    });
    await _saveLocalDraft();
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
    final data = _serverDraftData[step];
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }

  void _mergeDraftStepData(String step, Map<String, dynamic> data) {
    _serverDraftData = <String, dynamic>{
      ..._serverDraftData,
      step: <String, dynamic>{..._draftStepData(step), ...data},
    };
  }

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
      });
      return false;
    }

    final payloadData = await _dataForOnboardingStep(step, data);
    if (payloadData == null) return false;

    setState(() {
      _loading = true;
      _error = null;
      _message = null;
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
        setState(() {
          _loading = false;
          _error = readableApiError(
            draftResponse,
            _t('Could not save details.', 'माहिती save झाली नाही.'),
          );
        });
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
          setState(() {
            _loading = false;
            _error = readableApiError(
              profileResponse!,
              _t('Could not save details.', 'माहिती save झाली नाही.'),
            );
          });
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
      setState(() {
        _loading = false;
        _message = _t('Saved.', 'Save झाले.');
        if (advance) {
          _step = step == 'photo'
              ? _SmartOnboardingStep.activation
              : _nextProfileStep(_step);
        }
      });
      await _saveLocalDraft();
      return true;
    } catch (error) {
      if (!mounted) return false;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
      return false;
    }
  }

  Future<Map<String, dynamic>?> _dataForOnboardingStep(
    String step,
    Map<String, dynamic> data,
  ) async {
    if (step != 'basic_info' || _motherTongue == null) {
      return data;
    }

    var motherTongue = _motherTongue;
    if (motherTongue?.intId == null) {
      final options = await _loadMotherTongueOptions();
      motherTongue = _resolveSelectedMotherTongue(motherTongue, options);
      if (mounted) {
        setState(() {
          _motherTongues = options;
          _motherTongue = motherTongue;
        });
      }
    }

    final motherTongueId = motherTongue?.intId;
    if (motherTongueId == null) {
      if (mounted) {
        setState(() {
          _error = _t(
            'Choose mother tongue again from the list.',
            'मातृभाषा पुन्हा यादीतून निवडा.',
          );
        });
      }
      return null;
    }

    return <String, dynamic>{...data, 'mother_tongue_id': motherTongueId};
  }

  void _goBackOneStep() {
    setState(() {
      _error = null;
      _message = null;
      _step = _previousProfileStep(_step);
    });
  }

  void _showStepMessage(String message) {
    setState(() {
      _message = message;
      _error = null;
    });
  }

  void _syncProfileForWhomFromDraft() {
    final data = _draftStepData('profile_for_whom');
    final value = onboardingText(data['profile_for_whom']);
    if (value == null) return;
    _profileForWhom = _profileOptionFromKey(value);
  }

  Future<void> _continueFromProfileForWhom() async {
    if (_profileForWhom == null) {
      setState(() {
        _error = _t(
          'Choose who this profile is for.',
          'ही प्रोफाइल कोणासाठी आहे ते निवडा.',
        );
      });
      return;
    }

    if (_needsGenderWarmup && _warmupGender == null) {
      setState(() {
        _error = _t('Choose profile gender.', 'प्रोफाइलचा लिंग प्रकार निवडा.');
      });
      return;
    }
    if (_motherTongue == null) {
      setState(() {
        _error = _t('Choose mother tongue.', 'मातृभाषा निवडा.');
      });
      return;
    }

    await _saveLocalDraft();
    await _continueAfterWarmup();
  }

  Future<void> _continueAfterWarmup() async {
    if (_isAuthenticated) {
      await _startOnboardingAfterAuth();
      return;
    }

    setState(() {
      _error = null;
      _message = null;
      _step = _SmartOnboardingStep.mobileOtp;
    });
  }

  void _startExistingMobileFlow() {
    setState(() {
      _error = null;
      _message = _t(
        'Verify mobile to continue.',
        'पुढे जाण्यासाठी मोबाइल पडताळा.',
      );
      _step = _SmartOnboardingStep.mobileOtp;
    });
  }

  void _goBackFromMobile() {
    setState(() {
      _error = null;
      _message = null;
      _step = _SmartOnboardingStep.profileForWhom;
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

  List<OnboardingOption> _motherTongueOptions() {
    return _motherTongues.isEmpty ? _fallbackMotherTongues() : _motherTongues;
  }

  List<OnboardingOption> _fallbackMotherTongues() {
    const labels = <String>[
      'Marathi',
      'Hindi',
      'English',
      'Gujarati',
      'Kannada',
      'Tamil',
      'Telugu',
      'Malayalam',
      'Punjabi',
      'Bengali',
    ];

    return labels
        .map(
          (label) => OnboardingOption(
            key: label.toLowerCase().replaceAll(' ', '_'),
            label: label,
          ),
        )
        .toList();
  }

  OnboardingOption? _resolveSelectedMotherTongue(
    OnboardingOption? selected,
    List<OnboardingOption> options,
  ) {
    if (selected == null || options.isEmpty) return selected;
    if (selected.intId != null) {
      return optionById(options, selected.intId) ?? selected;
    }

    final byKey = optionByKey(options, selected.key);
    if (byKey != null) return byKey;

    final wanted = _normalizeLookupLabel(selected.label);
    for (final option in options) {
      if (_normalizeLookupLabel(option.label) == wanted) {
        return option;
      }
    }

    return selected;
  }

  String _normalizeLookupLabel(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('Create Profile', 'प्रोफाइल तयार करा')),
        actions: [
          if (_step != _SmartOnboardingStep.language)
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
                if (_showProgress) ...[
                  _StepIndicator(
                    currentStep: _progressIndex,
                    totalSteps: _progressSteps.length,
                  ),
                  const SizedBox(height: 14),
                ],
                if (_message != null) _InfoBanner(message: _message!),
                if (_error != null) _ErrorBanner(message: _error!),
                if (_message != null || _error != null)
                  const SizedBox(height: 12),
                _buildStepCard(context),
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
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.appName,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _showProgress
              ? _t('Almost done', 'थोडी माहिती पूर्ण करा')
              : _t('Let’s create a profile', 'चला, प्रोफाइल तयार करूया'),
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
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
            _SmartOnboardingStep.language => _buildLanguageStep(context),
            _SmartOnboardingStep.profileForWhom => _buildProfileForWhomStep(
              context,
            ),
            _SmartOnboardingStep.mobileOtp => _buildMobileOtpStep(context),
            _SmartOnboardingStep.accountDetails => _buildAccountDetailsStep(
              context,
            ),
            _SmartOnboardingStep.basicInfo => BasicCandidateInfoStep(
              data: _draftStepData('basic_info'),
              bootstrap: _bootstrap,
              account: _status?.account ?? const <String, dynamic>{},
              profileForWhom: _profileForWhom,
              warmupGender: _warmupGender,
              locale: _localeCode,
              loading: _loading,
              onSave: _saveOnboardingStep,
              onBack: _goBackOneStep,
              onMessage: _showStepMessage,
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
              account: _status?.account ?? const <String, dynamic>{},
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

  Widget _buildLanguageStep(BuildContext context) {
    return _StepContent(
      key: const ValueKey('language'),
      title: _t('Choose language', 'भाषा निवडा'),
      children: [
        Text(
          _t(
            'You can change language before sending OTP.',
            'OTP पाठवण्यापूर्वी भाषा बदलू शकता.',
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _loading
              ? null
              : () => _selectLanguage(AppLanguage.marathi),
          child: const Text('मराठी'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: _loading
              ? null
              : () => _selectLanguage(AppLanguage.english),
          child: const Text('English'),
        ),
      ],
    );
  }

  Widget _buildMobileOtpStep(BuildContext context) {
    final otpSent = _otpChallenge?.challengeId != null;

    return AutofillGroup(
      key: const ValueKey('mobile'),
      child: _StepContent(
        title: _t('Verify mobile number', 'मोबाइल नंबर पडताळा'),
        children: [
          Text(
            _t(
              'We will send a 6 digit code to continue.',
              'पुढे जाण्यासाठी 6 अंकी code पाठवू.',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _mobileController,
            enabled: !_loading && !otpSent,
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
            decoration: InputDecoration(
              labelText: _t('Mobile number *', 'मोबाइल नंबर *'),
              prefixText: '+91 ',
            ),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: _termsAccepted,
            onChanged: _loading
                ? null
                : (value) => setState(() => _termsAccepted = value ?? false),
            title: Text(_t('I accept Terms.', 'मी Terms स्वीकारतो.')),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          CheckboxListTile(
            value: _privacyAccepted,
            onChanged: _loading
                ? null
                : (value) => setState(() => _privacyAccepted = value ?? false),
            title: Text(
              _t('I accept Privacy Policy.', 'मी Privacy Policy स्वीकारतो.'),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          CheckboxListTile(
            value: _whatsappAlertsOptIn,
            onChanged: _loading
                ? null
                : (value) =>
                      setState(() => _whatsappAlertsOptIn = value ?? false),
            title: Text(
              _t(
                'Send profile alerts on WhatsApp',
                'Profile alerts WhatsApp वर पाठवा',
              ),
            ),
            subtitle: Text(
              _t(
                'This does not verify WhatsApp.',
                'यामुळे WhatsApp verify होत नाही.',
              ),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (!otpSent && !_isAuthenticated) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : _goBackFromMobile,
                    icon: const Icon(Icons.arrow_back),
                    label: Text(_t('Back', 'मागे')),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _loading || otpSent ? null : _sendOtp,
                  child: _loading && !otpSent
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_t('Send code', 'Code पाठवा')),
                ),
              ),
            ],
          ),
          if (otpSent) ...[
            const SizedBox(height: 18),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              decoration: InputDecoration(
                labelText: _t('Verification code', 'पडताळणी code'),
                helperText: _otpChallenge?.resendAfter == null
                    ? null
                    : _t(
                        'You can resend after ${_otpChallenge!.resendAfter}s.',
                        '${_otpChallenge!.resendAfter}s नंतर code पुन्हा पाठवू शकता.',
                      ),
              ),
            ),
            if (!kReleaseMode && _otpChallenge?.debugOtp != null) ...[
              const SizedBox(height: 8),
              Text(
                'Debug code: ${_otpChallenge!.debugOtp}',
                style: Theme.of(context).textTheme.bodySmall,
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
            TextButton(
              onPressed: _loading
                  ? null
                  : () => setState(() {
                      _otpChallenge = null;
                      _otpController.clear();
                    }),
              child: Text(_t('Change mobile number', 'मोबाइल नंबर बदला')),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAccountDetailsStep(BuildContext context) {
    return _StepContent(
      key: const ValueKey('account'),
      title: _t('Your name', 'तुमचे नाव'),
      children: [
        TextField(
          controller: _creatorNameController,
          decoration: InputDecoration(
            labelText: _t('Your name *', 'तुमचे नाव *'),
            helperText: _t(
              'This helps us manage your account.',
              'यामुळे तुमचे account व्यवस्थित ठेवता येते.',
            ),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _loading ? null : _saveAccountDetails,
          child: _loading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_t('Save and continue', 'Save करून पुढे जा')),
        ),
      ],
    );
  }

  Widget _buildProfileForWhomStep(BuildContext context) {
    final options = _profileForWhomOptions();
    return _StepContent(
      key: const ValueKey('profile_for_whom'),
      title: _t(
        'I am creating this profile for',
        'मी ही प्रोफाइल तयार करत आहे',
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
              _t('Profile gender', 'प्रोफाइलचा लिंग प्रकार'),
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _profileGenderOptions().map((option) {
                final selected = _warmupGender?.identity == option.identity;
                final key = option.key?.toLowerCase();
                final label = key == 'male'
                    ? _t('Groom', 'वर')
                    : key == 'female'
                    ? _t('Bride', 'वधू')
                    : option.label;
                return ChoiceChip(
                  label: Text(label),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  onSelected: _loading
                      ? null
                      : (_) {
                          setState(() {
                            _warmupGender = option;
                            _error = null;
                            _message = null;
                          });
                          _saveLocalDraft();
                        },
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 20),
          OnboardingPickerField(
            label: _t('Mother tongue *', 'मातृभाषा *'),
            selectedItems: _motherTongue == null ? const [] : [_motherTongue!],
            placeholder: _t('Select mother tongue', 'मातृभाषा निवडा'),
            searchHint: _t('Search mother tongue', 'मातृभाषा शोधा'),
            loadPage: (query, page, limit) =>
                _staticOptionsPage(_motherTongueOptions(), query, page, limit),
            onChanged: (items) {
              setState(() {
                _motherTongue = items.isEmpty ? null : items.first;
                _error = null;
                _message = null;
              });
              _saveLocalDraft();
            },
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
        onboardingText(_status?.account['name']) ??
        onboardingText(_creatorNameController.text);
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

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return _Banner(
      message: message,
      icon: Icons.info_outline,
      color: Theme.of(context).colorScheme.primary,
    );
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
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}
