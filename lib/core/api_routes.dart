class ApiRoutes {
  static const String baseUrl = 'https://navrimilenavryala.com/api/v1';
  static const String rootApiBaseUrl = 'https://navrimilenavryala.com/api';
  static const String login = '/login';
  static const String register = '/register';
  static const String mobileOtpSend = '/auth/mobile-otp/send';
  static const String mobileOtpVerify = '/auth/mobile-otp/verify';
  static const String accountDetails = '/account/details';
  static const String accountEmailGoogle = '/account/email/google';
  static const String accountEmailOtpSend = '/account/email-otp/send';
  static const String accountEmailOtpVerify = '/account/email-otp/verify';
  static const String locationSearch = '/location/search';
  static const String internalLocationStates = '/internal/location/states';
  static const String internalLocationDistricts =
      '/internal/location/districts';
  static const String internalLocationTalukas = '/internal/location/talukas';
  static const String internalLocationCities = '/internal/location/cities';
  static const String internalLocationChildren = '/internal/location/children';
  static const String educationDegreeSearch = '/education-degrees/search';

  // Smart Onboarding
  static const String onboardingStart = '/onboarding/start';
  static const String onboardingStatus = '/onboarding/status';
  static const String onboardingDraft = '/onboarding/draft';
  static const String onboardingProfileSaveStep =
      '/onboarding/profile/save-step';
  static const String onboardingActivationChecklist =
      '/onboarding/activation-checklist';
  static const String onboardingLookupsBootstrap =
      '/onboarding/lookups/bootstrap';
  static const String onboardingLookupsReligions =
      '/onboarding/lookups/religions';
  static const String onboardingLookupsCastes = '/onboarding/lookups/castes';
  static const String onboardingLookupsSubCastes =
      '/onboarding/lookups/sub-castes';
  static const String onboardingLookupsLocations =
      '/onboarding/lookups/locations';
  static const String onboardingLocationSuggestions =
      '/onboarding/location-suggestions';
  static const String onboardingLookupsEducation =
      '/onboarding/lookups/education';
  static const String onboardingEducationSuggestions =
      '/onboarding/education-suggestions';
  static const String onboardingLookupsWorkingWith =
      '/onboarding/lookups/working-with';
  static const String onboardingLookupsOccupations =
      '/onboarding/lookups/occupations';
  static const String onboardingOccupationSuggestions =
      '/onboarding/occupation-suggestions';
  static const String onboardingLookupsIncomeOptions =
      '/onboarding/lookups/income-options';
  static const String onboardingLookupsDiet = '/onboarding/lookups/diet';
  static const String onboardingLookupsSmoking = '/onboarding/lookups/smoking';
  static const String onboardingLookupsDrinking =
      '/onboarding/lookups/drinking';
  static const String onboardingLookupsPhysicalBuilds =
      '/onboarding/lookups/physical-builds';
  static const String onboardingLookupsSpectaclesLens =
      '/onboarding/lookups/spectacles-lens';
  static const String onboardingPreferenceAutoDraftPreview =
      '/onboarding/preferences/auto-draft/preview';
  static const String onboardingPreferenceAutoDraft =
      '/onboarding/preferences/auto-draft';
  static const String onboardingPreferenceAutoDraftStatus =
      '/onboarding/preferences/auto-draft/status';

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
  static const String profilePartnerPreferenceOptions =
      '/profile/partner-preference-options';
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

  static String onboardingDraftStep(String step) => '$onboardingDraft/$step';
}
