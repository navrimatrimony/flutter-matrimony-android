class OnboardingFieldErrorTarget {
  const OnboardingFieldErrorTarget({
    required this.backendField,
    required this.ownerStep,
    required this.uiField,
  });

  final String backendField;
  final String ownerStep;
  final String uiField;
}

class OnboardingFieldErrorMap {
  static const String profileForWhomStep = 'profile_for_whom';
  static const String basicInfoStep = 'basic_info';

  static const List<String> knownBackendFields = <String>[
    'mother_tongue_id',
    'mother_tongue',
    'full_name',
    'date_of_birth',
    'height_cm',
  ];

  static const List<String> ownershipPriority = <String>[
    'mother_tongue_id',
    'mother_tongue',
    'full_name',
    'date_of_birth',
    'height_cm',
  ];

  static const Map<String, OnboardingFieldErrorTarget> _targets =
      <String, OnboardingFieldErrorTarget>{
        'mother_tongue_id': OnboardingFieldErrorTarget(
          backendField: 'mother_tongue_id',
          ownerStep: profileForWhomStep,
          uiField: 'mother_tongue',
        ),
        'mother_tongue': OnboardingFieldErrorTarget(
          backendField: 'mother_tongue',
          ownerStep: profileForWhomStep,
          uiField: 'mother_tongue',
        ),
        'full_name': OnboardingFieldErrorTarget(
          backendField: 'full_name',
          ownerStep: basicInfoStep,
          uiField: 'full_name',
        ),
        'date_of_birth': OnboardingFieldErrorTarget(
          backendField: 'date_of_birth',
          ownerStep: basicInfoStep,
          uiField: 'dob',
        ),
        'height_cm': OnboardingFieldErrorTarget(
          backendField: 'height_cm',
          ownerStep: basicInfoStep,
          uiField: 'height',
        ),
      };

  static OnboardingFieldErrorTarget? targetFor(String backendField) {
    return _targets[backendField];
  }

  static Map<String, String> forStep(
    Map<String, String> fieldErrors,
    String ownerStep,
  ) {
    return Map<String, String>.fromEntries(
      fieldErrors.entries.where(
        (entry) => targetFor(entry.key)?.ownerStep == ownerStep,
      ),
    );
  }

  static String? firstMessage(
    Map<String, String> fieldErrors,
    Iterable<String> priority,
  ) {
    for (final field in priority) {
      final message = fieldErrors[field];
      if (message != null && message.trim().isNotEmpty) return message;
    }
    return null;
  }

  static String? ownerStepFor(
    Map<String, String> fieldErrors, {
    Iterable<String> priority = ownershipPriority,
  }) {
    for (final field in priority) {
      if (!fieldErrors.containsKey(field)) continue;
      final ownerStep = targetFor(field)?.ownerStep;
      if (ownerStep != null) return ownerStep;
    }
    return null;
  }
}
