class AccountState {
  const AccountState({
    this.isNewAccount = false,
    this.hasProfile = false,
    this.nextAction,
    this.raw = const <String, dynamic>{},
  });

  final bool isNewAccount;
  final bool hasProfile;
  final String? nextAction;
  final Map<String, dynamic> raw;

  factory AccountState.fromJson(Map<String, dynamic>? json) {
    final source = json ?? <String, dynamic>{};
    return AccountState(
      isNewAccount: _boolValue(source['is_new_account']) ?? false,
      hasProfile: _boolValue(source['has_profile']) ?? false,
      nextAction: _stringValue(source['next_action']),
      raw: Map<String, dynamic>.from(source),
    );
  }

  static AccountState? maybeFrom(dynamic value) {
    if (value is Map) {
      return AccountState.fromJson(Map<String, dynamic>.from(value));
    }
    return null;
  }

  static String? _stringValue(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  static bool? _boolValue(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().trim().toLowerCase();
    if (text == null || text.isEmpty) return null;
    if (text == '1' || text == 'true' || text == 'yes') return true;
    if (text == '0' || text == 'false' || text == 'no') return false;
    return null;
  }
}
