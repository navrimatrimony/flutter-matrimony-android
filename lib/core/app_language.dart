import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_matrimony_android/l10n/app_localizations.dart';

enum AppLanguage {
  marathi,
  english,
}

final ValueNotifier<AppLanguage?> appLanguage = ValueNotifier<AppLanguage?>(
  null,
);

AppLanguage get currentAppLanguage =>
    appLanguage.value ?? AppLanguage.marathi;

bool get isMarathiApp => currentAppLanguage == AppLanguage.marathi;

void setAppLanguage(AppLanguage language) {
  appLanguage.value = language;
}

String appLanguageCode(AppLanguage language) {
  return language == AppLanguage.marathi ? 'mr' : 'en';
}

/// The one string source, reachable without a BuildContext.
///
/// Most copy in this app is produced by static getters (AppStrings) and inline
/// `_t(en, mr)` helpers that read [currentAppLanguage] directly, not from an
/// InheritedWidget — so they cannot call `AppLocalizations.of(context)`. Rather
/// than keep English and Marathi hand-paired in code (which does not scale past
/// two languages — a third would mean editing every call site), they read the
/// generated ARB localisations through this getter. Adding Kannada later is one
/// new `app_kn.arb` file, no code change at the call sites.
AppLocalizations get appText =>
    lookupAppLocalizations(Locale(appLanguageCode(currentAppLanguage)));

AppLanguage? appLanguageFromCode(String? code) {
  switch (code) {
    case 'mr':
      return AppLanguage.marathi;
    case 'en':
      return AppLanguage.english;
  }

  return null;
}

String? localizedMapValue(Map<String, dynamic>? row) {
  if (row == null) return null;

  final preferredKeys = isMarathiApp
      ? <String>[
          'display_label_mr',
          'label_mr',
          'name_mr',
          'name_marathi',
          'marathi_name',
        ]
      : <String>[
          'display_label_en',
          'label_en',
          'name_en',
          'name_english',
          'english_name',
        ];

  final fallbackKeys = <String>[
    'display_label',
    'label',
    'name',
  ];

  for (final key in [...preferredKeys, ...fallbackKeys]) {
    final value = row[key]?.toString().trim();
    if (value != null && value.isNotEmpty) return value;
  }

  return null;
}
