import 'app_language.dart';

class AppStrings {
  static bool get _mr => isMarathiApp;

  static String get appName =>
      appText.appName;

  static bool get isMarathi => _mr;

  static String get chooseLanguage => appText.chooseLanguage;

  static String get chooseLanguageBilingual => 'भाषा निवडा\nChoose language';

  static String get languageMenu => appText.languageMenu;

  static String get languageSwitchSubtitle =>
      appText.languageSwitchSubtitle;

  static String get marathi => 'मराठी';

  static String get english => 'English';

  static String get landingHeadline => appText.landingHeadline;

  static String get landingSubline => appText.landingSubline;

  static String get safeProfiles => appText.safeProfiles;

  static String get familyFriendly =>
      appText.familyFriendly;

  static String get simpleProcess =>
      appText.simpleProcess;

  static String get register => appText.register;

  static String get login => appText.login;

  static String get loginWelcomeTitle =>
      appText.loginWelcomeTitle;

  static String get loginWelcomeSubtitle => appText.loginWelcomeSubtitle;

  static String get loginIdentifierLabel =>
      appText.loginIdentifierLabel;

  static String get loginPasswordLabel => appText.loginPasswordLabel;

  static String get loginShowPassword =>
      appText.loginShowPassword;

  static String get loginHidePassword => appText.loginHidePassword;

  static String get loginKeepSignedIn =>
      appText.loginKeepSignedIn;

  static String get loginKeepSignedInSubtitle => appText.loginKeepSignedInSubtitle;

  static String get loginMissingFields =>
      appText.loginMissingFields;

  static String get loginSuccess =>
      appText.loginSuccess;

  static String get loginProfileMissing => appText.loginProfileMissing;

  static String get loginProfileCheckFailed => appText.loginProfileCheckFailed;

  static String get loginFailed => appText.loginFailed;

  static String get loginRegisterPrompt =>
      appText.loginRegisterPrompt;

  // Mobile-OTP login. Registration has always signed members in with an OTP;
  // these are the strings that let the login screen offer the same door.

  static String get loginMobileHint => appText.loginMobileHint;

  static String get loginOtpSentHint => appText.loginOtpSentHint;

  static String get loginOtpWhatsappHint => appText.loginOtpWhatsappHint;

  static String get loginOtpAutoFillHint => appText.loginOtpAutoFillHint;

  static String get loginTestOtpBanner => appText.loginTestOtpBanner;

  static String get loginChangeMobile => appText.loginChangeMobile;

  static String get loginPickFromSim => appText.loginPickFromSim;

  static String get loginNetworkError => appText.loginNetworkError;

  static String get loginUseOtpInstead => appText.loginUseOtpInstead;

  static String get loginUsePasswordInstead => appText.loginUsePasswordInstead;

  static String get loginMobileLabel => appText.mobileNumber2;

  static String get loginOtpLabel => appText.enterThe6DigitOtp2;

  static String get loginSendOtp => appText.getOtp;

  static String get loginVerifyOtp => appText.verifyOtp;

  static String get loginOtpInvalidLength => appText.enterThe6DigitOtp;

  static String get loginMobileInvalid => appText.enterAValid10DigitMobile;

  static String get loginOtpSendFailed => appText.couldNotSendOtp;

  static String get loginOtpVerifyFailed => appText.otpVerificationFailed;

  static String get loginConsentPrefix => appText.byContinuingIAgreeToThe;

  static String get loginConsentAnd => appText.and;

  static String get loginConsentSuffix => appText.str;

  static String loginResendInSeconds(int seconds) =>
      // Latin digits, always. `seconds.toString()` is deliberate — an int
      // placeholder would go through intl's locale-aware number formatter and
      // render ३० for a Marathi member.
      appText.loginResendInSeconds(seconds.toString());

  static String loginTestOtpLabel(String otp) => appText.testOtpLabel(otp);

  static String get logoutToExit => appText.logoutToExit;

  static String get dashboard => appText.dashboard;

  static String get dashboardHeadline => appText.dashboardHeadline;

