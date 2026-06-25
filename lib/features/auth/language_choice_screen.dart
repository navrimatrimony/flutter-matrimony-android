import 'package:flutter/material.dart';

import '../../core/app_language.dart';
import '../../core/app_storage.dart';
import '../../core/app_strings.dart';

const String _languageLogoAsset = 'assets/images/navri_logo.png';

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
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              Center(
                child: Image.asset(
                  _languageLogoAsset,
                  width: 190,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 34),
              Text(
                AppStrings.chooseLanguageBilingual,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.18,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => _selectLanguage(context, AppLanguage.marathi),
                child: Text(AppStrings.marathi),
              ),
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: () => _selectLanguage(context, AppLanguage.english),
                child: Text(AppStrings.english),
              ),
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}
