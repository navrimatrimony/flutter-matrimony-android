import 'package:flutter/material.dart';
import 'features/auth/login_screen.dart';
import 'features/matrimony_profile/create_profile_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      initialRoute: '/login',

      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/create-profile': (context) => const CreateMatrimonyProfileScreen(),
      },
    );

  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Matrimony'),
      ),
      body: const Center(
        child: Text(
          'Hello Flutter',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
