import 'dart:convert';

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
  mobileOtp,
  accountDetails,
  profileForWhom,
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

  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _creatorNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  _SmartOnboardingStep _step = _SmartOnboardingStep.language;
  AppLanguage _language = currentAppLanguage;
  OnboardingBootstrap _bootstrap = OnboardingBootstrap.fallbackProfileForWhom();
  OnboardingStatus? _status;
  OnboardingOption? _profileForWhom;
  MobileOtpSendResponse? _otpChallenge;
  Map<String, dynamic> _serverDraftData = <String, dynamic>{};

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
    final language = savedLanguage ?? currentAppLanguage;
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
    }
  }

  String _t(String english, String marathi) {
    return _language == AppLanguage.marathi ? marathi : english;
  }

  String get _localeCode => appLanguageCode(_language);

  bool get _isAuthenticated =>
      ApiClient.authToken != null && ApiClient.authToken!.isNotEmpty;

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
    };
    await AppStorage.instance.saveOnboardingDraftJson(jsonEncode(draft));
  }

  Future<void> _selectLanguage(AppLanguage language) async {
    setState(() {
      _language = language;
      _error = null;
      _message = null;
      _step = _SmartOnboardingStep.mobileOtp;
    });
    setAppLanguage(language);
    await AppStorage.instance.saveLanguage(language);
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
      if (nextAction == 'account_details') {
        _step = _SmartOnboardingStep.accountDetails;
      } else if (nextAction == 'resume_onboarding' ||
          response.accountState?.hasProfile == true) {
        _step = _status == null
            ? _SmartOnboardingStep.activation
            : _stepFromStatus(_status!);
      } else {
        _step = _SmartOnboardingStep.profileForWhom;
      }
    });
    await _saveLocalDraft();
  }

  Future<void> _saveAccountDetails() async {
    final creatorName = _creatorNameController.text.trim();
    final email = _emailController.text.trim();
    if (creatorName.isEmpty) {
      setState(() {
        _error = _t(
          'Enter account creator name.',
          'Account creator चे नाव भरा.',
        );
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
      email: email.isEmpty ? null : email,
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
                  _t(
                    'Could not save account details.',
                    'Account तपशील save झाले नाहीत.',
                  );
      });
      return;
    }

    await _loadBootstrap();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _step = _SmartOnboardingStep.profileForWhom;
      _message = _t('Account details saved.', 'Account तपशील save झाले.');
    });
    await _saveLocalDraft();
  }

  Future<void> _loadBootstrap() async {
    try {
      final data = await ApiClient.getOnboardingBootstrap(locale: _localeCode);
      final parsed = OnboardingBootstrap.fromJson(data);
      if (!mounted) return;
      setState(() {
        _bootstrap = parsed.profileForWhom.isEmpty
            ? OnboardingBootstrap.fallbackProfileForWhom()
            : parsed;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _bootstrap = OnboardingBootstrap.fallbackProfileForWhom();
      });
    }
  }

  Future<void> _startOnboarding() async {
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

    setState(() {
      _loading = true;
      _error = null;
      _message = null;
    });

    final data = await ApiClient.startOnboarding(
      profileForWhom: profileForWhom,
    );
    if (!mounted) return;
    if (data['success'] != true) {
      setState(() {
        _loading = false;
        _error =
            data['message']?.toString() ??
            _t('Could not start onboarding.', 'Onboarding सुरू झाले नाही.');
      });
      return;
    }

    await _loadStatus(goToStatus: true);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _message = _t(
        'Onboarding started. Add candidate details.',
        'Onboarding सुरू झाले. Candidate तपशील भरा.',
      );
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

    setState(() {
      _loading = true;
      _error = null;
      _message = null;
    });

    try {
      final draftResponse = await ApiClient.saveOnboardingDraftStep(
        step: step,
        data: data,
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
            _t('Could not save draft.', 'Draft save झाले नाही.'),
          );
        });
        return false;
      }

      _mergeDraftStepData(step, data);
      final draft = draftResponse['draft'];
      if (draft is Map && draft['data'] is Map) {
        _serverDraftData = Map<String, dynamic>.from(draft['data'] as Map);
      }

      Map<String, dynamic>? profileResponse;
      if (saveProfile && step != 'photo') {
        profileResponse = await ApiClient.saveOnboardingProfileStep(
          step: step,
          data: data,
        );
        if (!mounted) return false;
        if (profileResponse['success'] != true) {
          setState(() {
            _loading = false;
            _error = readableApiError(
              profileResponse!,
              _t(
                'Could not save profile step.',
                'Profile step save झाला नाही.',
              ),
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
    _profileForWhom =
        optionByKey(_bootstrap.profileForWhom, value) ??
        OnboardingOption(key: value, label: value);
  }

  Future<PagedLookupResponse> _profileForWhomPage(
    String query,
    int page,
    int limit,
  ) async {
    final normalized = query.trim().toLowerCase();
    final rows = _bootstrap.profileForWhom
        .where(
          (option) =>
              normalized.isEmpty ||
              option.label.toLowerCase().contains(normalized) ||
              (option.key?.toLowerCase().contains(normalized) ?? false),
        )
        .toList();

    final start = (page - 1) * limit;
    final pageRows = start >= rows.length
        ? <OnboardingOption>[]
        : rows.skip(start).take(limit).toList();

    return PagedLookupResponse.fromOptions(pageRows);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Smart Onboarding')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildHeader(context),
            const SizedBox(height: 14),
            _StepIndicator(
              currentStep: _step.index,
              totalSteps: _SmartOnboardingStep.values.length,
            ),
            const SizedBox(height: 14),
            if (_message != null) _InfoBanner(message: _message!),
            if (_error != null) _ErrorBanner(message: _error!),
            if (_message != null || _error != null) const SizedBox(height: 12),
            _buildStepCard(context),
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
          _t(
            'OTP-first matrimony onboarding',
            'OTP-first matrimony onboarding',
          ),
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
            _SmartOnboardingStep.mobileOtp => _buildMobileOtpStep(context),
            _SmartOnboardingStep.accountDetails => _buildAccountDetailsStep(
              context,
            ),
            _SmartOnboardingStep.profileForWhom => _buildProfileForWhomStep(
              context,
            ),
            _SmartOnboardingStep.basicInfo => BasicCandidateInfoStep(
              data: _draftStepData('basic_info'),
              bootstrap: _bootstrap,
              account: _status?.account ?? const <String, dynamic>{},
              profileForWhom: _profileForWhom,
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
              locale: _localeCode,
              loading: _loading,
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

    return _StepContent(
      key: const ValueKey('mobile'),
      title: _t('Verify mobile number', 'मोबाइल नंबर पडताळा'),
      children: [
        TextField(
          controller: _mobileController,
          enabled: !_loading && !otpSent,
          keyboardType: TextInputType.phone,
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
        ElevatedButton(
          onPressed: _loading || otpSent ? null : _sendOtp,
          child: _loading && !otpSent
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_t('Send OTP', 'OTP पाठवा')),
        ),
        if (otpSent) ...[
          const SizedBox(height: 18),
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: _t('OTP', 'OTP'),
              helperText: _otpChallenge?.resendAfter == null
                  ? null
                  : _t(
                      'You can resend after ${_otpChallenge!.resendAfter}s.',
                      '${_otpChallenge!.resendAfter}s नंतर OTP पुन्हा पाठवू शकता.',
                    ),
            ),
          ),
          if (_otpChallenge?.debugOtp != null) ...[
            const SizedBox(height: 8),
            Text(
              'Debug OTP: ${_otpChallenge!.debugOtp}',
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
                : Text(_t('Verify OTP', 'OTP पडताळा')),
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
    );
  }

  Widget _buildAccountDetailsStep(BuildContext context) {
    return _StepContent(
      key: const ValueKey('account'),
      title: _t('Account details', 'Account तपशील'),
      children: [
        TextField(
          controller: _creatorNameController,
          decoration: InputDecoration(
            labelText: _t('Creator name *', 'Creator नाव *'),
            helperText: _t(
              'This is account holder name, not candidate name.',
              'हे account holder चे नाव आहे, candidate चे नाही.',
            ),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: _t('Email (optional)', 'Email (optional)'),
            helperText: _t(
              'You can skip email. No fake email will be created.',
              'Email skip करू शकता. Fake email तयार होणार नाही.',
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
    return _StepContent(
      key: const ValueKey('profile_for_whom'),
      title: _t('Profile for whom?', 'Profile कोणासाठी?'),
      children: [
        OnboardingPickerField(
          label: _t('Profile for whom', 'Profile कोणासाठी'),
          selectedItems: _profileForWhom == null
              ? const <OnboardingOption>[]
              : [_profileForWhom!],
          placeholder: _t('Select', 'निवडा'),
          searchHint: _t('Search relation', 'Relation शोधा'),
          loadPage: _profileForWhomPage,
          itemSubtitleBuilder: (option) {
            final mode = option.meta['gender_mode']?.toString();
            if (mode == null || mode.isEmpty) return null;
            return _t('Gender mode: $mode', 'Gender mode: $mode');
          },
          onChanged: (items) {
            setState(() {
              _profileForWhom = items.isEmpty ? null : items.first;
            });
            _saveLocalDraft();
          },
        ),
        const SizedBox(height: 12),
        Text(
          _t(
            'Candidate name is not collected in this foundation step.',
            'या foundation step मध्ये candidate चे नाव घेतले जात नाही.',
          ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _loading ? null : _startOnboarding,
          child: _loading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_t('Start onboarding', 'Onboarding सुरू करा')),
        ),
      ],
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
