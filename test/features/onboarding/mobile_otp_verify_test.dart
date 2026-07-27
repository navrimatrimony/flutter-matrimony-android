import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_matrimony_android/core/api_client.dart';
import 'package:flutter_matrimony_android/core/app_language.dart';
import 'package:flutter_matrimony_android/core/app_storage.dart';
import 'package:flutter_matrimony_android/features/onboarding/smart_onboarding_screen.dart';

import '../../support/fake_http.dart';

/// Reported from a real device: the member entered a mobile number, the OTP
/// arrived, and the screen then sat on a spinner and never moved on. The server
/// had genuinely issued a personal access token at that moment — the login
/// worked, only the UI failed to follow.
///
/// The verify step stores the token FIRST and then does more network work
/// before it moves, all while `_loading` is true — which disables the OTP
/// field, disables the button and makes the screen refuse to pop. So anything
/// slow or unexpected after the token lands strands a member who is, as far as
/// the server is concerned, already signed in.
///
/// Production runs `mobile_verification_mode = dev_show`, so the OTP comes back
/// in the send response, the field self-fills and the AUTO-verify path is the
/// one real members take. That is the path exercised here.
/// `pumpAndSettle` is unusable on this screen: a progress indicator and the
/// header band's marquee never stop animating, so it always times out. Pump a
/// fixed number of frames instead, which is enough to flush the awaited work.
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

    http = FakeHttpOverrides();
    http.onJson('/auth/mobile-otp/send', <String, dynamic>{
      'success': true,
      'challenge_id': 'ch_test_1',
      'expires_in': 300,
      'resend_after': 15,
      'delivery_channel': 'dev',
      'debug_otp': '123456',
    });

    final previous = HttpOverrides.current;
    HttpOverrides.global = http;
    addTearDown(() => HttpOverrides.global = previous);
  });

  tearDown(() {
    ApiClient.authToken = null;
  });

  Future<void> pumpOtpScreen(WidgetTester tester) async {
    // Phone-shaped. The default 800x600 test surface overflows this screen's
    // chrome, which is a separate layout quirk and not what is under test here.
    await tester.binding.setSurfaceSize(const Size(412, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: SmartOnboardingScreen(
          initialMode: SmartOnboardingInitialMode.mobileOtp,
          initialMobile: '9876543210',
        ),
      ),
    );
    await settle(tester);
  }

  /// Taps "Get OTP", then lets the auto-verify timer and its hand-off pause run
  /// out. Mirrors the real timings: 1400ms before auto-verify fires, then a
  /// 900ms hand-off pause once it succeeds.
  Future<void> sendAndAutoVerify(WidgetTester tester) async {
    await tester.tap(find.text('Get OTP'));
    await tester.pump();
    await settle(tester);

    await tester.pump(const Duration(milliseconds: 1500));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 1000));
    await settle(tester);
  }

  testWidgets('a verified member gets in even when the follow-up lookups fail', (
    tester,
  ) async {
    http.onJson('/auth/mobile-otp/verify', <String, dynamic>{
      'success': true,
      'token': 'tok_test_1',
      'token_type': 'Bearer',
      'user': <String, dynamic>{'id': 1, 'mobile': '9876543210'},
      'account_state': <String, dynamic>{
        'is_new_account': false,
        'has_profile': true,
        'next_action': 'resume_onboarding',
      },
    });
    // The exact conditions that used to strand the member: the token lands,
    // then everything the screen wanted to load next falls over.
    http.onJson(
      '/onboarding/lookups/bootstrap',
      <String, dynamic>{'success': false},
      status: 500,
    );
    http.onJson(
      '/onboarding/status',
      <String, dynamic>{'success': false},
      status: 500,
    );

    await pumpOtpScreen(tester);
    await sendAndAutoVerify(tester);

    // The session is real...
    expect(ApiClient.authToken, 'tok_test_1');
    expect(http.requestFor('/auth/mobile-otp/verify'), isNotNull);
    // ...so the screen must have moved on, and no spinner may be left running.
    expect(find.text('Verify and continue'), findsNothing);
    expect(find.text('Verifying...'), findsNothing);
    expect(find.text('Continuing...'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a rejected OTP shows an error instead of an endless spinner', (
    tester,
  ) async {
    http.onJson('/auth/mobile-otp/verify', <String, dynamic>{
      'success': false,
      'message': 'That code is not right.',
    }, status: 422);

    await pumpOtpScreen(tester);
    await sendAndAutoVerify(tester);

    expect(ApiClient.authToken, isNull);
    // The header band scrolls its text, so it renders more than one copy.
    expect(find.text('That code is not right.'), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    // Still on the verify step, and idle rather than frozen: the button only
    // carries this label when neither `_loading` nor `_otpAutoAdvancePending`
    // is set — the two flags that used to stick and disable the whole step.
    expect(find.text('Verify and continue'), findsOneWidget);
    expect(find.text('Verifying...'), findsNothing);
    expect(find.text('Continuing...'), findsNothing);
  });

  testWidgets('a send failure clears the spinner and says so', (tester) async {
    http.onJson('/auth/mobile-otp/send', <String, dynamic>{
      'success': false,
      'message': 'Could not send the code right now.',
    }, status: 500);

    await pumpOtpScreen(tester);
    await tester.tap(find.text('Get OTP'));
    await tester.pump();
    await settle(tester);

    expect(find.text('Could not send the code right now.'), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    // Back to the idle label, so the member can try again.
    expect(find.text('Get OTP'), findsOneWidget);
    expect(find.text('Sending OTP'), findsNothing);
  });
}
