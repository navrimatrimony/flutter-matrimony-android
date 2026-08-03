import '../../core/app_language.dart';

/// One chip + body used by the Family/About optional step.
class AboutTemplateSuggestion {
  const AboutTemplateSuggestion({required this.label, required this.text});

  final String label;
  final String text;

  // Value equality is load-bearing, not tidiness. `SmartOnboardingScreen`
  // rebuilds this list from scratch on every build, so without this
  // `listEquals` in `didUpdateWidget` compares object identities, never
  // matches, and the step re-seeds itself from the draft on every parent
  // rebuild — silently discarding whatever the member had just selected.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AboutTemplateSuggestion &&
        other.label == label &&
        other.text == text;
  }

  @override
  int get hashCode => Object.hash(label, text);
}

/// SSOT: who speaks in onboarding "About" copy.
///
/// Locked product rule (2026-08-03):
/// - `profile_for_whom = self` → candidate first person, gender-aware
/// - any other relation (son/daughter/brother/sister/relative/friend) →
///   **parent/elder voice** ("आमची मुलगी…", "Our daughter…"), gender-aware
///
/// Do not invent a second voice path beside this resolver.
class AboutVoice {
  const AboutVoice({
    required this.relationKey,
    required this.female,
    required this.parentVoice,
  });

  final String relationKey;
  final bool female;
  final bool parentVoice;

  factory AboutVoice.resolve({
    required String? profileForWhom,
    required String? genderKey,
  }) {
    final relation = (profileForWhom ?? 'self').trim().toLowerCase();
    final gender = (genderKey ?? '').trim().toLowerCase();
    final female = gender == 'female' ||
        gender == 'f' ||
        gender.contains('female') ||
        gender.contains('woman') ||
        gender.contains('स्त्री') ||
        gender.contains('मुलगी');
    final parentVoice = relation != 'self' && relation.isNotEmpty;
    return AboutVoice(
      relationKey: relation.isEmpty ? 'self' : relation,
      female: female,
      parentVoice: parentVoice,
    );
  }

  /// Third-person / parent-voice subject ("आमची मुलगी", "Our son").
  String get subject {
    if (!parentVoice) return '';
    if (isMarathiApp) {
      return switch (relationKey) {
        'son' => 'आमचा मुलगा',
        'daughter' => 'आमची मुलगी',
        'brother' => 'आमचा भाऊ',
        'sister' => 'आमची बहीण',
        'friend' => female ? 'आमची मैत्रिण' : 'आमचा मित्र',
        'relative' => female ? 'आमची नातेवाईक' : 'आमचा नातेवाईक',
        _ => female ? 'आमची मुलगी' : 'आमचा मुलगा',
      };
    }
    return switch (relationKey) {
      'son' => 'Our son',
      'daughter' => 'Our daughter',
      'brother' => 'Our brother',
      'sister' => 'Our sister',
      'friend' => female ? 'Our friend' : 'Our friend',
      'relative' => 'Our relative',
      _ => female ? 'Our daughter' : 'Our son',
    };
  }

  List<AboutTemplateSuggestion> templates({required String factText}) {
    String body(String seed) {
      return [seed, factText].where((part) => part.trim().isNotEmpty).join(' ');
    }

    return <AboutTemplateSuggestion>[
      AboutTemplateSuggestion(
        label: isMarathiApp ? 'कुटुंब प्रथम' : 'Family first',
        text: body(_familyFirst),
      ),
      AboutTemplateSuggestion(
        label: isMarathiApp ? 'काम आणि समतोल' : 'Career with balance',
        text: body(_careerBalance),
      ),
      AboutTemplateSuggestion(
        label: isMarathiApp ? 'परंपरा आणि मोकळेपण' : 'Tradition, open mind',
        text: body(_tradition),
      ),
      AboutTemplateSuggestion(
        label: isMarathiApp ? 'प्रामाणिकपणा' : 'Honesty & respect',
        text: body(_honesty),
      ),
      AboutTemplateSuggestion(
        label: isMarathiApp ? 'शांत स्वभाव' : 'Calm & steady',
        text: body(_calm),
      ),
      AboutTemplateSuggestion(
        label: isMarathiApp ? 'एकत्र वाटचाल' : 'Growing together',
        text: body(_growth),
      ),
    ];
  }