  static String get dashboardSubtitle => appText.dashboardSubtitle;

  static String dashboardGreeting(String name) =>
      _mr ? 'नमस्कार, $name!' : 'Hello, $name!';

  static String get dashboardHeroFallback => appText.dashboardHeroFallback;

  static String get dashboardPremiumMember =>
      appText.dashboardPremiumMember;

  static String get dashboardFreePlan => appText.dashboardFreePlan;

  static String get dashboardProfileActive =>
      appText.dashboardProfileActive;

  static String get dashboardProfileMissing =>
      appText.dashboardProfileMissing;

  static String get dashboardPhotoMissing =>
      appText.dashboardPhotoMissing;

  static String get dashboardPhotoPending =>
      appText.dashboardPhotoPending;

  static String get dashboardPhotoApproved =>
      appText.dashboardPhotoApproved;

  static String get dashboardViewMatches => appText.dashboardViewMatches;

  static String get dashboardChangePlan => appText.dashboardChangePlan;

  static String dashboardContactCreditsRemaining(int count) =>
      _mr ? 'संपर्क क्रेडिट: $count शिल्लक' : 'Contact credits: $count left';

  static String get dashboardNextBestAction =>
      appText.dashboardNextBestAction;

  static String get dashboardCreateProfile =>
      appText.dashboardCreateProfile;

  static String get dashboardCreateProfileSubtitle => appText.dashboardCreateProfileSubtitle;

  static String get dashboardUploadPhotoPrompt => appText.dashboardUploadPhotoPrompt;

  static String get dashboardPhotoPendingSubtitle => appText.dashboardPhotoPendingSubtitle;

  static String get dashboardCompleteProfile =>
      appText.dashboardCompleteProfile;

  static String get dashboardCompleteProfileSubtitle => appText.dashboardCompleteProfileSubtitle;

  static String get dashboardRespondInterests =>
      appText.dashboardRespondInterests;

  static String get dashboardRespondInterestsSubtitle => appText.dashboardRespondInterestsSubtitle;

  static String get dashboardReplyMessages =>
      appText.dashboardReplyMessages;

  static String get dashboardReplyMessagesSubtitle => appText.dashboardReplyMessagesSubtitle;

  static String get dashboardReviewContactRequests =>
      appText.dashboardReviewContactRequests;

  static String get dashboardReviewContactRequestsSubtitle => appText.dashboardReviewContactRequestsSubtitle;

  static String get dashboardCheckNotifications =>
      appText.dashboardCheckNotifications;

  static String get dashboardCheckNotificationsSubtitle => appText.dashboardCheckNotificationsSubtitle;

  static String get dashboardUpgradePlan =>
      appText.dashboardUpgradePlan;

  static String get dashboardUpgradePlanSubtitle => appText.dashboardUpgradePlanSubtitle;

  static String get dashboardViewMatchesSubtitle => appText.dashboardViewMatchesSubtitle;

  static String get dashboardQuickActions =>
      appText.dashboardQuickActions;

  static String get dashboardReadiness =>
      appText.dashboardReadiness;

  static String get dashboardReadinessSubtitle => appText.dashboardReadinessSubtitle;

  static String get dashboardReady => appText.dashboardReady;

  static String get dashboardNeedsAttention =>
      appText.dashboardNeedsAttention;

  static String get dashboardAddNow => appText.dashboardAddNow;

  static String get dashboardBasicDetails =>
      appText.dashboardBasicDetails;

  static String get dashboardPhoto => appText.dashboardPhoto;

  static String get dashboardLocationDetails =>
      appText.dashboardLocationDetails;

  static String get dashboardEducationCareer =>
      appText.dashboardEducationCareer;

  static String get dashboardPartnerPreference =>
      appText.dashboardPartnerPreference;

  static String get dashboardPlanContact =>
      appText.dashboardPlanContact;

  static String get dashboardActivity =>
      appText.dashboardActivity;

  static String get dashboardAccountTools =>
      appText.dashboardAccountTools;

