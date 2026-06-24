import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../onboarding/smart_onboarding_screen.dart';

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

  void handleLogin() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    final result = await ApiClient.login(
      login: loginController.text,
      password: passwordController.text,
    );

    // Check if login was successful (token present)
    if (result.containsKey('token') && result['token'] != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Login यशस्वी! Welcome back...'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
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
            const SnackBar(
              content: Text('ℹ️ प्रोफाइल सापडली नाही. प्रोफाइल तयार करा...'),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.pushReplacementNamed(context, '/smart-onboarding');
          return;
        }

        if (statusCode == 200 && profileResult['success'] == true) {
          setState(() {
            isLoading = false;
          });
          Navigator.pushReplacementNamed(context, '/home');
          return;
        }

        setState(() {
          isLoading = false;
          errorMessage =
              profileResult['message'] ??
              'Profile check failed. Please try again.';
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          isLoading = false; // दुरुस्ती केली
          errorMessage = 'Profile check error: ${e.toString()}';
        });
      }
      return;
    }
    // Login failed
    if (!mounted) return;
    setState(() {
      isLoading = false; // दुरुस्ती केली
      errorMessage =
          result['message'] ?? 'Login failed. Check login or password.';
    });
  }

  @override
  void dispose() {
    loginController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: loginController,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.next,
              autofillHints: const [
                AutofillHints.username,
                AutofillHints.email,
                AutofillHints.telephoneNumber,
              ],
              decoration: const InputDecoration(
                labelText: 'Mobile / Email / Username',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 20),
            if (errorMessage.isNotEmpty)
              Text(errorMessage, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: isLoading ? null : handleLogin,
              child: isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Login'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SmartOnboardingScreen(),
                  ),
                );
              },
              child: const Text('New user? Register here'),
            ),
          ],
        ),
      ),
    );
  }
}
