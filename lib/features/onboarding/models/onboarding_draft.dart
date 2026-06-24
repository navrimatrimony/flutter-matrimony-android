class OnboardingDraft {
  const OnboardingDraft({
    this.id,
    this.currentStep,
    this.lastCompletedStep,
    this.completedSteps = const <String>[],
    this.data = const <String, dynamic>{},
    this.profileId,
    this.raw = const <String, dynamic>{},
  });

  final int? id;
  final String? currentStep;
  final String? lastCompletedStep;
  final List<String> completedSteps;
  final Map<String, dynamic> data;
  final int? profileId;
  final Map<String, dynamic> raw;

  factory OnboardingDraft.fromJson(Map<String, dynamic>? json) {
    final source = json ?? <String, dynamic>{};
    final rawSteps = source['completed_steps'];
    final steps = rawSteps is List
        ? rawSteps
              .map((step) => step?.toString().trim())
              .whereType<String>()
              .where((step) => step.isNotEmpty)
              .toList()
        : <String>[];
    final rawData = source['data'];

    return OnboardingDraft(
      id: _intValue(source['id']),
      currentStep: _stringValue(source['current_step']),
      lastCompletedStep: _stringValue(source['last_completed_step']),
      completedSteps: steps,
      data: rawData is Map
          ? Map<String, dynamic>.from(rawData)
          : <String, dynamic>{},
      profileId: _intValue(source['profile_id']),
      raw: Map<String, dynamic>.from(source),
    );
  }

  static OnboardingDraft? maybeFrom(dynamic value) {
    if (value is Map) {
      return OnboardingDraft.fromJson(Map<String, dynamic>.from(value));
    }
    return null;
  }
}

String? _stringValue(dynamic value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  return text;
}

int? _intValue(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}
