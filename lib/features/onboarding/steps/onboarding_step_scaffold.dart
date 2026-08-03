import 'package:flutter/material.dart';

import '../../../core/app_language.dart';
import 'onboarding_step_helpers.dart';

/// Flat bottom actions on the page background — not inside the content card.
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
    final pageBg = Theme.of(context).scaffoldBackgroundColor;

    return ColoredBox(
      color: pageBg,
      child: SafeArea(
        top: false,
        minimum: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
    this.contentPadding = const EdgeInsets.fromLTRB(16, 14, 16, 12),
    this.contentAsCard = true,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Future<void> Function() onContinue;
  final VoidCallback? onBack;
  final bool loading;
  final bool continueEnabled;
  final String? continueLabel;

  /// Only when a step already provides one (astro skip, refresh, request…).
  final Widget? secondary;
  final Widget? titleAction;
  final TextStyle? titleStyle;
  final EdgeInsetsGeometry contentPadding;

  /// When false (photo / post-reg), scroll content is not wrapped in a card.
  final bool contentAsCard;

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

  Widget _contentCard(BuildContext context, List<Widget> headerAndFields) {
    final scroll = SingleChildScrollView(
      padding: contentPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: headerAndFields,
      ),
    );
    if (!contentAsCard) return scroll;

    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      clipBehavior: Clip.antiAlias,
      child: scroll,
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

        final pageBg = Theme.of(context).scaffoldBackgroundColor;

        if (!bounded) {
          return ColoredBox(
            color: pageBg,
            child: Column(
              key: key,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _contentCard(context, headerAndFields),
                sticky,
              ],
            ),
          );
        }

        // Content card expands; CTA stays outside on page background.
        return ColoredBox(
          color: pageBg,
          child: Column(
            key: key,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _contentCard(context, headerAndFields)),
              sticky,
            ],
          ),
        );
      },
    );
  }
}
