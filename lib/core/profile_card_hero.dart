import 'dart:ui';

import 'package:flutter/material.dart';

/// The tags one tapped list card flies under, and the gate on whether it flies
/// at all.
///
/// **A tag belongs to a rendered instance, not to a profile.** Two heroes that
/// share a tag inside one route throw "There are multiple heroes that share the
/// same tag within a subtree" and blank the screen. This app renders the same
/// profile in several places at once — the More tab draws six independently-built
/// server sections with no cross-section de-duplication, and its fallback layout
/// draws the first five profiles in both the mini carousel and the card list — so
/// a tag of just the profile id is a guaranteed crash. [of] therefore takes a
/// `scope` that identifies *where* the card is drawn, and every caller folds its
/// section/list and its index into it.
///
/// **No tags means no flight, not a broken one.** [of] returns null when there is
/// no profile id, no photo, or no scope, and every hero here renders its child
/// with no [Hero] at all when handed a null tag. Opening the detail screen from a
/// push notification or an interest list — where there is no source card on
/// screen — then simply cuts in the way it always did.
///
/// The photo and the text printed on top of it fly as two heroes rather than
/// one, on purpose. They read as one object because both flights are driven by
/// the same route animation over the same interval, but the photo roughly
/// doubles in size on the way to the header while the name has to stay legible
/// at both ends. Scaling them together would blow the name up with the photo.
///
/// **A missing photo does not cancel the text flight.** The overlay block is
/// drawn on a gradient placeholder when a profile has no photo, and that block
/// still has somewhere to land, so only [photo] is withheld in that case.
@immutable
class ProfileCardHeroTags {
  const ProfileCardHeroTags._({required this.photo, required this.identity});

  /// Builds the tags for one rendered card, or null when this card must not fly.
  ///
  /// [scope] must identify the drawn position, not the profile — a section key
  /// plus an index, a list kind plus an index, and so on. Two cards of the same
  /// profile drawn at the same time must never be handed the same scope.
  static ProfileCardHeroTags? of({
    required int? profileId,
    required String? scope,
    required String? photoUrl,
  }) {
    if (profileId == null || scope == null) return null;

    return ProfileCardHeroTags._(
      // Only the picture itself is gated on there being a picture. Handing the
      // photo tag out anyway would fly one screen's "no photo yet" placeholder
      // into the other's, which are two different drawings of nothing.
      photo: photoUrl == null ? null : 'profile-photo:$profileId@$scope',
      identity: 'profile-identity:$profileId@$scope',
    );
  }

  /// Tag for the photo itself, or null when this profile has no photo to fly.
  /// See [ProfilePhotoHero].
  final String? photo;

  /// Tag for the name/age block drawn over the photo. See [ProfileIdentityHero].
  ///
  /// Only the surfaces that actually draw that block over the photo claim it; a
  /// tag the list side never uses simply produces no flight on that end.
  final String identity;

  @override
  bool operator ==(Object other) =>
      other is ProfileCardHeroTags &&
      other.photo == photo &&
      other.identity == identity;

  @override
  int get hashCode => Object.hash(photo, identity);
}

/// The one way a profile photo flies between a list and the profile detail
/// screen. Every list surface that routes into `ProfileDetailScreen` wraps its
/// photo in this, and the detail screen wraps its header photo in it too.
///
/// **A locked photo stays locked for the whole flight.** Flutter's default
/// shuttle renders the *destination* hero in both directions, so popping off a
/// blurred profile would fly the list's clear copy of the same photo at header
/// size — un-blurring, mid-animation, exactly what the paywall hides. This
/// shuttle instead renders the end the viewer is *leaving* (which is the end that
/// is definitely painted already) and blurs it whenever **either** end is
/// blurred. The sigma is supplied by the caller from `ProfileAlbumBlur` — the
/// admin's blur-strength dial — so there is no second blur path here.
class ProfilePhotoHero extends StatelessWidget {
  const ProfilePhotoHero({
    super.key,
    required this.tag,
    required this.child,
    this.borderRadius = BorderRadius.zero,
    this.blurSigma,
  });

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
    final from = _heroContentOf<_ProfilePhotoHeroContent>(fromHeroContext);
    final to = _heroContentOf<_ProfilePhotoHeroContent>(toHeroContext);
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
        return ClipRRect(
          borderRadius:
              BorderRadius.lerp(
                beginRadius,
                endRadius,
                heroFlightProgress(animation, direction),
              ) ??
              endRadius,
          child: child,
        );
      },
    );
  }

  static double? _strongestSigma(double? first, double? second) {
    if (first == null) return second;
    if (second == null) return first;

    return first > second ? first : second;
  }
}