  static String get dashboardPlanToolSubtitle => appText.dashboardPlanToolSubtitle;

  static String get dashboardListsToolSubtitle =>
      appText.dashboardListsToolSubtitle;

  static String get dashboardSettingsToolSubtitle =>
      appText.dashboardSettingsToolSubtitle;

  static String get featureNotAvailable => appText.featureNotAvailable;

  static String get browseProfiles => appText.bottomMatches;

  static String get browseProfilesSubtitle => appText.browseProfilesSubtitle;

  static String get matchesTabSearch => appText.matchesTabSearch;

  static String get matchesTabNew => appText.matchesTabNew;

  static String get matchesTabDaily => appText.matchesTabDaily;

  static String get matchesTabMyMatches =>
      appText.matchesTabMyMatches;

  static String get matchesTabNearMe => appText.matchesTabNearMe;

  static String get matchesTabMore => appText.matchesTabMore;

  static String get matchesFilter => appText.matchesFilter;

  static String get matchesFilterHint =>
      appText.matchesFilterHint;

  static String get chooseLocationForNearMe => appText.chooseLocationForNearMe;

  static String get chooseLocationFilter =>
      appText.chooseLocationFilter;

  static String get membersYouMayLike =>
      appText.membersYouMayLike;

  static String get moreProfilesYouMayLike =>
      appText.moreProfilesYouMayLike;

  static String get premiumProfiles =>
      appText.premiumProfiles;

  static String get premiumProfilesSubtitle =>
      appText.premiumProfilesSubtitle;

  static String get profilesFromSearch =>
      appText.profilesFromSearch;

  static String moreMatchesSectionTitle(String key, String? targetGender) {
    final target = targetGender?.trim().toLowerCase();
    final bride = target == 'female';
    final groom = target == 'male';

    switch (key) {
      case 'looking_for_me':
        if (_mr) {
          if (bride) return 'माझ्या शोधात असलेल्या वधू';
          if (groom) return 'माझ्या शोधात असलेले वर';
          return 'माझ्या शोधात असलेली स्थळे';
        }
        if (bride) return 'Brides looking for me';
        if (groom) return 'Grooms looking for me';
        return 'Profiles looking for me';
      case 'recently_viewed':
        if (_mr) {
          if (bride) return 'अलीकडे पाहिलेल्या वधू';
          if (groom) return 'अलीकडे पाहिलेले वर';
          return 'अलीकडे पाहिलेली स्थळे';
        }
        if (bride) return 'Recently viewed Brides';
        if (groom) return 'Recently viewed Grooms';
        return 'Recently viewed Profiles';
      case 'matching_my_preference':
        if (_mr) {
          if (bride) return 'माझ्या पसंतीशी जुळणाऱ्या वधू';
          if (groom) return 'माझ्या पसंतीशी जुळणारे वर';
          return 'माझ्या पसंतीशी जुळणारी स्थळे';
        }
        if (bride) return 'Brides matching my preference';
        if (groom) return 'Grooms matching my preference';
        return 'Profiles matching my preference';
      case 'nearby':
        if (_mr) {
          if (bride) return 'जवळच्या वधू';
          if (groom) return 'जवळचे वर';
          return 'जवळची स्थळे';
        }
        if (bride) return 'Nearby Brides';
        if (groom) return 'Nearby Grooms';
        return 'Nearby profiles';
      case 'recent_visitors':
        if (_mr) {
          if (bride) return 'अलीकडील भेट देणाऱ्या वधू';
          if (groom) return 'अलीकडील भेट देणारे वर';
          return 'अलीकडील भेट देणारी स्थळे';
        }
        return 'Recent visitors';
      case 'you_may_like':
        if (_mr) {
          if (bride) return 'तुम्हाला आवडू शकणाऱ्या वधू';
          if (groom) return 'तुम्हाला आवडू शकणारे वर';
          return 'तुम्हाला आवडू शकणारी स्थळे';
        }
        if (bride) return 'Brides you may like';
        if (groom) return 'Grooms you may like';
        return 'Profiles you may like';
    }

    return appText.matchesTabMore;
  }

