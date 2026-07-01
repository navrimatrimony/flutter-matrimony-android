import 'app_language.dart';

class AppStrings {
  static bool get _mr => isMarathiApp;

  static String get appName =>
      _mr ? 'नवरी मिळे नवऱ्याला' : 'Navri Mile Navryala';

  static bool get isMarathi => _mr;

  static String get chooseLanguage => _mr ? 'भाषा निवडा' : 'Choose Language';

  static String get chooseLanguageBilingual => 'भाषा निवडा\nChoose language';

  static String get languageMenu => _mr ? 'भाषा' : 'Language';

  static String get languageSwitchSubtitle =>
      _mr ? 'App भाषा बदला' : 'Change app language';

  static String get marathi => 'मराठी';

  static String get english => 'English';

  static String get landingHeadline => _mr
      ? 'योग्य जोडीदार शोधण्याचा विश्वासार्ह मार्ग'
      : 'A trusted way to find the right match';

  static String get landingSubline => _mr
      ? 'सुरक्षित, सोपे आणि कुटुंबासाठी योग्य विवाह-जुळवणी व्यासपीठ'
      : 'Safe, simple and family-friendly matrimony platform';

  static String get safeProfiles => _mr ? 'सुरक्षित प्रोफाइल' : 'Safe profiles';

  static String get familyFriendly =>
      _mr ? 'कुटुंबांसाठी योग्य' : 'Family-friendly';

  static String get simpleProcess =>
      _mr ? 'सोपे नोंदणी' : 'Simple registration';

  static String get register => _mr ? 'नोंदणी करा' : 'Register';

  static String get login => _mr ? 'लॉगिन करा' : 'Login';

  static String get loginWelcomeTitle =>
      _mr ? 'परत स्वागत आहे' : 'Welcome back';

  static String get loginWelcomeSubtitle => _mr
      ? 'तुमच्या स्थळांचा प्रवास सुरक्षितपणे पुढे सुरू करा.'
      : 'Continue your matrimony journey securely.';

  static String get loginIdentifierLabel =>
      _mr ? 'मोबाइल / ईमेल / युजरनेम' : 'Mobile / Email / Username';

  static String get loginPasswordLabel => _mr ? 'पासवर्ड' : 'Password';

  static String get loginShowPassword =>
      _mr ? 'पासवर्ड दाखवा' : 'Show password';

  static String get loginHidePassword => _mr ? 'पासवर्ड लपवा' : 'Hide password';

  static String get loginKeepSignedIn =>
      _mr ? 'लॉगिन कायम ठेवा' : 'Keep me signed in';

  static String get loginKeepSignedInSubtitle => _mr
      ? 'पुढच्या वेळी password न टाकता app उघडेल.'
      : 'Open the app next time without entering your password.';

  static String get loginMissingFields =>
      _mr ? 'Login आणि password दोन्ही भरा.' : 'Enter login and password.';

  static String get loginSuccess =>
      _mr ? 'Login यशस्वी. Welcome back.' : 'Login successful. Welcome back.';

  static String get loginProfileMissing => _mr
      ? 'प्रोफाइल सापडली नाही. प्रोफाइल तयार करा.'
      : 'Profile not found. Create your profile.';

  static String get loginProfileCheckFailed => _mr
      ? 'Profile तपासता आली नाही. पुन्हा प्रयत्न करा.'
      : 'Profile check failed. Please try again.';

  static String get loginFailed => _mr
      ? 'Login failed. Login किंवा password तपासा.'
      : 'Login failed. Check login or password.';

  static String get loginRegisterPrompt =>
      _mr ? 'नवीन user? इथे register करा' : 'New user? Register here';

  static String get logoutToExit => _mr
      ? 'App मधून बाहेर पडण्यासाठी Logout वापरा.'
      : 'Use Logout when you want to leave this account.';

  static String get dashboard => _mr ? 'माझे डॅशबोर्ड' : 'My Dashboard';

  static String get dashboardHeadline => _mr
      ? 'तुमच्या योग्य स्थळांसाठी पुढचे पाऊल'
      : 'Your next step toward the right match';

  static String get dashboardSubtitle => _mr
      ? 'प्रोफाइल, फोटो आणि इंटरेस्ट एका ठिकाणी व्यवस्थापित करा.'
      : 'Manage your profile, photo and interests in one place.';

  static String dashboardGreeting(String name) =>
      _mr ? 'नमस्कार, $name!' : 'Hello, $name!';

