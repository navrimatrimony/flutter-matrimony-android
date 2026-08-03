import 'api_client.dart';
import 'app_language.dart';
import 'app_storage.dart';

/// Where an authenticated member with a profile should land.
///
/// Inactive / not-searchable members always go to `/home` so they see the
/// activation coachmark instead of the daily swipe deck.
Future<String> resolveCompletedMemberRoute() async {
  try {
    final data = await ApiClient.getOnboardingStatus(
      locale: appLanguageCode(currentAppLanguage),
    );
    final profile = data['profile'];
    final searchable = data['is_searchable'] == true ||
        (profile is Map && profile['is_searchable'] == true);
    if (!searchable) {
      return '/home';
    }
  } catch (_) {
    // Fall through to the daily-recommendation rule.
  }

  final shownDate =
      await AppStorage.instance.readDailyRecommendationShownDate();
  return shownDate == _todayKey() ? '/home' : '/matches';
}

String _todayKey() {
  final now = DateTime.now();
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  return '${now.year}-$month-$day';
}
