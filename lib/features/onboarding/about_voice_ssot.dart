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
/// - any other relation → **parent/elder voice** ("आमची मुलगी…"), gender-aware
///
/// Copy tone: short biodata / WhatsApp-style Marathi people actually write —
/// not essay language.
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

  /// Parent-voice subject ("आमची मुलगी", "Our son").
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
      'friend' => 'Our friend',
      'relative' => 'Our relative',
      _ => female ? 'Our daughter' : 'Our son',
    };
  }

  /// Short equal-length chip labels (same tile size in UI).
  List<AboutTemplateSuggestion> templates({required String factText}) {
    String body(String seed) {
      return [seed, factText].where((part) => part.trim().isNotEmpty).join(' ');
    }

    if (isMarathiApp) {
      return <AboutTemplateSuggestion>[
        AboutTemplateSuggestion(label: 'कुटुंब', text: body(_familyFirst)),
        AboutTemplateSuggestion(label: 'काम', text: body(_careerBalance)),
        AboutTemplateSuggestion(label: 'परंपरा', text: body(_tradition)),
        AboutTemplateSuggestion(label: 'प्रामाणिक', text: body(_honesty)),
        AboutTemplateSuggestion(label: 'शांत', text: body(_calm)),
        AboutTemplateSuggestion(label: 'एकत्र', text: body(_growth)),
      ];
    }

    return <AboutTemplateSuggestion>[
      AboutTemplateSuggestion(label: 'Family', text: body(_familyFirst)),
      AboutTemplateSuggestion(label: 'Work', text: body(_careerBalance)),
      AboutTemplateSuggestion(label: 'Tradition', text: body(_tradition)),
      AboutTemplateSuggestion(label: 'Honest', text: body(_honesty)),
      AboutTemplateSuggestion(label: 'Calm', text: body(_calm)),
      AboutTemplateSuggestion(label: 'Together', text: body(_growth)),
    ];
  }

  String familyBackgroundFact(String status) {
    if (parentVoice) {
      return isMarathiApp
          ? 'कुटुंब $status आहे.'
          : 'Family is $status.';
    }
    return isMarathiApp
        ? 'आमचे कुटुंब $status आहे.'
        : 'Our family is $status.';
  }

  String familyValuesFact(String values) {
    return isMarathiApp
        ? 'घरची विचारसरणी $values आहे.'
        : 'Home values are $values.';
  }

  String careerFact(String label) {
    if (parentVoice) {
      return isMarathiApp
          ? (female
                ? '$subject $label क्षेत्रात काम करते.'
                : '$subject $label क्षेत्रात काम करतो.')
          : '$subject works in $label.';
    }
    if (isMarathiApp) {
      return female ? 'मी $label क्षेत्रात काम करते.' : 'मी $label क्षेत्रात काम करतो.';
    }
    return 'I work in $label.';
  }

  String ageFact(int age) {
    if (parentVoice) {
      return isMarathiApp
          ? (female ? 'तिचे वय $age वर्षे.' : 'त्याचे वय $age वर्षे.')
          : (female ? 'She is $age.' : 'He is $age.');
    }
    return isMarathiApp ? 'माझे वय $age वर्षे.' : 'I am $age.';
  }

  String get _familyFirst {
    if (parentVoice) {
      if (isMarathiApp) {
        return female
            ? '$subject घरची आहे. कुटुंबाला खूप महत्त्व देते. चांगला संसार व्हावा अशी आमची इच्छा आहे.'
            : '$subject घरचा आहे. कुटुंबाला खूप महत्त्व देतो. चांगला संसार व्हावा अशी आमची इच्छा आहे.';
      }
      return '$subject is close to family. We want a simple, happy married life.';
    }
    if (isMarathiApp) {
      return female
          ? 'मी घरची मुलगी आहे. कुटुंबाला खूप महत्त्व देते. साधा आणि सुखी संसार हवा आहे.'
          : 'मी घरचा माणूस आहे. कुटुंबाला खूप महत्त्व देतो. साधा आणि सुखी संसार हवा आहे.';
    }
    return 'I am close to my family and want a simple, happy married life.';
  }

  String get _careerBalance {
    if (parentVoice) {
      return isMarathiApp
          ? (female
                ? '$subject कामात गांभीर्याने करते, पण घर आणि कुटुंबही तितकेच महत्त्वाचे मानते.'
                : '$subject कामात गांभीर्याने करतो, पण घर आणि कुटुंबही तितकेच महत्त्वाचे मानतो.')
          : '$subject takes work seriously, but family and home matter just as much.';
    }
    if (isMarathiApp) {
      return female
          ? 'कामात मी गांभीर्याने करते, पण घर आणि कुटुंबही तितकेच महत्त्वाचे वाटते.'
          : 'कामात मी गांभीर्याने करतो, पण घर आणि कुटुंबही तितकेच महत्त्वाचे वाटते.';
    }
    return 'I take work seriously, but family and home matter just as much.';
  }

  String get _tradition {
    if (parentVoice) {
      return isMarathiApp
          ? (female
                ? '$subject घरच्या रीतिरिवाजांचा मान ठेवते. गरज असेल तर नवीन गोष्टीही समजून घेते.'
                : '$subject घरच्या रीतिरिवाजांचा मान ठेवतो. गरज असेल तर नवीन गोष्टीही समजून घेतो.')
          : '$subject respects family traditions and is open to practical new ideas.';
    }
    if (isMarathiApp) {
      return female
          ? 'घरच्या रीतिरिवाजांचा मान ठेवते. गरज असेल तर नवीन गोष्टीही समजून घेते.'
          : 'घरच्या रीतिरिवाजांचा मान ठेवतो. गरज असेल तर नवीन गोष्टीही समजून घेतो.';
    }
    return 'I respect family traditions and I am open to practical new ideas.';
  }

  String get _honesty {
    if (parentVoice) {
      return isMarathiApp
          ? (female
                ? '$subject सरळ आणि प्रामाणिक आहे. खोट्या गोष्टी नकोत — एकमेकांचा आदर हवा, असे तिला वाटते.'
                : '$subject सरळ आणि प्रामाणिक आहे. खोट्या गोष्टी नकोत — एकमेकांचा आदर हवा, असे त्याला वाटते.')
          : '$subject is straightforward and honest. Mutual respect matters more than showing off.';
    }
    if (isMarathiApp) {
      return female
          ? 'मी सरळ आणि प्रामाणिक आहे. खोट्या गोष्टी नकोत. एकमेकांचा आदर असला पाहिजे.'
          : 'मी सरळ आणि प्रामाणिक आहे. खोट्या गोष्टी नकोत. एकमेकांचा आदर असला पाहिजे.';
    }
    return 'I am straightforward and honest. Mutual respect matters more than showing off.';
  }

  String get _calm {
    if (parentVoice) {
      return isMarathiApp
          ? (female
                ? '$subject शांत स्वभावाची आहे. गोंधळ नको — साध्या आणि समजूतदार गोष्टी आवडतात.'
                : '$subject शांत स्वभावाचा आहे. गोंधळ नको — साध्या आणि समजूतदार गोष्टी आवडतात.')
          : '$subject has a calm nature and prefers a peaceful, understanding home.';
    }
    if (isMarathiApp) {
      return female
          ? 'मी शांत स्वभावाची आहे. गोंधळ नको. साध्या आणि समजूतदार गोष्टी आवडतात.'
          : 'मी शांत स्वभावाचा आहे. गोंधळ नको. साध्या आणि समजूतदार गोष्टी आवडतात.';
    }
    return 'I have a calm nature. I prefer a peaceful, understanding home.';
  }

  String get _growth {
    if (parentVoice) {
      return isMarathiApp
          ? '$subject ला अशी जोडी हवी आहे जी एकमेकांना समजेल आणि एकत्र पुढे जाईल.'
          : 'We hope $subject finds a partner who understands and grows together.';
    }
    if (isMarathiApp) {
      return 'मला अशी जोडी हवी आहे जी एकमेकांना समजेल आणि एकत्र पुढे जाईल.';
    }
    return 'I want a partner who understands me and we can move forward together.';
  }
}
