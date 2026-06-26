import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    final titleText = title.trim();
    final subtitleText = subtitle?.trim();
    final hasHeader =
        titleText.isNotEmpty || (subtitleText?.isNotEmpty ?? false);

    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasHeader) ...[
          if (titleText.isNotEmpty)
            Text(
              titleText,
              style: Theme.of(
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
        const SizedBox(height: 18),
        ElevatedButton.icon(
          onPressed: loading || !continueEnabled ? null : onContinue,
          icon: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.arrow_forward),
          label: Text(continueLabel ?? 'Continue'),
        ),
        if (secondary != null) ...[const SizedBox(height: 10), secondary!],
      ],
    );
  }
}
