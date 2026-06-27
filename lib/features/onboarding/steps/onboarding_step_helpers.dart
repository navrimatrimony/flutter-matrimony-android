import 'package:flutter/material.dart';

import '../models/onboarding_option.dart';

typedef OnboardingStepSaver =
    Future<bool> Function(
      String step,
      Map<String, dynamic> data, {
      bool saveProfile,
      bool advance,
    });

int? onboardingInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

String? onboardingText(dynamic value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  return text;
}

bool? onboardingBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value?.toString().trim().toLowerCase();
  if (text == null || text.isEmpty) return null;
  if (text == '1' || text == 'true' || text == 'yes') return true;
  if (text == '0' || text == 'false' || text == 'no') return false;
  return null;
}

String onboardingSelectedLoadingLabel(String locale) {
  return locale == 'mr'
      ? 'निवडलेली माहिती लोड होत आहे...'
      : 'Loading selected value...';
}

String onboardingSelectedFailureLabel(String locale) {
  return locale == 'mr'
      ? 'निवडलेली माहिती लोड झाली नाही. कृपया पुन्हा निवडा.'
      : 'Selected value could not be loaded. Please select again.';
}

OnboardingOption? selectedValuePlaceholderOption(
  dynamic id,
  String locale, {
  bool failed = false,
  Map<String, dynamic> meta = const <String, dynamic>{},
}) {
  final intId = onboardingInt(id);
  if (intId == null) return null;
  final status = failed ? 'failed' : 'loading';
  return OnboardingOption(
    id: intId,
    label: failed
        ? onboardingSelectedFailureLabel(locale)
        : onboardingSelectedLoadingLabel(locale),
    meta: <String, dynamic>{...meta, 'selected_label_status': status},
  );
}

OnboardingOption? optionFromData(dynamic value) {
  if (value is Map) {
    return OnboardingOption.fromJson(Map<String, dynamic>.from(value));
  }
  return null;
}

OnboardingOption? optionById(List<OnboardingOption> options, dynamic id) {
  final intId = onboardingInt(id);
  if (intId == null) return null;
  for (final option in options) {
    if (option.intId == intId) return option;
  }
  return null;
}

OnboardingOption? optionByKey(List<OnboardingOption> options, dynamic key) {
  final text = onboardingText(key);
  if (text == null) return null;
  for (final option in options) {
    if (option.key == text) return option;
  }
  return null;
}

List<OnboardingOption> optionListFromData(dynamic value) {
  if (value is! List) return const <OnboardingOption>[];
  return value
      .whereType<Map>()
      .map((row) => OnboardingOption.fromJson(Map<String, dynamic>.from(row)))
      .toList();
}

Map<String, dynamic> optionDraft(OnboardingOption option) {
  return <String, dynamic>{
    if (option.id != null) 'id': option.id,
    if (option.key != null) 'key': option.key,
    'label': option.label,
    if (option.meta.isNotEmpty) 'meta': option.meta,
  };
}

Map<String, dynamic> compactPayload(Map<String, dynamic> data) {
  final out = <String, dynamic>{};
  data.forEach((key, value) {
    if (value == null) return;
    if (value is String && value.trim().isEmpty) return;
    if (value is List && value.isEmpty) {
      out[key] = value;
      return;
    }
    out[key] = value;
  });
  return out;
}

String readableApiError(Map<String, dynamic> response, String fallback) {
  String friendly(String? text) {
    if (text == null) return fallback;
    final lower = text.toLowerCase();
    if (lower.contains('not accepted in onboarding phase 2') ||
        lower.contains('not supported for this onboarding step') ||
        lower.contains('direct custom education or occupation text')) {
      return fallback;
    }
    return text;
  }

  final message = onboardingText(response['message']);
  final errors = response['errors'];
  if (errors is Map && errors.isNotEmpty) {
    final first = errors.values.first;
    if (first is List && first.isNotEmpty) {
      final text = onboardingText(first.first);
      if (text != null) return friendly(text);
    }
    final text = onboardingText(first);
    if (text != null) return friendly(text);
  }
  return friendly(message);
}

const Color onboardingSelectedGreen = Color(0xFF0F8F5F);

class OnboardingSelectablePill extends StatelessWidget {
  const OnboardingSelectablePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.prominent = false,
    this.minHeight = 54,
    this.maxLines = 1,
    this.fontSize,
    this.horizontalPadding = 14,
    this.verticalPadding = 12,
    this.muted = false,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool prominent;
  final double minHeight;
  final int maxLines;
  final double? fontSize;
  final double horizontalPadding;
  final double verticalPadding;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? Colors.white
        : muted
        ? Colors.grey.shade500
        : Colors.grey.shade900;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          constraints: BoxConstraints(minHeight: minHeight),
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          decoration: BoxDecoration(
            color: selected
                ? onboardingSelectedGreen
                : muted
                ? Colors.grey.shade100
                : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? Colors.white : Colors.grey.shade300,
              width: selected ? 1.8 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: onboardingSelectedGreen.withValues(alpha: 0.26),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 120),
                child: selected
                    ? const Padding(
                        key: ValueKey('selected'),
                        padding: EdgeInsets.only(right: 6),
                        child: Icon(
                          Icons.check_circle,
                          size: 17,
                          color: Colors.white,
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey('unselected')),
              ),
              Flexible(
                child: Text(
                  label,
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: foreground,
                    fontSize: fontSize,
                    fontWeight: selected || prominent
                        ? FontWeight.w800
                        : FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OnboardingContinueButton extends StatelessWidget {
  const OnboardingContinueButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.enabled = true,
    this.loading = false,
    this.icon = Icons.arrow_forward,
  });

  final String label;
  final Future<void> Function() onPressed;
  final bool enabled;
  final bool loading;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: loading || !enabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: const StadiumBorder(),
          side: enabled && !loading
              ? const BorderSide(color: Colors.white, width: 1.2)
              : BorderSide.none,
        ),
        icon: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon),
        label: Text(label),
      ),
    );
  }
}
