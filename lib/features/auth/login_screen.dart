import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../auth/register_screen.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;
  String errorMessage = '';

  void handleLogin() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    final result = await ApiClient.login(
      email: emailController.text,
      password: passwordController.text,
    );

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Login यशस्वी! Welcome back...'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      final profileResult = await ApiClient.getMyProfile();
      final statusCode = profileResult['statusCode'];

      if (statusCode == 404) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ℹ️ Profile सापडली नाही. Profile create करा...'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pushReplacementNamed(context, '/create-profile');
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
        errorMessage = profileResult['message'] ??
            'Profile check failed. Please try again.';
      });
      return;
    }


    setState(() {
      isLoading = false;
    });

    setState(() {
      errorMessage =
          result['message'] ?? 'Login failed. Check email or password.';
    });

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
              ),
            ),
            const SizedBox(height: 20),
            if (errorMessage.isNotEmpty)
              Text(
                errorMessage,
                style: const TextStyle(color: Colors.red),
              ),
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
                    builder: (context) => const RegisterScreen(),
                  ),
                );
              },
              child: const Text(
                'New user? Register here',
              ),
            ),

          ],
        ),
      ),
    );
  }
}