  static String moreMatchesSectionSubtitle(String key) {
    switch (key) {
      case 'looking_for_me':
        return appText.profilesWhosePreferencesMayMatchYou;
      case 'recently_viewed':
        return appText.profilesYouViewedRecently;
      case 'matching_my_preference':
        return appText.basedOnYourPartnerPreferences;
      case 'nearby':
        return appText.profilesCloserToYourLocation;
      case 'recent_visitors':
        return appText.seeWhoViewedYourProfile;
      case 'you_may_like':
        return appText.suggestedProfilesForYou;
    }

    return '';
  }

  static String get upgradeToSeeVisitors =>
      appText.upgradeToSeeVisitors;

  static String get recentVisitorsEmpty => appText.recentVisitorsEmpty;

  static String get upgrade => appText.upgrade;

  static String get bottomHome => appText.bottomHome;

  static String get bottomMatches => appText.bottomMatches;

  static String get bottomConnect => appText.bottomConnect;

  static String get bottomChat => appText.chatMenu;

  static String get connectReceived => appText.connectReceived;

  static String get connectSent => appText.connectSent;

  static String get connectContactRequests => appText.connectContactRequests;

  static String get connectUpgrade => appText.connectUpgrade;

  static String get contactRequests =>
      appText.contactRequests;

  static String get plansTitle => appText.plansTitle;

  static String get plansUpgradeMenu =>
      appText.plansUpgradeMenu;

  static String get plansCurrentPlan => appText.plansCurrentPlan;

  static String get plansAvailablePlans =>
      appText.plansAvailablePlans;

  static String get plansRefresh => appText.plansRefresh;

  static String get plansChoose => appText.plansChoose;

  static String get plansOpeningCheckout =>
      appText.plansOpeningCheckout;

  static String get plansEmpty => appText.plansEmpty;

  static String get plansNoCurrentPlan =>
      appText.plansNoCurrentPlan;

  static String get plansContactQuota =>
      appText.plansContactQuota;

  static String get plansRemaining => appText.plansRemaining;

  static String get plansManualRefreshHint => appText.plansManualRefreshHint;

  static String get plansBrowserNote => appText.plansBrowserNote;

  static String get plansCheckoutUrlMissing => appText.plansCheckoutUrlMissing;

  static String get plansOpenFailedCopied => appText.plansOpenFailedCopied;

  static String get plansLoadFailed =>
      appText.plansLoadFailed;

  static String get plansFreeOrLocked =>
      appText.plansFreeOrLocked;

  static String get plansActiveSubscription =>
      appText.plansActiveSubscription;

  static String get biodataExportTitle =>
      appText.biodataExportMenu;

  static String get biodataExportMenu =>
      appText.biodataExportMenu;

  static String get biodataPrintAction =>
      appText.biodataPrintAction;

  static String get biodataExportSubtitle => appText.biodataExportSubtitle;

  static String get biodataExportTemplate =>
      appText.biodataExportTemplate;

  static String get biodataTemplateDesignPreview =>
      appText.biodataTemplateDesignPreview;

  static String get biodataTemplateWithPhoto => appText.biodataTemplateWithPhoto;

  static String get biodataTemplateNoPhoto => appText.biodataTemplateNoPhoto;

  static String get biodataTemplatePremium => appText.biodataTemplatePremium;

  static String get biodataTemplateLocked => appText.biodataTemplateLocked;

  static String biodataTemplateOrientation(String orientation) {
    final normalized = orientation.trim().toLowerCase();
    if (normalized == 'landscape') {
      return appText.a4Landscape;
    }

    return appText.a4Portrait;
  }

  static String biodataTemplateLabel(String key, String fallback) {
    if (!_mr) return fallback;

    return switch (key) {
      'classic_portrait_photo' => 'क्लासिक फोटो',
      'classic_portrait_no_photo' => 'क्लासिक फोटोशिवाय',
      'parichay_patra_photo' => 'पारंपरिक परिचय पत्र',
      'photo_side_biodata' => 'फोटो साइड बायोडाटा',
      'simple_landscape_no_photo' => appText.plainLandscape,
      'double_portrait_photo' => appText.doubleBorderPortrait,
      'royal_landscape_photo' => appText.royalLandscape,
      _ => fallback,
    };
  }

