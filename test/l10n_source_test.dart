import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the member app's Marathi source against the two defects the ARB
/// migration cleaned up, so neither can silently return.
///
/// These rules read lib/l10n/app_mr.arb directly rather than a hand-listed set
/// of getters, so a string added tomorrow is covered the moment it is written —
/// which is the only way a rule like this survives past the commit that adds it.
void main() {
  /// Words that stay in Latin script inside Marathi copy because they name
  /// themselves — brands, protocols and initialisms a Marathi speaker also
  /// writes in Latin. Anything outside this list is untranslated copy.
  const properNouns = {
    'UPI', 'QR', 'PayU', 'PayUMoney', 'OTP', 'SMS', 'WhatsApp', 'Google',
    'PDF', 'JPG', 'SIM', 'CRM', 'KYC', 'EN', 'ID', 'OK', 'JSON', 'OCR',
  };

  final entries = (jsonDecode(File('lib/l10n/app_mr.arb').readAsStringSync())
          as Map<String, dynamic>)
      .entries
      .where((e) => !e.key.startsWith('@') && e.value is String)
      .map((e) => MapEntry(e.key, e.value as String));

  test('Marathi copy uses Latin digits, not Devanagari', () {
    // Decided 2026-07-24: Marathi readers read 0-9 fluently, and one numeral
    // system keeps sorting, parsing and formatting identical across locales.
    final offenders = entries
        .where((e) => RegExp('[०-९]').hasMatch(e.value))
        .map((e) => '${e.key}: ${e.value}')
        .toList();
    expect(offenders, isEmpty,
        reason: 'Devanagari digits found — use 0-9:\n${offenders.join('\n')}');
  });

  test('no untranslated English words are left in Marathi copy', () {
    final offenders = <String>[];
    for (final e in entries) {
      // {placeholders} and $interpolations are argument names, not copy.
      final copy = e.value
          .replaceAll(RegExp(r'\{[^}]*\}'), '')
          .replaceAll(RegExp(r'\$\{[^}]*\}|\$\w+'), '');
      final words = RegExp(r'[A-Za-z]{2,}')
          .allMatches(copy)
          .map((m) => m.group(0)!)
          .where((w) => !properNouns.contains(w))
          .toList();
      if (words.isNotEmpty) offenders.add('${e.key}: ${words.join(', ')}');
    }
    expect(offenders, isEmpty,
        reason: 'English left in Marathi strings:\n${offenders.join('\n')}');
  });
}
