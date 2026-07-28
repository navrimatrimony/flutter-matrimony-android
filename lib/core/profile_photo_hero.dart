import 'dart:ui';

import 'package:flutter/material.dart';

/// The one way a profile photo flies between a list and the profile detail
/// screen. Every list surface that routes into `ProfileDetailScreen` wraps its
/// photo in this, and the detail screen wraps its header photo in it too.
///
/// Three rules it exists to keep, all of which a bare [Hero] would break here:
///
///  * **A tag belongs to a rendered instance, not to a profile.** Two heroes
///    that share a tag inside one route throw
///    "There are multiple heroes that share the same tag within a subtree" and
///    blank the screen. This app renders the same profile in several places at
///    once — the More tab draws six independently-built server sections with no
///    cross-section de-duplication, and its fallback layout draws the first five
///    profiles in both the mini carousel and the card list — so a tag of just
///    the profile id is a guaranteed crash. [tagFor] therefore takes a `scope`
///    that identifies *where* the photo is drawn, and every caller folds its
///    section/list and its index into it.
///
///  * **A locked photo stays locked for the whole flight.** Flutter's default
///    shuttle renders the *destination* hero in both directions, so popping off
///    a blurred profile would fly the list's clear copy of the same photo at
///    header size — un-blurring, mid-animation, exactly what the paywall hides.
///    This shuttle instead renders the end the viewer is *leaving* (which is the
///    end that is definitely painted already) and blurs it whenever **either**
///    end is blurred. The sigma is supplied by the caller from `ProfileAlbumBlur`
///    — the admin's blur-strength dial — so there is no second blur path here.
///
///  * **No tag means no flight, not a broken one.** [tagFor] returns null when
///    there is no profile id, no photo, or no scope, and a null [tag] renders
///    [child] with no [Hero] at all. Opening the detail screen from a push
///    notification or an interest list — where there is no source photo on
///    screen — then simply cuts in the way it does today.
class ProfilePhotoHero extends StatelessWidget {
  const ProfilePhotoHero({
    super.key,
    required this.tag,
    required this.child,
    this.borderRadius = BorderRadius.zero,
    this.blurSigma,
  });

  /// Builds the tag for one rendered photo, or null when this instance must not
  /// fly at all.
  ///
  /// [scope] must identify the drawn position, not the profile — a section key
  /// plus an index, a list kind plus an index, and so on. Two photos of the same
  /// profile drawn at the same time must never be handed the same scope.
  static String? tagFor({
    required int? profileId,
    required String? scope,
    required String? photoUrl,
  }) {
    if (profileId == null || scope == null || photoUrl == null) return null;

    return 'profile-photo:$profileId@$scope';
  }

  /// Null disables the flight for this instance and renders [child] unchanged.
  final String? tag;

  final Widget child;

  /// The shape the *parent* already clips this photo to. Carried as data, not
  /// applied here: the flight is drawn in an overlay outside every clip on the
  /// way, so without it a 54px circular avatar would pop square the instant it
  /// left the list. The shuttle interpolates between the two ends' shapes.
  final BorderRadius borderRadius;

  /// Blur strength this end is already drawn at, or null when it is clear.
  ///
  /// Supply `ProfileAlbumBlur.sigma` when the server locked the photo. Kept as a
  /// plain number so this widget stays free of the access decision — it only
  /// carries forward what the caller already resolved.
  final double? blurSigma;

  @override
  Widget build(BuildContext context) {
    final heroTag = tag;
    if (heroTag == null) return child;

    return Hero(
      tag: heroTag,
      flightShuttleBuilder: _buildFlightShuttle,
      child: _ProfilePhotoHeroContent(
        borderRadius: borderRadius,
        blurSigma: blurSigma,
        child: child,
      ),
    );
  }

  static Widget _buildFlightShuttle(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection direction,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    final from = _contentOf(fromHeroContext);
    final to = _contentOf(toHeroContext);
    if (from == null || to == null) return const SizedBox.shrink();

    // Draw the end being left behind rather than the destination. That end is
    // on screen, so its bitmap is already decoded; the destination's usually is
    // not, because each surface decodes the same photo at its own width and
    // that width is part of the image-cache key. Flying the destination would
    // therefore show its loading placeholder for the whole animation on any
    // list whose cards are narrower than the screen.
    Widget photo = from.child;

    // Never weaker than the strongest end. On a pop off a locked profile the
    // list's copy of this photo is clear, so taking the destination's strength
    // would reveal it at header size on the way out.
    final sigma = _strongestSigma(from.blurSigma, to.blurSigma);
    if (sigma != null) {
      photo = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: photo,
      );
    }

    final beginRadius = from.borderRadius;
    final endRadius = to.borderRadius;
    if (beginRadius == endRadius) {
      if (beginRadius == BorderRadius.zero) return photo;

      return ClipRRect(borderRadius: beginRadius, child: photo);
    }

    return AnimatedBuilder(
      animation: animation,
      child: photo,
      builder: (context, child) {
        // The flight rectangle always travels from the `from` hero to the `to`
        // hero, but this animation only runs 0 -> 1 on a push; on a pop it is
        // the outgoing route's own animation, which runs 1 -> 0. So the
        // geometric progress has to be flipped to stay in step with the rect.
        final progress = direction == HeroFlightDirection.push
            ? animation.value
            : 1 - animation.value;

        return ClipRRect(
          borderRadius:
              BorderRadius.lerp(beginRadius, endRadius, progress) ?? endRadius,
          child: child,
        );
      },
    );
  }

  static _ProfilePhotoHeroContent? _contentOf(BuildContext heroContext) {
    final hero = heroContext.widget;
    if (hero is! Hero) return null;

    final content = hero.child;
    return content is _ProfilePhotoHeroContent ? content : null;
  }

  static double? _strongestSigma(double? first, double? second) {
    if (first == null) return second;
    if (second == null) return first;

    return first > second ? first : second;
  }
}

/// Carries each end's shape and blur strength to the flight shuttle, which can
/// only reach the two [Hero]es' `child` widgets. Renders [child] untouched — the
/// values are read, never applied, on either end.
class _ProfilePhotoHeroContent extends StatelessWidget {
  const _ProfilePhotoHeroContent({
    required this.borderRadius,
    required this.blurSigma,
    required this.child,
  });

  final BorderRadius borderRadius;
  final double? blurSigma;
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