  String familyBackgroundFact(String status) {
    if (parentVoice) {
      return isMarathiApp
          ? '$subject यांची कौटुंबिक पार्श्वभूमी $status आहे.'
          : '$subject comes from a $status family background.';
    }
    return isMarathiApp
        ? 'कौटुंबिक पार्श्वभूमी $status आहे.'
        : 'Family background is $status.';
  }

  String familyValuesFact(String values) {
    if (parentVoice) {
      return isMarathiApp
          ? 'कौटुंबिक मूल्ये $values आहेत.'
          : 'Family values are $values.';
    }
    return isMarathiApp
        ? 'कौटुंबिक मूल्ये $values आहेत.'
        : 'Family values are $values.';
  }

  String careerFact(String label) {
    if (parentVoice) {
      return isMarathiApp
          ? (female
                ? '$subject व्यवसायाने $label या क्षेत्राशी जोडलेली आहे.'
                : '$subject व्यवसायाने $label या क्षेत्राशी जोडलेला आहे.')
          : '$subject is professionally connected with $label.';
    }
    if (isMarathiApp) {
      return female
          ? 'व्यवसायाने $label या क्षेत्राशी जोडलेली आहे.'
          : 'व्यवसायाने $label या क्षेत्राशी जोडलेला आहे.';
    }
    return 'Professionally connected with $label.';
  }

  String ageFact(int age) {
    if (parentVoice) {
      return isMarathiApp
          ? (female
                ? 'तिचे वय $age वर्षे आहे.'
                : 'त्याचे वय $age वर्षे आहे.')
          : (female
                ? 'She is $age years old.'
                : 'He is $age years old.');
    }
    return isMarathiApp
        ? 'वय $age वर्षे आहे.'
        : 'Age is $age years.';
  }

  String get _familyFirst {
    if (parentVoice) {
      return isMarathiApp
          ? '$subject साठी कुटुंब खूप मोलाचे आहे. मोकळा संवाद आणि संयम ठेवून एकमेकांचा आदर करणारा संसार व्हावा, अशी आमची इच्छा आहे.'
          : 'Family means a great deal to $subject, and we hope for a respectful partnership built on clear communication and patience.';
    }
    if (isMarathiApp) {
      return female
          ? 'कुटुंब माझ्यासाठी खूप मोलाचे आहे. मोकळा संवाद आणि संयम ठेवून एकमेकांचा आदर करणारा संसार करावा, अशी माझी इच्छा आहे.'
          : 'कुटुंब माझ्यासाठी खूप मोलाचे आहे. मोकळा संवाद आणि संयम ठेवून एकमेकांचा आदर करणारा संसार करावा, अशी माझी इच्छा आहे.';
    }
    return 'Family means a great deal to me, and I hope to build a respectful partnership with clear communication and patience.';
  }

  String get _careerBalance {
    if (parentVoice) {
      return isMarathiApp
          ? (female
                ? '$subject जबाबदाऱ्या मनापासून पार पाडते, तसेच कुटुंब, नाती आणि शांत दिनक्रम यांनाही तेवढेच महत्त्व देते.'
                : '$subject जबाबदाऱ्या मनापासून पार पाडतो, तसेच कुटुंब, नाती आणि शांत दिनक्रम यांनाही तेवढेच महत्त्व देतो.')
          : '$subject takes responsibilities seriously while keeping space for family, relationships, and a peaceful daily routine.';
    }
    if (isMarathiApp) {
      return female
          ? 'जबाबदाऱ्या मी मनापासून पार पाडते, तसेच कुटुंब, नाती आणि शांत दिनक्रम यांनाही तेवढेच महत्त्व देते.'
          : 'जबाबदाऱ्या मी मनापासून पार पाडतो, तसेच कुटुंब, नाती आणि शांत दिनक्रम यांनाही तेवढेच महत्त्व देतो.';
    }
    return 'I take responsibilities seriously while keeping space for family, relationships, and a peaceful daily routine.';
  }