  static String biodataTemplateDescription(String key, String fallback) {
    if (!_mr) return fallback;

    return switch (key) {
      'classic_portrait_photo' =>
        appText.cleanBorderPhotoRightA4Portrait,
      'classic_portrait_no_photo' =>
        'फोटोशिवाय साधा, वाचायला सोपा A4 बायोडाटा.',
      'parichay_patra_photo' =>
        appText.traditionalColorsDecorativeBorder,
      'photo_side_biodata' =>
        appText.landscapeLayoutLargePhotoCompact,
      'simple_landscape_no_photo' =>
        appText.professionalLandscapeBiodataNoPhoto,
      'double_portrait_photo' =>
        appText.premiumDoubleBorderElegantA4Portrait,
      'royal_landscape_photo' => appText.premiumRoyalStyleLandscape,
      _ => fallback,
    };
  }

  static String get biodataExportFormat =>
      appText.biodataExportFormat;

  static String get biodataExportPdf => 'PDF';

  static String get biodataExportJpg => 'JPG';

  static String get biodataExportDownload => appText.biodataExportDownload;

  static String get biodataExportShare => appText.biodataExportShare;

  static String get biodataExportWarnings =>
      appText.biodataExportWarnings;

  static String get biodataExportLoadFailed => appText.biodataExportLoadFailed;

  static String get biodataExportFailed =>
      appText.biodataExportFailed;

  static String get biodataExportUnavailable => appText.biodataExportUnavailable;

  static String get biodataExportLinkMissing => appText.biodataExportLinkMissing;

  static String get biodataExportBrowserOpened => appText.biodataExportBrowserOpened;

  static String get biodataExportOpenFailedCopied => appText.biodataExportOpenFailedCopied;

  static String get biodataExportShared =>
      appText.biodataExportShared;

  static String get biodataExportLinkExpires => appText.biodataExportLinkExpires;

  static String get biodataGeneratedTitle =>
      appText.biodataGeneratedTitle;

  static String get biodataGeneratedSubtitle => appText.biodataGeneratedSubtitle;

  static String get biodataPreviewAction =>
      appText.biodataPreviewAction;

  static String get biodataCopyLink => appText.biodataCopyLink;

  static String get biodataLinkCopied =>
      appText.biodataLinkCopied;

  static String get biodataExpiresAt =>
      appText.biodataExpiresAt;

  static String get biodataIntakeTitle =>
      appText.biodataIntakeMenu;

  static String get biodataIntakeMenu =>
      appText.biodataIntakeMenu;

  static String get biodataIntakeSubtitle => appText.biodataIntakeSubtitle;

  static String get biodataIntakeIntroTitle =>
      appText.biodataIntakeIntroTitle;

  static String get biodataIntakeIntroSubtitle => appText.biodataIntakeIntroSubtitle;

  static List<String> get biodataIntakeProcessingMessages => _mr
      ? <String>[
          'बायोडाटा प्रोसेस होत आहे...',
          'मजकूर वाचत आहोत...',
          'माहिती व्यवस्थित फॉरमॅट करत आहोत...',
          appText.preparingReviewScreen,
        ]
      : <String>[
          'Processing biodata...',
          'Reading text from the photo...',
          'Formatting the information...',
          'Preparing the review screen...',
        ];

  static String get biodataIntakeReviewTitle =>
      appText.biodataIntakeReviewTitle;

  static String get biodataIntakeReviewSubtitle => appText.biodataIntakeReviewSubtitle;

  static String get biodataIntakeQualitySignals =>
      appText.biodataIntakeQualitySignals;

  static String get biodataIntakeLowConfidence =>
      appText.biodataIntakeLowConfidence;

  static String get biodataIntakeCheckLowConfidenceFields =>
      appText.biodataIntakeCheckLowConfidenceFields;

