import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_matrimony_android/core/profile_card_hero.dart';

/// Covers the rules in the browse -> detail flight that fail silently rather
/// than loudly: a card that must not fly, a locked photo that must not be
/// revealed on the way out, and text that must settle rather than snap.
void main() {
  group('ProfileCardHeroTags', () {
    const url = 'https://example.test/a.webp';

    test('scopes the tags by rendered position, not by profile', () {
      final first = ProfileCardHeroTags.of(
        profileId: 7,
        scope: 'nearby:0',
        photoUrl: url,
      );
      final second = ProfileCardHeroTags.of(
        profileId: 7,
        scope: 'you_may_like:3',
        photoUrl: url,
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

    test('gives the photo and the text on it different tags', () {
      final tags = ProfileCardHeroTags.of(
        profileId: 7,
        scope: 'nearby:0',
        photoUrl: url,
      )!;

      expect(
        tags.photo,
        isNot(tags.identity),
        reason:
            'One card wraps both, inside the same subtree. Equal tags would be '
            'the same crash a bare profile-id tag causes.',
      );
    });

    test('refuses tags when there is no rendered position to fly from', () {
      expect(
        ProfileCardHeroTags.of(
          profileId: null,
          scope: 'nearby:0',
          photoUrl: url,
        ),
        isNull,
      );
      expect(
        ProfileCardHeroTags.of(profileId: 7, scope: null, photoUrl: url),
        isNull,
      );
    });

    test('withholds only the photo tag when the profile has no photo', () {
      final tags = ProfileCardHeroTags.of(
        profileId: 7,
        scope: 'nearby:0',
        photoUrl: null,
      );

      expect(tags, isNotNull);
      expect(
        tags!.photo,
        isNull,
        reason:
            'The two screens draw two different "no photo yet" placeholders, '
            'so there is nothing to fly between them.',
      );
      expect(
        tags.identity,
        isNotNull,
        reason:
            'The block of words is drawn on the placeholder just as it is on a '
            'photo, and it has somewhere to land, so a missing photo must not '
            'cancel the text flight as well.',
      );
    });
  });

  testWidgets('a null tag renders the photo with no Hero at all', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: ProfilePhotoHero(tag: null, child: Text('photo'))),
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

  testWidgets('a null tag renders the name with no Hero at all', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ProfileIdentityHero(
          tag: null,
          title: 'Asha, 27',
          titleStyle: TextStyle(fontSize: 28),
          child: Text('Asha, 27'),
        ),
      ),
    );

    expect(find.text('Asha, 27'), findsOneWidget);
    expect(find.byType(Hero), findsNothing);
  });

  group('photo flight', () {
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

  group('identity flight', () {
    const tag = 'profile-identity:7@nearby:0';
    const cardTitleSize = 28.0;
    const headerTitleSize = 44.0;

    Future<void> pumpFlightApp(
      WidgetTester tester, {
      String cardTitle = 'Asha, 27',
      String headerTitle = 'Asha, 27',
      bool headerVerified = false,
      List<String> cardLines = const ['Pune'],
      List<String> headerLines = const ['Pune'],
      List<String> cardChips = const [],
      List<String> headerChips = const [],
    }) async {
      Widget end({
        required String title,
        required double size,
        required List<String> lineTexts,
        required List<String> chipTexts,
        Widget? trailing,
      }) {
        final style = TextStyle(fontSize: size, fontWeight: FontWeight.w800);
        const lineStyle = TextStyle(fontSize: 15);
        final lines = [
          for (final text in lineTexts)
            ProfileIdentityLine(text: text, style: lineStyle, gap: 8),
        ];
        final chips = [for (final text in chipTexts) Text(text)];

        return ProfileIdentityHero(
          tag: tag,
          title: title,
          titleStyle: style,
          trailing: trailing,
          lines: lines,
          chips: chips,
          chipsGap: 10,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Flexible(child: Text(title, style: style)),
                  if (trailing != null) trailing,
                ],
              ),
              for (final line in lines) ...[
                SizedBox(height: line.gap),
                Text(line.text, style: line.style),
              ],
              if (chips.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(children: chips),
              ],
            ],
          ),
        );
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  end(
                    title: cardTitle,
                    size: cardTitleSize,
                    lineTexts: cardLines,
                    chipTexts: cardChips,
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => Scaffold(
                          body: end(
                            title: headerTitle,
                            size: headerTitleSize,
                            lineTexts: headerLines,
                            chipTexts: headerChips,
                            trailing: headerVerified
                                ? const Icon(Icons.verified)
                                : null,
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
      );
    }

    testWidgets('the name grows with the photo and settles at header size', (
      tester,
    ) async {
      await pumpFlightApp(tester);

      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 140));

      final inFlight = tester.widget<Text>(find.text('Asha, 27')).style;
      expect(
        inFlight?.fontSize,
        allOf(greaterThan(cardTitleSize), lessThan(headerTitleSize)),
        reason:
            'Only the photo moving and the name cutting is the complaint this '
            'exists to answer: the words have to be part-way through their own '
            'change of size while the photo is part-way through its flight.',
      );

      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.text('Asha, 27')).style?.fontSize,
        headerTitleSize,
        reason: 'Landing on a different size than the shuttle ended at snaps.',
      );
    });

    testWidgets('the words never change in mid-air', (tester) async {
      await pumpFlightApp(tester, headerTitle: 'Asha Patil, 27');

      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 140));

      expect(find.text('Asha, 27'), findsOneWidget);
      expect(
        find.text('Asha Patil, 27'),
        findsNothing,
        reason:
            'The shuttle carries the words of the end being left behind, so a '
            'surface that words the headline differently changes it on landing '
            'rather than part-way through the animation.',
      );

      await tester.pumpAndSettle();
    });

    testWidgets('every line of the block flies, not just the headline', (
      tester,
    ) async {
      await pumpFlightApp(
        tester,
        cardLines: const ['5\'7" • Hindu, Maratha', 'B.Sc. (Agri.)', 'Pune'],
        headerLines: const ['5\'7" • Hindu, Maratha', 'B.Sc. (Agri.)', 'Pune'],
        cardChips: const ['You & her'],
        headerChips: const ['You & her'],
      );

      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 140));

      // Two of each: the outgoing card still painted underneath, plus the copy
      // the shuttle is carrying. The point is that none of them is missing.
      for (final line in const [
        '5\'7" • Hindu, Maratha',
        'B.Sc. (Agri.)',
        'Pune',
        'You & her',
      ]) {
        expect(
          find.text(line),
          findsWidgets,
          reason:
              'The member tapped a card with this line on it. Leaving it behind '
              'is the "photo moves, caption is swapped" complaint.',
        );
      }

      await tester.pumpAndSettle();
    });

    testWidgets('a line the destination lacks fades out instead of gapping', (
      tester,
    ) async {
      await pumpFlightApp(
        tester,
        cardLines: const ['Pune', 'B.Sc. (Agri.)'],
        headerLines: const ['Pune'],
      );

      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 140));

      final fade = tester.widget<Opacity>(
        find
            .ancestor(
              of: find.text('B.Sc. (Agri.)'),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(
        fade.opacity,
        allOf(greaterThan(0.0), lessThan(1.0)),
        reason:
            'Not every profile fills every line. One that stops short has to '
            'shrink away over the flight rather than blink out at the hand-off.',
      );

      await tester.pumpAndSettle();
    });

    testWidgets('a tick only the detail screen has fades in as it flies', (
      tester,
    ) async {
      await pumpFlightApp(tester, headerVerified: true);

      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 140));

      final fade = tester.widget<Opacity>(
        find
            .ancestor(
              of: find.byIcon(Icons.verified),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(fade.opacity, allOf(greaterThan(0.0), lessThan(1.0)));

      await tester.pumpAndSettle();
    });
  });
}
