import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_matrimony_android/core/api_cache.dart';
import 'package:flutter_matrimony_android/core/api_client.dart';
import 'package:flutter_matrimony_android/core/app_language.dart';
import 'package:flutter_matrimony_android/core/app_storage.dart';
import 'package:flutter_matrimony_android/features/settings/change_password_screen.dart';

import '../../support/fake_http.dart';

/// `POST /api/v1/account/password` is the only change-password path a member
/// has: the emailed reset link cannot reach a mobile-only account, so without
/// this screen a member who signs in by OTP can never set a password at all.
///
/// The contract these tests pin comes from `MemberPasswordApiController`:
/// `password` + `password_confirmation`, **no current password**, `{success,
/// message}` on the way out, and a stock 422 with `errors.password` when
/// `Rules\Password::defaults()` rejects it. The server also keeps THIS device's
/// Sanctum token alive while revoking every other one — so a member must come
/// out of a successful change still signed in.
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
    ApiClient.authToken = 'tok_this_device';
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

  /// Pushed rather than used as `home`, because a successful change pops back
  /// to wherever the member came from — Settings, in the app.
  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  Navigator.pushNamed(context, '/change-password'),
              child: const Text('SETTINGS'),
            ),
          ),
        ),
        routes: <String, WidgetBuilder>{
          '/change-password': (_) => const ChangePasswordScreen(),
          '/login': (_) => const Scaffold(body: Text('LOGIN')),
        },
      ),
    );
    await tester.tap(find.text('SETTINGS'));
    await settle(tester);
  }

  Future<void> submit(
    WidgetTester tester,
    String password,
    String confirmation,
  ) async {
    await tester.enterText(find.byType(TextField).at(0), password);
    await tester.enterText(find.byType(TextField).at(1), confirmation);
    await tester.tap(
      find.widgetWithText(ElevatedButton, 'Save new password'),
    );
    await settle(tester);
  }

  testWidgets('the old password is never asked for', (tester) async {
    await pumpScreen(tester);

    // Two boxes: the new password and its confirmation. A third one would be
    // the lockout this screen exists to remove.
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('New password'), findsOneWidget);
    expect(find.text('Confirm new password'), findsOneWidget);
  });

  testWidgets('a new password is saved and the member stays signed in', (
    tester,
  ) async {
    http.onJson('/account/password', <String, dynamic>{
      'success': true,
      'message':
          'Your password has been updated. Other devices have been signed out.',
    });

    await pumpScreen(tester);
    await submit(tester, 'NewPassword1!', 'NewPassword1!');

    final sent = http.requestFor('/account/password');
    expect(sent, isNotNull);
    expect(sent!.jsonBody['password'], 'NewPassword1!');
    expect(sent.jsonBody['password_confirmation'], 'NewPassword1!');
    // No current password is sent, because the server does not ask for one.
    expect(sent.jsonBody.containsKey('current_password'), isFalse);

    // The server spares this device's token on purpose; throwing it away here
    // would sign her out of the one session it deliberately kept.
    expect(ApiClient.authToken, 'tok_this_device');
    expect(find.text('SETTINGS'), findsOneWidget);
    expect(
      find.text(
        'Your password has been updated. Other devices have been signed out.',
      ),
      findsOneWidget,
      reason: "the server's own confirmation is what the member reads",
    );
  });

  testWidgets('a password the server rejects is shown in the server wording', (
    tester,
  ) async {
    // Rules\Password::defaults() is an uncustomised min:8, and this project has
    // no handler reshaping ValidationException — so this is the real envelope.
    http.onJson('/account/password', <String, dynamic>{
      'message': 'The password field must be at least 8 characters.',
      'errors': <String, dynamic>{
        'password': <String>[
          'The password field must be at least 8 characters.',
        ],
      },
    }, status: 422);

    await pumpScreen(tester);
    await submit(tester, 'short', 'short');

    expect(
      find.text('The password field must be at least 8 characters.'),
      findsOneWidget,
    );
    expect(
      find.byType(CircularProgressIndicator),
      findsNothing,
      reason: 'a rejected password must never leave the spinner running',
    );
    // Still here, still able to try again.
    expect(
      find.widgetWithText(ElevatedButton, 'Save new password'),
      findsOneWidget,
    );
  });

  testWidgets('no client-side length rule fires before the server sees it', (
    tester,
  ) async {
    http.onJson('/account/password', <String, dynamic>{'success': true});

    await pumpScreen(tester);
    await submit(tester, 'short', 'short');

    // The server owns the password policy. Guessing at it here would start
    // disagreeing the day someone tightens Rules\Password::defaults().
    expect(http.requestFor('/account/password'), isNotNull);
  });

  testWidgets('a mismatched confirmation is caught before the request leaves', (
    tester,
  ) async {
    await pumpScreen(tester);
    await submit(tester, 'NewPassword1!', 'NewPassword2!');

    expect(find.text('Both passwords must match.'), findsOneWidget);
    expect(http.requestFor('/account/password'), isNull);
  });

  testWidgets('an empty password is named, not sent', (tester) async {
    await pumpScreen(tester);
    await submit(tester, '', '');

    expect(find.text('Enter a new password.'), findsOneWidget);
    expect(http.requestFor('/account/password'), isNull);
  });

  testWidgets('an unreachable server is reported, and the spinner stops', (
    tester,
  ) async {
    http.on('/account/password', (_) => throw const SocketException('down'));

    await pumpScreen(tester);
    await submit(tester, 'NewPassword1!', 'NewPassword1!');

    expect(
      find.text('Could not reach the server. Check your internet and try again.'),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a token another device already revoked sends her to sign in', (
    tester,
  ) async {
    // Sanctum's answer once this token is gone — which is exactly what happens
    // when the password was changed from her other phone first.
    http.onJson('/account/password', <String, dynamic>{
      'message': 'Unauthenticated.',
    }, status: 401);

    await pumpScreen(tester);
    await submit(tester, 'NewPassword1!', 'NewPassword1!');

    expect(ApiClient.authToken, isNull);
    expect(find.text('LOGIN'), findsOneWidget);
  });
}
