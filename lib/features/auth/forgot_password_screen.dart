import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/api_error_text.dart';
import '../../core/app_storage.dart';
import '../../core/app_strings.dart';
import '../../core/mobile_number.dart';
import 'login_screen.dart';

/// Password recovery, built against what the backend actually does — and around
/// the members it could not serve.
///
/// `POST /api/v1/auth/password/forgot` accepts a mobile number, an email or a
/// username under one `login` key, resolves it to the account's **email**, and
/// emails a web link — `…/reset-password/{token}?email=…`, valid 60 minutes.
/// It is not an OTP flow: the reply carries no challenge id, no correlation
/// key, nothing to carry forward. That is why this screen does not reuse the
/// OTP widgets or `MobileOtpSendResponse` — there is no challenge to model, and
/// pretending otherwise would invent a contract the server does not have.
///
/// The dead end that produced this screen's current shape: a member who
/// registered with a mobile number and no email typed that number here, and the
/// server dutifully emailed a link to an address she does not have. She was
/// locked out for good. So the mobile branch no longer calls `forgot` at all —
/// it hands the number to the mobile-OTP door on the login screen, which signs
/// her in with a one-time code and no password. A password, if she wants one,
/// is set afterwards from Settings.
///
/// The email / username branch is untouched: `forgot` is still called, and
/// stage two still asks the member to paste the link back in. That is the only
/// in-app route to the token without registering an Android deep link.
/// `POST /auth/password/reset` needs `token` + `email` + `password` +
/// `password_confirmation`; the email is read out of the pasted link, because
/// that endpoint — unlike `forgot` — does not accept a mobile number.
enum _Stage { request, reset }

/// What the member typed, and therefore which door this screen opens.
///
/// Nothing here re-implements identifier detection: [MobileNumberInput] is the
/// one place in the app that knows what counts as a mobile number (the login
/// screen decides the same way before it seeds its OTP field), and
/// `_looksLikeEmail` below is the email test this screen already carried for
/// the reset step.
enum _IdentifierKind {
  /// Nothing usable typed yet.
  empty,

  /// A complete 10-digit mobile number — the OTP door.
  mobile,

  /// Digits, but not ten of them. Heading for the OTP door once complete;
  /// saying so beats letting the server answer "no such account".
  partialMobile,

  /// An email address — the emailed-link door.
  email,

