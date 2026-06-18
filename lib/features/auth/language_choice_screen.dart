import 'package:flutter/material.dart';

import '../../core/app_language.dart';
import '../../core/app_storage.dart';
import '../../core/app_strings.dart';

class LanguageChoiceScreen extends StatelessWidget {
  const LanguageChoiceScreen({super.key});

  Future<void> _selectLanguage(
    BuildContext context,
    AppLanguage language,
  ) async {
    setAppLanguage(language);
    await AppStorage.instance.saveLanguage(language);

    if (!context.mounted) return;

    Navigator.pushReplacementNamed(context, '/landing');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(
                Icons.favorite,
                size: 54,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 18),
              Text(
                AppStrings.appName,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 28),
              Text(
                AppStrings.chooseLanguage,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.chooseLanguageSubtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade700,
                    ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => _selectLanguage(
                  context,
                  AppLanguage.marathi,
                ),
                child: Text(AppStrings.marathi),
              ),
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: () => _selectLanguage(
                  context,
                  AppLanguage.english,
                ),
                child: Text(AppStrings.english),
              ),
              const Spacer(),
              Text(
                'Navri Mile Navryala',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
