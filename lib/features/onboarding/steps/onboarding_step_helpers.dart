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
