import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_matrimony_android/core/locked_teaser.dart';
import 'package:flutter_matrimony_android/features/matrimony_profile/profile_album_blur.dart';

/// The admin dial `profile_view_lock_blur_strength` (35–100) reaches the phone
/// as `display.photo_album.blur_photo_class`. Three things are worth pinning:
/// the setting is actually obeyed, moving it up never blurs less, and nothing
/// the server can send — including nothing at all — renders a locked photo
/// clear.
void main() {
  /// `App\Services\Profile\ProfileViewLockBlurPolicy::photoBlurClass()` at the
  /// two ends of the dial and at the shipped default.
  const atMinimum = 'blur-[12px] scale-105 opacity-100';
  const atDefault = 'blur-[40px] scale-105 opacity-100';
  const atMaximum = 'blur-[64px] scale-105 opacity-100';

  Map<String, dynamic> album(Object? blurPhotoClass) {
    return <String, dynamic>{
      'slots': <Map<String, dynamic>>[
        <String, dynamic>{'url': 'https://example.test/a.jpg', 'blur': false},
        <String, dynamic>{'url': 'https://example.test/b.jpg', 'blur': true},
      ],
      'message_key': 'profile.photos_upgrade_to_view_all',
      'message': 'Upgrade to view all photos',
      'tier': 'free_own_photo',
      'photo_count': 2,
      'primary_photo_url': 'https://example.test/a.jpg',
      'has_locked_photos': true,
      if (blurPhotoClass != null) 'blur_photo_class': blurPhotoClass,
    };
  }

  /// `ImageFilter` exposes no sigma getter but compares by value, so the filter
  /// the widgets actually receive is checked against a rebuilt one.
  Matcher blursAt(double sigma) =>
      equals(ImageFilter.blur(sigmaX: sigma, sigmaY: sigma));

  group('the admin dial is what the album renders', () {
    test('the default dial keeps exactly the sigma the app shipped', () {
      // 78 → blur-[40px] → 18 through the app's existing css-px→sigma curve,
      // which is the constant every locked album surface used to hardcode.
      expect(ProfileAlbumBlur.fromAlbum(album(atDefault)).sigma, 18);
      expect(ProfileAlbumBlur.fromAlbum(album(atDefault)).sigma,
          ProfileAlbumBlur.fallbackSigma);
    });

    test('a stronger dial actually blurs more, a weaker one blurs less', () {
      final minimum = ProfileAlbumBlur.fromAlbum(album(atMinimum)).sigma;
      final byDefault = ProfileAlbumBlur.fromAlbum(album(atDefault)).sigma;
      final maximum = ProfileAlbumBlur.fromAlbum(album(atMaximum)).sigma;

      expect(minimum, lessThan(byDefault));
      expect(byDefault, lessThan(maximum));
      // And the whole range stays a real blur — the dial cannot reach clear.
      expect(minimum, greaterThan(0));
    });

    test('the sigma comes from the shared parser, not a second reading', () {
      expect(
        ProfileAlbumBlur.fromAlbum(album(atMaximum)).sigma,
        LockedTeaser.blurSigmaForClass(atMaximum),
      );
    });
  });

  group('a payload with no readable strength still hides the photo', () {
    test('a missing field, an empty one or a wrong type fall back blurred', () {
      for (final absent in <Object?>[null, '', '   ', 42, <String>[]]) {
        final blur = ProfileAlbumBlur.fromAlbum(album(absent));

        expect(
          blur.sigma,
          ProfileAlbumBlur.fallbackSigma,
          reason: 'blur_photo_class "$absent" must not render a locked photo '
              'weaker than the app already did',
        );
      }
    });

    test('no album block at all still blurs', () {
      expect(
        ProfileAlbumBlur.fromAlbum(null).sigma,
        ProfileAlbumBlur.fallbackSigma,
      );
    });

    test('a class the parser cannot read never resolves to clear', () {
      for (final garbage in <String>[
        'totally-unexpected',
        'scale-105 opacity-100',
        'blur-none',
        'blur-[0px]',
        'blur-[]px',
      ]) {
        final blur = ProfileAlbumBlur(garbage);

        expect(
          blur.sigma,
          greaterThan(0),
          reason: 'class "$garbage" must not render the photo unblurred',
        );
        expect(blur.slotFilter(blur: true), blursAt(blur.sigma));
      }
    });
  });

  group('only the server decides which slot is hidden', () {
    test('an unlocked slot is never blurred, however strong the dial', () {
      final blur = ProfileAlbumBlur.fromAlbum(album(atMaximum));

      expect(blur.slotFilter(blur: false), isNull);
      expect(blur.slotFilter(blur: true), isNotNull);
    });

    test('an unlocked slot stays unblurred even with no strength sent', () {
      expect(ProfileAlbumBlur.fromAlbum(null).slotFilter(blur: false), isNull);
    });

    test('the locked filter carries the dial through to the render', () {
      expect(
        ProfileAlbumBlur.fromAlbum(album(atDefault)).slotFilter(blur: true),
        blursAt(18),
      );

      final maximum = ProfileAlbumBlur.fromAlbum(album(atMaximum));
      expect(maximum.sigma, greaterThan(18));
      expect(maximum.slotFilter(blur: true), blursAt(maximum.sigma));
    });
  });

  group('the decorative backdrops keep their own look', () {
    test('an unlocked photo leaves the backdrop exactly as the app drew it', () {
      final blur = ProfileAlbumBlur.fromAlbum(album(atMaximum));

      expect(blur.backdropSigma(blur: false, decorative: 14), 14);
      expect(blur.backdropSigma(blur: false, decorative: 22), 22);
    });

    test('under a locked photo the backdrop is never the weaker layer', () {
      for (final blurClass in <String>[atMinimum, atDefault, atMaximum]) {
        final blur = ProfileAlbumBlur(blurClass);

        for (final decorative in <double>[14, 22]) {
          expect(
            blur.backdropSigma(blur: true, decorative: decorative),
            greaterThanOrEqualTo(blur.sigma),
            reason: 'a backdrop softer than the lock shows the photo through '
                'the blur fringe',
          );
          expect(
            blur.backdropSigma(blur: true, decorative: decorative),
            greaterThanOrEqualTo(decorative),
            reason: 'the decorative floor stays the floor',
          );
        }
      }
    });

    test('the gallery backdrop is unchanged at the default dial', () {
      expect(
        ProfileAlbumBlur.fromAlbum(album(atDefault))
            .backdropSigma(blur: true, decorative: 22),
        22,
      );
    });
  });
}
