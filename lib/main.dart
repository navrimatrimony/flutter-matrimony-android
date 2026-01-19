import 'package:flutter/material.dart';
import 'features/auth/landing_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/home/home_screen.dart';
import 'features/matrimony_profile/create_profile_screen.dart';
import 'features/matrimony_profile/view_profile_screen.dart';

// RouteObserver for RouteAware lifecycle management
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      initialRoute: '/landing',

      navigatorObservers: [routeObserver],

      routes: {
        '/landing': (context) => const LandingScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => HomeScreen(),
        '/create-profile': (context) => const CreateMatrimonyProfileScreen(),
        '/view-profile': (context) => const ViewProfileScreen(),
      },
    );

  }
}

