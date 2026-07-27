import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_matrimony_android/core/api_client.dart';
import 'package:flutter_matrimony_android/core/app_language.dart';
import 'package:flutter_matrimony_android/core/app_storage.dart';
import 'package:flutter_matrimony_android/features/matrimony_profile/profile_detail_screen.dart';
import 'package:flutter_matrimony_android/main.dart';

import '../../support/fake_http.dart';

/// A Suchak-routed profile never shows the candidate's number — the product
/// rule is that contact happens through the Suchak. Before this flow shipped,
/// the app knew none of the four `suchak_request_*` states, so the card fell
/// through to "unavailable" and the button dead-ended in a snackbar: a working
/// backend rendered as a failure.
///
/// These tests drive the real profile detail screen against the real payload
/// shape, so a state dropped from any of the three switches shows up here.
void main() {
  const profileId = 4242;
  late FakeHttpOverrides http;

  setUp(() {
    AppStorage.instance = AppStorage.memory();
    setAppLanguage(AppLanguage.english);
    ApiClient.authToken = 'test-token';
    ApiClient.currentUserProfile = null;

    http = FakeHttpOverrides();
    final previous = HttpOverrides.current;
    HttpOverrides.global = http;
    addTearDown(() => HttpOverrides.global = previous);
  });

  Map<String, dynamic> suchakBlock({
    Map<String, dynamic>? request,
    bool canRequest = true,
  }) {
    return <String, dynamic>{
      'representation_id': 71,
      'suchak_account_id': 9,
      'name': 'Pawar Vivah Mandal',
      'subtitle': 'Experienced marriage facilitator',
      'initial': 'P',
      // Left null on purpose: the initial-avatar path is what a Suchak without
      // an uploaded photo actually hits, and it keeps Image.network out of the
      // widget tree under test.
      'photo_url': null,
      'masked_phone': '9822XXXXXX',
      'can_request': canRequest,
      'request': request,
    };
  }

  Map<String, dynamic> contactPayload({
    required String state,
    required String ctaLabel,
    required String ctaAction,
    required bool ctaEnabled,
    required String message,
    Map<String, dynamic>? request,
    bool canRequest = true,
  }) {
    return <String, dynamic>{
      'enabled': true,
      'title': 'Contact Information',
      'state': state,
      'message': message,
      // The candidate's own number is absent by design on every Suchak state.
      'phone': null,
      'masked_phone': null,
      'email': null,
      'primary_cta': <String, dynamic>{
        'label': ctaLabel,
        'style': ctaEnabled ? 'primary' : 'disabled',
        'action': ctaAction,
        'enabled': ctaEnabled,
      },
      'suchak': suchakBlock(request: request, canRequest: canRequest),
      'whatsapp_response': <String, dynamic>{
        'visible': false,
        'label': 'WhatsApp Response',
        'message': null,
        'enabled': false,
      },
    };
  }

  Map<String, dynamic> profileResponse(Map<String, dynamic> contact) {
    return <String, dynamic>{
      'success': true,
      'profile': <String, dynamic>{
        'id': profileId,
        'full_name': 'Asha Patil',
        'date_of_birth': '1996-04-12',
      },
      'display': <String, dynamic>{
        'hero': <String, dynamic>{'name': 'Asha Patil'},
        'contact': contact,
      },
    };
  }

  Future<void> pumpProfile(
    WidgetTester tester,
    Map<String, dynamic> contact,
  ) async {
    http.onJson('/matrimony-profiles/$profileId', profileResponse(contact));

    await tester.pumpWidget(
      MaterialApp(
        // The app registers this observer, and the screen re-reads the profile
        // through it; a host without it cannot observe that.
        navigatorObservers: [routeObserver],
        home: const ProfileDetailScreen(profileId: profileId),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  /// `ElevatedButton.icon` builds a private subclass, so `find.byType` (an
  /// exact runtime-type match) never sees the CTA. Match on the supertype.
  Finder ctaFinder(String label) => find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate((widget) => widget is ElevatedButton),
  );

  ElevatedButton ctaButton(WidgetTester tester, String label) =>
      tester.widget<ElevatedButton>(ctaFinder(label).first);

  List<String> renderedText(WidgetTester tester) {
    final values = <String>[];
    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      final value = text.data;
      if (value != null) values.add(value);
    }
    for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
      values.add(rich.text.toPlainText());
    }

    return values;
  }

  testWidgets(
    'suchak_request_available names the Suchak and offers the request',
    (WidgetTester tester) async {
      await pumpProfile(
        tester,
        contactPayload(
          state: 'suchak_request_available',
          ctaLabel: 'Request through Suchak',
          ctaAction: 'send_suchak_request',
          ctaEnabled: true,
          message: 'A Suchak manages this profile.',
        ),
      );

      // Who manages the profile, not a blank contact block.
      expect(find.text('Pawar Vivah Mandal'), findsOneWidget);
      expect(find.text('Experienced marriage facilitator'), findsOneWidget);
      expect(find.text(appText.suchakManagedProfileTitle), findsOneWidget);
      // The Suchak's own masked number — never the candidate's.
      expect(find.text('9822XXXXXX'), findsOneWidget);
      // Says why the number is missing rather than leaving it to be read as a
      // bug.
      expect(find.text(appText.suchakContactPrivacyNote), findsOneWidget);
      expect(find.text(appText.suchakStateAvailableBadge), findsWidgets);
      expect(find.text('Request through Suchak'), findsOneWidget);

      // The old failure mode: an unknown state degrading to "unavailable".
      expect(
        find.text(appText.contactInformationNotAvailable),
        findsNothing,
        reason: 'A Suchak-routed profile is not an unavailable contact.',
      );
    },
  );

  testWidgets('tapping the CTA posts to the profile suchak-requests endpoint', (
    WidgetTester tester,
  ) async {
    http.onJson(
      '/matrimony-profiles/$profileId/suchak-requests',
      <String, dynamic>{
        'success': true,
        'message': 'Suchak request sent.',
        'data': <String, dynamic>{},
        'display': <String, dynamic>{
          'contact': contactPayload(
            state: 'suchak_request_pending',
            ctaLabel: 'Request pending',
            ctaAction: 'none',
            ctaEnabled: false,
            message: 'Your request is with the Suchak.',
            canRequest: false,
            request: <String, dynamic>{
              'id': 501,
              'status': 'pending',
              'status_label': 'Request pending',
            },
          ),
        },
      },
      status: 201,
    );

    await pumpProfile(
      tester,
      contactPayload(
        state: 'suchak_request_available',
        ctaLabel: 'Request through Suchak',
        ctaAction: 'send_suchak_request',
        ctaEnabled: true,
        message: 'A Suchak manages this profile.',
      ),
    );

    final cta = ctaFinder('Request through Suchak').first;
    await tester.ensureVisible(cta);
    await tester.pump();
    await tester.tap(cta);
    await tester.pumpAndSettle();

    // The sheet collects an optional note before anything is sent. It is
    // pushed over the card, so its copy of the label is the later one.
    expect(find.text(appText.suchakRequestMessageLabel), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Please share more detail.');
    await tester.tap(ctaFinder('Request through Suchak').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final posted = http.requestFor('/suchak-requests');
    expect(
      posted,
      isNotNull,
      reason: 'The CTA must reach POST /matrimony-profiles/{id}/suchak-requests.',
    );
    expect(posted!.uri.path, endsWith('/matrimony-profiles/$profileId/suchak-requests'));
    expect(posted.jsonBody['representation_id'], 71);
    expect(posted.jsonBody['message'], 'Please share more detail.');
  });

  testWidgets('suchak_request_pending reads as waiting, not as an error', (
    WidgetTester tester,
  ) async {
    await pumpProfile(
      tester,
      contactPayload(
        state: 'suchak_request_pending',
        ctaLabel: 'Request pending',
        ctaAction: 'none',
        ctaEnabled: false,
        message: 'Your request is with the Suchak.',
        canRequest: false,
        request: <String, dynamic>{
          'id': 501,
          'status': 'pending',
          'status_label': 'Request pending',
        },
      ),
    );

    expect(find.text('Your request is with the Suchak.'), findsOneWidget);
    expect(find.text(appText.pending), findsWidgets);
    // Status the server already localised, echoed rather than re-derived.
    expect(find.text('Request pending'), findsWidgets);
    expect(find.text(appText.contactInformationNotAvailable), findsNothing);

    expect(
      ctaButton(tester, 'Request pending').onPressed,
      isNull,
      reason: 'Nothing to do while the Suchak holds the request.',
    );
  });

  testWidgets('suchak_request_answered offers the existing chat', (
    WidgetTester tester,
  ) async {
    await pumpProfile(
      tester,
      contactPayload(
        state: 'suchak_request_answered',
        ctaLabel: 'Open chat',
        ctaAction: 'open_suchak_chat',
        ctaEnabled: true,
        message: 'The Suchak has answered.',
        canRequest: false,
        request: <String, dynamic>{
          'id': 501,
          'status': 'candidate_interested',
          'status_label': 'Candidate interested',
          'answered_by_label': 'the candidate',
          'chat_conversation_id': 88,
        },
      ),
    );

    expect(find.text(appText.suchakStateAnsweredBadge), findsWidgets);
    expect(find.text('Candidate interested'), findsWidgets);
    expect(
      find.text(appText.suchakRequestAnsweredByName('the candidate')),
      findsOneWidget,
      reason: 'The member should see who answered, calmly stated.',
    );

    expect(ctaButton(tester, 'Open chat').onPressed, isNotNull);
  });

  testWidgets('suchak_request_closed invites a fresh request', (
    WidgetTester tester,
  ) async {
    await pumpProfile(
      tester,
      contactPayload(
        state: 'suchak_request_closed',
        ctaLabel: 'Send a new request',
        ctaAction: 'send_suchak_request',
        ctaEnabled: true,
        message: 'This request is closed.',
        request: <String, dynamic>{
          'id': 501,
          'status': 'expired',
          'status_label': 'Expired',
        },
      ),
    );

    expect(find.text(appText.suchakStateClosedBadge), findsWidgets);
    expect(find.text('This request is closed.'), findsOneWidget);

    expect(
      ctaButton(tester, 'Send a new request').onPressed,
      isNotNull,
      reason: 'A closed request is the moment the member may ask again.',
    );
  });

  testWidgets(
    'coming back to the screen re-reads the contact state instead of holding '
    'the one it opened with',
    (WidgetTester tester) async {
      // Opened while nobody had asked yet.
      await pumpProfile(
        tester,
        contactPayload(
          state: 'suchak_request_available',
          ctaLabel: 'Request through Suchak',
          ctaAction: 'send_suchak_request',
          ctaEnabled: true,
          message: 'A Suchak manages this profile.',
        ),
      );

      expect(find.text('Request through Suchak'), findsOneWidget);

      // Meanwhile the Suchak answers. The server now returns a different
      // contact state for the same profile.
      http.onJson(
        '/matrimony-profiles/$profileId',
        profileResponse(
          contactPayload(
            state: 'suchak_request_answered',
            ctaLabel: 'Open chat',
            ctaAction: 'open_suchak_chat',
            ctaEnabled: true,
            message: 'The Suchak has answered.',
            canRequest: false,
            request: <String, dynamic>{
              'id': 501,
              'status': 'accepted_by_suchak',
              'status_label': 'Reply received from Suchak',
              'chat_conversation_id': 88,
            },
          ),
        ),
      );

      // The member walks off to another screen and comes back — the exact
      // sequence that used to leave the stale CTA on screen forever.
      final navigator = Navigator.of(
        tester.element(find.byType(ProfileDetailScreen)),
      );
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('somewhere else')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      navigator.pop();
      await tester.pumpAndSettle();

      expect(
        find.text('Open chat'),
        findsOneWidget,
        reason:
            'The route became visible again, so the contact block must come '
            'from a fresh read — not from the response the route opened with.',
      );
      expect(
        find.text('Request through Suchak'),
        findsNothing,
        reason: 'The stale CTA is the defect: it must be gone.',
      );

      // Same guarantee for the other way back onto the screen: resume from
      // background.
      http.onJson(
        '/matrimony-profiles/$profileId',
        profileResponse(
          contactPayload(
            state: 'suchak_request_closed',
            ctaLabel: 'Send a new request',
            ctaAction: 'send_suchak_request',
            ctaEnabled: true,
            message: 'This request is closed.',
            request: <String, dynamic>{
              'id': 501,
              'status': 'expired',
              'status_label': 'Expired',
            },
          ),
        ),
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.text('Send a new request'), findsOneWidget);
      expect(find.text('Open chat'), findsNothing);
    },
  );

  testWidgets('a Marathi member sees no Devanagari digits on the card', (
    WidgetTester tester,
  ) async {
    setAppLanguage(AppLanguage.marathi);

    await pumpProfile(
      tester,
      contactPayload(
        state: 'suchak_request_available',
        ctaLabel: 'सूचक मार्फत विनंती करा',
        ctaAction: 'send_suchak_request',
        ctaEnabled: true,
        message: 'हे स्थळ सूचक सांभाळतात.',
      ),
    );

    // FROZEN workspace rule: every user-facing numeral is Latin 0-9, in any
    // language. The masked Suchak number is the obvious place for this to slip.
    final devanagariDigits = RegExp('[०-९]');
    final offenders = renderedText(
      tester,
    ).where(devanagariDigits.hasMatch).toList();

    expect(offenders, isEmpty, reason: offenders.join('\n'));
    expect(find.text('9822XXXXXX'), findsOneWidget);
  });
}
