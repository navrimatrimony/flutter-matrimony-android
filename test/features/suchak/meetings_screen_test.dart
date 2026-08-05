import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_matrimony_android/core/api_client.dart';
import 'package:flutter_matrimony_android/core/app_language.dart';
import 'package:flutter_matrimony_android/core/app_storage.dart';
import 'package:flutter_matrimony_android/features/suchak/meetings_screen.dart';

import '../../support/fake_http.dart';

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

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SuchakMeetingsScreen()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('renders meetings from U9a payload', (tester) async {
    http.onJson('/suchak-meetings', <String, dynamic>{
      'success': true,
      'data': <String, dynamic>{
        'meetings': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 42,
            'visit_status': 'completed',
            'scheduled_for': '2026-08-01T10:00:00+05:30',
            'suchak_display_name': 'Pawar Vivah Mandal',
          },
        ],
      },
    });

    await pumpScreen(tester);

    expect(find.text('Pawar Vivah Mandal'), findsOneWidget);
    expect(find.text('completed'), findsOneWidget);
  });

  testWidgets('renders honest empty state', (tester) async {
    http.onJson('/suchak-meetings', <String, dynamic>{
      'success': true,
      'data': <String, dynamic>{
        'meetings': <Map<String, dynamic>>[],
      },
    });

    await pumpScreen(tester);

    expect(
      find.text('No meetings have been recorded for you yet.'),
      findsOneWidget,
    );
  });
}
