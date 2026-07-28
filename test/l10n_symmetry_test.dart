import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_matrimony_android/core/api_client.dart';
import 'package:flutter_matrimony_android/core/app_language.dart';
import 'package:flutter_matrimony_android/core/app_storage.dart';
import 'package:flutter_matrimony_android/l10n/app_localizations.dart';
import 'package:flutter_matrimony_android/features/matrimony_profile/profile_detail_screen.dart';
import 'package:flutter_matrimony_android/features/matrimony_profile/view_profile_screen.dart';

/// Guards the symmetry rule: a Marathi user sees only Marathi, an English user
/// sees only English. `l10n_source_test.dart` already guards the Marathi side
/// (no stray English, no Devanagari digits); this file guards the English side
/// and the call sites that used to bypass the ARB entirely.
void main() {
  final devanagari = RegExp(r'[ऀ-ॿ]');

  Map<String, String> readArb(String path) {
    final decoded =
        jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

    return <String, String>{
      for (final entry in decoded.entries)
        if (!entry.key.startsWith('@') && entry.value is String)
          entry.key: entry.value as String,
    };
  }

  final en = readArb('lib/l10n/app_en.arb');
  final mr = readArb('lib/l10n/app_mr.arb');

  group('ARB source symmetry', () {
    test('English copy contains no Devanagari', () {
      // The mirror of the Marathi rule in l10n_source_test.dart. Five entries
      // shipped Marathi (or Marathi/English code-mix) straight into the English
      // UI before this guard existed.
      final offenders = en.entries
          .where((e) => devanagari.hasMatch(e.value))
          .map((e) => '${e.key}: ${e.value}')
          .toList();

      expect(
        offenders,
        isEmpty,
        reason:
            'Devanagari found in app_en.arb — English users would see Marathi:'
            '\n${offenders.join('\n')}',
      );
    });

    test('every key exists in both locales', () {
      expect(
        mr.keys.toSet().difference(en.keys.toSet()),
        isEmpty,
        reason: 'Keys present in app_mr.arb but missing from app_en.arb',
      );
      expect(
        en.keys.toSet().difference(mr.keys.toSet()),
        isEmpty,
        reason: 'Keys present in app_en.arb but missing from app_mr.arb',
      );
    });

    test('English copy uses Latin digits, not Devanagari', () {
      // FROZEN workspace rule: every user-facing numeral is 0-9 in any locale.
      final offenders = en.entries
          .where((e) => RegExp('[०-९]').hasMatch(e.value))
          .map((e) => '${e.key}: ${e.value}')
          .toList();

      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });

  group('formerly hardcoded labels now resolve from localization', () {
    final marathi = lookupAppLocalizations(const Locale('mr'));
    final english = lookupAppLocalizations(const Locale('en'));

    test('Marathi wording is preserved byte-for-byte', () {
      // These strings used to be baked into the widget tree. Moving them into
      // the ARB must not change a single character of what a Marathi user reads.
      expect(marathi.community, 'समुदाय');
      expect(marathi.profilePreview, 'प्रोफाइल झलक');
      expect(marathi.profileInformation, 'प्रोफाइल माहिती');
      expect(marathi.photoNotAddedYet, 'फोटो अजून जोडलेला नाही');
      expect(marathi.nameNotAvailable, 'नाव उपलब्ध नाही');
      expect(marathi.profileNotFound, 'प्रोफाइल सापडली नाही.');
      expect(marathi.pleaseTryAgain, 'कृपया पुन्हा प्रयत्न करा.');
      expect(marathi.signUpWithGoogle, 'Google ने सुरू करा');
      expect(marathi.signUpWithMobile, 'मोबाइल नंबरने सुरू करा');
      expect(marathi.retry, 'पुन्हा प्रयत्न करा');
      expect(marathi.unexpectedErrorOccurred('boom'), 'एक अनपेक्षित एरर आली: boom');
      expect(marathi.sectionSavedNamed('मूलभूत माहिती'), 'मूलभूत माहिती जतन झाले.');
      expect(marathi.testOtpLabel('123456'), 'चाचणी OTP: 123456');
      expect(marathi.nearbyTalukasCount(3), '3 जवळचे तालुके');
      expect(marathi.districtsCount(2), '2 जिल्हे');
      expect(marathi.statesCount(4), '4 राज्ये');
      expect(marathi.countriesCount(5), '5 देश');
    });

    test('the same labels come back in English for an English user', () {
      final rendered = <String>[
        english.community,
        english.profilePreview,
        english.profileInformation,
        english.photoNotAddedYet,
        english.nameNotAvailable,
        english.profileNotFound,
        english.pleaseTryAgain,
        english.signUpWithGoogle,
        english.signUpWithMobile,
        english.retry,
        english.couldNotLoadProfile,
        english.photoUnavailable,
        english.unexpectedErrorOccurred('boom'),
        english.sectionSavedNamed('Basic details'),
        english.testOtpLabel('123456'),
        english.nearbyTalukasCount(3),
        english.districtsCount(2),
        english.statesCount(4),
        english.countriesCount(5),
      ];

      for (final value in rendered) {
        expect(
          devanagari.hasMatch(value),
          isFalse,
          reason: 'English lookup returned Devanagari: $value',
        );
      }
    });

    test('counts stay in Latin digits in both locales', () {
      // Guards against a locale-aware NumberFormat sneaking in and rendering
      // ३ instead of 3 for the mr locale.
      expect(marathi.nearbyTalukasCount(3), contains('3'));
      expect(marathi.districtsCount(12), contains('12'));
      expect(english.districtsCount(12), contains('12'));
      expect(RegExp('[०-९]').hasMatch(marathi.statesCount(7)), isFalse);
    });
  });

  testWidgets('profile detail screen renders no Devanagari in English', (
    WidgetTester tester,
  ) async {
    AppStorage.instance = AppStorage.memory();
    setAppLanguage(AppLanguage.english);

    // Seeded locally so the screen paints its real content without waiting on
    // the API — the network call in initState fails harmlessly under test.
    const profileId = 4242;
    await tester.pumpWidget(
      const MaterialApp(
        home: ProfileDetailScreen(
          profileId: profileId,
          initialProfile: <String, dynamic>{
            'id': profileId,
            'full_name': 'Asha Patil',
            'date_of_birth': '1996-04-12',
            'height_label': '5 ft 4 in',
            'education': 'B.Com',
            'occupation': 'Accountant',
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final offenders = <String>[];
    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      final value = text.data;
      if (value != null && devanagari.hasMatch(value)) offenders.add(value);
    }
    for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
      final value = rich.text.toPlainText();
      if (devanagari.hasMatch(value)) offenders.add(value);
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Marathi leaked into the English profile detail screen:'
          '\n${offenders.join('\n')}',
    );
  });

  testWidgets('own profile renders no English labels in Marathi', (
    WidgetTester tester,
  ) async {
    // The mirror of the test above, and the one that was missing: until it
    // existed, `Text('Family Details')` written today shipped untested and a
    // Marathi member read her own profile in English.
    //
    // Every seeded value is Marathi or a number on purpose, so any Latin word
    // left on screen can only have come from a hardcoded label.
    AppStorage.instance = AppStorage.memory();
    setAppLanguage(AppLanguage.marathi);
    ApiClient.currentUserProfile = <String, dynamic>{
      'id': 4242,
      'full_name': 'आशा पाटील',
      'gender_label': 'स्त्री',
      'marital_status_key': 'unmarried',
      'marital_status_label': 'अविवाहित',
      'mother_tongue_label': 'मराठी',
      'complexion_label': 'गोरा',
      'blood_group_label': 'ओ पॉझिटिव्ह',
      'diet_label': 'शाकाहारी',
      'occupation_master_label': 'शिक्षिका',
      'company_name': 'जिल्हा परिषद',
      'father_name': 'रामराव पाटील',
      'mother_name': 'सुनीता पाटील',
      'family_type_label': 'एकत्र कुटुंब',
      'family_status': 'मध्यमवर्गीय',
      'rashi_label': 'मेष',
      'nakshatra_label': 'अश्विनी',
      'gotra': 'कश्यप',
      'property_details': 'शेती',
      'other_relatives_text': 'काका',
      'narrative_about_me': 'माझ्याबद्दल थोडक्यात.',
      'siblings': const <dynamic>[],
      'preferred_age_min': 24,
      'preferred_age_max': 30,
    };
    addTearDown(() {
      ApiClient.currentUserProfile = null;
      setAppLanguage(AppLanguage.english);
    });

    await tester.pumpWidget(const MaterialApp(home: ViewProfileScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final latinWord = RegExp('[A-Za-z]{2,}');
    final offenders = <String>[];
    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      final value = text.data;
      if (value == null) continue;
      final words = latinWord
          .allMatches(value)
          .map((m) => m.group(0)!)
          .where((word) => !latinAllowed.contains(word))
          .toList();
      if (words.isNotEmpty) offenders.add('$value  ->  ${words.join(', ')}');
    }

    expect(
      offenders,
      isEmpty,
      reason: 'English left on the Marathi My Profile screen:'
          '\n${offenders.join('\n')}',
    );
  });

  test('bilingual helpers are never handed the same string twice', () {
    // `_readinessCopy('Family Details', 'Family Details')` type-checks, reads
    // as translated, and returns English forever. Eight dashboard rows and
    // seven filter labels shipped that way, so the shape is worth a guard of
    // its own — the helper cannot detect it, only the source can.
    final call = RegExp(
      r"_(?:t|text|copy|readinessCopy)\(\s*'([^'\\]*)'\s*,\s*'([^'\\]*)'\s*\)",
    );
    final latinWord = RegExp('[A-Za-z]{2,}');

    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      for (final match in call.allMatches(source)) {
        // `$interpolations` are variable names, not copy — '₹$value' says
        // nothing in either language and must not count as English.
        final marathi = match
            .group(2)!
            .replaceAll(RegExp(r'\$\{[^}]*\}|\$\w+'), '');
        if (devanagari.hasMatch(marathi)) continue;
        if (!latinWord.hasMatch(marathi)) continue; // '₹1200', '5/7' and such
        final line = '\n'.allMatches(source.substring(0, match.start)).length + 1;
        offenders.add('${entity.path}:$line  ${match.group(0)}');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'English passed as the Marathi argument:\n${offenders.join('\n')}',
    );
  });
}

/// Latin runs a Marathi screen may legitimately show: brands and initialisms
/// that name themselves, plus the unit tokens the height/weight formatters
/// emit. Everything else is untranslated copy.
const latinAllowed = <String>{
  'UPI', 'QR', 'PayU', 'PayUMoney', 'OTP', 'SMS', 'WhatsApp', 'Google',
  'PDF', 'JPG', 'SIM', 'CRM', 'KYC', 'EN', 'ID', 'OK', 'JSON', 'OCR',
  'cm', 'kg', 'ft', 'in',
};