/// One line of the overlay block, as one end draws it.
///
/// [gap] is the space this end leaves *above* the line, so a shuttle can
/// interpolate the spacing as well as the type.
@immutable
class ProfileIdentityLine {
  const ProfileIdentityLine({
    required this.text,
    required this.style,
    this.gap = 0,
    this.icon,
  });

  final String text;
  final TextStyle style;
  final double gap;

  /// Leading glyph this end draws before the text, if any.
  final IconData? icon;
}

/// The whole block of words printed on the photo — headline, every detail line
/// under it, and the status chips below those — flown across alongside the
/// photo.
///
/// A photo-only flight came apart in the hand: the picture lifted out of the
/// card and the words it was printed on stayed behind and cut. Carrying only the
/// headline was no better — the block visibly lost three quarters of itself at
/// the hand-off. So the block travels whole.
///
/// **Both ends must word the block the same way.** That is not something this
/// widget can enforce, and it is not something it will paper over: the shuttle
/// renders one end's strings, so if the two ends disagree the words change at
/// the hand-off instead of in mid-air, which is only marginally better. The
/// profile detail screen therefore composes its header from the card's own
/// fields rather than from a second, shorter idea of the same profile.
///
/// Both ends keep rendering their own [child] untouched — this widget only
/// *carries* the strings, styles and chips so the shuttle can reach them. The
/// two screens therefore look exactly as they did whenever no flight is running,
/// and the shuttle is the single place their two designs are reconciled.
///
/// What the shuttle does with them:
///
///  * **The words never change in mid-air.** It renders the strings of the end
///    being left behind and interpolates only the *style* and the spacing, so
///    the block settles into the destination's size instead of snapping.
///  * **A missing line degrades, it does not gap.** Lines are matched by
///    position; a line the destination does not draw at all keeps the outgoing
///    end's type and fades out over the flight, taking its own leading gap with
///    it, so the block shrinks smoothly instead of leaving a hole. The same
///    holds for the chip row and for a [trailing] widget only one end has (the
///    detail screen's verified tick).
class ProfileIdentityHero extends StatelessWidget {
  const ProfileIdentityHero({
    super.key,
    required this.tag,
    required this.title,
    required this.titleStyle,
    required this.child,
    this.titleMaxLines = 2,
    this.trailing,
    this.trailingGap = 8,
    this.lines = const <ProfileIdentityLine>[],
    this.chips = const <Widget>[],
    this.chipsGap = 0,
    this.chipsSpacing = 8,
  });

  /// Null disables the flight for this instance and renders [child] unchanged.
  ///
  /// Pass `ProfileCardHeroTags.identity` only from a surface that really draws
  /// this block over the photo and words it the way the detail screen words it.
  /// A compact tile that shows the bare name where the header shows "name, age"
  /// must leave this null — the words would have to change in mid-air.
  final String? tag;

  /// The headline both ends share — "name, age".
  final String title;

  final TextStyle titleStyle;
  final int titleMaxLines;

  /// Drawn to the right of [title] on the end that has it, faded across the
  /// flight when only one end does.
  final Widget? trailing;
  final double trailingGap;

  /// The detail lines under the headline, in the order this end draws them.
  final List<ProfileIdentityLine> lines;

  /// The status chips under the lines, already built by this end.
  final List<Widget> chips;

  /// Space this end leaves above the chip row.
  final double chipsGap;
  final double chipsSpacing;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final heroTag = tag;
    if (heroTag == null) return child;

