/// Canonical client-side home for turning whatever a member typed (or whatever
/// the SIM hint handed back) into the bare 10-digit Indian mobile number the
/// API expects.
///
/// Mirrors `App\Support\MobileNumber::normalize()` on the Laravel side, which
/// is the real authority — this only spares the member a rejected request for
/// input the server would have normalised anyway (`+91`, `0`, spaces, dashes).
class MobileNumberInput {
  const MobileNumberInput._();

  /// Digits only, `+91`/`91`/leading-zero prefixes dropped, trimmed to the last
  /// 10 digits. Returns whatever is left — callers decide whether a result of
  /// length 10 is required.
  static String normalize(String value) {
    var digits = value.replaceAll(RegExp(r'\D'), '');

    if (digits.length == 12 && digits.startsWith('91')) {
      digits = digits.substring(2);
    }
    if (digits.length > 10) {
      digits = digits.substring(digits.length - 10);
    }

    return digits;
  }

  /// True when [value] normalises to a complete 10-digit mobile number.
  static bool isComplete(String value) => normalize(value).length == 10;
}
