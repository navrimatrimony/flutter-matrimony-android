import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_matrimony_android/core/locked_teaser.dart';

/// The teaser payload is a privacy instruction from the admin, so the two rules
/// worth pinning are: every strength the server can emit resolves to its own
/// blur, and nothing the server can emit ever resolves to "no blur".
void main() {
  /// `WhoViewedTeaserPresenter::blurTailwindClasses` — who viewed me and
  /// received interests.
  const whoViewedClasses = <String, String>{
    'light': 'blur-sm scale-105 opacity-95',
    'soft': 'blur-[3px] scale-105 opacity-95',
    'gentle': 'blur-[6px] scale-110 opacity-93',
    'medium': 'blur-md scale-110 opacity-90',
    'strong': 'blur-2xl scale-125 opacity-[0.88]',
  };

  /// `ChatTeaserPolicy::blurClass` — locked chat rows.
  const chatClasses = <String, String>{
    'light': 'blur-[1px]',
    'soft': 'blur-[2px]',
    'gentle': 'blur-[3px]',
    'medium': 'blur-[4px]',
    'strong': 'blur-[6px]',
  };

  group('blur strength', () {
    test('each who-viewed strength gets its own sigma', () {
      final sigmas = whoViewedClasses.map(
        (strength, css) => MapEntry(strength, LockedTeaser.blurSigmaForClass(css)),
      );

      expect(sigmas['light'], 4);
      expect(sigmas['soft'], 3);
      expect(sigmas['gentle'], 6);
      expect(sigmas['medium'], 10);
      expect(sigmas['strong'], 18);
    });

    test('each chat strength gets its own sigma', () {
      // These four used to fall through to the medium default, so light and
      // strong rendered identically.
      expect(LockedTeaser.blurSigmaForClass(chatClasses['light']!), 1);
      expect(LockedTeaser.blurSigmaForClass(chatClasses['soft']!), 2);
      expect(LockedTeaser.blurSigmaForClass(chatClasses['gentle']!), 3);
      expect(LockedTeaser.blurSigmaForClass(chatClasses['medium']!), 4);
      expect(LockedTeaser.blurSigmaForClass(chatClasses['strong']!), 6);
    });

    test('stronger admin settings never blur less', () {
      for (final classes in <Map<String, String>>[whoViewedClasses, chatClasses]) {
        final ordered = <String>['light', 'soft', 'gentle', 'medium', 'strong']
            .map((strength) => LockedTeaser.blurSigmaForClass(classes[strength]!))
            .toList();

        // `soft` is the one inversion the server itself ships (who-viewed
        // light is blur-sm = 4px, soft is 3px), so compare the rest.
        expect(ordered[2], lessThanOrEqualTo(ordered[3]));
        expect(ordered[3], lessThanOrEqualTo(ordered[4]));
      }
    });

    test('an unreadable class fails safe to blurred, never clear', () {
      for (final unknown in <String>[
        '',
        'scale-110 opacity-90',
        'blur-none',
        'blur-[0px]',
        'totally-unexpected',
      ]) {
        expect(
          LockedTeaser.blurSigmaForClass(unknown),
          LockedTeaser.defaultBlurSigma,
          reason: 'class "$unknown" must not render the photo unblurred',
        );
      }
    });

    test('named Tailwind utilities outside the current five still resolve', () {
      expect(LockedTeaser.blurSigmaForClass('blur'), greaterThan(6));
      expect(LockedTeaser.blurSigmaForClass('blur-lg'), greaterThan(10));
      expect(LockedTeaser.blurSigmaForClass('blur-xl'), greaterThan(11));
      expect(LockedTeaser.blurSigmaForClass('blur-3xl'), greaterThan(18));
    });
  });

  group('scale and opacity', () {
    test('scale and opacity tokens are honoured', () {
      expect(LockedTeaser.photoScaleForClass('blur-2xl scale-125'), 1.25);
      expect(LockedTeaser.photoScaleForClass('blur-md scale-110'), 1.10);
      expect(LockedTeaser.photoScaleForClass('blur-sm scale-105'), 1.05);
      expect(
        LockedTeaser.photoOpacityForClass('blur-2xl scale-125 opacity-[0.88]'),
        closeTo(0.88, 0.001),
      );
      expect(
        LockedTeaser.photoOpacityForClass('blur-[6px] scale-110 opacity-93'),
        closeTo(0.93, 0.001),
      );
    });

    test('a class without those tokens keeps the defaults', () {
      expect(
        LockedTeaser.photoScaleForClass('blur-[4px]'),
        LockedTeaser.defaultPhotoScale,
      );
      expect(LockedTeaser.photoOpacityForClass('blur-[4px]'), 1);
    });
  });

  group('what the server withholds stays withheld', () {
    Map<String, dynamic> payload({
      String avatarStyle = 'blur',
      String? photoUrl = 'https://example.test/photos/a.jpg',
    }) {
      return <String, dynamic>{
        'headline': 'A girl from Khanapur',
        'lines': <String>['Khanapur / Sangli', '26 years', 'Never married'],
        'viewed_summary': 'Interest received 2 hours ago',
        'photo_url': photoUrl,
        'avatar_style': avatarStyle,
        'blur_photo_class': 'blur-2xl scale-125 opacity-[0.88]',
        'accent_line': null,
        'match_line': '82% match',
        'interest_hint': 'She may be waiting for your interest',
      };
    }

    test('a blur teaser with a photo renders it', () {
      final teaser = LockedTeaser.fromJson(payload())!;

      expect(teaser.hasPhoto, isTrue);
      expect(teaser.blurSigma, 18);
    });

    test('avatar_style silhouette hides the photo even when a url is sent', () {
      final teaser =
          LockedTeaser.fromJson(payload(avatarStyle: 'silhouette'))!;

      expect(teaser.hasPhoto, isFalse);
    });

    test('an unknown avatar style is treated as silhouette', () {
      final teaser = LockedTeaser.fromJson(payload(avatarStyle: 'sneaky'))!;

      expect(teaser.hasPhoto, isFalse);
    });

    test('a withheld photo_url renders nothing', () {
      final teaser = LockedTeaser.fromJson(payload(photoUrl: null))!;

      expect(teaser.hasPhoto, isFalse);
    });

    test("the server's own svg placeholder is not treated as a photo", () {
      final teaser = LockedTeaser.fromJson(
        payload(
          photoUrl: 'https://example.test/images/placeholders/female-profile.svg',
        ),
      )!;

      expect(teaser.hasPhoto, isFalse);
    });

    test('omitted lines stay omitted', () {
      final teaser = LockedTeaser.fromJson(<String, dynamic>{
        'headline': 'A girl from Khanapur',
        'lines': <String>[],
        'avatar_style': 'silhouette',
      })!;

      expect(teaser.lines, isEmpty);
      expect(teaser.accentLine, isNull);
      expect(teaser.matchLine, isNull);
      expect(teaser.accentAndMatchLine, isNull);
      expect(teaser.viewedSummary, isNull);
    });

    test('no teaser block means no teaser', () {
      expect(LockedTeaser.fromJson(null), isNull);
      expect(LockedTeaser.fromJson(<String, dynamic>{}), isNull);
      expect(LockedTeaser.fromJson('nonsense'), isNull);
    });

    test('a default teaser shows nothing at all', () {
      const teaser = LockedTeaser();

      expect(teaser.hasPhoto, isFalse);
      expect(teaser.wantsBlurredPhoto, isFalse);
      expect(teaser.headline, isNull);
    });
  });

  group('what the shared card actually paints', () {
    testWidgets('a withheld photo draws the person stand-in and the lock, '
        'never an image', (tester) async {
      const teaser = LockedTeaser(headline: 'A girl from Khanapur');

      await tester.pumpWidget(host(const LockedTeaserPhotoFrame(teaser: teaser)));

      expect(find.byType(LockedTeaserSilhouette), findsOneWidget);
      expect(find.byType(LockedTeaserLockBadge), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('an unknown avatar style still refuses to draw the photo',
        (tester) async {
      final teaser = LockedTeaser.fromJson(<String, dynamic>{
        'headline': 'A girl from Khanapur',
        'avatar_style': 'sneaky',
        'photo_url': 'https://example.test/photos/a.jpg',
      })!;

      await tester.pumpWidget(host(LockedTeaserPhotoFrame(teaser: teaser)));

      expect(find.byType(Image), findsNothing);
      expect(find.byType(LockedTeaserSilhouette), findsOneWidget);
    });

    testWidgets('attributes read as one scannable line and the curiosity '
        'lines are drawn apart from it', (tester) async {
      final teaser = LockedTeaser.fromJson(<String, dynamic>{
        'lines': <String>['Khanapur', '22 years', 'Never married'],
        'accent_line': 'Viewed your profile 4 times',
        'match_line': '82% match',
        'avatar_style': 'silhouette',
      })!;

      await tester.pumpWidget(host(LockedTeaserLines(teaser: teaser)));

      expect(find.text('Khanapur · 22 years · Never married'), findsOneWidget);
      expect(find.text('Viewed your profile 4 times'), findsOneWidget);
      expect(find.text('82% match'), findsOneWidget);
    });

    testWidgets('a surface whose headline already carries the repeat count '
        'can drop the accent without losing the match line', (tester) async {
      final teaser = LockedTeaser.fromJson(<String, dynamic>{
        'accent_line': 'Viewed your profile 4 times',
        'match_line': '82% match',
        'avatar_style': 'silhouette',
      })!;

      await tester.pumpWidget(
        host(LockedTeaserLines(teaser: teaser, showAccent: false)),
      );

      expect(find.text('Viewed your profile 4 times'), findsNothing);
      expect(find.text('82% match'), findsOneWidget);
    });
  });

  group('a real production payload is rendered as sent', () {
    /// The teaser blob read straight off a production notification row, kept
    /// verbatim — trailing comma, SVG placeholder and all. The phone used to
    /// rebuild this headline into a sentence of its own ("Kurhani मधील वधूने
    /// तुमचे प्रोफाइल पाहिले.") and to show a formatted `created_at` instead of
    /// `viewed_summary`, which threw away both `name_display` and
    /// `teaser_viewed_time`.
    Map<String, dynamic> productionRow() {
      return <String, dynamic>{
        'headline': 'Kurhani तालुका हून एक स्त्री,',
        'lines': <String>['Kurhani / Muzaffarpur / Bihar', '27 वर्षे'],
        'viewed_summary': 'पाहिले: 2 तासांपूर्वी',
        'photo_url':
            'https://navrimilenavryala.com/images/placeholders/female-profile.svg',
        'avatar_style': 'blur',
        'blur_photo_class': 'blur-md scale-110 opacity-90',
        'accent_line': null,
        'match_line': null,
        'interest_hint': 'ही महिला तुमच्या प्रोफाइलमध्ये interested असू शकते.',
      };
    }

    test("the server's own SVG placeholder is ruled out before any request", () {
      final teaser = LockedTeaser.fromJson(productionRow())!;

      // The admin did ask for a blurred photo — there just is not one to blur.
      expect(teaser.wantsBlurredPhoto, isTrue);
      expect(teaser.renderablePhotoUrl, isNull);
      expect(teaser.hasPhoto, isFalse);
      // And the strength is still read, so a real photo on the next row blurs.
      expect(teaser.blurSigma, 10);
    });

    testWidgets('so the card draws the stand-in rather than attempting the '
        'placeholder and failing', (tester) async {
      final teaser = LockedTeaser.fromJson(productionRow())!;

      await tester.pumpWidget(host(LockedTeaserPhotoFrame(teaser: teaser)));

      // No Image widget means no network round trip and no error flash.
      expect(find.byType(Image), findsNothing);
      expect(find.byType(LockedTeaserSilhouette), findsOneWidget);
    });

    testWidgets('the headline is drawn exactly as sent, trailing comma and all',
        (tester) async {
      final teaser = LockedTeaser.fromJson(productionRow())!;

      await tester.pumpWidget(
        host(LockedTeaserHeadline(text: teaser.headline!)),
      );

      expect(find.text('Kurhani तालुका हून एक स्त्री,'), findsOneWidget);
    });

    testWidgets('the attribute lines keep the location string the server '
        'resolved', (tester) async {
      final teaser = LockedTeaser.fromJson(productionRow())!;

      await tester.pumpWidget(
        host(LockedTeaserLines(teaser: teaser, showInterestHint: true)),
      );

      expect(
        find.text('Kurhani / Muzaffarpur / Bihar · 27 वर्षे'),
        findsOneWidget,
      );
      expect(find.text('पाहिले: 2 तासांपूर्वी'), findsOneWidget);
      expect(
        find.text('ही महिला तुमच्या प्रोफाइलमध्ये interested असू शकते.'),
        findsOneWidget,
      );
    });

    testWidgets('once the same row carries repeat views and a match, both '
        'become their own pills', (tester) async {
      final teaser = LockedTeaser.fromJson(<String, dynamic>{
        ...productionRow(),
        'accent_line': 'तुमची प्रोफाइल 4 वेळा पाहिली',
        'match_line': '82% जुळणी',
      })!;

      await tester.pumpWidget(host(LockedTeaserLines(teaser: teaser)));

      expect(find.byType(LockedTeaserAccentRow), findsOneWidget);
      expect(find.text('तुमची प्रोफाइल 4 वेळा पाहिली'), findsOneWidget);
      expect(find.text('82% जुळणी'), findsOneWidget);
      // The curiosity lines are their own pills, never folded into the
      // attribute row or the headline.
      expect(
        find.text('Kurhani / Muzaffarpur / Bihar · 27 वर्षे'),
        findsOneWidget,
      );
    });

    testWidgets('the compact pill used by the narrow tile still says both',
        (tester) async {
      final teaser = LockedTeaser.fromJson(<String, dynamic>{
        ...productionRow(),
        'accent_line': 'तुमची प्रोफाइल 4 वेळा पाहिली',
        'match_line': '82% जुळणी',
      })!;

      await tester.pumpWidget(
        host(LockedTeaserAccentRow(teaser: teaser, compact: true)),
      );

      expect(
        find.text('तुमची प्रोफाइल 4 वेळा पाहिली · 82% जुळणी'),
        findsOneWidget,
      );
    });
  });
}

Widget host(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Center(child: SizedBox(width: 180, height: 260, child: child)),
    ),
  );
}
