import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

/// The one client-side reading of the server's locked-teaser payload.
///
/// Laravel builds this block in `App\Services\WhoViewed\WhoViewedTeaserPresenter`
/// (shared by the who-viewed and received-interest surfaces) and in
/// `App\Services\Chat\ChatTeaserPolicy` for locked chat rows. The admin tunes it
/// through `WhoViewedTeaserPolicy`, `ReceivedInterestTeaserPolicy` and
/// `ChatTeaserPolicy`, so every value below is an instruction from the admin,
/// not a suggestion: the app renders what it is told and never re-decides
/// client-side what to expose.
///
/// Every surface that draws a locked/teaser card goes through this class, so a
/// blur strength or a withheld photo can never be honoured on one screen and
/// ignored on another.
///
/// The widgets below the model are the other half of that promise: the photo
/// frame, headline, attribute/summary stack, curiosity pills and unlock button
/// are shared, so who-viewed tiles, locked notification rows and locked
/// received-interest cards read as the same object in three sizes rather than
/// three different-looking cards.
@immutable
class LockedTeaser {
  const LockedTeaser({
    this.headline,
    this.lines = const <String>[],
    this.viewedSummary,
    this.accentLine,
    this.matchLine,
    this.interestHint,
    this.photoUrl,
    this.avatarStyle = silhouetteAvatarStyle,
    this.blurPhotoClass = '',
  });

  /// Admin picked "blurred approved photo" for the teaser avatar.
  static const String blurAvatarStyle = 'blur';

  /// Admin picked "icon only" — the photo must not be drawn at all.
  static const String silhouetteAvatarStyle = 'silhouette';

  /// Sigma used when the class is missing or unreadable. Equals the sigma of
  /// Tailwind `blur-md`, which is what the server emits for its own default
  /// strength (`medium`). An unknown class must never render clear: exposing a
  /// photo the admin meant to hide is the one failure mode worth guarding.
  static const double defaultBlurSigma = 10;

  /// Slight upscale hides the transparent fringe a Gaussian blur leaves at the
  /// edges. Used when the class carries no `scale-*` token.
  static const double defaultPhotoScale = 1.08;

  final String? headline;
  final List<String> lines;
  final String? viewedSummary;
  final String? accentLine;
  final String? matchLine;
  final String? interestHint;

  /// Server-resolved photo. Null means the server deliberately withheld it.
  final String? photoUrl;

  /// `blur` or `silhouette`.
  final String avatarStyle;

  /// Tailwind classes derived from the admin's `teaser_blur_strength`, e.g.
  /// `blur-2xl scale-125 opacity-[0.88]` (strong) or `blur-[1px]` (chat, light).
  final String blurPhotoClass;

  /// Reads a teaser block out of an API payload. Returns null when the payload
  /// carries no teaser, so callers can fall back to their locked-but-anonymous
  /// presentation instead of inventing one.
  static LockedTeaser? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    if (map.isEmpty) return null;

    final style = _string(map['avatar_style'])?.toLowerCase();