  static String get biodataIntakeFailureCodes =>
      appText.biodataIntakeFailureCodes;

  static String get biodataIntakeOverallQuality =>
      appText.biodataIntakeOverallQuality;

  static String get biodataIntakeExtractedText =>
      appText.biodataIntakeExtractedText;

  static String get biodataIntakeConfirmSave =>
      appText.biodataIntakeConfirmSave;

  static String get biodataIntakeSaveReview =>
      appText.biodataIntakeSaveReview;

  static String get biodataIntakeTryAnother =>
      appText.biodataIntakeTryAnother;

  static String get biodataIntakeNoReadableText => appText.biodataIntakeNoReadableText;

  static String get biodataIntakeProcessFailed => appText.biodataIntakeProcessFailed;

  static String get biodataIntakeSaveSuccess => appText.biodataIntakeSaveSuccess;

  static String get biodataIntakeSavePending => appText.biodataIntakeSavePending;

  static String get biodataIntakeSaveFailed =>
      appText.biodataIntakeSaveFailed;

  static String get biodataIntakeReviewSaveSuccess => appText.biodataIntakeReviewSaveSuccess;

  static String get biodataIntakeReviewSaveFailed =>
      appText.biodataIntakeReviewSaveFailed;

  static String get biodataIntakeAlreadyApprovedLocked => appText.biodataIntakeAlreadyApprovedLocked;

  static String get biodataIntakeFieldsEmpty => appText.biodataIntakeFieldsEmpty;

  static String get biodataIntakeOpenProfile =>
      appText.biodataIntakeOpenProfile;

  static String get notificationsTitle => appText.settingsNotifications;

  static String get notificationsEmpty =>
      appText.notificationsEmpty;

  static String get notificationsLoadFailed =>
      appText.notificationsLoadFailed;

  static String get notificationsMarkAllRead =>
      appText.notificationsMarkAllRead;

  static String get notificationsUnread => appText.notificationsUnread;

  static String get notificationsRead => appText.notificationsRead;

  static String get notificationsOpenFailed => appText.notificationsOpenFailed;

  static String get notificationsSoon => appText.notificationsSoon;

  static String get settingsTitle => appText.settingsTitle;

  static String get settingsAccountSummary =>
      appText.settingsAccountSummary;

  static String get settingsPrivacy => appText.settingsPrivacy;

  static String get settingsCommunication =>
      appText.settingsCommunication;

  static String get settingsNotifications => appText.settingsNotifications;

  static String get settingsSecurity => appText.settingsSecurity;

  static String get settingsSave => appText.settingsSave;

  static String get settingsSaved =>
      appText.settingsSaved;

  static String get settingsLoadFailed =>
      appText.settingsLoadFailed;

  static String get settingsNoProfile => appText.settingsNoProfile;

  static String get settingsReadOnly => appText.settingsReadOnly;

  static String get settingsNotAvailable =>
      appText.settingsNotAvailable;

  static String get profileListsTitle =>
      appText.profileListsMenu;

  static String get profileListsMenu =>
      appText.profileListsMenu;

  static String get profileListsShortlist => appText.profileListsShortlist;

  static String get profileListsBlocked => appText.profileListsBlocked;

  static String get profileListsHidden => appText.profileListsHidden;

  static String get profileListsLoadFailed => appText.profileListsLoadFailed;

  static String get noShortlistedProfiles =>
      appText.noShortlistedProfiles;

  static String get noBlockedProfiles =>
      appText.noBlockedProfiles;

  static String get noHiddenProfiles =>
      appText.noHiddenProfiles;

  static String get removeFromShortlist =>
      appText.removeFromShortlist;

  static String get unblockProfile => appText.unblockProfile;

  static String get unhideProfile => appText.unhideProfile;

  static String get profileRemovedFromShortlist =>
      appText.profileRemovedFromShortlist;

  static String get profileUnblocked =>
      appText.profileUnblocked;

  static String get profileUnhidden =>
      appText.profileUnhidden;

