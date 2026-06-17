import 'package:flutter/material.dart';
import 'features/auth/language_choice_screen.dart';
import 'features/auth/landing_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/home/home_screen.dart';
import 'features/matrimony_profile/create_profile_screen.dart';
import 'features/matrimony_profile/view_profile_screen.dart';

// RouteObserver for RouteAware lifecycle management
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

const Color _brandMaroon = Color(0xFF8B1E3F);
const Color _brandGold = Color(0xFFC79A3B);
const Color _screenBackground = Color(0xFFF8F4EF);

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      initialRoute: '/language',

      navigatorObservers: [routeObserver],

      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _brandMaroon,
          primary: _brandMaroon,
          secondary: _brandGold,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: _screenBackground,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: _brandMaroon,
          foregroundColor: Colors.white,
          elevation: 0,
          titleTextStyle: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _brandMaroon,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: _brandMaroon,
            side: const BorderSide(color: _brandMaroon, width: 1.4),
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _brandMaroon, width: 1.4),
          ),
        ),
      ),

      routes: {
        '/language': (context) => const LanguageChoiceScreen(),
        '/landing': (context) => const LandingScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/create-profile': (context) => const CreateMatrimonyProfileScreen(),
        '/view-profile': (context) => const ViewProfileScreen(),
      },
    );
  }
}
