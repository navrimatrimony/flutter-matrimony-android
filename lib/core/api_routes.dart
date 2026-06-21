class ApiRoutes {
  static const String baseUrl = 'https://navrimilenavryala.com/api/v1';
  static const String rootApiBaseUrl = 'https://navrimilenavryala.com/api';
  static const String login = '/login';
  static const String register = '/register';
  static const String locationSearch = '/location/search';
  static const String educationDegreeSearch = '/education-degrees/search';

  // Matrimony Profile
  static const String matrimonyProfile = '/matrimony-profile';
  static const String matrimonyProfilePhoto = '/matrimony-profile/photo';
  static const String matrimonyProfiles = '/matrimony-profiles'; // For listing
  static const String matrimonyProfileMoreSections =
      '/matrimony-profiles/more-sections';
  static const String profileBasicPhysicalOptions =
      '/profile/basic-physical-options';
  static const String profileEducationCareerOptions =
      '/profile/education-career-options';
  static const String profileMaritalLifestyleOptions =
      '/profile/marital-lifestyle-options';
  static const String profileRemainingProfileOptions =
      '/profile/remaining-profile-options';
  static const String religions = '/religions';
  static const String genders = '/genders';
  static const String castes = '/castes';
  static const String subCastes = '/sub-castes';

  // Interests
  static const String interests = '/interests';
  static const String interestsSent = '/interests/sent';
  static const String interestsReceived = '/interests/received';
  static const String abuseReports = '/abuse-reports';

  static String profileShortlist(int profileId) =>
      '$matrimonyProfiles/$profileId/shortlist';

  static String profileHide(int profileId) =>
      '$matrimonyProfiles/$profileId/hide';

  static String profileBlock(int profileId) =>
      '$matrimonyProfiles/$profileId/block';
}
