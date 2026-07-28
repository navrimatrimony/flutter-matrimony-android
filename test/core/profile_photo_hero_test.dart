import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_matrimony_android/core/profile_photo_hero.dart';

/// Covers the two rules in [ProfilePhotoHero] that fail silently rather than
/// loudly: a photo that must not fly, and a locked photo that must not be
/// revealed on the way out.
void main() {
  group('tagFor', () {
    test('scopes the tag by rendered position, not by profile', () {
      final first = ProfilePhotoHero.tagFor(
        profileId: 7,
        scope: 'nearby:0',
        photoUrl: 'https://example.test/a.webp',
      );
      final second = ProfilePhotoHero.tagFor(
        profileId: 7,
        scope: 'you_may_like:3',
        photoUrl: 'https://example.test/a.webp',
      );

      expect(first, isNotNull);
      expect(
        first,
        isNot(second),
        reason:
            'The same profile is drawn in several sections of the More tab at '
            'once. Sharing one tag throws "multiple heroes that share the same '
            'tag" and blanks the screen.',
      );
    });

    test('refuses a tag when anything needed for a flight is missing', () {
      const url = 'https://example.test/a.webp';

      expect(
        ProfilePhotoHero.tagFor(profileId: null, scope: 'nearby:0', photoUrl: url),
        isNull,
      );
      expect(
        ProfilePhotoHero.tagFor(profileId: 7, scope: null, photoUrl: url),
        isNull,
      );
      expect(
        ProfilePhotoHero.tagFor(profileId: 7, scope: 'nearby:0', photoUrl: null),
        isNull,
        reason:
            'A card showing the placeholder has no photo to fly, so it must '
            'not claim the tag its photo would have used.',
      );
    });
  });

  testWidgets('a null tag renders the photo with no Hero at all', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ProfilePhotoHero(tag: null, child: Text('photo')),
      ),
    );

    expect(find.text('photo'), findsOneWidget);
    expect(
      find.byType(Hero),
      findsNothing,
      reason:
          'Opening the detail screen from a push notification has no source '
          'photo, so it must cut in normally rather than half-fly.',
    );
  });

  group('flight', () {
    const tag = 'profile-photo:7@nearby:0';

    Future<void> pumpFlightApp(
      WidgetTester tester, {
      required double? detailBlurSigma,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 60,
                      height: 60,
                      child: ProfilePhotoHero(
                        tag: tag,
                        child: ColoredBox(color: Color(0xFF112233)),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => Scaffold(
                            body: ProfilePhotoHero(
                              tag: tag,
                              blurSigma: detailBlurSigma,
                              child: const ColoredBox(color: Color(0xFF445566)),
                            ),
                          ),
                        ),
                      ),
                      child: const Text('open'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('an unlocked photo flies with no blur imposed on it', (
      tester,
    ) async {
      await pumpFlightApp(tester, detailBlurSigma: null);

      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      expect(find.byType(ImageFiltered), findsNothing);

      await tester.pumpAndSettle();
    });

    testWidgets('a locked photo stays blurred while it flies back to the list', (
      tester,
    ) async {
      await pumpFlightApp(tester, detailBlurSigma: 18);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      expect(
        find.byType(ImageFiltered),
        findsWidgets,
        reason:
            'The list copy of this photo is clear, so a shuttle that took the '
            'destination end would un-blur a paywalled photo at header size '
            'for the whole way out.',
      );

      await tester.pumpAndSettle();
    });
  });
}