    return LockedTeaser(
      headline: _string(map['headline']),
      lines: _stringList(map['lines']),
      viewedSummary: _string(map['viewed_summary']),
      accentLine: _string(map['accent_line']),
      matchLine: _string(map['match_line']),
      interestHint: _string(map['interest_hint']),
      photoUrl: _string(map['photo_url']),
      // Anything other than an explicit `blur` keeps the photo hidden.
      avatarStyle: style == blurAvatarStyle
          ? blurAvatarStyle
          : silhouetteAvatarStyle,
      blurPhotoClass: _string(map['blur_photo_class']) ?? '',
    );
  }

  /// The admin asked for a blurred photo rather than an icon.
  bool get wantsBlurredPhoto => avatarStyle == blurAvatarStyle;

  /// The URL to actually paint, or null when nothing may be drawn.
  ///
  /// Null covers three server decisions the app must respect: avatar style is
  /// `silhouette`, the photo was withheld, or the server fell back to its own
  /// SVG placeholder (which `Image.network` cannot decode anyway — the local
  /// silhouette is the honest render of it).
  String? get renderablePhotoUrl {
    if (!wantsBlurredPhoto) return null;

    final url = photoUrl;
    if (url == null || url.isEmpty) return null;
    if (_isVectorPlaceholder(url)) return null;

    return url;
  }

  bool get hasPhoto => renderablePhotoUrl != null;

  double get blurSigma => blurSigmaForClass(blurPhotoClass);

  double get photoScale => photoScaleForClass(blurPhotoClass);

  double get photoOpacity => photoOpacityForClass(blurPhotoClass);

  /// Accent and match lines are one emphasised row wherever they are shown.
  String? get accentAndMatchLine {
    final parts = <String>[
      if (accentLine != null) accentLine!,
      if (matchLine != null) matchLine!,
    ];

    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// Tailwind's named blur utilities, in CSS pixels.
  ///
  /// The bare `blur` key is last so the longer names match first when the class
  /// string is scanned token by token.
  static const Map<String, double> _namedBlurCssPx = <String, double>{
    'blur-none': 0,
    'blur-sm': 4,
    'blur-md': 12,
    'blur-lg': 16,
    'blur-xl': 24,
    'blur-2xl': 40,
    'blur-3xl': 64,
    'blur': 8,
  };

  /// CSS pixel radius → Flutter sigma.
  ///
  /// Not a straight 1:1: Tailwind's large utilities assume a full-width web
  /// hero, while these cards are 58–160 px wide, so the curve compresses the
  /// top end. The anchors preserve the sigmas the app already shipped
  /// (`blur-sm`→4, `blur-[3px]`→3, `blur-[6px]`→6, `blur-md`→10,
  /// `blur-2xl`→18) and interpolate everything in between, which is how the
  /// classes the app used to fall through on (`blur-[1px]`, `blur-[2px]`,
  /// `blur-[4px]`, `blur-lg`, `blur-xl`) now land on their own strength.
  static const List<List<double>> _sigmaCurve = <List<double>>[
    <double>[0, 0],
    <double>[6, 6],
    <double>[12, 10],
    <double>[40, 18],
    <double>[64, 22],
  ];

  /// Blur sigma for a server-emitted `blur_photo_class`.
  ///
  /// Falls back to [defaultBlurSigma] — never to zero — when no blur token can
  /// be read out of the class.
  static double blurSigmaForClass(String blurPhotoClass) {
    for (final token in _tokens(blurPhotoClass)) {
      final cssPx = _blurCssPxForToken(token);
      if (cssPx == null) continue;

      final sigma = _sigmaForCssPx(cssPx);
      // A token that resolves to "no blur" is treated as unreadable. All five
      // admin strengths are non-zero, so a zero here means malformed input.
      if (sigma > 0) return sigma;
    }

    return defaultBlurSigma;
  }

  /// Upscale for a server-emitted `blur_photo_class` (`scale-125` → 1.25).
  static double photoScaleForClass(String blurPhotoClass) {
    for (final token in _tokens(blurPhotoClass)) {
      final match = RegExp(r'^scale-(\d{1,3})$').firstMatch(token);
      if (match == null) continue;

      final percent = int.tryParse(match.group(1)!);
      if (percent == null || percent <= 0) continue;

      return (percent / 100).clamp(1.0, 2.0);
    }

    return defaultPhotoScale;
  }

  /// Opacity for a server-emitted `blur_photo_class`
  /// (`opacity-90` → 0.90, `opacity-[0.88]` → 0.88).
  static double photoOpacityForClass(String blurPhotoClass) {
    for (final token in _tokens(blurPhotoClass)) {
      final arbitrary = RegExp(
        r'^opacity-\[(\d*\.?\d+)\]$',
      ).firstMatch(token);
      if (arbitrary != null) {
        final value = double.tryParse(arbitrary.group(1)!);
        if (value != null) return value.clamp(0.0, 1.0);
        continue;
      }

      final named = RegExp(r'^opacity-(\d{1,3})$').firstMatch(token);
      if (named == null) continue;

      final percent = int.tryParse(named.group(1)!);
      if (percent == null) continue;

      return (percent / 100).clamp(0.0, 1.0);
    }

    return 1;
  }

  static Iterable<String> _tokens(String blurPhotoClass) =>
      blurPhotoClass.toLowerCase().trim().split(RegExp(r'\s+'));

  static double? _blurCssPxForToken(String token) {
    final named = _namedBlurCssPx[token];
    if (named != null) return named;

    final arbitrary = RegExp(
      r'^blur-\[(\d*\.?\d+)px\]$',
    ).firstMatch(token);
    if (arbitrary == null) return null;

    return double.tryParse(arbitrary.group(1)!);
  }

  static double _sigmaForCssPx(double cssPx) {
    if (cssPx <= 0) return 0;

    for (var i = 1; i < _sigmaCurve.length; i++) {
      final previous = _sigmaCurve[i - 1];
      final next = _sigmaCurve[i];
      if (cssPx > next[0]) continue;

      final span = next[0] - previous[0];
      final progress = span == 0 ? 0.0 : (cssPx - previous[0]) / span;

      return previous[1] + (next[1] - previous[1]) * progress;
    }

    return _sigmaCurve.last[1];
  }

  static bool _isVectorPlaceholder(String url) {
    final lower = url.toLowerCase();

    return lower.contains('/images/placeholders/') || lower.contains('.svg');
  }

  static String? _string(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();

    return text.isEmpty ? null : text;
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const <String>[];

    return value
        .map(_string)
        .whereType<String>()
        .toList(growable: false);
  }
}

