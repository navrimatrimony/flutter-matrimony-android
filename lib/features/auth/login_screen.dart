import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_client.dart';
import '../../core/api_error_text.dart';
import '../../core/app_consent.dart';
import '../../core/app_language.dart';
import '../../core/app_storage.dart';
import '../../core/app_strings.dart';
import '../../core/google_auth_flow.dart';
import '../../core/google_brand_mark.dart';
import '../../core/post_auth_router.dart';
import '../../core/mobile_number.dart';
import '../../core/phone_number_hint_service.dart';
// Reused, not re-declared: registration already parses these two responses, and
// the mobile-OTP contract has exactly one shape. A second copy of it here is the
// duplicate that eventually drifts.
import '../onboarding/models/mobile_otp_models.dart';

/// How the member proves who they are.
///
/// Registration signs a member in with a mobile OTP and nothing else, so OTP is
/// the default here too — a rural family should not have to remember a password
/// they were never asked to create. Password stays as an equal second door for
/// the members who do have one (it also accepts email / username, which OTP
/// cannot).
enum _LoginMethod { otp, password }

/// Route argument for `/login` that opens the OTP door on a number the member
/// already typed somewhere else.
///
/// Today that somewhere is the forgot-password screen: a member with no email
/// cannot be sent a reset link, so her number is carried here instead of being
/// retyped, and the code is requested on arrival. Anything else pushed at
/// `/login` without this argument gets the ordinary empty screen.
class MobileOtpLoginRequest {
  const MobileOtpLoginRequest(this.mobile);