  /// Anything else, i.e. a username. `forgot` resolves it to the account's
  /// email, so it takes the emailed-link door too.
  username,
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  _Stage _stage = _Stage.request;
  _IdentifierKind _kind = _IdentifierKind.empty;
  bool _isLoading = false;
  String _errorMessage = '';
  String _noticeMessage = '';
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    unawaited(_prefillIdentifier());
    _identifierController.addListener(_onIdentifierChanged);
    _linkController.addListener(_onLinkChanged);
  }

  @override
  void dispose() {
    _identifierController.removeListener(_onIdentifierChanged);
    _linkController.removeListener(_onLinkChanged);
    _identifierController.dispose();
    _linkController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  /// Same stored identifier the login screen prefills from — a member who got
  /// here by failing to sign in should not retype what they just typed.
  Future<void> _prefillIdentifier() async {
    final remembered = (await AppStorage.instance
                .readRememberedLoginIdentifier())
            ?.trim() ??
        '';
    if (!mounted || remembered.isEmpty) return;
    if (_identifierController.text.trim().isNotEmpty) return;
    // Assigning the text fires _onIdentifierChanged, which sets the branch and
    // repaints — so the member sees which door is open before touching anything.
    _identifierController.text = remembered;
  }

  // ---------------------------------------------------------------------------
  // Stage 1 — pick a door, then walk through it
  // ---------------------------------------------------------------------------

  void _onIdentifierChanged() {
    final kind = _kindOf(_identifierController.text);
    if (kind == _kind) return;
    setState(() {
      _kind = kind;
      // The old branch's complaint does not belong to the new one.
      _errorMessage = '';
    });
  }

  _IdentifierKind _kindOf(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return _IdentifierKind.empty;
    if (_looksLikeEmail(text)) return _IdentifierKind.email;
    if (MobileNumberInput.isComplete(text)) return _IdentifierKind.mobile;
    // Digits and the punctuation people put between them (+91, spaces, dashes,
    // brackets) — someone typing a phone number, just not finished.
    if (RegExp(r'^[0-9+\-\s()]+$').hasMatch(text)) {
      return _IdentifierKind.partialMobile;
    }
    return _IdentifierKind.username;
  }

  /// The one action behind the primary button on the request stage.
  void _startRequest() {
    switch (_kind) {
      case _IdentifierKind.empty:
        setState(() {
          _errorMessage = AppStrings.forgotPasswordIdentifierMissing;
          _noticeMessage = '';
        });
        return;
      case _IdentifierKind.partialMobile:
        setState(() {
          _errorMessage = AppStrings.loginMobileInvalid;
          _noticeMessage = '';
        });
        return;
      case _IdentifierKind.mobile:
        _continueWithOtpLogin();
        return;
      case _IdentifierKind.email:
      case _IdentifierKind.username:
        unawaited(_sendResetLink());
        return;
    }
  }

  /// A mobile number never touches `/auth/password/forgot`.
  ///
  /// That endpoint can only ever deliver by email, and the members who type a
  /// mobile number here are precisely the ones with no email on the account.
  /// Instead the number is handed to the login screen's mobile-OTP door — the
  /// same door registration and login already use — with the code requested on
  /// arrival, so the member's next action is typing it. Nothing is reset and
  /// nothing has to be remembered.
  void _continueWithOtpLogin() {
    final mobile = MobileNumberInput.normalize(_identifierController.text);
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/login',
      (route) => false,
      arguments: MobileOtpLoginRequest(mobile),
    );
  }

  Future<void> _sendResetLink() async {
    final identifier = _identifierController.text.trim();
    if (identifier.isEmpty) {
      setState(
        () => _errorMessage = AppStrings.forgotPasswordIdentifierMissing,
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _noticeMessage = '';
    });

    try {
      final data = await ApiClient.sendPasswordResetLink(login: identifier);
      if (!mounted) return;

      if (data['success'] != true) {
        setState(() => _errorMessage = _failureText(
              data,
              AppStrings.forgotPasswordSendFailed,
            ));
        return;
      }

      setState(() {
        _stage = _Stage.reset;
        // The server's own sentence ("We have emailed your password reset
        // link!"), already localised by the Accept-Language header ApiClient
        // sends.
        _noticeMessage = apiErrorText(
          data,
          AppStrings.forgotPasswordLinkSentSubtitle,
        );
        // If the member identified themselves by email, that is the address the
        // link went to and the one /reset needs. A mobile or username tells us
        // nothing, so the field stays empty and the pasted link fills it.
        if (_looksLikeEmail(identifier)) {
          _emailController.text = identifier;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _errorMessage = networkErrorText(
          error,
          label: 'Password reset request',
        ),
      );
    } finally {
      // Every route out stops the spinner. This app has already shipped a
      // spinner that never resolved once, on the OTP screen; it does not come
      // back here.
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Stage 2 — consume the link
  // ---------------------------------------------------------------------------

  /// Pulls `token` and `email` out of whatever the member pasted.
  ///
  /// The emailed URL is `…/reset-password/{token}?email=…`, so the token is the
  /// last path segment and the email is a query parameter. A member who pasted
  /// only the bare token is handled too — that is the `Uri` parse falling
  /// through to the raw string.
  void _onLinkChanged() {
    final email = _emailFromLink(_linkController.text);
    if (email == null || email == _emailController.text.trim()) return;
    setState(() => _emailController.text = email);
  }

  String? _emailFromLink(String raw) {
    final text = raw.trim();
    if (!text.contains('?')) return null;
    final uri = Uri.tryParse(text);
    final email = uri?.queryParameters['email']?.trim();
    return (email == null || email.isEmpty) ? null : email;
  }

  String _tokenFromLink(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return '';
    if (!text.contains('/')) return text;

    final uri = Uri.tryParse(text);
    if (uri == null) return text;
    final segments = uri.pathSegments.where((s) => s.trim().isNotEmpty);
    return segments.isEmpty ? text : segments.last.trim();
  }

  Future<void> _submitReset() async {
    final token = _tokenFromLink(_linkController.text);
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    // Mirrors the server's own rules so a member is not round-tripped for a
    // mistake we can already see: `token` and `email` are required, `email`
    // must be an email, and Rules\Password::defaults() is an uncustomised
    // min:8 in this project.
    final String? localError;
    if (token.isEmpty) {
      localError = AppStrings.forgotPasswordTokenMissing;
    } else if (email.isEmpty) {
      localError = AppStrings.forgotPasswordEmailMissing;
    } else if (!_looksLikeEmail(email)) {
      localError = AppStrings.forgotPasswordEmailInvalid;
    } else if (password.length < 8) {
      localError = AppStrings.forgotPasswordTooShort;
    } else if (password != confirm) {
      localError = AppStrings.forgotPasswordMismatch;
    } else {
      localError = null;
    }

    if (localError != null) {
      setState(() {
        _errorMessage = localError!;
        _noticeMessage = '';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _noticeMessage = '';
    });

    try {
      final data = await ApiClient.resetPassword(
        token: token,
        email: email,
        password: password,
        passwordConfirmation: confirm,
      );
      if (!mounted) return;

      if (data['success'] != true) {
        // Invalid token and expired token are one message on the server; the
        // member reads that wording rather than a guess made here.
        setState(() => _errorMessage = _failureText(
              data,
              AppStrings.forgotPasswordResetFailed,
            ));
        return;
      }

      await _finishReset();
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _errorMessage = networkErrorText(error, label: 'Password reset'),
      );
    } finally {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// The server issues no session on reset and does not revoke existing Sanctum
  /// tokens, so whatever token this device still holds is now stale — it
  /// belongs to the password that was just replaced. Clear it locally and send
  /// the member to a clean login rather than leave them half signed in.
  Future<void> _finishReset() async {
    await ApiClient.logout();
    if (!mounted) return;

    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppStrings.forgotPasswordResetDone),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  // ---------------------------------------------------------------------------
  // Shared
  // ---------------------------------------------------------------------------

  bool _looksLikeEmail(String value) {
    final text = value.trim();
    if (text.isEmpty || text.contains(' ')) return false;
    final at = text.indexOf('@');
    if (at <= 0 || at != text.lastIndexOf('@')) return false;
    final domain = text.substring(at + 1);
    return domain.contains('.') &&
        !domain.startsWith('.') &&
        !domain.endsWith('.');
  }

  /// `PasswordResetApiController` never returns 429 — it has no throttle
  /// middleware, and the broker's 60-second window surfaces as a 422 carrying
  /// "Please wait before retrying." The 429 branch is kept anyway so that
  /// putting a throttle on the route later degrades into a clear sentence
  /// instead of a blank failure.
  String _failureText(Map<String, dynamic> data, String fallback) {
    if (data['statusCode'] == 429) {
      return apiErrorText(data, AppStrings.forgotPasswordRateLimited);
    }
    return apiErrorText(data, fallback);
  }

  void _backToRequest() {
    setState(() {
      _stage = _Stage.request;
      _errorMessage = '';
      _noticeMessage = '';
    });
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isReset = _stage == _Stage.reset;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text(AppStrings.forgotPasswordTitle),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: Center(
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 440),
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    isReset
                        ? AppStrings.forgotPasswordLinkSentTitle
                        : AppStrings.forgotPasswordTitle,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: const Color(0xFF111827),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isReset
                        ? AppStrings.forgotPasswordResetStepSubtitle
                        : AppStrings.forgotPasswordRequestSubtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF6B7280),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (isReset)
                    ..._buildResetFields()
                  else
                    ..._buildRequestFields(theme),
                  if (_noticeMessage.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _Banner(
                      key: const ValueKey('forgot-password-notice'),
                      text: _noticeMessage,
                      background: const Color(0xFFECFDF5),
                      border: const Color(0xFFA7F3D0),
                      foreground: const Color(0xFF065F46),
                      theme: theme,
                    ),
                  ],
                  if (_errorMessage.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _Banner(
                      key: const ValueKey('forgot-password-error'),
                      text: _errorMessage,
                      background: const Color(0xFFFFEBEE),
                      border: const Color(0xFFFFCDD2),
                      foreground: const Color(0xFFB91C1C),
                      theme: theme,
                    ),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              FocusScope.of(context).unfocus();
                              if (isReset) {
                                unawaited(_submitReset());
                                return;
                              }
                              _startRequest();
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE65A43),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              isReset
                                  ? AppStrings.forgotPasswordSubmit
                                  : _requestActionLabel,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // A member on the mobile branch has no emailed link to
                  // already have, so the shortcut into stage two is not offered
                  // there.
                  if (isReset || !_isMobileBranch)
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : (isReset
                                ? _backToRequest
                                : () => setState(() => _stage = _Stage.reset)),
                      child: Text(
                        isReset
                            ? AppStrings.forgotPasswordBackToRequest
                            : AppStrings.forgotPasswordHaveLink,
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

  bool get _isMobileBranch =>
      _kind == _IdentifierKind.mobile || _kind == _IdentifierKind.partialMobile;

  /// The button says what is about to happen, so the branch is never a surprise.
  String get _requestActionLabel => _isMobileBranch
      ? AppStrings.forgotPasswordUseOtp
      : AppStrings.forgotPasswordSendLink;

  List<Widget> _buildRequestFields(ThemeData theme) {
    return <Widget>[
      TextField(
        controller: _identifierController,
        enabled: !_isLoading,
        keyboardType: TextInputType.text,
        textInputAction: TextInputAction.done,
        autofillHints: const [
          AutofillHints.username,
          AutofillHints.email,
          AutofillHints.telephoneNumber,
        ],
        onSubmitted: (_) {
          if (!_isLoading) _startRequest();
        },
        decoration: InputDecoration(
          labelText: AppStrings.forgotPasswordIdentifierLabel,
          prefixIcon: const Icon(Icons.person_outline_rounded),
        ),
      ),
      ..._buildBranchNotice(theme),
    ];
  }

  /// Names the branch the member has landed on, in her own words, before she
  /// presses anything. Detection is automatic; the consequence is not hidden.
  List<Widget> _buildBranchNotice(ThemeData theme) {
    final String title;
    final String body;
    final IconData icon;

    switch (_kind) {
      case _IdentifierKind.empty:
        return const <Widget>[];
      case _IdentifierKind.mobile:
      case _IdentifierKind.partialMobile:
        title = AppStrings.forgotPasswordMobileNoticeTitle;
        body = AppStrings.forgotPasswordMobileNoticeBody;
        icon = Icons.phone_iphone_rounded;
      case _IdentifierKind.email:
        title = AppStrings.forgotPasswordEmailNoticeTitle;
        body = AppStrings.forgotPasswordEmailNoticeBody;
        icon = Icons.mail_outline_rounded;
      case _IdentifierKind.username:
        title = AppStrings.forgotPasswordUsernameNoticeTitle;
        body = AppStrings.forgotPasswordUsernameNoticeBody;
        icon = Icons.person_outline_rounded;
    }

    return <Widget>[
      const SizedBox(height: 14),
      _Banner(
        key: const ValueKey('forgot-password-branch'),
        title: title,
        icon: icon,
        text: body,
        background: const Color(0xFFEFF6FF),
        border: const Color(0xFFBFDBFE),
        foreground: const Color(0xFF1E3A8A),
        theme: theme,
      ),
    ];
  }

  List<Widget> _buildResetFields() {
    return <Widget>[
      TextField(
        controller: _linkController,
        enabled: !_isLoading,
        minLines: 1,
        maxLines: 3,
        keyboardType: TextInputType.url,
        decoration: InputDecoration(
          labelText: AppStrings.forgotPasswordLinkLabel,
          helperText: AppStrings.forgotPasswordLinkHint,
          helperMaxLines: 2,
          prefixIcon: const Icon(Icons.link_rounded),
        ),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _emailController,
        enabled: !_isLoading,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        decoration: InputDecoration(
          labelText: AppStrings.forgotPasswordEmailLabel,
          prefixIcon: const Icon(Icons.mail_outline_rounded),
        ),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _passwordController,
        enabled: !_isLoading,
        obscureText: _obscurePassword,
        autofillHints: const [AutofillHints.newPassword],
        decoration: InputDecoration(
          labelText: AppStrings.forgotPasswordNewPasswordLabel,
          prefixIcon: const Icon(Icons.lock_outline_rounded),
          suffixIcon: IconButton(
            tooltip: _obscurePassword
                ? AppStrings.loginShowPassword
                : AppStrings.loginHidePassword,
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
          ),
        ),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _confirmController,
        enabled: !_isLoading,
        obscureText: _obscurePassword,
        autofillHints: const [AutofillHints.newPassword],
        textInputAction: TextInputAction.done,
        onSubmitted: (_) {
          if (!_isLoading) unawaited(_submitReset());
        },
        decoration: InputDecoration(
          labelText: AppStrings.forgotPasswordConfirmPasswordLabel,
          prefixIcon: const Icon(Icons.lock_reset_rounded),
        ),
      ),
    ];
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    super.key,
    required this.text,
    required this.background,
    required this.border,
    required this.foreground,
    required this.theme,
    this.title,
    this.icon,
  });

  final String text;
  final Color background;
  final Color border;
  final Color foreground;
  final ThemeData theme;

  /// Optional headline above [text]. Used by the branch notice, which has to
  /// name what the member typed before it explains what happens next.
  final String? title;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final body = Text(
      text,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: foreground,
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
    );

    final headline = title;
    final content = headline == null
        ? body
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                headline,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              body,
            ],
          );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: icon == null
          ? content
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 20, color: foreground),
                const SizedBox(width: 10),
                Expanded(child: content),
              ],
            ),
    );
  }
}