/// The colours every locked surface shares.
///
/// These are the app's own tokens, not a new palette: [brand] is the brand red
/// used by the matches, notifications and interests screens, [brandSoft] is the
/// tint those screens already use behind brand icons, [accent] is the deep rose
/// the teaser text has always used, and [match] is the trust green the match
/// card already spends on "verified". Keeping them in one place is what stops
/// a locked card on one screen drifting away from the same card on another.
abstract final class LockedTeaserTheme {
  static const Color brand = Color(0xFFDC2626);
  static const Color brandSoft = Color(0xFFFEE2E2);
  static const Color accent = Color(0xFF9F1239);
  static const Color match = Color(0xFF157F5B);
  static const Color ink = Color(0xFF2E2220);
  static const Color muted = Color(0xFF746966);

  /// Warm neutral drawn under a teaser photo so a slow image never shows as a
  /// hole in the card.
  static const Color photoBase = Color(0xFFF1E7E3);
}

/// Photo, scrim, lock badge and any overlay chrome — the one frame every
/// locked surface draws, so a teaser looks the same everywhere.
///
/// [width]/[height] are optional: inside an `Expanded` or a `Stack` the frame
/// fills what it is given and sizes the lock badge and silhouette from the
/// resulting box.
class LockedTeaserPhotoFrame extends StatelessWidget {
  const LockedTeaserPhotoFrame({
    super.key,
    required this.teaser,
    this.width,
    this.height,
    this.circle = false,
    this.cornerRadius = 16,
    this.showLock = true,
    this.lockAlignment = Alignment.bottomRight,
    this.scrim = false,
    this.bottomOverlay,
    this.topStartOverlay,
  });

  final LockedTeaser teaser;
  final double? width;
  final double? height;
  final bool circle;
  final double cornerRadius;
  final bool showLock;
  final Alignment lockAlignment;

  /// Dark bottom gradient. Only needed when text is drawn over the photo.
  final bool scrim;

  /// Drawn along the bottom edge, above the scrim — the headline on card-style
  /// teasers.
  final Widget? bottomOverlay;

  /// Drawn in the top-left corner — the time chip on card-style teasers.
  final Widget? topStartOverlay;

  @override
  Widget build(BuildContext context) {
    Widget frame = LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = width ??
            (constraints.hasBoundedWidth ? constraints.maxWidth : 96.0);
        final boxHeight = height ??
            (constraints.hasBoundedHeight ? constraints.maxHeight : 96.0);
        final shortSide = math.max(24.0, math.min(boxWidth, boxHeight));
        final lockSize = (shortSide * 0.30).clamp(19.0, 34.0).toDouble();
        final inset = (shortSide * 0.05).clamp(3.0, 9.0).toDouble();
        final iconSize = (shortSide * 0.42).clamp(18.0, 58.0).toDouble();

        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            const ColoredBox(color: LockedTeaserTheme.photoBase),
            LockedTeaserPhoto(teaser: teaser, placeholderIconSize: iconSize),
            if (scrim)
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Color(0x1A000000),
                      Color(0x00000000),
                      Color(0xD9000000),
                    ],
                    stops: <double>[0, 0.42, 1],
                  ),
                ),
              ),
            if (topStartOverlay != null)
              Positioned(
                top: inset,
                left: inset,
                right: inset + lockSize,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: topStartOverlay,
                ),
              ),
            if (bottomOverlay != null)
              Positioned(
                left: inset + 2,
                right: inset + 2,
                bottom: inset + 1,
                child: bottomOverlay!,
              ),
            if (showLock)
              Align(
                alignment: lockAlignment,
                child: Padding(
                  padding: EdgeInsets.all(inset),
                  child: LockedTeaserLockBadge(size: lockSize),
                ),
              ),
          ],
        );
      },
    );

    frame = circle
        ? ClipOval(child: frame)
        : ClipRRect(
            borderRadius: BorderRadius.circular(cornerRadius),
            child: frame,
          );

    if (width != null || height != null) {
      frame = SizedBox(width: width, height: height, child: frame);
    }

    return frame;
  }
}

