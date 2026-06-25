import 'package:flutter/material.dart';

import '../../core/app_strings.dart';
import '../../core/email_hint_service.dart';
import '../../core/phone_number_hint_service.dart';
import '../onboarding/smart_onboarding_screen.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  static const Color _brandRed = Color(0xFFE01F26);
  static const Color _textColor = Color(0xFF4A3A3A);

  String _copy(String english, String marathi) {
    return AppStrings.isMarathi ? marathi : english;
  }

  Future<void> _captureEmailAndStartMobile(BuildContext context) async {
    var email = await EmailHintService.requestEmailHint();
    if (!context.mounted) return;
    email ??= await _showEmailCaptureSheet(context);
    if (email == null || !context.mounted) return;

    await _startMobileSignup(context, pendingEmail: email);
  }

  Future<void> _startMobileSignup(
    BuildContext context, {
    String? pendingEmail,
  }) async {
    final mobile = await PhoneNumberHintService.requestPhoneNumberHint();
    if (!context.mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SmartOnboardingScreen(
          initialMode: SmartOnboardingInitialMode.mobileOtp,
          pendingEmail: pendingEmail?.trim().isEmpty == true
              ? null
              : pendingEmail?.trim(),
          initialMobile: mobile,
        ),
      ),
    );
  }

  Future<String?> _showEmailCaptureSheet(BuildContext context) {
    final controller = TextEditingController();
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            22,
            24,
            MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: AutofillGroup(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _copy('Choose email', 'Email निवडा'),
                  style: Theme.of(sheetContext)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  _copy(
                    'This email will be used for your account. Mobile verification is required to continue.',
                    'हा email account साठी वापरला जाईल. पुढे जाण्यासाठी मोबाइल verification आवश्यक आहे.',
                  ),
                  style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade700,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: _copy('Email', 'Email'),
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                  onSubmitted: (_) {
                    Navigator.pop(sheetContext, controller.text.trim());
                  },
                ),
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(sheetContext, controller.text.trim());
                  },
                  child: Text(_copy('Continue', 'पुढे जा')),
                ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(controller.dispose);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/landing_hero.jpg',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(color: _brandRed);
            },
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x66A40E15),
                  Color(0x33A40E15),
                  Color(0xEEA40E15),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 34, 28, 28),
              child: Column(
                children: [
                  Image.asset(
                    'assets/images/brand_logo.png',
                    height: 112,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Text(
                        AppStrings.appName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      );
                    },
                  ),
                  const Spacer(),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _copy('New here?', 'नवीन आहात?'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _AuthChoiceButton(
                          icon: const _GoogleMark(),
                          label: _copy(
                            'Sign Up with Google',
                            'Google ने सुरू करा',
                          ),
                          onPressed: () => _captureEmailAndStartMobile(
                            context,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _AuthChoiceButton(
                          icon: const Icon(
                            Icons.phone_android_rounded,
                            color: Color(0xFF8A8A8A),
                          ),
                          label: _copy(
                            'Sign Up with Mobile',
                            'मोबाइल नंबरने सुरू करा',
                          ),
                          onPressed: () => _startMobileSignup(context),
                        ),
                        const SizedBox(height: 12),
                        _AuthChoiceButton(
                          icon: const Icon(
                            Icons.email_outlined,
                            color: Color(0xFF8A8A8A),
                          ),
                          label: _copy(
                            'Sign Up with Email',
                            'Email ने सुरू करा',
                          ),
                          onPressed: () => _captureEmailAndStartMobile(
                            context,
                          ),
                        ),
                        const SizedBox(height: 26),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                _copy(
                                  'Already have an account?',
                                  'आधीपासून account आहे?',
                                ),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            OutlinedButton(
                              onPressed: () {
                                Navigator.pushNamed(context, '/login');
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                                minimumSize: const Size(84, 42),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                shape: const StadiumBorder(),
                              ),
                              child: Text(
                                _copy('Login', 'Login'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthChoiceButton extends StatelessWidget {
  const _AuthChoiceButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final Widget icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: LandingScreen._textColor,
          elevation: 8,
          shadowColor: Colors.black.withValues(alpha: 0.20),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(width: 28, height: 28, child: Center(child: icon)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 42),
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'G',
      style: TextStyle(
        color: Color(0xFF4285F4),
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
    );
  }
}
