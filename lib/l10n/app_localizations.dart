import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_mr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('mr'),
  ];

  /// No description provided for @a4Landscape.
  ///
  /// In en, this message translates to:
  /// **'A4 Landscape'**
  String get a4Landscape;

  /// No description provided for @a4Portrait.
  ///
  /// In en, this message translates to:
  /// **'A4 Portrait'**
  String get a4Portrait;

  /// No description provided for @aClearPhotoUsuallyImprovesResponse.
  ///
  /// In en, this message translates to:
  /// **'A clear photo usually improves response quality.'**
  String get aClearPhotoUsuallyImprovesResponse;

  /// No description provided for @aLocationRequestIsAlreadyRunning.
  ///
  /// In en, this message translates to:
  /// **'A location request is already running.'**
  String get aLocationRequestIsAlreadyRunning;

  /// No description provided for @aboutProfile.
  ///
  /// In en, this message translates to:
  /// **'About profile'**
  String get aboutProfile;

  /// No description provided for @accepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get accepted;

  /// No description provided for @accepted2.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get accepted2;

  /// No description provided for @acceptedIfChildrenLiveSeparately.
  ///
  /// In en, this message translates to:
  /// **'Accepted if children live separately'**
  String get acceptedIfChildrenLiveSeparately;

  /// No description provided for @addAClearPhotoCropIt.
  ///
  /// In en, this message translates to:
  /// **'Add a clear photo. Crop it if needed, then upload it for approval.'**
  String get addAClearPhotoCropIt;

  /// No description provided for @addAProfilePhotoFromCamera.
  ///
  /// In en, this message translates to:
  /// **'Add a profile photo from camera or gallery.'**
  String get addAProfilePhotoFromCamera;

  /// No description provided for @addChild.
  ///
  /// In en, this message translates to:
  /// **'Add child'**
  String get addChild;

  /// No description provided for @addCompanyWorkLocation.
  ///
  /// In en, this message translates to:
  /// **'+ Add company / work location'**
  String get addCompanyWorkLocation;

  /// No description provided for @addName.
  ///
  /// In en, this message translates to:
  /// **'Add name'**
  String get addName;

  /// No description provided for @addNewLocation.
  ///
  /// In en, this message translates to:
  /// **'Add new location'**
  String get addNewLocation;

  /// No description provided for @addOccupationAndOptionalWorkInfo.
  ///
  /// In en, this message translates to:
  /// **'Add occupation and optional work info.'**
  String get addOccupationAndOptionalWorkInfo;

  /// No description provided for @addPhotos.
  ///
  /// In en, this message translates to:
  /// **'Add photos'**
  String get addPhotos;

  /// No description provided for @addPhotosAndReviewPartnerPreference.
  ///
  /// In en, this message translates to:
  /// **'Add photos and review partner preference to improve suggestions.'**
  String get addPhotosAndReviewPartnerPreference;

  /// No description provided for @addedToShortlist.
  ///
  /// In en, this message translates to:
  /// **'Added to Shortlist.'**
  String get addedToShortlist;

  /// No description provided for @addressLineOptional.
  ///
  /// In en, this message translates to:
  /// **'Address line optional'**
  String get addressLineOptional;

  /// No description provided for @age.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get age;

  /// No description provided for @ageRange.
  ///
  /// In en, this message translates to:
  /// **'Age range'**
  String get ageRange;

  /// No description provided for @allowLocationToApplyTheClosest.
  ///
  /// In en, this message translates to:
  /// **'Allow location to apply the closest app location.'**
  String get allowLocationToApplyTheClosest;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// No description provided for @alreadyRegisteredVerifyMobileToContinue.
  ///
  /// In en, this message translates to:
  /// **'Already registered? Verify mobile to continue'**
  String get alreadyRegisteredVerifyMobileToContinue;

  /// No description provided for @and.
  ///
  /// In en, this message translates to:
  /// **' and '**
  String get and;

  /// No description provided for @annual.
  ///
  /// In en, this message translates to:
  /// **'Annual'**
  String get annual;

  /// No description provided for @annualIncome.
  ///
  /// In en, this message translates to:
  /// **'Annual income'**
  String get annualIncome;

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Navri Mile Navryala'**
  String get appName;

  /// No description provided for @applyCrop.
  ///
  /// In en, this message translates to:
  /// **'Apply crop'**
  String get applyCrop;

  /// No description provided for @approvalPending.
  ///
  /// In en, this message translates to:
  /// **'Approval pending'**
  String get approvalPending;

  /// No description provided for @approvalRequired.
  ///
  /// In en, this message translates to:
  /// **'Approval required'**
  String get approvalRequired;

  /// No description provided for @approvedPhotoIsVisibleOnYour.
  ///
  /// In en, this message translates to:
  /// **'Approved photo is visible on your profile. You can replace it with a new photo.'**
  String get approvedPhotoIsVisibleOnYour;

  /// No description provided for @approvedPhotoShownOnProfile.
  ///
  /// In en, this message translates to:
  /// **'This approved photo is shown on your profile.'**
  String get approvedPhotoShownOnProfile;

  /// No description provided for @approvedPhotoShownReplace.
  ///
  /// In en, this message translates to:
  /// **'The approved photo is shown on your profile. You can select a new photo to replace it.'**
  String get approvedPhotoShownReplace;

  /// No description provided for @approx.
  ///
  /// In en, this message translates to:
  /// **'Approx'**
  String get approx;

  /// No description provided for @astroDetails.
  ///
  /// In en, this message translates to:
  /// **'Astro details'**
  String get astroDetails;

  /// No description provided for @authExpiredLoginAgain.
  ///
  /// In en, this message translates to:
  /// **'Authentication expired! Please log in again'**
  String get authExpiredLoginAgain;

  /// No description provided for @authExpiredPleaseLoginAgain.
  ///
  /// In en, this message translates to:
  /// **'Authentication expired. Please log in again.'**
  String get authExpiredPleaseLoginAgain;

  /// No description provided for @basedOnYourPartnerPreferences.
  ///
  /// In en, this message translates to:
  /// **'Based on your partner preferences'**
  String get basedOnYourPartnerPreferences;

  /// No description provided for @basicDetails.
  ///
  /// In en, this message translates to:
  /// **'Basic details'**
  String get basicDetails;

  /// No description provided for @basicPreferences.
  ///
  /// In en, this message translates to:
  /// **'Basic Preferences'**
  String get basicPreferences;

  /// No description provided for @basics.
  ///
  /// In en, this message translates to:
  /// **'Basics'**
  String get basics;

  /// No description provided for @before.
  ///
  /// In en, this message translates to:
  /// **'Before'**
  String get before;

  /// No description provided for @biodataCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get biodataCopyLink;

  /// No description provided for @biodataExpiresAt.
  ///
  /// In en, this message translates to:
  /// **'Link valid until'**
  String get biodataExpiresAt;

  /// No description provided for @biodataExportBrowserOpened.
  ///
  /// In en, this message translates to:
  /// **'Biodata opened in the browser.'**
  String get biodataExportBrowserOpened;

  /// No description provided for @biodataExportDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get biodataExportDownload;

  /// No description provided for @biodataExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Biodata export failed.'**
  String get biodataExportFailed;

  /// No description provided for @biodataExportFormat.
  ///
  /// In en, this message translates to:
  /// **'Choose format'**
  String get biodataExportFormat;

  /// No description provided for @biodataExportLinkExpires.
  ///
  /// In en, this message translates to:
  /// **'Share/download links are valid for a short time.'**
  String get biodataExportLinkExpires;

  /// No description provided for @biodataExportLinkMissing.
  ///
  /// In en, this message translates to:
  /// **'The backend did not return a download link.'**
  String get biodataExportLinkMissing;

  /// No description provided for @biodataExportLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Biodata export options could not be loaded.'**
  String get biodataExportLoadFailed;

  /// No description provided for @biodataExportMenu.
  ///
  /// In en, this message translates to:
  /// **'Biodata Export'**
  String get biodataExportMenu;

  /// No description provided for @biodataExportOpenFailedCopied.
  ///
  /// In en, this message translates to:
  /// **'Could not open the browser. Link copied to clipboard.'**
  String get biodataExportOpenFailedCopied;

  /// No description provided for @biodataExportShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get biodataExportShare;

  /// No description provided for @biodataExportShared.
  ///
  /// In en, this message translates to:
  /// **'Biodata share link is ready.'**
  String get biodataExportShared;

  /// No description provided for @biodataExportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Download or share your own biodata as a PDF.'**
  String get biodataExportSubtitle;

  /// No description provided for @biodataExportTemplate.
  ///
  /// In en, this message translates to:
  /// **'Choose template'**
  String get biodataExportTemplate;

  /// No description provided for @biodataExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Biodata Export'**
  String get biodataExportTitle;

  /// No description provided for @biodataExportUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Biodata export is not available right now.'**
  String get biodataExportUnavailable;

  /// No description provided for @biodataExportWarnings.
  ///
  /// In en, this message translates to:
  /// **'Completeness warnings'**
  String get biodataExportWarnings;

  /// No description provided for @biodataGeneratedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use this link to preview, download, or share the generated biodata.'**
  String get biodataGeneratedSubtitle;

  /// No description provided for @biodataGeneratedTitle.
  ///
  /// In en, this message translates to:
  /// **'Generated biodata is ready'**
  String get biodataGeneratedTitle;

  /// No description provided for @biodataIntakeAlreadyApprovedLocked.
  ///
  /// In en, this message translates to:
  /// **'This biodata is already approved and cannot be edited here.'**
  String get biodataIntakeAlreadyApprovedLocked;

  /// No description provided for @biodataIntakeCheckLowConfidenceFields.
  ///
  /// In en, this message translates to:
  /// **'Please check these fields carefully'**
  String get biodataIntakeCheckLowConfidenceFields;

  /// No description provided for @biodataIntakeConfirmSave.
  ///
  /// In en, this message translates to:
  /// **'Confirm & Save'**
  String get biodataIntakeConfirmSave;

  /// No description provided for @biodataIntakeExtractedText.
  ///
  /// In en, this message translates to:
  /// **'Biodata text used for autofill'**
  String get biodataIntakeExtractedText;

  /// No description provided for @biodataIntakeFailureCodes.
  ///
  /// In en, this message translates to:
  /// **'Failure codes'**
  String get biodataIntakeFailureCodes;

  /// No description provided for @biodataIntakeFieldsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No structured fields were detected. Check the text below and try again with a clearer photo.'**
  String get biodataIntakeFieldsEmpty;

  /// No description provided for @biodataIntakeIntroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use a clear photo or screenshot. The app will read the text and show editable details on the next screen.'**
  String get biodataIntakeIntroSubtitle;

  /// No description provided for @biodataIntakeIntroTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a biodata photo'**
  String get biodataIntakeIntroTitle;

  /// No description provided for @biodataIntakeLowConfidence.
  ///
  /// In en, this message translates to:
  /// **'Low confidence'**
  String get biodataIntakeLowConfidence;

  /// No description provided for @biodataIntakeMenu.
  ///
  /// In en, this message translates to:
  /// **'Biodata Intake'**
  String get biodataIntakeMenu;

  /// No description provided for @biodataIntakeNoReadableText.
  ///
  /// In en, this message translates to:
  /// **'Could not read enough text from this photo. Please use a clearer, straight, well-lit photo.'**
  String get biodataIntakeNoReadableText;

  /// No description provided for @biodataIntakeOpenProfile.
  ///
  /// In en, this message translates to:
  /// **'View Profile'**
  String get biodataIntakeOpenProfile;

  /// No description provided for @biodataIntakeOverallQuality.
  ///
  /// In en, this message translates to:
  /// **'Overall quality'**
  String get biodataIntakeOverallQuality;

  /// No description provided for @biodataIntakeProcessFailed.
  ///
  /// In en, this message translates to:
  /// **'Biodata could not be processed. Please try again.'**
  String get biodataIntakeProcessFailed;

  /// No description provided for @biodataIntakeQualitySignals.
  ///
  /// In en, this message translates to:
  /// **'Quality signals'**
  String get biodataIntakeQualitySignals;

  /// No description provided for @biodataIntakeReviewSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Review could not be saved.'**
  String get biodataIntakeReviewSaveFailed;

  /// No description provided for @biodataIntakeReviewSaveSuccess.
  ///
  /// In en, this message translates to:
  /// **'Review saved. Approval is still separate.'**
  String get biodataIntakeReviewSaveSuccess;

  /// No description provided for @biodataIntakeReviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Edit anything that looks wrong, then save.'**
  String get biodataIntakeReviewSubtitle;

  /// No description provided for @biodataIntakeReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Review details'**
  String get biodataIntakeReviewTitle;

  /// No description provided for @biodataIntakeSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Details could not be saved.'**
  String get biodataIntakeSaveFailed;

  /// No description provided for @biodataIntakeSavePending.
  ///
  /// In en, this message translates to:
  /// **'Details have been saved for review.'**
  String get biodataIntakeSavePending;

  /// No description provided for @biodataIntakeSaveReview.
  ///
  /// In en, this message translates to:
  /// **'Save review'**
  String get biodataIntakeSaveReview;

  /// No description provided for @biodataIntakeSaveSuccess.
  ///
  /// In en, this message translates to:
  /// **'Details saved. Profile has been updated.'**
  String get biodataIntakeSaveSuccess;

  /// No description provided for @biodataIntakeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Read biodata photo text and prepare a profile draft.'**
  String get biodataIntakeSubtitle;

  /// No description provided for @biodataIntakeTitle.
  ///
  /// In en, this message translates to:
  /// **'Biodata Intake'**
  String get biodataIntakeTitle;

  /// No description provided for @biodataIntakeTryAnother.
  ///
  /// In en, this message translates to:
  /// **'Another photo'**
  String get biodataIntakeTryAnother;

  /// No description provided for @biodataLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Biodata link copied.'**
  String get biodataLinkCopied;

  /// No description provided for @biodataNotReadyForReview.
  ///
  /// In en, this message translates to:
  /// **'This biodata is not yet ready for review.'**
  String get biodataNotReadyForReview;

  /// No description provided for @biodataPreviewAction.
  ///
  /// In en, this message translates to:
  /// **'Open preview'**
  String get biodataPreviewAction;

  /// No description provided for @biodataPrintAction.
  ///
  /// In en, this message translates to:
  /// **'Biodata / Print'**
  String get biodataPrintAction;

  /// No description provided for @biodataTemplateDesignPreview.
  ///
  /// In en, this message translates to:
  /// **'Design preview'**
  String get biodataTemplateDesignPreview;

  /// No description provided for @biodataTemplateLocked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get biodataTemplateLocked;

  /// No description provided for @biodataTemplateNoPhoto.
  ///
  /// In en, this message translates to:
  /// **'No photo'**
  String get biodataTemplateNoPhoto;

  /// No description provided for @biodataTemplatePremium.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get biodataTemplatePremium;

  /// No description provided for @biodataTemplateWithPhoto.
  ///
  /// In en, this message translates to:
  /// **'With photo'**
  String get biodataTemplateWithPhoto;

  /// No description provided for @bottomChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get bottomChat;

  /// No description provided for @bottomConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get bottomConnect;

  /// No description provided for @bottomHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get bottomHome;

  /// No description provided for @bottomMatches.
  ///
  /// In en, this message translates to:
  /// **'Matches'**
  String get bottomMatches;

  /// No description provided for @brideGroom.
  ///
  /// In en, this message translates to:
  /// **'Bride / Groom'**
  String get brideGroom;

  /// No description provided for @brideRelativeSDetails.
  ///
  /// In en, this message translates to:
  /// **'Bride relative’s details'**
  String get brideRelativeSDetails;

  /// No description provided for @brideRelativeSFullName.
  ///
  /// In en, this message translates to:
  /// **'Bride relative’s full name *'**
  String get brideRelativeSFullName;

  /// No description provided for @brother.
  ///
  /// In en, this message translates to:
  /// **'Brother'**
  String get brother;

  /// No description provided for @brotherSDetails.
  ///
  /// In en, this message translates to:
  /// **'Brother’s details'**
  String get brotherSDetails;

  /// No description provided for @brotherSFullName.
  ///
  /// In en, this message translates to:
  /// **'Brother’s full name *'**
  String get brotherSFullName;

  /// No description provided for @browseProfiles.
  ///
  /// In en, this message translates to:
  /// **'Matches'**
  String get browseProfiles;

  /// No description provided for @browseProfilesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Explore suitable matrimony profiles'**
  String get browseProfilesSubtitle;

  /// No description provided for @byContinuingIAgreeToThe.
  ///
  /// In en, this message translates to:
  /// **'By continuing, I agree to the '**
  String get byContinuingIAgreeToThe;

  /// No description provided for @byRegisteringIAgreeToThe.
  ///
  /// In en, this message translates to:
  /// **'By registering, I agree to the '**
  String get byRegisteringIAgreeToThe;

  /// No description provided for @calmSteady.
  ///
  /// In en, this message translates to:
  /// **'Calm & steady'**
  String get calmSteady;

  /// No description provided for @camera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get camera;

  /// No description provided for @cameraGalleryProfilePhotoAdd.
  ///
  /// In en, this message translates to:
  /// **'Add a profile photo from the camera or gallery.'**
  String get cameraGalleryProfilePhotoAdd;

  /// No description provided for @canSendContactRequestForProfile.
  ///
  /// In en, this message translates to:
  /// **'You can send a contact request for this profile.'**
  String get canSendContactRequestForProfile;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @cancel2.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel2;

  /// No description provided for @cannotSendInterestForThisProfile.
  ///
  /// In en, this message translates to:
  /// **'Interest cannot be sent for this profile.'**
  String get cannotSendInterestForThisProfile;

  /// No description provided for @careerWithBalance.
  ///
  /// In en, this message translates to:
  /// **'Career with balance'**
  String get careerWithBalance;

  /// No description provided for @careerWithBalance2.
  ///
  /// In en, this message translates to:
  /// **'Career with balance'**
  String get careerWithBalance2;

  /// No description provided for @caste.
  ///
  /// In en, this message translates to:
  /// **'Caste'**
  String get caste;

  /// No description provided for @caste2.
  ///
  /// In en, this message translates to:
  /// **'Caste *'**
  String get caste2;

  /// No description provided for @charan.
  ///
  /// In en, this message translates to:
  /// **'Charan'**
  String get charan;

  /// No description provided for @chatAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get chatAll;

  /// No description provided for @chatComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Chat will be available in the app soon.'**
  String get chatComingSoon;

  /// No description provided for @chatEmpty.
  ///
  /// In en, this message translates to:
  /// **'No chats yet.'**
  String get chatEmpty;

  /// No description provided for @chatInbox.
  ///
  /// In en, this message translates to:
  /// **'Chat Inbox'**
  String get chatInbox;

  /// No description provided for @chatLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Chat could not be loaded.'**
  String get chatLoadFailed;

  /// No description provided for @chatMenu.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chatMenu;

  /// No description provided for @chatMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Type a message...'**
  String get chatMessageHint;

  /// No description provided for @chatMessageRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get chatMessageRead;

  /// No description provided for @chatMessageSent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get chatMessageSent;

  /// No description provided for @chatOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Chat could not be opened.'**
  String get chatOpenFailed;

  /// No description provided for @chatReadLocked.
  ///
  /// In en, this message translates to:
  /// **'Upgrade may be required to read this message.'**
  String get chatReadLocked;

  /// No description provided for @chatRequests.
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get chatRequests;

  /// No description provided for @chatSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get chatSend;

  /// No description provided for @chatSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Message could not be sent.'**
  String get chatSendFailed;

  /// No description provided for @chatTitle.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chatTitle;

  /// No description provided for @chatUnread.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get chatUnread;

  /// No description provided for @chatUpgradeToRead.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to read'**
  String get chatUpgradeToRead;

  /// No description provided for @checkThisNumberBeforeSaving.
  ///
  /// In en, this message translates to:
  /// **'This number must be checked before saving'**
  String get checkThisNumberBeforeSaving;

  /// No description provided for @checkingGoogleEmail.
  ///
  /// In en, this message translates to:
  /// **'Checking Google email'**
  String get checkingGoogleEmail;

  /// No description provided for @checkingProfile.
  ///
  /// In en, this message translates to:
  /// **'Checking profile.'**
  String get checkingProfile;

  /// No description provided for @childLivingWithOptionsCouldNot.
  ///
  /// In en, this message translates to:
  /// **'Child living-with options could not be loaded.'**
  String get childLivingWithOptionsCouldNot;

  /// No description provided for @childName.
  ///
  /// In en, this message translates to:
  /// **'Child name'**
  String get childName;

  /// No description provided for @children.
  ///
  /// In en, this message translates to:
  /// **'Children?'**
  String get children;

  /// No description provided for @childrenSeparate.
  ///
  /// In en, this message translates to:
  /// **'Children separate'**
  String get childrenSeparate;

  /// No description provided for @chooseCityDistrictFromFilters.
  ///
  /// In en, this message translates to:
  /// **'Choose city/district from filters.'**
  String get chooseCityDistrictFromFilters;

  /// No description provided for @chooseCommunityDetails.
  ///
  /// In en, this message translates to:
  /// **'Choose community details'**
  String get chooseCommunityDetails;

  /// No description provided for @chooseGenderBeforeContinuing.
  ///
  /// In en, this message translates to:
  /// **'Choose gender before continuing.'**
  String get chooseGenderBeforeContinuing;

  /// No description provided for @chooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose Language'**
  String get chooseLanguage;

  /// No description provided for @chooseLocationFilter.
  ///
  /// In en, this message translates to:
  /// **'Choose location'**
  String get chooseLocationFilter;

  /// No description provided for @chooseLocationForNearMe.
  ///
  /// In en, this message translates to:
  /// **'Choose a location filter to see nearby profiles.'**
  String get chooseLocationForNearMe;

  /// No description provided for @chooseOccupation.
  ///
  /// In en, this message translates to:
  /// **'Choose occupation.'**
  String get chooseOccupation;

  /// No description provided for @chooseSearchFilters.
  ///
  /// In en, this message translates to:
  /// **'Choose search filters'**
  String get chooseSearchFilters;

  /// No description provided for @chooseTheHighestOrRelevantEducation.
  ///
  /// In en, this message translates to:
  /// **'Choose the highest or relevant education.'**
  String get chooseTheHighestOrRelevantEducation;

  /// No description provided for @chooseWhereTheProfileLives.
  ///
  /// In en, this message translates to:
  /// **'Choose where the profile lives.'**
  String get chooseWhereTheProfileLives;

  /// No description provided for @chooseWhoThisProfileIsFor.
  ///
  /// In en, this message translates to:
  /// **'Choose who this profile is for.'**
  String get chooseWhoThisProfileIsFor;

  /// No description provided for @chooseWhoThisProfileIsFor2.
  ///
  /// In en, this message translates to:
  /// **'Choose who this profile is for.'**
  String get chooseWhoThisProfileIsFor2;

  /// No description provided for @chooseWorkDetails.
  ///
  /// In en, this message translates to:
  /// **'Choose work details.'**
  String get chooseWorkDetails;

  /// No description provided for @citySuburban.
  ///
  /// In en, this message translates to:
  /// **'City / Suburban'**
  String get citySuburban;

  /// No description provided for @cleanBorderPhotoRightA4Portrait.
  ///
  /// In en, this message translates to:
  /// **'Clean border, photo on the right and A4 portrait layout.'**
  String get cleanBorderPhotoRightA4Portrait;

  /// No description provided for @clearFace.
  ///
  /// In en, this message translates to:
  /// **'Clear face'**
  String get clearFace;

  /// No description provided for @clearFilter.
  ///
  /// In en, this message translates to:
  /// **'Clear filter'**
  String get clearFilter;

  /// No description provided for @clearLocation.
  ///
  /// In en, this message translates to:
  /// **'Clear location'**
  String get clearLocation;

  /// No description provided for @community.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get community;

  /// No description provided for @communityDetails.
  ///
  /// In en, this message translates to:
  /// **'Community details'**
  String get communityDetails;

  /// No description provided for @communityPreferencesHelpKeepSuggestionsRelevant.
  ///
  /// In en, this message translates to:
  /// **'Community preferences help keep suggestions relevant.'**
  String get communityPreferencesHelpKeepSuggestionsRelevant;

  /// No description provided for @companyOptional.
  ///
  /// In en, this message translates to:
  /// **'Company optional'**
  String get companyOptional;

  /// No description provided for @comparisonShowLess.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get comparisonShowLess;

  /// No description provided for @comparisonValueUnknown.
  ///
  /// In en, this message translates to:
  /// **'Not specified'**
  String get comparisonValueUnknown;

  /// No description provided for @comparisonViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get comparisonViewAll;

  /// No description provided for @completeAtLeastOneChildDetail.
  ///
  /// In en, this message translates to:
  /// **'Complete at least one child detail.'**
  String get completeAtLeastOneChildDetail;

  /// No description provided for @completeChildDetailsBeforeContinuing.
  ///
  /// In en, this message translates to:
  /// **'Complete child details before continuing.'**
  String get completeChildDetailsBeforeContinuing;

  /// No description provided for @completeRegistration.
  ///
  /// In en, this message translates to:
  /// **'Complete registration'**
  String get completeRegistration;

  /// No description provided for @confirmAction.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirmAction;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @connectContactRequests.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get connectContactRequests;

  /// No description provided for @connectReceived.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get connectReceived;

  /// No description provided for @connectSent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get connectSent;

  /// No description provided for @connectUpgrade.
  ///
  /// In en, this message translates to:
  /// **'Upgrade'**
  String get connectUpgrade;

  /// No description provided for @contactInbox.
  ///
  /// In en, this message translates to:
  /// **'Contact inbox'**
  String get contactInbox;

  /// No description provided for @contactInboxDidNotLoad.
  ///
  /// In en, this message translates to:
  /// **'Contact inbox did not load.'**
  String get contactInboxDidNotLoad;

  /// No description provided for @contactInformationNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Contact information is currently not available.'**
  String get contactInformationNotAvailable;

  /// No description provided for @contactRequestNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Contact request is not available right now.'**
  String get contactRequestNotAvailable;

  /// No description provided for @contactRequestOptionsNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Contact request options are not available.'**
  String get contactRequestOptionsNotAvailable;

  /// No description provided for @contactRequestPending.
  ///
  /// In en, this message translates to:
  /// **'Your contact request is pending.'**
  String get contactRequestPending;

  /// No description provided for @contactRequestRejected.
  ///
  /// In en, this message translates to:
  /// **'Your contact request has been rejected.'**
  String get contactRequestRejected;

  /// No description provided for @contactRequests.
  ///
  /// In en, this message translates to:
  /// **'Contact Requests'**
  String get contactRequests;

  /// No description provided for @contactRoute.
  ///
  /// In en, this message translates to:
  /// **'Contact route'**
  String get contactRoute;

  /// No description provided for @contactRuleStrictness.
  ///
  /// In en, this message translates to:
  /// **'Contact rule strictness'**
  String get contactRuleStrictness;

  /// No description provided for @contactUnlockComingSoon.
  ///
  /// In en, this message translates to:
  /// **'The contact unlock feature will be available soon.'**
  String get contactUnlockComingSoon;

  /// No description provided for @contactUnlockMode.
  ///
  /// In en, this message translates to:
  /// **'Contact unlock mode'**
  String get contactUnlockMode;

  /// No description provided for @contactUnlockNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Contact unlock is not available right now.'**
  String get contactUnlockNotAvailable;

  /// No description provided for @contactVisibility.
  ///
  /// In en, this message translates to:
  /// **'Contact visibility'**
  String get contactVisibility;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @continueToPartnerPreference.
  ///
  /// In en, this message translates to:
  /// **'Continue to partner preference'**
  String get continueToPartnerPreference;

  /// No description provided for @continuing.
  ///
  /// In en, this message translates to:
  /// **'Continuing...'**
  String get continuing;

  /// No description provided for @couldNotAcceptInterest.
  ///
  /// In en, this message translates to:
  /// **'Could not accept interest.'**
  String get couldNotAcceptInterest;

  /// No description provided for @couldNotApproveContact.
  ///
  /// In en, this message translates to:
  /// **'Could not approve contact.'**
  String get couldNotApproveContact;

  /// No description provided for @couldNotBlockProfile.
  ///
  /// In en, this message translates to:
  /// **'Could not block profile.'**
  String get couldNotBlockProfile;

  /// No description provided for @couldNotCheckProfile.
  ///
  /// In en, this message translates to:
  /// **'Could not check profile.'**
  String get couldNotCheckProfile;

  /// No description provided for @couldNotCropPhoto.
  ///
  /// In en, this message translates to:
  /// **'Could not crop the photo. Please try again or select a different photo.'**
  String get couldNotCropPhoto;

  /// No description provided for @couldNotHideProfile.
  ///
  /// In en, this message translates to:
  /// **'Could not hide profile.'**
  String get couldNotHideProfile;

  /// No description provided for @couldNotLoadCasteList.
  ///
  /// In en, this message translates to:
  /// **'Could not load caste list.'**
  String get couldNotLoadCasteList;

  /// No description provided for @couldNotLoadDropdownOptions.
  ///
  /// In en, this message translates to:
  /// **'Could not load the dropdown options.'**
  String get couldNotLoadDropdownOptions;

  /// No description provided for @couldNotLoadEducationAndCareerOptions.
  ///
  /// In en, this message translates to:
  /// **'Could not load the education and career options.'**
  String get couldNotLoadEducationAndCareerOptions;

  /// No description provided for @couldNotLoadFamilyAndHoroscopeOptions.
  ///
  /// In en, this message translates to:
  /// **'Could not load the family and horoscope options.'**
  String get couldNotLoadFamilyAndHoroscopeOptions;

  /// No description provided for @couldNotLoadInterests.
  ///
  /// In en, this message translates to:
  /// **'Could not load interests.'**
  String get couldNotLoadInterests;

  /// No description provided for @couldNotLoadMaritalAndLifestyleOptions.
  ///
  /// In en, this message translates to:
  /// **'Could not load the marital and lifestyle options.'**
  String get couldNotLoadMaritalAndLifestyleOptions;

  /// No description provided for @couldNotLoadOptions.
  ///
  /// In en, this message translates to:
  /// **'Could not load options.'**
  String get couldNotLoadOptions;

  /// No description provided for @couldNotLoadPartnerPreferenceOptions.
  ///
  /// In en, this message translates to:
  /// **'Could not load the partner preference options.'**
  String get couldNotLoadPartnerPreferenceOptions;

  /// No description provided for @couldNotLoadPhotos.
  ///
  /// In en, this message translates to:
  /// **'Photos could not be loaded.'**
  String get couldNotLoadPhotos;

  /// No description provided for @couldNotLoadProfile.
  ///
  /// In en, this message translates to:
  /// **'Could not load the profile.'**
  String get couldNotLoadProfile;

  /// No description provided for @couldNotLoadReligionList.
  ///
  /// In en, this message translates to:
  /// **'Could not load religion list.'**
  String get couldNotLoadReligionList;

  /// No description provided for @couldNotReadAGoogleEmail.
  ///
  /// In en, this message translates to:
  /// **'Could not read a Google email from this device.'**
  String get couldNotReadAGoogleEmail;

  /// No description provided for @couldNotReadAccountNamePlease.
  ///
  /// In en, this message translates to:
  /// **'Could not read account name. Please go back and try again.'**
  String get couldNotReadAccountNamePlease;

  /// No description provided for @couldNotReadEmailFromGoogle.
  ///
  /// In en, this message translates to:
  /// **'Could not read email from Google.'**
  String get couldNotReadEmailFromGoogle;

  /// No description provided for @couldNotReadMobileLocation.
  ///
  /// In en, this message translates to:
  /// **'Could not read mobile location.'**
  String get couldNotReadMobileLocation;

  /// No description provided for @couldNotRefreshPhotoStatus.
  ///
  /// In en, this message translates to:
  /// **'Could not refresh photo status.'**
  String get couldNotRefreshPhotoStatus;

  /// No description provided for @couldNotRefreshProfile.
  ///
  /// In en, this message translates to:
  /// **'Could not refresh the profile.'**
  String get couldNotRefreshProfile;

  /// No description provided for @couldNotRefreshProfileDetails.
  ///
  /// In en, this message translates to:
  /// **'Profile details could not be refreshed.'**
  String get couldNotRefreshProfileDetails;

  /// No description provided for @couldNotRejectContact.
  ///
  /// In en, this message translates to:
  /// **'Could not reject contact.'**
  String get couldNotRejectContact;

  /// No description provided for @couldNotRejectInterest.
  ///
  /// In en, this message translates to:
  /// **'Could not reject interest.'**
  String get couldNotRejectInterest;

  /// No description provided for @couldNotRemoveFromShortlist.
  ///
  /// In en, this message translates to:
  /// **'Could not remove from Shortlist.'**
  String get couldNotRemoveFromShortlist;

  /// No description provided for @couldNotSavePassword.
  ///
  /// In en, this message translates to:
  /// **'Could not save password.'**
  String get couldNotSavePassword;

  /// No description provided for @couldNotSaveProfile.
  ///
  /// In en, this message translates to:
  /// **'Could not save the profile. Please try again.'**
  String get couldNotSaveProfile;

  /// No description provided for @couldNotSaveTheAboutSection.
  ///
  /// In en, this message translates to:
  /// **'Could not save the about section.'**
  String get couldNotSaveTheAboutSection;

  /// No description provided for @couldNotSearchLocation.
  ///
  /// In en, this message translates to:
  /// **'Could not search location.'**
  String get couldNotSearchLocation;

  /// No description provided for @couldNotSearchSubCaste.
  ///
  /// In en, this message translates to:
  /// **'Could not search sub-caste.'**
  String get couldNotSearchSubCaste;

  /// No description provided for @couldNotSendContactRequest.
  ///
  /// In en, this message translates to:
  /// **'Could not send the contact request.'**
  String get couldNotSendContactRequest;

  /// No description provided for @couldNotSendEmailOtp.
  ///
  /// In en, this message translates to:
  /// **'Could not send email OTP.'**
  String get couldNotSendEmailOtp;

  /// No description provided for @couldNotSendInterest.
  ///
  /// In en, this message translates to:
  /// **'Could not send interest. Please try again.'**
  String get couldNotSendInterest;

  /// No description provided for @couldNotSendInterest2.
  ///
  /// In en, this message translates to:
  /// **'Could not send interest.'**
  String get couldNotSendInterest2;

  /// No description provided for @couldNotSendOtp.
  ///
  /// In en, this message translates to:
  /// **'Could not send OTP.'**
  String get couldNotSendOtp;

  /// No description provided for @couldNotShareProfile.
  ///
  /// In en, this message translates to:
  /// **'Could not share profile.'**
  String get couldNotShareProfile;

  /// No description provided for @couldNotShortlist.
  ///
  /// In en, this message translates to:
  /// **'Could not add to Shortlist.'**
  String get couldNotShortlist;

  /// No description provided for @couldNotSubmitLocationRequestCheck.
  ///
  /// In en, this message translates to:
  /// **'Could not submit location request. Check the selected district and taluka, then try again.'**
  String get couldNotSubmitLocationRequestCheck;

  /// No description provided for @couldNotSubmitReport.
  ///
  /// In en, this message translates to:
  /// **'Could not submit report.'**
  String get couldNotSubmitReport;

  /// No description provided for @couldNotSubmitRequest.
  ///
  /// In en, this message translates to:
  /// **'Could not submit request.'**
  String get couldNotSubmitRequest;

  /// No description provided for @couldNotUnlockContact.
  ///
  /// In en, this message translates to:
  /// **'Could not unlock the contact.'**
  String get couldNotUnlockContact;

  /// No description provided for @couldNotUseLocation.
  ///
  /// In en, this message translates to:
  /// **'Could not use location.'**
  String get couldNotUseLocation;

  /// No description provided for @couldNotUseMobileLocation.
  ///
  /// In en, this message translates to:
  /// **'Could not use mobile location.'**
  String get couldNotUseMobileLocation;

  /// No description provided for @couldNotVerifyEmail.
  ///
  /// In en, this message translates to:
  /// **'Could not verify email.'**
  String get couldNotVerifyEmail;

  /// No description provided for @couldNotWithdrawInterest.
  ///
  /// In en, this message translates to:
  /// **'Could not withdraw interest.'**
  String get couldNotWithdrawInterest;

  /// No description provided for @country.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get country;

  /// No description provided for @createAPasswordNowIfYou.
  ///
  /// In en, this message translates to:
  /// **'Create a password now if you want password login later.'**
  String get createAPasswordNowIfYou;

  /// No description provided for @createAdd.
  ///
  /// In en, this message translates to:
  /// **'Create / add'**
  String get createAdd;

  /// No description provided for @createAddYourLocation.
  ///
  /// In en, this message translates to:
  /// **'Create / add your location'**
  String get createAddYourLocation;

  /// No description provided for @createPassword.
  ///
  /// In en, this message translates to:
  /// **'Create Password'**
  String get createPassword;

  /// No description provided for @cropAdjustPhoto.
  ///
  /// In en, this message translates to:
  /// **'Crop / adjust photo'**
  String get cropAdjustPhoto;

  /// No description provided for @cropPhoto.
  ///
  /// In en, this message translates to:
  /// **'Crop photo'**
  String get cropPhoto;

  /// No description provided for @cropTheSelectedPhotoIfNeeded.
  ///
  /// In en, this message translates to:
  /// **'Crop the selected photo if needed, then upload it.'**
  String get cropTheSelectedPhotoIfNeeded;

  /// No description provided for @croppedPhotoIsReadyUploadIt.
  ///
  /// In en, this message translates to:
  /// **'Cropped photo is ready. Upload it to continue.'**
  String get croppedPhotoIsReadyUploadIt;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'My Dashboard'**
  String get dashboard;

  /// No description provided for @dashboardAccountTools.
  ///
  /// In en, this message translates to:
  /// **'Account tools'**
  String get dashboardAccountTools;

  /// No description provided for @dashboardActivity.
  ///
  /// In en, this message translates to:
  /// **'Your activity'**
  String get dashboardActivity;

  /// No description provided for @dashboardAddNow.
  ///
  /// In en, this message translates to:
  /// **'Add now'**
  String get dashboardAddNow;

  /// No description provided for @dashboardBasicDetails.
  ///
  /// In en, this message translates to:
  /// **'Basic details'**
  String get dashboardBasicDetails;

  /// No description provided for @dashboardChangePlan.
  ///
  /// In en, this message translates to:
  /// **'Change plan'**
  String get dashboardChangePlan;

  /// No description provided for @dashboardCheckNotifications.
  ///
  /// In en, this message translates to:
  /// **'Check Notifications'**
  String get dashboardCheckNotifications;

  /// No description provided for @dashboardCheckNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'See new notifications and updates.'**
  String get dashboardCheckNotificationsSubtitle;

  /// No description provided for @dashboardCompleteProfile.
  ///
  /// In en, this message translates to:
  /// **'Complete Profile'**
  String get dashboardCompleteProfile;

  /// No description provided for @dashboardCompleteProfileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Complete key details to improve matching.'**
  String get dashboardCompleteProfileSubtitle;

  /// No description provided for @dashboardCreateProfile.
  ///
  /// In en, this message translates to:
  /// **'Create Profile'**
  String get dashboardCreateProfile;

  /// No description provided for @dashboardCreateProfileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Dashboard fallback: start onboarding if your profile is missing.'**
  String get dashboardCreateProfileSubtitle;

  /// No description provided for @dashboardEducationCareer.
  ///
  /// In en, this message translates to:
  /// **'Education / Career'**
  String get dashboardEducationCareer;

  /// No description provided for @dashboardFreePlan.
  ///
  /// In en, this message translates to:
  /// **'Free Plan'**
  String get dashboardFreePlan;

  /// No description provided for @dashboardHeadline.
  ///
  /// In en, this message translates to:
  /// **'Your next step toward the right match'**
  String get dashboardHeadline;

  /// No description provided for @dashboardHeroFallback.
  ///
  /// In en, this message translates to:
  /// **'Your matrimony dashboard is ready.'**
  String get dashboardHeroFallback;

  /// No description provided for @dashboardListsToolSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Shortlist, block and hidden'**
  String get dashboardListsToolSubtitle;

  /// No description provided for @dashboardLocationDetails.
  ///
  /// In en, this message translates to:
  /// **'Location details'**
  String get dashboardLocationDetails;

  /// No description provided for @dashboardNeedsAttention.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get dashboardNeedsAttention;

  /// No description provided for @dashboardNextBestAction.
  ///
  /// In en, this message translates to:
  /// **'Next best action'**
  String get dashboardNextBestAction;

  /// No description provided for @dashboardPartnerPreference.
  ///
  /// In en, this message translates to:
  /// **'Partner Preference'**
  String get dashboardPartnerPreference;

  /// No description provided for @dashboardPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get dashboardPhoto;

  /// No description provided for @dashboardPhotoApproved.
  ///
  /// In en, this message translates to:
  /// **'Photo approved'**
  String get dashboardPhotoApproved;

  /// No description provided for @dashboardPhotoMissing.
  ///
  /// In en, this message translates to:
  /// **'Photo missing'**
  String get dashboardPhotoMissing;

  /// No description provided for @dashboardPhotoPending.
  ///
  /// In en, this message translates to:
  /// **'Photo pending'**
  String get dashboardPhotoPending;

  /// No description provided for @dashboardPhotoPendingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Check your photo verification status.'**
  String get dashboardPhotoPendingSubtitle;

  /// No description provided for @dashboardPlanContact.
  ///
  /// In en, this message translates to:
  /// **'Plan / Contact status'**
  String get dashboardPlanContact;

  /// No description provided for @dashboardPlanToolSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Plans, payment and contact credits'**
  String get dashboardPlanToolSubtitle;

  /// No description provided for @dashboardPremiumMember.
  ///
  /// In en, this message translates to:
  /// **'Premium Member'**
  String get dashboardPremiumMember;

  /// No description provided for @dashboardProfileActive.
  ///
  /// In en, this message translates to:
  /// **'Profile active'**
  String get dashboardProfileActive;

  /// No description provided for @dashboardProfileMissing.
  ///
  /// In en, this message translates to:
  /// **'Profile missing'**
  String get dashboardProfileMissing;

  /// No description provided for @dashboardQuickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get dashboardQuickActions;

  /// No description provided for @dashboardReadiness.
  ///
  /// In en, this message translates to:
  /// **'Profile readiness'**
  String get dashboardReadiness;

  /// No description provided for @dashboardReadinessSubtitle.
  ///
  /// In en, this message translates to:
  /// **'No fake percentage; checklist based on available data.'**
  String get dashboardReadinessSubtitle;

  /// No description provided for @dashboardReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get dashboardReady;

  /// No description provided for @dashboardReplyMessages.
  ///
  /// In en, this message translates to:
  /// **'Reply to Messages'**
  String get dashboardReplyMessages;

  /// No description provided for @dashboardReplyMessagesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Unread chats are waiting for your response.'**
  String get dashboardReplyMessagesSubtitle;

  /// No description provided for @dashboardRespondInterests.
  ///
  /// In en, this message translates to:
  /// **'Respond to Interests'**
  String get dashboardRespondInterests;

  /// No description provided for @dashboardRespondInterestsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review pending proposals and respond.'**
  String get dashboardRespondInterestsSubtitle;

  /// No description provided for @dashboardReviewContactRequests.
  ///
  /// In en, this message translates to:
  /// **'Review Contact Requests'**
  String get dashboardReviewContactRequests;

  /// No description provided for @dashboardReviewContactRequestsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review pending contact requests safely.'**
  String get dashboardReviewContactRequestsSubtitle;

  /// No description provided for @dashboardSettingsToolSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy and preferences'**
  String get dashboardSettingsToolSubtitle;

  /// No description provided for @dashboardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage your profile, photo and interests in one place.'**
  String get dashboardSubtitle;

  /// No description provided for @dashboardUpgradePlan.
  ///
  /// In en, this message translates to:
  /// **'Upgrade Plan'**
  String get dashboardUpgradePlan;

  /// No description provided for @dashboardUpgradePlanSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View contact unlocks and premium benefits.'**
  String get dashboardUpgradePlanSubtitle;

  /// No description provided for @dashboardUploadPhotoPrompt.
  ///
  /// In en, this message translates to:
  /// **'Upload a clear photo to get better responses.'**
  String get dashboardUploadPhotoPrompt;

  /// No description provided for @dashboardViewMatches.
  ///
  /// In en, this message translates to:
  /// **'View Matches'**
  String get dashboardViewMatches;

  /// No description provided for @dashboardViewMatchesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Explore suitable profiles for you.'**
  String get dashboardViewMatchesSubtitle;

  /// No description provided for @dateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Date of birth'**
  String get dateOfBirth;

  /// No description provided for @dateOfBirth2.
  ///
  /// In en, this message translates to:
  /// **'Date of birth *'**
  String get dateOfBirth2;

  /// No description provided for @daughter.
  ///
  /// In en, this message translates to:
  /// **'Daughter'**
  String get daughter;

  /// No description provided for @daughterSDetails.
  ///
  /// In en, this message translates to:
  /// **'Daughter’s details'**
  String get daughterSDetails;

  /// No description provided for @daughterSFullName.
  ///
  /// In en, this message translates to:
  /// **'Daughter’s full name *'**
  String get daughterSFullName;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deletePhoto.
  ///
  /// In en, this message translates to:
  /// **'Delete photo'**
  String get deletePhoto;

  /// No description provided for @deviceLocationIsOffTurnOn.
  ///
  /// In en, this message translates to:
  /// **'Device location is off. Turn on location from settings.'**
  String get deviceLocationIsOffTurnOn;

  /// No description provided for @didnTGetTheCodeYet.
  ///
  /// In en, this message translates to:
  /// **'Didn’t get the code yet?'**
  String get didnTGetTheCodeYet;

  /// No description provided for @diet.
  ///
  /// In en, this message translates to:
  /// **'Diet'**
  String get diet;

  /// No description provided for @district.
  ///
  /// In en, this message translates to:
  /// **'District'**
  String get district;

  /// No description provided for @doNotCloseScreenUntilUploadComplete.
  ///
  /// In en, this message translates to:
  /// **'Do not close the screen until the upload is complete.'**
  String get doNotCloseScreenUntilUploadComplete;

  /// No description provided for @doNotEnterContactNumbersOrPrivateDetails.
  ///
  /// In en, this message translates to:
  /// **'Do not enter contact numbers or private details.'**
  String get doNotEnterContactNumbersOrPrivateDetails;

  /// No description provided for @doubleBorderPortrait.
  ///
  /// In en, this message translates to:
  /// **'Double Border Portrait'**
  String get doubleBorderPortrait;

  /// No description provided for @draftParsedReview.
  ///
  /// In en, this message translates to:
  /// **'Draft / parsed review'**
  String get draftParsedReview;

  /// No description provided for @draftRowsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Draft rows are not available.'**
  String get draftRowsUnavailable;

  /// No description provided for @drinking.
  ///
  /// In en, this message translates to:
  /// **'Drinking'**
  String get drinking;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @editOneSectionAtATimeProfileReloadsAfterSave.
  ///
  /// In en, this message translates to:
  /// **'Edit one section at a time. After saving, the profile will reload freshly.'**
  String get editOneSectionAtATimeProfileReloadsAfterSave;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Update Profile'**
  String get editProfile;

  /// No description provided for @editTheEmailIfNeededThen.
  ///
  /// In en, this message translates to:
  /// **'Edit the email if needed, then verify it with Google or email OTP.'**
  String get editTheEmailIfNeededThen;

  /// No description provided for @education.
  ///
  /// In en, this message translates to:
  /// **'Education'**
  String get education;

  /// No description provided for @education2.
  ///
  /// In en, this message translates to:
  /// **'Education *'**
  String get education2;

  /// No description provided for @educationCareer.
  ///
  /// In en, this message translates to:
  /// **'Education & Career'**
  String get educationCareer;

  /// No description provided for @educationLabel.
  ///
  /// In en, this message translates to:
  /// **'Education label'**
  String get educationLabel;

  /// No description provided for @educationRequestSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Education request submitted.'**
  String get educationRequestSubmitted;

  /// No description provided for @emailAdded.
  ///
  /// In en, this message translates to:
  /// **'Email added'**
  String get emailAdded;

  /// No description provided for @emailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get emailAddress;

  /// No description provided for @emailAlerts.
  ///
  /// In en, this message translates to:
  /// **'Email alerts'**
  String get emailAlerts;

  /// No description provided for @emailOtp.
  ///
  /// In en, this message translates to:
  /// **'Email OTP'**
  String get emailOtp;

  /// No description provided for @emailUsedForAccountMobileVerification.
  ///
  /// In en, this message translates to:
  /// **'This email will be used for the account. Mobile verification is required to proceed.'**
  String get emailUsedForAccountMobileVerification;

  /// No description provided for @emailVerified.
  ///
  /// In en, this message translates to:
  /// **'Email verified'**
  String get emailVerified;

  /// No description provided for @emailVerifiedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Email verified successfully.'**
  String get emailVerifiedSuccessfully;

  /// No description provided for @enterAValid10DigitMobile.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid 10 digit mobile number.'**
  String get enterAValid10DigitMobile;

  /// No description provided for @enterAValidDob.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid DOB.'**
  String get enterAValidDob;

  /// No description provided for @enterAValidEmailAddress.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get enterAValidEmailAddress;

  /// No description provided for @enterAValidIncomeAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid income amount.'**
  String get enterAValidIncomeAmount;

  /// No description provided for @enterAValidMaxIncome.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid max income.'**
  String get enterAValidMaxIncome;

  /// No description provided for @enterAValidMinIncome.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid min income.'**
  String get enterAValidMinIncome;

  /// No description provided for @enterCandidateRealNameBeforeSaving.
  ///
  /// In en, this message translates to:
  /// **'Enter the candidate\'s real name before saving'**
  String get enterCandidateRealNameBeforeSaving;

  /// No description provided for @enterChildAge.
  ///
  /// In en, this message translates to:
  /// **'Enter child age.'**
  String get enterChildAge;

  /// No description provided for @enterFullName.
  ///
  /// In en, this message translates to:
  /// **'Enter full name.'**
  String get enterFullName;

  /// No description provided for @enterMinIncomeToo.
  ///
  /// In en, this message translates to:
  /// **'Enter min income too.'**
  String get enterMinIncomeToo;

  /// No description provided for @enterPasswordAndConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter password and confirm password.'**
  String get enterPasswordAndConfirmPassword;

  /// No description provided for @enterThe6DigitOtp.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6 digit OTP.'**
  String get enterThe6DigitOtp;

  /// No description provided for @enterThe6DigitOtp2.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6 digit OTP.'**
  String get enterThe6DigitOtp2;

  /// No description provided for @enterTheOtpSentToYour.
  ///
  /// In en, this message translates to:
  /// **'Enter the OTP sent to your email.'**
  String get enterTheOtpSentToYour;

  /// No description provided for @enterTitleAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter the \$title amount.'**
  String get enterTitleAmount;

  /// No description provided for @enterTitleRangeAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter the \$title range amount.'**
  String get enterTitleRangeAmount;

  /// No description provided for @enterValidChildAge.
  ///
  /// In en, this message translates to:
  /// **'Enter valid child age.'**
  String get enterValidChildAge;

  /// No description provided for @enterYourMobileNumberToReceive.
  ///
  /// In en, this message translates to:
  /// **'Enter your mobile number to receive a secure 6 digit code.'**
  String get enterYourMobileNumberToReceive;

  /// No description provided for @exact.
  ///
  /// In en, this message translates to:
  /// **'Exact'**
  String get exact;

  /// No description provided for @extraNoteOptional.
  ///
  /// In en, this message translates to:
  /// **'Extra note optional'**
  String get extraNoteOptional;

  /// No description provided for @familyAndAbout.
  ///
  /// In en, this message translates to:
  /// **'Family and about'**
  String get familyAndAbout;

  /// No description provided for @familyDetails.
  ///
  /// In en, this message translates to:
  /// **'Family details'**
  String get familyDetails;

  /// No description provided for @familyFriendly.
  ///
  /// In en, this message translates to:
  /// **'Family-friendly'**
  String get familyFriendly;

  /// No description provided for @familyStatus.
  ///
  /// In en, this message translates to:
  /// **'Family status'**
  String get familyStatus;

  /// No description provided for @familyValues.
  ///
  /// In en, this message translates to:
  /// **'Family values'**
  String get familyValues;

  /// No description provided for @featureNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'This feature is not available right now.'**
  String get featureNotAvailable;

  /// No description provided for @female.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get female;

  /// No description provided for @friend.
  ///
  /// In en, this message translates to:
  /// **'Friend'**
  String get friend;

  /// No description provided for @friendSDetails.
  ///
  /// In en, this message translates to:
  /// **'Friend’s details'**
  String get friendSDetails;

  /// No description provided for @friendSDetails2.
  ///
  /// In en, this message translates to:
  /// **'Friend’s details'**
  String get friendSDetails2;

  /// No description provided for @friendSDetails3.
  ///
  /// In en, this message translates to:
  /// **'Friend’s details'**
  String get friendSDetails3;

  /// No description provided for @friendSFullName.
  ///
  /// In en, this message translates to:
  /// **'Friend’s full name *'**
  String get friendSFullName;

  /// No description provided for @friendSFullName2.
  ///
  /// In en, this message translates to:
  /// **'Friend’s full name *'**
  String get friendSFullName2;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full name *'**
  String get fullName;

  /// No description provided for @gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery;

  /// No description provided for @gender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get gender;

  /// No description provided for @getOtp.
  ///
  /// In en, this message translates to:
  /// **'Get OTP'**
  String get getOtp;

  /// No description provided for @gettingLocation.
  ///
  /// In en, this message translates to:
  /// **'Getting location...'**
  String get gettingLocation;

  /// No description provided for @goodLight.
  ///
  /// In en, this message translates to:
  /// **'Good light'**
  String get goodLight;

  /// No description provided for @googleVerificationFailedWeWillVerify.
  ///
  /// In en, this message translates to:
  /// **'Google verification failed. We will verify this email with OTP.'**
  String get googleVerificationFailedWeWillVerify;

  /// No description provided for @googleVerificationIsNotReadyWe.
  ///
  /// In en, this message translates to:
  /// **'Google verification is not ready. We will verify this email with OTP.'**
  String get googleVerificationIsNotReadyWe;

  /// No description provided for @googleVerifiedYourEmail.
  ///
  /// In en, this message translates to:
  /// **'Google verified your email.'**
  String get googleVerifiedYourEmail;

  /// No description provided for @grantAtLeastOneContactMethod.
  ///
  /// In en, this message translates to:
  /// **'Grant at least one contact method.'**
  String get grantAtLeastOneContactMethod;

  /// No description provided for @groomRelativeSDetails.
  ///
  /// In en, this message translates to:
  /// **'Groom relative’s details'**
  String get groomRelativeSDetails;

  /// No description provided for @groomRelativeSFullName.
  ///
  /// In en, this message translates to:
  /// **'Groom relative’s full name *'**
  String get groomRelativeSFullName;

  /// No description provided for @gunamilanDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Gunamilan is only a compatibility reference. Families should make the final decision after discussion.'**
  String get gunamilanDisclaimer;

  /// No description provided for @gunamilanHideDetails.
  ///
  /// In en, this message translates to:
  /// **'Hide details'**
  String get gunamilanHideDetails;

  /// No description provided for @gunamilanIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Horoscope data is incomplete.'**
  String get gunamilanIncomplete;

  /// No description provided for @gunamilanRequired.
  ///
  /// In en, this message translates to:
  /// **'Gunamilan match required'**
  String get gunamilanRequired;

  /// No description provided for @gunamilanRequiredHelp.
  ///
  /// In en, this message translates to:
  /// **'When on, only matches scoring at least 18 of 36 are shown. If either side has no patrika details filled in, the match is not excluded — gunamilan simply cannot be checked.'**
  String get gunamilanRequiredHelp;

  /// No description provided for @gunamilanScore.
  ///
  /// In en, this message translates to:
  /// **'Gunamilan score'**
  String get gunamilanScore;

  /// No description provided for @gunamilanTitle.
  ///
  /// In en, this message translates to:
  /// **'Gunamilan / Horoscope Match'**
  String get gunamilanTitle;

  /// No description provided for @gunamilanViewDetails.
  ///
  /// In en, this message translates to:
  /// **'View details'**
  String get gunamilanViewDetails;

  /// No description provided for @height.
  ///
  /// In en, this message translates to:
  /// **'Height *'**
  String get height;

  /// No description provided for @heightRangeCm.
  ///
  /// In en, this message translates to:
  /// **'Height range cm'**
  String get heightRangeCm;

  /// No description provided for @herMotherTongue.
  ///
  /// In en, this message translates to:
  /// **'Her mother tongue'**
  String get herMotherTongue;

  /// No description provided for @hideFromBlockedUsers.
  ///
  /// In en, this message translates to:
  /// **'Hide from blocked users'**
  String get hideFromBlockedUsers;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @highestSelected.
  ///
  /// In en, this message translates to:
  /// **'Highest selected: '**
  String get highestSelected;

  /// No description provided for @hisMotherTongue.
  ///
  /// In en, this message translates to:
  /// **'His mother tongue'**
  String get hisMotherTongue;

  /// No description provided for @honestyRespect.
  ///
  /// In en, this message translates to:
  /// **'Honesty & respect'**
  String get honestyRespect;

  /// No description provided for @iAmCreatingThisProfileFor.
  ///
  /// In en, this message translates to:
  /// **'I am creating this profile for'**
  String get iAmCreatingThisProfileFor;

  /// No description provided for @iWillDoThisLater.
  ///
  /// In en, this message translates to:
  /// **'I will do this later'**
  String get iWillDoThisLater;

  /// No description provided for @importantSettingsAreNext.
  ///
  /// In en, this message translates to:
  /// **'Important settings are next'**
  String get importantSettingsAreNext;

  /// No description provided for @inactiveReminder.
  ///
  /// In en, this message translates to:
  /// **'Inactive reminder'**
  String get inactiveReminder;

  /// No description provided for @income.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get income;

  /// No description provided for @incomeAmount.
  ///
  /// In en, this message translates to:
  /// **'Income amount'**
  String get incomeAmount;

  /// No description provided for @incomeAmount2.
  ///
  /// In en, this message translates to:
  /// **'Income amount'**
  String get incomeAmount2;

  /// No description provided for @incomeCanBeKeptPrivate.
  ///
  /// In en, this message translates to:
  /// **'Income can be kept private.'**
  String get incomeCanBeKeptPrivate;

  /// No description provided for @incomePeriod.
  ///
  /// In en, this message translates to:
  /// **'Income period'**
  String get incomePeriod;

  /// No description provided for @incomeRange.
  ///
  /// In en, this message translates to:
  /// **'Income range'**
  String get incomeRange;

  /// No description provided for @incomeRange2.
  ///
  /// In en, this message translates to:
  /// **'Income range'**
  String get incomeRange2;

  /// No description provided for @incomeType.
  ///
  /// In en, this message translates to:
  /// **'Income type'**
  String get incomeType;

  /// No description provided for @intercasteAccepted.
  ///
  /// In en, this message translates to:
  /// **'Intercaste accepted.'**
  String get intercasteAccepted;

  /// No description provided for @interestAlreadySent.
  ///
  /// In en, this message translates to:
  /// **'Interest has already been sent.'**
  String get interestAlreadySent;

  /// No description provided for @interestSent.
  ///
  /// In en, this message translates to:
  /// **'Interest Sent'**
  String get interestSent;

  /// No description provided for @interestSent2.
  ///
  /// In en, this message translates to:
  /// **'Interest sent.'**
  String get interestSent2;

  /// No description provided for @interestStatistics.
  ///
  /// In en, this message translates to:
  /// **'Interest Statistics'**
  String get interestStatistics;

  /// No description provided for @keepIncomePrivate.
  ///
  /// In en, this message translates to:
  /// **'Keep income private'**
  String get keepIncomePrivate;

  /// No description provided for @keepIncomePrivate2.
  ///
  /// In en, this message translates to:
  /// **'Keep income private'**
  String get keepIncomePrivate2;

  /// No description provided for @label.
  ///
  /// In en, this message translates to:
  /// **'label'**
  String get label;

  /// No description provided for @landingHeadline.
  ///
  /// In en, this message translates to:
  /// **'A trusted way to find the right match'**
  String get landingHeadline;

  /// No description provided for @landingSubline.
  ///
  /// In en, this message translates to:
  /// **'Safe, simple and family-friendly matrimony platform'**
  String get landingSubline;

  /// No description provided for @landscapeLayoutLargePhotoCompact.
  ///
  /// In en, this message translates to:
  /// **'Large photo and compact information in a landscape layout.'**
  String get landscapeLayoutLargePhotoCompact;

  /// No description provided for @languageMenu.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageMenu;

  /// No description provided for @languageSwitchSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Change app language'**
  String get languageSwitchSubtitle;

  /// No description provided for @leftRight.
  ///
  /// In en, this message translates to:
  /// **'Left / right'**
  String get leftRight;

  /// No description provided for @lessThan1YearIsNot.
  ///
  /// In en, this message translates to:
  /// **'Less than 1 year is not supported by the current save rules. Select 1 year for now.'**
  String get lessThan1YearIsNot;

  /// No description provided for @lifestyle.
  ///
  /// In en, this message translates to:
  /// **'Lifestyle'**
  String get lifestyle;

  /// No description provided for @lifestyleDetails.
  ///
  /// In en, this message translates to:
  /// **'Lifestyle details'**
  String get lifestyleDetails;

  /// No description provided for @lifestylePreferences.
  ///
  /// In en, this message translates to:
  /// **'Lifestyle Preferences'**
  String get lifestylePreferences;

  /// No description provided for @likeThisProfile.
  ///
  /// In en, this message translates to:
  /// **'Like this profile?'**
  String get likeThisProfile;

  /// No description provided for @livingWith.
  ///
  /// In en, this message translates to:
  /// **'Living with'**
  String get livingWith;

  /// No description provided for @livingWithOptionsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Living-with options unavailable.'**
  String get livingWithOptionsUnavailable;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @loadingBiodataOptions.
  ///
  /// In en, this message translates to:
  /// **'Loading biodata options'**
  String get loadingBiodataOptions;

  /// No description provided for @loadingChats.
  ///
  /// In en, this message translates to:
  /// **'Loading chats'**
  String get loadingChats;

  /// No description provided for @loadingContactRequests.
  ///
  /// In en, this message translates to:
  /// **'Loading contact requests'**
  String get loadingContactRequests;

  /// No description provided for @loadingConversation.
  ///
  /// In en, this message translates to:
  /// **'Loading conversation'**
  String get loadingConversation;

  /// No description provided for @loadingMatches.
  ///
  /// In en, this message translates to:
  /// **'Loading matches'**
  String get loadingMatches;

  /// No description provided for @loadingNotifications.
  ///
  /// In en, this message translates to:
  /// **'Loading notifications'**
  String get loadingNotifications;

  /// No description provided for @loadingPhotos.
  ///
  /// In en, this message translates to:
  /// **'Loading photos'**
  String get loadingPhotos;

  /// No description provided for @loadingPlans.
  ///
  /// In en, this message translates to:
  /// **'Loading plans'**
  String get loadingPlans;

  /// No description provided for @loadingProfile.
  ///
  /// In en, this message translates to:
  /// **'Loading profile'**
  String get loadingProfile;

  /// No description provided for @loadingProfileLists.
  ///
  /// In en, this message translates to:
  /// **'Loading profile lists'**
  String get loadingProfileLists;

  /// No description provided for @loadingReceivedInterests.
  ///
  /// In en, this message translates to:
  /// **'Loading received interests'**
  String get loadingReceivedInterests;

  /// No description provided for @loadingSentInterests.
  ///
  /// In en, this message translates to:
  /// **'Loading sent interests'**
  String get loadingSentInterests;

  /// No description provided for @loadingSettings.
  ///
  /// In en, this message translates to:
  /// **'Loading settings'**
  String get loadingSettings;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @locationDetails.
  ///
  /// In en, this message translates to:
  /// **'Location details'**
  String get locationDetails;

  /// No description provided for @locationEntryAddedYouCanContinue.
  ///
  /// In en, this message translates to:
  /// **'Location entry added. You can continue.'**
  String get locationEntryAddedYouCanContinue;

  /// No description provided for @locationFoundButNoMatchingApp.
  ///
  /// In en, this message translates to:
  /// **'Location found, but no matching app location was found.'**
  String get locationFoundButNoMatchingApp;

  /// No description provided for @locationPermissionIsNeededForNearby.
  ///
  /// In en, this message translates to:
  /// **'Location permission is needed for Nearby.'**
  String get locationPermissionIsNeededForNearby;

  /// No description provided for @locationPermissionWasDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission was denied.'**
  String get locationPermissionWasDenied;

  /// No description provided for @locationPreference.
  ///
  /// In en, this message translates to:
  /// **'Location preference'**
  String get locationPreference;

  /// No description provided for @locationPreferences.
  ///
  /// In en, this message translates to:
  /// **'Location Preferences'**
  String get locationPreferences;

  /// No description provided for @locationSelected.
  ///
  /// In en, this message translates to:
  /// **'Location selected'**
  String get locationSelected;

  /// No description provided for @locationTookTooLongTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Location took too long. Try again.'**
  String get locationTookTooLongTryAgain;

  /// No description provided for @lockedProfile.
  ///
  /// In en, this message translates to:
  /// **'Locked profile'**
  String get lockedProfile;

  /// No description provided for @lockedVisitor.
  ///
  /// In en, this message translates to:
  /// **'Locked visitor'**
  String get lockedVisitor;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @loginChangeMobile.
  ///
  /// In en, this message translates to:
  /// **'Change mobile number'**
  String get loginChangeMobile;

  /// No description provided for @loginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed. Check login or password.'**
  String get loginFailed;

  /// No description provided for @loginHidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get loginHidePassword;

  /// No description provided for @loginIdentifierLabel.
  ///
  /// In en, this message translates to:
  /// **'Mobile / Email / Username'**
  String get loginIdentifierLabel;

  /// No description provided for @loginKeepSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Keep me signed in'**
  String get loginKeepSignedIn;

  /// No description provided for @loginKeepSignedInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Open the app next time without entering your password.'**
  String get loginKeepSignedInSubtitle;

  /// No description provided for @loginMissingFields.
  ///
  /// In en, this message translates to:
  /// **'Enter login and password.'**
  String get loginMissingFields;

  /// No description provided for @loginMobileHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your mobile number. We will send you a one-time code.'**
  String get loginMobileHint;

  /// No description provided for @loginNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the server. Check your internet and try again.'**
  String get loginNetworkError;

  /// No description provided for @loginOtpAutoFillHint.
  ///
  /// In en, this message translates to:
  /// **'If the code arrives on this phone it fills in by itself.'**
  String get loginOtpAutoFillHint;

  /// No description provided for @loginOtpSentHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the code we sent to your mobile number.'**
  String get loginOtpSentHint;

  /// No description provided for @loginOtpWhatsappHint.
  ///
  /// In en, this message translates to:
  /// **'The code was sent on WhatsApp.'**
  String get loginOtpWhatsappHint;

  /// No description provided for @loginPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get loginPasswordLabel;

  /// No description provided for @loginPickFromSim.
  ///
  /// In en, this message translates to:
  /// **'Pick from SIM'**
  String get loginPickFromSim;

  /// No description provided for @loginProfileCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Profile check failed. Please try again.'**
  String get loginProfileCheckFailed;

  /// No description provided for @loginProfileMissing.
  ///
  /// In en, this message translates to:
  /// **'Profile not found. Create your profile.'**
  String get loginProfileMissing;

  /// No description provided for @loginRegisterPrompt.
  ///
  /// In en, this message translates to:
  /// **'New user? Register here'**
  String get loginRegisterPrompt;

  /// No description provided for @loginShowPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get loginShowPassword;

  /// No description provided for @loginSuccess.
  ///
  /// In en, this message translates to:
  /// **'Login successful. Welcome back.'**
  String get loginSuccess;

  /// No description provided for @loginTestOtpBanner.
  ///
  /// In en, this message translates to:
  /// **'Test mode. This code is shown only because real messages are not being sent yet.'**
  String get loginTestOtpBanner;

  /// No description provided for @loginUseOtpInstead.
  ///
  /// In en, this message translates to:
  /// **'Use OTP instead'**
  String get loginUseOtpInstead;

  /// No description provided for @loginUsePasswordInstead.
  ///
  /// In en, this message translates to:
  /// **'Use password instead'**
  String get loginUsePasswordInstead;

  /// No description provided for @loginWelcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Continue your matrimony journey securely.'**
  String get loginWelcomeSubtitle;

  /// No description provided for @loginWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get loginWelcomeTitle;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @logoutToExit.
  ///
  /// In en, this message translates to:
  /// **'Use Logout when you want to leave this account.'**
  String get logoutToExit;

  /// No description provided for @makeSelectionBeforeSaving.
  ///
  /// In en, this message translates to:
  /// **'A selection must be made before saving'**
  String get makeSelectionBeforeSaving;

  /// No description provided for @male.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get male;

  /// No description provided for @mangalDosh.
  ///
  /// In en, this message translates to:
  /// **'Mangal dosh'**
  String get mangalDosh;

  /// No description provided for @maritalStatus.
  ///
  /// In en, this message translates to:
  /// **'Marital status'**
  String get maritalStatus;

  /// No description provided for @maritalStatusOptionsCouldNotBe.
  ///
  /// In en, this message translates to:
  /// **'Marital status options could not be loaded.'**
  String get maritalStatusOptionsCouldNotBe;

  /// No description provided for @marriageType.
  ///
  /// In en, this message translates to:
  /// **'Marriage type'**
  String get marriageType;

  /// No description provided for @matchesFilter.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get matchesFilter;

  /// No description provided for @matchesFilterHint.
  ///
  /// In en, this message translates to:
  /// **'Age, caste, location'**
  String get matchesFilterHint;

  /// No description provided for @matchesScreenWillAppearSoon.
  ///
  /// In en, this message translates to:
  /// **'The matches screen will appear in a moment.'**
  String get matchesScreenWillAppearSoon;

  /// No description provided for @matchesTabDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get matchesTabDaily;

  /// No description provided for @matchesTabMore.
  ///
  /// In en, this message translates to:
  /// **'More Matches'**
  String get matchesTabMore;

  /// No description provided for @matchesTabMyMatches.
  ///
  /// In en, this message translates to:
  /// **'My Matches'**
  String get matchesTabMyMatches;

  /// No description provided for @matchesTabNearMe.
  ///
  /// In en, this message translates to:
  /// **'Near Me'**
  String get matchesTabNearMe;

  /// No description provided for @matchesTabNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get matchesTabNew;

  /// No description provided for @matchesTabSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get matchesTabSearch;

  /// No description provided for @max.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get max;

  /// No description provided for @maxIncome.
  ///
  /// In en, this message translates to:
  /// **'Max income'**
  String get maxIncome;

  /// No description provided for @maxIncomeMustBeMoreThan.
  ///
  /// In en, this message translates to:
  /// **'Max income must be more than min income.'**
  String get maxIncomeMustBeMoreThan;

  /// No description provided for @membersYouMayLike.
  ///
  /// In en, this message translates to:
  /// **'Profiles you may like'**
  String get membersYouMayLike;

  /// No description provided for @min.
  ///
  /// In en, this message translates to:
  /// **'Min'**
  String get min;

  /// No description provided for @minIncome.
  ///
  /// In en, this message translates to:
  /// **'Min income'**
  String get minIncome;

  /// No description provided for @mobileLocationFilledPleaseReviewIt.
  ///
  /// In en, this message translates to:
  /// **'Mobile location filled. Please review it before continuing.'**
  String get mobileLocationFilledPleaseReviewIt;

  /// No description provided for @mobileLocationIsAlreadyRunning.
  ///
  /// In en, this message translates to:
  /// **'Mobile location is already running.'**
  String get mobileLocationIsAlreadyRunning;

  /// No description provided for @mobileLocationMatchedPleaseReviewIt.
  ///
  /// In en, this message translates to:
  /// **'Mobile location matched. Please review it before continuing.'**
  String get mobileLocationMatchedPleaseReviewIt;

  /// No description provided for @mobileLocationTimedOutTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Mobile location timed out. Try again or search manually.'**
  String get mobileLocationTimedOutTryAgain;

  /// No description provided for @mobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Mobile number *'**
  String get mobileNumber;

  /// No description provided for @mobileNumber2.
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get mobileNumber2;

  /// No description provided for @mobileVerificationKeepsTheAccountSecure.
  ///
  /// In en, this message translates to:
  /// **'Mobile verification keeps the account secure and recoverable.'**
  String get mobileVerificationKeepsTheAccountSecure;

  /// No description provided for @mobileVerified.
  ///
  /// In en, this message translates to:
  /// **'Mobile verified'**
  String get mobileVerified;

  /// No description provided for @monthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get monthly;

  /// No description provided for @moreMatchesSectionsAreUnavailableShowing.
  ///
  /// In en, this message translates to:
  /// **'More Matches sections are unavailable. Showing available matches below.'**
  String get moreMatchesSectionsAreUnavailableShowing;

  /// No description provided for @moreProfilesYouMayLike.
  ///
  /// In en, this message translates to:
  /// **'More suitable profiles'**
  String get moreProfilesYouMayLike;

  /// No description provided for @motherTongue.
  ///
  /// In en, this message translates to:
  /// **'Mother tongue *'**
  String get motherTongue;

  /// No description provided for @motherTongue2.
  ///
  /// In en, this message translates to:
  /// **'Mother tongue'**
  String get motherTongue2;

  /// No description provided for @moveLeft.
  ///
  /// In en, this message translates to:
  /// **'Move left'**
  String get moveLeft;

  /// No description provided for @moveRight.
  ///
  /// In en, this message translates to:
  /// **'Move right'**
  String get moveRight;

  /// No description provided for @myProfile.
  ///
  /// In en, this message translates to:
  /// **'My Profile'**
  String get myProfile;

  /// No description provided for @myProfileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View your matrimony profile'**
  String get myProfileSubtitle;

  /// No description provided for @myself.
  ///
  /// In en, this message translates to:
  /// **'Myself'**
  String get myself;

  /// No description provided for @nakshatra.
  ///
  /// In en, this message translates to:
  /// **'Nakshatra'**
  String get nakshatra;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @nearbyLocation.
  ///
  /// In en, this message translates to:
  /// **'Nearby location'**
  String get nearbyLocation;

  /// No description provided for @nearbyTalukaSuggestionsComeFromBackend.
  ///
  /// In en, this message translates to:
  /// **'Nearby taluka suggestions come from the backend.'**
  String get nearbyTalukaSuggestionsComeFromBackend;

  /// No description provided for @newEditableIntakeNotReady.
  ///
  /// In en, this message translates to:
  /// **'A new editable intake was created, but it is not ready yet.'**
  String get newEditableIntakeNotReady;

  /// No description provided for @newMatchesDigest.
  ///
  /// In en, this message translates to:
  /// **'New matches digest'**
  String get newMatchesDigest;

  /// No description provided for @newSetWillAppearHere.
  ///
  /// In en, this message translates to:
  /// **'It will appear here when a new set is available. Until then you can view regular matches.'**
  String get newSetWillAppearHere;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @noBiodataIntakeUploadedYet.
  ///
  /// In en, this message translates to:
  /// **'No biodata intake has been uploaded yet.'**
  String get noBiodataIntakeUploadedYet;

  /// No description provided for @noBlockedProfiles.
  ///
  /// In en, this message translates to:
  /// **'No blocked profiles.'**
  String get noBlockedProfiles;

  /// No description provided for @noChildren.
  ///
  /// In en, this message translates to:
  /// **'No children'**
  String get noChildren;

  /// No description provided for @noHiddenProfiles.
  ///
  /// In en, this message translates to:
  /// **'No hidden profiles.'**
  String get noHiddenProfiles;

  /// No description provided for @noInformation.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get noInformation;

  /// No description provided for @noLocationsFound.
  ///
  /// In en, this message translates to:
  /// **'No locations found.'**
  String get noLocationsFound;

  /// No description provided for @noOptionsFound.
  ///
  /// In en, this message translates to:
  /// **'No options found.'**
  String get noOptionsFound;

  /// No description provided for @noOptionsFound2.
  ///
  /// In en, this message translates to:
  /// **'No options found'**
  String get noOptionsFound2;

  /// No description provided for @noProfileData.
  ///
  /// In en, this message translates to:
  /// **'Profile data is not available.'**
  String get noProfileData;

  /// No description provided for @noProfilesFoundTryReducingFilters.
  ///
  /// In en, this message translates to:
  /// **'No profiles found. Try reducing filters and search again.'**
  String get noProfilesFoundTryReducingFilters;

  /// No description provided for @noSafeNewDataToSave.
  ///
  /// In en, this message translates to:
  /// **'There is no safe new information to save. The previous profile information has been kept as is.'**
  String get noSafeNewDataToSave;

  /// No description provided for @noShortlistedProfiles.
  ///
  /// In en, this message translates to:
  /// **'No shortlisted profiles yet.'**
  String get noShortlistedProfiles;

  /// No description provided for @normal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get normal;

  /// No description provided for @normalModeSelectedSomePreferencesAre.
  ///
  /// In en, this message translates to:
  /// **'Normal mode selected. Some preferences are wider for more matches.'**
  String get normalModeSelectedSomePreferencesAre;

  /// No description provided for @notFoundRequestOccupation.
  ///
  /// In en, this message translates to:
  /// **'Not found? Request occupation'**
  String get notFoundRequestOccupation;

  /// No description provided for @notFoundRequestToAdd.
  ///
  /// In en, this message translates to:
  /// **'Not found? Request to add'**
  String get notFoundRequestToAdd;

  /// No description provided for @notesOptional.
  ///
  /// In en, this message translates to:
  /// **'Notes optional'**
  String get notesOptional;

  /// No description provided for @notificationsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet.'**
  String get notificationsEmpty;

  /// No description provided for @notificationsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Notifications could not be loaded.'**
  String get notificationsLoadFailed;

  /// No description provided for @notificationsMarkAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get notificationsMarkAllRead;

  /// No description provided for @notificationsOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'This notification does not have an app action.'**
  String get notificationsOpenFailed;

  /// No description provided for @notificationsRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get notificationsRead;

  /// No description provided for @notificationsSoon.
  ///
  /// In en, this message translates to:
  /// **'Notifications will be available soon.'**
  String get notificationsSoon;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @notificationsUnread.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get notificationsUnread;

  /// No description provided for @nowSetAFewImportantThings.
  ///
  /// In en, this message translates to:
  /// **'Now set a few important things so we can suggest suitable matches.'**
  String get nowSetAFewImportantThings;

  /// No description provided for @occupation.
  ///
  /// In en, this message translates to:
  /// **'Occupation'**
  String get occupation;

  /// No description provided for @occupationAndIncomeAreOptionalWhen.
  ///
  /// In en, this message translates to:
  /// **'Occupation and income are optional when not working.'**
  String get occupationAndIncomeAreOptionalWhen;

  /// No description provided for @occupationLabel.
  ///
  /// In en, this message translates to:
  /// **'Occupation label'**
  String get occupationLabel;

  /// No description provided for @occupationRequestSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Occupation request submitted.'**
  String get occupationRequestSubmitted;

  /// No description provided for @ofThisProfile.
  ///
  /// In en, this message translates to:
  /// **'Of this profile'**
  String get ofThisProfile;

  /// No description provided for @oneFinalProfileDetailHelpsFamilies.
  ///
  /// In en, this message translates to:
  /// **'One final profile detail helps families understand the match better.'**
  String get oneFinalProfileDetailHelpsFamilies;

  /// No description provided for @onlyIdVerifiedProfiles.
  ///
  /// In en, this message translates to:
  /// **'Only ID verified profiles'**
  String get onlyIdVerifiedProfiles;

  /// No description provided for @onlyProfilesWithPhoto.
  ///
  /// In en, this message translates to:
  /// **'Only profiles with photo'**
  String get onlyProfilesWithPhoto;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @open2.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open2;

  /// No description provided for @openLocation.
  ///
  /// In en, this message translates to:
  /// **'Open location'**
  String get openLocation;

  /// No description provided for @openToIntercaste.
  ///
  /// In en, this message translates to:
  /// **'Open to intercaste'**
  String get openToIntercaste;

  /// No description provided for @optional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optional;

  /// No description provided for @optional2.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optional2;

  /// No description provided for @optionalButUsefulForBetterSuggestions.
  ///
  /// In en, this message translates to:
  /// **'Optional, but useful for better suggestions'**
  String get optionalButUsefulForBetterSuggestions;

  /// No description provided for @optionsNotLoaded.
  ///
  /// In en, this message translates to:
  /// **'Options not loaded.'**
  String get optionsNotLoaded;

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;

  /// No description provided for @otherPreferences.
  ///
  /// In en, this message translates to:
  /// **'Other Preferences'**
  String get otherPreferences;

  /// No description provided for @otpVerificationFailed.
  ///
  /// In en, this message translates to:
  /// **'OTP verification failed.'**
  String get otpVerificationFailed;

  /// No description provided for @partnerPreference.
  ///
  /// In en, this message translates to:
  /// **'Partner preference'**
  String get partnerPreference;

  /// No description provided for @partnerPreference2.
  ///
  /// In en, this message translates to:
  /// **'Partner Preference'**
  String get partnerPreference2;

  /// No description provided for @partnerPreferencePreviewIsNotReady.
  ///
  /// In en, this message translates to:
  /// **'Partner preference preview is not ready.'**
  String get partnerPreferencePreviewIsNotReady;

  /// No description provided for @partnerPreferenceSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Partner preference save failed.'**
  String get partnerPreferenceSaveFailed;

  /// No description provided for @partnerPreferenceSaveProblem.
  ///
  /// In en, this message translates to:
  /// **'A problem occurred while saving the partner preference.'**
  String get partnerPreferenceSaveProblem;

  /// No description provided for @partnerProfileWithChildren.
  ///
  /// In en, this message translates to:
  /// **'Partner profile with children'**
  String get partnerProfileWithChildren;

  /// No description provided for @passwordAndConfirmPasswordDoNot.
  ///
  /// In en, this message translates to:
  /// **'Password and confirm password do not match.'**
  String get passwordAndConfirmPasswordDoNot;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @pendingSuggestionsAreNotSelectedAs.
  ///
  /// In en, this message translates to:
  /// **'Pending suggestions are not selected as occupation until approved.'**
  String get pendingSuggestionsAreNotSelectedAs;

  /// No description provided for @pendingSuggestionsAreNotSelectedAs2.
  ///
  /// In en, this message translates to:
  /// **'Pending suggestions are not selected as education until approved.'**
  String get pendingSuggestionsAreNotSelectedAs2;

  /// No description provided for @perMonth.
  ///
  /// In en, this message translates to:
  /// **'per month'**
  String get perMonth;

  /// No description provided for @perYear.
  ///
  /// In en, this message translates to:
  /// **'per year'**
  String get perYear;

  /// No description provided for @photoApproved.
  ///
  /// In en, this message translates to:
  /// **'Photo approved'**
  String get photoApproved;

  /// No description provided for @photoApprovedMovingToPartnerPreference.
  ///
  /// In en, this message translates to:
  /// **'Photo approved. Moving to partner preference.'**
  String get photoApprovedMovingToPartnerPreference;

  /// No description provided for @photoAvailable.
  ///
  /// In en, this message translates to:
  /// **'Photo available'**
  String get photoAvailable;

  /// No description provided for @photoCropPhoto.
  ///
  /// In en, this message translates to:
  /// **'Could not crop the photo. Please select a different photo.'**
  String get photoCropPhoto;

  /// No description provided for @photoDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove this photo from your profile?'**
  String get photoDeleteConfirm;

  /// No description provided for @photoGalleryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No photos uploaded yet.'**
  String get photoGalleryEmpty;

  /// No description provided for @photoInReviewShownWhenApproved.
  ///
  /// In en, this message translates to:
  /// **'The photo is under review. It will be shown on your profile once approved.'**
  String get photoInReviewShownWhenApproved;

  /// No description provided for @photoIsNotValidPleaseSelect.
  ///
  /// In en, this message translates to:
  /// **'Photo is not valid. Please select a clear image.'**
  String get photoIsNotValidPleaseSelect;

  /// No description provided for @photoIsUploadedApprovalOrSafety.
  ///
  /// In en, this message translates to:
  /// **'Photo is uploaded. Approval or safety check is pending.'**
  String get photoIsUploadedApprovalOrSafety;

  /// No description provided for @photoIsUploadingPleaseWait.
  ///
  /// In en, this message translates to:
  /// **'Photo is uploading. Please wait.'**
  String get photoIsUploadingPleaseWait;

  /// No description provided for @photoManagementHint.
  ///
  /// In en, this message translates to:
  /// **'Select a thumbnail below, then manage that photo.'**
  String get photoManagementHint;

  /// No description provided for @photoNotApproved.
  ///
  /// In en, this message translates to:
  /// **'Photo not approved'**
  String get photoNotApproved;

  /// No description provided for @photoNotUploaded.
  ///
  /// In en, this message translates to:
  /// **'Photo not uploaded'**
  String get photoNotUploaded;

  /// No description provided for @photoPreviewUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Photo preview is not available.'**
  String get photoPreviewUnavailable;

  /// No description provided for @photoReachedBackendQualityAndSafety.
  ///
  /// In en, this message translates to:
  /// **'Photo reached backend. Quality and safety check is in progress.'**
  String get photoReachedBackendQualityAndSafety;

  /// No description provided for @photoReceivedByBackend.
  ///
  /// In en, this message translates to:
  /// **'The backend has received the photo. Quality and safety check is in progress.'**
  String get photoReceivedByBackend;

  /// No description provided for @photoReceivedCheckingQualitySafety.
  ///
  /// In en, this message translates to:
  /// **'The photo has been received. The backend is checking quality and safety.'**
  String get photoReceivedCheckingQualitySafety;

  /// No description provided for @photoReorderFailed.
  ///
  /// In en, this message translates to:
  /// **'Photo reorder failed.'**
  String get photoReorderFailed;

  /// No description provided for @photoSelectedCropItIfNeeded.
  ///
  /// In en, this message translates to:
  /// **'Photo selected. Crop it if needed, then upload.'**
  String get photoSelectedCropItIfNeeded;

  /// No description provided for @photoSelectionCancelled.
  ///
  /// In en, this message translates to:
  /// **'Photo selection cancelled.'**
  String get photoSelectionCancelled;

  /// No description provided for @photoStatusCouldNotBeRefreshed.
  ///
  /// In en, this message translates to:
  /// **'Photo status could not be refreshed.'**
  String get photoStatusCouldNotBeRefreshed;

  /// No description provided for @photoUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Photo not available'**
  String get photoUnavailable;

  /// No description provided for @photoUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Photo upload failed.'**
  String get photoUploadFailed;

  /// No description provided for @photoUploadFailedPleaseTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Photo upload failed. Please try again.'**
  String get photoUploadFailedPleaseTryAgain;

  /// No description provided for @photoUploadHelp.
  ///
  /// In en, this message translates to:
  /// **'Upload a clear, single-person photo in good light.'**
  String get photoUploadHelp;

  /// No description provided for @photoUploadIsNotAllowedFor.
  ///
  /// In en, this message translates to:
  /// **'Photo upload is not allowed for this account.'**
  String get photoUploadIsNotAllowedFor;

  /// No description provided for @photoUploadNotAllowedForAccount.
  ///
  /// In en, this message translates to:
  /// **'Photo upload is currently not allowed for your account.'**
  String get photoUploadNotAllowedForAccount;

  /// No description provided for @photoUploadProblem.
  ///
  /// In en, this message translates to:
  /// **'A problem occurred while uploading the photo. Please try again.'**
  String get photoUploadProblem;

  /// No description provided for @photoUploaded.
  ///
  /// In en, this message translates to:
  /// **'Photo uploaded.'**
  String get photoUploaded;

  /// No description provided for @photoUploadedApprovalPending.
  ///
  /// In en, this message translates to:
  /// **'The photo is uploaded. Approval or safety check is pending.'**
  String get photoUploadedApprovalPending;

  /// No description provided for @photoUploadedBackendQualitySafetyCheck.
  ///
  /// In en, this message translates to:
  /// **'The photo is uploaded. It will become visible after the server quality and safety check.'**
  String get photoUploadedBackendQualitySafetyCheck;

  /// No description provided for @photoUploadedPleaseCheckTheStatus.
  ///
  /// In en, this message translates to:
  /// **'Photo uploaded. Please check the status before continuing.'**
  String get photoUploadedPleaseCheckTheStatus;

  /// No description provided for @photoUploadedReviewIsPendingSo.
  ///
  /// In en, this message translates to:
  /// **'Photo uploaded. Review is pending, so we will continue.'**
  String get photoUploadedReviewIsPendingSo;

  /// No description provided for @photoUploadedStatusWillUpdate.
  ///
  /// In en, this message translates to:
  /// **'Photo uploaded. Status will update here.'**
  String get photoUploadedStatusWillUpdate;

  /// No description provided for @photoUploadedToModerationEngine.
  ///
  /// In en, this message translates to:
  /// **'This photo will be uploaded to the backend moderation engine.'**
  String get photoUploadedToModerationEngine;

  /// No description provided for @photoVisibility.
  ///
  /// In en, this message translates to:
  /// **'Photo visibility'**
  String get photoVisibility;

  /// No description provided for @photosVerification.
  ///
  /// In en, this message translates to:
  /// **'Photos / Verification'**
  String get photosVerification;

  /// No description provided for @photosVerificationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage gallery and verification status'**
  String get photosVerificationSubtitle;

  /// No description provided for @physicalBuild.
  ///
  /// In en, this message translates to:
  /// **'Physical Build'**
  String get physicalBuild;

  /// No description provided for @pincodeOptional.
  ///
  /// In en, this message translates to:
  /// **'Pincode optional'**
  String get pincodeOptional;

  /// No description provided for @plainLandscape.
  ///
  /// In en, this message translates to:
  /// **'Plain Landscape'**
  String get plainLandscape;

  /// No description provided for @plansActiveSubscription.
  ///
  /// In en, this message translates to:
  /// **'Active subscription'**
  String get plansActiveSubscription;

  /// No description provided for @plansAvailablePlans.
  ///
  /// In en, this message translates to:
  /// **'Available plans'**
  String get plansAvailablePlans;

  /// No description provided for @plansBrowserNote.
  ///
  /// In en, this message translates to:
  /// **'Checkout opened in the browser. Payment status will update from Laravel.'**
  String get plansBrowserNote;

  /// No description provided for @plansCheckoutUrlMissing.
  ///
  /// In en, this message translates to:
  /// **'Checkout link was not returned by the backend.'**
  String get plansCheckoutUrlMissing;

  /// No description provided for @plansChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose'**
  String get plansChoose;

  /// No description provided for @plansContactQuota.
  ///
  /// In en, this message translates to:
  /// **'Contact unlock quota'**
  String get plansContactQuota;

  /// No description provided for @plansCurrentPlan.
  ///
  /// In en, this message translates to:
  /// **'Current plan'**
  String get plansCurrentPlan;

  /// No description provided for @plansEmpty.
  ///
  /// In en, this message translates to:
  /// **'No upgrade plan is available right now.'**
  String get plansEmpty;

  /// No description provided for @plansFreeOrLocked.
  ///
  /// In en, this message translates to:
  /// **'Free / locked state'**
  String get plansFreeOrLocked;

  /// No description provided for @plansLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Plans could not be loaded.'**
  String get plansLoadFailed;

  /// No description provided for @plansManualRefreshHint.
  ///
  /// In en, this message translates to:
  /// **'After payment, return to the app and tap Refresh.'**
  String get plansManualRefreshHint;

  /// No description provided for @plansNoCurrentPlan.
  ///
  /// In en, this message translates to:
  /// **'Current plan is not available'**
  String get plansNoCurrentPlan;

  /// No description provided for @plansOpenFailedCopied.
  ///
  /// In en, this message translates to:
  /// **'Could not open the browser. Checkout link was copied to the clipboard.'**
  String get plansOpenFailedCopied;

  /// No description provided for @plansOpeningCheckout.
  ///
  /// In en, this message translates to:
  /// **'Opening checkout...'**
  String get plansOpeningCheckout;

  /// No description provided for @plansRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get plansRefresh;

  /// No description provided for @plansRemaining.
  ///
  /// In en, this message translates to:
  /// **'remaining'**
  String get plansRemaining;

  /// No description provided for @plansTitle.
  ///
  /// In en, this message translates to:
  /// **'Plans'**
  String get plansTitle;

  /// No description provided for @plansUpgradeMenu.
  ///
  /// In en, this message translates to:
  /// **'Plans / Upgrade'**
  String get plansUpgradeMenu;

  /// No description provided for @pleaseCheckChildDetails.
  ///
  /// In en, this message translates to:
  /// **'Please check child details.'**
  String get pleaseCheckChildDetails;

  /// No description provided for @pleaseCheckDateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Please check Date of birth.'**
  String get pleaseCheckDateOfBirth;

  /// No description provided for @pleaseCheckHeight.
  ///
  /// In en, this message translates to:
  /// **'Please check Height.'**
  String get pleaseCheckHeight;

  /// No description provided for @pleaseCheckThisField.
  ///
  /// In en, this message translates to:
  /// **'Please check this field.'**
  String get pleaseCheckThisField;

  /// No description provided for @pleaseCheckThisInformation.
  ///
  /// In en, this message translates to:
  /// **'Please check this information.'**
  String get pleaseCheckThisInformation;

  /// No description provided for @pleaseEnterEducation.
  ///
  /// In en, this message translates to:
  /// **'Please enter education.'**
  String get pleaseEnterEducation;

  /// No description provided for @pleaseEnterEducationOrSelectSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Please enter education or select a suggestion.'**
  String get pleaseEnterEducationOrSelectSuggestion;

  /// No description provided for @pleaseEnterFullName.
  ///
  /// In en, this message translates to:
  /// **'Please enter full name.'**
  String get pleaseEnterFullName;

  /// No description provided for @pleaseSelectAPhotoFirst.
  ///
  /// In en, this message translates to:
  /// **'Please select a photo first.'**
  String get pleaseSelectAPhotoFirst;

  /// No description provided for @pleaseSelectCasteFromSuggestions.
  ///
  /// In en, this message translates to:
  /// **'Please select a caste from the suggestions.'**
  String get pleaseSelectCasteFromSuggestions;

  /// No description provided for @pleaseSelectDateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Please select date of birth.'**
  String get pleaseSelectDateOfBirth;

  /// No description provided for @pleaseSelectLivingWithAgain.
  ///
  /// In en, this message translates to:
  /// **'Please select living with again.'**
  String get pleaseSelectLivingWithAgain;

  /// No description provided for @pleaseSelectLocationFromSuggestions.
  ///
  /// In en, this message translates to:
  /// **'Please select a location from the suggestions.'**
  String get pleaseSelectLocationFromSuggestions;

  /// No description provided for @pleaseSelectMotherTongueAgain.
  ///
  /// In en, this message translates to:
  /// **'Please select mother tongue again.'**
  String get pleaseSelectMotherTongueAgain;

  /// No description provided for @pleaseSelectReligionFromSuggestions.
  ///
  /// In en, this message translates to:
  /// **'Please select a religion from the suggestions.'**
  String get pleaseSelectReligionFromSuggestions;

  /// No description provided for @pleaseSelectWhetherThereAreChildren.
  ///
  /// In en, this message translates to:
  /// **'Please select whether there are children.'**
  String get pleaseSelectWhetherThereAreChildren;

  /// No description provided for @pleaseTryAgainWithAClear.
  ///
  /// In en, this message translates to:
  /// **'Please try again with a clear photo.'**
  String get pleaseTryAgainWithAClear;

  /// No description provided for @pleaseUploadAClearSafeSingle.
  ///
  /// In en, this message translates to:
  /// **'Please upload a clear, safe, single-person photo.'**
  String get pleaseUploadAClearSafeSingle;

  /// No description provided for @pleaseVerifyMobileFirst.
  ///
  /// In en, this message translates to:
  /// **'Please verify mobile first.'**
  String get pleaseVerifyMobileFirst;

  /// No description provided for @pleaseWriteReportReason.
  ///
  /// In en, this message translates to:
  /// **'Please write the reason for the report'**
  String get pleaseWriteReportReason;

  /// No description provided for @preferredAgeRangeInvalid.
  ///
  /// In en, this message translates to:
  /// **'The preferred age range is invalid.'**
  String get preferredAgeRangeInvalid;

  /// No description provided for @preferredHeightRangeInvalid.
  ///
  /// In en, this message translates to:
  /// **'The preferred height range is invalid.'**
  String get preferredHeightRangeInvalid;

  /// No description provided for @preferredIncomeRangeInvalid.
  ///
  /// In en, this message translates to:
  /// **'The preferred income range is invalid.'**
  String get preferredIncomeRangeInvalid;

  /// No description provided for @premiumDoubleBorderElegantA4Portrait.
  ///
  /// In en, this message translates to:
  /// **'Premium double border, photo and an elegant A4 portrait.'**
  String get premiumDoubleBorderElegantA4Portrait;

  /// No description provided for @premiumProfiles.
  ///
  /// In en, this message translates to:
  /// **'Premium profiles'**
  String get premiumProfiles;

  /// No description provided for @premiumProfilesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Selected premium profiles'**
  String get premiumProfilesSubtitle;

  /// No description provided for @premiumRoyalStyleLandscape.
  ///
  /// In en, this message translates to:
  /// **'Premium royal style, with a landscape photo.'**
  String get premiumRoyalStyleLandscape;

  /// No description provided for @preparingProfilesForYou.
  ///
  /// In en, this message translates to:
  /// **'Preparing profiles for you.'**
  String get preparingProfilesForYou;

  /// No description provided for @preparingReviewScreen.
  ///
  /// In en, this message translates to:
  /// **'Preparing the review screen...'**
  String get preparingReviewScreen;

  /// No description provided for @preparingYourInformation.
  ///
  /// In en, this message translates to:
  /// **'Preparing your information.'**
  String get preparingYourInformation;

  /// No description provided for @previousBiodataTextUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The previous biodata text is not available. Please upload the biodata again.'**
  String get previousBiodataTextUnavailable;

  /// No description provided for @primaryPhoto.
  ///
  /// In en, this message translates to:
  /// **'Primary'**
  String get primaryPhoto;

  /// No description provided for @problemSelectingPhoto.
  ///
  /// In en, this message translates to:
  /// **'A problem occurred while selecting the photo. Please try again.'**
  String get problemSelectingPhoto;

  /// No description provided for @professionalLandscapeBiodataNoPhoto.
  ///
  /// In en, this message translates to:
  /// **'Professional landscape biodata without a photo.'**
  String get professionalLandscapeBiodataNoPhoto;

  /// No description provided for @professionalPreferences.
  ///
  /// In en, this message translates to:
  /// **'Professional Preferences'**
  String get professionalPreferences;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @profileCreatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Profile created successfully!'**
  String get profileCreatedSuccessfully;

  /// No description provided for @profileDetailsCopied.
  ///
  /// In en, this message translates to:
  /// **'Profile details copied.'**
  String get profileDetailsCopied;

  /// No description provided for @profileListsBlocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get profileListsBlocked;

  /// No description provided for @profileListsHidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get profileListsHidden;

  /// No description provided for @profileListsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Profile list could not be loaded.'**
  String get profileListsLoadFailed;

  /// No description provided for @profileListsMenu.
  ///
  /// In en, this message translates to:
  /// **'Shortlist / Blocked'**
  String get profileListsMenu;

  /// No description provided for @profileListsShortlist.
  ///
  /// In en, this message translates to:
  /// **'Shortlist'**
  String get profileListsShortlist;

  /// No description provided for @profileListsTitle.
  ///
  /// In en, this message translates to:
  /// **'Shortlist / Blocked'**
  String get profileListsTitle;

  /// No description provided for @profileManagedBy.
  ///
  /// In en, this message translates to:
  /// **'Profile managed by'**
  String get profileManagedBy;

  /// No description provided for @profileNotFoundCreateFirst.
  ///
  /// In en, this message translates to:
  /// **'Profile not found. Please create a profile first.'**
  String get profileNotFoundCreateFirst;

  /// No description provided for @profileOpenNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'This profile cannot be opened right now.'**
  String get profileOpenNotAllowed;

  /// No description provided for @profilePhoto.
  ///
  /// In en, this message translates to:
  /// **'Profile photo'**
  String get profilePhoto;

  /// No description provided for @profilePhoto2.
  ///
  /// In en, this message translates to:
  /// **'Profile Photo'**
  String get profilePhoto2;

  /// No description provided for @profileQuality.
  ///
  /// In en, this message translates to:
  /// **'Profile quality'**
  String get profileQuality;

  /// No description provided for @profileRemovedFromShortlist.
  ///
  /// In en, this message translates to:
  /// **'Profile removed from shortlist.'**
  String get profileRemovedFromShortlist;

  /// No description provided for @profileType.
  ///
  /// In en, this message translates to:
  /// **'Profile type'**
  String get profileType;

  /// No description provided for @profileTypeLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Profile type could not be loaded.'**
  String get profileTypeLoadFailed;

  /// No description provided for @profileUnblocked.
  ///
  /// In en, this message translates to:
  /// **'Profile unblocked.'**
  String get profileUnblocked;

  /// No description provided for @profileUnhidden.
  ///
  /// In en, this message translates to:
  /// **'Profile unhidden.'**
  String get profileUnhidden;

  /// No description provided for @profileUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully!'**
  String get profileUpdatedSuccessfully;

  /// No description provided for @profileViewed.
  ///
  /// In en, this message translates to:
  /// **'Profile viewed'**
  String get profileViewed;

  /// No description provided for @profileVisibility.
  ///
  /// In en, this message translates to:
  /// **'Profile visibility'**
  String get profileVisibility;

  /// No description provided for @profileWasNotFoundPleaseComplete.
  ///
  /// In en, this message translates to:
  /// **'Profile was not found. Please complete profile first.'**
  String get profileWasNotFoundPleaseComplete;

  /// No description provided for @profilesCloserToYourLocation.
  ///
  /// In en, this message translates to:
  /// **'Profiles closer to your location'**
  String get profilesCloserToYourLocation;

  /// No description provided for @profilesFromSearch.
  ///
  /// In en, this message translates to:
  /// **'Profiles from your search'**
  String get profilesFromSearch;

  /// No description provided for @profilesWhosePreferencesMayMatchYou.
  ///
  /// In en, this message translates to:
  /// **'Profiles whose preferences may match you'**
  String get profilesWhosePreferencesMayMatchYou;

  /// No description provided for @profilesYouViewedRecently.
  ///
  /// In en, this message translates to:
  /// **'Profiles you viewed recently'**
  String get profilesYouViewedRecently;

  /// No description provided for @range.
  ///
  /// In en, this message translates to:
  /// **'Range'**
  String get range;

  /// No description provided for @rashi.
  ///
  /// In en, this message translates to:
  /// **'Rashi'**
  String get rashi;

  /// No description provided for @readyToUpload.
  ///
  /// In en, this message translates to:
  /// **'Ready to upload'**
  String get readyToUpload;

  /// No description provided for @receivedInterests.
  ///
  /// In en, this message translates to:
  /// **'Received Interests'**
  String get receivedInterests;

  /// No description provided for @receivedInterests2.
  ///
  /// In en, this message translates to:
  /// **'Received interests'**
  String get receivedInterests2;

  /// No description provided for @receivedInterestsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View and respond to received interests'**
  String get receivedInterestsSubtitle;

  /// No description provided for @recentVisitorsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No eligible recent visitors to show yet.'**
  String get recentVisitorsEmpty;

  /// No description provided for @recentlyActive.
  ///
  /// In en, this message translates to:
  /// **'Recently active'**
  String get recentlyActive;

  /// No description provided for @recognizedButNotAddedToForm.
  ///
  /// In en, this message translates to:
  /// **'Information that was recognized but not added to the form'**
  String get recognizedButNotAddedToForm;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @refreshPhotoStatus.
  ///
  /// In en, this message translates to:
  /// **'Refresh photo status'**
  String get refreshPhotoStatus;

  /// No description provided for @refreshPreference.
  ///
  /// In en, this message translates to:
  /// **'Refresh preference'**
  String get refreshPreference;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// No description provided for @registrationComplete.
  ///
  /// In en, this message translates to:
  /// **'Registration complete'**
  String get registrationComplete;

  /// No description provided for @registrationIsCompleteNextSettingsImprove.
  ///
  /// In en, this message translates to:
  /// **'Registration is complete. Next settings improve match suggestions.'**
  String get registrationIsCompleteNextSettingsImprove;

  /// No description provided for @registrationSuccessfulCreateProfile.
  ///
  /// In en, this message translates to:
  /// **'Registration successful! Create your profile...'**
  String get registrationSuccessfulCreateProfile;

  /// No description provided for @rejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get rejected;

  /// No description provided for @relative.
  ///
  /// In en, this message translates to:
  /// **'Relative'**
  String get relative;

  /// No description provided for @relativeSDetails.
  ///
  /// In en, this message translates to:
  /// **'Relative’s details'**
  String get relativeSDetails;

  /// No description provided for @relativeSFullName.
  ///
  /// In en, this message translates to:
  /// **'Relative’s full name *'**
  String get relativeSFullName;

  /// No description provided for @religion.
  ///
  /// In en, this message translates to:
  /// **'Religion'**
  String get religion;

  /// No description provided for @religion2.
  ///
  /// In en, this message translates to:
  /// **'Religion *'**
  String get religion2;

  /// No description provided for @religiousPreferences.
  ///
  /// In en, this message translates to:
  /// **'Religious Preferences'**
  String get religiousPreferences;

  /// No description provided for @removeFromShortlist.
  ///
  /// In en, this message translates to:
  /// **'Remove from shortlist'**
  String get removeFromShortlist;

  /// No description provided for @removeUnwantedTalukasBeforeSaving.
  ///
  /// In en, this message translates to:
  /// **'Remove unwanted talukas before saving.'**
  String get removeUnwantedTalukasBeforeSaving;

  /// No description provided for @removedFromShortlist.
  ///
  /// In en, this message translates to:
  /// **'Removed from Shortlist.'**
  String get removedFromShortlist;

  /// No description provided for @replaceApprovedPhoto.
  ///
  /// In en, this message translates to:
  /// **'Replace approved photo'**
  String get replaceApprovedPhoto;

  /// No description provided for @replacePhoto.
  ///
  /// In en, this message translates to:
  /// **'Replace photo'**
  String get replacePhoto;

  /// No description provided for @reportReasonMinLength.
  ///
  /// In en, this message translates to:
  /// **'Report reason must be at least 10 characters.'**
  String get reportReasonMinLength;

  /// No description provided for @requestEducation.
  ///
  /// In en, this message translates to:
  /// **'Request education'**
  String get requestEducation;

  /// No description provided for @requestOccupation.
  ///
  /// In en, this message translates to:
  /// **'Request occupation'**
  String get requestOccupation;

  /// No description provided for @requestedLocation.
  ///
  /// In en, this message translates to:
  /// **'Requested location'**
  String get requestedLocation;

  /// No description provided for @requireContactRequest.
  ///
  /// In en, this message translates to:
  /// **'Require contact request'**
  String get requireContactRequest;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @resendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get resendCode;

  /// No description provided for @resendOtp.
  ///
  /// In en, this message translates to:
  /// **'Resend OTP'**
  String get resendOtp;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @reviewThePreferencePreparedFromYour.
  ///
  /// In en, this message translates to:
  /// **'Review the preference prepared from your profile. You can widen it for more matches.'**
  String get reviewThePreferencePreparedFromYour;

  /// No description provided for @royalLandscape.
  ///
  /// In en, this message translates to:
  /// **'Royal Landscape'**
  String get royalLandscape;

  /// No description provided for @rural.
  ///
  /// In en, this message translates to:
  /// **'Rural'**
  String get rural;

  /// No description provided for @safePhoto.
  ///
  /// In en, this message translates to:
  /// **'Safe photo'**
  String get safePhoto;

  /// No description provided for @safeProfiles.
  ///
  /// In en, this message translates to:
  /// **'Safe profiles'**
  String get safeProfiles;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saveAndContinue.
  ///
  /// In en, this message translates to:
  /// **'Save and continue'**
  String get saveAndContinue;

  /// No description provided for @saveAndContinue2.
  ///
  /// In en, this message translates to:
  /// **'Save and continue'**
  String get saveAndContinue2;

  /// No description provided for @saveNormalPreferenceAndFinishSetup.
  ///
  /// In en, this message translates to:
  /// **'Save normal preference and finish setup'**
  String get saveNormalPreferenceAndFinishSetup;

  /// No description provided for @saveOrDiscardChangesInSection.
  ///
  /// In en, this message translates to:
  /// **'Do you want to save or discard the changes in this section?'**
  String get saveOrDiscardChangesInSection;

  /// No description provided for @saveSection.
  ///
  /// In en, this message translates to:
  /// **'Save section'**
  String get saveSection;

  /// No description provided for @saveStrictPreferenceAndFinishSetup.
  ///
  /// In en, this message translates to:
  /// **'Save strict preference and finish setup'**
  String get saveStrictPreferenceAndFinishSetup;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved.'**
  String get saved;

  /// No description provided for @savedChooseMaritalStatus.
  ///
  /// In en, this message translates to:
  /// **'Saved. Choose marital status.'**
  String get savedChooseMaritalStatus;

  /// No description provided for @savedForNowAdminCanApprove.
  ///
  /// In en, this message translates to:
  /// **'Saved for now; admin can approve the master location later.'**
  String get savedForNowAdminCanApprove;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @search2.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search2;

  /// No description provided for @searchAndSelectEducation.
  ///
  /// In en, this message translates to:
  /// **'Search and select education'**
  String get searchAndSelectEducation;

  /// No description provided for @searchCountry.
  ///
  /// In en, this message translates to:
  /// **'Search country'**
  String get searchCountry;

  /// No description provided for @searchDistrict.
  ///
  /// In en, this message translates to:
  /// **'Search district'**
  String get searchDistrict;

  /// No description provided for @searchEducation.
  ///
  /// In en, this message translates to:
  /// **'Search education'**
  String get searchEducation;

  /// No description provided for @searchFilters.
  ///
  /// In en, this message translates to:
  /// **'Search filters'**
  String get searchFilters;

  /// No description provided for @searchLocation.
  ///
  /// In en, this message translates to:
  /// **'Search location'**
  String get searchLocation;

  /// No description provided for @searchMotherTongue.
  ///
  /// In en, this message translates to:
  /// **'Search mother tongue'**
  String get searchMotherTongue;

  /// No description provided for @searchOccupation.
  ///
  /// In en, this message translates to:
  /// **'Search occupation'**
  String get searchOccupation;

  /// No description provided for @searchState.
  ///
  /// In en, this message translates to:
  /// **'Search state'**
  String get searchState;

  /// No description provided for @searchTaluka.
  ///
  /// In en, this message translates to:
  /// **'Search taluka'**
  String get searchTaluka;

  /// No description provided for @searchTalukaCityOrSuburb.
  ///
  /// In en, this message translates to:
  /// **'Search taluka, city or suburb'**
  String get searchTalukaCityOrSuburb;

  /// No description provided for @searchWithAgeCommunityLocationAnd.
  ///
  /// In en, this message translates to:
  /// **'Search with age, community, location and advanced filters.'**
  String get searchWithAgeCommunityLocationAnd;

  /// No description provided for @searchWorkType.
  ///
  /// In en, this message translates to:
  /// **'Search work type'**
  String get searchWorkType;

  /// No description provided for @sectionSaved.
  ///
  /// In en, this message translates to:
  /// **'Section saved.'**
  String get sectionSaved;

  /// No description provided for @sectionUpdated.
  ///
  /// In en, this message translates to:
  /// **'Section updated.'**
  String get sectionUpdated;

  /// No description provided for @seeHowYourProfileMatchesHer.
  ///
  /// In en, this message translates to:
  /// **'See how well your profile matches her expectations'**
  String get seeHowYourProfileMatchesHer;

  /// No description provided for @seeHowYourProfileMatchesHis.
  ///
  /// In en, this message translates to:
  /// **'See how well your profile matches his expectations'**
  String get seeHowYourProfileMatchesHis;

  /// No description provided for @seeHowYourProfileMatchesThisMatch.
  ///
  /// In en, this message translates to:
  /// **'See how well your profile matches this match\'s expectations'**
  String get seeHowYourProfileMatchesThisMatch;

  /// No description provided for @seeWhoViewedYourProfile.
  ///
  /// In en, this message translates to:
  /// **'See who viewed your profile'**
  String get seeWhoViewedYourProfile;

  /// No description provided for @select.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get select;

  /// No description provided for @selectACitySuburbVillageOr.
  ///
  /// In en, this message translates to:
  /// **'Select a city, suburb, village, or add your location.'**
  String get selectACitySuburbVillageOr;

  /// No description provided for @selectAgeBetween1And30.
  ///
  /// In en, this message translates to:
  /// **'Select age between 1 and 30.'**
  String get selectAgeBetween1And30;

  /// No description provided for @selectAtLeastOneContactMethod.
  ///
  /// In en, this message translates to:
  /// **'Select at least one contact method.'**
  String get selectAtLeastOneContactMethod;

  /// No description provided for @selectCaste.
  ///
  /// In en, this message translates to:
  /// **'Select caste.'**
  String get selectCaste;

  /// No description provided for @selectChildGender.
  ///
  /// In en, this message translates to:
  /// **'Select child gender.'**
  String get selectChildGender;

  /// No description provided for @selectClearPortraitPhoto.
  ///
  /// In en, this message translates to:
  /// **'Select a clear portrait photo from the camera or gallery.'**
  String get selectClearPortraitPhoto;

  /// No description provided for @selectCountry.
  ///
  /// In en, this message translates to:
  /// **'Select country'**
  String get selectCountry;

  /// No description provided for @selectCountry2.
  ///
  /// In en, this message translates to:
  /// **'Select country.'**
  String get selectCountry2;

  /// No description provided for @selectCountryStateDistrictAndEnter.
  ///
  /// In en, this message translates to:
  /// **'Select country, state, district and enter location name.'**
  String get selectCountryStateDistrictAndEnter;

  /// No description provided for @selectDistrict.
  ///
  /// In en, this message translates to:
  /// **'Select district'**
  String get selectDistrict;

  /// No description provided for @selectDistrictAndLocation.
  ///
  /// In en, this message translates to:
  /// **'Select district and location.'**
  String get selectDistrictAndLocation;

  /// No description provided for @selectDob.
  ///
  /// In en, this message translates to:
  /// **'Select DOB.'**
  String get selectDob;

  /// No description provided for @selectEducation.
  ///
  /// In en, this message translates to:
  /// **'Select education.'**
  String get selectEducation;

  /// No description provided for @selectEmail.
  ///
  /// In en, this message translates to:
  /// **'Select Email'**
  String get selectEmail;

  /// No description provided for @selectFamilyStatus.
  ///
  /// In en, this message translates to:
  /// **'Select family status.'**
  String get selectFamilyStatus;

  /// No description provided for @selectFamilyStatusAndWriteA.
  ///
  /// In en, this message translates to:
  /// **'Select family status and write a short about section.'**
  String get selectFamilyStatusAndWriteA;

  /// No description provided for @selectFriendSGender.
  ///
  /// In en, this message translates to:
  /// **'Select friend\'s gender'**
  String get selectFriendSGender;

  /// No description provided for @selectGender.
  ///
  /// In en, this message translates to:
  /// **'Select gender'**
  String get selectGender;

  /// No description provided for @selectGenderAgain.
  ///
  /// In en, this message translates to:
  /// **'Select gender again.'**
  String get selectGenderAgain;

  /// No description provided for @selectHeight.
  ///
  /// In en, this message translates to:
  /// **'Select height.'**
  String get selectHeight;

  /// No description provided for @selectHeight2.
  ///
  /// In en, this message translates to:
  /// **'Select height'**
  String get selectHeight2;

  /// No description provided for @selectIfKnown.
  ///
  /// In en, this message translates to:
  /// **'Select if known'**
  String get selectIfKnown;

  /// No description provided for @selectIncomeRange.
  ///
  /// In en, this message translates to:
  /// **'Select income range'**
  String get selectIncomeRange;

  /// No description provided for @selectLocation.
  ///
  /// In en, this message translates to:
  /// **'Select location'**
  String get selectLocation;

  /// No description provided for @selectLocationBeforeSaving.
  ///
  /// In en, this message translates to:
  /// **'A place of residence must be selected before saving'**
  String get selectLocationBeforeSaving;

  /// No description provided for @selectMaritalStatus.
  ///
  /// In en, this message translates to:
  /// **'Select marital status.'**
  String get selectMaritalStatus;

  /// No description provided for @selectMotherTongue.
  ///
  /// In en, this message translates to:
  /// **'Select mother tongue'**
  String get selectMotherTongue;

  /// No description provided for @selectMotherTongueReligionAndCaste.
  ///
  /// In en, this message translates to:
  /// **'Select mother tongue, religion and caste to continue.'**
  String get selectMotherTongueReligionAndCaste;

  /// No description provided for @selectOccupation.
  ///
  /// In en, this message translates to:
  /// **'Select occupation'**
  String get selectOccupation;

  /// No description provided for @selectPhoto.
  ///
  /// In en, this message translates to:
  /// **'Select photo'**
  String get selectPhoto;

  /// No description provided for @selectProfileType.
  ///
  /// In en, this message translates to:
  /// **'Please select profile type.'**
  String get selectProfileType;

  /// No description provided for @selectRelativeSGender.
  ///
  /// In en, this message translates to:
  /// **'Select relative\'s gender'**
  String get selectRelativeSGender;

  /// No description provided for @selectReligion.
  ///
  /// In en, this message translates to:
  /// **'Select religion.'**
  String get selectReligion;

  /// No description provided for @selectReligionFirstToChoosePreferredCaste.
  ///
  /// In en, this message translates to:
  /// **'Select a religion first to choose a preferred caste.'**
  String get selectReligionFirstToChoosePreferredCaste;

  /// No description provided for @selectState.
  ///
  /// In en, this message translates to:
  /// **'Select state'**
  String get selectState;

  /// No description provided for @selectState2.
  ///
  /// In en, this message translates to:
  /// **'Select state.'**
  String get selectState2;

  /// No description provided for @selectSubCasteFromSuggestionsOrLeaveEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please select a sub-caste from the suggestions or leave the field empty.'**
  String get selectSubCasteFromSuggestionsOrLeaveEmpty;

  /// No description provided for @selectTalukaCityOrSuburb.
  ///
  /// In en, this message translates to:
  /// **'Select taluka, city or suburb'**
  String get selectTalukaCityOrSuburb;

  /// No description provided for @selectTalukaOptional.
  ///
  /// In en, this message translates to:
  /// **'Select taluka optional'**
  String get selectTalukaOptional;

  /// No description provided for @selectTheCurrentWorkType.
  ///
  /// In en, this message translates to:
  /// **'Select the current work type.'**
  String get selectTheCurrentWorkType;

  /// No description provided for @selectWhenOptionsAvailable.
  ///
  /// In en, this message translates to:
  /// **'Select once options are available.'**
  String get selectWhenOptionsAvailable;

  /// No description provided for @selectWorkType.
  ///
  /// In en, this message translates to:
  /// **'Select work type'**
  String get selectWorkType;

  /// No description provided for @selectYourGender.
  ///
  /// In en, this message translates to:
  /// **'Select your gender'**
  String get selectYourGender;

  /// No description provided for @selectedPhoto.
  ///
  /// In en, this message translates to:
  /// **'Selected photo'**
  String get selectedPhoto;

  /// No description provided for @sendEmailOtp.
  ///
  /// In en, this message translates to:
  /// **'Send email OTP'**
  String get sendEmailOtp;

  /// No description provided for @sendInterest.
  ///
  /// In en, this message translates to:
  /// **'Send Interest'**
  String get sendInterest;

  /// No description provided for @sendOtpAgain.
  ///
  /// In en, this message translates to:
  /// **'Send OTP again'**
  String get sendOtpAgain;

  /// No description provided for @sendOtpFirst.
  ///
  /// In en, this message translates to:
  /// **'Send OTP first.'**
  String get sendOtpFirst;

  /// No description provided for @sendProfileAlertsOnWhatsapp.
  ///
  /// In en, this message translates to:
  /// **'Send profile alerts on WhatsApp'**
  String get sendProfileAlertsOnWhatsapp;

  /// No description provided for @sendingOtp.
  ///
  /// In en, this message translates to:
  /// **'Sending OTP'**
  String get sendingOtp;

  /// No description provided for @sentInterests.
  ///
  /// In en, this message translates to:
  /// **'Sent Interests'**
  String get sentInterests;

  /// No description provided for @sentInterestsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View interests you have sent'**
  String get sentInterestsSubtitle;

  /// No description provided for @sessionExpiredPleaseLogin.
  ///
  /// In en, this message translates to:
  /// **'Session expired. Please log in again.'**
  String get sessionExpiredPleaseLogin;

  /// No description provided for @sessionExpiredPleaseLoginAgain.
  ///
  /// In en, this message translates to:
  /// **'Session expired. Please login again.'**
  String get sessionExpiredPleaseLoginAgain;

  /// No description provided for @sessionExpiredVerifyMobileAgain.
  ///
  /// In en, this message translates to:
  /// **'Session expired. Verify mobile again.'**
  String get sessionExpiredVerifyMobileAgain;

  /// No description provided for @setAPasswordIfYouWish.
  ///
  /// In en, this message translates to:
  /// **'Set a password if you wish to log in with it'**
  String get setAPasswordIfYouWish;

  /// No description provided for @setPassword.
  ///
  /// In en, this message translates to:
  /// **'Set password'**
  String get setPassword;

  /// No description provided for @setPassword2.
  ///
  /// In en, this message translates to:
  /// **'Set Password'**
  String get setPassword2;

  /// No description provided for @setPrimary.
  ///
  /// In en, this message translates to:
  /// **'Set primary'**
  String get setPrimary;

  /// No description provided for @settingsAccountSummary.
  ///
  /// In en, this message translates to:
  /// **'Account summary'**
  String get settingsAccountSummary;

  /// No description provided for @settingsCommunication.
  ///
  /// In en, this message translates to:
  /// **'Communication'**
  String get settingsCommunication;

  /// No description provided for @settingsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Settings could not be loaded.'**
  String get settingsLoadFailed;

  /// No description provided for @settingsNoProfile.
  ///
  /// In en, this message translates to:
  /// **'These settings will be available after your profile is complete.'**
  String get settingsNoProfile;

  /// No description provided for @settingsNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get settingsNotAvailable;

  /// No description provided for @settingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// No description provided for @settingsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get settingsPrivacy;

  /// No description provided for @settingsReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Read only'**
  String get settingsReadOnly;

  /// No description provided for @settingsSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get settingsSave;

  /// No description provided for @settingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Settings saved.'**
  String get settingsSaved;

  /// No description provided for @settingsSecurity.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get settingsSecurity;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @simpleFamilyFirst.
  ///
  /// In en, this message translates to:
  /// **'Simple & family-first'**
  String get simpleFamilyFirst;

  /// No description provided for @simpleFamilyFirst2.
  ///
  /// In en, this message translates to:
  /// **'Simple & family-first'**
  String get simpleFamilyFirst2;

  /// No description provided for @simpleProcess.
  ///
  /// In en, this message translates to:
  /// **'Simple registration'**
  String get simpleProcess;

  /// No description provided for @singlePerson.
  ///
  /// In en, this message translates to:
  /// **'Single person'**
  String get singlePerson;

  /// No description provided for @sister.
  ///
  /// In en, this message translates to:
  /// **'Sister'**
  String get sister;

  /// No description provided for @sisterSDetails.
  ///
  /// In en, this message translates to:
  /// **'Sister’s details'**
  String get sisterSDetails;

  /// No description provided for @sisterSFullName.
  ///
  /// In en, this message translates to:
  /// **'Sister’s full name *'**
  String get sisterSFullName;

  /// No description provided for @skipAstroDetails.
  ///
  /// In en, this message translates to:
  /// **'Skip astro details'**
  String get skipAstroDetails;

  /// No description provided for @skipEmailVerification.
  ///
  /// In en, this message translates to:
  /// **'Skip email verification'**
  String get skipEmailVerification;

  /// No description provided for @smoking.
  ///
  /// In en, this message translates to:
  /// **'Smoking'**
  String get smoking;

  /// No description provided for @son.
  ///
  /// In en, this message translates to:
  /// **'Son'**
  String get son;

  /// No description provided for @sonSDetails.
  ///
  /// In en, this message translates to:
  /// **'Son’s details'**
  String get sonSDetails;

  /// No description provided for @sonSFullName.
  ///
  /// In en, this message translates to:
  /// **'Son’s full name *'**
  String get sonSFullName;

  /// No description provided for @spectaclesLens.
  ///
  /// In en, this message translates to:
  /// **'Spectacles / Lens'**
  String get spectaclesLens;

  /// No description provided for @startWithEmail.
  ///
  /// In en, this message translates to:
  /// **'Start with Email'**
  String get startWithEmail;

  /// No description provided for @startWithProfileOwner.
  ///
  /// In en, this message translates to:
  /// **'Start with profile owner'**
  String get startWithProfileOwner;

  /// No description provided for @state.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get state;

  /// No description provided for @str.
  ///
  /// In en, this message translates to:
  /// **'.'**
  String get str;

  /// No description provided for @strict.
  ///
  /// In en, this message translates to:
  /// **'Strict'**
  String get strict;

  /// No description provided for @strictModeSelectedPreferencesAreFocused.
  ///
  /// In en, this message translates to:
  /// **'Strict mode selected. Preferences are focused from your profile.'**
  String get strictModeSelectedPreferencesAreFocused;

  /// No description provided for @subCaste.
  ///
  /// In en, this message translates to:
  /// **'Sub-caste'**
  String get subCaste;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @suggestedProfilesForYou.
  ///
  /// In en, this message translates to:
  /// **'Suggested profiles for you'**
  String get suggestedProfilesForYou;

  /// No description provided for @taluka.
  ///
  /// In en, this message translates to:
  /// **'Taluka'**
  String get taluka;

  /// No description provided for @talukaCitySuburban.
  ///
  /// In en, this message translates to:
  /// **'Taluka / City / Suburban'**
  String get talukaCitySuburban;

  /// No description provided for @thereWasAProblemSelectingThe.
  ///
  /// In en, this message translates to:
  /// **'There was a problem selecting the photo. Please try again.'**
  String get thereWasAProblemSelectingThe;

  /// No description provided for @thereWasAProblemUploadingThe.
  ///
  /// In en, this message translates to:
  /// **'There was a problem uploading the photo. Please try again.'**
  String get thereWasAProblemUploadingThe;

  /// No description provided for @thisApprovedPhotoIsVisibleOn.
  ///
  /// In en, this message translates to:
  /// **'This approved photo is visible on your profile.'**
  String get thisApprovedPhotoIsVisibleOn;

  /// No description provided for @thisIsOptionalAddOnlyWhat.
  ///
  /// In en, this message translates to:
  /// **'This is optional. Add only what you know now.'**
  String get thisIsOptionalAddOnlyWhat;

  /// No description provided for @thisKeepsEveryNextQuestionRelevant.
  ///
  /// In en, this message translates to:
  /// **'This keeps every next question relevant to the right person.'**
  String get thisKeepsEveryNextQuestionRelevant;

  /// No description provided for @thisLocationAlreadyExistsItHas.
  ///
  /// In en, this message translates to:
  /// **'This location already exists. It has been selected.'**
  String get thisLocationAlreadyExistsItHas;

  /// No description provided for @thisMonth.
  ///
  /// In en, this message translates to:
  /// **'this month'**
  String get thisMonth;

  /// No description provided for @thisPhotoCouldNotBeApproved.
  ///
  /// In en, this message translates to:
  /// **'This photo could not be approved. Please upload another clear photo.'**
  String get thisPhotoCouldNotBeApproved;

  /// No description provided for @thisPhotoWasNotApprovedPlease.
  ///
  /// In en, this message translates to:
  /// **'This photo was not approved. Please upload another clear photo.'**
  String get thisPhotoWasNotApprovedPlease;

  /// No description provided for @thisPreferenceIsBasedOnThe.
  ///
  /// In en, this message translates to:
  /// **'This preference is based on the information you filled. You can edit any section now or change it later.'**
  String get thisPreferenceIsBasedOnThe;

  /// No description provided for @thisWeek.
  ///
  /// In en, this message translates to:
  /// **'this week'**
  String get thisWeek;

  /// No description provided for @titleRangeInvalid.
  ///
  /// In en, this message translates to:
  /// **'The \$title range is invalid.'**
  String get titleRangeInvalid;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'today'**
  String get today;

  /// No description provided for @todaysRecommendationsComplete.
  ///
  /// In en, this message translates to:
  /// **'Today\'s recommendations are complete'**
  String get todaysRecommendationsComplete;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @traditionOpenMind.
  ///
  /// In en, this message translates to:
  /// **'Tradition & open mind'**
  String get traditionOpenMind;

  /// No description provided for @traditionOpenMind2.
  ///
  /// In en, this message translates to:
  /// **'Tradition & open mind'**
  String get traditionOpenMind2;

  /// No description provided for @traditionalColorsDecorativeBorder.
  ///
  /// In en, this message translates to:
  /// **'Traditional colors, decorative border and an introduction card with photo.'**
  String get traditionalColorsDecorativeBorder;

  /// No description provided for @tryAgainAfterTheLatestServer.
  ///
  /// In en, this message translates to:
  /// **'Try again after the latest server update.'**
  String get tryAgainAfterTheLatestServer;

  /// No description provided for @tryGoogleVerification.
  ///
  /// In en, this message translates to:
  /// **'Try Google verification'**
  String get tryGoogleVerification;

  /// No description provided for @turnOnDeviceLocationInAndroid.
  ///
  /// In en, this message translates to:
  /// **'Turn on device location in Android settings and try again.'**
  String get turnOnDeviceLocationInAndroid;

  /// No description provided for @unblockProfile.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get unblockProfile;

  /// No description provided for @unhideProfile.
  ///
  /// In en, this message translates to:
  /// **'Unhide'**
  String get unhideProfile;

  /// No description provided for @unlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlock;

  /// No description provided for @unlockRequiredToViewContact.
  ///
  /// In en, this message translates to:
  /// **'Unlock is required to view contact details.'**
  String get unlockRequiredToViewContact;

  /// No description provided for @upDown.
  ///
  /// In en, this message translates to:
  /// **'Up / down'**
  String get upDown;

  /// No description provided for @upgrade.
  ///
  /// In en, this message translates to:
  /// **'Upgrade'**
  String get upgrade;

  /// No description provided for @upgradeRequiredToViewContact.
  ///
  /// In en, this message translates to:
  /// **'Upgrade is required to view contact details.'**
  String get upgradeRequiredToViewContact;

  /// No description provided for @upgradeToSeeVisitors.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to see visitors'**
  String get upgradeToSeeVisitors;

  /// No description provided for @uploadAProfilePhotoBeforeContinuing.
  ///
  /// In en, this message translates to:
  /// **'Upload a profile photo before continuing.'**
  String get uploadAProfilePhotoBeforeContinuing;

  /// No description provided for @uploadClearProfilePhoto.
  ///
  /// In en, this message translates to:
  /// **'Upload a clear profile photo. The approved status will appear only after backend approval.'**
  String get uploadClearProfilePhoto;

  /// No description provided for @uploadClearSafeSinglePersonPhoto.
  ///
  /// In en, this message translates to:
  /// **'Please upload a clear, safe and single-person photo.'**
  String get uploadClearSafeSinglePersonPhoto;

  /// No description provided for @uploadCompleteScreen.
  ///
  /// In en, this message translates to:
  /// **'Do not close the screen until the upload is complete.'**
  String get uploadCompleteScreen;

  /// No description provided for @uploadNeedsAttention.
  ///
  /// In en, this message translates to:
  /// **'Upload needs attention'**
  String get uploadNeedsAttention;

  /// No description provided for @uploadPhoto.
  ///
  /// In en, this message translates to:
  /// **'Upload Photo'**
  String get uploadPhoto;

  /// No description provided for @uploadPhotoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Update your profile photo'**
  String get uploadPhotoSubtitle;

  /// No description provided for @uploadSelectedPhoto.
  ///
  /// In en, this message translates to:
  /// **'Upload selected photo'**
  String get uploadSelectedPhoto;

  /// No description provided for @uploadTheSelectedPhotoBeforeContinuing.
  ///
  /// In en, this message translates to:
  /// **'Upload the selected photo before continuing.'**
  String get uploadTheSelectedPhotoBeforeContinuing;

  /// No description provided for @uploadedBiodataPhoto.
  ///
  /// In en, this message translates to:
  /// **'Uploaded biodata photo'**
  String get uploadedBiodataPhoto;

  /// No description provided for @uploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading...'**
  String get uploading;

  /// No description provided for @uploadingPhoto.
  ///
  /// In en, this message translates to:
  /// **'Uploading photo'**
  String get uploadingPhoto;

  /// No description provided for @useLocation.
  ///
  /// In en, this message translates to:
  /// **'Use location'**
  String get useLocation;

  /// No description provided for @useLocationForNearby.
  ///
  /// In en, this message translates to:
  /// **'Use location for Nearby'**
  String get useLocationForNearby;

  /// No description provided for @useMobileLocation.
  ///
  /// In en, this message translates to:
  /// **'Use mobile location'**
  String get useMobileLocation;

  /// No description provided for @useNearby.
  ///
  /// In en, this message translates to:
  /// **'Use nearby'**
  String get useNearby;

  /// No description provided for @useNearbyKeepsBackendSuggestedCountry.
  ///
  /// In en, this message translates to:
  /// **'Use nearby keeps backend suggested country/state/district. Open removes location filters.'**
  String get useNearbyKeepsBackendSuggestedCountry;

  /// No description provided for @usefulForDayToDayCompatibility.
  ///
  /// In en, this message translates to:
  /// **'Useful for day-to-day compatibility.'**
  String get usefulForDayToDayCompatibility;

  /// No description provided for @v1.
  ///
  /// In en, this message translates to:
  /// **'<1'**
  String get v1;

  /// No description provided for @v10kTo30k.
  ///
  /// In en, this message translates to:
  /// **'10K to 30K'**
  String get v10kTo30k;

  /// No description provided for @v10lTo30l.
  ///
  /// In en, this message translates to:
  /// **'10L to 30L'**
  String get v10lTo30l;

  /// No description provided for @v1lTo2l.
  ///
  /// In en, this message translates to:
  /// **'1L to 2L'**
  String get v1lTo2l;

  /// No description provided for @v2lTo5l.
  ///
  /// In en, this message translates to:
  /// **'2L to 5L'**
  String get v2lTo5l;

  /// No description provided for @v30kTo1l.
  ///
  /// In en, this message translates to:
  /// **'30K to 1L'**
  String get v30kTo1l;

  /// No description provided for @v30lTo50l.
  ///
  /// In en, this message translates to:
  /// **'30L to 50L'**
  String get v30lTo50l;

  /// No description provided for @v50lAndAbove.
  ///
  /// In en, this message translates to:
  /// **'50L and above'**
  String get v50lAndAbove;

  /// No description provided for @v5lAndAbove.
  ///
  /// In en, this message translates to:
  /// **'5L and above'**
  String get v5lAndAbove;

  /// No description provided for @v5lTo10l.
  ///
  /// In en, this message translates to:
  /// **'5L to 10L'**
  String get v5lTo10l;

  /// No description provided for @verificationStatus.
  ///
  /// In en, this message translates to:
  /// **'Verification status'**
  String get verificationStatus;

  /// No description provided for @verified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get verified;

  /// No description provided for @verifiedEmail.
  ///
  /// In en, this message translates to:
  /// **'Verified email'**
  String get verifiedEmail;

  /// No description provided for @verifyAndContinue.
  ///
  /// In en, this message translates to:
  /// **'Verify and continue'**
  String get verifyAndContinue;

  /// No description provided for @verifyEmail.
  ///
  /// In en, this message translates to:
  /// **'Verify email'**
  String get verifyEmail;

  /// No description provided for @verifyMobile.
  ///
  /// In en, this message translates to:
  /// **'Verify mobile'**
  String get verifyMobile;

  /// No description provided for @verifyMobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Verify mobile number'**
  String get verifyMobileNumber;

  /// No description provided for @verifyMobileNumber2.
  ///
  /// In en, this message translates to:
  /// **'Verify Mobile Number'**
  String get verifyMobileNumber2;

  /// No description provided for @verifyOtp.
  ///
  /// In en, this message translates to:
  /// **'Verify OTP'**
  String get verifyOtp;

  /// No description provided for @verifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying...'**
  String get verifying;

  /// No description provided for @verifying2.
  ///
  /// In en, this message translates to:
  /// **'Verifying'**
  String get verifying2;

  /// No description provided for @viewMatches.
  ///
  /// In en, this message translates to:
  /// **'View matches'**
  String get viewMatches;

  /// No description provided for @viewProfile.
  ///
  /// In en, this message translates to:
  /// **'View profile'**
  String get viewProfile;

  /// No description provided for @viewedRecently.
  ///
  /// In en, this message translates to:
  /// **'Viewed recently'**
  String get viewedRecently;

  /// No description provided for @viewedYourProfile.
  ///
  /// In en, this message translates to:
  /// **'Viewed your profile'**
  String get viewedYourProfile;

  /// No description provided for @villageLocationName.
  ///
  /// In en, this message translates to:
  /// **'Village / location name'**
  String get villageLocationName;

  /// No description provided for @weCouldNotSaveThisInformation.
  ///
  /// In en, this message translates to:
  /// **'We could not save this information. Please check the highlighted field.'**
  String get weCouldNotSaveThisInformation;

  /// No description provided for @weFoundYourMobileLocationPlease.
  ///
  /// In en, this message translates to:
  /// **'We found your mobile location. Please select the nearest location from the list.'**
  String get weFoundYourMobileLocationPlease;

  /// No description provided for @wePreparedThisFromTheInformation.
  ///
  /// In en, this message translates to:
  /// **'We prepared this from the information you filled. You can keep it strict or make it normal.'**
  String get wePreparedThisFromTheInformation;

  /// No description provided for @weVeSentAVerificationCode.
  ///
  /// In en, this message translates to:
  /// **'We’ve sent a verification code to'**
  String get weVeSentAVerificationCode;

  /// No description provided for @weWillAddThisOnlyIf.
  ///
  /// In en, this message translates to:
  /// **'We will add this only if it is not already available.'**
  String get weWillAddThisOnlyIf;

  /// No description provided for @whatsappResponseAvailable.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp Response is available.'**
  String get whatsappResponseAvailable;

  /// No description provided for @whatsappResponseComingSoon.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp Response feature will be available soon.'**
  String get whatsappResponseComingSoon;

  /// No description provided for @whatsappResponseInboxWillBeAvailable.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp Response inbox will be available in the mobile app soon.'**
  String get whatsappResponseInboxWillBeAvailable;

  /// No description provided for @whoViewed.
  ///
  /// In en, this message translates to:
  /// **'Who viewed'**
  String get whoViewed;

  /// No description provided for @willingToRelocate.
  ///
  /// In en, this message translates to:
  /// **'Willing to relocate'**
  String get willingToRelocate;

  /// No description provided for @workDetails.
  ///
  /// In en, this message translates to:
  /// **'Work details'**
  String get workDetails;

  /// No description provided for @workLocationOptional.
  ///
  /// In en, this message translates to:
  /// **'Work location optional'**
  String get workLocationOptional;

  /// No description provided for @workingAs.
  ///
  /// In en, this message translates to:
  /// **'Working as'**
  String get workingAs;

  /// No description provided for @workingWith.
  ///
  /// In en, this message translates to:
  /// **'Working with'**
  String get workingWith;

  /// No description provided for @writeANaturalIntroductionFamilyBackground.
  ///
  /// In en, this message translates to:
  /// **'Write a natural introduction, family background, and what makes this profile easy to understand.'**
  String get writeANaturalIntroductionFamilyBackground;

  /// No description provided for @writeAShortAboutSection.
  ///
  /// In en, this message translates to:
  /// **'Write a short about section.'**
  String get writeAShortAboutSection;

  /// No description provided for @writeExpectationsAboutPartnerBriefly.
  ///
  /// In en, this message translates to:
  /// **'Write your expectations about a partner briefly.'**
  String get writeExpectationsAboutPartnerBriefly;

  /// No description provided for @writeOtherReason.
  ///
  /// In en, this message translates to:
  /// **'Write the other reason.'**
  String get writeOtherReason;

  /// No description provided for @years.
  ///
  /// In en, this message translates to:
  /// **' years'**
  String get years;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @yes2.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes2;

  /// No description provided for @yourDetails.
  ///
  /// In en, this message translates to:
  /// **'Your details'**
  String get yourDetails;

  /// No description provided for @yourFullName.
  ///
  /// In en, this message translates to:
  /// **'Your full name *'**
  String get yourFullName;

  /// No description provided for @yourMotherTongue.
  ///
  /// In en, this message translates to:
  /// **'Your mother tongue'**
  String get yourMotherTongue;

  /// No description provided for @yourPhotos.
  ///
  /// In en, this message translates to:
  /// **'Your photos'**
  String get yourPhotos;

  /// No description provided for @yourProfileHasBeenCreatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Your profile has been created successfully.'**
  String get yourProfileHasBeenCreatedSuccessfully;

  /// No description provided for @yourProfileViewedTimes.
  ///
  /// In en, this message translates to:
  /// **'Your profile was viewed \$count times'**
  String get yourProfileViewedTimes;

  /// No description provided for @yourProfileViewedTimesInWindow.
  ///
  /// In en, this message translates to:
  /// **'\$window your profile was viewed \$count times'**
  String get yourProfileViewedTimesInWindow;

  /// No description provided for @yourProfileWasViewed.
  ///
  /// In en, this message translates to:
  /// **'Your profile was viewed.'**
  String get yourProfileWasViewed;

  /// No description provided for @zoom.
  ///
  /// In en, this message translates to:
  /// **'Zoom'**
  String get zoom;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @viewPlans.
  ///
  /// In en, this message translates to:
  /// **'View Plans'**
  String get viewPlans;

  /// No description provided for @profileActions.
  ///
  /// In en, this message translates to:
  /// **'Profile actions'**
  String get profileActions;

  /// No description provided for @shareProfile.
  ///
  /// In en, this message translates to:
  /// **'Share profile'**
  String get shareProfile;

  /// No description provided for @addToShortlist.
  ///
  /// In en, this message translates to:
  /// **'Add to Shortlist'**
  String get addToShortlist;

  /// No description provided for @hideThisProfile.
  ///
  /// In en, this message translates to:
  /// **'Hide this Profile'**
  String get hideThisProfile;

  /// No description provided for @blockThisProfile.
  ///
  /// In en, this message translates to:
  /// **'Block this Profile'**
  String get blockThisProfile;

  /// No description provided for @reportThisProfile.
  ///
  /// In en, this message translates to:
  /// **'Report this Profile'**
  String get reportThisProfile;

  /// No description provided for @gunmilan.
  ///
  /// In en, this message translates to:
  /// **'Gunmilan'**
  String get gunmilan;

  /// No description provided for @requestContact.
  ///
  /// In en, this message translates to:
  /// **'Request Contact'**
  String get requestContact;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @sendRequest.
  ///
  /// In en, this message translates to:
  /// **'Send Request'**
  String get sendRequest;

  /// No description provided for @hide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get hide;

  /// No description provided for @block.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get block;

  /// No description provided for @whatsappResponse.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp Response'**
  String get whatsappResponse;

  /// No description provided for @viewContact.
  ///
  /// In en, this message translates to:
  /// **'View Contact'**
  String get viewContact;

  /// No description provided for @upgradeToViewContact.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to View Contact'**
  String get upgradeToViewContact;

  /// No description provided for @statusOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get statusOnline;

  /// No description provided for @comparisonYouAndHer.
  ///
  /// In en, this message translates to:
  /// **'You & Her'**
  String get comparisonYouAndHer;

  /// No description provided for @comparisonYouAndHim.
  ///
  /// In en, this message translates to:
  /// **'You & Him'**
  String get comparisonYouAndHim;

  /// No description provided for @comparisonYouAndProfile.
  ///
  /// In en, this message translates to:
  /// **'You & Profile'**
  String get comparisonYouAndProfile;

  /// No description provided for @contactInformationTitle.
  ///
  /// In en, this message translates to:
  /// **'Contact Information'**
  String get contactInformationTitle;

  /// No description provided for @contactInformationAvailable.
  ///
  /// In en, this message translates to:
  /// **'Contact information is available.'**
  String get contactInformationAvailable;

  /// No description provided for @upgradeToViewAllPhotos.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to view all photos.'**
  String get upgradeToViewAllPhotos;

  /// No description provided for @uploadPhotoToUnlockProfiles.
  ///
  /// In en, this message translates to:
  /// **'Upload your photo to unlock more profiles.'**
  String get uploadPhotoToUnlockProfiles;

  /// No description provided for @photoAccessLockedForPlan.
  ///
  /// In en, this message translates to:
  /// **'Photo access is locked for your current plan.'**
  String get photoAccessLockedForPlan;

  /// No description provided for @contactDetailsUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Contact details unlocked.'**
  String get contactDetailsUnlocked;

  /// No description provided for @contactRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Contact request sent.'**
  String get contactRequestSent;

  /// No description provided for @profileHidden.
  ///
  /// In en, this message translates to:
  /// **'Profile hidden.'**
  String get profileHidden;

  /// No description provided for @profileBlocked.
  ///
  /// In en, this message translates to:
  /// **'Profile blocked.'**
  String get profileBlocked;

  /// No description provided for @profileLinkReadyToShare.
  ///
  /// In en, this message translates to:
  /// **'Profile link ready to share.'**
  String get profileLinkReadyToShare;

  /// No description provided for @profileLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Profile link copied.'**
  String get profileLinkCopied;

  /// No description provided for @reportSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Report submitted.'**
  String get reportSubmitted;

  /// No description provided for @comparisonTitle.
  ///
  /// In en, this message translates to:
  /// **'Comparison'**
  String get comparisonTitle;

  /// No description provided for @comparisonViewerYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get comparisonViewerYou;

  /// No description provided for @heightLabel.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get heightLabel;

  /// No description provided for @astro.
  ///
  /// In en, this message translates to:
  /// **'Astro'**
  String get astro;

  /// No description provided for @moreProfilesYouMayLike2.
  ///
  /// In en, this message translates to:
  /// **'More profiles you may like'**
  String get moreProfilesYouMayLike2;

  /// No description provided for @contactMethods.
  ///
  /// In en, this message translates to:
  /// **'Contact methods'**
  String get contactMethods;

  /// No description provided for @reason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get reason;

  /// No description provided for @otherReason.
  ///
  /// In en, this message translates to:
  /// **'Other reason'**
  String get otherReason;

  /// No description provided for @reportProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Report profile'**
  String get reportProfileTitle;

  /// No description provided for @hideProfileConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Hide profile?'**
  String get hideProfileConfirmTitle;

  /// No description provided for @hideProfileConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This profile will be hidden from your browse/search list.'**
  String get hideProfileConfirmMessage;

  /// No description provided for @blockProfileConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Block profile?'**
  String get blockProfileConfirmTitle;

  /// No description provided for @blockProfileConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Blocking will remove interests/shortlists between both profiles and hide this profile from you.'**
  String get blockProfileConfirmMessage;

  /// No description provided for @viewProfileColon.
  ///
  /// In en, this message translates to:
  /// **'View profile:'**
  String get viewProfileColon;

  /// No description provided for @photoActions.
  ///
  /// In en, this message translates to:
  /// **'Photo actions'**
  String get photoActions;

  /// No description provided for @aboutName.
  ///
  /// In en, this message translates to:
  /// **'About {name}'**
  String aboutName(String name);

  /// No description provided for @photosCounter.
  ///
  /// In en, this message translates to:
  /// **'Photos {current}/{total}'**
  String photosCounter(int current, int total);

  /// No description provided for @contactValueCopied.
  ///
  /// In en, this message translates to:
  /// **'{label} copied.'**
  String contactValueCopied(String label);

  /// No description provided for @profileIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Profile ID: {id}'**
  String profileIdLabel(String id);

  /// No description provided for @profileNotFound.
  ///
  /// In en, this message translates to:
  /// **'Profile not found.'**
  String get profileNotFound;

  /// No description provided for @profilePreview.
  ///
  /// In en, this message translates to:
  /// **'Profile preview'**
  String get profilePreview;

  /// No description provided for @profileInformation.
  ///
  /// In en, this message translates to:
  /// **'Profile information'**
  String get profileInformation;

  /// No description provided for @photoNotAddedYet.
  ///
  /// In en, this message translates to:
  /// **'No photo added yet'**
  String get photoNotAddedYet;

  /// No description provided for @nameNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Name not available'**
  String get nameNotAvailable;

  /// No description provided for @pleaseTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Please try again.'**
  String get pleaseTryAgain;

  /// No description provided for @signUpWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign Up with Google'**
  String get signUpWithGoogle;

  /// No description provided for @signUpWithMobile.
  ///
  /// In en, this message translates to:
  /// **'Sign Up with Mobile'**
  String get signUpWithMobile;

  /// No description provided for @unexpectedErrorOccurred.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred: {error}'**
  String unexpectedErrorOccurred(String error);

  /// No description provided for @sectionSavedNamed.
  ///
  /// In en, this message translates to:
  /// **'{section} saved.'**
  String sectionSavedNamed(String section);

  /// No description provided for @testOtpLabel.
  ///
  /// In en, this message translates to:
  /// **'Test OTP: {otp}'**
  String testOtpLabel(String otp);

  /// Resend cooldown. `seconds` is a String on purpose so no locale-aware number formatter can turn the digits into Devanagari.
  ///
  /// In en, this message translates to:
  /// **'Send OTP again in {seconds}s'**
  String loginResendInSeconds(String seconds);

  /// No description provided for @nearbyTalukasCount.
  ///
  /// In en, this message translates to:
  /// **'{count} nearby talukas'**
  String nearbyTalukasCount(int count);

  /// No description provided for @districtsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} districts'**
  String districtsCount(int count);

  /// No description provided for @statesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} states'**
  String statesCount(int count);

  /// No description provided for @countriesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} countries'**
  String countriesCount(int count);

  /// No description provided for @contactMobileNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Mobile Number'**
  String get contactMobileNumberLabel;

  /// No description provided for @contactEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get contactEmailLabel;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @soon.
  ///
  /// In en, this message translates to:
  /// **'Soon'**
  String get soon;

  /// No description provided for @contactStateAvailableBadge.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get contactStateAvailableBadge;

  /// No description provided for @contactStateLockedBadge.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get contactStateLockedBadge;

  /// No description provided for @contactStateResponseBadge.
  ///
  /// In en, this message translates to:
  /// **'Response'**
  String get contactStateResponseBadge;

  /// No description provided for @contactStateRequestBadge.
  ///
  /// In en, this message translates to:
  /// **'Request'**
  String get contactStateRequestBadge;

  /// No description provided for @contactStateInfoBadge.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get contactStateInfoBadge;

  /// No description provided for @suchakManagedProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile added by a Suchak'**
  String get suchakManagedProfileTitle;

  /// No description provided for @suchakContactSubtitleFallback.
  ///
  /// In en, this message translates to:
  /// **'Experienced marriage facilitator'**
  String get suchakContactSubtitleFallback;

  /// No description provided for @suchakContactPrivacyNote.
  ///
  /// In en, this message translates to:
  /// **'The candidate\'s own number is never shown. Everything goes through the Suchak.'**
  String get suchakContactPrivacyNote;

  /// No description provided for @suchakContactNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Suchak\'s number'**
  String get suchakContactNumberLabel;

  /// No description provided for @suchakLabel.
  ///
  /// In en, this message translates to:
  /// **'Suchak'**
  String get suchakLabel;

  /// No description provided for @suchakStateAvailableBadge.
  ///
  /// In en, this message translates to:
  /// **'Suchak'**
  String get suchakStateAvailableBadge;

  /// No description provided for @suchakStateAnsweredBadge.
  ///
  /// In en, this message translates to:
  /// **'Answered'**
  String get suchakStateAnsweredBadge;

  /// No description provided for @suchakStateClosedBadge.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get suchakStateClosedBadge;

  /// No description provided for @suchakRequestAvailableMessage.
  ///
  /// In en, this message translates to:
  /// **'A Suchak manages this profile. Send a request and they will take it ahead.'**
  String get suchakRequestAvailableMessage;

  /// No description provided for @suchakRequestPendingMessage.
  ///
  /// In en, this message translates to:
  /// **'Your request is with the Suchak. Their reply arrives here.'**
  String get suchakRequestPendingMessage;

  /// No description provided for @suchakRequestAnsweredMessage.
  ///
  /// In en, this message translates to:
  /// **'The Suchak has answered. Continue in chat.'**
  String get suchakRequestAnsweredMessage;

  /// No description provided for @suchakRequestClosedMessage.
  ///
  /// In en, this message translates to:
  /// **'This request is closed. You can send a new one.'**
  String get suchakRequestClosedMessage;

  /// No description provided for @suchakRequestSendButton.
  ///
  /// In en, this message translates to:
  /// **'Request through Suchak'**
  String get suchakRequestSendButton;

  /// No description provided for @suchakRequestResendButton.
  ///
  /// In en, this message translates to:
  /// **'Send a new request'**
  String get suchakRequestResendButton;

  /// No description provided for @suchakRequestOpenChatButton.
  ///
  /// In en, this message translates to:
  /// **'Open chat'**
  String get suchakRequestOpenChatButton;

  /// No description provided for @suchakRequestPendingBadge.
  ///
  /// In en, this message translates to:
  /// **'Request pending'**
  String get suchakRequestPendingBadge;

  /// No description provided for @suchakRequestDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Request through Suchak'**
  String get suchakRequestDialogTitle;

  /// No description provided for @suchakRequestDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Your request goes to {name}, who will take it to the candidate and their family.'**
  String suchakRequestDialogBody(String name);

  /// No description provided for @suchakRequestMessageLabel.
  ///
  /// In en, this message translates to:
  /// **'Message for the Suchak'**
  String get suchakRequestMessageLabel;

  /// No description provided for @suchakRequestMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Share brief context for the Suchak.'**
  String get suchakRequestMessageHint;

  /// No description provided for @suchakRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Suchak request sent.'**
  String get suchakRequestSent;

  /// No description provided for @couldNotSendSuchakRequest.
  ///
  /// In en, this message translates to:
  /// **'Could not send the Suchak request.'**
  String get couldNotSendSuchakRequest;

  /// No description provided for @suchakChatNotOpenYet.
  ///
  /// In en, this message translates to:
  /// **'The Suchak has not opened the chat yet.'**
  String get suchakChatNotOpenYet;

  /// No description provided for @suchakRequestsTitle.
  ///
  /// In en, this message translates to:
  /// **'Suchak Requests'**
  String get suchakRequestsTitle;

  /// No description provided for @tabReceived.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get tabReceived;

  /// No description provided for @tabSent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get tabSent;

  /// No description provided for @loadingSuchakRequests.
  ///
  /// In en, this message translates to:
  /// **'Loading Suchak requests'**
  String get loadingSuchakRequests;

  /// No description provided for @suchakRequestsDidNotLoad.
  ///
  /// In en, this message translates to:
  /// **'Suchak requests did not load.'**
  String get suchakRequestsDidNotLoad;

  /// No description provided for @noReceivedSuchakRequests.
  ///
  /// In en, this message translates to:
  /// **'Nobody has asked your Suchak about you yet.'**
  String get noReceivedSuchakRequests;

  /// No description provided for @noSentSuchakRequests.
  ///
  /// In en, this message translates to:
  /// **'You have not sent a Suchak request yet.'**
  String get noSentSuchakRequests;

  /// No description provided for @suchakRequestInterested.
  ///
  /// In en, this message translates to:
  /// **'Interested'**
  String get suchakRequestInterested;

  /// No description provided for @suchakRequestNotInterested.
  ///
  /// In en, this message translates to:
  /// **'Not interested'**
  String get suchakRequestNotInterested;

  /// No description provided for @suchakRequestConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Send this answer?'**
  String get suchakRequestConfirmTitle;

  /// No description provided for @suchakRequestConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Your Suchak can answer this request too. Whichever answer arrives first is the one that counts.'**
  String get suchakRequestConfirmBody;

  /// No description provided for @suchakRequestDecisionRecorded.
  ///
  /// In en, this message translates to:
  /// **'Your answer has been recorded.'**
  String get suchakRequestDecisionRecorded;

  /// No description provided for @couldNotAnswerSuchakRequest.
  ///
  /// In en, this message translates to:
  /// **'Could not record your answer.'**
  String get couldNotAnswerSuchakRequest;

  /// No description provided for @suchakRequestAlreadyAnswered.
  ///
  /// In en, this message translates to:
  /// **'This request was already answered.'**
  String get suchakRequestAlreadyAnswered;

  /// No description provided for @suchakRequestAlreadyAnsweredBy.
  ///
  /// In en, this message translates to:
  /// **'This request was already answered by {by}.'**
  String suchakRequestAlreadyAnsweredBy(String by);

  /// No description provided for @suchakRequestAnsweredByName.
  ///
  /// In en, this message translates to:
  /// **'Answered by {by}'**
  String suchakRequestAnsweredByName(String by);

  /// No description provided for @suchakRequestAskedOnDate.
  ///
  /// In en, this message translates to:
  /// **'Asked on {date}'**
  String suchakRequestAskedOnDate(String date);

  /// No description provided for @suchakRequestSentOnDate.
  ///
  /// In en, this message translates to:
  /// **'Sent on {date}'**
  String suchakRequestSentOnDate(String date);

  /// No description provided for @suchakRequestYourMessage.
  ///
  /// In en, this message translates to:
  /// **'Your message'**
  String get suchakRequestYourMessage;

  /// No description provided for @suchakRequestTheirMessage.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get suchakRequestTheirMessage;

  /// No description provided for @notificationSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification settings'**
  String get notificationSettingsTitle;

  /// No description provided for @notificationSettingsIntro.
  ///
  /// In en, this message translates to:
  /// **'Choose which notifications reach your phone.'**
  String get notificationSettingsIntro;

  /// No description provided for @notificationSettingsManage.
  ///
  /// In en, this message translates to:
  /// **'Push notifications'**
  String get notificationSettingsManage;

  /// No description provided for @notificationSettingsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No notification types are available right now.'**
  String get notificationSettingsEmpty;

  /// No description provided for @notificationSettingsSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'This change could not be saved.'**
  String get notificationSettingsSaveFailed;

  /// Banner heading shown when Android is blocking notifications for this app.
  ///
  /// In en, this message translates to:
  /// **'Notifications are switched off'**
  String get notificationPermissionOffTitle;

  /// No description provided for @notificationPermissionOffBody.
  ///
  /// In en, this message translates to:
  /// **'Your phone is not letting this app send notifications, so nothing below can reach you.'**
  String get notificationPermissionOffBody;

  /// No description provided for @notificationPermissionBlockedBody.
  ///
  /// In en, this message translates to:
  /// **'Your phone is blocking notifications for this app. The app can no longer ask for this — switch notifications on in phone settings.'**
  String get notificationPermissionBlockedBody;

  /// No description provided for @notificationPermissionEnable.
  ///
  /// In en, this message translates to:
  /// **'Turn on notifications'**
  String get notificationPermissionEnable;

  /// No description provided for @notificationPermissionOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open phone settings'**
  String get notificationPermissionOpenSettings;

  /// No description provided for @quietHours.
  ///
  /// In en, this message translates to:
  /// **'Quiet hours'**
  String get quietHours;

  /// No description provided for @pushChannelName.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get pushChannelName;

  /// No description provided for @pushChannelDescription.
  ///
  /// In en, this message translates to:
  /// **'Alerts about interests, contact requests and matches.'**
  String get pushChannelDescription;

  /// No description provided for @pushDefaultTitle.
  ///
  /// In en, this message translates to:
  /// **'New notification'**
  String get pushDefaultTitle;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @reject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reject;

  /// No description provided for @statusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get statusLabel;

  /// No description provided for @interestAccepted.
  ///
  /// In en, this message translates to:
  /// **'Interest accepted.'**
  String get interestAccepted;

  /// No description provided for @interestRejected.
  ///
  /// In en, this message translates to:
  /// **'Interest declined.'**
  String get interestRejected;

  /// No description provided for @noReceivedInterests.
  ///
  /// In en, this message translates to:
  /// **'No received interests yet.'**
  String get noReceivedInterests;

  /// No description provided for @lockedInterestTitle.
  ///
  /// In en, this message translates to:
  /// **'Locked interest'**
  String get lockedInterestTitle;

  /// No description provided for @lockedInterestBody.
  ///
  /// In en, this message translates to:
  /// **'Unlock with a plan to see who sent this interest.'**
  String get lockedInterestBody;

  /// No description provided for @lockedInterestAcceptHint.
  ///
  /// In en, this message translates to:
  /// **'Accept becomes available once this interest is unlocked.'**
  String get lockedInterestAcceptHint;

  /// No description provided for @interestRevealLimitBanner.
  ///
  /// In en, this message translates to:
  /// **'Your plan reveals {count} received interests {interval}.'**
  String interestRevealLimitBanner(int count, String interval);

  /// No description provided for @interestRevealNone.
  ///
  /// In en, this message translates to:
  /// **'Your current plan does not reveal any received interest.'**
  String get interestRevealNone;

  /// No description provided for @intervalEachDay.
  ///
  /// In en, this message translates to:
  /// **'each day'**
  String get intervalEachDay;

  /// No description provided for @intervalEachWeek.
  ///
  /// In en, this message translates to:
  /// **'each week'**
  String get intervalEachWeek;

  /// No description provided for @intervalEachMonth.
  ///
  /// In en, this message translates to:
  /// **'each month'**
  String get intervalEachMonth;

  /// No description provided for @intervalEachQuarter.
  ///
  /// In en, this message translates to:
  /// **'each quarter'**
  String get intervalEachQuarter;

  /// No description provided for @intervalInTotal.
  ///
  /// In en, this message translates to:
  /// **'in total'**
  String get intervalInTotal;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'mr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'mr':
      return AppLocalizationsMr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