/// The one widget that paints a teaser photo.
///
/// Honours the admin's avatar style, blur strength, upscale and opacity, and
/// renders the silhouette whenever the server withheld the photo.
class LockedTeaserPhoto extends StatelessWidget {
  const LockedTeaserPhoto({
    super.key,
    required this.teaser,
    this.placeholderIconSize = 42,
    this.alignment = Alignment.topCenter,
  });

  final LockedTeaser teaser;
  final double placeholderIconSize;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final url = teaser.renderablePhotoUrl;
    if (url == null) {
      return LockedTeaserSilhouette(iconSize: placeholderIconSize);
    }

    final sigma = teaser.blurSigma;

    return Opacity(
      opacity: teaser.photoOpacity,
      child: Transform.scale(
        scale: teaser.photoScale,
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: Image.network(
            Uri.encodeFull(url),
            fit: BoxFit.cover,
            alignment: alignment,
            errorBuilder: (_, _, _) =>
                LockedTeaserSilhouette(iconSize: placeholderIconSize),
          ),
        ),
      ),
    );
  }
}

/// Stand-in used whenever no photo may be drawn.
///
/// Deliberately the same warm brand wash and white person medallion the match
/// cards already use for a missing photo: a locked row has to read as "there is
/// a person here you cannot see yet", never as a broken image.
class LockedTeaserSilhouette extends StatelessWidget {
  const LockedTeaserSilhouette({super.key, this.iconSize = 42});

  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final medallion = iconSize * 1.62;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            LockedTeaserTheme.brandSoft,
            LockedTeaserTheme.brand,
          ],
        ),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Container(
            width: medallion,
            height: medallion,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.20),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white54, width: 1.4),
            ),
            child: Icon(Icons.person, color: Colors.white, size: iconSize),
          ),
        ),
      ),
    );
  }
}

/// Round lock badge drawn over a teaser photo.
///
/// Brand-filled with a white ring so it reads as a deliberate status pip on the
/// person — the way a verified tick does — rather than a grey "unavailable"
/// stamp.
class LockedTeaserLockBadge extends StatelessWidget {
  const LockedTeaserLockBadge({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: LockedTeaserTheme.brand,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: (size * 0.07).clamp(1.2, 2.2).toDouble(),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.26),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        Icons.lock_rounded,
        color: Colors.white,
        size: size * 0.50,
      ),
    );
  }
}

/// The teaser's loudest line. [onPhoto] draws it white over the scrim; without
/// it the headline is ink on the card surface.
class LockedTeaserHeadline extends StatelessWidget {
  const LockedTeaserHeadline({
    super.key,
    required this.text,
    this.onPhoto = false,
    this.fontSize = 16,
    this.maxLines = 2,
  });

  final String text;
  final bool onPhoto;
  final double fontSize;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: onPhoto ? Colors.white : LockedTeaserTheme.ink,
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        height: 1.16,
        shadows: onPhoto
            ? const <Shadow>[
                Shadow(
                  color: Color(0x99000000),
                  blurRadius: 6,
                  offset: Offset(0, 1),
                ),
              ]
            : null,
      ),
    );
  }
}

