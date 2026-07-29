import 'package:flutter/material.dart';

/// Date picker that always renders its numerals in Latin 0-9.
///
/// Flutter builds the calendar's day cells, year list and header from
/// `MaterialLocalizations`, which takes its digits from the locale's number
/// symbols. Under `mr` those are Devanagari, so the picker showed २९ जुलै and
/// जुलै २००१ while the field beneath it read 29-07-2001 — the app's frozen rule
/// is that every numeral a member sees is Latin, in either language.
///
/// The picker's localisations are overridden for the duration of the dialog.
/// Its month and weekday names come from the same source, so they follow; that
/// is the cost of the guarantee, and it is confined to this one dialog — the
/// screen behind it stays in the member's language.
///
/// Every date picker in the app goes through here. Calling `showDatePicker`
/// directly reintroduces Devanagari digits on that screen alone.
Future<DateTime?> showLatinDigitDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String? helpText,
}) {
  return showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
    helpText: helpText,
    builder: (context, child) {
      if (child == null) return const SizedBox.shrink();

      return Localizations.override(
        context: context,
        locale: const Locale('en'),
        child: child,
      );
    },
  );
}
