import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Spotlight coachmark for inactive / not-searchable members.
///
/// Dim overlay with a clear hole on [targetKey], a bold animated arrow, and
/// plain tip text (no white dialog card).
class InactiveActivationCoachmark extends StatefulWidget {
  const InactiveActivationCoachmark({
    super.key,
    required this.targetKey,
    required this.tip,
    this.detail,
    required this.onAction,
    required this.onDismiss,
  });

  final GlobalKey targetKey;

  /// One short line: what to do. [detail] is the quieter why, if there is one.
  final String tip;
  final String? detail;
  final VoidCallback onAction;
  final VoidCallback onDismiss;

  @override
  State<InactiveActivationCoachmark> createState() =>
      _InactiveActivationCoachmarkState();
}

class _InactiveActivationCoachmarkState
    extends State<InactiveActivationCoachmark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  Rect? _targetRect;

  /// A snapshot of the target, painted back inside the spotlight at full
  /// opacity. Cutting a hole in the dim was not enough on a real device — the
  /// target still read as faint against everything around it. Drawing the thing
  /// itself is the only version where "highlighted" means brighter.
  ui.Image? _targetImage;

  /// The ratio the snapshot was taken at. RawImage treats an image's raw pixels
  /// as LOGICAL pixels unless told otherwise, so a 3x capture shown without it
  /// gets squashed to a third of its size — and the resampling averaged every
  /// dark glyph stroke into the white around it. Measured on device: the
  /// darkest pixel in the whole card came back (129,123,123) instead of near
  /// black, and the gold circle came back pale. Nothing was dimming it; it was
  /// being downscaled.
  double _targetScale = 1;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    // The target moves: the page scrolls it into view right after this opens,
    // and cards above it finish loading at their own pace. Measuring once left
    // the ring where the card USED to be — on this screen, two cards further
    // down, so it circled the views chart while the words said "complete your
    // profile". Following the pulse costs nothing, because the measurement
    // returns early unless the rectangle actually moved.
    _pulse.addListener(_measureTarget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureTarget());
  }

  @override
  void didUpdateWidget(covariant InactiveActivationCoachmark oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureTarget());
  }

  @override
  void dispose() {
    _pulse.removeListener(_measureTarget);
    _pulse.dispose();
    _targetImage?.dispose();
    super.dispose();
  }

  void _measureTarget() {
    final targetContext = widget.targetKey.currentContext;
    if (targetContext == null || !mounted) return;
    final box = targetContext.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final offset = box.localToGlobal(Offset.zero);
    final rect = offset & box.size;
    if (_targetRect != rect) {
      setState(() => _targetRect = rect);
    }
    _captureTarget();
  }

  Future<void> _captureTarget() async {
    if (_capturing || !mounted) return;
    final targetContext = widget.targetKey.currentContext;
    final boundary =
        targetContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null || !boundary.hasSize) return;
    // NOT debugNeedsPaint: that getter assigns its result inside an assert, so
    // in a RELEASE build reading it throws LateInitializationError. The throw
    // was swallowed by the catch below, the snapshot was never taken, and what
    // looked like a faint image was the real card seen through the hole with
    // the ring's white glow lying over it — measured on device at (129,123,123)
    // where the same text on the DIMMED page measured (13,10,10).

    _capturing = true;
    try {
      final ratio = MediaQuery.of(context).devicePixelRatio;
      final image = await boundary.toImage(pixelRatio: ratio);
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() {
        _targetImage?.dispose();
        _targetImage = image;
        _targetScale = ratio;
      });
    } catch (_) {
      // A frame where the boundary is not ready yet; the pulse tries again.
    } finally {
      _capturing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final fallback = Rect.fromLTWH(
      16,
      media.padding.top + 120,
      media.size.width - 32,
      160,
    );
    final target = _targetRect ?? fallback;
    // Inflated enough that the ring drawn around it never sits ON the target.
    final hole = target.inflate(7);

    final tipBelow =
        hole.bottom + 110 < media.size.height - media.padding.bottom - 56;
    final tipTop = tipBelow
        ? (hole.bottom + 58).clamp(
            media.padding.top + 12.0,
            media.size.height - 120.0,
          )
        : (hole.top - 72).clamp(
            media.padding.top + 12.0,
            media.size.height - 120.0,
          );

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onDismiss,
              child: CustomPaint(painter: _DimHolePainter(hole: hole)),
            ),
          ),

          // Ring + glow around the hole, UNDER the snapshot: a BoxShadow is a
          // blurred solid rect behind the box, so with a transparent interior
          // its white core fills the hole too. The snapshot painted after it
          // covers that core; only the halo outside the target survives.
          Positioned(
            left: hole.left,
            top: hole.top,
            width: hole.width,
            height: hole.height,
            child: GestureDetector(
              onTap: widget.onAction,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: _targetImage == null
                      ? const []
                      : [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.4),
                            blurRadius: 22,
                            spreadRadius: 3,
                          ),
                        ],
                ),
              ),
            ),
          ),

          // The snapshot lands EXACTLY on the target, not on the inflated
          // hole: the capture is partly transparent, so the real card stays
          // visible through the cleared hole underneath it. Stretching the
          // snapshot to the hole put its glyphs 7px off the real ones and
          // every word read double. Same rect, same size — the two layers
          // coincide and the eye sees one card.
          if (_targetImage != null)
            Positioned(
              left: target.left,
              top: target.top,
              width: target.width,
              height: target.height,
              child: IgnorePointer(
                child: RawImage(
                  image: _targetImage,
                  scale: _targetScale,
                  filterQuality: FilterQuality.high,
                  fit: BoxFit.fill,
                ),
              ),
            ),

          AnimatedBuilder(
            animation: _pulse,
            builder: (context, child) {
              final bounce = Curves.easeInOut.transform(_pulse.value) * 10;
              final arrowTop = tipBelow
                  ? hole.bottom + 4 + bounce
                  : tipTop + 36 - bounce;
              return Positioned(
                left: hole.center.dx - 34,
                top: arrowTop,
                child: child!,
              );
            },
            child: Transform.rotate(
              angle: tipBelow ? 0 : math.pi,
              child: Image.asset(
                'assets/images/coachmark_arrow.png',
                width: 52,
                height: 62,
                fit: BoxFit.contain,
              ),
            ),
          ),

          // The tip carries its own surface. As bare shadowed text it landed on
          // whatever card happened to be behind it — on this screen, the credits
          // row — and the two sets of words became one unreadable mix.
          Positioned(
            left: 18,
            right: 18,
            top: tipTop,
            child: GestureDetector(
              onTap: widget.onAction,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 10, 6, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.tip,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        height: 1.3,
                        fontWeight: FontWeight.w800,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.9),
                            blurRadius: 10,
                          ),
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.75),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                    ),
                    if ((widget.detail ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.detail!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontSize: 13.5,
                          height: 1.35,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.9),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Deliberately the quietest thing here. It used to be the largest and
          // easiest control on the screen, which told the member the way out of
          // this was to leave rather than to finish.
          Positioned(
            left: 0,
            right: 0,
            bottom: media.padding.bottom + 14,
            child: Center(
              child: TextButton(
                onPressed: widget.onDismiss,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white.withValues(alpha: 0.72),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                ),
                child: Text(
                  MaterialLocalizations.of(context).closeButtonLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DimHolePainter extends CustomPainter {
  const _DimHolePainter({required this.hole});

  final Rect hole;

  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Path()..addRect(Offset.zero & size);
    final cut = Path()
      ..addRRect(RRect.fromRectAndRadius(hole, const Radius.circular(10)));
    final path = Path.combine(PathOperation.difference, overlay, cut);
    // saveLayer + clear guarantees the target is left at full brightness even
    // where something else has already painted into this layer. The point of a
    // spotlight is that one thing is BRIGHTER than the rest; dimming it too,
    // which is what a plain rect over the whole screen does, defeats it.
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawPath(
      path,
      Paint()..color = Colors.black.withValues(alpha: 0.72),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(hole, const Radius.circular(10)),
      Paint()..blendMode = BlendMode.clear,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DimHolePainter oldDelegate) {
    return oldDelegate.hole != hole;
  }
}
