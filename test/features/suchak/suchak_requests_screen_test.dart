import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_matrimony_android/core/api_client.dart';
import 'package:flutter_matrimony_android/core/app_language.dart';
import 'package:flutter_matrimony_android/core/app_storage.dart';
import 'package:flutter_matrimony_android/features/suchak/suchak_requests_screen.dart';

import '../../support/fake_http.dart';

/// The candidate's own side of the Suchak pipeline.
///
/// Product decision being protected here: the candidate AND their Suchak can
/// both answer the same request, and the FIRST answer wins. The server settles
/// the race and replies HTTP 200 with `code: already_answered` plus who got
/// there first — so losing the race must read as information, never as a
/// failure, and the list must refresh to the real outcome.
void main() {
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

  Map<String, dynamic> receivedRow({
    bool candidateCanAnswer = true,
    String status = 'forwarded_to_candidate',
    String statusLabel = 'Forwarded to candidate',
    String? answeredByLabel,
  }) {
    return <String, dynamic>{
      'id': 501,
      'status': status,
      'status_label': statusLabel,
      'is_open': candidateCanAnswer,
      'message': 'We would like to know more.',
      'created_at': '2026-07-20T09:30:00+05:30',
      'answered_by': answeredByLabel == null ? null : 'suchak',
      'answered_by_label': answeredByLabel,
      'candidate_can_answer': candidateCanAnswer,
      'from_profile': <String, dynamic>{
        'id': 77,
        'name': 'Rohit Deshmukh',
        'age': 29,
        'community': 'Hindu • Maratha',
        'location': 'Pune',
        'profile_photo_url': null,
      },
    };
  }

  Map<String, dynamic> sentRow() {
    return <String, dynamic>{
      'id': 601,
      'status': 'pending',
      'status_label': 'Request pending',
      'message': 'Please share more detail.',
      'created_at': '2026-07-22T11:00:00+05:30',
      'chat_conversation_id': null,
      'target_profile_id': 4242,
      'suchak': <String, dynamic>{
        'representation_id': 71,
        'name': 'Pawar Vivah Mandal',
        'subtitle': 'Experienced marriage facilitator',
        'initial': 'P',
        'photo_url': null,
        'masked_phone': '9822XXXXXX',
      },
    };
  }

  Map<String, dynamic> listResponse({
    List<Map<String, dynamic>>? received,
    List<Map<String, dynamic>>? sent,
  }) {
    return <String, dynamic>{
      'success': true,
      'data': <String, dynamic>{
        'sent': sent ?? <Map<String, dynamic>>[],
        'received': received ?? <Map<String, dynamic>>[],
        'decision_options': <Map<String, dynamic>>[
          <String, dynamic>{'key': 'interested', 'label': 'Interested'},
          <String, dynamic>{
            'key': 'not_interested',
            'label': 'Not interested',
          },
        ],
      },
    };
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SuchakRequestsScreen()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('a request waiting on the candidate offers both answers', (
    WidgetTester tester,
  ) async {
    http.onJson(
      '/suchak-requests',
      listResponse(received: <Map<String, dynamic>>[receivedRow()]),
    );

    await pumpScreen(tester);

    expect(find.text('Rohit Deshmukh'), findsOneWidget);
    expect(find.text('29 • Hindu • Maratha • Pune'), findsOneWidget);
    expect(find.text('Forwarded to candidate'), findsOneWidget);
    expect(find.text('We would like to know more.'), findsOneWidget);
    // Server labels win; the ARB fallbacks only cover a missing payload.
    expect(find.text('Interested'), findsOneWidget);
    expect(find.text('Not interested'), findsOneWidget);
  });

  testWidgets('answering posts the decision to the decision endpoint', (
    WidgetTester tester,
  ) async {
    http.onJson(
      '/suchak-requests',
      listResponse(received: <Map<String, dynamic>>[receivedRow()]),
    );
    http.onJson('/suchak-requests/501/decision', <String, dynamic>{
      'success': true,
      'code': 'decision_recorded',
      'message': 'Your answer has been recorded.',
      'data': <String, dynamic>{
        'already_answered': false,
        'answered_by': 'candidate',
        'answered_by_label': 'the candidate',
        'suchak_request': <String, dynamic>{'id': 501},
      },
    });

    await pumpScreen(tester);

    await tester.tap(find.text('Interested'));
    await tester.pumpAndSettle();

    // First answer wins, so the choice is confirmed before it is sent.
    expect(find.text(appText.suchakRequestConfirmTitle), findsOneWidget);
    await tester.tap(find.text(appText.yes));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final posted = http.requestFor('/suchak-requests/501/decision');
    expect(posted, isNotNull);
    expect(posted!.jsonBody['decision'], 'interested');
    expect(find.text('Your answer has been recorded.'), findsOneWidget);
  });

  testWidgets('losing the race renders calmly, naming who answered first', (
    WidgetTester tester,
  ) async {
    // First load: the request is still answerable from this member's side.
    http.onJson(
      '/suchak-requests',
      listResponse(received: <Map<String, dynamic>>[receivedRow()]),
    );
    // The Suchak answered in the meantime. HTTP 200, not an error.
    http.onJson('/suchak-requests/501/decision', <String, dynamic>{
      'success': true,
      'code': 'already_answered',
      'message': 'This request was already answered by the Suchak.',
      'data': <String, dynamic>{
        'already_answered': true,
        'answered_by': 'suchak',
        'answered_by_label': 'the Suchak',
        'answered_at': '2026-07-23T10:00:00+05:30',
        'suchak_request': <String, dynamic>{'id': 501},
      },
    });

    await pumpScreen(tester);

    // The refresh that follows the answer must land on the settled outcome,
    // so the list route starts returning it from here on.
    http.onJson(
      '/suchak-requests',
      listResponse(
        received: <Map<String, dynamic>>[
          receivedRow(
            candidateCanAnswer: false,
            status: 'candidate_interested',
            statusLabel: 'Candidate interested',
            answeredByLabel: 'the Suchak',
          ),
        ],
      ),
    );

    await tester.tap(find.text('Interested'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(appText.yes));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(
      snackBar.backgroundColor,
      isNot(Colors.red),
      reason: 'Somebody answering first is the system working, not a failure.',
    );
    expect(
      find.text('This request was already answered by the Suchak.'),
      findsOneWidget,
    );

    // ...and the list has reloaded, so the buttons give way to the real
    // outcome instead of inviting a second answer.
    expect(find.text('Candidate interested'), findsOneWidget);
    expect(
      find.text(appText.suchakRequestAnsweredByName('the Suchak')),
      findsOneWidget,
    );
    expect(find.text('Interested'), findsNothing);
    expect(find.text('Not interested'), findsNothing);
  });

  testWidgets('the sent tab shows the Suchak a request went to', (
    WidgetTester tester,
  ) async {
    http.onJson(
      '/suchak-requests',
      listResponse(sent: <Map<String, dynamic>>[sentRow()]),
    );

    await pumpScreen(tester);
    await tester.tap(find.text(appText.tabSent));
    await tester.pumpAndSettle();

    expect(find.text('Pawar Vivah Mandal'), findsOneWidget);
    expect(find.text('Experienced marriage facilitator'), findsOneWidget);
    expect(find.text('Request pending'), findsOneWidget);
    expect(find.text('Please share more detail.'), findsOneWidget);
    expect(find.text(appText.suchakRequestSentOnDate('2026-07-22')), findsOneWidget);
  });

  testWidgets('an empty inbox reads as empty, not as an error', (
    WidgetTester tester,
  ) async {
    http.onJson('/suchak-requests', listResponse());

    await pumpScreen(tester);

    expect(find.text(appText.noReceivedSuchakRequests), findsOneWidget);
    expect(find.text(appText.suchakRequestsDidNotLoad), findsNothing);
  });

  testWidgets('a Marathi member sees no Devanagari digits in the inbox', (
    WidgetTester tester,
  ) async {
    setAppLanguage(AppLanguage.marathi);
    http.onJson(
      '/suchak-requests',
      listResponse(received: <Map<String, dynamic>>[receivedRow()]),
    );

    await pumpScreen(tester);

    // FROZEN workspace rule: ages, counts and dates stay Latin 0-9 in Marathi.
    final devanagariDigits = RegExp('[०-९]');
    final offenders = <String>[];
    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      final value = text.data;
      if (value != null && devanagariDigits.hasMatch(value)) {
        offenders.add(value);
      }
    }
    for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
      final value = rich.text.toPlainText();
      if (devanagariDigits.hasMatch(value)) offenders.add(value);
    }

    expect(offenders, isEmpty, reason: offenders.join('\n'));
    expect(find.text('29 • Hindu • Maratha • Pune'), findsOneWidget);
    expect(
      find.text(appText.suchakRequestAskedOnDate('2026-07-20')),
      findsOneWidget,
    );
  });
}
