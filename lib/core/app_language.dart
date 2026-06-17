import 'package:flutter/foundation.dart';

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