  static String get dashboardHeroFallback => _mr
      ? 'तुमच्या योग्य स्थळांसाठी dashboard तयार आहे.'
      : 'Your matrimony dashboard is ready.';

  static String get dashboardPremiumMember =>
      _mr ? 'Premium Member' : 'Premium Member';

  static String get dashboardFreePlan => _mr ? 'Free Plan' : 'Free Plan';

  static String get dashboardProfileActive =>
      _mr ? 'Profile active' : 'Profile active';

  static String get dashboardProfileMissing =>
      _mr ? 'Profile तयार नाही' : 'Profile missing';

  static String get dashboardPhotoMissing =>
      _mr ? 'Photo missing' : 'Photo missing';

  static String get dashboardPhotoPending =>
      _mr ? 'Photo pending' : 'Photo pending';

  static String get dashboardPhotoApproved =>
      _mr ? 'Photo approved' : 'Photo approved';

  static String get dashboardViewMatches => _mr ? 'स्थळे पहा' : 'View Matches';

  static String get dashboardChangePlan => _mr ? 'प्लॅन बदला' : 'Change plan';

  static String dashboardContactCreditsRemaining(int count) =>
      _mr ? 'Contact credits: $count शिल्लक' : 'Contact credits: $count left';

  static String get dashboardNextBestAction =>
      _mr ? 'पुढचे योग्य पाऊल' : 'Next best action';

  static String get dashboardCreateProfile =>
      _mr ? 'प्रोफाइल तयार करा' : 'Create Profile';

  static String get dashboardCreateProfileSubtitle => _mr
      ? 'Dashboard fallback: profile नसल्यास इथून onboarding सुरू करा.'
      : 'Dashboard fallback: start onboarding if your profile is missing.';

  static String get dashboardUploadPhotoPrompt => _mr
      ? 'Clear photo upload करा आणि जास्त प्रतिसाद मिळवा.'
      : 'Upload a clear photo to get better responses.';

  static String get dashboardPhotoPendingSubtitle => _mr
      ? 'तुमच्या photo verification ची स्थिती तपासा.'
      : 'Check your photo verification status.';

  static String get dashboardCompleteProfile =>
      _mr ? 'Profile पूर्ण करा' : 'Complete Profile';

  static String get dashboardCompleteProfileSubtitle => _mr
      ? 'महत्त्वाची माहिती पूर्ण केल्यावर matching चांगले होते.'
      : 'Complete key details to improve matching.';

  static String get dashboardRespondInterests =>
      _mr ? 'आलेल्या इंटरेस्टला उत्तर द्या' : 'Respond to Interests';

  static String get dashboardRespondInterestsSubtitle => _mr
      ? 'Pending proposals पाहून accept/reject करा.'
      : 'Review pending proposals and respond.';

  static String get dashboardReplyMessages =>
      _mr ? 'Messages ला reply द्या' : 'Reply to Messages';

  static String get dashboardReplyMessagesSubtitle => _mr
      ? 'Unread chat तुमच्या प्रतिसादाची वाट पाहत आहे.'
      : 'Unread chats are waiting for your response.';

  static String get dashboardReviewContactRequests =>
      _mr ? 'Contact requests तपासा' : 'Review Contact Requests';

  static String get dashboardReviewContactRequestsSubtitle => _mr
      ? 'Pending contact requests सुरक्षितपणे review करा.'
      : 'Review pending contact requests safely.';

  static String get dashboardCheckNotifications =>
      _mr ? 'सूचना तपासा' : 'Check Notifications';

  static String get dashboardCheckNotificationsSubtitle => _mr
      ? 'नवीन सूचना आणि updates पहा.'
      : 'See new notifications and updates.';

  static String get dashboardUpgradePlan =>
      _mr ? 'Plan upgrade करा' : 'Upgrade Plan';

  static String get dashboardUpgradePlanSubtitle => _mr
      ? 'Contact unlock आणि premium benefits पाहा.'
      : 'View contact unlocks and premium benefits.';

  static String get dashboardViewMatchesSubtitle => _mr
      ? 'तुमच्यासाठी योग्य स्थळे पाहा.'
      : 'Explore suitable profiles for you.';

  static String get dashboardQuickActions =>
      _mr ? 'क्विक लिंक्स' : 'Quick actions';

  static String get dashboardReadiness =>
      _mr ? 'तुमची तयारी' : 'Profile readiness';

