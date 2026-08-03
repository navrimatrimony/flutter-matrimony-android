import 'package:flutter/material.dart';

import '../../../core/app_language.dart';
import 'onboarding_step_helpers.dart';

/// Flat bottom actions — Continue (+ optional secondary under it).
///
/// Not an elevated footer card glued to content. Page background shows through
/// so the CTA reads as independent; secondary (skip / refresh / request) stays
/// directly under the button only when a step already provides one.
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

    return ColoredBox(
      color: colorScheme.surface,
      child: SafeArea(
        top: false,
        minimum: EdgeInsets.zero,
        // Tight padding — enough air so CTA is not glued to the card above,
        // without a large empty footer band.
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (top != null) ...[top!, const SizedBox(height: 4)],
              child,
            ],
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
    this.titleAction,
    this.titleStyle,
    this.contentPadding = const EdgeInsets.fromLTRB(16, 16, 16, 4),
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Future<void> Function() onContinue;
  final VoidCallback? onBack;
  final bool loading;
  final bool continueEnabled;
  final String? continueLabel;

  /// Optional action already used by skippable / utility steps only
  /// (astro skip, partner refresh, education/career request). Never invent
  /// a Skip for every step — only render when the step passes one.
  final Widget? secondary;
  final Widget? titleAction;
  final TextStyle? titleStyle;
  final EdgeInsetsGeometry contentPadding;

  Widget _compactSecondary(BuildContext context, Widget child) {
    return Theme(
      data: Theme.of(context).copyWith(
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(40),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleText = title.trim();
    final subtitleText = subtitle?.trim();
    final hasHeader =
        titleText.isNotEmpty ||
        (subtitleText?.isNotEmpty ?? false) ||
        titleAction != null ||
        onBack != null;

    final headerAndFields = <Widget>[
      if (hasHeader) ...[
        if (titleText.isNotEmpty || titleAction != null || onBack != null)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (onBack != null) ...[
                IconButton(
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: loading ? null : onBack,
                  icon: const Icon(Icons.arrow_back),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                ),
                const SizedBox(width: 4),
              ],
              if (titleText.isNotEmpty)
                Expanded(
                  child: Text(
                    titleText,
                    style:
                        titleStyle ??
                        Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                )
              else
                const Spacer(),
              if (titleAction != null) ...[
                const SizedBox(width: 8),
                titleAction!,
              ],
            ],
          ),
        if (subtitleText != null && subtitleText.isNotEmpty) ...[
          if (titleText.isNotEmpty || titleAction != null || onBack != null)
            const SizedBox(height: 6),
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

    // CTA + existing secondary under it (skip stays here). Flat — no elevated
    // footer card, so the button does not read as part of the content card.
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
          if (secondary != null) ...[
            const SizedBox(height: 2),
            Center(child: _compactSecondary(context, secondary!)),
          ],
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
