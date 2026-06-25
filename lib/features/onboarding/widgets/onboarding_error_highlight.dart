import 'dart:math' as math;

import 'package:flutter/material.dart';

class OnboardingErrorHighlight extends StatefulWidget {
  const OnboardingErrorHighlight({
    super.key,
    required this.hasError,
    required this.child,
    this.pulseKey,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  factory OnboardingErrorHighlight.forField({
    Key? key,
    required String field,
    required Map<String, String> fieldErrors,
    required Widget child,
    bool localError = false,
    Object? pulseToken,
    BorderRadius borderRadius = const BorderRadius.all(Radius.circular(8)),
  }) {
    return OnboardingErrorHighlight(
      key: key,
      hasError: localError || fieldErrors.containsKey(field),
      pulseKey: '$field:$pulseToken:${fieldErrors[field]}',
      borderRadius: borderRadius,
      child: child,
    );
  }

  final bool hasError;
  final Object? pulseKey;
  final BorderRadius borderRadius;
  final Widget child;

  @override
  State<OnboardingErrorHighlight> createState() =>
      _OnboardingErrorHighlightState();
}

class _OnboardingErrorHighlightState extends State<OnboardingErrorHighlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.hasError) {
      _controller.forward(from: 0);
    }
  }

  @override
  void didUpdateWidget(covariant OnboardingErrorHighlight oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.hasError) {
      _controller.value = 0;
      return;
    }

    if (!oldWidget.hasError || oldWidget.pulseKey != widget.pulseKey) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.hasError) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final pulse = math.sin(_controller.value * math.pi * 6).abs();
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            boxShadow: [
              BoxShadow(
                color: Colors.red.shade900.withValues(
                  alpha: 0.10 + (pulse * 0.20),
                ),
                blurRadius: 6 + (pulse * 8),
                spreadRadius: 0.5 + (pulse * 1.8),
              ),
            ],
          ),
          child: child,
        );
      },
    );
  }
}

InputDecoration onboardingErrorInputDecoration({
  required String labelText,
  String? errorText,
  Widget? suffixIcon,
}) {
  final errorBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: Colors.red.shade900, width: 1.6),
  );

  return InputDecoration(
    labelText: labelText,
    errorText: errorText,
    suffixIcon: suffixIcon,
    errorBorder: errorBorder,
    focusedErrorBorder: errorBorder.copyWith(
      borderSide: BorderSide(color: Colors.red.shade900, width: 2),
    ),
  );
}

String? onboardingFirstFieldError(
  Map<String, String> fieldErrors,
  Iterable<String> priority,
) {
  for (final field in priority) {
    final message = fieldErrors[field];
    if (message != null && message.trim().isNotEmpty) return message;
  }
  return null;
}