  String get _tradition {
    if (parentVoice) {
      return isMarathiApp
          ? (female
                ? 'परंपरांचा $subject आदर करते, आणि मोठे निर्णय घेताना मोकळेपणाने व व्यवहारी विचाराने बोलणे तिला आवडते.'
                : 'परंपरांचा $subject आदर करतो, आणि मोठे निर्णय घेताना मोकळेपणाने व व्यवहारी विचाराने बोलणे त्याला आवडते.')
          : '$subject respects traditions and still values practical, open-minded conversations for important decisions.';
    }
    if (isMarathiApp) {
      return female
          ? 'परंपरांचा मी आदर करते, आणि मोठे निर्णय घेताना मोकळेपणाने व व्यवहारी विचाराने बोलणे मला आवडते.'
          : 'परंपरांचा मी आदर करतो, आणि मोठे निर्णय घेताना मोकळेपणाने व व्यवहारी विचाराने बोलणे मला आवडते.';
    }
    return 'I respect traditions and still value practical, open-minded conversations when important decisions need to be made.';
  }

  String get _honesty {
    if (parentVoice) {
      return isMarathiApp
          ? (female
                ? 'कागदावरच्या परिपूर्णतेपेक्षा प्रामाणिकपणा, एकमेकांबद्दलचा आदर आणि मनाची सुरक्षितता $subject ला जास्त महत्त्वाची वाटते.'
                : 'कागदावरच्या परिपूर्णतेपेक्षा प्रामाणिकपणा, एकमेकांबद्दलचा आदर आणि मनाची सुरक्षितता $subject ला जास्त महत्त्वाची वाटते.')
          : 'For $subject, honesty, mutual respect, and emotional safety matter more than perfection on paper.';
    }
    if (isMarathiApp) {
      return 'कागदावरच्या परिपूर्णतेपेक्षा प्रामाणिकपणा, एकमेकांबद्दलचा आदर आणि मनाची सुरक्षितता मला जास्त महत्त्वाची वाटते.';
    }
    return 'Honesty, mutual respect, and emotional safety matter more to me than perfection on paper.';
  }

  String get _calm {
    if (parentVoice) {
      return isMarathiApp
          ? (female
                ? '$subject यांचा स्वभाव शांत आणि स्थिर आहे. कोणतीही गोष्ट संयमाने, स्पष्टपणे आणि मायेने सोडवायला त्यांना आवडते.'
                : '$subject यांचा स्वभाव शांत आणि स्थिर आहे. कोणतीही गोष्ट संयमाने, स्पष्टपणे आणि मायेने सोडवायला त्यांना आवडते.')
          : '$subject is generally calm and steady, and prefers resolving things with patience, clarity, and kindness.';
    }
    if (isMarathiApp) {
      return female
          ? 'माझा स्वभाव शांत आणि स्थिर आहे. कोणतीही गोष्ट संयमाने, स्पष्टपणे आणि मायेने सोडवायला मला आवडते.'
          : 'माझा स्वभाव शांत आणि स्थिर आहे. कोणतीही गोष्ट संयमाने, स्पष्टपणे आणि मायेने सोडवायला मला आवडते.';
    }
    return 'I am generally calm and steady, and I prefer resolving things with patience, clarity, and kindness.';
  }

  String get _growth {
    if (parentVoice) {
      return isMarathiApp
          ? (female
                ? '$subject एकमेकांना समजून घेत, एकत्र पुढे जाणाऱ्या सोबत्याच्या शोधात आहे.'
                : '$subject एकमेकांना समजून घेत, एकत्र पुढे जाणाऱ्या सोबत्याच्या शोधात आहे.')
          : '$subject is looking for a partner to understand each other and move forward together.';
    }
    if (isMarathiApp) {
      return 'एकमेकांना समजून घेत, एकत्र पुढे जाणाऱ्या सोबत्याच्या शोधात आहे.';
    }
    return 'Looking for a partner to understand each other and move forward together.';
  }
}
