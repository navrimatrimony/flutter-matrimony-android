import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Spotlight coachmark for inactive / not-searchable members.
///
/// Dim overlay with a clear hole on [targetKey], a bold animated arrow, and
/// plain tip text (no white dialog card).
class InactiveActivationCoachmark extends StatefulWidget {
  const InactiveActivationCoachmark({
    super.key,
    required this.targetKey,
    required this.tip,
    required this.onAction,
    required this.onDismiss,
  });

  final GlobalKey targetKey;
  final String tip;
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

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureTarget());
  }

  @override
  void didUpdateWidget(covariant InactiveActivationCoachmark oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureTarget());
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _measureTarget() {
    final targetContext = widget.targetKey.currentContext;
    if (targetContext == null || !mounted) return;
    final box = targetContext.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final offset = box.localToGlobal(Offset.zero);
    final rect = offset & box.size;
    if (_targetRect == rect) return;
    setState(() => _targetRect = rect);
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
    final hole = (_targetRect ?? fallback).inflate(4);

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

          // Spotlight ring — brand white, no cream glow.
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
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 10,
                    ),
                  ],
                ),
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
              child: CustomPaint(
                size: const Size(68, 48),
                painter: _BoldArrowPainter(),
              ),
            ),
          ),

          // Plain tip text — no white box.
          Positioned(
            left: 24,
            right: 24,
            top: tipTop,
            child: GestureDetector(
              onTap: widget.onAction,
              child: Text(
                widget.tip,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  height: 1.35,
                  fontWeight: FontWeight.w800,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.85),
                      blurRadius: 8,
                      offset: const Offset(0, 1),
                    ),
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.7),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: media.padding.bottom + 16,
            child: Center(
              child: TextButton(
                onPressed: widget.onDismiss,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.white.withValues(alpha: 0.14),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                ),
                child: Text(
                  MaterialLocalizations.of(context).closeButtonLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BoldArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Dark outline first so the arrow stays visible on any backdrop.
    final outline = Paint()
      ..color = Colors.black.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()
      ..color = const Color(0xFFFFE566)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final stem = Path()
      ..moveTo(size.width * 0.5, size.height)
      ..quadraticBezierTo(
        size.width * 0.18,
        size.height * 0.55,
        size.width * 0.5,
        8,
      );

    final head = Path()
      ..moveTo(size.width * 0.5 - 14, 22)
      ..lineTo(size.width * 0.5, 4)
      ..lineTo(size.width * 0.5 + 14, 22);

    for (final paint in [outline, fill]) {
      canvas.drawPath(stem, paint);
      canvas.drawPath(head, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
    canvas.drawPath(
      path,
      Paint()..color = Colors.black.withValues(alpha: 0.78),
    );
  }

  @override
  bool shouldRepaint(covariant _DimHolePainter oldDelegate) {
    return oldDelegate.hole != hole;
  }
}
