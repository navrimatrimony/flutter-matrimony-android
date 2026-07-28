import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_matrimony_android/core/api_cache.dart';
import 'package:flutter_matrimony_android/core/api_client.dart';
import 'package:flutter_matrimony_android/core/app_language.dart';
import 'package:flutter_matrimony_android/core/app_storage.dart';
import 'package:flutter_matrimony_android/features/auth/login_screen.dart';

import '../../support/fake_http.dart';

/// The member login screen offered password only, while registration has always
/// signed members in with a mobile OTP. These tests cover the OTP door that was
/// added to close that gap, and pin the three failure modes that matter most on
/// a rural handset: a spinner that never ends, an error nobody can see, and the
/// temporary `dev_show` OTP quietly becoming the only path anyone exercises.
///
/// `pumpAndSettle` is unusable here — the resend countdown ticks forever — so
/// pump a fixed number of frames instead.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
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
    // Production is on `mobile_verification_mode = dev_show`, so the OTP really
    // does come back in the send response. Modelled here exactly as it arrives.
    http.onJson('/auth/mobile-otp/send', <String, dynamic>{
      'success': true,
      'challenge_id': 'ch_login_1',
      'expires_in': 600,
      'resend_after': 60,
      'delivery_channel': 'dev',
      'debug_otp': '123456',
    });
    http.onJson('/matrimony-profile', <String, dynamic>{
      'success': true,
      'profile': <String, dynamic>{'id': 7, 'full_name': 'Asha Patil'},
    });

    final previous = HttpOverrides.current;
    HttpOverrides.global = http;
    addTearDown(() => HttpOverrides.global = previous);
  });

  tearDown(() {
    ApiClient.authToken = null;
    ApiCache.instance.clear();
  });

  Future<void> pumpLogin(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: const LoginScreen(),
        routes: <String, WidgetBuilder>{
          '/home': (_) => const Scaffold(body: Text('HOME')),
          '/matches': (_) => const Scaffold(body: Text('MATCHES')),
          '/smart-onboarding': (_) => const Scaffold(body: Text('ONBOARDING')),
          '/register': (_) => const Scaffold(body: Text('REGISTER')),
        },
      ),
    );
    await settle(tester);
  }

  Future<void> sendOtp(WidgetTester tester) async {
    await tester.enterText(
      find.byType(TextField).first,
      '9876543210',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Get OTP'));
    await tester.pump();
    await settle(tester);
  }

  /// The OTP field is the second one once the challenge exists.
  Finder otpField() => find.byType(TextField).at(1);

  testWidgets('the OTP door opens by default, not the password one', (
    tester,
  ) async {
    await pumpLogin(tester);

    expect(find.widgetWithText(ElevatedButton, 'Get OTP'), findsOneWidget);
    expect(find.text('Use password instead'), findsOneWidget);
    // Password is a peer, not a replacement — and it still accepts the email or
    // username identifiers OTP cannot.
    await tester.tap(find.text('Use password instead'));
    await settle(tester);
    expect(find.text('Mobile / Email / Username'), findsOneWidget);
    expect(find.text('Use OTP instead'), findsOneWidget);
  });

  testWidgets('the dev_show OTP is never typed into the box for the member', (
    tester,
  ) async {
    await pumpLogin(tester);
    await sendOtp(tester);

    // Shown, clearly marked as test-only...
    expect(find.text('Test OTP: 123456'), findsOneWidget);
    // ...but the field stays empty and nothing auto-verifies. The moment
    // WhatsApp delivery goes live this banner disappears and the flow the
    // member already knows is unchanged.
    expect(tester.widget<TextField>(otpField()).controller?.text, isEmpty);
    expect(http.requestFor('/auth/mobile-otp/verify'), isNull);
    expect(ApiClient.authToken, isNull);
  });

  testWidgets('a correct OTP signs the member in and leaves no spinner', (
    tester,
  ) async {
    http.onJson('/auth/mobile-otp/verify', <String, dynamic>{
      'success': true,
      'token': 'tok_login_1',
      'token_type': 'Bearer',
      'user': <String, dynamic>{'id': 7, 'mobile': '9876543210'},
      'account_state': <String, dynamic>{
        'is_new_account': false,
        'has_profile': true,
        'next_action': 'resume_onboarding',
      },
    });

    await pumpLogin(tester);
    await sendOtp(tester);
    await tester.enterText(otpField(), '123456');
    await tester.pump(const Duration(milliseconds: 500));
    await settle(tester);

    expect(ApiClient.authToken, 'tok_login_1');
    expect(http.requestFor('/auth/mobile-otp/verify'), isNotNull);
    // The member landed somewhere real rather than on a frozen login card.
    expect(find.text('MATCHES'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a rejected OTP shows the server wording, not a dead spinner', (
    tester,
  ) async {
    http.onJson('/auth/mobile-otp/verify', <String, dynamic>{
      'message': 'Invalid or expired OTP.',
      'errors': <String, dynamic>{
        'otp': <String>['Invalid or expired OTP.'],
      },
    }, status: 422);

    await pumpLogin(tester);
    await sendOtp(tester);
    await tester.enterText(otpField(), '111111');
    await tester.pump(const Duration(milliseconds: 500));
    await settle(tester);

    expect(ApiClient.authToken, isNull);
    expect(find.text('Invalid or expired OTP.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    // Idle again, so a second attempt is possible.
    expect(find.widgetWithText(ElevatedButton, 'Verify OTP'), findsOneWidget);
  });

  testWidgets('a rate limit is shown to the member in words', (tester) async {
    http.onJson('/auth/mobile-otp/send', <String, dynamic>{
      'success': false,
      'message': 'Please wait before requesting another OTP.',
      'resend_after': 42,
    }, status: 429);

    await pumpLogin(tester);
    await sendOtp(tester);

    expect(
      find.text('Please wait before requesting another OTP.'),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.widgetWithText(ElevatedButton, 'Get OTP'), findsOneWidget);
  });

  testWidgets('an unreachable server says so instead of spinning forever', (
    tester,
  ) async {
    http.on('/auth/mobile-otp/send', (_) => throw const SocketException('down'));

    await pumpLogin(tester);
    await sendOtp(tester);

    expect(
      find.text(
        'Could not reach the server. Check your internet and try again.',
      ),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.widgetWithText(ElevatedButton, 'Get OTP'), findsOneWidget);
  });
}