    return Hero(
      tag: heroTag,
      flightShuttleBuilder: _buildFlightShuttle,
      child: _ProfileIdentityHeroContent(
        title: title,
        titleStyle: titleStyle,
        titleMaxLines: titleMaxLines,
        trailing: trailing,
        trailingGap: trailingGap,
        lines: lines,
        chips: chips,
        chipsGap: chipsGap,
        chipsSpacing: chipsSpacing,
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
    final from = _heroContentOf<_ProfileIdentityHeroContent>(fromHeroContext);
    final to = _heroContentOf<_ProfileIdentityHeroContent>(toHeroContext);
    if (from == null || to == null) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return _flightFrame(
          from,
          to,
          heroFlightProgress(animation, direction),
        );
      },
    );
  }

  static Widget _flightFrame(
    _ProfileIdentityHeroContent from,
    _ProfileIdentityHeroContent to,
    double progress,
  ) {
    final trailing = from.trailing ?? to.trailing;
    final trailingOpacity = from.trailing == null
        ? (to.trailing == null ? 0.0 : progress)
        : (to.trailing == null ? 1 - progress : 1.0);

    // The outgoing end's words, for the same reason the photo shuttle draws the
    // outgoing photo: that is what the viewer is already looking at. Lines pair
    // up by position, and a line with no counterpart shrinks away rather than
    // holding an empty row open.
    final lines = <Widget>[];
    for (var i = 0; i < from.lines.length; i++) {
      final line = from.lines[i];
      final landing = i < to.lines.length ? to.lines[i] : null;
      final opacity = landing == null ? 1 - progress : 1.0;
      lines.add(
        SizedBox(
          height:
              lerpDouble(line.gap, landing?.gap ?? 0, progress) ?? line.gap,
        ),
      );
      lines.add(
        Opacity(
          opacity: opacity,
          child: _flightLine(
            line,
            TextStyle.lerp(line.style, landing?.style ?? line.style, progress),
            progress,
          ),
        ),
      );
    }

    final chips = from.chips;
    final chipsOpacity = to.chips.isEmpty ? 1 - progress : 1.0;

    return DefaultTextStyle(
      // The flight is drawn in the navigator's overlay, outside any Material, so
      // without this the debug fallback paints a yellow double underline through
      // every word for the length of the animation.
      style: const TextStyle(decoration: TextDecoration.none),
      child: OverflowBox(
        alignment: Alignment.topLeft,
        // The flight rectangle interpolates between two boxes whose text wraps
        // differently, so for part of the way the content is a few pixels taller
        // than the rectangle it is being laid out in. Letting it spill is the
        // right call — constraining it would clip a descender, or trip a
        // flex-overflow assert, in the middle of the animation.
        minHeight: 0,
        maxHeight: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    from.title,
                    maxLines: from.titleMaxLines,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle.lerp(
                      from.titleStyle,
                      to.titleStyle,
                      progress,
                    ),
                  ),
                ),
                if (trailing != null) ...[
                  SizedBox(
                    width:
                        lerpDouble(
                          from.trailingGap,
                          to.trailingGap,
                          progress,
                        ) ??
                        to.trailingGap,
                  ),
                  Opacity(opacity: trailingOpacity, child: trailing),
                ],
              ],
            ),
            ...lines,
            if (chips.isNotEmpty) ...[
              SizedBox(
                height:
                    lerpDouble(from.chipsGap, to.chipsGap, progress) ??
                    from.chipsGap,
              ),
              Opacity(
                opacity: chipsOpacity,
                child: Wrap(
                  spacing:
                      lerpDouble(
                        from.chipsSpacing,
                        to.chipsSpacing,
                        progress,
                      ) ??
                      from.chipsSpacing,
                  runSpacing: 8,
                  children: chips,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// One line as the shuttle draws it: the outgoing end's words and glyph at an
  /// interpolated size. The icon is sized off the text so it keeps pace with it.
  static Widget _flightLine(
    ProfileIdentityLine line,
    TextStyle? style,
    double progress,
  ) {
    final text = Text(
      line.text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );

    final icon = line.icon;
    if (icon == null) return text;

    return Row(
      children: [
        Icon(icon, size: (style?.fontSize ?? 15) + 1, color: style?.color),
        const SizedBox(width: 5),
        Flexible(child: text),
      ],
    );
  }
}

/// How far along the flight *rectangle* is: 0 at the `from` hero, 1 at the `to`
/// hero, in both directions.
///
/// The rectangle always travels from `from` to `to`, but the animation handed to
/// a shuttle only runs 0 -> 1 on a push; on a pop it is the outgoing route's own
/// animation, which runs 1 -> 0. Anything a shuttle interpolates alongside the
/// rectangle has to be flipped to stay in step with it.
@visibleForTesting
double heroFlightProgress(
  Animation<double> animation,
  HeroFlightDirection direction,
) {
  return direction == HeroFlightDirection.push
      ? animation.value
      : 1 - animation.value;
}

/// Reads back the payload a hero end wrapped its child in. A shuttle can only
/// reach the two [Hero] widgets, so everything it needs has to be hung on their
/// `child`.
T? _heroContentOf<T extends Widget>(BuildContext heroContext) {
  final hero = heroContext.widget;
  if (hero is! Hero) return null;

  final content = hero.child;
  return content is T ? content : null;
}

/// Carries each end's shape and blur strength to [ProfilePhotoHero]'s shuttle.
/// Renders [child] untouched — the values are read, never applied, on either end.
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

/// Carries each end's words and text styles to [ProfileIdentityHero]'s shuttle.
/// Renders [child] untouched — the values are read, never applied, on either end.
class _ProfileIdentityHeroContent extends StatelessWidget {
  const _ProfileIdentityHeroContent({
    required this.title,
    required this.titleStyle,
    required this.titleMaxLines,
    required this.trailing,
    required this.trailingGap,
    required this.lines,
    required this.chips,
    required this.chipsGap,
    required this.chipsSpacing,
    required this.child,
  });

  final String title;
  final TextStyle titleStyle;
  final int titleMaxLines;
  final Widget? trailing;
  final double trailingGap;
  final List<ProfileIdentityLine> lines;
  final List<Widget> chips;
  final double chipsGap;
  final double chipsSpacing;
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
