import 'onboarding_option.dart';

class OnboardingBootstrap {
  const OnboardingBootstrap({
    this.profileForWhom = const <OnboardingOption>[],
    this.genders = const <OnboardingOption>[],
    this.motherTongues = const <OnboardingOption>[],
    this.maritalStatuses = const <OnboardingOption>[],
    this.heightOptions = const <OnboardingOption>[],
    this.diets = const <OnboardingOption>[],
    this.smokingOptions = const <OnboardingOption>[],
    this.drinkingOptions = const <OnboardingOption>[],
    this.mangalDoshTypes = const <OnboardingOption>[],
    this.nakshatras = const <OnboardingOption>[],
    this.rashis = const <OnboardingOption>[],
    this.charanOptions = const <OnboardingOption>[],
    this.childrenRules = const <String, dynamic>{},
    this.agePolicy = const <String, dynamic>{},
    this.steps = const <String>[],
    this.raw = const <String, dynamic>{},
  });

  final List<OnboardingOption> profileForWhom;
  final List<OnboardingOption> genders;
  final List<OnboardingOption> motherTongues;
  final List<OnboardingOption> maritalStatuses;
  final List<OnboardingOption> heightOptions;
  final List<OnboardingOption> diets;
  final List<OnboardingOption> smokingOptions;
  final List<OnboardingOption> drinkingOptions;
  final List<OnboardingOption> mangalDoshTypes;
  final List<OnboardingOption> nakshatras;
  final List<OnboardingOption> rashis;
  final List<OnboardingOption> charanOptions;
  final Map<String, dynamic> childrenRules;
  final Map<String, dynamic> agePolicy;
  final List<String> steps;
  final Map<String, dynamic> raw;

  factory OnboardingBootstrap.fromJson(Map<String, dynamic> json) {
    final source = _payloadMap(json);
    final rawSteps = source['steps'] ?? source['onboarding_steps'];

    return OnboardingBootstrap(
      profileForWhom: OnboardingOption.listFrom(source['profile_for_whom']),
      genders: OnboardingOption.listFrom(
        source['gender_options'] ?? source['genders'],
      ),
      motherTongues: OnboardingOption.listFrom(
        source['mother_tongues'] ?? source['motherTongues'],
      ),
      maritalStatuses: OnboardingOption.listFrom(source['marital_statuses']),
      heightOptions: OnboardingOption.listFrom(
        source['height_options'] ?? source['heights'],
      ),
      diets: OnboardingOption.listFrom(
        source['diet_options'] ?? source['diets'] ?? source['diet'],
      ),
      smokingOptions: OnboardingOption.listFrom(
        source['smoking_options'] ??
            source['smoking'] ??
            source['smoking_statuses'],
      ),
      drinkingOptions: OnboardingOption.listFrom(
        source['drinking_options'] ??
            source['drinking'] ??
            source['drinking_statuses'],
      ),
      mangalDoshTypes: OnboardingOption.listFrom(
        source['mangal_dosh_types'] ??
            source['mangalDoshTypes'] ??
            source['mangal_dosh'],
      ),
      nakshatras: OnboardingOption.listFrom(
        source['nakshatras'] ?? source['nakshatra'],
      ),
      rashis: OnboardingOption.listFrom(source['rashis'] ?? source['rashi']),
      charanOptions: OnboardingOption.listFrom(
        source['charan_options'] ?? source['charans'] ?? source['charan'],
      ),
      childrenRules: _mapValue(source['children_rules']),
      agePolicy: _mapValue(source['age_policy']),
      steps: rawSteps is List
          ? rawSteps
                .map((step) => step?.toString().trim())
                .whereType<String>()
                .where((step) => step.isNotEmpty)
                .toList()
          : const <String>[],
      raw: Map<String, dynamic>.from(json),
    );
  }

  factory OnboardingBootstrap.fallbackProfileForWhom() {
    const rows = <Map<String, dynamic>>[
      {
        'key': 'self',
        'label': 'Self',
        'meta': {'gender_mode': 'ask'},
      },
      {
        'key': 'son',
        'label': 'Son',
        'meta': {'gender_mode': 'male'},
      },
      {
        'key': 'daughter',
        'label': 'Daughter',
        'meta': {'gender_mode': 'female'},
      },
      {
        'key': 'brother',
        'label': 'Brother',
        'meta': {'gender_mode': 'male'},
      },
      {
        'key': 'sister',
        'label': 'Sister',
        'meta': {'gender_mode': 'female'},
      },
      {
        'key': 'relative',
        'label': 'Relative',
        'meta': {'gender_mode': 'ask'},
      },
      {
        'key': 'friend',
        'label': 'Friend',
        'meta': {'gender_mode': 'ask'},
      },
    ];

    return OnboardingBootstrap(
      profileForWhom: rows.map(OnboardingOption.fromJson).toList(),
    );
  }

  static Map<String, dynamic> _payloadMap(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return json;
  }

  static Map<String, dynamic> _mapValue(dynamic value) {
    return value is Map
        ? Map<String, dynamic>.from(value)
        : <String, dynamic>{};
  }
}
