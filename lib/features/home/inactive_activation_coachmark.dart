import 'package:flutter/material.dart';

/// Dimmed coachmark that keeps one target region readable and points an
/// animated arrow at it — used when the profile is not searchable yet.
class InactiveActivationCoachmark extends StatefulWidget {
  const InactiveActivationCoachmark({
    super.key,
    required this.targetKey,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    required this.onDismiss,
  });

  final GlobalKey targetKey;
  final String title;
  final String message;
  final String actionLabel;
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
    final context = widget.targetKey.currentContext;
    if (context == null || !mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final offset = box.localToGlobal(Offset.zero);
    final rect = offset & box.size;
    if (_targetRect == rect) return;
    setState(() => _targetRect = rect);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final target = _targetRect;
    final highlight = target == null
        ? Rect.fromLTWH(
            16,
            media.padding.top + 180,
            media.size.width - 32,
            116,
          )
        : target.inflate(8);

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _DimHolePainter(hole: highlight),
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            left: highlight.left,
            top: highlight.top,
            width: highlight.width,
            height: highlight.height,
            child: GestureDetector(
              onTap: widget.onAction,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.35),
                      blurRadius: 18,
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
              return Positioned(
                left: highlight.center.dx - 22,
                top: highlight.bottom + 4 + bounce,
                child: child!,
              );
            },
            child: const Icon(
              Icons.arrow_upward_rounded,
              size: 44,
              color: Color(0xFFFFF1A8),
              shadows: [
                Shadow(color: Colors.black54, blurRadius: 8),
              ],
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            top: (highlight.bottom + 56).clamp(
              media.padding.top + 24,
              media.size.height - 220,
            ),
            child: _CoachCard(
              title: widget.title,
              message: widget.message,
              actionLabel: widget.actionLabel,
              onAction: widget.onAction,
              onDismiss: widget.onDismiss,
            ),
          ),
        ],
      ),
    );
  }
}

class _CoachCard extends StatelessWidget {
  const _CoachCard({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    required this.onDismiss,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 10,
      shadowColor: Colors.black45,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: Color(0xFF2D2323),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: Color(0xFF7C6A64),
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(46),
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            TextButton(
              onPressed: onDismiss,
              child: Text(
                MaterialLocalizations.of(context).closeButtonLabel,
              ),
            ),
          ],
        ),
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
      ..addRRect(
        RRect.fromRectAndRadius(hole, const Radius.circular(12)),
      );
    final path = Path.combine(PathOperation.difference, overlay, cut);
    canvas.drawPath(
      path,
      Paint()..color = Colors.black.withValues(alpha: 0.62),
    );
  }

  @override
  bool shouldRepaint(covariant _DimHolePainter oldDelegate) {
    return oldDelegate.hole != hole;
  }
}
