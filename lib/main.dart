import 'package:flutter/material.dart';
import 'features/auth/login_screen.dart';
import 'features/home/home_screen.dart';
import 'features/matrimony_profile/create_profile_screen.dart';
import 'features/matrimony_profile/view_profile_screen.dart';
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
        '/home': (context) => HomeScreen(),
        '/create-profile': (context) => const CreateMatrimonyProfileScreen(),
        '/view-profile': (context) => const ViewProfileScreen(),
      },
    );

  }
}

