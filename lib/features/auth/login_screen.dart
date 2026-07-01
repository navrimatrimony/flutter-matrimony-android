import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/app_storage.dart';
import '../../core/app_strings.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController loginController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;
  String errorMessage = '';
  bool _obscurePassword = true;
  bool _keepSignedIn = true;

  @override
  void initState() {
    super.initState();
    _loadSavedLoginPreference();
  }

  Future<void> _loadSavedLoginPreference() async {
    final keepSignedIn = await AppStorage.instance.readKeepSignedIn();
    final rememberedLogin = await AppStorage.instance
        .readRememberedLoginIdentifier();
    if (!mounted) return;
    setState(() {
      _keepSignedIn = keepSignedIn ?? true;
      if (loginController.text.trim().isEmpty &&
          rememberedLogin != null &&
          rememberedLogin.trim().isNotEmpty) {
        loginController.text = rememberedLogin.trim();
      }
    });
  }

  void handleLogin() async {
    final loginValue = loginController.text.trim();
    final passwordValue = passwordController.text;
    if (loginValue.isEmpty || passwordValue.isEmpty) {
      setState(() {
        errorMessage = AppStrings.loginMissingFields;
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    final result = await ApiClient.login(
      login: loginValue,
      password: passwordValue,
      persistSession: _keepSignedIn,
    );

    // Check if login was successful (token present)
    if (result.containsKey('token') && result['token'] != null) {
      await AppStorage.instance.saveKeepSignedIn(_keepSignedIn);
      if (_keepSignedIn) {
        await AppStorage.instance.saveRememberedLoginIdentifier(loginValue);
      } else {
        await AppStorage.instance.clearRememberedLoginIdentifier();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.loginSuccess),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      // Check if user has created matrimony profile
      try {
        final profileResult = await ApiClient.getMyProfile();
        if (!mounted) return;
        final statusCode = profileResult['statusCode'];

        if (statusCode == 404) {
          setState(() {
            isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppStrings.loginProfileMissing),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 2),
            ),
          );
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/smart-onboarding',
            (route) => false,
          );
          return;
        }

        if (statusCode == 200 && profileResult['success'] == true) {
          setState(() {
            isLoading = false;
          });
          final route = await _completedProfileRoute();
          if (!mounted) return;
          Navigator.pushNamedAndRemoveUntil(context, route, (route) => false);
          return;
        }

        setState(() {
          isLoading = false;
          errorMessage =
              profileResult['message'] ?? AppStrings.loginProfileCheckFailed;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          isLoading = false;
          errorMessage = 'Profile check error: ${e.toString()}';
        });
      }
      return;
    }
    // Login failed
    if (!mounted) return;
    setState(() {
      isLoading = false;
      errorMessage = result['message'] ?? AppStrings.loginFailed;
    });
  }

  @override
  void dispose() {
    loginController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<String> _completedProfileRoute() async {
    final shownDate = await AppStorage.instance
        .readDailyRecommendationShownDate();
    return shownDate == _todayKey() ? '/home' : '/matches';
  }

  String _todayKey() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
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
                            AppStrings.loginWelcomeSubtitle,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF6B7280),
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 24),
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
                              prefixIcon: const Icon(
                                Icons.person_outline_rounded,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            onSubmitted: (_) {
                              if (!isLoading) handleLogin();
                            },
                            decoration: InputDecoration(
                              labelText: AppStrings.loginPasswordLabel,
                              prefixIcon: const Icon(
                                Icons.lock_outline_rounded,
                              ),
                              suffixIcon: IconButton(
                                tooltip: _obscurePassword
                                    ? AppStrings.loginShowPassword
                                    : AppStrings.loginHidePassword,
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7F5),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFF2C3BB),
                              ),
                            ),
                            child: CheckboxListTile(
                              value: _keepSignedIn,
                              onChanged: isLoading
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _keepSignedIn = value ?? true;
                                      });
                                    },
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 2,
                              ),
                              checkboxShape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              activeColor: const Color(0xFFE65A43),
                              title: Text(
                                AppStrings.loginKeepSignedIn,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFF111827),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                AppStrings.loginKeepSignedInSubtitle,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFF6B7280),
                                  height: 1.25,
                                ),
                              ),
                            ),
                          ),
                          if (errorMessage.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Container(
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
                              onPressed: isLoading ? null : handleLogin,
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
                                      AppStrings.login,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 10),
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
}
