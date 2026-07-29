import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// The one low-level way this app draws a profile photo that comes from the
/// network. Every profile-photo surface delegates here.
///
/// Why it exists: a bare `Image.network` paints nothing at all while its bytes
/// are in flight, so whatever sits behind it shows through — that absence is
/// the "grey empty box" a member sees while scrolling, not a placeholder. This
/// widget always paints the caller's own fallback during the load and
/// cross-fades the sharp photo in on top of it. It reuses that exact same
/// fallback when the photo fails, so a slow photo and a broken photo look
/// identical and neither can ever read as an error or a bare rectangle.
///
/// It also owns the app's photo caching. Every photo resolves through
/// [providerFor], which is backed by an on-disk + in-memory cache, so a URL is
/// downloaded from the server once and served locally on every later view,
/// including after an app restart. Callers that know a photo is about to be
/// needed can warm that same cache up front with [prefetch].
///
/// It is deliberately NOT a blur-up ("WhatsApp style") loader. The API exposes
/// a single full-size photo URL per profile — no thumbnail, no blurhash, no
/// preview asset of any kind — so there is nothing cheap to show first.
/// Blurring that same URL could only produce a blurry frame once the full image
/// had already downloaded, which is exactly the moment the sharp one is ready,
/// so it would cost work and change nothing. Real blur-up needs the backend to
/// ship a small preview alongside the photo URL first.
class ProfileNetworkImage extends StatelessWidget {
  const ProfileNetworkImage({
    super.key,
    required this.url,
    required this.placeholder,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.topCenter,
    this.width,
    this.height,
    this.decodeWidth,
    this.onError,
  });

  /// Widest photo the backend ever stores — ImageOptimizationService renders a
  /// single 720x960 WebP derivative — so decoding wider than this only wastes
  /// memory without adding detail.
  static const int _storedPhotoWidth = 720;

  static const Duration _fadeDuration = Duration(milliseconds: 220);

  final String url;

  /// Drawn while the photo loads and again if it fails. Callers pass the same
  /// fallback they already use for a missing photo, so no new visual is
  /// invented and loading, missing and broken all read the same way.
  final Widget placeholder;

  final BoxFit fit;
  final AlignmentGeometry alignment;
  final double? width;
  final double? height;

  /// Logical width this photo is laid out at. Used to decode the image at the
  /// size it is actually drawn instead of the stored 720x960 (2.76 MB of RAM
  /// per card, which evicts the image cache while scrolling and forces the
  /// photos to be downloaded again). Leave null when the caller cannot know
  /// its own width.
  final double? decodeWidth;

  /// Called when the photo fails to load, for callers that remember bad URLs.
  final VoidCallback? onError;

  /// The single image provider every profile photo in the app goes through.
  ///
  /// It is backed by the shared on-disk cache, so a photo is downloaded from
  /// the server once and afterwards served locally — including across app
  /// restarts. Both this widget and [prefetch] build the provider here so they
  /// resolve to the same cache entry and a prefetched photo is genuinely
  /// already decoded when its card arrives.
  static ImageProvider providerFor(
    BuildContext context,
    String url, {
    double? decodeWidth,
  }) {
    return ResizeImage.resizeIfNeeded(
      _decodeCacheWidthFor(context, decodeWidth),
      null,
      CachedNetworkImageProvider(url),
    );
  }

  /// Warms the cache for [url] so the photo is on disk and decoded before the
  /// widget that draws it is ever built.
  ///
  /// Failures are swallowed on purpose: a photo that cannot be prefetched is
  /// simply retried by the widget later, and a broken URL must never surface
  /// as an error from a background warm-up.
  static Future<void> prefetch(
    BuildContext context,
    String url, {
    double? decodeWidth,
  }) {
    return precacheImage(
      providerFor(context, url, decodeWidth: decodeWidth),
      context,
      onError: (_, _) {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final image = Image(
      image: providerFor(context, url, decodeWidth: decodeWidth),
      fit: fit,
      alignment: alignment,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        // Already decoded in the image cache: show it straight away. Fading
        // here would read as a flicker every time the widget rebuilds.
        if (wasSynchronouslyLoaded) return child;

        return AnimatedSwitcher(
          duration: _fadeDuration,
          switchInCurve: Curves.easeOut,
          child: frame == null
              ? KeyedSubtree(
                  key: const ValueKey<String>('placeholder'),
                  child: placeholder,
                )
              : KeyedSubtree(
                  key: const ValueKey<String>('photo'),
                  child: child,
                ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        onError?.call();
        return placeholder;
      },
    );

    // The width/height a caller asks for must size the placeholder too, so they
    // are applied here rather than on the Image — Image passes them to the
    // decoded frame only, which does not exist yet while loading.
    if (width == null && height == null) return image;
    return SizedBox(width: width, height: height, child: image);
  }

  static int? _decodeCacheWidthFor(BuildContext context, double? decodeWidth) {
    final logicalWidth = decodeWidth;
    if (logicalWidth == null || logicalWidth <= 0) return null;

    final devicePixels = (logicalWidth * MediaQuery.devicePixelRatioOf(context))
        .round();
    return devicePixels < _storedPhotoWidth ? devicePixels : _storedPhotoWidth;
  }
}
