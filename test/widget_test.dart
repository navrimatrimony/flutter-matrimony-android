import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_matrimony_android/core/app_language.dart';
import 'package:flutter_matrimony_android/core/app_storage.dart';
import 'package:flutter_matrimony_android/core/app_strings.dart';
import 'package:flutter_matrimony_android/features/auth/landing_screen.dart';
import 'package:flutter_matrimony_android/features/auth/login_screen.dart';
import 'package:flutter_matrimony_android/main.dart';

void main() {
  testWidgets('Language choice appears before landing screen', (
    WidgetTester tester,
  ) async {
    AppStorage.instance = AppStorage.memory();
    appLanguage.value = null;

    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text(AppStrings.chooseLanguage), findsOneWidget);
    expect(find.text(AppStrings.marathi), findsOneWidget);
    expect(find.text(AppStrings.english), findsOneWidget);

    await tester.tap(find.text(AppStrings.english));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('New here?'), findsOneWidget);
    expect(find.text('Sign Up with Mobile'), findsOneWidget);
    expect(find.text(AppStrings.login), findsOneWidget);
  });

  testWidgets('/register opens signup choices before onboarding', (
    WidgetTester tester,
  ) async {
    AppStorage.instance = AppStorage.memory();
    setAppLanguage(AppLanguage.english);

    await tester.pumpWidget(
      MaterialApp(
        routes: {'/register': (context) => const LandingScreen()},
        initialRoute: '/register',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Sign Up with Google'), findsOneWidget);
    expect(find.text('Sign Up with Mobile'), findsOneWidget);
    expect(find.text('Sign Up with Email'), findsOneWidget);
    expect(find.text('I am creating this profile for'), findsNothing);
  });

  testWidgets('login register link opens signup choices, not onboarding', (
    WidgetTester tester,
  ) async {
    AppStorage.instance = AppStorage.memory();
    setAppLanguage(AppLanguage.english);

    await tester.pumpWidget(
      MaterialApp(
        routes: {
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const LandingScreen(),
        },
        initialRoute: '/login',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('New user? Register here'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Sign Up with Mobile'), findsOneWidget);
    expect(find.text('I am creating this profile for'), findsNothing);
  });
}
