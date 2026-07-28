import 'package:flutter/material.dart';

import '../../../core/email_hint_service.dart';
import 'onboarding_step_helpers.dart';
import '../../../core/app_language.dart';

class RegistrationSuccessStep extends StatefulWidget {
  const RegistrationSuccessStep({
    super.key,
    required this.account,
    required this.locale,
    required this.loading,
    required this.onVerifyGoogleEmail,
    required this.onSendEmailOtp,
    required this.onVerifyEmailOtp,
    required this.onSkipEmail,
    required this.onVerifyMobile,
    required this.onContinue,
  });

  final Map<String, dynamic> account;
  final String locale;
  final bool loading;
  final Future<String?> Function(GoogleEmailCredential credential)
  onVerifyGoogleEmail;
  final Future<Map<String, dynamic>> Function(String email) onSendEmailOtp;
  final Future<String?> Function({
    required String challengeId,
    required String email,
    required String otp,
  })
  onVerifyEmailOtp;
  final VoidCallback onSkipEmail;
  final VoidCallback onVerifyMobile;
  final VoidCallback onContinue;

  @override
  State<RegistrationSuccessStep> createState() =>
      _RegistrationSuccessStepState();
}

class _RegistrationSuccessStepState extends State<RegistrationSuccessStep> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  bool _workingGoogle = false;
  bool _sendingOtp = false;
  bool _verifyingOtp = false;
  bool _showInitialSuccess = true;
  String? _localError;
  String? _localInfo;
  String? _verificationEmail;
  String? _challengeId;
  String? _debugOtp;
  bool _verifiedInThisStep = false;
  bool get _emailVerified =>
      _verifiedInThisStep ||
      onboardingBool(widget.account['email_verified']) == true ||
      onboardingText(widget.account['email_verified_at']) != null;
  bool get _hasMobile =>
      onboardingText(widget.account['mobile']) != null ||
      onboardingBool(widget.account['mobile_verified']) == true;
  bool get _needsEmail => !_emailVerified && _hasMobile;
  bool get _needsMobile => !_hasMobile;
  bool get _busy =>
      widget.loading || _workingGoogle || _sendingOtp || _verifyingOtp;


  @override
  void initState() {
    super.initState();
    _syncEmailFromAccount(force: true);
  }

  @override
  void didUpdateWidget(covariant RegistrationSuccessStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.account != widget.account) {
      _syncEmailFromAccount();
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _syncEmailFromAccount({bool force = false}) {
    final email = onboardingText(widget.account['email']) ?? _verificationEmail;
    if (email == null || email.isEmpty) return;
    if (!force && _emailController.text.trim().isNotEmpty) return;
    _emailController.text = email;
    _verificationEmail = email;
  }

  void _hideInitialSuccess() {
    if (!_showInitialSuccess) return;
    setState(() {
      _showInitialSuccess = false;
    });
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  Future<void> _continueWithGoogle() async {
    if (_busy) return;
    setState(() {
      _showInitialSuccess = false;
      _workingGoogle = true;
      _localError = null;
      _localInfo = null;
      _challengeId = null;
      _debugOtp = null;
      _otpController.clear();
    });

    final credential = await EmailHintService.requestGoogleEmailVerification();
    if (!mounted) return;

    final email = credential?.email.trim() ?? '';
    if (credential == null || email.isEmpty) {
      setState(() {
        _workingGoogle = false;
        _localError = appText.couldNotReadAGoogleEmail;
      });
      return;
    }

    _verificationEmail = email;
    _emailController.text = email;
    final googleError = await widget.onVerifyGoogleEmail(credential);
    if (!mounted) return;

    if (googleError == null) {
      setState(() {
        _workingGoogle = false;
        _verifiedInThisStep = true;
        _localInfo = appText.googleVerifiedYourEmail;
      });
      return;
    }

    setState(() {
      _workingGoogle = false;
      _localInfo = googleError;
    });
    await _sendOtp(email);
  }

  Future<void> _sendOtpToTypedEmail() async {
    if (_busy) return;
    final email = _emailController.text.trim();
    setState(() {
      _showInitialSuccess = false;
      _localInfo = null;
    });

    if (!_isValidEmail(email)) {
      setState(() {
        _localError = appText.enterAValidEmailAddress;
      });
      return;
    }

    await _sendOtp(email);
  }

  Future<void> _sendOtp(String email) async {
    if (_busy && !_workingGoogle) return;
    setState(() {
      _showInitialSuccess = false;
      _sendingOtp = true;
      _localError = null;
      _challengeId = null;
      _debugOtp = null;
      _otpController.clear();
    });

    final response = await widget.onSendEmailOtp(email);
    if (!mounted) return;

    if (response['success'] == true) {
      setState(() {
        _sendingOtp = false;
        _verificationEmail = email;
        _challengeId = onboardingText(response['challenge_id']);
        _debugOtp = onboardingText(response['debug_otp']);
        _localInfo = appText.enterTheOtpSentToYour;
      });
      return;
    }

    setState(() {
      _sendingOtp = false;
      _localError = readableApiError(
        response,
        appText.couldNotSendEmailOtp,
      );
    });
  }

  Future<void> _verifyOtp() async {
    if (_busy) return;
    _hideInitialSuccess();
    final challengeId = _challengeId;
    final email = _verificationEmail;
    final otp = _otpController.text.trim();
    if (challengeId == null || email == null) return;
    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      setState(() {
        _localError = appText.enterThe6DigitOtp2;
      });
      return;
    }

    setState(() {
      _verifyingOtp = true;
      _localError = null;
    });

    final error = await widget.onVerifyEmailOtp(
      challengeId: challengeId,
      email: email,
      otp: otp,
    );
    if (!mounted) return;

    setState(() {
      _verifyingOtp = false;
      _localError = error;
      if (error == null) {
        _verifiedInThisStep = true;
        _challengeId = null;
        _debugOtp = null;
        _localInfo = appText.emailVerifiedSuccessfully;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final availableHeight =
        MediaQuery.sizeOf(context).height -
        MediaQuery.paddingOf(context).vertical -
        32;

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 4),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: availableHeight),
        child: Column(
          mainAxisAlignment: _showInitialSuccess
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_showInitialSuccess) ...[
              Center(
                child: Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green.shade50,
                    border: Border.all(color: Colors.green.shade100, width: 8),
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    size: 58,
                    color: Colors.green.shade700,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                appText.yourProfileHasBeenCreatedSuccessfully,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: Colors.grey.shade900,
                  height: 1.12,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                appText.nowSetAFewImportantThings,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 24),
            ],
            if (_needsEmail)
              _emailRequestCard(context)
            else if (_needsMobile)
              _mobileRequestCard(context)
            else
              _settingsReadyCard(context),
          ],
        ),
      ),
    );
  }

  Widget _emailRequestCard(BuildContext context) {
    final email = _verificationEmail;
    final challengeId = _challengeId;
    return _ActionPanel(
      icon: Icons.verified_user_outlined,
      title: appText.verifyEmail,
      body: appText.editTheEmailIfNeededThen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_verifiedInThisStep && email != null)
            _EmailSummary(email: email, verified: true, locale: widget.locale)
          else ...[
            TextField(
              controller: _emailController,
              enabled: !_busy,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: appText.emailAddress,
                prefixIcon: const Icon(Icons.email_outlined),
              ),
              onChanged: (_) {
                if (_localError == null && _localInfo == null) return;
                setState(() {
                  _localError = null;
                  _localInfo = null;
                });
              },
              onSubmitted: (_) => _sendOtpToTypedEmail(),
            ),
            if (challengeId != null && email != null) ...[
              const SizedBox(height: 12),
              _OtpBox(
                email: email,
                controller: _otpController,
                locale: widget.locale,
                debugOtp: _debugOtp,
                verifying: _verifyingOtp,
                onVerify: _verifyOtp,
                onResend: _busy ? null : _sendOtpToTypedEmail,
              ),
            ],
          ],
          if (_localInfo != null) ...[
            const SizedBox(height: 10),
            Text(
              _localInfo!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ],
          if (_localError != null) ...[
            const SizedBox(height: 10),
            Text(
              _localError!,
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (_verifiedInThisStep)
            ElevatedButton.icon(
              onPressed: _busy ? null : widget.onContinue,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(appText.continueLabel),
            )
          else ...[
            ElevatedButton.icon(
              onPressed: _busy ? null : _sendOtpToTypedEmail,
              icon: _sendingOtp
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.mark_email_read_outlined),
              label: Text(
                _sendingOtp
                    ? appText.sendingOtp
                    : challengeId == null
                    ? appText.sendEmailOtp
                    : appText.sendOtpAgain,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _continueWithGoogle,
              icon: _workingGoogle
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const _GoogleMarkIcon(),
              label: Text(
                _workingGoogle
                    ? appText.checkingGoogleEmail
                    : appText.tryGoogleVerification,
              ),
            ),
          ],
          TextButton.icon(
            onPressed: _busy ? null : widget.onSkipEmail,
            icon: const Icon(Icons.chevron_right_rounded),
            label: Text(
              appText.skipEmailVerification,
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileRequestCard(BuildContext context) {
    return _ActionPanel(
      icon: Icons.phone_android_rounded,
      title: appText.verifyMobileNumber,
      body: appText.mobileVerificationKeepsTheAccountSecure,
      child: ElevatedButton.icon(
        onPressed: _busy ? null : widget.onVerifyMobile,
        icon: const Icon(Icons.sms_outlined),
        label: Text(appText.verifyMobile),
      ),
    );
  }

  Widget _settingsReadyCard(BuildContext context) {
    final email = onboardingText(widget.account['email']) ?? _verificationEmail;
    return _ActionPanel(
      icon: Icons.tune_rounded,
      title: appText.importantSettingsAreNext,
      body: appText.addPhotosAndReviewPartnerPreference,
      footer: email == null
          ? null
          : _EmailSummary(
              email: email,
              verified: _emailVerified,
              locale: widget.locale,
            ),
      child: ElevatedButton.icon(
        onPressed: _busy ? null : widget.onContinue,
        icon: const Icon(Icons.arrow_forward_rounded),
        label: Text(appText.continueLabel),
      ),
    );
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({
    required this.icon,
    required this.title,
    required this.body,
    required this.child,
    this.footer,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: onboardingSelectedGreen.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: onboardingSelectedGreen),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: Colors.grey.shade900,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        body,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade700,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
            if (footer != null) ...[const SizedBox(height: 12), footer!],
          ],
        ),
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  const _OtpBox({
    required this.email,
    required this.controller,
    required this.locale,
    required this.verifying,
    required this.onVerify,
    required this.onResend,
    this.debugOtp,
  });

  final String email;
  final TextEditingController controller;
  final String locale;
  final bool verifying;
  final VoidCallback onVerify;
  final VoidCallback? onResend;
  final String? debugOtp;


  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.primary.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              email,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(
                counterText: '',
                labelText: appText.emailOtp,
                prefixIcon: const Icon(Icons.password_rounded),
              ),
            ),
            if (debugOtp != null) ...[
              const SizedBox(height: 6),
              Text(
                appText.testOtpLabel(debugOtp!),
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: verifying ? null : onVerify,
                    icon: verifying
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.verified_rounded),
                    label: Text(
                      verifying
                          ? appText.verifying2
                          : appText.verifyOtp,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: onResend,
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: appText.resendOtp,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmailSummary extends StatelessWidget {
  const _EmailSummary({
    required this.email,
    required this.verified,
    required this.locale,
  });

  final String email;
  final bool verified;
  final String locale;


  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final statusColor = verified ? const Color(0xFF15803D) : colors.primary;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              verified ? Icons.verified_rounded : Icons.mail_outline_rounded,
              color: statusColor,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    verified
                        ? appText.verifiedEmail
                        : appText.emailAdded,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleMarkIcon extends StatelessWidget {
  const _GoogleMarkIcon();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'G',
      style: TextStyle(
        color: Color(0xFF4285F4),
        fontSize: 20,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
    );
  }
}
