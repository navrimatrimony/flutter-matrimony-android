import 'app_language.dart';

class AppStrings {
  static bool get _mr => isMarathiApp;

  static String get appName =>
      _mr ? 'नवरी मिळे नवऱ्याला' : 'Navri Mile Navryala';

  static bool get isMarathi => _mr;

  static String get chooseLanguage =>
      _mr ? 'भाषा निवडा' : 'Choose Language';

  static String get chooseLanguageSubtitle => _mr
      ? 'अ‍ॅप कोणत्या भाषेत वापरायचे?'
      : 'Which language would you like to use?';

  static String get marathi => 'मराठी';

  static String get english => 'English';

  static String get landingHeadline => _mr
      ? 'योग्य जोडीदार शोधण्याचा विश्वासार्ह मार्ग'
      : 'A trusted way to find the right match';

  static String get landingSubline => _mr
      ? 'सुरक्षित, सोपे आणि कुटुंबासाठी योग्य विवाह-जुळवणी व्यासपीठ'
      : 'Safe, simple and family-friendly matrimony platform';

  static String get safeProfiles =>
      _mr ? 'सुरक्षित प्रोफाइल' : 'Safe profiles';

  static String get familyFriendly =>
      _mr ? 'कुटुंबांसाठी योग्य' : 'Family-friendly';

  static String get simpleProcess =>
      _mr ? 'सोपे नोंदणी' : 'Simple registration';

  static String get register => _mr ? 'नोंदणी करा' : 'Register';

  static String get login => _mr ? 'लॉगिन करा' : 'Login';

  static String get dashboard => _mr ? 'माझे डॅशबोर्ड' : 'My Dashboard';

  static String get dashboardHeadline => _mr
      ? 'तुमच्या योग्य स्थळांसाठी पुढचे पाऊल'
      : 'Your next step toward the right match';

  static String get dashboardSubtitle => _mr
      ? 'प्रोफाइल, फोटो आणि इंटरेस्ट एका ठिकाणी व्यवस्थापित करा.'
      : 'Manage your profile, photo and interests in one place.';

  static String get browseProfiles =>
      _mr ? 'स्थळे' : 'Matches';

  static String get browseProfilesSubtitle => _mr
      ? 'तुमच्यासाठी योग्य स्थळे शोधा'
      : 'Explore suitable matrimony profiles';

  static String get matchesTabNew => _mr ? 'नवीन' : 'New';

  static String get matchesTabDaily => _mr ? 'दैनिक' : 'Daily';

  static String get matchesTabMyMatches =>
      _mr ? 'माझी जुळणारी स्थळे' : 'My Matches';

  static String get matchesTabNearMe =>
      _mr ? 'जवळची स्थळे' : 'Near Me';

  static String get matchesTabMore =>
      _mr ? 'अधिक स्थळे' : 'More Matches';

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

  static String get upgradeToSeeVisitors => _mr
      ? 'भेट देणारे पाहण्यासाठी अपग्रेड करा'
      : 'Upgrade to see visitors';

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

  static String get notificationsSoon => _mr
      ? 'सूचना लवकरच app मध्ये येतील.'
      : 'Notifications will be available soon.';

  static String get chatComingSoon => _mr
      ? 'Chat सुविधा लवकरच app मध्ये येईल.'
      : 'Chat will be available in the app soon.';

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

  static String get myProfile => _mr ? 'माझे प्रोफाइल' : 'My Profile';

  static String get myProfileSubtitle => _mr
      ? 'तुमची प्रोफाइल माहिती पहा'
      : 'View your matrimony profile';

  static String get editProfile =>
      _mr ? 'प्रोफाइल अपडेट करा' : 'Update Profile';

  static String get uploadPhoto =>
      _mr ? 'फोटो अपलोड करा' : 'Upload Photo';

  static String get uploadPhotoSubtitle => _mr
      ? 'प्रोफाइलसाठी फोटो अपडेट करा'
      : 'Update your profile photo';

  static String get sentInterests =>
      _mr ? 'पाठवलेले इंटरेस्ट' : 'Sent Interests';

  static String get sentInterestsSubtitle => _mr
      ? 'तुम्ही पाठवलेले इंटरेस्ट पहा'
      : 'View interests you have sent';

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

  static String get profileType =>
      _mr ? 'प्रोफाइल प्रकार' : 'Profile type';

  static String get brideGroom =>
      _mr ? 'वधू / वर' : 'Bride / Groom';

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

  static String get sendInterest =>
      _mr ? 'इंटरेस्ट पाठवा' : 'Send Interest';

  static String get interestSent =>
      _mr ? 'इंटरेस्ट पाठवला' : 'Interest Sent';
}
