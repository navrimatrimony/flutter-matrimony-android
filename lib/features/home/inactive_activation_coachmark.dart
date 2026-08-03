import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Spotlight coachmark for inactive members.
///
/// Dim overlay + clear hole on [targetKey] + bouncing yellow arrow + compact
/// tip bubble. No full-screen white dialog (that looked like a duplicate card).
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
      duration: const Duration(milliseconds: 850),
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
      media.padding.top + 200,
      media.size.width - 32,
      120,
    );
    final hole = (_targetRect ?? fallback).inflate(6);

    // Tip sits under the hole when space allows; otherwise above.
    final tipBelow = hole.bottom + 120 < media.size.height - media.padding.bottom;
    final tipTop = tipBelow
        ? (hole.bottom + 52).clamp(
            media.padding.top + 12.0,
            media.size.height - 140.0,
          )
        : (hole.top - 88).clamp(
            media.padding.top + 12.0,
            media.size.height - 140.0,
          );

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Dim layer — tap outside hole dismisses.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onDismiss,
              child: CustomPaint(
                painter: _DimHolePainter(hole: hole),
              ),
            ),
          ),

          // Clear hit target on the spotlight — runs the fix action.
          Positioned(
            left: hole.left,
            top: hole.top,
            width: hole.width,
            height: hole.height,
            child: GestureDetector(
              onTap: widget.onAction,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFF1A8).withValues(alpha: 0.45),
                      blurRadius: 22,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Animated arrow between hole and tip.
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, child) {
              final bounce = Curves.easeInOut.transform(_pulse.value) * 8;
              final arrowTop = tipBelow
                  ? hole.bottom + 6 + bounce
                  : tipTop + 58 - bounce;
              return Positioned(
                left: hole.center.dx - 28,
                top: arrowTop,
                child: child!,
              );
            },
            child: Transform.rotate(
              angle: tipBelow ? 0 : math.pi,
              child: CustomPaint(
                size: const Size(56, 40),
                painter: _YellowArrowPainter(),
              ),
            ),
          ),

          // Compact tip bubble — not a second action card.
          Positioned(
            left: 28,
            right: 28,
            top: tipTop,
            child: _TipBubble(
              text: widget.tip,
              onTap: widget.onAction,
            ),
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: media.padding.bottom + 18,
            child: Center(
              child: TextButton(
                onPressed: widget.onDismiss,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.black.withValues(alpha: 0.35),
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

class _TipBubble extends StatelessWidget {
  const _TipBubble({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 8,
      shadowColor: Colors.black38,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              height: 1.3,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2D2323),
            ),
          ),
        ),
      ),
    );
  }
}

class _YellowArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFF1A8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(size.width * 0.5, size.height)
      ..quadraticBezierTo(
        size.width * 0.15,
        size.height * 0.55,
        size.width * 0.5,
        4,
      );
    canvas.drawPath(path, paint);

    // Arrow head pointing up.
    final head = Path()
      ..moveTo(size.width * 0.5 - 11, 16)
      ..lineTo(size.width * 0.5, 2)
      ..lineTo(size.width * 0.5 + 11, 16);
    canvas.drawPath(
      head,
      Paint()
        ..color = const Color(0xFFFFF1A8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
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
      ..addRRect(RRect.fromRectAndRadius(hole, const Radius.circular(12)));
    final path = Path.combine(PathOperation.difference, overlay, cut);
    canvas.drawPath(
      path,
      Paint()..color = Colors.black.withValues(alpha: 0.72),
    );
  }

  @override
  bool shouldRepaint(covariant _DimHolePainter oldDelegate) {
    return oldDelegate.hole != hole;
  }
}