  static String get profileOpenNotAllowed => appText.profileOpenNotAllowed;

  static String get confirmAction => appText.confirmAction;

  static String get cancel => appText.cancel;

  static String get retry => appText.retry;

  static String get gunamilanTitle =>
      appText.gunamilanTitle;

  static String get gunamilanScore =>
      appText.gunamilanScore;

  static String get gunamilanIncomplete =>
      appText.gunamilanIncomplete;

  static String get gunamilanViewDetails => appText.gunamilanViewDetails;

  static String get gunamilanHideDetails => appText.gunamilanHideDetails;

  static String get gunamilanDisclaimer => appText.gunamilanDisclaimer;

  static String get chatComingSoon => appText.chatComingSoon;

  static String get chatTitle => appText.chatMenu;

  static String get chatInbox => appText.chatInbox;

  static String get chatMenu => appText.chatMenu;

  static String get chatAll => appText.chatAll;

  static String get chatUnread => appText.chatUnread;

  static String get chatRequests => appText.chatRequests;

  static String get chatEmpty =>
      appText.chatEmpty;

  static String get chatLoadFailed =>
      appText.chatLoadFailed;

  static String get chatMessageHint =>
      appText.chatMessageHint;

  static String get chatSend => appText.chatSend;

  static String get chatOpenFailed =>
      appText.chatOpenFailed;

  static String get chatSendFailed =>
      appText.chatSendFailed;

  static String get chatReadLocked => appText.chatReadLocked;

  static String get chatUpgradeToRead =>
      appText.chatUpgradeToRead;

  static String get likeThisProfile =>
      appText.likeThisProfile;

  static String get photoUnavailable =>
      appText.photoUnavailable;

  static String comparisonLabel(String label) {
    if (!_mr) return label;

    final normalized = label.trim().toLowerCase();
    if (normalized == 'you & her') return 'तू आणि ती';
    if (normalized == 'you & him') return 'तू आणि तो';
    if (normalized == 'you & profile') return 'तू आणि हे स्थळ';
    return label;
  }

  static String comparisonPreferenceTitle(String comparisonLabel) {
    final subject = _comparisonPreferenceSubject(comparisonLabel);
    if (_mr) {
      return switch (subject) {
        'her' => 'तिच्या जोडीदार अपेक्षा',
        'his' => 'त्याच्या जोडीदार अपेक्षा',
        _ => 'जोडीदार अपेक्षा',
      };
    }

    return switch (subject) {
      'her' => 'Her Partner Preferences',
      'his' => 'His Partner Preferences',
      _ => 'Partner Preferences',
    };
  }

  static String comparisonPreferenceMatchSummary(
    int matched,
    int total,
    String comparisonLabel,
  ) {
    final subject = _comparisonPreferenceSubject(comparisonLabel);
    if (_mr) {
      final owner = switch (subject) {
        'her' => 'तिच्या',
        'his' => 'त्याच्या',
        _ => 'या स्थळाच्या',
      };
      return '$owner अपेक्षांपैकी $matched/$total जुळतात';
    }

    final owner = switch (subject) {
      'her' => 'her',
      'his' => 'his',
      _ => 'this profile',
    };
    return 'You match $matched/$total of $owner preferences';
  }

  static String comparisonPreferenceFallbackSummary(String comparisonLabel) {
    final subject = _comparisonPreferenceSubject(comparisonLabel);
    if (_mr) {
      return switch (subject) {
        'her' => appText.seeHowYourProfileMatchesHer,
        'his' => appText.seeHowYourProfileMatchesHis,
        _ => appText.seeHowYourProfileMatchesThisMatch,
      };
    }

    return switch (subject) {
      'her' => 'See how well you fit her preferences',
      'his' => 'See how well you fit his preferences',
      _ => 'See how well you fit this profile',
    };
  }

  static String comparisonPreferenceGroup(String groupKey) {
    return switch (groupKey) {
      'basic' => appText.basicPreferences,
      'religious' => appText.religiousPreferences,
      'professional' =>
        appText.professionalPreferences,
      'location' => appText.locationPreferences,
      'lifestyle' => appText.lifestylePreferences,
      _ => appText.otherPreferences,
    };
  }

