import 'package:flutter/material.dart';

import '../../../core/app_language.dart';
import 'onboarding_step_helpers.dart';

/// Shared sticky bottom strip for primary onboarding CTAs.
class OnboardingStickyCtaBar extends StatelessWidget {
  const OnboardingStickyCtaBar({
    super.key,
    required this.child,
    this.top,
  });

  final Widget child;
  final Widget? top;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surface,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.grey.shade300),
          ),
        ),
        child: SafeArea(
          top: false,
          minimum: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (top != null) ...[top!, const SizedBox(height: 10)],
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class OnboardingStepScaffold extends StatelessWidget {
  const OnboardingStepScaffold({
    super.key,
    required this.title,
    required this.children,
    required this.onContinue,
    this.onBack,
    this.loading = false,
    this.continueEnabled = true,
    this.subtitle,
    this.continueLabel,
    this.secondary,
    this.titleStyle,
    this.contentPadding = const EdgeInsets.fromLTRB(16, 16, 16, 8),
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Future<void> Function() onContinue;
  final VoidCallback? onBack;
  final bool loading;
  final bool continueEnabled;
  final String? continueLabel;
  final Widget? secondary;
  final TextStyle? titleStyle;
  final EdgeInsetsGeometry contentPadding;

  @override
  Widget build(BuildContext context) {
    final titleText = title.trim();
    final subtitleText = subtitle?.trim();
    final hasHeader =
        titleText.isNotEmpty || (subtitleText?.isNotEmpty ?? false);

    final headerAndFields = <Widget>[
      if (hasHeader) ...[
        if (titleText.isNotEmpty)
          Text(
            titleText,
            style:
                titleStyle ??
                Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        if (subtitleText != null && subtitleText.isNotEmpty) ...[
          if (titleText.isNotEmpty) const SizedBox(height: 6),
          Text(
            subtitleText,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
          ),
        ],
        const SizedBox(height: 14),
      ],
      ...children,
    ];

    final sticky = OnboardingStickyCtaBar(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OnboardingContinueButton(
            label: continueLabel ?? appText.continueLabel,
            loading: loading,
            enabled: continueEnabled,
            onPressed: onContinue,
          ),
          if (secondary != null) ...[const SizedBox(height: 10), secondary!],
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final bounded = constraints.hasBoundedHeight &&
            constraints.maxHeight.isFinite &&
            constraints.maxHeight > 0;

        if (!bounded) {
          return Column(
            key: key,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: contentPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: headerAndFields,
                ),
              ),
              sticky,
            ],
          );
        }

        return Column(
          key: key,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: contentPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: headerAndFields,
                ),
              ),
            ),
            sticky,
          ],
        );
      },
    );
  }
}
