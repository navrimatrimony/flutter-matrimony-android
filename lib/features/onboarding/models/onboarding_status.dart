import 'account_state.dart';
import 'activation_checklist.dart';
import 'onboarding_draft.dart';
import 'profile_summary.dart';

class OnboardingStatus {
  const OnboardingStatus({
    required this.success,
    this.account = const <String, dynamic>{},
    this.draft,
    this.profile,
    this.hasProfile = false,
    this.profileStatus,
    this.isSearchable = false,
    this.nextStep,
    this.accountState,
    this.activationChecklist = const <ActivationChecklistItem>[],
    this.preferences,
    this.message,
    this.raw = const <String, dynamic>{},
  });

  final bool success;
  final Map<String, dynamic> account;
  final OnboardingDraft? draft;
  final ProfileSummary? profile;
  final bool hasProfile;
  final String? profileStatus;
  final bool isSearchable;
  final String? nextStep;
  final AccountState? accountState;
  final List<ActivationChecklistItem> activationChecklist;
  final Map<String, dynamic>? preferences;
  final String? message;
  final Map<String, dynamic> raw;

  factory OnboardingStatus.fromJson(Map<String, dynamic> json) {
    final account = json['account'];
    final preferences = json['preferences'];

    return OnboardingStatus(
      success: _boolValue(json['success']) ?? false,
      account: account is Map
          ? Map<String, dynamic>.from(account)
          : <String, dynamic>{},
      draft: OnboardingDraft.maybeFrom(json['draft']),
      profile: ProfileSummary.maybeFrom(json['profile']),
      hasProfile:
          _boolValue(json['has_profile'] ?? json['has_existing_profile']) ??
          false,
      profileStatus: _stringValue(json['profile_status']),
      isSearchable: _boolValue(json['is_searchable']) ?? false,
      nextStep: _stringValue(json['next_step']),
      accountState: AccountState.maybeFrom(json['account_state']),
      activationChecklist: ActivationChecklistItem.listFrom(
        json['activation_checklist'] ?? json['items'],
      ),
      preferences: preferences is Map
          ? Map<String, dynamic>.from(preferences)
          : null,
      message: _stringValue(json['message']),
      raw: Map<String, dynamic>.from(json),
    );
  }
}

String? _stringValue(dynamic value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  return text;
}

bool? _boolValue(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value?.toString().trim().toLowerCase();
  if (text == null || text.isEmpty) return null;
  if (text == '1' || text == 'true' || text == 'yes') return true;
  if (text == '0' || text == 'false' || text == 'no') return false;
  return null;
}