  static String comparisonPreferredLabel(String label) {
    final normalized = label.trim().toLowerCase();
    if (normalized.startsWith('preferred ') ||
        label.trim().startsWith('अपेक्षित ')) {
      return label;
    }
    return _mr ? 'अपेक्षित $label' : 'Preferred $label';
  }

  static String comparisonYourValue(String value) {
    return _mr ? 'तुमचे: $value' : 'You: $value';
  }

  static String get comparisonValueUnknown =>
      appText.comparisonValueUnknown;

  static String get comparisonViewAll => appText.comparisonViewAll;

  static String get comparisonShowLess => appText.comparisonShowLess;

  static String _comparisonPreferenceSubject(String label) {
    final normalized = label.trim().toLowerCase();
    if (normalized.contains('her') || normalized.contains('ती')) return 'her';
    if (normalized.contains('him') || normalized.contains('तो')) return 'his';
    return 'profile';
  }

  static String get myProfile => appText.myProfile;

  static String get myProfileSubtitle =>
      appText.myProfileSubtitle;

  static String get editProfile =>
      appText.editProfile;

  static String get uploadPhoto => appText.uploadPhoto;

  static String get uploadPhotoSubtitle =>
      appText.uploadPhotoSubtitle;

  static String get photosVerification =>
      appText.photosVerification;

  static String get photosVerificationSubtitle => appText.photosVerificationSubtitle;

  static String get photoGalleryEmpty =>
      appText.photoGalleryEmpty;

  static String get addPhotos => appText.addPhotos;

  static String get photoUploadHelp => appText.photoUploadHelp;

  static String photoSlotsRemaining(int count) =>
      _mr ? '$count फोटो जागा शिल्लक' : '$count photo slots remaining';

  static String get camera => appText.camera;

  static String get gallery => appText.gallery;

  static String get yourPhotos => appText.yourPhotos;

  static String get selectedPhoto => appText.selectedPhoto;

  static String get replacePhoto => appText.replacePhoto;

  static String get setPrimary => appText.setPrimary;

  static String get deletePhoto => appText.deletePhoto;

  static String get moveLeft => appText.moveLeft;

  static String get moveRight => appText.moveRight;

  static String get primaryPhoto => appText.primaryPhoto;

  static String get photoManagementHint => appText.photoManagementHint;

  static String get photoDeleteConfirm => appText.photoDeleteConfirm;

  static String get delete => appText.delete;

  static String get refresh => appText.refresh;

  static String get uploading => appText.uploading;

  static String get verificationStatus =>
      appText.verificationStatus;

  static String get sentInterests =>
      appText.sentInterests;

  static String get sentInterestsSubtitle =>
      appText.sentInterestsSubtitle;

  static String get receivedInterests =>
      appText.receivedInterests;

  static String get receivedInterestsSubtitle => appText.receivedInterestsSubtitle;

  static String get logout => appText.logout;

  static String get interestStatistics =>
      appText.interestStatistics;

  static String get total => appText.total;

  static String get pending => appText.pending;

  static String get accepted => appText.accepted;

  static String get rejected => appText.rejected;

  static String get loading => appText.loading;

  static String get profile => appText.profile;

  static String get profileType => appText.profileType;

  static String get brideGroom => appText.brideGroom;

  static String get selectProfileType =>
      appText.selectProfileType;

  static String get profileTypeLoadFailed => appText.profileTypeLoadFailed;

  static String get name => appText.name;

  static String get dateOfBirth => appText.dateOfBirth;

  static String get age => appText.age;

  static String get caste => appText.caste;

  static String get education => appText.education;

  static String get location => appText.location;

  static String years(int value) => _mr ? '$value वर्षे' : '$value years';

  static String get noInformation => appText.noInformation;

  static String get noProfileData =>
      appText.noProfileData;

  static String get sendInterest => appText.sendInterest;

  static String get interestSent => appText.interestSent;
}
