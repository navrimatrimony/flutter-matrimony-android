import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_matrimony_android/core/api_client.dart';
import 'package:flutter_matrimony_android/core/app_language.dart';
import 'package:flutter_matrimony_android/core/app_storage.dart';
import 'package:flutter_matrimony_android/features/onboarding/steps/family_optional_step.dart';
import 'package:flutter_matrimony_android/features/onboarding/steps/onboarding_step_helpers.dart';

import '../../support/fake_http.dart';

/// Reported from a real device: on the "Family and about" step the member taps
/// the two pill groups above the about box — Family status and Family values —
/// and a moment later both pills are unselected again, without the member
/// touching anything.
///
/// The mechanism is the parent, not the tap. `SmartOnboardingScreen` builds a
/// brand new `List<AboutTemplateSuggestion>` on every single build (see
/// `_aboutTemplateSuggestions()`), and `AboutTemplateSuggestion` carries no
/// value equality, so `listEquals` in `didUpdateWidget` compares object
/// identities and can never be true. Every parent rebuild therefore looked like
/// "the suggestions changed" and re-seeded the whole step from the draft — which
/// does not contain the just-tapped pills yet.
///
/// The parent rebuilds on its own on this step: arriving here runs
/// `_showOnboardingMessage('Saved')`, which parks a 5s timer and then a 1s
/// timer, each calling `setState`. That is the "moments later" the member saw.
///
/// This harness reproduces the parent exactly: a fresh suggestion list and a
/// fresh data map on every build, then an unrelated parent `setState`.
class _ParentHarness extends StatefulWidget {
  const _ParentHarness();

  @override
  State<_ParentHarness> createState() => _ParentHarnessState();
}

class _ParentHarnessState extends State<_ParentHarness> {
  int _unrelatedCounter = 0;
  Map<String, dynamic> _familyDraft = <String, dynamic>{};

  /// What the step handed on to be POSTed to `/onboarding/profile/save-step`.
  Map<String, dynamic>? sentFamilyData;
  String? sentAboutText;

  void rebuildForUnrelatedReason() {
    setState(() => _unrelatedCounter++);
  }

  /// `_loadStatus()` refreshing the server draft mid-step: the map really did
  /// change, but it still predates the member's untouched taps.
  void refreshDraftFromServer(Map<String, dynamic> data) {
    setState(() => _familyDraft = data);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: FamilyOptionalStep(
            // `_draftStepData('family')` hands back a fresh map each build.
            data: Map<String, dynamic>.from(_familyDraft),
            initialAbout: null,
            // `_aboutTemplateSuggestions()` allocates new objects each build.
            // The labels there come from the runtime `appText` getter, so the
            // instances are never const-canonicalised — `.toString()` here
            // reproduces that without pulling in localisations.
            aboutSuggestions: <AboutTemplateSuggestion>[
              AboutTemplateSuggestion(
                label: 'Simple, family first'.toString(),
                text: 'Family means a great deal to me.'.toString(),
              ),
              AboutTemplateSuggestion(
                label: 'Career with balance'.toString(),
                text: 'I take responsibilities seriously.'.toString(),
              ),
            ],
            locale: 'en',
            loading: false,
            onSaveFamilyAbout: (familyData, aboutText) async {
              sentFamilyData = familyData;
              sentAboutText = aboutText;
              return true;
            },
            onBack: () {},
          ),
        ),
      ),
    );
  }
}

bool _pillSelected(WidgetTester tester, String label) {
  final pill = tester.widget<OnboardingSelectablePill>(
    find.widgetWithText(OnboardingSelectablePill, label),
  );
  return pill.selected;
}

void main() {
  late FakeHttpOverrides http;

  setUp(() {
    AppStorage.instance = AppStorage.memory();
    setAppLanguage(AppLanguage.english);
    ApiClient.authToken = null;
    ApiClient.currentUserProfile = null;

    http = FakeHttpOverrides();
    final previous = HttpOverrides.current;
    HttpOverrides.global = http;
    addTearDown(() => HttpOverrides.global = previous);
  });

  testWidgets(
    'family status and family values survive an unrelated parent rebuild',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const _ParentHarness());
      await tester.pump();

      await tester.tap(find.text('Middle Class'));
      await tester.pump();
      await tester.tap(find.text('Traditional'));
      await tester.pump();

      expect(_pillSelected(tester, 'Middle Class'), isTrue);
      expect(_pillSelected(tester, 'Traditional'), isTrue);

      // The "Saved" banner timer firing, a loading flag flipping, anything at
      // all in the parent — the member did not touch the screen.
      final harness = tester.state<_ParentHarnessState>(
        find.byType(_ParentHarness),
      );
      harness.rebuildForUnrelatedReason();
      await tester.pump();

      expect(
        _pillSelected(tester, 'Middle Class'),
        isTrue,
        reason: 'family status must not clear itself on a parent rebuild',
      );
      expect(
        _pillSelected(tester, 'Traditional'),
        isTrue,
        reason: 'family values must not clear itself on a parent rebuild',
      );
    },
  );

  testWidgets('a stale server draft arriving mid-step does not undo the taps', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const _ParentHarness());
    await tester.pump();

    await tester.tap(find.text('Affluent'));
    await tester.pump();

    // `_loadStatus()` lands and genuinely replaces the family draft map, but it
    // was built before the tap, so it still says nothing about family status.
    tester
        .state<_ParentHarnessState>(find.byType(_ParentHarness))
        .refreshDraftFromServer(<String, dynamic>{'brothers_count': 1});
    await tester.pump();

    expect(_pillSelected(tester, 'Affluent'), isTrue);
  });

  testWidgets('the saved payload still carries both keys after a rebuild', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const _ParentHarness());
    await tester.pump();

    await tester.tap(find.text('Upper Middle Class'));
    await tester.pump();
    await tester.tap(find.text('Moderate'));
    await tester.pump();

    final harness = tester.state<_ParentHarnessState>(
      find.byType(_ParentHarness),
    );
    harness.rebuildForUnrelatedReason();
    await tester.pump();

    await tester.tap(find.text('Complete registration'));
    await tester.pump();

    // These are the exact translation keys Laravel exposes at
    // `components.family.status_options` / `values_options` and stores on the
    // profile through MutationService.
    expect(harness.sentFamilyData, <String, dynamic>{
      'family_status': 'upper_middle_class',
      'family_values': 'moderate',
    });
    expect(harness.sentAboutText, isNotEmpty);
  });

  test('AboutTemplateSuggestion compares by value, not identity', () {
    // `listEquals` in `didUpdateWidget` is only meaningful if this holds; the
    // parent allocates a fresh list of fresh instances on every build.
    final a = AboutTemplateSuggestion(
      label: 'Simple'.toString(),
      text: 'Body'.toString(),
    );
    final b = AboutTemplateSuggestion(
      label: 'Simple'.toString(),
      text: 'Body'.toString(),
    );

    expect(identical(a, b), isFalse);
    expect(a, equals(b));
    expect(a.hashCode, equals(b.hashCode));
  });
}
