import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../core/locked_teaser.dart';

/// How strongly the profile-detail photo album must blur a photo the server
/// locked.
///
/// The strength is the admin setting `profile_view_lock_blur_strength` (35–100).
/// Laravel resolves it in `App\Services\Profile\ProfileViewLockBlurPolicy` and
/// ships it as `display.photo_album.blur_photo_class`, in the same Tailwind
/// grammar the locked-teaser payload already uses. Until that field existed the
/// album hardcoded its own sigmas, so the admin's dial moved the website and did
/// nothing on the phone.
///
/// This class is binding, not maths: every number it returns comes out of
/// [LockedTeaser]'s existing class parser. It decides only *where* the strength
/// is applied.
///
/// Two rules it exists to keep:
///
///   * The access decision stays on the server. A slot is blurred if and only if
///     the server set that slot's `blur` flag — [slotFilter] returns null for an
///     unlocked slot, so no caller can blur one by accident.
///   * A payload with no readable strength renders blurred, never clear.
///     Exposing a photo the admin meant to hide is the one unacceptable outcome,
///     so a missing field falls back to [fallbackSigma] and an unreadable class
///     falls back to the parser's own never-clear default.
@immutable
class ProfileAlbumBlur {
  const ProfileAlbumBlur(this.blurPhotoClass);

  /// Reads the strength out of a `display.photo_album` block. A null album, a
  /// missing field or a non-string value all mean "no strength was sent".
  factory ProfileAlbumBlur.fromAlbum(Map<String, dynamic>? photoAlbum) {
    final raw = photoAlbum?['blur_photo_class'];

    return ProfileAlbumBlur(raw is String ? raw.trim() : '');
  }

  /// Sigma used when the server sends no strength at all — an older build, or a
  /// response whose album block is missing.
  ///
  /// It is the value every locked album surface hardcoded before the dial
  /// reached mobile, so an un-upgraded server keeps rendering exactly what it
  /// renders today instead of getting quietly weaker.
  static const double fallbackSigma = 18;

  /// The server's class string, or empty when nothing was sent.
  final String blurPhotoClass;

  bool get hasServerStrength => blurPhotoClass.isNotEmpty;

  /// Blur sigma for a locked photo.
  ///
  /// A class that is present but unreadable resolves through
  /// [LockedTeaser.blurSigmaForClass], which is documented never to return zero
  /// — an unknown class blurs at [LockedTeaser.defaultBlurSigma] rather than
  /// rendering the photo clear.
  double get sigma => hasServerStrength
      ? LockedTeaser.blurSigmaForClass(blurPhotoClass)
      : fallbackSigma;

  /// The filter for an album slot, or null when the server left that slot
  /// unlocked. Callers draw the plain image on null.
  ImageFilter? slotFilter({required bool blur}) {
    if (!blur) return null;

    return ImageFilter.blur(sigmaX: sigma, sigmaY: sigma);
  }

  /// Sigma for a decorative backdrop drawn *underneath* a photo — the fill
  /// behind the hero image and behind the full-screen gallery page.
  ///
  /// Those layers are drawn for locked and unlocked photos alike and have their
  /// own look, so [decorative] is kept as the floor. Under a locked photo the
  /// backdrop must never be the weaker of the two: a Gaussian blur leaves a
  /// translucent fringe at the edges of the layer above it, and a backdrop
  /// softer than the lock would show the photo more clearly through that fringe
  /// than the admin allowed.
  double backdropSigma({required bool blur, required double decorative}) {
    if (!blur) return decorative;

    return math.max(decorative, sigma);
  }
}
