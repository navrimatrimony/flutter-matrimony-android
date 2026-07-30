/// Lenient readers for values that arrive from an API as whatever JSON felt
/// like at the time — `7`, `"7"`, `null`, or `" "`.
///
/// These live in the engine rather than in either app because the engine reads
/// the same payloads, and a second copy of "how do we read an id" is exactly
/// the kind of drift that ends with two apps disagreeing about the same row.
library;

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
