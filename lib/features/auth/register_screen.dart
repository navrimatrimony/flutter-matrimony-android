import 'package:flutter/material.dart';
import '../../core/api_client.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;
  String errorMessage = '';

  String selectedGender = 'male';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Name
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
              ),
            ),

            const SizedBox(height: 12),

            // Gender
            DropdownButtonFormField<String>(
              initialValue: selectedGender,
              items: const [
                DropdownMenuItem(
                  value: 'male',
                  child: Text('Male'),
                ),
                DropdownMenuItem(
                  value: 'female',
                  child: Text('Female'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  selectedGender = value!;
                });
              },
              decoration: const InputDecoration(
                labelText: 'Gender',
              ),
            ),

            const SizedBox(height: 12),

            // Email
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
              ),
            ),

            const SizedBox(height: 12),

            // Password
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

            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                setState(() {
                  isLoading = true;
                  errorMessage = '';
                });

                final result = await ApiClient.register(
                  name: nameController.text,
                  email: emailController.text,
                  password: passwordController.text,
                  passwordConfirmation: passwordController.text,
                  gender: selectedGender,
                );



                setState(() {
                  isLoading = false;
                });

                if (result['message'] != null &&
                    result['message'].toString().toLowerCase().contains('success')) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Registration यशस्वी! Profile create करा...'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                  Navigator.pushReplacementNamed(context, '/create-profile');


                } else {
                  setState(() {
                    errorMessage = result['message'] ?? 'Registration failed';
                  });
                }



              },
              child: isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Register'),
            ),

          ],
        ),
      ),
    );
  }
}