  /// Normalised by the caller through `MobileNumberInput`; re-normalised here
  /// anyway, because a route argument can come from anywhere.
  final String mobile;
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.otpRequest});

  final MobileOtpLoginRequest? otpRequest;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController loginController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController mobileController = TextEditingController();
  final TextEditingController otpController = TextEditingController();
  final FocusNode _mobileFocus = FocusNode();

  _LoginMethod _method = _LoginMethod.otp;

  bool isLoading = false;
  String errorMessage = '';
  bool _obscurePassword = true;

  MobileOtpSendResponse? _challenge;
  String? _testOtpCode;
  String? _deliveryHint;

  Timer? _resendTimer;
  Timer? _autoVerifyTimer;
  DateTime? _resendAvailableAt;
  int _resendSecondsRemaining = 0;
  String? _lastAutoVerifyAttempt;

  bool get _otpSent => _challenge?.challengeId != null;

  @override
  void initState() {
    super.initState();
    _applyOtpRequest();
    _loadSavedLoginPreference();
    otpController.addListener(_onOtpChanged);
  }

  /// Opens the OTP door on a number handed over by another screen.
  ///
  /// The send is deliberately fired here rather than left as a button the
  /// member has to find: she arrived by pressing an action that said a code
  /// would be sent, so the screen owes her the code, not another tap. Every
  /// failure route out of [_sendOtp] paints a message and stops the spinner, so
  /// an auto-send that fails leaves a screen she can still use.
  void _applyOtpRequest() {
    final requested = widget.otpRequest?.mobile ?? '';
    if (!MobileNumberInput.isComplete(requested)) return;

    _method = _LoginMethod.otp;
    mobileController.text = MobileNumberInput.normalize(requested);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || isLoading || _otpSent) return;
      unawaited(_sendOtp());
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _autoVerifyTimer?.cancel();
    otpController.removeListener(_onOtpChanged);
    loginController.dispose();
    passwordController.dispose();
    mobileController.dispose();
    otpController.dispose();
    _mobileFocus.dispose();
    super.dispose();
  }

  Future<void> _loadSavedLoginPreference() async {
    final rememberedLogin = await AppStorage.instance
        .readRememberedLoginIdentifier();
    if (!mounted) return;
    final remembered = rememberedLogin?.trim() ?? '';
    if (remembered.isEmpty) return;

    setState(() {
      if (loginController.text.trim().isEmpty) {
        loginController.text = remembered;
      }
      // The same stored identifier seeds the OTP field, but only when it really
      // is a mobile number — an email or a username must not land there.
      if (mobileController.text.trim().isEmpty &&
          MobileNumberInput.isComplete(remembered)) {
        mobileController.text = MobileNumberInput.normalize(remembered);
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Mobile OTP
  // ---------------------------------------------------------------------------

  Future<void> _pickMobileFromSim() async {
    final raw = await PhoneNumberHintService.requestPhoneNumberHint();
    if (!mounted || raw == null) return;
    final mobile = MobileNumberInput.normalize(raw);
    if (mobile.length != 10) return;
    setState(() {
      mobileController.text = mobile;
      errorMessage = '';
    });
  }

  Future<void> _sendOtp() async {
    final mobile = MobileNumberInput.normalize(mobileController.text);
    if (mobile.length != 10) {
      setState(() => errorMessage = AppStrings.loginMobileInvalid);
      return;
    }
    mobileController.text = mobile;

    _autoVerifyTimer?.cancel();
    setState(() {
      isLoading = true;
      errorMessage = '';
      _lastAutoVerifyAttempt = null;
    });

    try {
      final data = await ApiClient.sendMobileOtp(
        mobile: mobile,
        locale: appLanguageCode(currentAppLanguage),
        // The login screen shows the same consent line registration shows, and
        // stamps the same version — the server writes a user_consents row for
        // each challenge it verifies.
        termsAccepted: true,
        privacyAccepted: true,
        termsVersion: AppConsent.version,
        privacyVersion: AppConsent.version,
      );
      if (!mounted) return;

      final response = MobileOtpSendResponse.fromJson(data);
      if (!response.success || response.challengeId == null) {
        // A 429 carries the seconds left, so the member is told how long to
        // wait instead of being left to guess.
        final retryAfter = response.resendAfter;
        setState(() {
          errorMessage = _messageOf(data, AppStrings.loginOtpSendFailed);
        });
        if (retryAfter != null && retryAfter > 0) {
          _startResendCooldown(retryAfter);
        }
        return;
      }

      final isTestChannel = response.deliveryChannel == 'dev';
      setState(() {
        _challenge = response;
        // Shown, never typed in for the member. Production is on dev_show right
        // now; if this screen filled the box itself, the only path anyone would
        // ever exercise is the one that disappears the day WhatsApp goes live.
        _testOtpCode = isTestChannel ? response.debugOtp : null;
        _deliveryHint = isTestChannel
            ? AppStrings.loginTestOtpBanner
            : AppStrings.loginOtpWhatsappHint;
      });
      _startResendCooldown(response.resendAfter ?? 60);
    } catch (error) {
      if (!mounted) return;
      setState(() => errorMessage = _networkMessage(error));
    } finally {
      // Whatever route this took out, the spinner stops. A verified member left
      // holding a dead spinner is the exact bug this screen must not grow back.
      if (mounted && isLoading) {
        setState(() => isLoading = false);
      }
    }
  }

  void _onOtpChanged() {
    final otp = otpController.text.trim();
    if (otp.length != 6 || otp != _lastAutoVerifyAttempt) {
      _lastAutoVerifyAttempt = null;
    }
    _scheduleAutoVerify();
  }

  void _scheduleAutoVerify() {
    _autoVerifyTimer?.cancel();
    final otp = otpController.text.trim();
    if (!_otpSent ||
        isLoading ||
        otp.length != 6 ||
        _lastAutoVerifyAttempt == otp) {
      return;
    }
    _autoVerifyTimer = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      unawaited(_verifyOtp(autoTriggered: true));
    });
  }

  Future<void> _verifyOtp({bool autoTriggered = false}) async {
    if (isLoading) return;
    _autoVerifyTimer?.cancel();

    final challengeId = _challenge?.challengeId;
    if (challengeId == null || challengeId.isEmpty) {
      setState(() => errorMessage = AppStrings.loginOtpSendFailed);
      return;
    }

    final otp = otpController.text.trim();
    if (otp.length != 6) {
      // Auto-verify never nags: it only fires at six digits, and a half-typed
      // code is not a mistake worth shouting about.
      if (!autoTriggered) {
        setState(() => errorMessage = AppStrings.loginOtpInvalidLength);
      }
      return;
    }

    _lastAutoVerifyAttempt = otp;
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final data = await ApiClient.verifyMobileOtp(
        challengeId: challengeId,
        mobile: MobileNumberInput.normalize(mobileController.text),
        otp: otp,
      );
      if (!mounted) return;

      final response = MobileOtpVerifyResponse.fromJson(data);
      if (!response.success || (response.token ?? '').isEmpty) {
        // Wrong code, expired challenge, attempt limit, rate limit — the server
        // words each one, and the member reads that wording.
        setState(() {
          errorMessage = _messageOf(data, AppStrings.loginOtpVerifyFailed);
        });
        return;
      }

      // ApiClient.verifyMobileOtp has already stored the token and registered
      // the FCM device token, exactly as ApiClient.login does. From here the
      // two paths are the same screen-for-screen.
      setState(() => isLoading = false);
      await _afterAuthenticated(
        rememberIdentifier: MobileNumberInput.normalize(mobileController.text),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => errorMessage = _networkMessage(error));
    } finally {
      if (mounted && isLoading) {
        setState(() => isLoading = false);
      }
    }
  }

  void _startResendCooldown(int seconds) {
    _resendTimer?.cancel();
    final waitSeconds = seconds <= 0 ? 60 : seconds;
    _resendAvailableAt = DateTime.now().add(Duration(seconds: waitSeconds));
    setState(() => _resendSecondsRemaining = waitSeconds);

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final target = _resendAvailableAt;
      if (!mounted || target == null) {
        timer.cancel();
        return;
      }
      final remaining = target.difference(DateTime.now()).inSeconds;
      if (remaining <= 0) {
        timer.cancel();
        setState(() => _resendSecondsRemaining = 0);
        return;
      }
      setState(() => _resendSecondsRemaining = remaining);
    });
  }

  void _resetOtpChallenge() {
    _resendTimer?.cancel();
    _autoVerifyTimer?.cancel();
    setState(() {
      _challenge = null;
      _testOtpCode = null;
      _deliveryHint = null;
      _resendSecondsRemaining = 0;
      _lastAutoVerifyAttempt = null;
      errorMessage = '';
      otpController.clear();
    });
  }

  // ---------------------------------------------------------------------------
  // Password
  // ---------------------------------------------------------------------------

  Future<void> _handlePasswordLogin() async {
    final loginValue = loginController.text.trim();
    final passwordValue = passwordController.text;
    if (loginValue.isEmpty || passwordValue.isEmpty) {
      setState(() => errorMessage = AppStrings.loginMissingFields);
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final result = await ApiClient.login(
        login: loginValue,
        password: passwordValue,
      );
      if (!mounted) return;

      if (result['token'] == null ||
          result['token'].toString().trim().isEmpty) {
        setState(() {
          errorMessage = _messageOf(result, AppStrings.loginFailed);
        });
        return;
      }

      setState(() => isLoading = false);
      await _afterAuthenticated(rememberIdentifier: loginValue);
    } catch (error) {
      if (!mounted) return;
      setState(() => errorMessage = _networkMessage(error));
    } finally {
      if (mounted && isLoading) {
        setState(() => isLoading = false);
      }
    }
  }

  /// The Google door. [runGoogleAuthFlow] handles the chooser, the server and
  /// the routing, so this only has to keep the screen from being used twice at
  /// once and clear any message left over from an earlier attempt.
  Future<void> _signInWithGoogle() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    await runGoogleAuthFlow(context);

    if (!mounted) return;
    setState(() => isLoading = false);
  }

  // ---------------------------------------------------------------------------
  // Shared post-login handling — one path for every door
  // ---------------------------------------------------------------------------

  /// Runs after any successful authentication. Both `ApiClient.login` and
  /// `ApiClient.verifyMobileOtp` have already saved the token and fired
  /// `PushNotificationService.instance.registerToken()` before we get here, so
  /// a member who signs in with an OTP is as reachable by push as one who typed
  /// a password.
  Future<void> _afterAuthenticated({required String rememberIdentifier}) async {
    if (rememberIdentifier.isNotEmpty) {
      await AppStorage.instance.saveRememberedLoginIdentifier(
        rememberIdentifier,
      );
    }
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppStrings.loginSuccess),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      final outcome = await resolvePostAuthDestination();
      if (!mounted) return;

      if (outcome.destination == PostAuthDestination.onboarding) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.loginProfileMissing),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 2),
          ),
        );
        navigateAfterAuth(context, outcome.route!);
        return;
      }

      if (outcome.destination == PostAuthDestination.home) {
        setState(() => isLoading = false);
        navigateAfterAuth(context, outcome.route!);
        return;
      }

      setState(() {
        isLoading = false;
        errorMessage =
            outcome.failureMessage ?? AppStrings.loginProfileCheckFailed;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        errorMessage = _networkMessage(error);
      });
    }
  }

  /// The server words its own failures (wrong OTP, expired challenge, attempt
  /// limit, rate limit). Prefer that wording; fall back only when it sends none.
  /// Shared with the forgot-password flow, which reads the same envelopes.
  String _messageOf(Map<String, dynamic> data, String fallback) =>
      apiErrorText(data, fallback);

  String _networkMessage(Object error) =>
      networkErrorText(error, label: 'Login request');

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  void _switchMethod(_LoginMethod next) {
    if (_method == next) return;
    _resetOtpChallenge();
    setState(() {
      _method = next;
      errorMessage = '';
    });
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (_method == _LoginMethod.password) {
      unawaited(_handlePasswordLogin());
      return;
    }
    if (_otpSent) {
      unawaited(_verifyOtp());
      return;
    }
    unawaited(_sendOtp());
  }

  String get _primaryActionLabel {
    if (_method == _LoginMethod.password) return AppStrings.login;
    return _otpSent ? AppStrings.loginVerifyOtp : AppStrings.loginSendOtp;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text(AppStrings.login),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF1F2937),
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          color: const Color(0xFF1F2937),
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 34,
                ),
                child: Center(
                  child: AutofillGroup(
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxWidth: 440),
                      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.07),
                            blurRadius: 24,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Image.asset(
                              'assets/images/brand_logo.png',
                              height: 58,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.favorite_rounded,
                                  size: 54,
                                  color: Color(0xFFE65A43),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            AppStrings.loginWelcomeTitle,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: const Color(0xFF111827),
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _method == _LoginMethod.otp
                                ? (_otpSent
                                      ? AppStrings.loginOtpSentHint
                                      : AppStrings.loginMobileHint)
                                : AppStrings.loginWelcomeSubtitle,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF6B7280),
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (_method == _LoginMethod.otp)
                            ..._buildOtpFields(theme)
                          else
                            ..._buildPasswordFields(theme),
                          if (errorMessage.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Container(
                              key: const ValueKey('login-error'),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFEBEE),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFFFCDD2),
                                ),
                              ),
                              child: Text(
                                errorMessage,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFFB91C1C),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: isLoading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE65A43),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 0,
                              ),
                              child: isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      _primaryActionLabel,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // A member who signed up with Google has no password
                          // and may not remember which number they used, so the
                          // Google door has to exist on this screen too — not
                          // only on the sign-up screen where they first met it.
                          OutlinedButton.icon(
                            onPressed: isLoading ? null : _signInWithGoogle,
                            icon: const GoogleBrandMark(),
                            label: Text(appText.signInWithGoogle),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              side: const BorderSide(color: Color(0xFFDADCE0)),
                              foregroundColor: const Color(0xFF3C4043),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextButton(
                            onPressed: isLoading
                                ? null
                                : () => _switchMethod(
                                    _method == _LoginMethod.otp
                                        ? _LoginMethod.password
                                        : _LoginMethod.otp,
                                  ),
                            child: Text(
                              _method == _LoginMethod.otp
                                  ? AppStrings.loginUsePasswordInstead
                                  : AppStrings.loginUseOtpInstead,
                            ),
                          ),
                          // Only offered beside the password door, because an
                          // OTP member has no password to have forgotten —
                          // she is already standing at the door that screen
                          // would send her back to.
                          if (_method == _LoginMethod.password)
                            TextButton(
                              onPressed: isLoading
                                  ? null
                                  : () => Navigator.pushNamed(
                                      context,
                                      '/forgot-password',
                                    ),
                              child: Text(AppStrings.forgotPasswordLink),
                            ),
                          if (_method == _LoginMethod.otp)
                            _ConsentFooter(theme: theme),
                          TextButton(
                            onPressed: isLoading
                                ? null
                                : () {
                                    Navigator.pushNamed(context, '/register');
                                  },
                            child: Text(AppStrings.loginRegisterPrompt),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildOtpFields(ThemeData theme) {
    return <Widget>[
      TextField(
        controller: mobileController,
        focusNode: _mobileFocus,
        enabled: !_otpSent,
        keyboardType: TextInputType.phone,
        textInputAction: TextInputAction.done,
        autofillHints: const [AutofillHints.telephoneNumber],
        inputFormatters: [
          // Latin 0-9 only. A Devanagari numeral typed on a Marathi keyboard is
          // dropped here rather than rejected by the server.
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(10),
        ],
        decoration: InputDecoration(
          labelText: AppStrings.loginMobileLabel,
          prefixIcon: const Icon(Icons.phone_iphone_rounded),
          suffixIcon: _otpSent
              ? null
              : IconButton(
                  tooltip: AppStrings.loginPickFromSim,
                  onPressed: isLoading
                      ? null
                      : () => unawaited(_pickMobileFromSim()),
                  icon: const Icon(Icons.sim_card_outlined),
                ),
        ),
        onSubmitted: (_) {
          if (!isLoading && !_otpSent) unawaited(_sendOtp());
        },
      ),
      if (_otpSent) ...[
        const SizedBox(height: 14),
        if (_deliveryHint != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              _deliveryHint!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF6B7280),
              ),
            ),
          ),
        if (_testOtpCode != null)
          Container(
            key: const ValueKey('login-test-otp'),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFED7AA)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.science_outlined,
                  size: 18,
                  color: Color(0xFF9A3412),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppStrings.loginTestOtpLabel(_testOtpCode!),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF9A3412),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        TextField(
          controller: otpController,
          autofocus: true,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          decoration: InputDecoration(
            labelText: AppStrings.loginOtpLabel,
            prefixIcon: const Icon(Icons.pin_outlined),
            helperText: AppStrings.loginOtpAutoFillHint,
            helperMaxLines: 2,
          ),
          onSubmitted: (_) {
            if (!isLoading) unawaited(_verifyOtp());
          },
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: TextButton(
                onPressed: isLoading ? null : _resetOtpChallenge,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
                child: Text(
                  AppStrings.loginChangeMobile,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Flexible(
              child: TextButton(
                onPressed: (isLoading || _resendSecondsRemaining > 0)
                    ? null
                    : () => unawaited(_sendOtp()),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
                child: Text(
                  _resendSecondsRemaining > 0
                      ? AppStrings.loginResendInSeconds(_resendSecondsRemaining)
                      : AppStrings.loginSendOtp,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ],
    ];
  }

  List<Widget> _buildPasswordFields(ThemeData theme) {
    return <Widget>[
      TextField(
        controller: loginController,
        keyboardType: TextInputType.text,
        textInputAction: TextInputAction.next,
        autofillHints: const [
          AutofillHints.username,
          AutofillHints.email,
          AutofillHints.telephoneNumber,
        ],
        decoration: InputDecoration(
          labelText: AppStrings.loginIdentifierLabel,
          prefixIcon: const Icon(Icons.person_outline_rounded),
        ),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: passwordController,
        obscureText: _obscurePassword,
        textInputAction: TextInputAction.done,
        autofillHints: const [AutofillHints.password],
        onSubmitted: (_) {
          if (!isLoading) unawaited(_handlePasswordLogin());
        },
        decoration: InputDecoration(
          labelText: AppStrings.loginPasswordLabel,
          prefixIcon: const Icon(Icons.lock_outline_rounded),
          suffixIcon: IconButton(
            tooltip: _obscurePassword
                ? AppStrings.loginShowPassword
                : AppStrings.loginHidePassword,
            onPressed: () {
              setState(() => _obscurePassword = !_obscurePassword);
            },
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
          ),
        ),
      ),
    ];
  }
}

/// Same consent wording registration shows, because the same consent is being
/// recorded: `/auth/mobile-otp/send` requires a terms and privacy version, and
/// verifying the challenge writes both into `user_consents`.
class _ConsentFooter extends StatelessWidget {
  const _ConsentFooter({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final textStyle = theme.textTheme.bodySmall?.copyWith(
      color: const Color(0xFF6B7280),
      fontSize: 11,
      height: 1.2,
    );

    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 2),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(AppStrings.loginConsentPrefix, style: textStyle),
              Text(
                appText.termsAndConditionsShort,
                style: textStyle?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(AppStrings.loginConsentAnd, style: textStyle),
              Text(
                appText.privacyPolicy,
                style: textStyle?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(AppStrings.loginConsentSuffix, style: textStyle),
            ],
          ),
        ),
      ),
    );
  }
}
