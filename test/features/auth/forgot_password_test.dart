import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_matrimony_android/core/api_cache.dart';
import 'package:flutter_matrimony_android/core/api_client.dart';
import 'package:flutter_matrimony_android/core/app_language.dart';
import 'package:flutter_matrimony_android/core/app_storage.dart';
import 'package:flutter_matrimony_android/features/auth/forgot_password_screen.dart';

import '../../support/fake_http.dart';

/// The member app shipped without any way to recover a password, though
/// `/api/v1/auth/password/{forgot,reset}` had been live all along.
///
/// These tests pin the parts of that contract a client can get wrong:
/// `forgot` reports failures as **422 with `success: false`**, never 429 — the
/// route carries no throttle middleware, and the broker's 60-second window
/// arrives as a plain 422 sentence. And every failure must leave a readable
/// message on screen with the spinner stopped, which is the bug this app
/// already shipped once on the OTP screen.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void main() {
  late FakeHttpOverrides http;

  setUp(() {
    AppStorage.instance = AppStorage.memory();
    setAppLanguage(AppLanguage.english);
    ApiClient.authToken = null;
    ApiClient.currentUserProfile = null;
    ApiCache.instance.clear();

    http = FakeHttpOverrides();
    final previous = HttpOverrides.current;
    HttpOverrides.global = http;
    addTearDown(() => HttpOverrides.global = previous);
  });

  tearDown(() {
    ApiClient.authToken = null;
    ApiCache.instance.clear();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: const ForgotPasswordScreen(),
        routes: <String, WidgetBuilder>{
          '/login': (_) => const Scaffold(body: Text('LOGIN')),
        },
      ),
    );
    await settle(tester);
  }

  Future<void> requestLink(WidgetTester tester, String identifier) async {
    await tester.enterText(find.byType(TextField).first, identifier);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Send reset link'));
    await settle(tester);
  }

  testWidgets('a successful request moves on and posts the login key', (
    tester,
  ) async {
    http.onJson('/auth/password/forgot', <String, dynamic>{
      'success': true,
      'message': 'We have emailed your password reset link!',
    });

    await pumpScreen(tester);
    await requestLink(tester, '9876543210');

    // The controller reads one key for mobile, email and username alike.
    final sent = http.requestFor('/auth/password/forgot');
    expect(sent, isNotNull);
    expect(sent!.jsonBody['login'], '9876543210');

    expect(find.text('Reset password'), findsWidgets);
    expect(
      find.text('We have emailed your password reset link!'),
      findsOneWidget,
      reason: "the server's own sentence is what the member reads",
    );
  });

  testWidgets('an unknown account shows the server message, not a spinner', (
    tester,
  ) async {
    // PasswordResetApiController returns this as 422 with success:false.
    http.onJson('/auth/password/forgot', <String, dynamic>{
      'success': false,
      'message':
          'We could not find an account with a reset-enabled email for this login.',
    }, status: 422);

    await pumpScreen(tester);
    await requestLink(tester, 'nobody@example.com');

    expect(
      find.text(
        'We could not find an account with a reset-enabled email for this login.',
      ),
      findsOneWidget,
    );
    expect(
      find.byType(CircularProgressIndicator),
      findsNothing,
      reason: 'a failed request must never leave the spinner running',
    );
  });

  testWidgets('the 60-second throttle arrives as a 422 and is shown', (
    tester,
  ) async {
    // config/auth.php sets the broker throttle to 60s; there is no 429 here.
    http.onJson('/auth/password/forgot', <String, dynamic>{
      'success': false,
      'message': 'Please wait before retrying.',
    }, status: 422);

    await pumpScreen(tester);
    await requestLink(tester, '9876543210');

    expect(find.text('Please wait before retrying.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a validation 422 with no success key still surfaces a message', (
    tester,
  ) async {
    // This project has no handler reshaping ValidationException, so the
    // envelope is Laravel's stock one: no `success`, errors keyed by field.
    http.onJson('/auth/password/forgot', <String, dynamic>{
      'message': 'The login field is required when email is not present.',
      'errors': <String, dynamic>{
        'login': <String>['The login field is required when email is not present.'],
      },
    }, status: 422);

    await pumpScreen(tester);
    await requestLink(tester, 'x');

    expect(
      find.text('The login field is required when email is not present.'),
      findsOneWidget,
    );
  });

  testWidgets('an unreachable server is reported, and the spinner stops', (
    tester,
  ) async {
    http.on('/auth/password/forgot', (_) => throw const SocketException('down'));

    await pumpScreen(tester);
    await requestLink(tester, '9876543210');

    expect(
      find.text('Could not reach the server. Check your internet and try again.'),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a pasted reset link fills the email and unpacks the token', (
    tester,
  ) async {
    http.onJson('/auth/password/forgot', <String, dynamic>{'success': true});
    http.onJson('/auth/password/reset', <String, dynamic>{
      'success': true,
      'message': 'Your password has been reset!',
    });
    ApiClient.authToken = 'stale-token-from-the-old-password';

    await pumpScreen(tester);
    await requestLink(tester, '9876543210');

    // Exactly the URL Illuminate's ResetPassword notification builds.
    await tester.enterText(
      find.byType(TextField).at(0),
      'https://navrimilenavryala.com/reset-password/tok_abc123?email=asha%40example.com',
    );
    await settle(tester);

    // The reset endpoint does not accept a mobile number, so the email has to
    // come out of the link.
    expect(find.text('asha@example.com'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(2), 'newpassword1');
    await tester.enterText(find.byType(TextField).at(3), 'newpassword1');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Reset password'));
    await settle(tester);

    final sent = http.requestFor('/auth/password/reset');
    expect(sent, isNotNull);
    expect(sent!.jsonBody['token'], 'tok_abc123');
    expect(sent.jsonBody['email'], 'asha@example.com');
    expect(sent.jsonBody['password'], 'newpassword1');
    expect(sent.jsonBody['password_confirmation'], 'newpassword1');

    // The server issues no session on reset and revokes nothing, so the token
    // this device still held belongs to the replaced password.
    expect(
      ApiClient.authToken,
      isNull,
      reason: 'a reset member must not be left holding a stale session',
    );
    expect(find.text('LOGIN'), findsOneWidget);
  });

  testWidgets('an expired token shows the server wording', (tester) async {
    http.onJson('/auth/password/forgot', <String, dynamic>{'success': true});
    http.onJson('/auth/password/reset', <String, dynamic>{
      'success': false,
      'message': 'This password reset token is invalid.',
    }, status: 422);

    await pumpScreen(tester);
    await requestLink(tester, 'asha@example.com');

    await tester.enterText(find.byType(TextField).at(0), 'tok_expired');
    await tester.enterText(find.byType(TextField).at(2), 'newpassword1');
    await tester.enterText(find.byType(TextField).at(3), 'newpassword1');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Reset password'));
    await settle(tester);

    expect(find.text('This password reset token is invalid.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a short password is caught before the request leaves', (
    tester,
  ) async {
    http.onJson('/auth/password/forgot', <String, dynamic>{'success': true});

    await pumpScreen(tester);
    await requestLink(tester, 'asha@example.com');

    await tester.enterText(find.byType(TextField).at(0), 'tok_abc123');
    await tester.enterText(find.byType(TextField).at(2), 'short');
    await tester.enterText(find.byType(TextField).at(3), 'short');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Reset password'));
    await settle(tester);

    // Rules\Password::defaults() is an uncustomised min:8 in this project.
    expect(find.text('Use at least 8 characters.'), findsOneWidget);
    expect(http.requestFor('/auth/password/reset'), isNull);
  });

  testWidgets('mismatched confirmation is caught before the request leaves', (
    tester,
  ) async {
    http.onJson('/auth/password/forgot', <String, dynamic>{'success': true});

    await pumpScreen(tester);
    await requestLink(tester, 'asha@example.com');

    await tester.enterText(find.byType(TextField).at(0), 'tok_abc123');
    await tester.enterText(find.byType(TextField).at(2), 'newpassword1');
    await tester.enterText(find.byType(TextField).at(3), 'newpassword2');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Reset password'));
    await settle(tester);

    expect(find.text('Both passwords must match.'), findsOneWidget);
    expect(http.requestFor('/auth/password/reset'), isNull);
  });
}
