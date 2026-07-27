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

/// Icon-only stand-in used whenever no photo may be drawn.
class LockedTeaserSilhouette extends StatelessWidget {
  const LockedTeaserSilhouette({super.key, this.iconSize = 42});

  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFF8D9D3), Color(0xFFEAF3F8)],
        ),
      ),
      child: Icon(
        Icons.person_outline,
        color: const Color(0xFF9F1239),
        size: iconSize,
      ),
    );
  }
}

/// Round lock badge drawn over a teaser photo.
class LockedTeaserLockBadge extends StatelessWidget {
  const LockedTeaserLockBadge({super.key, this.size = 30});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.50),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.lock_outline,
        color: Colors.white,
        size: size * 0.56,
      ),
    );
  }
}

/// The one text stack for a teaser: the attribute lines, the time summary and
/// the emphasised accent/match row, all rendered exactly as the server sent
/// them. Strings arrive already localized, so nothing here rewrites copy.
class LockedTeaserLines extends StatelessWidget {
  const LockedTeaserLines({
    super.key,
    required this.teaser,
    this.maxAttributeLines = 3,
    this.accentColor = const Color(0xFF9F1239),
    this.showInterestHint = false,
  });

  final LockedTeaser teaser;
  final int maxAttributeLines;
  final Color accentColor;

  /// The server's nudge line ("She may be waiting for your interest").
  final bool showInterestHint;

  @override
  Widget build(BuildContext context) {
    final lines = teaser.lines.take(maxAttributeLines).toList(growable: false);
    final summary = teaser.viewedSummary;
    final accent = teaser.accentAndMatchLine;
    final hint = showInterestHint ? teaser.interestHint : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final line in lines) ...<Widget>[
          Text(
            line,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.grey.shade800,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
        ],
        if (summary != null)
          Text(
            summary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        if (accent != null) ...<Widget>[
          const SizedBox(height: 5),
          Text(
            accent,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accentColor,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
        if (hint != null) ...<Widget>[
          const SizedBox(height: 5),
          Text(
            hint,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ],
      ],
    );
  }
}
