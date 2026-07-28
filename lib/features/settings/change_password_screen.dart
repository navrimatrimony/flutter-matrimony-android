import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/api_error_text.dart';
import '../../core/app_strings.dart';
import '../../main.dart';

/// Sets a new password for a member who is already signed in.
///
/// This is the other half of the mobile-OTP recovery path. A member with no
/// email can never receive the emailed reset link, so she signs in with a
/// one-time code and lands here — which is why **the current password is not
/// asked for**. Demanding it would rebuild the lockout this screen exists to
/// remove. The server takes the same position: `MemberPasswordApiController`
/// validates `password` + `password_confirmation` and nothing else, and
/// `App\Services\Account\MemberPasswordService` records why.
///
/// `POST /api/v1/account/password` revokes every OTHER Sanctum token but keeps
/// the caller's own, so the member stays signed in on this phone. Nothing here
/// clears [ApiClient.authToken] — that token is still valid, and throwing it
/// away would sign her out of the one session the server deliberately spared.
///
/// No password rules are enforced here. `Rules\Password::defaults()` is the
/// only policy, it lives on the server, and a client-side copy of it would
/// start disagreeing the day someone tightens it. A rejected password is shown
/// in the server's own words, already localised by the `Accept-Language` header
/// `ApiClient` sends.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _isSaving = false;
  bool _obscurePassword = true;
  String _errorMessage = '';

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSaving) return;

    final password = _passwordController.text;
    final confirm = _confirmController.text;

    // The only two local checks, and neither can ever disagree with the
    // server: an empty box is nothing to send, and a confirmation that does
    // not match is what the `confirmed` rule rejects anyway. Length and
    // strength are the server's to judge.
    final String? localError;
    if (password.trim().isEmpty) {
      localError = AppStrings.changePasswordMissing;
    } else if (password != confirm) {
      localError = AppStrings.forgotPasswordMismatch;
    } else {
      localError = null;
    }

    if (localError != null) {
      setState(() => _errorMessage = localError!);
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = '';
    });

    try {
      final data = await ApiClient.changeAccountPassword(
        password: password,
        passwordConfirmation: confirm,
      );
      if (!mounted) return;

      if (data['success'] == true) {
        await _finish(data);
        return;
      }

      setState(() {
        _isSaving = false;
        _errorMessage = _failureText(data);
      });

      // Another device changed the password first, so the token this screen
      // was using is among the ones the server revoked. The message is already
      // on screen; now leave, rather than let her press a button that can no
      // longer work. Navigation stays outside setState.
      if (_isRevokedSession(data)) {
        await signOutAndReturnToLogin(Navigator.of(context));
      }
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _errorMessage = networkErrorText(error, label: 'Change password'),
      );
    } finally {
      // Every route out of this method stops the spinner. The app has already
      // shipped one that never resolved, on the OTP screen; it does not come
      // back here.
      if (mounted && _isSaving) {
        setState(() => _isSaving = false);
      }
    }
  }

  /// Names the failure instead of showing one blank sentence for all of them.
  String _failureText(Map<String, dynamic> data) {
    // The route carries no throttle middleware today, so this is defensive:
    // putting one on it later degrades into a clear sentence rather than the
    // generic failure.
    if (data['statusCode'] == 429) {
      return apiErrorText(data, AppStrings.forgotPasswordRateLimited);
    }

    if (_isRevokedSession(data)) {
      return AppStrings.changePasswordSessionExpired;
    }

    // 422 with `errors.password` is the common case: the server's own
    // Rules\Password::defaults() message, in the member's language.
    return apiErrorText(data, AppStrings.changePasswordFailed);
  }

  /// Sanctum answers a dead token with 401 "Unauthenticated."; the raw sentence
  /// is not something a member can act on, so it is replaced rather than shown.
  bool _isRevokedSession(Map<String, dynamic> data) {
    final status = data['statusCode'];
    return status == 401 || status == 403;
  }

  /// The server keeps this device's token alive on purpose, so there is nothing
  /// to re-authenticate — the member simply goes back to Settings with the
  /// server's own confirmation ("… Other devices have been signed out.").
  Future<void> _finish(Map<String, dynamic> data) async {
    setState(() => _isSaving = false);
    _passwordController.clear();
    _confirmController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(apiErrorText(data, AppStrings.changePasswordTitle)),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
      ),
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(title: Text(AppStrings.changePasswordTitle)),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Center(
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 440),
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
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
                    AppStrings.changePasswordIntro,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF6B7280),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _passwordController,
                    enabled: !_isSaving,
                    obscureText: _obscurePassword,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      labelText: AppStrings.forgotPasswordNewPasswordLabel,
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        tooltip: _obscurePassword
                            ? AppStrings.loginShowPassword
                            : AppStrings.loginHidePassword,
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
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
                    enabled: !_isSaving,
                    obscureText: _obscurePassword,
                    autofillHints: const [AutofillHints.newPassword],
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) {
                      if (!_isSaving) unawaited(_submit());
                    },
                    decoration: InputDecoration(
                      labelText: AppStrings.forgotPasswordConfirmPasswordLabel,
                      prefixIcon: const Icon(Icons.lock_reset_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.devices_other_rounded,
                          size: 20,
                          color: Color(0xFF1E3A8A),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            AppStrings.changePasswordOtherDevicesNotice,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF1E3A8A),
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_errorMessage.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      key: const ValueKey('change-password-error'),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFFCDD2)),
                      ),
                      child: Text(
                        _errorMessage,
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
                      onPressed: _isSaving
                          ? null
                          : () {
                              FocusScope.of(context).unfocus();
                              unawaited(_submit());
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE65A43),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              AppStrings.changePasswordSubmit,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
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