/// Dark translucent chip drawn over a teaser photo — the same glass badge the
/// match cards use for their photo-count and premium markers.
class LockedTeaserGlassChip extends StatelessWidget {
  const LockedTeaserGlassChip({
    super.key,
    required this.label,
    this.icon = Icons.schedule_rounded,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: Colors.white, size: 12),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The curiosity row: the server's repeat-view accent line and its match line,
/// drawn as tinted pills so they cannot be mistaken for ordinary body text.
///
/// [compact] joins them into a single pill for narrow grid cards; wide surfaces
/// get one pill each. Both forms use the same shape, icons and colours, so the
/// two readings stay recognisably the same thing.
class LockedTeaserAccentRow extends StatelessWidget {
  const LockedTeaserAccentRow({
    super.key,
    required this.teaser,
    this.compact = false,
    this.showAccent = true,
    this.showMatch = true,
  });

  final LockedTeaser teaser;
  final bool compact;

  /// Suppressed where the surface already says the same thing in its headline.
  final bool showAccent;
  final bool showMatch;

  @override
  Widget build(BuildContext context) {
    final accent = showAccent ? teaser.accentLine : null;
    final match = showMatch ? teaser.matchLine : null;
    if (accent == null && match == null) return const SizedBox.shrink();

    if (compact) {
      final joined = <String>[
        if (accent != null) accent,
        if (match != null) match,
      ].join(' · ');

      return _LockedTeaserPill(
        icon: accent != null
            ? Icons.visibility_rounded
            : Icons.favorite_rounded,
        label: joined,
        foreground: accent != null
            ? LockedTeaserTheme.accent
            : LockedTeaserTheme.match,
        background: accent != null
            ? LockedTeaserTheme.brandSoft
            : LockedTeaserTheme.match.withValues(alpha: 0.10),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: <Widget>[
        if (accent != null)
          _LockedTeaserPill(
            icon: Icons.visibility_rounded,
            label: accent,
            foreground: LockedTeaserTheme.accent,
            background: LockedTeaserTheme.brandSoft,
          ),
        if (match != null)
          _LockedTeaserPill(
            icon: Icons.favorite_rounded,
            label: match,
            foreground: LockedTeaserTheme.match,
            background: LockedTeaserTheme.match.withValues(alpha: 0.10),
          ),
      ],
    );
  }
}

class _LockedTeaserPill extends StatelessWidget {
  const _LockedTeaserPill({
    required this.icon,
    required this.label,
    required this.foreground,
    required this.background,
  });

  final IconData icon;
  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foreground.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 12.5, color: foreground),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The one call to action on a locked card.
class LockedTeaserUnlockButton extends StatelessWidget {
  const LockedTeaserUnlockButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.expand = false,
    this.dense = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool expand;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(Icons.lock_open_rounded, size: dense ? 14 : 17),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: ElevatedButton.styleFrom(
        backgroundColor: LockedTeaserTheme.brand,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: EdgeInsets.symmetric(horizontal: dense ? 10 : 18),
        minimumSize: Size(expand ? double.infinity : 0, dense ? 32 : 42),
        tapTargetSize: dense
            ? MaterialTapTargetSize.shrinkWrap
            : MaterialTapTargetSize.padded,
        shape: const StadiumBorder(),
        textStyle: TextStyle(
          fontSize: dense ? 12 : 14,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

/// The one text stack for a teaser: the attribute line, the time summary, the
/// emphasised accent/match pills and the interest nudge — all rendered exactly
/// as the server sent them. Strings arrive already localized, so nothing here
/// rewrites copy, and no attribute is ever invented or reordered.
class LockedTeaserLines extends StatelessWidget {
  const LockedTeaserLines({
    super.key,
    required this.teaser,
    this.attributeMaxLines = 2,
    this.showSummary = true,
    this.showAccent = true,
    this.showMatch = true,
    this.compactAccent = false,
    this.showInterestHint = false,
    this.attributeFontSize = 12.5,
  });

  final LockedTeaser teaser;

  /// The server's attribute strings are joined into one scannable row; this
  /// caps how tall that row may grow before it ellipsises. Nothing is dropped
  /// before joining, so a short card shows a truncated line rather than
  /// silently hiding an attribute.
  final int attributeMaxLines;

  final bool showSummary;
  final bool showAccent;
  final bool showMatch;
  final bool compactAccent;
  final double attributeFontSize;

  /// The server's nudge line ("She may be waiting for your interest").
  final bool showInterestHint;

  @override
  Widget build(BuildContext context) {
    final attributes = teaser.lines.isEmpty ? null : teaser.lines.join(' · ');
    final summary = showSummary ? teaser.viewedSummary : null;
    final hint = showInterestHint ? teaser.interestHint : null;
    final hasAccentRow =
        (showAccent && teaser.accentLine != null) ||
        (showMatch && teaser.matchLine != null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (attributes != null)
          Text(
            attributes,
            maxLines: attributeMaxLines,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: LockedTeaserTheme.ink,
              fontSize: attributeFontSize,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
        if (summary != null) ...<Widget>[
          if (attributes != null) const SizedBox(height: 3),
          Text(
            summary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: LockedTeaserTheme.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        if (hasAccentRow) ...<Widget>[
          if (attributes != null || summary != null) const SizedBox(height: 7),
          LockedTeaserAccentRow(
            teaser: teaser,
            compact: compactAccent,
            showAccent: showAccent,
            showMatch: showMatch,
          ),
        ],
        if (hint != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            hint,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: LockedTeaserTheme.muted,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
        ],
      ],
    );
  }
}