  static String get dashboardReadinessSubtitle => _mr
      ? 'Fake percentage नाही; उपलब्ध माहितीवर आधारित checklist.'
      : 'No fake percentage; checklist based on available data.';

  static String get dashboardReady => _mr ? 'पूर्ण' : 'Ready';

  static String get dashboardNeedsAttention =>
      _mr ? 'पूर्ण करणे बाकी' : 'Needs attention';

  static String get dashboardAddNow => _mr ? 'Add now' : 'Add now';

  static String get dashboardBasicDetails =>
      _mr ? 'Basic details' : 'Basic details';

  static String get dashboardPhoto => _mr ? 'Photo' : 'Photo';

  static String get dashboardLocationDetails =>
      _mr ? 'Location details' : 'Location details';

  static String get dashboardEducationCareer =>
      _mr ? 'Education / Career' : 'Education / Career';

  static String get dashboardPartnerPreference =>
      _mr ? 'Partner Preference' : 'Partner Preference';

  static String get dashboardPlanContact =>
      _mr ? 'Plan / Contact status' : 'Plan / Contact status';

  static String get dashboardActivity =>
      _mr ? 'तुमची activity' : 'Your activity';

  static String get dashboardAccountTools =>
      _mr ? 'इतर पर्याय' : 'Account tools';

  static String get dashboardPlanToolSubtitle => _mr
      ? 'Plan, payment आणि contact credits'
      : 'Plans, payment and contact credits';

  static String get dashboardListsToolSubtitle =>
      _mr ? 'Shortlist, block आणि hidden list' : 'Shortlist, block and hidden';

  static String get dashboardSettingsToolSubtitle =>
      _mr ? 'Privacy आणि notification preferences' : 'Privacy and preferences';

  static String get featureNotAvailable => _mr
      ? 'ही सुविधा सध्या उपलब्ध नाही.'
      : 'This feature is not available right now.';

  static String get browseProfiles => _mr ? 'स्थळे' : 'Matches';

  static String get browseProfilesSubtitle => _mr
      ? 'तुमच्यासाठी योग्य स्थळे शोधा'
      : 'Explore suitable matrimony profiles';

  static String get matchesTabNew => _mr ? 'नवीन' : 'New';

  static String get matchesTabDaily => _mr ? 'दैनिक' : 'Daily';

  static String get matchesTabMyMatches =>
      _mr ? 'माझी जुळणारी स्थळे' : 'My Matches';

  static String get matchesTabNearMe => _mr ? 'जवळची स्थळे' : 'Near Me';

  static String get matchesTabMore => _mr ? 'अधिक स्थळे' : 'More Matches';

  static String get matchesFilter => _mr ? 'फिल्टर' : 'Filters';

  static String get matchesFilterHint =>
      _mr ? 'वय, जात, ठिकाण निवडा' : 'Age, caste, location';

  static String get chooseLocationForNearMe => _mr
      ? 'जवळची स्थळे पाहण्यासाठी location filter निवडा.'
      : 'Choose a location filter to see nearby profiles.';

  static String get chooseLocationFilter =>
      _mr ? 'Location निवडा' : 'Choose location';

  static String get membersYouMayLike =>
      _mr ? 'तुम्हाला आवडू शकणारी स्थळे' : 'Profiles you may like';

  static String get moreProfilesYouMayLike =>
      _mr ? 'आणखी योग्य स्थळे' : 'More suitable profiles';

  static String get premiumProfiles =>
      _mr ? 'Premium स्थळे' : 'Premium profiles';

  static String get premiumProfilesSubtitle =>
      _mr ? 'सदस्यत्व असलेली निवडक स्थळे' : 'Selected premium profiles';

  static String get profilesFromSearch =>
      _mr ? 'तुमच्या सध्याच्या शोधातील स्थळे' : 'Profiles from your search';

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

