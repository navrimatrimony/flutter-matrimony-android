import 'app_language.dart';

class AppStrings {
  static bool get _mr => isMarathiApp;

  static String get appName =>
      _mr ? 'नवरी मिळे नवऱ्याला' : 'Navri Mile Navryala';

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
      _mr ? 'स्थळे पहा' : 'Browse Profiles';

  static String get browseProfilesSubtitle => _mr
      ? 'तुमच्यासाठी योग्य स्थळे शोधा'
      : 'Explore suitable matrimony profiles';

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
