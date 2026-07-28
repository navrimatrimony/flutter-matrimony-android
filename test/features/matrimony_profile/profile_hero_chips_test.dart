import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_matrimony_android/core/api_client.dart';
import 'package:flutter_matrimony_android/core/app_language.dart';
import 'package:flutter_matrimony_android/core/app_storage.dart';
import 'package:flutter_matrimony_android/features/matrimony_profile/profile_detail_screen.dart';
import 'package:flutter_matrimony_android/main.dart';

import '../../support/fake_http.dart';

/// The hero chips are built from the server's `display.chips`, whose labels
/// arrive already translated. The client used to identify the comparison chip
/// by its English text ("you &..."), so for a Marathi member the server's own
/// chip went unrecognised and a second, identically worded one was appended —
/// two "तुम्ही आणि ती" pills side by side. These tests pin the fix: chips are
/// identified by the stable `icon` key, never by their words.
void main() {
  const profileId = 4242;
  late FakeHttpOverrides http;

  setUp(() {
    AppStorage.instance = AppStorage.memory();
    setAppLanguage(AppLanguage.marathi);
    ApiClient.authToken = 'test-token';
    ApiClient.currentUserProfile = null;

    http = FakeHttpOverrides();
    final previous = HttpOverrides.current;
    HttpOverrides.global = http;
    addTearDown(() => HttpOverrides.global = previous);
  });

  /// The exact chip list the Laravel presenter emits for a Marathi viewer
  /// looking at a verified, premium, photo-bearing profile with a horoscope.
  List<Map<String, dynamic>> marathiChips() {
    return <Map<String, dynamic>>[
      {'label': 'पडताळणी झालेली', 'icon': 'verified', 'tone': 'trust'},
      {'label': 'प्रीमियम', 'icon': 'premium', 'tone': 'premium'},
      {'label': '3 फोटो', 'icon': 'photo', 'tone': 'neutral'},
      {'label': 'तुम्ही आणि ती', 'icon': 'compare', 'tone': 'dark'},
      {'label': 'ज्योतिष', 'icon': 'astro', 'tone': 'warm'},
    ];
  }

  Map<String, dynamic> comparisonBlock() {
    return <String, dynamic>{
      'enabled': true,
      'title': 'तुम्ही आणि ती',
      'viewer': <String, dynamic>{'name': 'Sneha'},
      'target': <String, dynamic>{'name': 'Asha Patil'},
      'matched_count': 4,
      'total_count': 6,
      'rows': <Map<String, dynamic>>[
        {
          'key': 'age',
          'label': 'वय',
          'status': 'match',
          'viewer_value': '28',
          'target_value': '30',
          'is_counted': true,
        },
      ],
    };
  }

  Future<void> pumpProfile(
    WidgetTester tester, {
    required List<Map<String, dynamic>> chips,
    Map<String, dynamic>? comparison,
  }) async {
    http.onJson('/matrimony-profiles/$profileId', <String, dynamic>{
      'success': true,
      'profile': <String, dynamic>{
        'id': profileId,
        'full_name': 'Asha Patil',
        'date_of_birth': '1996-04-12',
      },
      'display': <String, dynamic>{
        'hero': <String, dynamic>{'name': 'Asha Patil'},
        'chips': chips,
        if (comparison != null) 'comparison': comparison,
      },
    });

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [routeObserver],
        home: const ProfileDetailScreen(profileId: profileId),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('a Marathi member sees the comparison chip exactly once', (
    WidgetTester tester,
  ) async {
    await pumpProfile(
      tester,
      chips: marathiChips(),
      comparison: comparisonBlock(),
    );

    // The comparison card's own heading uses the same words, so count only the
    // chips inside the hero row rather than every occurrence on the screen.
    final chipLabels = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(Wrap),
            matching: find.byType(Text),
          ),
        )
        .map((text) => text.data)
        .whereType<String>()
        .toList();

    expect(
      chipLabels.where((label) => label == 'तुम्ही आणि ती').length,
      1,
      reason: 'The hero row rendered the comparison chip more than once: '
          '$chipLabels',
    );
  });

  testWidgets('verified and premium are not repeated as Marathi chips', (
    WidgetTester tester,
  ) async {
    await pumpProfile(
      tester,
      chips: marathiChips(),
      comparison: comparisonBlock(),
    );

    // Already carried by the tick beside the name and the premium pill.
    expect(find.text('पडताळणी झालेली'), findsNothing);
    expect(find.text('प्रीमियम'), findsNothing);
    expect(find.text('3 फोटो'), findsNothing);
    // The astro chip used to be dropped by the overflow trim that the
    // duplicate comparison chip triggered.
    expect(find.text('ज्योतिष'), findsOneWidget);
  });

  testWidgets('the comparison chip is tappable, the astro chip is not dead', (
    WidgetTester tester,
  ) async {
    await pumpProfile(
      tester,
      chips: marathiChips(),
      comparison: comparisonBlock(),
    );

    final chipTaps = tester
        .widgetList<InkWell>(
          find.descendant(
            of: find.byType(Wrap),
            matching: find.byType(InkWell),
          ),
        )
        .map((inkWell) => inkWell.onTap)
        .toList();

    // Every pill drawn as a button carries a destination. A chip without one
    // is rendered flat instead, so it never reaches this list.
    expect(chipTaps, isNotEmpty);
    expect(chipTaps.every((onTap) => onTap != null), isTrue);
  });

  testWidgets('no comparison card means no comparison chip', (
    WidgetTester tester,
  ) async {
    await pumpProfile(tester, chips: marathiChips());

    expect(find.text('तुम्ही आणि ती'), findsNothing);
    expect(find.text('ज्योतिष'), findsOneWidget);
  });
}