    return _mr ? 'अधिक स्थळे' : 'More Matches';
  }

  static String moreMatchesSectionSubtitle(String key) {
    switch (key) {
      case 'looking_for_me':
        return _mr
            ? 'ज्यांच्या पसंतीशी तुमची माहिती जुळू शकते'
            : 'Profiles whose preferences may match you';
      case 'recently_viewed':
        return _mr
            ? 'तुम्ही अलीकडे पाहिलेली स्थळे'
            : 'Profiles you viewed recently';
      case 'matching_my_preference':
        return _mr
            ? 'तुमच्या जोडीदार पसंतीवर आधारित'
            : 'Based on your partner preferences';
      case 'nearby':
        return _mr
            ? 'तुमच्या ठिकाणाजवळील स्थळे'
            : 'Profiles closer to your location';
      case 'recent_visitors':
        return _mr
            ? 'तुमचे profile कोणी पाहिले ते पहा'
            : 'See who viewed your profile';
      case 'you_may_like':
        return _mr
            ? 'तुमच्यासाठी सुचवलेली स्थळे'
            : 'Suggested profiles for you';
    }

    return '';
  }

  static String get upgradeToSeeVisitors =>
      _mr ? 'भेट देणारे पाहण्यासाठी अपग्रेड करा' : 'Upgrade to see visitors';

  static String get recentVisitorsEmpty => _mr
      ? 'दाखवण्यासाठी योग्य अलीकडील भेटी अजून नाहीत.'
      : 'No eligible recent visitors to show yet.';

  static String get upgrade => _mr ? 'अपग्रेड करा' : 'Upgrade';

  static String get bottomHome => _mr ? 'होम' : 'Home';

  static String get bottomMatches => _mr ? 'स्थळे' : 'Matches';

  static String get bottomConnect => _mr ? 'कनेक्ट' : 'Connect';

  static String get bottomChat => _mr ? 'चॅट' : 'Chat';

  static String get connectReceived => _mr ? 'आलेले' : 'Received';

  static String get connectSent => _mr ? 'पाठवलेले' : 'Sent';

  static String get connectContactRequests => _mr ? 'कॉन्टॅक्ट' : 'Contact';

  static String get connectUpgrade => _mr ? 'अपग्रेड' : 'Upgrade';

  static String get contactRequests =>
      _mr ? 'कॉन्टॅक्ट रिक्वेस्ट' : 'Contact Requests';

  static String get plansTitle => _mr ? 'प्लॅन्स' : 'Plans';

  static String get plansUpgradeMenu =>
      _mr ? 'प्लॅन / अपग्रेड' : 'Plans / Upgrade';

  static String get plansCurrentPlan => _mr ? 'सध्याचा प्लॅन' : 'Current plan';

  static String get plansAvailablePlans =>
      _mr ? 'उपलब्ध प्लॅन्स' : 'Available plans';

  static String get plansRefresh => _mr ? 'रिफ्रेश' : 'Refresh';

  static String get plansChoose => _mr ? 'निवडा' : 'Choose';

  static String get plansOpeningCheckout =>
      _mr ? 'Checkout उघडत आहे...' : 'Opening checkout...';

  static String get plansEmpty => _mr
      ? 'सध्या upgrade साठी कोणताही प्लॅन उपलब्ध नाही.'
      : 'No upgrade plan is available right now.';

  static String get plansNoCurrentPlan =>
      _mr ? 'सध्याचा प्लॅन उपलब्ध नाही' : 'Current plan is not available';

  static String get plansContactQuota =>
      _mr ? 'Contact unlock quota' : 'Contact unlock quota';

  static String get plansRemaining => _mr ? 'शिल्लक' : 'remaining';

  static String get plansManualRefreshHint => _mr
      ? 'Payment पूर्ण झाल्यावर app मध्ये परत येऊन Refresh करा.'
      : 'After payment, return to the app and tap Refresh.';

  static String get plansBrowserNote => _mr
      ? 'Checkout browser मध्ये उघडले आहे. Payment status Laravel कडून update होईल.'
      : 'Checkout opened in the browser. Payment status will update from Laravel.';

  static String get plansCheckoutUrlMissing => _mr
      ? 'Checkout link backend कडून मिळाला नाही.'
      : 'Checkout link was not returned by the backend.';

  static String get plansOpenFailedCopied => _mr
      ? 'Browser उघडू शकला नाही. Checkout link clipboard मध्ये copy केला.'
      : 'Could not open the browser. Checkout link was copied to the clipboard.';

  static String get plansLoadFailed =>
      _mr ? 'Plans load झाले नाहीत.' : 'Plans could not be loaded.';

  static String get plansFreeOrLocked =>
      _mr ? 'Free / locked state' : 'Free / locked state';

  static String get plansActiveSubscription =>
      _mr ? 'Active subscription' : 'Active subscription';

  static String get biodataExportTitle =>
      _mr ? 'बायोडाटा एक्सपोर्ट' : 'Biodata Export';

  static String get biodataExportMenu =>
      _mr ? 'बायोडाटा एक्सपोर्ट' : 'Biodata Export';

  static String get biodataPrintAction =>
      _mr ? 'बायोडाटा / प्रिंट' : 'Biodata / Print';

  static String get biodataExportSubtitle => _mr
      ? 'तुमचा स्वतःचा बायोडाटा PDF म्हणून download किंवा share करा.'
      : 'Download or share your own biodata as a PDF.';

  static String get biodataExportTemplate =>
      _mr ? 'Template निवडा' : 'Choose template';

  static String get biodataExportFormat =>
      _mr ? 'Format निवडा' : 'Choose format';

  static String get biodataExportPdf => 'PDF';

  static String get biodataExportJpg => 'JPG';

  static String get biodataExportDownload => _mr ? 'Download करा' : 'Download';

  static String get biodataExportShare => _mr ? 'Share करा' : 'Share';

  static String get biodataExportWarnings =>
      _mr ? 'पूर्णता सूचना' : 'Completeness warnings';

  static String get biodataExportLoadFailed => _mr
      ? 'बायोडाटा export options load झाले नाहीत.'
      : 'Biodata export options could not be loaded.';

  static String get biodataExportFailed =>
      _mr ? 'बायोडाटा export तयार झाला नाही.' : 'Biodata export failed.';

  static String get biodataExportUnavailable => _mr
      ? 'बायोडाटा export सध्या उपलब्ध नाही.'
      : 'Biodata export is not available right now.';

  static String get biodataExportLinkMissing => _mr
      ? 'Backend कडून download link मिळाली नाही.'
      : 'The backend did not return a download link.';

  static String get biodataExportBrowserOpened => _mr
      ? 'Biodata browser मध्ये उघडले आहे.'
      : 'Biodata opened in the browser.';

  static String get biodataExportOpenFailedCopied => _mr
      ? 'Browser उघडू शकला नाही. Link clipboard मध्ये copy केली.'
      : 'Could not open the browser. Link copied to clipboard.';

  static String get biodataExportShared =>
      _mr ? 'Biodata share link तयार आहे.' : 'Biodata share link is ready.';

  static String get biodataExportLinkExpires => _mr
      ? 'Share/download link थोड्या वेळासाठीच valid असते.'
      : 'Share/download links are valid for a short time.';

  static String get biodataGeneratedTitle =>
      _mr ? 'Generated biodata तयार आहे' : 'Generated biodata is ready';

  static String get biodataGeneratedSubtitle => _mr
      ? 'Preview, download किंवा share करण्यासाठी हा link वापरा.'
      : 'Use this link to preview, download, or share the generated biodata.';

  static String get biodataPreviewAction =>
      _mr ? 'Preview उघडा' : 'Open preview';

  static String get biodataCopyLink => _mr ? 'Link copy करा' : 'Copy link';

  static String get biodataLinkCopied =>
      _mr ? 'Biodata link clipboard मध्ये copy केली.' : 'Biodata link copied.';

  static String get biodataExpiresAt =>
      _mr ? 'Link valid until' : 'Link valid until';

  static String get notificationsTitle => _mr ? 'सूचना' : 'Notifications';

  static String get notificationsEmpty =>
      _mr ? 'सध्या कोणतीही सूचना नाही.' : 'No notifications yet.';

  static String get notificationsLoadFailed =>
      _mr ? 'सूचना load झाल्या नाहीत.' : 'Notifications could not be loaded.';

  static String get notificationsMarkAllRead =>
      _mr ? 'सर्व वाचले' : 'Mark all read';

  static String get notificationsUnread => _mr ? 'न वाचलेल्या' : 'Unread';

  static String get notificationsRead => _mr ? 'वाचले' : 'Read';

  static String get notificationsOpenFailed => _mr
      ? 'ही सूचना app मध्ये उघडण्यासाठी route उपलब्ध नाही.'
      : 'This notification does not have an app action.';

  static String get notificationsSoon => _mr
      ? 'सूचना लवकरच app मध्ये येतील.'
      : 'Notifications will be available soon.';

  static String get settingsTitle => _mr ? 'सेटिंग्ज' : 'Settings';

  static String get settingsAccountSummary =>
      _mr ? 'अकाउंट माहिती' : 'Account summary';

  static String get settingsPrivacy => _mr ? 'गोपनीयता' : 'Privacy';

  static String get settingsCommunication =>
      _mr ? 'संपर्क प्राधान्ये' : 'Communication';

  static String get settingsNotifications => _mr ? 'सूचना' : 'Notifications';

  static String get settingsSecurity => _mr ? 'सुरक्षा' : 'Security';

  static String get settingsSave => _mr ? 'सेव्ह करा' : 'Save';

  static String get settingsSaved =>
      _mr ? 'सेटिंग्ज सेव्ह झाल्या.' : 'Settings saved.';

  static String get settingsLoadFailed =>
      _mr ? 'सेटिंग्ज load झाल्या नाहीत.' : 'Settings could not be loaded.';

  static String get settingsNoProfile => _mr
      ? 'प्रोफाइल पूर्ण केल्यानंतर या सेटिंग्ज उपलब्ध होतील.'
      : 'These settings will be available after your profile is complete.';

  static String get settingsReadOnly => _mr ? 'फक्त पाहण्यासाठी' : 'Read only';

  static String get settingsNotAvailable =>
      _mr ? 'उपलब्ध नाही' : 'Not available';

  static String get profileListsTitle =>
      _mr ? 'शॉर्टलिस्ट / ब्लॉक' : 'Shortlist / Blocked';

  static String get profileListsMenu =>
      _mr ? 'शॉर्टलिस्ट / ब्लॉक' : 'Shortlist / Blocked';

  static String get profileListsShortlist => _mr ? 'शॉर्टलिस्ट' : 'Shortlist';

  static String get profileListsBlocked => _mr ? 'ब्लॉक केलेले' : 'Blocked';

  static String get profileListsHidden => _mr ? 'लपवलेले' : 'Hidden';

  static String get profileListsLoadFailed => _mr
      ? 'प्रोफाइल यादी load झाली नाही.'
      : 'Profile list could not be loaded.';

  static String get noShortlistedProfiles =>
      _mr ? 'अजून कोणतीही shortlist नाही.' : 'No shortlisted profiles yet.';

  static String get noBlockedProfiles =>
      _mr ? 'कोणतेही blocked profiles नाहीत.' : 'No blocked profiles.';

  static String get noHiddenProfiles =>
      _mr ? 'कोणतेही hidden profiles नाहीत.' : 'No hidden profiles.';

  static String get removeFromShortlist =>
      _mr ? 'Shortlist मधून काढा' : 'Remove from shortlist';

  static String get unblockProfile => _mr ? 'Unblock करा' : 'Unblock';

  static String get unhideProfile => _mr ? 'Unhide करा' : 'Unhide';

  static String get profileRemovedFromShortlist =>
      _mr ? 'Profile shortlist मधून काढले.' : 'Profile removed from shortlist.';

  static String get profileUnblocked =>
      _mr ? 'Profile unblock केले.' : 'Profile unblocked.';

  static String get profileUnhidden =>
      _mr ? 'Profile unhide केले.' : 'Profile unhidden.';

  static String get profileOpenNotAllowed => _mr
      ? 'हे profile सध्या उघडता येत नाही.'
      : 'This profile cannot be opened right now.';

  static String get confirmAction => _mr ? 'Confirm करा' : 'Confirm';

  static String get cancel => _mr ? 'रद्द करा' : 'Cancel';

  static String get retry => _mr ? 'पुन्हा प्रयत्न करा' : 'Retry';

  static String get gunamilanTitle =>
      _mr ? 'गुणमिलन / पत्रिका जुळवणी' : 'Gunamilan / Horoscope Match';

  static String get gunamilanScore =>
      _mr ? 'गुणमिलन स्कोअर' : 'Gunamilan score';

  static String get gunamilanIncomplete =>
      _mr ? 'पत्रिका माहिती अपूर्ण आहे.' : 'Horoscope data is incomplete.';

  static String get gunamilanViewDetails => _mr ? 'तपशील पहा' : 'View details';

  static String get gunamilanHideDetails => _mr ? 'तपशील लपवा' : 'Hide details';

  static String get gunamilanDisclaimer => _mr
      ? 'गुणमिलन हा फक्त compatibility reference आहे. अंतिम निर्णय कुटुंबीयांनी चर्चा करून घ्यावा.'
      : 'Gunamilan is only a compatibility reference. Families should make the final decision after discussion.';

  static String get chatComingSoon => _mr
      ? 'Chat सुविधा लवकरच app मध्ये येईल.'
      : 'Chat will be available in the app soon.';

  static String get chatTitle => _mr ? 'चॅट' : 'Chat';

  static String get chatInbox => _mr ? 'चॅट इनबॉक्स' : 'Chat Inbox';

  static String get chatMenu => _mr ? 'चॅट' : 'Chat';

  static String get chatAll => _mr ? 'सर्व' : 'All';

  static String get chatUnread => _mr ? 'न वाचलेले' : 'Unread';

  static String get chatRequests => _mr ? 'रिक्वेस्ट' : 'Requests';

  static String get chatEmpty =>
      _mr ? 'अजून कोणतीही chat नाही.' : 'No chats yet.';

  static String get chatLoadFailed =>
      _mr ? 'Chat load झाली नाही.' : 'Chat could not be loaded.';

  static String get chatMessageHint =>
      _mr ? 'Message लिहा...' : 'Type a message...';

  static String get chatSend => _mr ? 'पाठवा' : 'Send';

  static String get chatOpenFailed =>
      _mr ? 'Chat उघडता आली नाही.' : 'Chat could not be opened.';

  static String get chatSendFailed =>
      _mr ? 'Message पाठवता आला नाही.' : 'Message could not be sent.';

  static String get chatReadLocked => _mr
      ? 'हा message वाचण्यासाठी upgrade आवश्यक असू शकते.'
      : 'Upgrade may be required to read this message.';

  static String get chatUpgradeToRead =>
      _mr ? 'वाचण्यासाठी अपग्रेड करा' : 'Upgrade to read';

  static String get likeThisProfile =>
      _mr ? 'हे स्थळ आवडले?' : 'Like this profile?';

  static String get photoUnavailable =>
      _mr ? 'फोटो उपलब्ध नाही' : 'Photo not available';

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
        'her' => 'तिच्या अपेक्षांशी तुमचे profile किती जुळते ते पहा',
        'his' => 'त्याच्या अपेक्षांशी तुमचे profile किती जुळते ते पहा',
        _ => 'या स्थळाच्या अपेक्षांशी तुमचे profile किती जुळते ते पहा',
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
      'basic' => _mr ? 'मूलभूत अपेक्षा' : 'Basic Preferences',
      'religious' => _mr ? 'धार्मिक अपेक्षा' : 'Religious Preferences',
      'professional' =>
        _mr ? 'शिक्षण / करिअर अपेक्षा' : 'Professional Preferences',
      'location' => _mr ? 'ठिकाण अपेक्षा' : 'Location Preferences',
      'lifestyle' => _mr ? 'जीवनशैली अपेक्षा' : 'Lifestyle Preferences',
      _ => _mr ? 'इतर अपेक्षा' : 'Other Preferences',
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
      _mr ? 'माहिती नाही' : 'Not specified';

  static String get comparisonViewAll => _mr ? 'सर्व पहा' : 'View all';

  static String get comparisonShowLess => _mr ? 'कमी दाखवा' : 'Show less';

  static String _comparisonPreferenceSubject(String label) {
    final normalized = label.trim().toLowerCase();
    if (normalized.contains('her') || normalized.contains('ती')) return 'her';
    if (normalized.contains('him') || normalized.contains('तो')) return 'his';
    return 'profile';
  }

  static String get myProfile => _mr ? 'माझे प्रोफाइल' : 'My Profile';

  static String get myProfileSubtitle =>
      _mr ? 'तुमची प्रोफाइल माहिती पहा' : 'View your matrimony profile';

  static String get editProfile =>
      _mr ? 'प्रोफाइल अपडेट करा' : 'Update Profile';

  static String get uploadPhoto => _mr ? 'फोटो अपलोड करा' : 'Upload Photo';

  static String get uploadPhotoSubtitle =>
      _mr ? 'प्रोफाइलसाठी फोटो अपडेट करा' : 'Update your profile photo';

  static String get photosVerification =>
      _mr ? 'फोटो / पडताळणी' : 'Photos / Verification';

  static String get photosVerificationSubtitle => _mr
      ? 'फोटो gallery आणि verification status पहा'
      : 'Manage gallery and verification status';

  static String get photoGalleryEmpty =>
      _mr ? 'अजून photo upload केलेले नाहीत.' : 'No photos uploaded yet.';

  static String get addPhotos => _mr ? 'फोटो जोडा' : 'Add photos';

  static String get photoUploadHelp => _mr
      ? 'Clear face, single person आणि चांगल्या light मधला photo upload करा.'
      : 'Upload a clear, single-person photo in good light.';

  static String photoSlotsRemaining(int count) =>
      _mr ? '$count photo slots बाकी आहेत' : '$count photo slots remaining';

  static String get camera => _mr ? 'Camera' : 'Camera';

  static String get gallery => _mr ? 'Gallery' : 'Gallery';

  static String get yourPhotos => _mr ? 'तुमचे फोटो' : 'Your photos';

  static String get selectedPhoto => _mr ? 'Selected photo' : 'Selected photo';

  static String get replacePhoto => _mr ? 'Photo बदला' : 'Replace photo';

  static String get setPrimary => _mr ? 'Primary करा' : 'Set primary';

  static String get deletePhoto => _mr ? 'फोटो delete करा' : 'Delete photo';

  static String get moveLeft => _mr ? 'डावीकडे' : 'Move left';

  static String get moveRight => _mr ? 'उजवीकडे' : 'Move right';

  static String get primaryPhoto => _mr ? 'Primary' : 'Primary';

  static String get photoManagementHint => _mr
      ? 'खालील thumbnail निवडा आणि त्या photo साठी action करा.'
      : 'Select a thumbnail below, then manage that photo.';

  static String get photoDeleteConfirm => _mr
      ? 'हा photo profile मधून काढायचा आहे का?'
      : 'Remove this photo from your profile?';

  static String get delete => _mr ? 'Delete' : 'Delete';

  static String get refresh => _mr ? 'Refresh' : 'Refresh';

  static String get uploading => _mr ? 'Uploading...' : 'Uploading...';

  static String get verificationStatus =>
      _mr ? 'पडताळणी स्थिती' : 'Verification status';

  static String get sentInterests =>
      _mr ? 'पाठवलेले इंटरेस्ट' : 'Sent Interests';

  static String get sentInterestsSubtitle =>
      _mr ? 'तुम्ही पाठवलेले इंटरेस्ट पहा' : 'View interests you have sent';

  static String get receivedInterests =>
      _mr ? 'आलेले इंटरेस्ट' : 'Received Interests';

  static String get receivedInterestsSubtitle => _mr
      ? 'आलेले इंटरेस्ट पहा आणि प्रतिसाद द्या'
      : 'View and respond to received interests';

  static String get logout => _mr ? 'लॉगआउट' : 'Logout';

  static String get interestStatistics =>
      _mr ? 'इंटरेस्ट स्थिती' : 'Interest Statistics';

  static String get total => _mr ? 'एकूण' : 'Total';

  static String get pending => _mr ? 'प्रलंबित' : 'Pending';

  static String get accepted => _mr ? 'स्वीकारले' : 'Accepted';

  static String get rejected => _mr ? 'नाकारले' : 'Rejected';

  static String get loading => _mr ? 'लोड होत आहे...' : 'Loading...';

  static String get profile => _mr ? 'प्रोफाइल' : 'Profile';

  static String get profileType => _mr ? 'प्रोफाइल प्रकार' : 'Profile type';

  static String get brideGroom => _mr ? 'वधू / वर' : 'Bride / Groom';

  static String get selectProfileType =>
      _mr ? 'कृपया वधू / वर निवडा.' : 'Please select profile type.';

  static String get profileTypeLoadFailed => _mr
      ? 'प्रोफाइल प्रकार load करता आला नाही.'
      : 'Profile type could not be loaded.';

  static String get name => _mr ? 'नाव' : 'Name';

  static String get dateOfBirth => _mr ? 'जन्मतारीख' : 'Date of birth';

  static String get age => _mr ? 'वय' : 'Age';

  static String get caste => _mr ? 'जात' : 'Caste';

  static String get education => _mr ? 'शिक्षण' : 'Education';

  static String get location => _mr ? 'ठिकाण' : 'Location';

  static String years(int value) => _mr ? '$value वर्षे' : '$value years';

  static String get noInformation => _mr ? 'माहिती नाही' : 'Not available';

  static String get noProfileData =>
      _mr ? 'प्रोफाइल डेटा उपलब्ध नाही.' : 'Profile data is not available.';

  static String get sendInterest => _mr ? 'इंटरेस्ट पाठवा' : 'Send Interest';

  static String get interestSent => _mr ? 'इंटरेस्ट पाठवला' : 'Interest Sent';
}
