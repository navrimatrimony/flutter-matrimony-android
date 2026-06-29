import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_language.dart';
import '../../core/app_strings.dart';
import '../photo/photo_upload_screen.dart';

class EditFullProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? initialProfile;

  const EditFullProfileScreen({super.key, this.initialProfile});

  @override
  State<EditFullProfileScreen> createState() => _EditFullProfileScreenState();
}

enum _EditProfileSection {
  basic,
  physical,
  educationCareer,
  familyDetails,
  siblings,
  relatives,
  property,
  horoscope,
  aboutMe,
  partnerPreferences,
  photo,
}

enum _UnsavedSectionAction { save, discard, cancel }

class _MarriageEditRow {
  _MarriageEditRow({
    this.id,
    this.divorceStatus,
    String? marriageYear,
    String? separationYear,
    String? divorceYear,
    String? spouseDeathYear,
    this.remarriageReason,
    String? notes,
  }) : marriageYearController = TextEditingController(text: marriageYear ?? ''),
       separationYearController = TextEditingController(
         text: separationYear ?? '',
       ),
       divorceYearController = TextEditingController(text: divorceYear ?? ''),
       spouseDeathYearController = TextEditingController(
         text: spouseDeathYear ?? '',
       ),
       notesController = TextEditingController(text: notes ?? '');

  int? id;
  String? divorceStatus;
  String? remarriageReason;
  final TextEditingController marriageYearController;
  final TextEditingController separationYearController;
  final TextEditingController divorceYearController;
  final TextEditingController spouseDeathYearController;
  final TextEditingController notesController;

  bool get hasData {
    return marriageYearController.text.trim().isNotEmpty ||
        separationYearController.text.trim().isNotEmpty ||
        divorceYearController.text.trim().isNotEmpty ||
        spouseDeathYearController.text.trim().isNotEmpty ||
        (divorceStatus != null && divorceStatus!.trim().isNotEmpty) ||
        (remarriageReason != null && remarriageReason!.trim().isNotEmpty) ||
        notesController.text.trim().isNotEmpty;
  }

  Map<String, dynamic> toPayload(int? maritalStatusId) {
    return <String, dynamic>{
      if (id != null) 'id': id,
      'marital_status_id': maritalStatusId,
      'marriage_year': _intOrNull(marriageYearController),
      'separation_year': _intOrNull(separationYearController),
      'divorce_year': _intOrNull(divorceYearController),
      'spouse_death_year': _intOrNull(spouseDeathYearController),
      'divorce_status': divorceStatus,
      'remarriage_reason': _stringOrNull(remarriageReason),
      'notes': _textOrNull(notesController),
    };
  }

  Map<String, dynamic> toStatusPayload(
    String? statusKey,
    int? maritalStatusId,
  ) {
    return <String, dynamic>{
      if (id != null) 'id': id,
      'marital_status_id': maritalStatusId,
      'marriage_year': _intOrNull(marriageYearController),
      'separation_year': statusKey == 'separated'
          ? _intOrNull(separationYearController)
          : null,
      'divorce_year': statusKey == 'divorced' || statusKey == 'annulled'
          ? _intOrNull(divorceYearController)
          : null,
      'spouse_death_year': statusKey == 'widowed'
          ? _intOrNull(spouseDeathYearController)
          : null,
      'divorce_status':
          statusKey == 'divorced' ||
              statusKey == 'annulled' ||
              statusKey == 'separated'
          ? divorceStatus
          : null,
      'remarriage_reason': null,
      'notes': null,
    };
  }

  void dispose() {
    marriageYearController.dispose();
    separationYearController.dispose();
    divorceYearController.dispose();
    spouseDeathYearController.dispose();
    notesController.dispose();
  }

  static int? _intOrNull(TextEditingController controller) {
    final text = controller.text.trim();
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }

  static String? _textOrNull(TextEditingController controller) {
    return _stringOrNull(controller.text);
  }

  static String? _stringOrNull(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }
}

class _ChildEditRow {
  _ChildEditRow({
    this.id,
    this.childName,
    this.gender,
    String? age,
    this.childLivingWithId,
    this.sortOrder = 0,
  }) : ageController = TextEditingController(text: age ?? '');

  int? id;
  String? childName;
  String? gender;
  int? childLivingWithId;
  int sortOrder;
  final TextEditingController ageController;

  bool get hasData {
    return (childName != null && childName!.trim().isNotEmpty) ||
        (gender != null && gender!.trim().isNotEmpty) ||
        ageController.text.trim().isNotEmpty ||
        childLivingWithId != null;
  }

  Map<String, dynamic> toPayload(int index) {
    return <String, dynamic>{
      if (id != null) 'id': id,
      'child_name': _stringOrNull(childName),
      'gender': gender,
      'age': _intOrNull(ageController),
      'child_living_with_id': childLivingWithId,
      'sort_order': index,
    };
  }

  void dispose() {
    ageController.dispose();
  }

  static int? _intOrNull(TextEditingController controller) {
    final text = controller.text.trim();
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }

  static String? _stringOrNull(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }
}

class _AddressEditRow {
  _AddressEditRow({
    this.id,
    this.addressTypeKey,
    String? addressLine,
    String? locationLabel,
    this.locationId,
  }) : addressLineController = TextEditingController(text: addressLine ?? ''),
       locationController = TextEditingController(text: locationLabel ?? ''),
       selectedLocationLabel = locationLabel;

  int? id;
  String? addressTypeKey;
  int? locationId;
  String? selectedLocationLabel;
  bool locationSearching = false;
  List<Map<String, dynamic>> locationSuggestions = <Map<String, dynamic>>[];
  final TextEditingController addressLineController;
  final TextEditingController locationController;

  bool get hasData {
    return id != null ||
        addressLineController.text.trim().isNotEmpty ||
        locationController.text.trim().isNotEmpty ||
        locationId != null;
  }

  Map<String, dynamic> toPayload(String defaultTypeKey) {
    return <String, dynamic>{
      if (id != null) 'id': id,
      'address_type_key': _stringOrNull(addressTypeKey) ?? defaultTypeKey,
      'address_line': _textOrNull(addressLineController),
      'location_id': locationId,
    };
  }

  void dispose() {
    addressLineController.dispose();
    locationController.dispose();
  }

  static String? _textOrNull(TextEditingController controller) {
    return _stringOrNull(controller.text);
  }

  static String? _stringOrNull(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }
}

class _SiblingEditRow {
  _SiblingEditRow({
    this.id,
    this.relationType,
    this.maritalStatus,
    String? name,
    String? occupation,
    String? addressLine,
    String? notes,
    this.sortOrder = 0,
  }) : nameController = TextEditingController(text: name ?? ''),
       occupationController = TextEditingController(text: occupation ?? ''),
       addressLineController = TextEditingController(text: addressLine ?? ''),
       notesController = TextEditingController(text: notes ?? '');

  int? id;
  String? relationType;
  String? maritalStatus;
  int sortOrder;
  final TextEditingController nameController;
  final TextEditingController occupationController;
  final TextEditingController addressLineController;
  final TextEditingController notesController;

  bool get hasData {
    return relationType != null ||
        nameController.text.trim().isNotEmpty ||
        occupationController.text.trim().isNotEmpty ||
        addressLineController.text.trim().isNotEmpty ||
        notesController.text.trim().isNotEmpty;
  }

  Map<String, dynamic> toPayload(int index) {
    return <String, dynamic>{
      if (id != null) 'id': id,
      'relation_type': relationType,
      'name': _textOrNull(nameController),
      'marital_status': maritalStatus,
      'occupation': _textOrNull(occupationController),
      'address_line': _textOrNull(addressLineController),
      'notes': _textOrNull(notesController),
      'sort_order': index,
    };
  }

  void dispose() {
    nameController.dispose();
    occupationController.dispose();
    addressLineController.dispose();
    notesController.dispose();
  }

  static String? _textOrNull(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
  }
}

class _RelativeEditRow {
  _RelativeEditRow({
    this.id,
    this.relationType,
    String? name,
    String? occupation,
    String? addressLine,
    String? notes,
  }) : nameController = TextEditingController(text: name ?? ''),
       occupationController = TextEditingController(text: occupation ?? ''),
       addressLineController = TextEditingController(text: addressLine ?? ''),
       notesController = TextEditingController(text: notes ?? '');

  int? id;
  String? relationType;
  final TextEditingController nameController;
  final TextEditingController occupationController;
  final TextEditingController addressLineController;
  final TextEditingController notesController;

  bool get hasData {
    return relationType != null ||
        nameController.text.trim().isNotEmpty ||
        occupationController.text.trim().isNotEmpty ||
        addressLineController.text.trim().isNotEmpty ||
        notesController.text.trim().isNotEmpty;
  }

  Map<String, dynamic> toPayload() {
    final addressOnly = relationType == 'maternal_address_ajol';
    return <String, dynamic>{
      if (id != null) 'id': id,
      'relation_type': relationType,
      'name': addressOnly ? null : _textOrNull(nameController),
      'occupation': addressOnly ? null : _textOrNull(occupationController),
      'address_line': _textOrNull(addressLineController),
      'notes': addressOnly ? null : _textOrNull(notesController),
    };
  }

  void dispose() {
    nameController.dispose();
    occupationController.dispose();
    addressLineController.dispose();
    notesController.dispose();
  }

  static String? _textOrNull(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
  }
}

class _AllianceNetworkEditRow {
  _AllianceNetworkEditRow({
    this.id,
    String? surname,
    String? locationLabel,
    this.cityId,
    this.stateId,
    this.districtId,
    this.talukaId,
    String? notes,
  }) : surnameController = TextEditingController(text: surname ?? ''),
       locationController = TextEditingController(text: locationLabel ?? ''),
       notesController = TextEditingController(text: notes ?? ''),
       selectedLocationLabel = locationLabel;

  int? id;
  int? cityId;
  int? stateId;
  int? districtId;
  int? talukaId;
  String? selectedLocationLabel;
  bool locationSearching = false;
  List<Map<String, dynamic>> locationSuggestions = <Map<String, dynamic>>[];
  final TextEditingController surnameController;
  final TextEditingController locationController;
  final TextEditingController notesController;

  bool get hasData {
    return surnameController.text.trim().isNotEmpty ||
        locationController.text.trim().isNotEmpty ||
        cityId != null ||
        stateId != null ||
        districtId != null ||
        talukaId != null ||
        notesController.text.trim().isNotEmpty;
  }

  Map<String, dynamic> toPayload() {
    return <String, dynamic>{
      if (id != null) 'id': id,
      'surname': _textOrNull(surnameController),
      'city_id': cityId,
      'state_id': stateId,
      'district_id': districtId,
      'taluka_id': talukaId,
      'notes': _textOrNull(notesController),
    };
  }

  void dispose() {
    surnameController.dispose();
    locationController.dispose();
    notesController.dispose();
  }

  static String? _textOrNull(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
  }
}

class _EditFullProfileScreenState extends State<EditFullProfileScreen> {
  static const int _clearNumberSelection = -1;
  static const Duration _locationSearchDebounceDuration = Duration(
    milliseconds: 400,
  );
  static const String _defaultPreferredStateName = 'Maharashtra';
  static const List<Map<String, String>> _addressTypeOptions = [
    {'key': 'current', 'label': 'Current'},
    {'key': 'permanent', 'label': 'Permanent'},
    {'key': 'native', 'label': 'Native'},
    {'key': 'work', 'label': 'Work'},
    {'key': 'other', 'label': 'Other'},
  ];

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _religionController = TextEditingController();
  final TextEditingController _casteController = TextEditingController();
  final TextEditingController _subCasteController = TextEditingController();
  final TextEditingController _educationController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _addressLineController = TextEditingController();
  final TextEditingController _birthTimeController = TextEditingController();
  final TextEditingController _birthPlaceController = TextEditingController();
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _workLocationController = TextEditingController();
  final TextEditingController _incomeAmountController = TextEditingController();
  final TextEditingController _incomeMinAmountController =
      TextEditingController();
  final TextEditingController _incomeMaxAmountController =
      TextEditingController();
  final TextEditingController _fatherNameController = TextEditingController();
  final TextEditingController _fatherOccupationController =
      TextEditingController();
  final TextEditingController _fatherExtraInfoController =
      TextEditingController();
  final TextEditingController _fatherContact1Controller =
      TextEditingController();
  final TextEditingController _fatherContact2Controller =
      TextEditingController();
  final TextEditingController _fatherContact3Controller =
      TextEditingController();
  final TextEditingController _motherNameController = TextEditingController();
  final TextEditingController _motherOccupationController =
      TextEditingController();
  final TextEditingController _motherExtraInfoController =
      TextEditingController();
  final TextEditingController _motherContact1Controller =
      TextEditingController();
  final TextEditingController _motherContact2Controller =
      TextEditingController();
  final TextEditingController _motherContact3Controller =
      TextEditingController();
  final TextEditingController _familyIncomeAmountController =
      TextEditingController();
  final TextEditingController _familyIncomeMinAmountController =
      TextEditingController();
  final TextEditingController _familyIncomeMaxAmountController =
      TextEditingController();
  final TextEditingController _otherRelativesController =
      TextEditingController();
  final TextEditingController _propertyDetailsController =
      TextEditingController();
  final TextEditingController _devakController = TextEditingController();
  final TextEditingController _kulController = TextEditingController();
  final TextEditingController _gotraController = TextEditingController();
  final TextEditingController _navrasNameController = TextEditingController();
  final TextEditingController _aboutMeController = TextEditingController();
  final TextEditingController _expectationsController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _gendersLoading = false;
  bool _religionsLoading = false;
  bool _castesLoading = false;
  bool _subCasteSearching = false;
  bool _birthPlaceSearching = false;
  bool _workLocationSearching = false;
  bool _optionsLoading = false;
  bool _educationCareerOptionsLoading = false;
  bool _maritalLifestyleOptionsLoading = false;
  bool _remainingProfileOptionsLoading = false;
  bool _partnerPreferenceOptionsLoading = false;
  bool _showFatherContact2 = false;
  bool _showFatherContact3 = false;
  bool _showMotherContact2 = false;
  bool _showMotherContact3 = false;
  bool _fatherContact2Removed = false;
  bool _fatherContact3Removed = false;
  bool _motherContact2Removed = false;
  bool _motherContact3Removed = false;
  int _parentContactMaxSlots = 2;
  _EditProfileSection? _expandedSection;
  Map<String, dynamic>? _expandedSectionSnapshot;
  Map<String, dynamic>? _lastLoadedProfile;
  final ScrollController _scrollController = ScrollController();
  final Map<_EditProfileSection, GlobalKey> _sectionCardKeys = {
    _EditProfileSection.basic: GlobalKey(),
    _EditProfileSection.physical: GlobalKey(),
    _EditProfileSection.educationCareer: GlobalKey(),
    _EditProfileSection.familyDetails: GlobalKey(),
    _EditProfileSection.siblings: GlobalKey(),
    _EditProfileSection.relatives: GlobalKey(),
    _EditProfileSection.property: GlobalKey(),
    _EditProfileSection.horoscope: GlobalKey(),
    _EditProfileSection.aboutMe: GlobalKey(),
    _EditProfileSection.partnerPreferences: GlobalKey(),
    _EditProfileSection.photo: GlobalKey(),
  };
  Timer? _savedHighlightTimer;
  _EditProfileSection? _savedFeedbackSection;
  bool _savedHighlightOn = false;
  bool _showSavedChip = false;

  String? _loadError;
  String? _optionsError;
  String? _educationCareerOptionsError;
  String? _maritalLifestyleOptionsError;
  String? _remainingProfileOptionsError;
  String? _partnerPreferenceOptionsError;
  String? _selectedReligionLabel;
  String? _selectedCasteLabel;
  String? _selectedSubCasteLabel;
  String? _selectedLocationLabel;
  String? _selectedBirthPlaceLabel;
  String? _selectedEducationDegreeLabel;
  String? _selectedOccupationLabel;
  String? _selectedFatherOccupationLabel;
  String? _selectedMotherOccupationLabel;
  String? _selectedWorkLocationLabel;
  String? _selectedSpectaclesLens;
  String? _selectedPhysicalCondition;
  String? _selectedIncomePeriod;
  String? _selectedIncomeValueType;
  String? _selectedFamilyStatus;
  String? _selectedFamilyValues;
  String? _selectedFamilyIncomePeriod;
  String? _selectedFamilyIncomeValueType;
  String? _selectedBirthWeekday;
  String? _selectedMaritalStatusKey;
  String? _selectedPartnerProfileWithChildren;
  String? _selectedPreferredProfileManagedBy;

  int? _selectedGenderId;
  int? _selectedReligionId;
  int? _selectedCasteId;
  int? _selectedSubCasteId;
  int? _selectedLocationId;
  int? _selectedBirthCityId;
  int? _selectedMotherTongueId;
  int? _selectedHeightCm;
  int? _selectedWeightKg;
  int? _selectedComplexionId;
  int? _selectedBloodGroupId;
  int? _selectedPhysicalBuildId;
  int? _selectedMaritalStatusId;
  bool? _selectedHasChildren;
  bool _showIncomeGroup = false;
  bool _showFamilyIncomeGroup = false;
  int? _selectedDietId;
  int? _selectedSmokingStatusId;
  int? _selectedDrinkingStatusId;
  int? _selectedEducationDegreeId;
  int? _selectedOccupationMasterId;
  int? _selectedOccupationCustomId;
  int? _selectedIncomeCurrencyId;
  int? _selectedFatherOccupationMasterId;
  int? _selectedFatherOccupationCustomId;
  int? _selectedMotherOccupationMasterId;
  int? _selectedMotherOccupationCustomId;
  int? _selectedFamilyTypeId;
  int? _selectedFamilyIncomeCurrencyId;
  bool? _selectedHasSiblings;
  int? _selectedRashiId;
  int? _selectedNakshatraId;
  int? _selectedCharan;
  int? _selectedGanId;
  int? _selectedNadiId;
  int? _selectedYoniId;
  int? _selectedVarnaId;
  int? _selectedVashyaId;
  int? _selectedRashiLordId;
  int? _selectedMangalDoshTypeId;
  int? _selectedPreferredAgeMin;
  int? _selectedPreferredAgeMax;
  int? _selectedPreferredHeightMinCm;
  int? _selectedPreferredHeightMaxCm;
  int? _selectedPreferredIncomeMin;
  int? _selectedPreferredIncomeMax;
  int? _selectedMarriageTypePreferenceId;
  int? _preferredStateId;
  bool? _selectedWillingToRelocate;
  bool? _selectedPreferredIntercaste;
  bool _incomePrivate = false;
  bool _familyIncomePrivate = false;

  int _subCasteSearchRequest = 0;
  int _birthPlaceSearchRequest = 0;
  int _workLocationSearchRequest = 0;
  int _addressLocationSearchRequest = 0;
  int _allianceLocationSearchRequest = 0;
  Timer? _birthPlaceSearchDebounce;
  Timer? _workLocationSearchDebounce;
  Timer? _addressLocationSearchDebounce;
  Timer? _allianceLocationSearchDebounce;

  List<Map<String, dynamic>> _genders = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _religions = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _religionSuggestions = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _castes = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _casteSuggestions = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _subCasteSuggestions = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _birthPlaceSuggestions = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _workLocationSuggestions =
      <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _motherTongueOptions = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _complexionOptions = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _bloodGroupOptions = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _physicalBuildOptions = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _spectaclesLensOptions = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _physicalConditionOptions =
      <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _maritalStatusOptions = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _childLivingWithOptions = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _dietOptions = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _smokingStatusOptions = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _drinkingStatusOptions = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _educationDegreeOptions = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _educationSuggestions = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _occupationOptions = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _customOccupationOptions =
      <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _incomeCurrencyOptions = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _familyTypeOptions = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _familyStatusOptions = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _familyValueOptions = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _familyOccupationOptions =
      <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _familyCustomOccupationOptions =
      <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _rashiOptions = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _nakshatraOptions = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _ganOptions = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _nadiOptions = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _yoniOptions = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _varnaOptions = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _vashyaOptions = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _rashiLordOptions = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _mangalDoshTypeOptions = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _birthWeekdayOptions = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _marriageTypePreferenceOptions =
      <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _preferredMaritalStatusOptions =
      <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _partnerProfileWithChildrenOptions =
      <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _preferredProfileManagedByOptions =
      <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _preferredDietOptions = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _preferredReligionOptions =
      <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _preferredCasteOptions = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _preferredMotherTongueOptions =
      <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _preferredEducationDegreeOptions =
      <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _preferredOccupationOptions =
      <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _preferredLocationSuggestionRows =
      <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _selectedPreferredLocationRows =
      <Map<String, dynamic>>[];
  final Set<int> _selectedPreferredMaritalStatusIds = <int>{};
  final Set<int> _selectedPreferredDietIds = <int>{};
  final Set<int> _selectedPreferredReligionIds = <int>{};
  final Set<int> _selectedPreferredCasteIds = <int>{};
  final Set<int> _selectedPreferredMotherTongueIds = <int>{};
  final Set<int> _selectedPreferredEducationDegreeIds = <int>{};
  final Set<int> _selectedPreferredOccupationMasterIds = <int>{};
  final Set<int> _selectedPreferredCountryIds = <int>{};
  final Set<int> _selectedPreferredStateIds = <int>{};
  final Set<int> _selectedPreferredDistrictIds = <int>{};
  final Set<int> _selectedPreferredTalukaIds = <int>{};
  bool _hasSavedPreferredEducationDegreeIds = false;
  bool _hasSavedPreferredOccupationMasterIds = false;
  bool _hasSavedPreferredIncomeMin = false;
  bool _hasSavedPreferredIncomeMax = false;
  bool _preferredEducationTouched = false;
  bool _preferredOccupationTouched = false;
  bool _preferredIncomeTouched = false;
  final List<_MarriageEditRow> _marriageRows = <_MarriageEditRow>[];
  final List<_ChildEditRow> _childRows = <_ChildEditRow>[];
  final List<_AddressEditRow> _selfAddressRows = <_AddressEditRow>[];
  final List<_AddressEditRow> _parentsAddressRows = <_AddressEditRow>[];
  final List<_SiblingEditRow> _siblingRows = <_SiblingEditRow>[];
  final List<_RelativeEditRow> _relativeRows = <_RelativeEditRow>[];
  final List<_AllianceNetworkEditRow> _allianceNetworkRows =
      <_AllianceNetworkEditRow>[];
  bool _preferredLocationsTouched = false;
  Map<String, dynamic> _horoscopeRules = <String, dynamic>{};
  Map<String, dynamic> _rashiAshtakoota = <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    final initialProfile =
        widget.initialProfile ?? ApiClient.currentUserProfile;
    if (initialProfile != null) {
      _prefillProfile(initialProfile);
    }
    _loadScreenData();
  }

  @override
  void dispose() {
    _birthPlaceSearchDebounce?.cancel();
    _workLocationSearchDebounce?.cancel();
    _addressLocationSearchDebounce?.cancel();
    _allianceLocationSearchDebounce?.cancel();
    _savedHighlightTimer?.cancel();
    _scrollController.dispose();
    _fullNameController.dispose();
    _dobController.dispose();
    _religionController.dispose();
    _casteController.dispose();
    _subCasteController.dispose();
    _educationController.dispose();
    _locationController.dispose();
    _addressLineController.dispose();
    _birthTimeController.dispose();
    _birthPlaceController.dispose();
    _companyNameController.dispose();
    _workLocationController.dispose();
    _incomeAmountController.dispose();
    _incomeMinAmountController.dispose();
    _incomeMaxAmountController.dispose();
    _fatherNameController.dispose();
    _fatherOccupationController.dispose();
    _fatherExtraInfoController.dispose();
    _fatherContact1Controller.dispose();
    _fatherContact2Controller.dispose();
    _fatherContact3Controller.dispose();
    _motherNameController.dispose();
    _motherOccupationController.dispose();
    _motherExtraInfoController.dispose();
    _motherContact1Controller.dispose();
    _motherContact2Controller.dispose();
    _motherContact3Controller.dispose();
    _familyIncomeAmountController.dispose();
    _familyIncomeMinAmountController.dispose();
    _familyIncomeMaxAmountController.dispose();
    _otherRelativesController.dispose();
    _propertyDetailsController.dispose();
    _devakController.dispose();
    _kulController.dispose();
    _gotraController.dispose();
    _navrasNameController.dispose();
    _aboutMeController.dispose();
    _expectationsController.dispose();
    _disposeMarriageRows();
    _disposeChildRows();
    _disposeAddressRows(_selfAddressRows);
    _disposeAddressRows(_parentsAddressRows);
    _disposeSiblingRows();
    _disposeRelativeRows();
    _disposeAllianceNetworkRows();
    super.dispose();
  }

  int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  bool? _readBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;

    final text = value?.toString().trim().toLowerCase();
    if (text == null || text.isEmpty || text == 'null') return null;
    if (['1', 'true', 'yes', 'y'].contains(text)) return true;
    if (['0', 'false', 'no', 'n'].contains(text)) return false;

    return null;
  }

  String? _readText(dynamic value) {
    if (value == null || value is Map || value is List) return null;

    final text = value.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return null;

    return text;
  }

  String _phoneText(dynamic value) {
    if (value == null || value is Map || value is List) return '';

    final text = value.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return '';

    return text;
  }

  String _readAmountText(dynamic value) {
    final text = _readText(value);
    if (text == null) return '';

    final parsed = double.tryParse(text);
    if (parsed == null) return text;
    if (parsed == parsed.roundToDouble()) {
      return parsed.toInt().toString();
    }

    return parsed.toString();
  }

  num? _nullableNumber(TextEditingController controller) {
    final text = controller.text.trim().replaceAll(',', '');
    if (text.isEmpty) return null;

    final intValue = int.tryParse(text);
    if (intValue != null) return intValue;

    return double.tryParse(text);
  }

  Map<String, dynamic> _readMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);

    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _readRows(dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];

    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  int _parentContactSlotsFromProfile(Map<String, dynamic> profile) {
    final explicit = _readInt(profile['parent_contact_max_slots']);
    if (explicit != null && explicit >= 3) return 3;
    if (profile.containsKey('father_contact_3') ||
        profile.containsKey('mother_contact_3')) {
      return 3;
    }

    return 2;
  }

  bool get _supportsParentContact3 => _parentContactMaxSlots >= 3;

  bool _shouldSendOptionalParentContact(
    TextEditingController controller,
    bool visible,
    bool removed,
  ) {
    return visible || controller.text.trim().isNotEmpty || removed;
  }

  void _disposeSiblingRows() {
    for (final row in _siblingRows) {
      row.dispose();
    }
    _siblingRows.clear();
  }

  void _disposeMarriageRows() {
    for (final row in _marriageRows) {
      row.dispose();
    }
    _marriageRows.clear();
  }

  void _disposeChildRows() {
    for (final row in _childRows) {
      row.dispose();
    }
    _childRows.clear();
  }

  void _disposeAddressRows(List<_AddressEditRow> rows) {
    for (final row in rows) {
      row.dispose();
    }
    rows.clear();
  }

  void _clearChildrenSelection() {
    _selectedHasChildren = false;
    _disposeChildRows();
  }

  void _disposeRelativeRows() {
    for (final row in _relativeRows) {
      row.dispose();
    }
    _relativeRows.clear();
  }

  void _disposeAllianceNetworkRows() {
    for (final row in _allianceNetworkRows) {
      row.dispose();
    }
    _allianceNetworkRows.clear();
  }

  void _prefillMarriages(dynamic value) {
    _disposeMarriageRows();
    final rows = _readRows(value);
    if (rows.isEmpty) return;

    rows.sort((a, b) {
      final aId = _readInt(a['id']) ?? 0;
      final bId = _readInt(b['id']) ?? 0;
      return bId.compareTo(aId);
    });
    final row = rows.first;
    _marriageRows.add(
      _MarriageEditRow(
        id: _readInt(row['id']),
        marriageYear: _readText(row['marriage_year']),
        separationYear: _readText(row['separation_year']),
        divorceYear: _readText(row['divorce_year']),
        spouseDeathYear: _readText(row['spouse_death_year']),
        divorceStatus: _readDivorceStatus(row['divorce_status']),
        remarriageReason: ApiClient.safeDisplayLabel(row['remarriage_reason']),
        notes: ApiClient.safeDisplayLabel(row['notes']),
      ),
    );
  }

  void _prefillChildren(dynamic value) {
    _disposeChildRows();
    for (final row in _readRows(value)) {
      _childRows.add(
        _ChildEditRow(
          id: _readInt(row['id']),
          childName: ApiClient.safeDisplayLabel(row['child_name']),
          gender: _readChildGender(row['gender']),
          age: _readText(row['age']),
          childLivingWithId: _readInt(row['child_living_with_id']),
          sortOrder: _readInt(row['sort_order']) ?? _childRows.length,
        ),
      );
    }
    if (_selectedHasChildren == null && _childRows.isNotEmpty) {
      _selectedHasChildren = true;
    }
  }

  String? _addressLocationLabel(Map<String, dynamic> row) {
    return ApiClient.safeDisplayLabel(row['location_label']) ??
        ApiClient.safeDisplayLabel(row['display']) ??
        _joinSummaryParts([
          ApiClient.safeDisplayLabel(row['city_label']),
          ApiClient.safeDisplayLabel(row['taluka_label']),
          ApiClient.safeDisplayLabel(row['district_label']),
          ApiClient.safeDisplayLabel(row['state_label']),
        ], separator: ', ');
  }

  _AddressEditRow _addressRowFromMap(
    Map<String, dynamic> row,
    String defaultTypeKey,
  ) {
    return _AddressEditRow(
      id: _readInt(row['id']),
      addressTypeKey:
          _readText(row['address_type_key']) ??
          _readText(row['address_type']) ??
          defaultTypeKey,
      addressLine: ApiClient.safeDisplayLabel(row['address_line']),
      locationId: _readInt(row['location_id']) ?? _readInt(row['city_id']),
      locationLabel: _addressLocationLabel(row),
    );
  }

  void _prefillAddressRows(Map<String, dynamic> profile) {
    _disposeAddressRows(_selfAddressRows);
    _disposeAddressRows(_parentsAddressRows);

    final selfRows = _readRows(profile['self_addresses']);
    if (selfRows.isEmpty) {
      _selfAddressRows.add(
        _AddressEditRow(
          addressTypeKey: 'current',
          addressLine: ApiClient.safeDisplayLabel(profile['address_line']),
          locationId: _readInt(profile['location_id']),
          locationLabel:
              ApiClient.safeDisplayLabel(profile['location_label']) ??
              ApiClient.profileLocationLabel(profile, allowIdFallback: false),
        ),
      );
    } else {
      for (final row in selfRows) {
        _selfAddressRows.add(_addressRowFromMap(row, 'current'));
      }
    }

    final parentsRows = _readRows(profile['parents_addresses']);
    if (parentsRows.isEmpty) {
      _parentsAddressRows.add(_AddressEditRow(addressTypeKey: 'permanent'));
    } else {
      for (final row in parentsRows) {
        _parentsAddressRows.add(_addressRowFromMap(row, 'permanent'));
      }
    }

    _syncCurrentAddressFromSelfRows();
  }

  _AddressEditRow? _currentSelfAddressRow() {
    for (final row in _selfAddressRows) {
      if ((row.addressTypeKey ?? '').trim() == 'current') {
        return row;
      }
    }
    return _selfAddressRows.isNotEmpty ? _selfAddressRows.first : null;
  }

  void _syncCurrentAddressFromSelfRows() {
    final current = _currentSelfAddressRow();
    if (current == null) return;

    _selectedLocationId = current.locationId;
    _selectedLocationLabel = current.selectedLocationLabel;
    _locationController.text = current.selectedLocationLabel ?? '';
    _addressLineController.text = current.addressLineController.text;
  }

  void _prefillSiblings(dynamic value) {
    _disposeSiblingRows();
    for (final row in _readRows(value)) {
      _siblingRows.add(
        _SiblingEditRow(
          id: _readInt(row['id']),
          relationType: _readSiblingRelationType(row['relation_type']),
          maritalStatus: _readSiblingMaritalStatus(row['marital_status']),
          name: ApiClient.safeDisplayLabel(row['name']),
          occupation:
              ApiClient.safeDisplayLabel(row['occupation']) ??
              ApiClient.safeDisplayLabel(row['occupation_master_label']) ??
              ApiClient.safeDisplayLabel(row['occupation_custom_label']),
          addressLine:
              ApiClient.safeDisplayLabel(row['address_line']) ??
              ApiClient.safeDisplayLabel(row['city_label']),
          notes: ApiClient.safeDisplayLabel(row['notes']),
          sortOrder: _readInt(row['sort_order']) ?? _siblingRows.length,
        ),
      );
    }
    if (_selectedHasSiblings == null && _siblingRows.isNotEmpty) {
      _selectedHasSiblings = true;
    }
  }

  void _prefillRelatives(dynamic value) {
    _disposeRelativeRows();
    for (final row in _readRows(value)) {
      _relativeRows.add(
        _RelativeEditRow(
          id: _readInt(row['id']),
          relationType: _readRelativeRelationType(row['relation_type']),
          name: ApiClient.safeDisplayLabel(row['name']),
          occupation:
              ApiClient.safeDisplayLabel(row['occupation']) ??
              ApiClient.safeDisplayLabel(row['occupation_master_label']) ??
              ApiClient.safeDisplayLabel(row['occupation_custom_label']),
          addressLine:
              ApiClient.safeDisplayLabel(row['address_line']) ??
              ApiClient.safeDisplayLabel(row['city_label']),
          notes: ApiClient.safeDisplayLabel(row['notes']),
        ),
      );
    }
  }

  String? _allianceNetworkLocationLabel(Map<String, dynamic> row) {
    return _joinSummaryParts([
      ApiClient.safeDisplayLabel(row['city_label']),
      ApiClient.safeDisplayLabel(row['taluka_label']),
      ApiClient.safeDisplayLabel(row['district_label']),
      ApiClient.safeDisplayLabel(row['state_label']),
    ], separator: ', ');
  }

  void _prefillAllianceNetworks(dynamic value) {
    _disposeAllianceNetworkRows();
    for (final row in _readRows(value)) {
      _allianceNetworkRows.add(
        _AllianceNetworkEditRow(
          id: _readInt(row['id']),
          surname: ApiClient.safeDisplayLabel(row['surname']),
          locationLabel: _allianceNetworkLocationLabel(row),
          cityId: _readInt(row['city_id']),
          stateId: _readInt(row['state_id']),
          districtId: _readInt(row['district_id']),
          talukaId: _readInt(row['taluka_id']),
          notes: ApiClient.safeDisplayLabel(row['notes']),
        ),
      );
    }
  }

  String? _readSiblingRelationType(dynamic value) {
    final text = _readText(value);
    if (text == null) return null;
    return const [
          'brother',
          'sister',
          'brother_wife',
          'sister_husband',
        ].contains(text)
        ? text
        : null;
  }

  String? _readRelativeRelationType(dynamic value) {
    final text = _readText(value);
    if (text == null) return null;
    return _relativeRelationOptions().any(
          (row) => _readText(row['value']) == text,
        )
        ? text
        : null;
  }

  String? _readSiblingMaritalStatus(dynamic value) {
    final text = _readText(value);
    if (text == null) return null;
    return const ['unmarried', 'married'].contains(text) ? text : null;
  }

  String? _readDivorceStatus(dynamic value) {
    final text = _readText(value);
    if (text == null) return null;
    return const ['pending', 'finalized', 'mutual', 'contested'].contains(text)
        ? text
        : null;
  }

  String? _readChildGender(dynamic value) {
    final text = _readText(value);
    if (text == null) return null;
    return const ['male', 'female', 'other', 'prefer_not_say'].contains(text)
        ? text
        : null;
  }

  List<Map<String, dynamic>> _divorceStatusOptions() {
    return const <Map<String, dynamic>>[
      {'value': 'pending', 'label': 'Pending'},
      {'value': 'finalized', 'label': 'Finalized'},
      {'value': 'mutual', 'label': 'Mutual'},
      {'value': 'contested', 'label': 'Contested'},
    ];
  }

  List<Map<String, dynamic>> _childGenderOptions() {
    return const <Map<String, dynamic>>[
      {'value': 'male', 'label': 'Male'},
      {'value': 'female', 'label': 'Female'},
      {'value': 'other', 'label': 'Other'},
      {'value': 'prefer_not_say', 'label': 'Prefer not to say'},
    ];
  }

  List<Map<String, dynamic>> _siblingRelationOptions() {
    return const <Map<String, dynamic>>[
      {'value': 'brother', 'label': 'Brother'},
      {'value': 'sister', 'label': 'Sister'},
      {'value': 'brother_wife', 'label': "Brother's wife"},
      {'value': 'sister_husband', 'label': "Sister's husband"},
    ];
  }

  List<Map<String, dynamic>> _siblingMaritalStatusOptions() {
    return const <Map<String, dynamic>>[
      {'value': 'unmarried', 'label': 'Unmarried'},
      {'value': 'married', 'label': 'Married'},
    ];
  }

  List<Map<String, dynamic>> _relativeRelationOptions() {
    return const <Map<String, dynamic>>[
      {'value': 'paternal_grandfather', 'label': 'Paternal Grandfather'},
      {'value': 'paternal_grandmother', 'label': 'Paternal Grandmother'},
      {'value': 'paternal_uncle', 'label': 'Paternal Uncle'},
      {'value': 'wife_paternal_uncle', 'label': 'Wife of Paternal Uncle'},
      {'value': 'paternal_aunt', 'label': 'Paternal Aunt'},
      {'value': 'husband_paternal_aunt', 'label': 'Husband of Paternal Aunt'},
      {'value': 'Cousin', 'label': 'Cousin'},
      {'value': 'maternal_address_ajol', 'label': 'Maternal address (Ajol)'},
      {'value': 'maternal_grandfather', 'label': 'Maternal Grandfather'},
      {'value': 'maternal_grandmother', 'label': 'Maternal Grandmother'},
      {'value': 'maternal_uncle', 'label': 'Maternal Uncle'},
      {'value': 'wife_maternal_uncle', 'label': "Maternal Uncle's wife"},
      {'value': 'maternal_aunt', 'label': 'Maternal Aunt'},
      {'value': 'husband_maternal_aunt', 'label': 'Husband of Maternal Aunt'},
      {'value': 'maternal_cousin', 'label': 'Cousin'},
    ];
  }

  List<int> _readIntList(dynamic value) {
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return <int>[];
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is List) {
          return decoded
              .map(_readInt)
              .whereType<int>()
              .toSet()
              .toList(growable: false);
        }
      } catch (_) {
        return trimmed
            .split(',')
            .map(_readInt)
            .whereType<int>()
            .toSet()
            .toList(growable: false);
      }
    }

    if (value is! List) return <int>[];

    return value
        .map((item) {
          if (item is Map) return _readInt(item['id']);
          return _readInt(item);
        })
        .whereType<int>()
        .toSet()
        .toList(growable: false);
  }

  double? _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  String _optionLabel(Map<String, dynamic> row, String fallbackPrefix) {
    final localizedValue = localizedMapValue(row);
    if (localizedValue != null) return localizedValue;

    for (final key in ['label', 'label_en', 'name', 'display_label', 'key']) {
      final value = _readText(row[key]);
      if (value != null) return value;
    }

    return fallbackPrefix;
  }

  Map<String, dynamic>? _normalizePreferredLocationRow(dynamic value) {
    if (value is! Map) return null;
    final row = Map<String, dynamic>.from(value);
    final id =
        _readInt(row['id']) ??
        _readInt(row['taluka_id']) ??
        _readInt(row['location_id']);
    if (id == null) return null;

    final label =
        ApiClient.safeDisplayLabel(row['label']) ??
        ApiClient.safeDisplayLabel(row['display_label']) ??
        ApiClient.safeDisplayLabel(row['location_label']) ??
        ApiClient.safeDisplayLabel(row);
    if (label == null || label.trim().isEmpty) return null;

    return <String, dynamic>{
      'id': id,
      'type': _readText(row['type']) ?? 'taluka',
      'label': label.trim(),
      'district_id':
          _readInt(row['district_id']) ??
          _readInt(row['preferred_district_id']),
      'state_id':
          _readInt(row['state_id']) ?? _readInt(row['preferred_state_id']),
      'country_id':
          _readInt(row['country_id']) ?? _readInt(row['preferred_country_id']),
      'distance_km': _readDouble(row['distance_km']),
      'source': _readText(row['source']),
    };
  }

  List<Map<String, dynamic>> _normalizePreferredLocationRows(dynamic value) {
    final rows = _readRows(
      value,
    ).map(_normalizePreferredLocationRow).whereType<Map<String, dynamic>>();
    final seen = <int>{};
    final out = <Map<String, dynamic>>[];
    for (final row in rows) {
      final id = _readInt(row['id']);
      if (id == null || seen.contains(id)) continue;
      seen.add(id);
      out.add(row);
    }
    return out;
  }

  List<Map<String, dynamic>> _locationRowsMatchingTalukas(
    List<Map<String, dynamic>> rows,
    Set<int> talukaIds,
  ) {
    if (talukaIds.isEmpty) return <Map<String, dynamic>>[];

    return rows
        .where((row) {
          final id = _readInt(row['id']);
          return id != null && talukaIds.contains(id);
        })
        .toList(growable: false);
  }

  void _syncPreferredLocationIdSetsFromRows(List<Map<String, dynamic>> rows) {
    _selectedPreferredCountryIds
      ..clear()
      ..addAll(_idsFromLocationRows(rows, 'country_id'));
    _selectedPreferredStateIds
      ..clear()
      ..addAll(_idsFromLocationRows(rows, 'state_id'));
    _selectedPreferredDistrictIds
      ..clear()
      ..addAll(_idsFromLocationRows(rows, 'district_id'));
    _selectedPreferredTalukaIds
      ..clear()
      ..addAll(_idsFromLocationRows(rows, 'id'));
  }

  Set<int> _idsFromLocationRows(List<Map<String, dynamic>> rows, String key) {
    final out = <int>{};
    for (final row in rows) {
      final id = _readInt(row[key]);
      if (id != null && id > 0) out.add(id);
    }
    return out;
  }

  List<int> _preferredLocationPayloadIds(String key, Set<int> fallback) {
    if (_selectedPreferredLocationRows.isEmpty && !_preferredLocationsTouched) {
      return fallback.toList(growable: false);
    }

    final ids = <int>[];
    for (final row in _selectedPreferredLocationRows) {
      final id = _readInt(row[key]);
      if (id != null && id > 0 && !ids.contains(id)) {
        ids.add(id);
      }
    }
    return ids;
  }

  bool _sameLocationRowOrder(
    List<Map<String, dynamic>> first,
    List<Map<String, dynamic>> second,
  ) {
    final firstIds = first.map((row) => _readInt(row['id'])).whereType<int>();
    final secondIds = second.map((row) => _readInt(row['id'])).whereType<int>();
    return jsonEncode(firstIds.toList()) == jsonEncode(secondIds.toList());
  }

  String? _preferredLocationSummary() {
    final count = _selectedPreferredLocationRows.length;
    if (count <= 0) return null;

    final firstLabel = _readText(_selectedPreferredLocationRows.first['label']);
    if (firstLabel == null) return '$count locations';
    if (count == 1) return firstLabel;
    return '$firstLabel +${count - 1} nearby';
  }

  void _prefillPreferredLocations(
    Map<String, dynamic> profile,
    Map<String, dynamic> suggestions,
  ) {
    _preferredLocationsTouched = false;
    _preferredLocationSuggestionRows = _normalizePreferredLocationRows(
      suggestions['preferred_location_suggestions'],
    );

    final savedCountryIds = _readIntList(
      profile['preferred_country_ids'] ?? profile['preferred_countries'],
    );
    final savedStateIds = _readIntList(
      profile['preferred_state_ids'] ?? profile['preferred_states'],
    );
    final savedDistrictIds = _readIntList(
      profile['preferred_district_ids'] ?? profile['preferred_districts'],
    );
    final savedTalukaIds = _readIntList(
      profile['preferred_taluka_ids'] ?? profile['preferred_talukas'],
    );

    final hasSavedLocationIds =
        savedCountryIds.isNotEmpty ||
        savedStateIds.isNotEmpty ||
        savedDistrictIds.isNotEmpty ||
        savedTalukaIds.isNotEmpty;

    if (hasSavedLocationIds) {
      _selectedPreferredCountryIds
        ..clear()
        ..addAll(savedCountryIds);
      _selectedPreferredStateIds
        ..clear()
        ..addAll(savedStateIds);
      _selectedPreferredDistrictIds
        ..clear()
        ..addAll(savedDistrictIds);
      _selectedPreferredTalukaIds
        ..clear()
        ..addAll(savedTalukaIds);

      final savedRows = _normalizePreferredLocationRows(
        profile['preferred_location_suggestions'] ??
            profile['preferred_locations'] ??
            profile['preferred_taluka_locations'] ??
            profile['preferred_talukas'],
      );
      _selectedPreferredLocationRows = savedRows.isNotEmpty
          ? savedRows
          : _locationRowsMatchingTalukas(
              _preferredLocationSuggestionRows,
              _selectedPreferredTalukaIds,
            );
      return;
    }

    _selectedPreferredLocationRows = List<Map<String, dynamic>>.from(
      _preferredLocationSuggestionRows,
    );
    if (_selectedPreferredLocationRows.isNotEmpty) {
      _syncPreferredLocationIdSetsFromRows(_selectedPreferredLocationRows);
      return;
    }

    _selectedPreferredCountryIds.clear();
    _selectedPreferredStateIds.clear();
    _selectedPreferredDistrictIds.clear();
    _selectedPreferredTalukaIds.clear();
  }

  String _locationLabel(Map<String, dynamic> location) {
    final label = ApiClient.locationSuggestionLabel(location).trim();
    if (label.isNotEmpty &&
        label != 'Unknown location' &&
        !label.toLowerCase().startsWith('location id:')) {
      return label;
    }

    return ApiClient.safeDisplayLabel(location['display_label']) ??
        ApiClient.safeDisplayLabel(location['location_label']) ??
        ApiClient.safeDisplayLabel(location['label']) ??
        ApiClient.safeDisplayLabel(location['name']) ??
        'Location';
  }

  int? _locationStateId(Map<String, dynamic> location) {
    final direct =
        _readInt(location['state_id']) ?? _readInt(location['stateId']);
    if (direct != null) return direct;

    final state = location['state'];
    if (state is Map) {
      return _readInt(state['id']);
    }

    return null;
  }

  int? _locationDistrictId(Map<String, dynamic> location) {
    final direct =
        _readInt(location['district_id']) ?? _readInt(location['districtId']);
    if (direct != null) return direct;

    final district = location['district'];
    if (district is Map) {
      return _readInt(district['id']);
    }

    return null;
  }

  int? _locationTalukaId(Map<String, dynamic> location) {
    final direct =
        _readInt(location['taluka_id']) ?? _readInt(location['talukaId']);
    if (direct != null) return direct;

    final taluka = location['taluka'];
    if (taluka is Map) {
      return _readInt(taluka['id']);
    }

    return null;
  }

  int? _profileLocationStateId(Map<String, dynamic> profile) {
    final direct =
        _readInt(profile['state_id']) ??
        _readInt(profile['location_state_id']) ??
        _readInt(profile['current_location_state_id']);
    if (direct != null) return direct;

    for (final key in ['location', 'current_location', 'residence_location']) {
      final value = profile[key];
      if (value is Map) {
        final id = _locationStateId(Map<String, dynamic>.from(value));
        if (id != null) return id;
      }
    }

    return null;
  }

  Future<List<Map<String, dynamic>>> _searchLocationOptions(String query) {
    return ApiClient.searchLocations(
      query,
      preferredStateId: _preferredStateId,
      preferredStateName: _preferredStateId == null
          ? _defaultPreferredStateName
          : null,
      limit: 20,
    );
  }

  String? _optionStoredValue(Map<String, dynamic> row) {
    for (final key in ['key', 'value', 'code']) {
      final value = _readText(row[key]);
      if (value != null) return value;
    }

    return null;
  }

  List<Map<String, dynamic>> _filterOptions(
    List<Map<String, dynamic>> rows,
    String query,
  ) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return rows.take(20).toList();

    return rows
        .where((row) {
          return [
            'label',
            'name',
            'display_label',
            'label_en',
            'label_mr',
            'code',
            'full_form',
            'category_label',
            'category_label_mr',
          ].any((key) {
            final value = row[key]?.toString().toLowerCase();
            return value != null && value.contains(normalizedQuery);
          });
        })
        .take(20)
        .toList();
  }

  Map<String, dynamic>? _optionById(
    List<Map<String, dynamic>> options,
    int? id,
  ) {
    if (id == null) return null;
    for (final option in options) {
      if (_readInt(option['id']) == id) return option;
    }
    return null;
  }

  String _normalizedOptionText(Map<String, dynamic> row) {
    final parts = <String?>[
      _readText(row['code']),
      _readText(row['label']),
      _readText(row['label_en']),
      _readText(row['full_form']),
      _readText(row['category_label']),
    ];
    return parts
        .whereType<String>()
        .join(' ')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
  }

  int? _educationLevelRank(Map<String, dynamic> row) {
    final text = ' ${_normalizedOptionText(row)} ';
    if (text.trim().isEmpty) return null;
    if (RegExp(r'\b(phd|ph d|doctorate|doctoral)\b').hasMatch(text)) {
      return 5;
    }
    if (RegExp(
      r'\b(post graduate|postgraduation|post graduation|master|masters|pg|ma|mcom|msc|mba|mca|me|mtech)\b',
    ).hasMatch(text)) {
      return 4;
    }
    if (RegExp(
      r'\b(graduation|graduate|under graduate|undergraduate|bachelor|ba|bcom|bsc|bca|be|btech|ug)\b',
    ).hasMatch(text)) {
      return 3;
    }
    if (RegExp(r'\b(diploma|iti|polytechnic)\b').hasMatch(text)) {
      return 2;
    }
    if (RegExp(r'\b(ssc|hsc|school|10th|12th)\b').hasMatch(text)) {
      return 1;
    }
    return null;
  }

  List<int> _categoryOrderAtOrAbove(
    List<Map<String, dynamic>> options,
    int selectedCategoryId,
  ) {
    final categoryOrder = <int>[];
    for (final option in options) {
      final categoryId = _readInt(option['category_id']);
      if (categoryId == null || categoryOrder.contains(categoryId)) continue;
      categoryOrder.add(categoryId);
    }
    final selectedIndex = categoryOrder.indexOf(selectedCategoryId);
    if (selectedIndex < 0) return const <int>[];
    final allowedCategoryIds = categoryOrder.skip(selectedIndex).toSet();
    return options
        .where((option) {
          final categoryId = _readInt(option['category_id']);
          return categoryId != null && allowedCategoryIds.contains(categoryId);
        })
        .map((option) => _readInt(option['id']))
        .whereType<int>()
        .toSet()
        .toList(growable: false);
  }

  List<int> _smartPreferredEducationDegreeIds() {
    final selectedId =
        _selectedEducationDegreeId ??
        _findEducationDegreeIdByText(_educationController.text);
    if (selectedId == null) return const <int>[];

    final options = _preferredEducationDegreeOptions.isNotEmpty
        ? _preferredEducationDegreeOptions
        : _educationDegreeOptions;
    if (options.isEmpty) return <int>[selectedId];

    final selectedRow =
        _optionById(options, selectedId) ??
        _optionById(_educationDegreeOptions, selectedId);
    if (selectedRow == null) return <int>[selectedId];

    final selectedRank = _educationLevelRank(selectedRow);
    if (selectedRank != null) {
      final rankedIds = options
          .where((option) {
            final rank = _educationLevelRank(option);
            return rank != null && rank >= selectedRank;
          })
          .map((option) => _readInt(option['id']))
          .whereType<int>()
          .toSet()
          .toList(growable: false);
      if (rankedIds.isNotEmpty) return rankedIds;
    }

    final selectedCategoryId = _readInt(selectedRow['category_id']);
    if (selectedCategoryId != null) {
      final categoryIds = _categoryOrderAtOrAbove(options, selectedCategoryId);
      if (categoryIds.isNotEmpty) return categoryIds;
    }

    return <int>[selectedId];
  }

  List<int> _smartPreferredOccupationMasterIds() {
    final selectedId = _selectedOccupationMasterId;
    if (selectedId == null) return const <int>[];

    final options = _preferredOccupationOptions.isNotEmpty
        ? _preferredOccupationOptions
        : _occupationOptions;
    if (options.isEmpty) return <int>[selectedId];

    final selectedRow =
        _optionById(options, selectedId) ??
        _optionById(_occupationOptions, selectedId);
    final categoryId = _readInt(selectedRow?['category_id']);
    if (categoryId == null) return <int>[selectedId];

    final ids = options
        .where((option) => _readInt(option['category_id']) == categoryId)
        .map((option) => _readInt(option['id']))
        .whereType<int>()
        .toSet()
        .toList(growable: false);
    return ids.isNotEmpty ? ids : <int>[selectedId];
  }

  int? _annualizedIncomeFromCurrentInputs() {
    final valueType = _selectedIncomeValueType;
    num? amount;
    if (valueType == 'range') {
      amount = _nullableNumber(_incomeMinAmountController);
    } else {
      amount = _nullableNumber(_incomeAmountController);
    }
    amount ??= _nullableNumber(_incomeMinAmountController);
    if (amount == null || amount <= 0) return null;

    final period = _selectedIncomePeriod ?? 'annual';
    final multiplier = switch (period) {
      'monthly' => 12,
      'weekly' => 52,
      'daily' => 365,
      _ => 1,
    };
    return (amount * multiplier).round();
  }

  int? _annualizedIncomeFromLoadedProfile() {
    final profile = _lastLoadedProfile;
    if (profile == null) return null;
    final direct =
        _readDouble(profile['income_normalized_annual_amount']) ??
        _readDouble(profile['annual_income']);
    if (direct != null && direct > 0) return direct.round();

    final amount =
        _readDouble(profile['income_amount']) ??
        _readDouble(profile['income_min_amount']);
    if (amount == null || amount <= 0) return null;

    final period = _readText(profile['income_period']) ?? 'annual';
    final multiplier = switch (period) {
      'monthly' => 12,
      'weekly' => 52,
      'daily' => 365,
      _ => 1,
    };
    return (amount * multiplier).round();
  }

  int? _smartPreferredIncomeMin() {
    final annualIncome =
        _annualizedIncomeFromCurrentInputs() ??
        _annualizedIncomeFromLoadedProfile();
    if (annualIncome == null || annualIncome <= 0) return null;
    return (annualIncome * 0.7).round();
  }

  void _applySmartPartnerPreferenceDefaults() {
    if (!_hasSavedPreferredEducationDegreeIds && !_preferredEducationTouched) {
      final ids = _smartPreferredEducationDegreeIds();
      if (ids.isNotEmpty) {
        _selectedPreferredEducationDegreeIds
          ..clear()
          ..addAll(ids);
      }
    }

    if (!_hasSavedPreferredOccupationMasterIds &&
        !_preferredOccupationTouched) {
      final ids = _smartPreferredOccupationMasterIds();
      if (ids.isNotEmpty) {
        _selectedPreferredOccupationMasterIds
          ..clear()
          ..addAll(ids);
      }
    }

    if (!_preferredIncomeTouched) {
      if (!_hasSavedPreferredIncomeMin) {
        final min = _smartPreferredIncomeMin();
        if (min != null) _selectedPreferredIncomeMin = min;
      }
      if (!_hasSavedPreferredIncomeMax) {
        _selectedPreferredIncomeMax = null;
      }
    }
  }

  String _educationDegreeLabel(Map<String, dynamic> degree) {
    return _readText(degree['code']) ?? _optionLabel(degree, 'Education');
  }

  int? _findEducationDegreeIdByText(String text) {
    final normalized = text.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    for (final degree in _educationDegreeOptions) {
      final id = _readInt(degree['id']);
      if (id == null) continue;

      final candidates = <String?>[
        _readText(degree['code']),
        _readText(degree['label']),
        _readText(degree['label_en']),
        _readText(degree['label_mr']),
        _readText(degree['full_form']),
      ];
      if (candidates.any((candidate) {
        return candidate != null &&
            candidate.trim().toLowerCase() == normalized;
      })) {
        return id;
      }
    }

    return null;
  }

  void _syncSelectedEducationFromText() {
    final degreeId = _findEducationDegreeIdByText(_educationController.text);
    _selectedEducationDegreeId = degreeId;
    _selectedEducationDegreeLabel = degreeId == null
        ? null
        : _labelForId(_educationDegreeOptions, degreeId, 'Education');
  }

  void _prefillProfile(Map<String, dynamic> profile) {
    _fullNameController.text = _readText(profile['full_name']) ?? '';
    _dobController.text = _readText(profile['date_of_birth']) ?? '';
    _educationController.text = ApiClient.profileEducationLabel(profile) ?? '';
    _selectedEducationDegreeId = null;
    _selectedEducationDegreeLabel = null;
    _selectedGenderId = _readInt(profile['gender_id']);
    _selectedReligionId = _readInt(profile['religion_id']);
    _selectedCasteId = _readInt(profile['caste_id']);
    _selectedSubCasteId = _readInt(profile['sub_caste_id']);
    _selectedReligionLabel = ApiClient.profileReligionLabel(profile);
    _selectedCasteLabel = ApiClient.profileCasteLabel(profile);
    _selectedSubCasteLabel = ApiClient.profileSubCasteLabel(profile);
    _religionController.text = _selectedReligionLabel ?? '';
    _casteController.text =
        _selectedCasteLabel ??
        ApiClient.safeDisplayLabel(profile['caste']) ??
        '';
    _subCasteController.text = _selectedSubCasteLabel ?? '';
    _selectedLocationId = _readInt(profile['location_id']);
    _selectedLocationLabel = ApiClient.profileLocationLabel(
      profile,
      allowIdFallback: false,
    );
    _locationController.text = _selectedLocationLabel ?? '';
    _addressLineController.text =
        ApiClient.safeDisplayLabel(profile['address_line']) ?? '';
    _preferredStateId = _profileLocationStateId(profile);
    _prefillAddressRows(profile);

    _birthTimeController.text = _readText(profile['birth_time']) ?? '';
    _selectedBirthCityId = _readInt(profile['birth_city_id']);
    _selectedBirthPlaceLabel =
        ApiClient.safeDisplayLabel(profile['birth_place_label']) ??
        ApiClient.safeDisplayLabel(profile['birth_place']);
    _birthPlaceController.text =
        ApiClient.safeDisplayLabel(profile['birth_place_text']) ??
        _selectedBirthPlaceLabel ??
        '';
    _selectedMotherTongueId = _readInt(profile['mother_tongue_id']);
    _selectedHeightCm = _readInt(profile['height_cm']);
    _selectedWeightKg = _readInt(profile['weight_kg']);
    _selectedComplexionId = _readInt(profile['complexion_id']);
    _selectedBloodGroupId = _readInt(profile['blood_group_id']);
    _selectedPhysicalBuildId = _readInt(profile['physical_build_id']);
    _selectedSpectaclesLens = _readText(profile['spectacles_lens']);
    _selectedPhysicalCondition = _readText(profile['physical_condition']);
    _selectedMaritalStatusId = _readInt(profile['marital_status_id']);
    _selectedMaritalStatusKey = _readText(profile['marital_status_key']);
    _selectedHasChildren = _readBool(profile['has_children']) ?? false;
    _prefillMarriages(profile['marriages']);
    _prefillChildren(profile['children']);
    final maritalStatusKey = _currentMaritalStatusKey();
    if (maritalStatusKey == 'never_married') {
      _clearChildrenSelection();
    } else if (_maritalStatusShowsDetails(maritalStatusKey)) {
      _ensureMarriageDetailRow();
      if (_selectedHasChildren != true) {
        _disposeChildRows();
      }
    }
    _selectedDietId = _readInt(profile['diet_id']);
    _selectedSmokingStatusId = _readInt(profile['smoking_status_id']);
    _selectedDrinkingStatusId = _readInt(profile['drinking_status_id']);
    _selectedOccupationMasterId = _readInt(profile['occupation_master_id']);
    _selectedOccupationCustomId = _readInt(profile['occupation_custom_id']);
    _selectedOccupationLabel =
        ApiClient.safeDisplayLabel(profile['occupation_master_label']) ??
        ApiClient.safeDisplayLabel(profile['occupation_custom_label']) ??
        ApiClient.profileOccupationLabel(profile);
    _companyNameController.text =
        ApiClient.safeDisplayLabel(profile['company_name']) ?? '';
    _workLocationController.text =
        ApiClient.safeDisplayLabel(profile['work_location_text']) ?? '';
    _selectedIncomeValueType = _readText(profile['income_value_type']);
    _selectedIncomePeriod = _readText(profile['income_period']);
    final incomeAmount = _readAmountText(
      profile['income_amount'] ?? profile['annual_income'],
    );
    _incomeAmountController.text = incomeAmount;
    _incomeMinAmountController.text = _readAmountText(
      profile['income_min_amount'],
    );
    _incomeMaxAmountController.text = _readAmountText(
      profile['income_max_amount'],
    );
    _showIncomeGroup = _incomeHasSavedValue(
      valueType: _selectedIncomeValueType,
      amountText: _incomeAmountController.text,
      minAmountText: _incomeMinAmountController.text,
      maxAmountText: _incomeMaxAmountController.text,
      private: _readBool(profile['income_private']) ?? false,
    );
    if (_showIncomeGroup && _selectedIncomeValueType == null) {
      if (incomeAmount.isNotEmpty) {
        _selectedIncomeValueType = 'exact';
      } else if (_incomeMinAmountController.text.trim().isNotEmpty ||
          _incomeMaxAmountController.text.trim().isNotEmpty) {
        _selectedIncomeValueType = 'range';
      } else {
        _selectedIncomeValueType = 'undisclosed';
      }
    }
    if (_showIncomeGroup && _selectedIncomePeriod == null) {
      _selectedIncomePeriod = 'annual';
    }
    _selectedIncomeCurrencyId = _readInt(profile['income_currency_id']);
    _incomePrivate = _readBool(profile['income_private']) ?? false;
    _selectedWorkLocationLabel =
        ApiClient.safeDisplayLabel(profile['work_location_label']) ??
        ApiClient.safeDisplayLabel(profile['work_location_text']);
    _parentContactMaxSlots = _parentContactSlotsFromProfile(profile);
    _fatherNameController.text =
        ApiClient.safeDisplayLabel(profile['father_name']) ?? '';
    _fatherOccupationController.text =
        ApiClient.safeDisplayLabel(profile['father_occupation']) ?? '';
    _fatherExtraInfoController.text =
        ApiClient.safeDisplayLabel(profile['father_extra_info']) ?? '';
    _fatherContact1Controller.text = _phoneText(profile['father_contact_1']);
    _fatherContact2Controller.text = _phoneText(profile['father_contact_2']);
    _fatherContact3Controller.text = _supportsParentContact3
        ? _phoneText(profile['father_contact_3'])
        : '';
    _showFatherContact3 =
        _supportsParentContact3 &&
        _fatherContact3Controller.text.trim().isNotEmpty;
    _showFatherContact2 =
        _fatherContact2Controller.text.trim().isNotEmpty || _showFatherContact3;
    _fatherContact2Removed = false;
    _fatherContact3Removed = false;
    _motherNameController.text =
        ApiClient.safeDisplayLabel(profile['mother_name']) ?? '';
    _motherOccupationController.text =
        ApiClient.safeDisplayLabel(profile['mother_occupation']) ?? '';
    _motherExtraInfoController.text =
        ApiClient.safeDisplayLabel(profile['mother_extra_info']) ?? '';
    _motherContact1Controller.text = _phoneText(profile['mother_contact_1']);
    _motherContact2Controller.text = _phoneText(profile['mother_contact_2']);
    _motherContact3Controller.text = _supportsParentContact3
        ? _phoneText(profile['mother_contact_3'])
        : '';
    _showMotherContact3 =
        _supportsParentContact3 &&
        _motherContact3Controller.text.trim().isNotEmpty;
    _showMotherContact2 =
        _motherContact2Controller.text.trim().isNotEmpty || _showMotherContact3;
    _motherContact2Removed = false;
    _motherContact3Removed = false;
    _selectedFatherOccupationMasterId = _readInt(
      profile['father_occupation_master_id'],
    );
    _selectedFatherOccupationCustomId = _readInt(
      profile['father_occupation_custom_id'],
    );
    _selectedMotherOccupationMasterId = _readInt(
      profile['mother_occupation_master_id'],
    );
    _selectedMotherOccupationCustomId = _readInt(
      profile['mother_occupation_custom_id'],
    );
    _selectedFatherOccupationLabel =
        ApiClient.safeDisplayLabel(profile['father_occupation_master_label']) ??
        ApiClient.safeDisplayLabel(profile['father_occupation_custom_label']) ??
        ApiClient.safeDisplayLabel(profile['father_occupation']);
    _selectedMotherOccupationLabel =
        ApiClient.safeDisplayLabel(profile['mother_occupation_master_label']) ??
        ApiClient.safeDisplayLabel(profile['mother_occupation_custom_label']) ??
        ApiClient.safeDisplayLabel(profile['mother_occupation']);
    _selectedFamilyTypeId = _readInt(profile['family_type_id']);
    _selectedFamilyStatus = _readText(profile['family_status']);
    _selectedFamilyValues = _readText(profile['family_values']);
    _selectedFamilyIncomeValueType = _readText(
      profile['family_income_value_type'],
    );
    _selectedFamilyIncomePeriod = _readText(profile['family_income_period']);
    final familyIncomeAmount = _readAmountText(
      profile['family_income_amount'] ?? profile['family_income'],
    );
    _familyIncomeAmountController.text = familyIncomeAmount;
    _familyIncomeMinAmountController.text = _readAmountText(
      profile['family_income_min_amount'],
    );
    _familyIncomeMaxAmountController.text = _readAmountText(
      profile['family_income_max_amount'],
    );
    _showFamilyIncomeGroup = _incomeHasSavedValue(
      valueType: _selectedFamilyIncomeValueType,
      amountText: _familyIncomeAmountController.text,
      minAmountText: _familyIncomeMinAmountController.text,
      maxAmountText: _familyIncomeMaxAmountController.text,
      private: _readBool(profile['family_income_private']) ?? false,
    );
    if (_showFamilyIncomeGroup && _selectedFamilyIncomeValueType == null) {
      if (familyIncomeAmount.isNotEmpty) {
        _selectedFamilyIncomeValueType = 'exact';
      } else if (_familyIncomeMinAmountController.text.trim().isNotEmpty ||
          _familyIncomeMaxAmountController.text.trim().isNotEmpty) {
        _selectedFamilyIncomeValueType = 'range';
      } else {
        _selectedFamilyIncomeValueType = 'undisclosed';
      }
    }
    if (_showFamilyIncomeGroup && _selectedFamilyIncomePeriod == null) {
      _selectedFamilyIncomePeriod = 'annual';
    }
    _selectedFamilyIncomeCurrencyId =
        _readInt(profile['family_income_currency_id']) ??
        _selectedIncomeCurrencyId;
    _familyIncomePrivate = _readBool(profile['family_income_private']) ?? false;
    _selectedHasSiblings = _readBool(profile['has_siblings']) ?? false;
    _prefillSiblings(profile['siblings']);
    if (_siblingRows.isNotEmpty) {
      _selectedHasSiblings = true;
    }
    _prefillRelatives(profile['relatives']);
    _prefillAllianceNetworks(profile['alliance_networks']);
    _otherRelativesController.text =
        ApiClient.safeDisplayLabel(profile['other_relatives_text']) ?? '';
    _propertyDetailsController.text =
        ApiClient.safeDisplayLabel(profile['property_details']) ?? '';
    _selectedRashiId = _readInt(profile['rashi_id']);
    _selectedNakshatraId = _readInt(profile['nakshatra_id']);
    _selectedCharan = _readInt(profile['charan']);
    _selectedGanId = _readInt(profile['gan_id']);
    _selectedNadiId = _readInt(profile['nadi_id']);
    _selectedYoniId = _readInt(profile['yoni_id']);
    _selectedVarnaId = _readInt(profile['varna_id']);
    _selectedVashyaId = _readInt(profile['vashya_id']);
    _selectedRashiLordId = _readInt(profile['rashi_lord_id']);
    _selectedMangalDoshTypeId = _readInt(profile['mangal_dosh_type_id']);
    _devakController.text = ApiClient.safeDisplayLabel(profile['devak']) ?? '';
    _kulController.text = ApiClient.safeDisplayLabel(profile['kul']) ?? '';
    _gotraController.text = ApiClient.safeDisplayLabel(profile['gotra']) ?? '';
    _navrasNameController.text =
        ApiClient.safeDisplayLabel(profile['navras_name']) ?? '';
    _selectedBirthWeekday = _readText(profile['birth_weekday']);
    _aboutMeController.text =
        ApiClient.safeDisplayLabel(profile['narrative_about_me']) ?? '';
    final partnerPreferenceSuggestions = _readMap(
      profile['partner_preference_suggestions'],
    );
    _preferredEducationTouched = false;
    _preferredOccupationTouched = false;
    _preferredIncomeTouched = false;
    _selectedPreferredAgeMin =
        _readInt(profile['preferred_age_min']) ??
        _readInt(partnerPreferenceSuggestions['preferred_age_min']);
    _selectedPreferredAgeMax =
        _readInt(profile['preferred_age_max']) ??
        _readInt(partnerPreferenceSuggestions['preferred_age_max']);
    _selectedPreferredHeightMinCm =
        _readInt(profile['preferred_height_min_cm']) ??
        _readInt(partnerPreferenceSuggestions['preferred_height_min_cm']);
    _selectedPreferredHeightMaxCm =
        _readInt(profile['preferred_height_max_cm']) ??
        _readInt(partnerPreferenceSuggestions['preferred_height_max_cm']);
    final savedPreferredIncomeMin = _readInt(profile['preferred_income_min']);
    final savedPreferredIncomeMax = _readInt(profile['preferred_income_max']);
    _hasSavedPreferredIncomeMin = savedPreferredIncomeMin != null;
    _hasSavedPreferredIncomeMax = savedPreferredIncomeMax != null;
    _selectedPreferredIncomeMin =
        savedPreferredIncomeMin ??
        _readInt(partnerPreferenceSuggestions['preferred_income_min']);
    _selectedPreferredIncomeMax =
        savedPreferredIncomeMax ??
        _readInt(partnerPreferenceSuggestions['preferred_income_max']);
    _selectedMarriageTypePreferenceId = _readInt(
      profile['marriage_type_preference_id'],
    );
    _selectedPartnerProfileWithChildren = _readText(
      profile['partner_profile_with_children'],
    );
    _selectedPreferredProfileManagedBy = _readText(
      profile['preferred_profile_managed_by'],
    );
    _selectedWillingToRelocate =
        _readBool(profile['willing_to_relocate']) ?? false;
    _selectedPreferredIntercaste =
        _readBool(profile['preferred_intercaste']) ?? false;
    final savedPreferredMaritalStatusIds = _readIntList(
      profile['preferred_marital_status_ids'] ??
          profile['preferred_marital_statuses'],
    );
    final savedPreferredDietIds = _readIntList(
      profile['preferred_diet_ids'] ?? profile['preferred_diets'],
    );
    final savedPreferredReligionIds = _readIntList(
      profile['preferred_religion_ids'] ?? profile['preferred_religions'],
    );
    final savedPreferredCasteIds = _readIntList(
      profile['preferred_caste_ids'] ?? profile['preferred_castes'],
    );
    final savedPreferredMotherTongueIds = _readIntList(
      profile['preferred_mother_tongue_ids'] ??
          profile['preferred_mother_tongues'],
    );
    final savedPreferredEducationDegreeIds = _readIntList(
      profile['preferred_education_degree_ids'] ??
          profile['preferred_education_degrees'],
    );
    final savedPreferredOccupationMasterIds = _readIntList(
      profile['preferred_occupation_master_ids'] ??
          profile['preferred_occupations'],
    );
    _hasSavedPreferredEducationDegreeIds =
        savedPreferredEducationDegreeIds.isNotEmpty;
    _hasSavedPreferredOccupationMasterIds =
        savedPreferredOccupationMasterIds.isNotEmpty;
    _selectedPreferredMaritalStatusIds
      ..clear()
      ..addAll(
        savedPreferredMaritalStatusIds.isNotEmpty
            ? savedPreferredMaritalStatusIds
            : _readIntList(
                partnerPreferenceSuggestions['preferred_marital_status_ids'],
              ),
      );
    _selectedPreferredDietIds
      ..clear()
      ..addAll(
        savedPreferredDietIds.isNotEmpty
            ? savedPreferredDietIds
            : _readIntList(partnerPreferenceSuggestions['preferred_diet_ids']),
      );
    _selectedPreferredReligionIds
      ..clear()
      ..addAll(
        savedPreferredReligionIds.isNotEmpty
            ? savedPreferredReligionIds
            : _readIntList(
                partnerPreferenceSuggestions['preferred_religion_ids'],
              ),
      );
    _selectedPreferredCasteIds
      ..clear()
      ..addAll(
        savedPreferredCasteIds.isNotEmpty
            ? savedPreferredCasteIds
            : _readIntList(partnerPreferenceSuggestions['preferred_caste_ids']),
      );
    _selectedPreferredMotherTongueIds
      ..clear()
      ..addAll(
        savedPreferredMotherTongueIds.isNotEmpty
            ? savedPreferredMotherTongueIds
            : _readIntList(
                partnerPreferenceSuggestions['preferred_mother_tongue_ids'],
              ),
      );
    _selectedPreferredEducationDegreeIds
      ..clear()
      ..addAll(
        savedPreferredEducationDegreeIds.isNotEmpty
            ? savedPreferredEducationDegreeIds
            : _readIntList(
                partnerPreferenceSuggestions['preferred_education_degree_ids'],
              ),
      );
    _selectedPreferredOccupationMasterIds
      ..clear()
      ..addAll(
        savedPreferredOccupationMasterIds.isNotEmpty
            ? savedPreferredOccupationMasterIds
            : _readIntList(
                partnerPreferenceSuggestions['preferred_occupation_master_ids'],
              ),
      );
    _prefillPreferredLocations(profile, partnerPreferenceSuggestions);
    _expectationsController.text =
        ApiClient.safeDisplayLabel(profile['narrative_expectations']) ?? '';
    _lastLoadedProfile = Map<String, dynamic>.from(profile);
    _applySmartPartnerPreferenceDefaults();
  }

  Future<void> _loadScreenData() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final profileResponse = await ApiClient.getMyProfile();
      final profile = profileResponse['profile'];
      if (profile is Map) {
        _prefillProfile(Map<String, dynamic>.from(profile));
      }
      await Future.wait([
        _loadGenders(),
        _loadReligions(),
        _loadBasicPhysicalOptions(),
        _loadEducationCareerOptions(),
        _loadMaritalLifestyleOptions(),
        _loadRemainingProfileOptions(),
        _loadPartnerPreferenceOptions(),
      ]);
    } catch (_) {
      if (!mounted) return;
      _loadError = 'Profile load करता आली नाही.';
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
    });
  }

  Future<void> _loadGenders() async {
    if (!mounted) return;
    setState(() {
      _gendersLoading = true;
    });

    try {
      final results = await ApiClient.getGenders();
      if (!mounted) return;
      setState(() {
        _genders = results;
      });
    } finally {
      if (mounted) {
        setState(() {
          _gendersLoading = false;
        });
      }
    }
  }

  Future<void> _loadReligions() async {
    if (!mounted) return;
    setState(() {
      _religionsLoading = true;
    });

    try {
      final results = await ApiClient.getReligions();
      if (!mounted) return;
      setState(() {
        _religions = results;
      });

      final selectedReligionId = _selectedReligionId;
      if (selectedReligionId != null) {
        final selected = results.where(
          (row) => _readInt(row['id']) == selectedReligionId,
        );
        if (selected.isNotEmpty) {
          _selectedReligionLabel = _optionLabel(selected.first, 'Religion');
          _religionController.text = _selectedReligionLabel ?? '';
        }
        await _loadCastes(selectedReligionId, preserveSelection: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _religionsLoading = false;
        });
      }
    }
  }

  Future<void> _loadBasicPhysicalOptions() async {
    if (!mounted) return;
    setState(() {
      _optionsLoading = true;
      _optionsError = null;
    });

    try {
      final results = await ApiClient.getProfileBasicPhysicalOptions();
      if (!mounted) return;
      setState(() {
        _motherTongueOptions =
            results['mother_tongues'] ?? <Map<String, dynamic>>[];
        _complexionOptions = results['complexions'] ?? <Map<String, dynamic>>[];
        _bloodGroupOptions =
            results['blood_groups'] ?? <Map<String, dynamic>>[];
        _physicalBuildOptions =
            results['physical_builds'] ?? <Map<String, dynamic>>[];
        _spectaclesLensOptions =
            results['spectacles_lens'] ?? <Map<String, dynamic>>[];
        _physicalConditionOptions =
            results['physical_conditions'] ?? <Map<String, dynamic>>[];
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _optionsError = 'Dropdown options load करता आले नाहीत.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _optionsLoading = false;
        });
      }
    }
  }

  Future<void> _loadEducationCareerOptions() async {
    if (!mounted) return;
    setState(() {
      _educationCareerOptionsLoading = true;
      _educationCareerOptionsError = null;
    });

    try {
      final results = await ApiClient.getProfileEducationCareerOptions();
      if (!mounted) return;
      setState(() {
        _educationDegreeOptions =
            results['education_degrees'] ?? <Map<String, dynamic>>[];
        _occupationOptions = results['occupations'] ?? <Map<String, dynamic>>[];
        _customOccupationOptions =
            results['custom_occupations'] ?? <Map<String, dynamic>>[];
        _incomeCurrencyOptions =
            results['currencies'] ?? <Map<String, dynamic>>[];
        _ensureDefaultCurrencySelections();
        _syncSelectedEducationFromText();
        _applySmartPartnerPreferenceDefaults();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _educationCareerOptionsError =
            'Education आणि career options load करता आले नाहीत.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _educationCareerOptionsLoading = false;
        });
      }
    }
  }

  Future<void> _loadMaritalLifestyleOptions() async {
    if (!mounted) return;
    setState(() {
      _maritalLifestyleOptionsLoading = true;
      _maritalLifestyleOptionsError = null;
    });

    try {
      final results = await ApiClient.getProfileMaritalLifestyleOptions();
      if (!mounted) return;
      setState(() {
        _maritalStatusOptions =
            results['marital_statuses'] ?? <Map<String, dynamic>>[];
        _selectedMaritalStatusKey =
            _maritalStatusKeyForId(_selectedMaritalStatusId) ??
            _selectedMaritalStatusKey;
        _childLivingWithOptions =
            results['child_living_with'] ?? <Map<String, dynamic>>[];
        _dietOptions = results['diets'] ?? <Map<String, dynamic>>[];
        _smokingStatusOptions =
            results['smoking_statuses'] ?? <Map<String, dynamic>>[];
        _drinkingStatusOptions =
            results['drinking_statuses'] ?? <Map<String, dynamic>>[];
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _maritalLifestyleOptionsError =
            'Marital आणि lifestyle options load करता आले नाहीत.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _maritalLifestyleOptionsLoading = false;
        });
      }
    }
  }

  Future<void> _loadRemainingProfileOptions() async {
    if (!mounted) return;
    setState(() {
      _remainingProfileOptionsLoading = true;
      _remainingProfileOptionsError = null;
    });

    try {
      final results = await ApiClient.getProfileRemainingProfileOptions();
      if (!mounted) return;
      setState(() {
        _familyTypeOptions = _readRows(results['family_types']);
        _familyStatusOptions = _readRows(results['family_statuses']);
        _familyValueOptions = _readRows(results['family_values']);
        _familyOccupationOptions = _readRows(results['occupations']);
        _familyCustomOccupationOptions = _readRows(
          results['custom_occupations'],
        );
        final currencies = _readRows(results['currencies']);
        if (currencies.isNotEmpty) {
          _incomeCurrencyOptions = currencies;
          _ensureDefaultCurrencySelections();
        }
        _rashiOptions = _readRows(results['rashis']);
        _nakshatraOptions = _readRows(results['nakshatras']);
        _ganOptions = _readRows(results['gans']);
        _nadiOptions = _readRows(results['nadis']);
        _yoniOptions = _readRows(results['yonis']);
        _varnaOptions = _readRows(results['varnas']);
        _vashyaOptions = _readRows(results['vashyas']);
        _rashiLordOptions = _readRows(results['rashi_lords']);
        _mangalDoshTypeOptions = _readRows(results['mangal_dosh_types']);
        _birthWeekdayOptions = _readRows(results['birth_weekdays']);
        _horoscopeRules = _readMap(results['horoscope_rules']);
        _rashiAshtakoota = _readMap(results['rashi_ashtakoota']);
        _applyHoroscopeDependencies();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _remainingProfileOptionsError =
            'Family आणि horoscope options load करता आले नाहीत.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _remainingProfileOptionsLoading = false;
        });
      }
    }
  }

  Future<void> _loadPartnerPreferenceOptions() async {
    if (!mounted) return;
    setState(() {
      _partnerPreferenceOptionsLoading = true;
      _partnerPreferenceOptionsError = null;
    });

    try {
      final results = await ApiClient.getProfilePartnerPreferenceOptions();
      if (!mounted) return;
      setState(() {
        _marriageTypePreferenceOptions =
            results['marriage_type_preferences'] ?? <Map<String, dynamic>>[];
        _preferredMaritalStatusOptions =
            results['marital_statuses'] ?? <Map<String, dynamic>>[];
        _partnerProfileWithChildrenOptions =
            results['partner_profile_with_children'] ??
            <Map<String, dynamic>>[];
        _preferredProfileManagedByOptions =
            results['preferred_profile_managed_by'] ?? <Map<String, dynamic>>[];
        _preferredDietOptions = results['diets'] ?? <Map<String, dynamic>>[];
        _preferredReligionOptions =
            results['religions'] ?? <Map<String, dynamic>>[];
        _preferredCasteOptions = results['castes'] ?? <Map<String, dynamic>>[];
        _preferredMotherTongueOptions =
            results['mother_tongues'] ?? <Map<String, dynamic>>[];
        _preferredEducationDegreeOptions =
            results['education_degrees'] ?? <Map<String, dynamic>>[];
        _preferredOccupationOptions =
            results['occupations'] ?? <Map<String, dynamic>>[];
        _removeInvalidPreferredCastes();
        _applySmartPartnerPreferenceDefaults();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _partnerPreferenceOptionsError =
            'Partner preference options load करता आले नाहीत.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _partnerPreferenceOptionsLoading = false;
        });
      }
    }
  }

  Future<void> _loadCastes(
    int religionId, {
    bool preserveSelection = false,
  }) async {
    setState(() {
      _castesLoading = true;
      _casteSuggestions = <Map<String, dynamic>>[];
    });

    try {
      final results = await ApiClient.getCastes(religionId: religionId);
      if (!mounted) return;
      setState(() {
        _castes = results;
      });

      if (preserveSelection && _selectedCasteId != null) {
        final selected = results.where(
          (row) => _readInt(row['id']) == _selectedCasteId,
        );
        if (selected.isNotEmpty) {
          setState(() {
            _selectedCasteLabel = _optionLabel(selected.first, 'Caste');
            _casteController.text = _selectedCasteLabel ?? '';
          });
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _castesLoading = false;
        });
      }
    }
  }

  void _onReligionChanged(String query) {
    if (_selectedReligionLabel == null || query != _selectedReligionLabel) {
      _selectedReligionId = null;
      _selectedReligionLabel = null;
      _selectedCasteId = null;
      _selectedCasteLabel = null;
      _selectedSubCasteId = null;
      _selectedSubCasteLabel = null;
      _castes = <Map<String, dynamic>>[];
      _casteController.clear();
      _subCasteController.clear();
    }

    setState(() {
      _religionSuggestions = _filterOptions(_religions, query);
    });
  }

  Future<void> _selectReligion(Map<String, dynamic> religion) async {
    final id = _readInt(religion['id']);
    if (id == null) return;

    final label = _optionLabel(religion, 'Religion');
    setState(() {
      _selectedReligionId = id;
      _selectedReligionLabel = label;
      _religionController.text = label;
      _religionSuggestions = <Map<String, dynamic>>[];
      _selectedCasteId = null;
      _selectedCasteLabel = null;
      _selectedSubCasteId = null;
      _selectedSubCasteLabel = null;
      _casteController.clear();
      _subCasteController.clear();
    });

    await _loadCastes(id);
  }

  void _onCasteChanged(String query) {
    if (_selectedCasteLabel == null || query != _selectedCasteLabel) {
      _selectedCasteId = null;
      _selectedCasteLabel = null;
      _selectedSubCasteId = null;
      _selectedSubCasteLabel = null;
      _subCasteController.clear();
    }

    setState(() {
      _casteSuggestions = _filterOptions(_castes, query);
    });
  }

  void _selectCaste(Map<String, dynamic> caste) {
    final id = _readInt(caste['id']);
    if (id == null) return;

    final label = _optionLabel(caste, 'Caste');
    setState(() {
      _selectedCasteId = id;
      _selectedCasteLabel = label;
      _casteController.text = label;
      _casteSuggestions = <Map<String, dynamic>>[];
      _selectedSubCasteId = null;
      _selectedSubCasteLabel = null;
      _subCasteController.clear();
      _subCasteSuggestions = <Map<String, dynamic>>[];
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _searchSubCastes(String query) async {
    final casteId = _selectedCasteId;
    final requestId = ++_subCasteSearchRequest;
    final trimmedQuery = query.trim();

    if (_selectedSubCasteLabel == null ||
        trimmedQuery != _selectedSubCasteLabel) {
      _selectedSubCasteId = null;
      _selectedSubCasteLabel = null;
    }

    if (casteId == null || trimmedQuery.length < 2) {
      setState(() {
        _subCasteSearching = false;
        _subCasteSuggestions = <Map<String, dynamic>>[];
      });
      return;
    }

    setState(() {
      _subCasteSearching = true;
    });

    try {
      final results = await ApiClient.searchSubCastes(
        casteId: casteId,
        query: trimmedQuery,
      );
      if (!mounted || requestId != _subCasteSearchRequest) return;
      setState(() {
        _subCasteSuggestions = results;
        _subCasteSearching = false;
      });
    } catch (_) {
      if (!mounted || requestId != _subCasteSearchRequest) return;
      setState(() {
        _subCasteSearching = false;
        _subCasteSuggestions = <Map<String, dynamic>>[];
      });
    }
  }

  void _selectSubCaste(Map<String, dynamic> subCaste) {
    final id = _readInt(subCaste['id']);
    if (id == null) return;

    final label = _optionLabel(subCaste, 'Sub-caste');
    setState(() {
      _selectedSubCasteId = id;
      _selectedSubCasteLabel = label;
      _subCasteController.text = label;
      _subCasteSuggestions = <Map<String, dynamic>>[];
      _subCasteSearching = false;
    });
    FocusScope.of(context).unfocus();
  }

  void _onEducationChanged(String query) {
    setState(() {
      if (_selectedEducationDegreeLabel == null ||
          query.trim() != _selectedEducationDegreeLabel) {
        _selectedEducationDegreeId = null;
        _selectedEducationDegreeLabel = null;
      }
      _educationSuggestions = _filterOptions(_educationDegreeOptions, query);
    });
  }

  void _selectEducation(Map<String, dynamic> degree) {
    final id = _readInt(degree['id']);
    final label = _educationDegreeLabel(degree);
    setState(() {
      _selectedEducationDegreeId = id;
      _selectedEducationDegreeLabel = label;
      _educationController.text = label;
      _educationSuggestions = <Map<String, dynamic>>[];
    });
    FocusScope.of(context).unfocus();
  }

  String? _selectedOccupationChoice() {
    if (_selectedOccupationMasterId != null) {
      return 'master:${_selectedOccupationMasterId!}';
    }
    if (_selectedOccupationCustomId != null) {
      return 'custom:${_selectedOccupationCustomId!}';
    }

    return null;
  }

  void _selectOccupationChoice(String? value) {
    setState(() {
      if (value == null || value.trim().isEmpty) {
        _selectedOccupationMasterId = null;
        _selectedOccupationCustomId = null;
        _selectedOccupationLabel = null;
        return;
      }

      final parts = value.split(':');
      if (parts.length != 2) return;

      final id = int.tryParse(parts[1]);
      if (id == null) return;

      if (parts[0] == 'master') {
        _selectedOccupationMasterId = id;
        _selectedOccupationCustomId = null;
        _selectedOccupationLabel = _labelForId(
          _occupationOptions,
          id,
          'Occupation',
        );
      } else if (parts[0] == 'custom') {
        _selectedOccupationMasterId = null;
        _selectedOccupationCustomId = id;
        _selectedOccupationLabel = _labelForId(
          _customOccupationOptions,
          id,
          'Occupation',
        );
      }
    });
  }

  String? _occupationChoiceValue(int? masterId, int? customId) {
    if (masterId != null) return 'master:$masterId';
    if (customId != null) return 'custom:$customId';
    return null;
  }

  void _selectFamilyOccupationChoice({
    required bool father,
    required String? value,
  }) {
    setState(() {
      if (value == null || value.trim().isEmpty) {
        if (father) {
          _selectedFatherOccupationMasterId = null;
          _selectedFatherOccupationCustomId = null;
          _selectedFatherOccupationLabel = null;
        } else {
          _selectedMotherOccupationMasterId = null;
          _selectedMotherOccupationCustomId = null;
          _selectedMotherOccupationLabel = null;
        }
        return;
      }

      final parts = value.split(':');
      if (parts.length != 2) return;

      final id = int.tryParse(parts[1]);
      if (id == null) return;

      if (parts[0] == 'master') {
        if (father) {
          _selectedFatherOccupationMasterId = id;
          _selectedFatherOccupationCustomId = null;
          _selectedFatherOccupationLabel = _labelForId(
            _familyOccupationOptions,
            id,
            'Occupation',
          );
        } else {
          _selectedMotherOccupationMasterId = id;
          _selectedMotherOccupationCustomId = null;
          _selectedMotherOccupationLabel = _labelForId(
            _familyOccupationOptions,
            id,
            'Occupation',
          );
        }
      } else if (parts[0] == 'custom') {
        if (father) {
          _selectedFatherOccupationMasterId = null;
          _selectedFatherOccupationCustomId = id;
          _selectedFatherOccupationLabel = _labelForId(
            _familyCustomOccupationOptions,
            id,
            'Occupation',
          );
        } else {
          _selectedMotherOccupationMasterId = null;
          _selectedMotherOccupationCustomId = id;
          _selectedMotherOccupationLabel = _labelForId(
            _familyCustomOccupationOptions,
            id,
            'Occupation',
          );
        }
      }
    });
  }

  void _scheduleBirthPlaceSearch(String query) {
    _birthPlaceSearchDebounce?.cancel();
    final requestId = ++_birthPlaceSearchRequest;
    final trimmedQuery = query.trim();

    setState(() {
      if (_selectedBirthPlaceLabel == null ||
          trimmedQuery != _selectedBirthPlaceLabel) {
        _selectedBirthCityId = null;
        _selectedBirthPlaceLabel = null;
      }
      if (trimmedQuery.length < 2) {
        _birthPlaceSearching = false;
        _birthPlaceSuggestions = <Map<String, dynamic>>[];
      } else {
        _birthPlaceSearching = true;
      }
    });

    if (trimmedQuery.length < 2) {
      return;
    }

    _birthPlaceSearchDebounce = Timer(_locationSearchDebounceDuration, () {
      _runBirthPlaceSearch(trimmedQuery, requestId);
    });
  }

  Future<void> _runBirthPlaceSearch(String trimmedQuery, int requestId) async {
    try {
      final results = await _searchLocationOptions(trimmedQuery);
      if (!mounted || requestId != _birthPlaceSearchRequest) return;
      setState(() {
        _birthPlaceSuggestions = results;
        _birthPlaceSearching = false;
      });
    } catch (_) {
      if (!mounted || requestId != _birthPlaceSearchRequest) return;
      setState(() {
        _birthPlaceSearching = false;
        _birthPlaceSuggestions = <Map<String, dynamic>>[];
      });
    }
  }

  void _selectBirthPlace(Map<String, dynamic> location) {
    final locationId = ApiClient.locationIdFrom(location);
    if (locationId == null) return;

    final label = _locationLabel(location);
    setState(() {
      _selectedBirthCityId = locationId;
      _selectedBirthPlaceLabel = label;
      _birthPlaceController.text = label;
      _birthPlaceSuggestions = <Map<String, dynamic>>[];
      _birthPlaceSearching = false;
    });
    FocusScope.of(context).unfocus();
  }

  void _scheduleWorkLocationSearch(String query) {
    _workLocationSearchDebounce?.cancel();
    final requestId = ++_workLocationSearchRequest;
    final trimmedQuery = query.trim();

    setState(() {
      if (_selectedWorkLocationLabel == null ||
          trimmedQuery != _selectedWorkLocationLabel) {
        _selectedWorkLocationLabel = null;
      }
      if (trimmedQuery.length < 2) {
        _workLocationSearching = false;
        _workLocationSuggestions = <Map<String, dynamic>>[];
      } else {
        _workLocationSearching = true;
      }
    });

    if (trimmedQuery.length < 2) {
      return;
    }

    _workLocationSearchDebounce = Timer(_locationSearchDebounceDuration, () {
      _runWorkLocationSearch(trimmedQuery, requestId);
    });
  }

  Future<void> _runWorkLocationSearch(
    String trimmedQuery,
    int requestId,
  ) async {
    try {
      final results = await _searchLocationOptions(trimmedQuery);
      if (!mounted || requestId != _workLocationSearchRequest) return;
      setState(() {
        _workLocationSuggestions = results;
        _workLocationSearching = false;
      });
    } catch (_) {
      if (!mounted || requestId != _workLocationSearchRequest) return;
      setState(() {
        _workLocationSearching = false;
        _workLocationSuggestions = <Map<String, dynamic>>[];
      });
    }
  }

  void _selectWorkLocation(Map<String, dynamic> location) {
    final label = _locationLabel(location);
    setState(() {
      _selectedWorkLocationLabel = label;
      _workLocationController.text = label;
      _workLocationSuggestions = <Map<String, dynamic>>[];
      _workLocationSearching = false;
    });
    FocusScope.of(context).unfocus();
  }

  bool _addressRowsContain(_AddressEditRow row) {
    return _selfAddressRows.contains(row) || _parentsAddressRows.contains(row);
  }

  void _scheduleAddressLocationSearch(_AddressEditRow row, String query) {
    if (!_addressRowsContain(row)) return;

    _addressLocationSearchDebounce?.cancel();
    final requestId = ++_addressLocationSearchRequest;
    final trimmedQuery = query.trim();

    setState(() {
      if (row.selectedLocationLabel == null ||
          trimmedQuery != row.selectedLocationLabel) {
        row.locationId = null;
        row.selectedLocationLabel = null;
        if (_currentSelfAddressRow() == row) {
          _syncCurrentAddressFromSelfRows();
        }
      }
      if (trimmedQuery.length < 2) {
        row.locationSearching = false;
        row.locationSuggestions = <Map<String, dynamic>>[];
      } else {
        row.locationSearching = true;
      }
    });

    if (trimmedQuery.length < 2) {
      return;
    }

    _addressLocationSearchDebounce = Timer(
      _locationSearchDebounceDuration,
      () => _runAddressLocationSearch(row, trimmedQuery, requestId),
    );
  }

  Future<void> _runAddressLocationSearch(
    _AddressEditRow row,
    String trimmedQuery,
    int requestId,
  ) async {
    try {
      final results = await _searchLocationOptions(trimmedQuery);
      if (!mounted ||
          requestId != _addressLocationSearchRequest ||
          !_addressRowsContain(row)) {
        return;
      }
      setState(() {
        row.locationSuggestions = results;
        row.locationSearching = false;
      });
    } catch (_) {
      if (!mounted ||
          requestId != _addressLocationSearchRequest ||
          !_addressRowsContain(row)) {
        return;
      }
      setState(() {
        row.locationSearching = false;
        row.locationSuggestions = <Map<String, dynamic>>[];
      });
    }
  }

  void _selectAddressLocation(
    _AddressEditRow row,
    Map<String, dynamic> location,
  ) {
    if (!_addressRowsContain(row)) return;

    final locationId = ApiClient.locationIdFrom(location);
    if (locationId == null) return;

    final label = _locationLabel(location);
    setState(() {
      row.locationId = locationId;
      row.selectedLocationLabel = label;
      row.locationController.text = label;
      row.locationSuggestions = <Map<String, dynamic>>[];
      row.locationSearching = false;
      if (_currentSelfAddressRow() == row) {
        _preferredStateId = _locationStateId(location) ?? _preferredStateId;
        _syncCurrentAddressFromSelfRows();
      }
    });
    FocusScope.of(context).unfocus();
  }

  void _scheduleAllianceLocationSearch(
    _AllianceNetworkEditRow row,
    String query,
  ) {
    _allianceLocationSearchDebounce?.cancel();
    final requestId = ++_allianceLocationSearchRequest;
    final trimmedQuery = query.trim();

    setState(() {
      if (row.selectedLocationLabel == null ||
          trimmedQuery != row.selectedLocationLabel) {
        row.cityId = null;
        row.stateId = null;
        row.districtId = null;
        row.talukaId = null;
        row.selectedLocationLabel = null;
      }
      if (trimmedQuery.length < 2) {
        row.locationSearching = false;
        row.locationSuggestions = <Map<String, dynamic>>[];
      } else {
        row.locationSearching = true;
      }
    });

    if (trimmedQuery.length < 2) {
      return;
    }

    _allianceLocationSearchDebounce = Timer(
      _locationSearchDebounceDuration,
      () => _runAllianceLocationSearch(row, trimmedQuery, requestId),
    );
  }

  Future<void> _runAllianceLocationSearch(
    _AllianceNetworkEditRow row,
    String trimmedQuery,
    int requestId,
  ) async {
    try {
      final results = await _searchLocationOptions(trimmedQuery);
      if (!mounted ||
          requestId != _allianceLocationSearchRequest ||
          !_allianceNetworkRows.contains(row)) {
        return;
      }
      setState(() {
        row.locationSuggestions = results;
        row.locationSearching = false;
      });
    } catch (_) {
      if (!mounted ||
          requestId != _allianceLocationSearchRequest ||
          !_allianceNetworkRows.contains(row)) {
        return;
      }
      setState(() {
        row.locationSearching = false;
        row.locationSuggestions = <Map<String, dynamic>>[];
      });
    }
  }

  void _selectAllianceLocation(
    _AllianceNetworkEditRow row,
    Map<String, dynamic> location,
  ) {
    if (!_allianceNetworkRows.contains(row)) return;

    final locationId = ApiClient.locationIdFrom(location);
    if (locationId == null) return;

    final label = _locationLabel(location);
    setState(() {
      row.cityId = locationId;
      row.stateId = _locationStateId(location);
      row.districtId = _locationDistrictId(location);
      row.talukaId = _locationTalukaId(location);
      row.selectedLocationLabel = label;
      row.locationController.text = label;
      row.locationSuggestions = <Map<String, dynamic>>[];
      row.locationSearching = false;
    });
    FocusScope.of(context).unfocus();
  }

  TimeOfDay _initialBirthTime() {
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})',
    ).firstMatch(_birthTimeController.text.trim());
    if (match == null) return TimeOfDay.now();

    final hour = int.tryParse(match.group(1) ?? '');
    final minute = int.tryParse(match.group(2) ?? '');
    if (hour == null || minute == null) return TimeOfDay.now();
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return TimeOfDay.now();
    }

    return TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> _pickBirthTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _initialBirthTime(),
    );
    if (pickedTime == null) return;
    if (!mounted) return;

    setState(() {
      _birthTimeController.text =
          '${pickedTime.hour.toString().padLeft(2, '0')}:'
          '${pickedTime.minute.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _pickDob() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_dobController.text) ?? DateTime(1995),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (pickedDate == null) return;
    if (!mounted) return;

    setState(() {
      _dobController.text =
          '${pickedDate.year.toString().padLeft(4, '0')}-'
          '${pickedDate.month.toString().padLeft(2, '0')}-'
          '${pickedDate.day.toString().padLeft(2, '0')}';
    });
  }

  Future<int?> _pickNumber({
    required String title,
    required List<int> values,
    required int? selected,
    required String Function(int value) labelBuilder,
  }) {
    return showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.62,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            Navigator.pop(sheetContext, _clearNumberSelection),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: values.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final value = values[index];
                      final isSelected = value == selected;
                      return ListTile(
                        title: Text(labelBuilder(value)),
                        trailing: isSelected
                            ? const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              )
                            : null,
                        onTap: () => Navigator.pop(sheetContext, value),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _heightLabel(int cm) {
    if (cm == 136) return 'Below 4\' 6" (136 cm)';
    if (cm == 214) return 'Above 7\' 0" (214 cm)';

    final totalInches = (cm / 2.54).round();
    final feet = totalInches ~/ 12;
    final inches = totalInches % 12;
    return '$feet\' $inches" ($cm cm)';
  }

  String _compactHeightLabel(int cm) => _heightLabel(cm).split(' (').first;

  String _weightLabel(int kg) => '$kg kg';

  List<int> _heightValues() {
    return <int>[
      136,
      ...List<int>.generate(31, (index) => ((54 + index) * 2.54).round()),
      214,
    ];
  }

  List<int> _weightValues() => List<int>.generate(231, (index) => 20 + index);

  String? _labelForId(
    List<Map<String, dynamic>> options,
    int? selectedId,
    String fallback,
  ) {
    if (selectedId == null) return null;
    for (final option in options) {
      if (_readInt(option['id']) == selectedId) {
        return _optionLabel(option, fallback);
      }
    }
    return null;
  }

  int? _defaultCurrencyId() {
    if (_incomeCurrencyOptions.isEmpty) return null;

    for (final option in _incomeCurrencyOptions) {
      final code = _readText(option['code'])?.toUpperCase();
      final symbol = _readText(option['symbol']);
      final label = _optionLabel(option, 'Currency').toUpperCase();
      if (code == 'INR' || symbol == '₹' || label.contains('INR')) {
        return _readInt(option['id']);
      }
    }

    return _readInt(_incomeCurrencyOptions.first['id']);
  }

  void _ensureDefaultCurrencySelections() {
    final defaultCurrencyId = _defaultCurrencyId();
    if (defaultCurrencyId == null) return;

    _selectedIncomeCurrencyId ??= defaultCurrencyId;
    _selectedFamilyIncomeCurrencyId ??= _selectedIncomeCurrencyId;
  }

  String _currencyLabel(int? currencyId) {
    for (final option in _incomeCurrencyOptions) {
      if (_readInt(option['id']) != currencyId) continue;

      return _readText(option['symbol']) ??
          _readText(option['code']) ??
          _optionLabel(option, 'Currency');
    }

    return '₹';
  }

  bool _incomeHasSavedValue({
    required String? valueType,
    required String amountText,
    required String minAmountText,
    required String maxAmountText,
    required bool private,
  }) {
    final hasAmount =
        amountText.trim().isNotEmpty ||
        minAmountText.trim().isNotEmpty ||
        maxAmountText.trim().isNotEmpty;
    return hasAmount || valueType == 'undisclosed' || private;
  }

  String? _labelForValue(
    List<Map<String, dynamic>> options,
    String? selectedValue,
    String fallback,
  ) {
    final normalizedValue = selectedValue?.trim().toLowerCase();
    if (normalizedValue == null || normalizedValue.isEmpty) return null;

    for (final option in options) {
      final value = _optionStoredValue(option)?.trim().toLowerCase();
      if (value == normalizedValue) {
        return _optionLabel(option, fallback);
      }
    }

    return selectedValue;
  }

  List<int> _orderedSelectedIds(
    List<Map<String, dynamic>> options,
    Set<int> selectedIds,
  ) {
    if (selectedIds.isEmpty) return <int>[];

    final ordered = <int>[];
    for (final option in options) {
      final id = _readInt(option['id']);
      if (id != null && selectedIds.contains(id)) {
        ordered.add(id);
      }
    }
    for (final id in selectedIds) {
      if (!ordered.contains(id)) {
        ordered.add(id);
      }
    }

    return ordered;
  }

  String? _labelsForIds(
    List<Map<String, dynamic>> options,
    Set<int> selectedIds,
    String fallback,
  ) {
    if (selectedIds.isEmpty) return null;

    final labels = _orderedSelectedIds(options, selectedIds)
        .map((id) => _labelForId(options, id, fallback))
        .whereType<String>()
        .toList();
    if (labels.isEmpty) return null;

    final visible = labels.take(3).join(', ');
    final remaining = labels.length - 3;
    return remaining > 0 ? '$visible +$remaining' : visible;
  }

  int? _religionIdForCaste(Map<String, dynamic> row) {
    return _readInt(row['religion_id']) ??
        _readInt(row['master_religion_id']) ??
        _readInt(row['religionId']);
  }

  List<Map<String, dynamic>> _preferredCasteOptionsForSelectedReligions() {
    if (_selectedPreferredReligionIds.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    return _preferredCasteOptions
        .where((row) {
          final religionId = _religionIdForCaste(row);
          return religionId != null &&
              _selectedPreferredReligionIds.contains(religionId);
        })
        .toList(growable: false);
  }

  bool _isPreferredCasteAllowed(int casteId) {
    return _preferredCasteOptionsForSelectedReligions().any(
      (row) => _readInt(row['id']) == casteId,
    );
  }

  void _removeInvalidPreferredCastes() {
    if (_selectedPreferredCasteIds.isEmpty) return;
    _selectedPreferredCasteIds.removeWhere(
      (casteId) => !_isPreferredCasteAllowed(casteId),
    );
  }

  List<Map<String, dynamic>> _horoscopeRuleRows(String key) {
    return _readRows(_horoscopeRules[key]);
  }

  List<int> _horoscopeIdList(String groupKey, int? id) {
    if (id == null) return <int>[];

    final group = _readMap(_horoscopeRules[groupKey]);
    return _readIntList(group[id.toString()]);
  }

  Map<String, dynamic>? _nakshatraAttributesFor(int? nakshatraId) {
    if (nakshatraId == null) return null;

    for (final row in _horoscopeRuleRows('nakshatra_attributes')) {
      if (_readInt(row['nakshatra_id']) == nakshatraId) {
        return row;
      }
    }

    return null;
  }

  Map<String, dynamic>? _rashiRuleFor({
    required int? nakshatraId,
    int? charan,
    int? rashiId,
  }) {
    if (nakshatraId == null) return null;

    for (final row in _horoscopeRuleRows('rashi_rules')) {
      if (_readInt(row['nakshatra_id']) != nakshatraId) continue;
      if (charan != null && _readInt(row['charan']) != charan) continue;
      if (rashiId != null && _readInt(row['rashi_id']) != rashiId) continue;

      return row;
    }

    return null;
  }

  Map<String, dynamic> _rashiAshtakootaFor(int? rashiId) {
    if (rashiId == null) return <String, dynamic>{};

    return _readMap(_rashiAshtakoota[rashiId.toString()]);
  }

  List<Map<String, dynamic>> _optionsMatchingIds(
    List<Map<String, dynamic>> options,
    List<int> allowedIds,
  ) {
    if (allowedIds.isEmpty) return options;
    final allowed = allowedIds.toSet();

    return options.where((option) {
      final id = _readInt(option['id']);
      return id != null && allowed.contains(id);
    }).toList();
  }

  List<int> _validCharansForSelection() {
    if (_selectedNakshatraId == null || _selectedRashiId == null) {
      return const [1, 2, 3, 4];
    }

    final charans = _horoscopeRuleRows('rashi_rules')
        .where((row) {
          return _readInt(row['nakshatra_id']) == _selectedNakshatraId &&
              _readInt(row['rashi_id']) == _selectedRashiId;
        })
        .map((row) => _readInt(row['charan']))
        .whereType<int>()
        .toSet()
        .toList();
    charans.sort();

    return charans.isEmpty ? const [1, 2, 3, 4] : charans;
  }

  List<Map<String, dynamic>> _rashiOptionsForSelection() {
    return _optionsMatchingIds(
      _rashiOptions,
      _horoscopeIdList('distinct_rashi_ids_by_nakshatra', _selectedNakshatraId),
    );
  }

  List<Map<String, dynamic>> _nakshatraOptionsForSelection() {
    return _optionsMatchingIds(
      _nakshatraOptions,
      _horoscopeIdList('nakshatra_ids_by_rashi', _selectedRashiId),
    );
  }

  List<Map<String, dynamic>> _yoniOptionsForSelection() {
    final attrs = _nakshatraAttributesFor(_selectedNakshatraId);
    final yoniId = _readInt(attrs?['yoni_id']);

    return _optionsMatchingIds(
      _yoniOptions,
      yoniId == null ? <int>[] : [yoniId],
    );
  }

  void _applyRashiAshtakootaSelection() {
    final details = _rashiAshtakootaFor(_selectedRashiId);
    _selectedVarnaId = _readInt(details['varna_id']);
    _selectedVashyaId = _readInt(details['vashya_id']);
    _selectedRashiLordId = _readInt(details['rashi_lord_id']);
  }

  void _applyHoroscopeDependencies() {
    final selectedNakshatra = _selectedNakshatraId;
    final selectedCharan = _selectedCharan;

    if (selectedNakshatra != null) {
      final attrs = _nakshatraAttributesFor(selectedNakshatra);
      if (attrs != null) {
        final ganId = _readInt(attrs['gan_id']);
        final nadiId = _readInt(attrs['nadi_id']);
        final yoniId = _readInt(attrs['yoni_id']);
        _selectedGanId ??= ganId;
        _selectedNadiId ??= nadiId;
        if (yoniId != null &&
            _selectedYoniId != null &&
            _selectedYoniId != yoniId) {
          _selectedYoniId = null;
        }
        _selectedYoniId ??= yoniId;
      }

      if (selectedCharan != null &&
          selectedCharan >= 1 &&
          selectedCharan <= 4) {
        final rule = _rashiRuleFor(
          nakshatraId: selectedNakshatra,
          charan: selectedCharan,
        );
        if (rule != null && _selectedRashiId == null) {
          _selectedRashiId = _readInt(rule['rashi_id']);
        }
      }

      final allowedRashiIds = _horoscopeIdList(
        'distinct_rashi_ids_by_nakshatra',
        selectedNakshatra,
      );
      final selectedRashi = _selectedRashiId;
      if (allowedRashiIds.isNotEmpty &&
          selectedRashi != null &&
          !allowedRashiIds.contains(selectedRashi)) {
        _selectedRashiId = allowedRashiIds.first;
      }

      final validCharans = _validCharansForSelection();
      final selectedCharanNow = _selectedCharan;
      if (selectedCharanNow != null &&
          validCharans.isNotEmpty &&
          !validCharans.contains(selectedCharanNow)) {
        _selectedCharan = validCharans.first;
      }
    } else {
      _selectedGanId = null;
      _selectedNadiId = null;
      _selectedYoniId = null;
    }

    if (_selectedRashiId != null) {
      final allowedNakshatraIds = _horoscopeIdList(
        'nakshatra_ids_by_rashi',
        _selectedRashiId,
      );
      final selectedNakshatraNow = _selectedNakshatraId;
      if (allowedNakshatraIds.isNotEmpty &&
          selectedNakshatraNow != null &&
          !allowedNakshatraIds.contains(selectedNakshatraNow)) {
        _selectedNakshatraId = null;
        _selectedCharan = null;
        _selectedGanId = null;
        _selectedNadiId = null;
        _selectedYoniId = null;
      }
    }

    _applyRashiAshtakootaSelection();
  }

  void _selectRashi(int? value) {
    setState(() {
      _selectedRashiId = value;
      _applyHoroscopeDependencies();
    });
  }

  void _selectNakshatra(int? value) {
    setState(() {
      _selectedNakshatraId = value;
      if (value == null) {
        _selectedCharan = null;
      }
      _applyHoroscopeDependencies();
    });
  }

  void _selectCharan(int? value) {
    setState(() {
      _selectedCharan = value;
      _applyHoroscopeDependencies();
    });
  }

  bool _validateRequiredFields() {
    if (_fullNameController.text.trim().isEmpty) {
      _showMessage('कृपया full name भरा.');
      return false;
    }
    if (_selectedGenderId == null) {
      _showMessage(AppStrings.selectProfileType);
      return false;
    }
    if (_dobController.text.trim().isEmpty) {
      _showMessage('कृपया date of birth निवडा.');
      return false;
    }
    if (_selectedReligionId == null) {
      _showMessage('कृपया suggestions मधून religion निवडा.');
      return false;
    }
    if (_selectedCasteId == null) {
      _showMessage('कृपया suggestions मधून caste निवडा.');
      return false;
    }
    if (_educationController.text.trim().isEmpty) {
      _showMessage('कृपया education भरा.');
      return false;
    }
    final currentAddressLocationId =
        _currentSelfAddressRow()?.locationId ?? _selectedLocationId;
    if (currentAddressLocationId == null) {
      _showMessage('कृपया suggestions मधून location निवडा.');
      return false;
    }
    return true;
  }

  bool _validatePreferenceRanges() {
    final ageMin = _selectedPreferredAgeMin;
    final ageMax = _selectedPreferredAgeMax;
    if (ageMin != null && ageMax != null && ageMin > ageMax) {
      _showMessage('Preferred age range चुकीची आहे.');
      return false;
    }

    final heightMin = _selectedPreferredHeightMinCm;
    final heightMax = _selectedPreferredHeightMaxCm;
    if (heightMin != null && heightMax != null && heightMin > heightMax) {
      _showMessage('Preferred height range चुकीची आहे.');
      return false;
    }

    final incomeMin = _selectedPreferredIncomeMin;
    final incomeMax = _selectedPreferredIncomeMax;
    if (incomeMin != null && incomeMax != null && incomeMin > incomeMax) {
      _showMessage('Preferred income range चुकीची आहे.');
      return false;
    }

    return true;
  }

  bool _validateIncomeFields() {
    bool validateOne({
      required String title,
      required bool enabled,
      required String? valueType,
      required TextEditingController amountController,
      required TextEditingController minAmountController,
      required TextEditingController maxAmountController,
    }) {
      if (!enabled) return true;

      final effectiveValueType = valueType ?? 'approximate';
      if (effectiveValueType == 'exact' ||
          effectiveValueType == 'approximate') {
        if (_nullableNumber(amountController) == null) {
          _showMessage('$title amount भरा.');
          return false;
        }
      }
      if (effectiveValueType == 'range') {
        final minAmount = _nullableNumber(minAmountController);
        final maxAmount = _nullableNumber(maxAmountController);
        if (minAmount == null || maxAmount == null) {
          _showMessage('$title range amount भरा.');
          return false;
        }
        if (minAmount > maxAmount) {
          _showMessage('$title range चुकीची आहे.');
          return false;
        }
      }

      return true;
    }

    return validateOne(
          title: 'Personal income',
          enabled: _showIncomeGroup,
          valueType: _selectedIncomeValueType,
          amountController: _incomeAmountController,
          minAmountController: _incomeMinAmountController,
          maxAmountController: _incomeMaxAmountController,
        ) &&
        validateOne(
          title: 'Family income',
          enabled: _showFamilyIncomeGroup,
          valueType: _selectedFamilyIncomeValueType,
          amountController: _familyIncomeAmountController,
          minAmountController: _familyIncomeMinAmountController,
          maxAmountController: _familyIncomeMaxAmountController,
        );
  }

  String? _nullableText(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
  }

  bool _incomeHasPayload({
    required bool enabled,
    required String? valueType,
    required TextEditingController amountController,
    required TextEditingController minAmountController,
    required TextEditingController maxAmountController,
    required bool private,
  }) {
    if (!enabled) return false;

    return valueType != null ||
        amountController.text.trim().isNotEmpty ||
        minAmountController.text.trim().isNotEmpty ||
        maxAmountController.text.trim().isNotEmpty ||
        private;
  }

  Map<String, dynamic> _incomePayload({
    required String prefix,
    required bool enabled,
    required String? period,
    required String? valueType,
    required TextEditingController amountController,
    required TextEditingController minAmountController,
    required TextEditingController maxAmountController,
    required int? currencyId,
    required bool private,
  }) {
    if (!_incomeHasPayload(
      enabled: enabled,
      valueType: valueType,
      amountController: amountController,
      minAmountController: minAmountController,
      maxAmountController: maxAmountController,
      private: private,
    )) {
      return const <String, dynamic>{};
    }

    final amount = _nullableNumber(amountController);
    final minAmount = _nullableNumber(minAmountController);
    final maxAmount = _nullableNumber(maxAmountController);
    final effectivePeriod = period ?? 'annual';
    final effectiveValueType = valueType ?? 'approximate';
    final singleAmount =
        effectiveValueType == 'exact' || effectiveValueType == 'approximate'
        ? amount
        : null;

    return <String, dynamic>{
      if (prefix == 'income') 'annual_income': singleAmount,
      if (prefix == 'family_income') 'family_income': singleAmount,
      '${prefix}_period': effectivePeriod,
      '${prefix}_value_type': effectiveValueType,
      '${prefix}_amount': singleAmount,
      '${prefix}_min_amount': effectiveValueType == 'range' ? minAmount : null,
      '${prefix}_max_amount': effectiveValueType == 'range' ? maxAmount : null,
      '${prefix}_currency_id': currencyId,
      '${prefix}_private': private,
    };
  }

  List<Map<String, dynamic>> _siblingsPayload() {
    if (_selectedHasSiblings == false) return const <Map<String, dynamic>>[];

    final rows = <Map<String, dynamic>>[];
    for (var index = 0; index < _siblingRows.length; index++) {
      final row = _siblingRows[index];
      if (!row.hasData) continue;
      rows.add(row.toPayload(index));
    }

    return rows;
  }

  List<Map<String, dynamic>> _relativesPayload() {
    final rows = <Map<String, dynamic>>[];
    for (final row in _relativeRows) {
      if (!row.hasData) continue;
      rows.add(row.toPayload());
    }

    return rows;
  }

  List<Map<String, dynamic>> _allianceNetworksPayload() {
    final rows = <Map<String, dynamic>>[];
    for (final row in _allianceNetworkRows) {
      if (!row.hasData) continue;
      rows.add(row.toPayload());
    }

    return rows;
  }

  List<Map<String, dynamic>> _addressRowsPayload(
    List<_AddressEditRow> source,
    String defaultTypeKey,
  ) {
    final rows = <Map<String, dynamic>>[];
    for (final row in source) {
      if (!row.hasData) continue;
      rows.add(row.toPayload(defaultTypeKey));
    }

    return rows;
  }

  List<Map<String, dynamic>> _marriagesPayload() {
    final statusKey = _currentMaritalStatusKey();
    if (!_maritalStatusShowsDetails(statusKey)) {
      return const <Map<String, dynamic>>[];
    }

    final row = _ensureMarriageDetailRow();
    return <Map<String, dynamic>>[
      row.toStatusPayload(statusKey, _selectedMaritalStatusId),
    ];
  }

  List<Map<String, dynamic>> _childrenPayload() {
    if (!_maritalStatusShowsDetails(_currentMaritalStatusKey()) ||
        _selectedHasChildren != true) {
      return const <Map<String, dynamic>>[];
    }

    final rows = <Map<String, dynamic>>[];
    for (var index = 0; index < _childRows.length; index++) {
      final row = _childRows[index];
      if (!row.hasData) continue;
      rows.add(row.toPayload(index));
    }

    return rows;
  }

  String? _maritalStatusKeyForId(int? id) {
    if (id == null) return null;
    for (final option in _maritalStatusOptions) {
      if (_readInt(option['id']) == id) {
        return _readText(option['key']);
      }
    }
    return id == _selectedMaritalStatusId ? _selectedMaritalStatusKey : null;
  }

  String? _currentMaritalStatusKey() {
    return _maritalStatusKeyForId(_selectedMaritalStatusId) ??
        _selectedMaritalStatusKey;
  }

  bool _maritalStatusShowsDetails(String? statusKey) {
    return const {
      'divorced',
      'annulled',
      'separated',
      'widowed',
    }.contains(statusKey);
  }

  _MarriageEditRow _ensureMarriageDetailRow() {
    if (_marriageRows.isEmpty) {
      _marriageRows.add(_MarriageEditRow());
    }
    return _marriageRows.first;
  }

  void _setMaritalStatus(int? value) {
    final changed = value != _selectedMaritalStatusId;
    _selectedMaritalStatusId = value;
    _selectedMaritalStatusKey = _maritalStatusKeyForId(value);

    if (changed) {
      _clearChildrenSelection();
    }
    if (_maritalStatusShowsDetails(_selectedMaritalStatusKey)) {
      _ensureMarriageDetailRow();
    }
  }

  void _setHasChildren(bool? value) {
    if (!_maritalStatusShowsDetails(_currentMaritalStatusKey())) {
      _clearChildrenSelection();
      return;
    }

    _selectedHasChildren = value;
    if (value == true) {
      if (_childRows.isEmpty) {
        _childRows.add(_ChildEditRow(sortOrder: 0));
      }
    }
  }

  Map<String, dynamic> _buildProfilePayload({
    bool includeSelfAddresses = false,
    bool includeParentsAddresses = false,
    bool includeParentContacts = false,
    bool includeSiblings = false,
    bool includeRelatives = false,
    bool includeAllianceNetworks = false,
    bool includeMarriageChildren = false,
    bool includePartnerPreferences = true,
  }) {
    final casteLabel = _selectedCasteLabel?.trim().isNotEmpty == true
        ? _selectedCasteLabel!.trim()
        : _casteController.text.trim();
    final educationText = _educationController.text.trim();
    final educationDegreeId =
        _selectedEducationDegreeId ??
        _findEducationDegreeIdByText(educationText);
    final statusKey = _currentMaritalStatusKey();
    final maritalChildrenEligible = _maritalStatusShowsDetails(statusKey);
    final currentAddress = _currentSelfAddressRow();
    final currentLocationId = currentAddress?.locationId ?? _selectedLocationId;
    final currentAddressLine = currentAddress == null
        ? _nullableText(_addressLineController)
        : _nullableText(currentAddress.addressLineController);

    final payload = <String, dynamic>{
      'full_name': _fullNameController.text.trim(),
      'gender_id': _selectedGenderId,
      'date_of_birth': _dobController.text.trim(),
      'religion_id': _selectedReligionId,
      'caste_id': _selectedCasteId,
      'caste': casteLabel,
      'highest_education': educationText,
      'location_id': currentLocationId,
      'address_line': currentAddressLine,
      'sub_caste_id': _selectedSubCasteId,
      'birth_time': _nullableText(_birthTimeController),
      'birth_city_id': _selectedBirthCityId,
      'birth_place_text': _nullableText(_birthPlaceController),
      'mother_tongue_id': _selectedMotherTongueId,
      'height_cm': _selectedHeightCm,
      'weight_kg': _selectedWeightKg,
      'complexion_id': _selectedComplexionId,
      'blood_group_id': _selectedBloodGroupId,
      'physical_build_id': _selectedPhysicalBuildId,
      'spectacles_lens': _selectedSpectaclesLens,
      'physical_condition': _selectedPhysicalCondition,
      'marital_status_id': _selectedMaritalStatusId,
      'has_children': maritalChildrenEligible ? _selectedHasChildren : false,
      'diet_id': _selectedDietId,
      'smoking_status_id': _selectedSmokingStatusId,
      'drinking_status_id': _selectedDrinkingStatusId,
      'occupation_master_id': _selectedOccupationMasterId,
      'occupation_custom_id': _selectedOccupationCustomId,
      'company_name': _nullableText(_companyNameController),
      'work_location_text': _nullableText(_workLocationController),
      ..._incomePayload(
        prefix: 'income',
        enabled: _showIncomeGroup,
        period: _selectedIncomePeriod,
        valueType: _selectedIncomeValueType,
        amountController: _incomeAmountController,
        minAmountController: _incomeMinAmountController,
        maxAmountController: _incomeMaxAmountController,
        currencyId: _selectedIncomeCurrencyId,
        private: _incomePrivate,
      ),
      'father_name': _nullableText(_fatherNameController),
      'father_occupation': _nullableText(_fatherOccupationController),
      'father_occupation_master_id': _selectedFatherOccupationMasterId,
      'father_occupation_custom_id': _selectedFatherOccupationCustomId,
      'father_extra_info': _nullableText(_fatherExtraInfoController),
      'mother_name': _nullableText(_motherNameController),
      'mother_occupation': _nullableText(_motherOccupationController),
      'mother_occupation_master_id': _selectedMotherOccupationMasterId,
      'mother_occupation_custom_id': _selectedMotherOccupationCustomId,
      'mother_extra_info': _nullableText(_motherExtraInfoController),
      'family_type_id': _selectedFamilyTypeId,
      'family_status': _selectedFamilyStatus,
      'family_values': _selectedFamilyValues,
      ..._incomePayload(
        prefix: 'family_income',
        enabled: _showFamilyIncomeGroup,
        period: _selectedFamilyIncomePeriod,
        valueType: _selectedFamilyIncomeValueType,
        amountController: _familyIncomeAmountController,
        minAmountController: _familyIncomeMinAmountController,
        maxAmountController: _familyIncomeMaxAmountController,
        currencyId: _selectedFamilyIncomeCurrencyId,
        private: _familyIncomePrivate,
      ),
      'has_siblings': _selectedHasSiblings,
      'other_relatives_text': _nullableText(_otherRelativesController),
      'property_details': _nullableText(_propertyDetailsController),
      'rashi_id': _selectedRashiId,
      'nakshatra_id': _selectedNakshatraId,
      'charan': _selectedCharan,
      'gan_id': _selectedGanId,
      'nadi_id': _selectedNadiId,
      'yoni_id': _selectedYoniId,
      'varna_id': _selectedVarnaId,
      'vashya_id': _selectedVashyaId,
      'rashi_lord_id': _selectedRashiLordId,
      'mangal_dosh_type_id': _selectedMangalDoshTypeId,
      'devak': _nullableText(_devakController),
      'kul': _nullableText(_kulController),
      'gotra': _nullableText(_gotraController),
      'navras_name': _nullableText(_navrasNameController),
      'birth_weekday': _selectedBirthWeekday,
      'narrative_about_me': _nullableText(_aboutMeController),
    };

    if (includePartnerPreferences) {
      payload.addAll({
        'preferred_age_min': _selectedPreferredAgeMin,
        'preferred_age_max': _selectedPreferredAgeMax,
        'preferred_height_min_cm': _selectedPreferredHeightMinCm,
        'preferred_height_max_cm': _selectedPreferredHeightMaxCm,
        'preferred_income_min': _selectedPreferredIncomeMin,
        'preferred_income_max': _selectedPreferredIncomeMax,
        'marriage_type_preference_id': _selectedMarriageTypePreferenceId,
        'partner_profile_with_children': _selectedPartnerProfileWithChildren,
        'preferred_profile_managed_by': _selectedPreferredProfileManagedBy,
        'willing_to_relocate': _selectedWillingToRelocate,
        'preferred_intercaste': _selectedPreferredIntercaste,
        'preferred_marital_status_ids': _orderedSelectedIds(
          _preferredMaritalStatusOptions,
          _selectedPreferredMaritalStatusIds,
        ),
        'preferred_diet_ids': _orderedSelectedIds(
          _preferredDietOptions,
          _selectedPreferredDietIds,
        ),
        'preferred_religion_ids': _orderedSelectedIds(
          _preferredReligionOptions,
          _selectedPreferredReligionIds,
        ),
        'preferred_caste_ids': _orderedSelectedIds(
          _preferredCasteOptionsForSelectedReligions(),
          _selectedPreferredCasteIds,
        ),
        'preferred_mother_tongue_ids': _orderedSelectedIds(
          _preferredMotherTongueOptions,
          _selectedPreferredMotherTongueIds,
        ),
        'preferred_education_degree_ids': _orderedSelectedIds(
          _preferredEducationDegreeOptions,
          _selectedPreferredEducationDegreeIds,
        ),
        'preferred_occupation_master_ids': _orderedSelectedIds(
          _preferredOccupationOptions,
          _selectedPreferredOccupationMasterIds,
        ),
        'preferred_country_ids': _preferredLocationPayloadIds(
          'country_id',
          _selectedPreferredCountryIds,
        ),
        'preferred_state_ids': _preferredLocationPayloadIds(
          'state_id',
          _selectedPreferredStateIds,
        ),
        'preferred_district_ids': _preferredLocationPayloadIds(
          'district_id',
          _selectedPreferredDistrictIds,
        ),
        'preferred_taluka_ids': _preferredLocationPayloadIds(
          'id',
          _selectedPreferredTalukaIds,
        ),
        'narrative_expectations': _nullableText(_expectationsController),
      });
    }

    if (includeParentContacts) {
      payload['father_contact_1'] = _nullableText(_fatherContact1Controller);
      payload['mother_contact_1'] = _nullableText(_motherContact1Controller);
      if (_shouldSendOptionalParentContact(
        _fatherContact2Controller,
        _showFatherContact2,
        _fatherContact2Removed,
      )) {
        payload['father_contact_2'] = _nullableText(_fatherContact2Controller);
      }
      if (_supportsParentContact3 &&
          _shouldSendOptionalParentContact(
            _fatherContact3Controller,
            _showFatherContact3,
            _fatherContact3Removed,
          )) {
        payload['father_contact_3'] = _nullableText(_fatherContact3Controller);
      }
      if (_shouldSendOptionalParentContact(
        _motherContact2Controller,
        _showMotherContact2,
        _motherContact2Removed,
      )) {
        payload['mother_contact_2'] = _nullableText(_motherContact2Controller);
      }
      if (_supportsParentContact3 &&
          _shouldSendOptionalParentContact(
            _motherContact3Controller,
            _showMotherContact3,
            _motherContact3Removed,
          )) {
        payload['mother_contact_3'] = _nullableText(_motherContact3Controller);
      }
    }

    if (includeSelfAddresses) {
      payload['self_addresses'] = _addressRowsPayload(
        _selfAddressRows,
        'current',
      );
    }

    if (includeParentsAddresses) {
      payload['parents_addresses'] = _addressRowsPayload(
        _parentsAddressRows,
        'permanent',
      );
    }

    if (includeSiblings) {
      payload['siblings'] = _siblingsPayload();
    }

    if (includeRelatives) {
      payload['relatives'] = _relativesPayload();
    }

    if (includeAllianceNetworks) {
      payload['alliance_networks'] = _allianceNetworksPayload();
    }

    if (includeMarriageChildren) {
      payload['marriages'] = _marriagesPayload();
      payload['children'] = _childrenPayload();
    }

    if (educationDegreeId != null) {
      payload['education_slots'] = jsonEncode([
        {'t': 'd', 'id': educationDegreeId},
      ]);
    }

    return payload;
  }

  Future<bool> _saveProfile({
    bool navigateOnSuccess = true,
    String successMessage = 'Profile update यशस्वी!',
    _EditProfileSection? section,
  }) async {
    final includePartnerPreferences =
        section == null || section == _EditProfileSection.partnerPreferences;
    if (!_validateRequiredFields()) return false;
    if (includePartnerPreferences && !_validatePreferenceRanges()) {
      return false;
    }
    if (!_validateIncomeFields()) return false;

    setState(() {
      _saving = true;
    });

    final payload = _buildProfilePayload(
      includeSelfAddresses: section == _EditProfileSection.basic,
      includeParentsAddresses: section == _EditProfileSection.familyDetails,
      includeParentContacts: section == _EditProfileSection.familyDetails,
      includeSiblings: section == _EditProfileSection.siblings,
      includeRelatives: section == _EditProfileSection.relatives,
      includeAllianceNetworks: section == _EditProfileSection.relatives,
      includeMarriageChildren: section == _EditProfileSection.basic,
      includePartnerPreferences: includePartnerPreferences,
    );
    Map<String, dynamic> response;
    try {
      response = await ApiClient.updateMatrimonyProfile(payload);
    } catch (_) {
      if (!mounted) return false;
      setState(() {
        _saving = false;
      });
      _showMessage('Profile save करता आली नाही. कृपया पुन्हा प्रयत्न करा.');
      return false;
    }

    if (!mounted) return false;
    setState(() {
      _saving = false;
    });

    if (response['success'] == true) {
      try {
        final refreshed = await ApiClient.getMyProfile();
        final profile = refreshed['profile'];
        if (profile is Map && mounted) {
          setState(() {
            _prefillProfile(Map<String, dynamic>.from(profile));
          });
        }
      } catch (_) {
        // Save already succeeded; the destination screen also performs a reload.
      }
      if (!mounted) return false;
      _showMessage(successMessage);
      if (navigateOnSuccess) {
        Navigator.pushReplacementNamed(context, '/view-profile');
      }
      return true;
    } else {
      _showMessage(response['message']?.toString() ?? 'Profile save failed');
      return false;
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  List<_EditProfileSection> get _profileSections => const [
    _EditProfileSection.basic,
    _EditProfileSection.physical,
    _EditProfileSection.educationCareer,
    _EditProfileSection.familyDetails,
    _EditProfileSection.siblings,
    _EditProfileSection.relatives,
    _EditProfileSection.property,
    _EditProfileSection.horoscope,
    _EditProfileSection.aboutMe,
    _EditProfileSection.partnerPreferences,
    _EditProfileSection.photo,
  ];

  String _sectionTitle(_EditProfileSection section) {
    switch (section) {
      case _EditProfileSection.basic:
        return 'Basic Information';
      case _EditProfileSection.physical:
        return 'Physical';
      case _EditProfileSection.educationCareer:
        return 'Education & Career';
      case _EditProfileSection.familyDetails:
        return 'Family Details';
      case _EditProfileSection.siblings:
        return 'Siblings';
      case _EditProfileSection.relatives:
        return 'Relatives';
      case _EditProfileSection.property:
        return 'Property';
      case _EditProfileSection.horoscope:
        return 'Horoscope';
      case _EditProfileSection.aboutMe:
        return 'About Me';
      case _EditProfileSection.partnerPreferences:
        return 'Partner Preferences';
      case _EditProfileSection.photo:
        return 'Photo';
    }
  }

  IconData _sectionIcon(_EditProfileSection section) {
    switch (section) {
      case _EditProfileSection.basic:
        return Icons.badge_outlined;
      case _EditProfileSection.physical:
        return Icons.accessibility_new_outlined;
      case _EditProfileSection.educationCareer:
        return Icons.school_outlined;
      case _EditProfileSection.familyDetails:
        return Icons.group_outlined;
      case _EditProfileSection.siblings:
        return Icons.people_alt_outlined;
      case _EditProfileSection.relatives:
        return Icons.people_outline;
      case _EditProfileSection.property:
        return Icons.real_estate_agent_outlined;
      case _EditProfileSection.horoscope:
        return Icons.star_border;
      case _EditProfileSection.aboutMe:
        return Icons.notes;
      case _EditProfileSection.partnerPreferences:
        return Icons.tune_outlined;
      case _EditProfileSection.photo:
        return Icons.photo_camera_outlined;
    }
  }

  String? _summaryText(String? value, {int maxLength = 72}) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return null;
    if (text.toLowerCase().startsWith('location id:')) return null;

    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 1).trimRight()}…';
  }

  String? _joinSummaryParts(
    List<String?> parts, {
    String separator = ' / ',
    int maxLength = 90,
  }) {
    final cleaned = parts
        .map((value) => _summaryText(value, maxLength: maxLength))
        .whereType<String>()
        .toList();
    if (cleaned.isEmpty) return null;

    return _summaryText(cleaned.join(separator), maxLength: maxLength);
  }

  String _summaryFromParts(List<String?> parts) {
    final cleaned = parts
        .map((value) => _summaryText(value))
        .whereType<String>()
        .toList();
    if (cleaned.isEmpty) return 'Not added yet';

    return cleaned.take(4).join(' • ');
  }

  String? _controllerSummary(TextEditingController controller) {
    return _summaryText(controller.text);
  }

  String _addressTypeLabel(String? key) {
    for (final row in _addressTypeOptions) {
      if (row['key'] == key) return row['label'] ?? key ?? 'Address';
    }
    final text = key?.trim();
    if (text == null || text.isEmpty) return 'Address';
    return text[0].toUpperCase() + text.substring(1);
  }

  String? _addressRowsSummary(List<_AddressEditRow> rows) {
    final filledRows = rows.where((row) => row.hasData).toList();
    if (filledRows.isEmpty) return null;

    final first = filledRows.first;
    final firstLabel = _joinSummaryParts([
      _addressTypeLabel(first.addressTypeKey),
      first.selectedLocationLabel,
      first.addressLineController.text,
    ], separator: ', ');
    if (filledRows.length == 1) return firstLabel;

    return _joinSummaryParts([
      '${filledRows.length} address${filledRows.length == 1 ? '' : 'es'}',
      firstLabel,
    ]);
  }

  String? _ageSummary() {
    final dob = DateTime.tryParse(_dobController.text.trim());
    if (dob == null) return null;

    final today = DateTime.now();
    var years = today.year - dob.year;
    if (today.month < dob.month ||
        (today.month == dob.month && today.day < dob.day)) {
      years--;
    }
    if (years <= 0) return null;

    return '$years years';
  }

  String? _boolSummary(bool? value) {
    if (value == null) return null;
    return value ? 'Yes' : 'No';
  }

  String? _preferenceAgeSummary() {
    final min = _selectedPreferredAgeMin;
    final max = _selectedPreferredAgeMax;
    if (min == null && max == null) return null;
    if (min != null && max != null) return 'Age $min-$max';
    if (min != null) return 'Age $min+';
    return 'Age up to $max';
  }

  String? _preferenceHeightSummary() {
    final min = _selectedPreferredHeightMinCm;
    final max = _selectedPreferredHeightMaxCm;
    if (min == null && max == null) return null;
    if (min != null && max != null) {
      return 'Height ${_heightLabel(min).split(' (').first}-'
          '${_heightLabel(max).split(' (').first}';
    }
    if (min != null) return 'Height ${_heightLabel(min).split(' (').first}+';
    return 'Height up to ${_heightLabel(max!).split(' (').first}';
  }

  String _incomeLabel(int value) {
    if (value <= 0) return '₹0';
    if (value >= 10000000 && value % 10000000 == 0) {
      final crore = value ~/ 10000000;
      return '₹${crore}Cr';
    }
    if (value >= 10000000) {
      return '₹${(value / 10000000).toStringAsFixed(1)}Cr';
    }
    if (value % 100000 == 0) {
      return '₹${value ~/ 100000}L';
    }
    return '₹${(value / 100000).toStringAsFixed(1)}L';
  }

  String? _editableIncomeSummary({
    required String? valueType,
    required TextEditingController amountController,
    required TextEditingController minAmountController,
    required TextEditingController maxAmountController,
    required bool private,
  }) {
    if (private) return 'Hidden';
    if (valueType == 'undisclosed') return 'Undisclosed';

    String amountLabel(TextEditingController controller) {
      final value = _nullableNumber(controller);
      if (value == null) return '';
      return _incomeLabel(value.round());
    }

    if (valueType == 'range') {
      final min = amountLabel(minAmountController);
      final max = amountLabel(maxAmountController);
      if (min.isEmpty && max.isEmpty) return null;
      if (min.isNotEmpty && max.isNotEmpty) return '$min-$max';
      return min.isNotEmpty ? '$min+' : 'Up to $max';
    }

    final amount = amountLabel(amountController);
    return amount.isEmpty ? null : amount;
  }

  String? _preferenceIncomeSummary() {
    final min = _selectedPreferredIncomeMin;
    final max = _selectedPreferredIncomeMax;
    if (min == null && max == null) return null;
    if (min != null && max != null) {
      return 'Income ${_incomeLabel(min)}-${_incomeLabel(max)}';
    }
    if (min != null) return 'Income ${_incomeLabel(min)}+';
    return 'Income up to ${_incomeLabel(max!)}';
  }

  String _sectionSummary(_EditProfileSection section) {
    switch (section) {
      case _EditProfileSection.basic:
        final statusKey = _currentMaritalStatusKey();
        final showMarriageChildren = _maritalStatusShowsDetails(statusKey);
        return _summaryFromParts([
          _controllerSummary(_fullNameController),
          _joinSummaryParts([
            _ageSummary(),
            _labelForId(_genders, _selectedGenderId, AppStrings.brideGroom),
          ], separator: ', '),
          _joinSummaryParts([
            _selectedReligionLabel ?? _controllerSummary(_religionController),
            _selectedCasteLabel ?? _controllerSummary(_casteController),
            _selectedSubCasteLabel ?? _controllerSummary(_subCasteController),
          ]),
          _addressRowsSummary(_selfAddressRows) ??
              _selectedLocationLabel ??
              _controllerSummary(_locationController),
          _controllerSummary(_birthPlaceController) ?? _selectedBirthPlaceLabel,
          _controllerSummary(_birthTimeController),
          _labelForId(
            _motherTongueOptions,
            _selectedMotherTongueId,
            'Mother tongue',
          ),
          _labelForId(
            _maritalStatusOptions,
            _selectedMaritalStatusId,
            'Marital status',
          ),
          showMarriageChildren
              ? _joinSummaryParts([
                  'Children',
                  _boolSummary(_selectedHasChildren),
                  _selectedHasChildren == true && _childRows.isNotEmpty
                      ? '${_childRows.length} child${_childRows.length == 1 ? '' : 'ren'}'
                      : null,
                ], separator: ': ')
              : null,
        ]);
      case _EditProfileSection.physical:
        return _summaryFromParts([
          _selectedHeightCm == null ? null : _heightLabel(_selectedHeightCm!),
          _selectedWeightKg == null ? null : _weightLabel(_selectedWeightKg!),
          _labelForId(_complexionOptions, _selectedComplexionId, 'Complexion'),
          _labelForId(_dietOptions, _selectedDietId, 'Diet'),
          _joinSummaryParts([
            _labelForId(
              _smokingStatusOptions,
              _selectedSmokingStatusId,
              'Smoking status',
            ),
            _labelForId(
              _drinkingStatusOptions,
              _selectedDrinkingStatusId,
              'Drinking status',
            ),
          ]),
        ]);
      case _EditProfileSection.educationCareer:
        return _summaryFromParts([
          _controllerSummary(_educationController),
          _selectedOccupationLabel ??
              _labelForId(
                _occupationOptions,
                _selectedOccupationMasterId,
                'Occupation',
              ),
          _controllerSummary(_workLocationController) ??
              _selectedWorkLocationLabel,
          _showIncomeGroup
              ? _editableIncomeSummary(
                  valueType: _selectedIncomeValueType,
                  amountController: _incomeAmountController,
                  minAmountController: _incomeMinAmountController,
                  maxAmountController: _incomeMaxAmountController,
                  private: _incomePrivate,
                )
              : null,
        ]);
      case _EditProfileSection.familyDetails:
        return _summaryFromParts([
          _joinSummaryParts([
            'Father',
            _controllerSummary(_fatherNameController),
            _selectedFatherOccupationLabel,
          ], separator: ': '),
          _joinSummaryParts([
            'Mother',
            _controllerSummary(_motherNameController),
            _selectedMotherOccupationLabel,
          ], separator: ': '),
          _addressRowsSummary(_parentsAddressRows),
          _labelForId(_familyTypeOptions, _selectedFamilyTypeId, 'Family type'),
          _labelForValue(
            _familyStatusOptions,
            _selectedFamilyStatus,
            'Family status',
          ),
          _labelForValue(
            _familyValueOptions,
            _selectedFamilyValues,
            'Family values',
          ),
          _showFamilyIncomeGroup
              ? _editableIncomeSummary(
                  valueType: _selectedFamilyIncomeValueType,
                  amountController: _familyIncomeAmountController,
                  minAmountController: _familyIncomeMinAmountController,
                  maxAmountController: _familyIncomeMaxAmountController,
                  private: _familyIncomePrivate,
                )
              : null,
        ]);
      case _EditProfileSection.siblings:
        return _summaryFromParts([
          _selectedHasSiblings == true ? 'Siblings added' : 'No siblings',
          _siblingRows.isEmpty
              ? null
              : '${_siblingRows.length} sibling${_siblingRows.length == 1 ? '' : 's'}',
        ]);
      case _EditProfileSection.relatives:
        return _summaryFromParts([
          _relativeRows.isEmpty
              ? null
              : '${_relativeRows.length} relative${_relativeRows.length == 1 ? '' : 's'}',
          _relativeRows.isEmpty
              ? null
              : _labelForValue(
                  _relativeRelationOptions(),
                  _relativeRows.first.relationType,
                  'Relation',
                ),
          _otherRelativesController.text.trim().isEmpty
              ? null
              : 'Other relatives added',
          _allianceNetworkRows.isEmpty
              ? null
              : '${_allianceNetworkRows.length} alliance famil${_allianceNetworkRows.length == 1 ? 'y' : 'ies'}',
          _allianceNetworkRows.isEmpty
              ? null
              : _controllerSummary(
                  _allianceNetworkRows.first.surnameController,
                ),
        ]);
      case _EditProfileSection.property:
        return _summaryFromParts([
          _propertyDetailsController.text.trim().isEmpty
              ? null
              : 'Property added',
        ]);
      case _EditProfileSection.horoscope:
        return _summaryFromParts([
          _labelForId(_rashiOptions, _selectedRashiId, 'Rashi'),
          _labelForId(_nakshatraOptions, _selectedNakshatraId, 'Nakshatra'),
          _labelForId(_ganOptions, _selectedGanId, 'Gan'),
        ]);
      case _EditProfileSection.aboutMe:
        return _summaryFromParts([
          _summaryText(_aboutMeController.text, maxLength: 110),
        ]);
      case _EditProfileSection.partnerPreferences:
        return _summaryFromParts([
          _preferenceAgeSummary(),
          _preferenceHeightSummary(),
          _preferenceIncomeSummary(),
          _labelForId(
            _marriageTypePreferenceOptions,
            _selectedMarriageTypePreferenceId,
            'Marriage type',
          ),
          _labelsForIds(
            _preferredReligionOptions,
            _selectedPreferredReligionIds,
            'Religion',
          ),
          _labelsForIds(
            _preferredMotherTongueOptions,
            _selectedPreferredMotherTongueIds,
            'Mother tongue',
          ),
          _labelsForIds(
            _preferredEducationDegreeOptions,
            _selectedPreferredEducationDegreeIds,
            'Education',
          ),
          _labelsForIds(
            _preferredDietOptions,
            _selectedPreferredDietIds,
            'Diet',
          ),
          _preferredLocationSummary(),
        ]);
      case _EditProfileSection.photo:
        return ApiClient.resolveProfilePhotoUrl(
                  _lastLoadedProfile ?? ApiClient.currentUserProfile,
                ) !=
                null
            ? 'Photo uploaded'
            : 'Photo not uploaded yet';
    }
  }

  Widget _buildBasicInformationSection() {
    return Column(
      children: [
        _buildBasicSection(),
        const SizedBox(height: 14),
        _buildBirthSection(),
        const SizedBox(height: 14),
        _buildMaritalLifestyleSection(),
      ],
    );
  }

  Widget _buildPhysicalWizardSection() {
    return Column(
      children: [
        _buildPhysicalSection(),
        const SizedBox(height: 14),
        _buildLifestyleChoicesSection(),
      ],
    );
  }

  Widget _buildFamilyDetailsWizardSection() {
    return Column(
      children: [
        _buildFamilyDetailsSection(),
        const SizedBox(height: 14),
        _buildFamilyOverviewSection(),
      ],
    );
  }

  Widget _sectionEditor(_EditProfileSection section) {
    switch (section) {
      case _EditProfileSection.basic:
        return _buildBasicInformationSection();
      case _EditProfileSection.physical:
        return _buildPhysicalWizardSection();
      case _EditProfileSection.educationCareer:
        return _buildEducationCareerSection();
      case _EditProfileSection.familyDetails:
        return _buildFamilyDetailsWizardSection();
      case _EditProfileSection.siblings:
        return _buildSiblingsSection();
      case _EditProfileSection.relatives:
        return _buildRelativesSection();
      case _EditProfileSection.property:
        return _buildPropertySection();
      case _EditProfileSection.horoscope:
        return _buildHoroscopeAstroSection();
      case _EditProfileSection.aboutMe:
        return _buildAboutMeSection();
      case _EditProfileSection.partnerPreferences:
        return _buildPartnerPreferencesSection();
      case _EditProfileSection.photo:
        return _buildPhotoSection();
    }
  }

  List<String> _sectionPayloadKeys(_EditProfileSection section) {
    switch (section) {
      case _EditProfileSection.basic:
        return const [
          'full_name',
          'gender_id',
          'date_of_birth',
          'birth_time',
          'birth_city_id',
          'birth_place_text',
          'religion_id',
          'caste_id',
          'caste',
          'location_id',
          'address_line',
          'self_addresses',
          'sub_caste_id',
          'mother_tongue_id',
          'marital_status_id',
          'has_children',
          'marriages',
          'children',
        ];
      case _EditProfileSection.physical:
        return const [
          'height_cm',
          'weight_kg',
          'complexion_id',
          'blood_group_id',
          'physical_build_id',
          'spectacles_lens',
          'physical_condition',
          'diet_id',
          'smoking_status_id',
          'drinking_status_id',
        ];
      case _EditProfileSection.educationCareer:
        return const [
          'highest_education',
          'education_slots',
          'occupation_master_id',
          'occupation_custom_id',
          'company_name',
          'work_location_text',
          'annual_income',
          'income_period',
          'income_value_type',
          'income_amount',
          'income_min_amount',
          'income_max_amount',
          'income_currency_id',
          'income_private',
        ];
      case _EditProfileSection.familyDetails:
        return const [
          'father_name',
          'father_occupation',
          'father_occupation_master_id',
          'father_occupation_custom_id',
          'father_extra_info',
          'father_contact_1',
          'father_contact_2',
          'father_contact_3',
          'mother_name',
          'mother_occupation',
          'mother_occupation_master_id',
          'mother_occupation_custom_id',
          'mother_extra_info',
          'mother_contact_1',
          'mother_contact_2',
          'mother_contact_3',
          'parents_addresses',
          'family_type_id',
          'family_status',
          'family_values',
          'family_income',
          'family_income_period',
          'family_income_value_type',
          'family_income_amount',
          'family_income_min_amount',
          'family_income_max_amount',
          'family_income_currency_id',
          'family_income_private',
        ];
      case _EditProfileSection.siblings:
        return const ['has_siblings', 'siblings'];
      case _EditProfileSection.relatives:
        return const ['relatives', 'other_relatives_text', 'alliance_networks'];
      case _EditProfileSection.property:
        return const ['property_details'];
      case _EditProfileSection.horoscope:
        return const [
          'rashi_id',
          'nakshatra_id',
          'charan',
          'gan_id',
          'nadi_id',
          'yoni_id',
          'varna_id',
          'vashya_id',
          'rashi_lord_id',
          'mangal_dosh_type_id',
          'devak',
          'kul',
          'gotra',
          'navras_name',
          'birth_weekday',
        ];
      case _EditProfileSection.aboutMe:
        return const ['narrative_about_me'];
      case _EditProfileSection.partnerPreferences:
        return const [
          'preferred_age_min',
          'preferred_age_max',
          'preferred_height_min_cm',
          'preferred_height_max_cm',
          'preferred_income_min',
          'preferred_income_max',
          'marriage_type_preference_id',
          'partner_profile_with_children',
          'preferred_profile_managed_by',
          'willing_to_relocate',
          'preferred_intercaste',
          'preferred_marital_status_ids',
          'preferred_diet_ids',
          'preferred_religion_ids',
          'preferred_caste_ids',
          'preferred_mother_tongue_ids',
          'preferred_education_degree_ids',
          'preferred_occupation_master_ids',
          'preferred_country_ids',
          'preferred_state_ids',
          'preferred_district_ids',
          'preferred_taluka_ids',
          'narrative_expectations',
        ];
      case _EditProfileSection.photo:
        return const [];
    }
  }

  Map<String, dynamic> _sectionSnapshot(_EditProfileSection section) {
    final payload = _buildProfilePayload(
      includeSelfAddresses: section == _EditProfileSection.basic,
      includeParentsAddresses: section == _EditProfileSection.familyDetails,
      includeParentContacts: section == _EditProfileSection.familyDetails,
      includeSiblings: section == _EditProfileSection.siblings,
      includeRelatives: section == _EditProfileSection.relatives,
      includeAllianceNetworks: section == _EditProfileSection.relatives,
      includeMarriageChildren: section == _EditProfileSection.basic,
      includePartnerPreferences:
          section == _EditProfileSection.partnerPreferences,
    );
    return <String, dynamic>{
      for (final key in _sectionPayloadKeys(section))
        key: payload.containsKey(key) ? payload[key] : null,
    };
  }

  bool _sectionSnapshotsEqual(
    Map<String, dynamic>? first,
    Map<String, dynamic>? second,
  ) {
    if (first == null || second == null) return first == second;
    return jsonEncode(first) == jsonEncode(second);
  }

  bool _expandedSectionHasChanges() {
    final section = _expandedSection;
    if (section == null) return false;

    return !_sectionSnapshotsEqual(
      _expandedSectionSnapshot,
      _sectionSnapshot(section),
    );
  }

  void _setExpandedSection(_EditProfileSection? section) {
    setState(() {
      _expandedSection = section;
      _expandedSectionSnapshot = section == null
          ? null
          : _sectionSnapshot(section);
    });
  }

  void _restoreLastLoadedProfile() {
    final profile = _lastLoadedProfile;
    if (profile == null) return;

    setState(() {
      _prefillProfile(Map<String, dynamic>.from(profile));
    });
  }

  Future<_UnsavedSectionAction?> _askUnsavedSectionAction() {
    return showDialog<_UnsavedSectionAction>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Unsaved changes'),
          content: const Text(
            'या section मधील बदल save करायचे का discard करायचे?',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, _UnsavedSectionAction.cancel),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, _UnsavedSectionAction.discard),
              child: const Text('Discard'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, _UnsavedSectionAction.save),
              child: const Text('Save changes'),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _resolvePendingSectionChanges() async {
    if (!_expandedSectionHasChanges()) return true;

    final action = await _askUnsavedSectionAction();
    if (!mounted) return false;

    switch (action) {
      case _UnsavedSectionAction.save:
        return _saveProfile(
          navigateOnSuccess: false,
          successMessage: 'Section save झाली.',
          section: _expandedSection,
        );
      case _UnsavedSectionAction.discard:
        _restoreLastLoadedProfile();
        return true;
      case _UnsavedSectionAction.cancel:
      case null:
        return false;
    }
  }

  Future<void> _openSection(_EditProfileSection section) async {
    if (_expandedSection == section) return;

    final canLeaveCurrent = await _resolvePendingSectionChanges();
    if (!mounted || !canLeaveCurrent) return;

    _setExpandedSection(section);
  }

  Future<void> _cancelExpandedSection() async {
    final canCollapse = await _resolvePendingSectionChanges();
    if (!mounted || !canCollapse) return;

    _setExpandedSection(null);
  }

  void _scrollToSectionAfterLayout(_EditProfileSection section) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final sectionContext = _sectionCardKeys[section]?.currentContext;
      if (sectionContext == null) return;

      Scrollable.ensureVisible(
        sectionContext,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        alignment: 0.08,
      );
    });
  }

  void _startSavedSectionFeedback(_EditProfileSection section) {
    _savedHighlightTimer?.cancel();
    setState(() {
      _savedFeedbackSection = section;
      _savedHighlightOn = true;
      _showSavedChip = true;
    });

    _scrollToSectionAfterLayout(section);

    var ticks = 0;
    _savedHighlightTimer = Timer.periodic(const Duration(milliseconds: 420), (
      timer,
    ) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      ticks++;
      if (ticks >= 6) {
        timer.cancel();
        setState(() {
          _savedFeedbackSection = null;
          _savedHighlightOn = false;
          _showSavedChip = false;
        });
        return;
      }

      setState(() {
        _savedHighlightOn = !_savedHighlightOn;
      });
    });
  }

  Future<void> _saveExpandedSection(_EditProfileSection section) async {
    if (_expandedSection != section) return;

    final saved = await _saveProfile(
      navigateOnSuccess: false,
      successMessage: '${_sectionTitle(section)} save झाले.',
      section: section,
    );
    if (!mounted || !saved) return;

    _setExpandedSection(null);
    _startSavedSectionFeedback(section);
  }

  Future<void> _openPhotoManager() async {
    final canLeaveCurrent = await _resolvePendingSectionChanges();
    if (!mounted || !canLeaveCurrent) return;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PhotoUploadScreen()),
    );
    if (!mounted) return;

    try {
      final refreshed = await ApiClient.getMyProfile();
      final profile = refreshed['profile'];
      if (profile is Map && mounted) {
        setState(() {
          _prefillProfile(Map<String, dynamic>.from(profile));
        });
      }
    } catch (_) {
      setState(() {});
    }
  }

  Future<void> _handleBackPressed() async {
    final canLeave = await _resolvePendingSectionChanges();
    if (!mounted || !canLeave) return;

    setState(() {
      _expandedSection = null;
      _expandedSectionSnapshot = null;
    });
    Navigator.of(context).pop();
  }

  Widget _buildSectionManagerCard(_EditProfileSection section) {
    final theme = Theme.of(context);
    final isExpanded = _expandedSection == section;
    final isPhotoSection = section == _EditProfileSection.photo;
    final showSiblingsHeaderSwitch =
        section == _EditProfileSection.siblings && isExpanded;
    final isSavedFeedback = _savedFeedbackSection == section;
    final showSavedPulse = isSavedFeedback && _savedHighlightOn;
    const successColor = Color(0xFF15803D);
    final borderColor = showSavedPulse
        ? successColor
        : isExpanded
        ? theme.colorScheme.primary.withValues(alpha: 0.38)
        : Colors.grey.shade200;

    return AnimatedContainer(
      key: _sectionCardKeys[section],
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: showSavedPulse
            ? successColor.withValues(alpha: 0.08)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: showSavedPulse
            ? [
                BoxShadow(
                  color: successColor.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _sectionIcon(section),
                    color: theme.colorScheme.primary,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _sectionTitle(section),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _sectionSummary(section),
                        maxLines: isExpanded ? 3 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade700,
                          height: 1.3,
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: isSavedFeedback && _showSavedChip
                            ? Padding(
                                key: const ValueKey('saved-chip'),
                                padding: const EdgeInsets.only(top: 8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: successColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    'Saved',
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          color: successColor,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(
                                key: ValueKey('saved-chip-empty'),
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (showSiblingsHeaderSwitch) ...[
                  Text(
                    _selectedHasSiblings == true ? 'ON' : 'OFF',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: _selectedHasSiblings == true
                          ? theme.colorScheme.primary
                          : Colors.grey.shade600,
                    ),
                  ),
                  Switch.adaptive(
                    value: _selectedHasSiblings == true,
                    onChanged: _saving
                        ? null
                        : (value) =>
                              setState(() => _selectedHasSiblings = value),
                  ),
                  const SizedBox(width: 4),
                ],
                isPhotoSection
                    ? FilledButton.icon(
                        onPressed: _saving ? null : _openPhotoManager,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Manage'),
                      )
                    : TextButton.icon(
                        onPressed: _saving
                            ? null
                            : () => isExpanded
                                  ? _cancelExpandedSection()
                                  : _openSection(section),
                        icon: Icon(
                          isExpanded ? Icons.close : Icons.edit_outlined,
                        ),
                        label: Text(isExpanded ? 'Cancel' : 'Edit'),
                      ),
              ],
            ),
            if (isExpanded) ...[
              const SizedBox(height: 16),
              Divider(color: Colors.grey.shade200, height: 1),
              const SizedBox(height: 16),
              _sectionEditor(section),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : _cancelExpandedSection,
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saving
                          ? null
                          : () => _saveExpandedSection(section),
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save section'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildSuggestions({
    required List<Map<String, dynamic>> suggestions,
    required String fallbackPrefix,
    required ValueChanged<Map<String, dynamic>> onSelect,
    bool loading = false,
  }) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: LinearProgressIndicator(),
      );
    }
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      constraints: const BoxConstraints(maxHeight: 180),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: suggestions.length,
        itemBuilder: (context, index) {
          final item = suggestions[index];
          final label = fallbackPrefix == 'Location'
              ? _locationLabel(item)
              : _optionLabel(item, fallbackPrefix);
          final hierarchy =
              item['hierarchy']?.toString().trim() ??
              item['full_form']?.toString().trim() ??
              item['category_label']?.toString().trim();

          return ListTile(
            dense: true,
            title: Text(label),
            subtitle:
                hierarchy != null && hierarchy.isNotEmpty && hierarchy != label
                ? Text(hierarchy)
                : null,
            onTap: () => onSelect(item),
          );
        },
      ),
    );
  }

  Widget _intDropdown({
    required String labelText,
    required IconData icon,
    required List<Map<String, dynamic>> options,
    required int? selectedId,
    required String fallbackPrefix,
    required ValueChanged<int?> onChanged,
    bool? loading,
  }) {
    final isLoading = loading ?? _optionsLoading;
    final selectedValue =
        options.any((row) => _readInt(row['id']) == selectedId)
        ? selectedId
        : null;
    final items = options
        .map((option) {
          final id = _readInt(option['id']);
          if (id == null) return null;
          return DropdownMenuItem<int>(
            value: id,
            child: Text(_optionLabel(option, fallbackPrefix)),
          );
        })
        .whereType<DropdownMenuItem<int>>()
        .toList();

    return DropdownButtonFormField<int>(
      key: ValueKey('$labelText-${items.length}-${selectedValue ?? 'none'}'),
      initialValue: selectedValue,
      isExpanded: true,
      items: items,
      onChanged: _saving || items.isEmpty ? null : onChanged,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: isLoading
            ? AppStrings.loading
            : _labelForId(options, selectedId, fallbackPrefix) ?? 'Optional',
        prefixIcon: Icon(icon),
        suffixIcon: selectedId == null || _saving
            ? null
            : IconButton(
                tooltip: 'Clear',
                icon: const Icon(Icons.close),
                onPressed: () => onChanged(null),
              ),
      ),
    );
  }

  Widget _stringDropdown({
    required String labelText,
    required IconData icon,
    required List<Map<String, dynamic>> options,
    required String? selectedValue,
    required String fallbackPrefix,
    required ValueChanged<String?> onChanged,
    bool? loading,
  }) {
    final isLoading = loading ?? _optionsLoading;
    final normalizedSelected = selectedValue?.trim().toLowerCase();
    String? matchedValue;
    if (normalizedSelected != null && normalizedSelected.isNotEmpty) {
      for (final row in options) {
        final value = _optionStoredValue(row);
        if (value != null && value.trim().toLowerCase() == normalizedSelected) {
          matchedValue = value;
          break;
        }
      }
    }
    final items = options
        .map((option) {
          final value = _optionStoredValue(option);
          if (value == null || value.isEmpty) return null;
          return DropdownMenuItem<String>(
            value: value,
            child: Text(_optionLabel(option, fallbackPrefix)),
          );
        })
        .whereType<DropdownMenuItem<String>>()
        .toList();

    return DropdownButtonFormField<String>(
      key: ValueKey('$labelText-${items.length}-${matchedValue ?? 'none'}'),
      initialValue: matchedValue,
      isExpanded: true,
      items: items,
      onChanged: _saving || items.isEmpty ? null : onChanged,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: isLoading
            ? AppStrings.loading
            : _labelForValue(options, selectedValue, fallbackPrefix) ??
                  'Optional',
        prefixIcon: Icon(icon),
        suffixIcon: selectedValue == null || _saving
            ? null
            : IconButton(
                tooltip: 'Clear',
                icon: const Icon(Icons.close),
                onPressed: () => onChanged(null),
              ),
      ),
    );
  }

  Widget _compactSwitchRow({
    required String title,
    String? subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            value ? 'ON' : 'OFF',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: value ? theme.colorScheme.primary : Colors.grey.shade600,
            ),
          ),
          Switch.adaptive(value: value, onChanged: _saving ? null : onChanged),
        ],
      ),
    );
  }

  Widget _connectedToggleGroup({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                value ? 'ON' : 'OFF',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: value
                      ? theme.colorScheme.primary
                      : Colors.grey.shade600,
                ),
              ),
              Switch.adaptive(
                value: value,
                onChanged: _saving ? null : onChanged,
              ),
            ],
          ),
          if (value && children.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            ...children,
          ],
        ],
      ),
    );
  }

  Widget _preferenceRangeField({
    required String labelText,
    required IconData icon,
    required String valueText,
    required Widget slider,
    required VoidCallback? onClear,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 21, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  labelText,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
              TextButton(
                onPressed: _saving ? null : onClear,
                child: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            valueText,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: const Color(0xFF2E2220),
            ),
          ),
          const SizedBox(height: 4),
          slider,
        ],
      ),
    );
  }

  Widget _preferredAgeRangeField() {
    const minAge = 18;
    const maxAge = 80;
    final hasValue =
        _selectedPreferredAgeMin != null || _selectedPreferredAgeMax != null;
    final lower = (_selectedPreferredAgeMin ?? minAge)
        .clamp(minAge, maxAge)
        .toDouble();
    final upper = (_selectedPreferredAgeMax ?? maxAge)
        .clamp(minAge, maxAge)
        .toDouble();
    final values = lower <= upper
        ? RangeValues(lower, upper)
        : RangeValues(upper, lower);
    final start = values.start.round();
    final end = values.end.round();

    return _preferenceRangeField(
      labelText: 'Preferred Age',
      icon: Icons.cake_outlined,
      valueText: hasValue ? '$start - $end years' : 'Not selected',
      onClear: hasValue
          ? () {
              setState(() {
                _selectedPreferredAgeMin = null;
                _selectedPreferredAgeMax = null;
              });
            }
          : null,
      slider: RangeSlider(
        values: values,
        min: minAge.toDouble(),
        max: maxAge.toDouble(),
        divisions: maxAge - minAge,
        labels: RangeLabels('$start years', '$end years'),
        onChanged: _saving
            ? null
            : (next) {
                setState(() {
                  _selectedPreferredAgeMin = next.start.round();
                  _selectedPreferredAgeMax = next.end.round();
                });
              },
      ),
    );
  }

  Widget _preferredHeightRangeField() {
    const minHeight = 136;
    const maxHeight = 214;
    final hasValue =
        _selectedPreferredHeightMinCm != null ||
        _selectedPreferredHeightMaxCm != null;
    final lower = (_selectedPreferredHeightMinCm ?? minHeight)
        .clamp(minHeight, maxHeight)
        .toDouble();
    final upper = (_selectedPreferredHeightMaxCm ?? maxHeight)
        .clamp(minHeight, maxHeight)
        .toDouble();
    final values = lower <= upper
        ? RangeValues(lower, upper)
        : RangeValues(upper, lower);
    final start = values.start.round();
    final end = values.end.round();

    return _preferenceRangeField(
      labelText: 'Preferred Height',
      icon: Icons.straighten,
      valueText: hasValue
          ? '${_compactHeightLabel(start)} - ${_compactHeightLabel(end)}'
          : 'Not selected',
      onClear: hasValue
          ? () {
              setState(() {
                _selectedPreferredHeightMinCm = null;
                _selectedPreferredHeightMaxCm = null;
              });
            }
          : null,
      slider: RangeSlider(
        values: values,
        min: minHeight.toDouble(),
        max: maxHeight.toDouble(),
        divisions: maxHeight - minHeight,
        labels: RangeLabels(
          _compactHeightLabel(start),
          _compactHeightLabel(end),
        ),
        onChanged: _saving
            ? null
            : (next) {
                setState(() {
                  _selectedPreferredHeightMinCm = next.start.round();
                  _selectedPreferredHeightMaxCm = next.end.round();
                });
              },
      ),
    );
  }

  Widget _preferredIncomeRangeField() {
    const minIncome = 0;
    const maxIncome = 10000000;
    const step = 100000;
    final hasValue =
        _selectedPreferredIncomeMin != null ||
        _selectedPreferredIncomeMax != null;
    final lower = (_selectedPreferredIncomeMin ?? minIncome)
        .clamp(minIncome, maxIncome)
        .toDouble();
    final upper = (_selectedPreferredIncomeMax ?? maxIncome)
        .clamp(minIncome, maxIncome)
        .toDouble();
    final values = lower <= upper
        ? RangeValues(lower, upper)
        : RangeValues(upper, lower);
    final start = (values.start / step).round() * step;
    final end = (values.end / step).round() * step;
    final valueText =
        _selectedPreferredIncomeMin != null &&
            _selectedPreferredIncomeMax == null
        ? '${_incomeLabel(_selectedPreferredIncomeMin!)}+'
        : hasValue
        ? '${_incomeLabel(start)} - ${_incomeLabel(end)}'
        : 'Not selected';

    return _preferenceRangeField(
      labelText: 'Preferred Income',
      icon: Icons.currency_rupee,
      valueText: valueText,
      onClear: hasValue
          ? () {
              setState(() {
                _preferredIncomeTouched = true;
                _selectedPreferredIncomeMin = null;
                _selectedPreferredIncomeMax = null;
              });
            }
          : null,
      slider: RangeSlider(
        values: RangeValues(start.toDouble(), end.toDouble()),
        min: minIncome.toDouble(),
        max: maxIncome.toDouble(),
        divisions: maxIncome ~/ step,
        labels: RangeLabels(_incomeLabel(start), _incomeLabel(end)),
        onChanged: _saving
            ? null
            : (next) {
                setState(() {
                  _preferredIncomeTouched = true;
                  _selectedPreferredIncomeMin =
                      (next.start / step).round() * step;
                  _selectedPreferredIncomeMax =
                      (next.end / step).round() * step;
                });
              },
      ),
    );
  }

  Widget _multiSelectChips({
    required String labelText,
    required IconData icon,
    required List<Map<String, dynamic>> options,
    required Set<int> selectedIds,
    required String fallbackPrefix,
    required ValueChanged<Set<int>> onChanged,
    bool loading = false,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
        helperText: loading
            ? AppStrings.loading
            : options.isEmpty
            ? 'Options available झाल्यावर निवडा.'
            : null,
        suffixIcon: selectedIds.isEmpty || _saving
            ? null
            : IconButton(
                tooltip: 'Clear',
                icon: const Icon(Icons.close),
                onPressed: () => onChanged(<int>{}),
              ),
      ),
      child: options.isEmpty
          ? const Text('Not selected')
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options.map((option) {
                final id = _readInt(option['id']);
                if (id == null) return const SizedBox.shrink();
                final isSelected = selectedIds.contains(id);

                return FilterChip(
                  label: Text(_optionLabel(option, fallbackPrefix)),
                  selected: isSelected,
                  onSelected: _saving
                      ? null
                      : (selected) {
                          final next = Set<int>.from(selectedIds);
                          if (selected) {
                            next.add(id);
                          } else {
                            next.remove(id);
                          }
                          onChanged(next);
                        },
                );
              }).toList(),
            ),
    );
  }

  Future<Set<int>?> _showMultiSelectPickerSheet({
    required String title,
    required List<Map<String, dynamic>> options,
    required Set<int> selectedIds,
    required String fallbackPrefix,
  }) async {
    final searchController = TextEditingController();
    final nextSelectedIds = Set<int>.from(selectedIds);
    var filteredOptions = options;

    try {
      return await showModalBottomSheet<Set<int>>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (context, setSheetState) {
              return SafeArea(
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
                  ),
                  child: SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.78,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Close',
                                icon: const Icon(Icons.close),
                                onPressed: () => Navigator.pop(sheetContext),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: TextField(
                            controller: searchController,
                            decoration: const InputDecoration(
                              labelText: 'Search',
                              prefixIcon: Icon(Icons.search),
                            ),
                            onChanged: (value) {
                              setSheetState(() {
                                filteredOptions = _filterOptions(
                                  options,
                                  value,
                                );
                              });
                            },
                          ),
                        ),
                        Expanded(
                          child: filteredOptions.isEmpty
                              ? const Center(child: Text('No options found.'))
                              : ListView.builder(
                                  itemCount: filteredOptions.length,
                                  itemBuilder: (context, index) {
                                    final option = filteredOptions[index];
                                    final id = _readInt(option['id']);
                                    if (id == null) {
                                      return const SizedBox.shrink();
                                    }
                                    final isSelected = nextSelectedIds.contains(
                                      id,
                                    );

                                    return CheckboxListTile(
                                      value: isSelected,
                                      title: Text(
                                        _optionLabel(option, fallbackPrefix),
                                      ),
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                      onChanged: (selected) {
                                        setSheetState(() {
                                          if (selected == true) {
                                            nextSelectedIds.add(id);
                                          } else {
                                            nextSelectedIds.remove(id);
                                          }
                                        });
                                      },
                                    );
                                  },
                                ),
                        ),
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                          child: Row(
                            children: [
                              TextButton(
                                onPressed: () {
                                  setSheetState(nextSelectedIds.clear);
                                },
                                child: const Text('Clear'),
                              ),
                              const Spacer(),
                              FilledButton(
                                onPressed: () => Navigator.pop(
                                  sheetContext,
                                  Set<int>.from(nextSelectedIds),
                                ),
                                child: const Text('Done'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      searchController.dispose();
    }
  }

  Widget _multiSelectPickerField({
    required String labelText,
    required IconData icon,
    required List<Map<String, dynamic>> options,
    required Set<int> selectedIds,
    required String fallbackPrefix,
    required ValueChanged<Set<int>> onChanged,
    bool loading = false,
    String? helperText,
  }) {
    final orderedIds = _orderedSelectedIds(options, selectedIds);

    return InputDecorator(
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
        helperText: loading ? AppStrings.loading : helperText,
        suffixIcon: selectedIds.isEmpty || _saving
            ? null
            : IconButton(
                tooltip: 'Clear',
                icon: const Icon(Icons.close),
                onPressed: () => onChanged(<int>{}),
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (orderedIds.isEmpty)
            const Text('Not selected')
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: orderedIds.map((id) {
                return InputChip(
                  label: Text(
                    _labelForId(options, id, fallbackPrefix) ?? fallbackPrefix,
                  ),
                  onDeleted: _saving
                      ? null
                      : () {
                          final next = Set<int>.from(selectedIds)..remove(id);
                          onChanged(next);
                        },
                );
              }).toList(),
            ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _saving || options.isEmpty
                ? null
                : () async {
                    final next = await _showMultiSelectPickerSheet(
                      title: labelText,
                      options: options,
                      selectedIds: selectedIds,
                      fallbackPrefix: fallbackPrefix,
                    );
                    if (!mounted || next == null) return;
                    onChanged(next);
                  },
            icon: const Icon(Icons.playlist_add_check),
            label: Text(options.isEmpty ? 'Options unavailable' : 'Select'),
          ),
        ],
      ),
    );
  }

  Widget _buildMaritalLifestyleSection() {
    final statusKey = _currentMaritalStatusKey();
    final showStatusDetails = _maritalStatusShowsDetails(statusKey);

    return _sectionCard(
      title: 'Marital status and children',
      icon: Icons.favorite_border,
      children: [
        _intDropdown(
          labelText: 'Marital status (Optional)',
          icon: Icons.favorite_border,
          options: _maritalStatusOptions,
          selectedId: _selectedMaritalStatusId,
          fallbackPrefix: 'Marital status',
          loading: _maritalLifestyleOptionsLoading,
          onChanged: (value) => setState(() => _setMaritalStatus(value)),
        ),
        if (showStatusDetails) ...[
          const SizedBox(height: 14),
          _buildMarriageHistoryEditor(),
          const SizedBox(height: 14),
          _connectedToggleGroup(
            title: 'Children',
            subtitle: _selectedHasChildren == true
                ? '${_childRows.length} child detail${_childRows.length == 1 ? '' : 's'}'
                : 'No children',
            icon: Icons.child_care_outlined,
            value: _selectedHasChildren == true,
            onChanged: (value) => setState(() => _setHasChildren(value)),
            children: [_buildChildrenEditor()],
          ),
        ],
        if (_maritalLifestyleOptionsLoading)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: LinearProgressIndicator(),
          ),
        if (_maritalLifestyleOptionsError != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _maritalLifestyleOptionsError!,
              style: TextStyle(color: Colors.amber.shade900),
            ),
          ),
      ],
    );
  }

  Widget _buildLifestyleChoicesSection() {
    return _sectionCard(
      title: 'Lifestyle',
      icon: Icons.restaurant_outlined,
      children: [
        _intDropdown(
          labelText: 'Diet (Optional)',
          icon: Icons.restaurant_outlined,
          options: _dietOptions,
          selectedId: _selectedDietId,
          fallbackPrefix: 'Diet',
          loading: _maritalLifestyleOptionsLoading,
          onChanged: (value) => setState(() => _selectedDietId = value),
        ),
        const SizedBox(height: 14),
        _intDropdown(
          labelText: 'Smoking status (Optional)',
          icon: Icons.smoke_free_outlined,
          options: _smokingStatusOptions,
          selectedId: _selectedSmokingStatusId,
          fallbackPrefix: 'Smoking status',
          loading: _maritalLifestyleOptionsLoading,
          onChanged: (value) =>
              setState(() => _selectedSmokingStatusId = value),
        ),
        const SizedBox(height: 14),
        _intDropdown(
          labelText: 'Drinking status (Optional)',
          icon: Icons.local_bar_outlined,
          options: _drinkingStatusOptions,
          selectedId: _selectedDrinkingStatusId,
          fallbackPrefix: 'Drinking status',
          loading: _maritalLifestyleOptionsLoading,
          onChanged: (value) =>
              setState(() => _selectedDrinkingStatusId = value),
        ),
        if (_maritalLifestyleOptionsLoading)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: LinearProgressIndicator(),
          ),
        if (_maritalLifestyleOptionsError != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _maritalLifestyleOptionsError!,
              style: TextStyle(color: Colors.amber.shade900),
            ),
          ),
      ],
    );
  }

  Widget _buildMarriageHistoryEditor() {
    final statusKey = _currentMaritalStatusKey();
    if (!_maritalStatusShowsDetails(statusKey)) {
      return const SizedBox.shrink();
    }

    return _buildMarriageRowEditor(_ensureMarriageDetailRow(), statusKey);
  }

  Widget _buildMarriageRowEditor(_MarriageEditRow row, String? statusKey) {
    final theme = Theme.of(context);
    final showDivorceFields =
        statusKey == 'divorced' || statusKey == 'annulled';
    final showSeparatedFields = statusKey == 'separated';
    final showLegalStatus = showDivorceFields || showSeparatedFields;
    final showWidowFields = statusKey == 'widowed';
    final title = switch (statusKey) {
      'annulled' => 'Annulment details',
      'separated' => 'Separation details',
      'widowed' => 'Widowhood details',
      _ => 'Divorce details',
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: row.marriageYearController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Marriage year (Optional)',
              prefixIcon: Icon(Icons.calendar_month_outlined),
            ),
          ),
          if (showDivorceFields) ...[
            const SizedBox(height: 12),
            TextField(
              controller: row.divorceYearController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: statusKey == 'annulled'
                    ? 'Annulment year (Optional)'
                    : 'Divorce year (Optional)',
                prefixIcon: const Icon(Icons.gavel_outlined),
              ),
            ),
          ],
          if (showSeparatedFields) ...[
            const SizedBox(height: 12),
            TextField(
              controller: row.separationYearController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Separation year (Optional)',
                prefixIcon: Icon(Icons.event_busy_outlined),
              ),
            ),
          ],
          if (showWidowFields) ...[
            const SizedBox(height: 12),
            TextField(
              controller: row.spouseDeathYearController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Spouse death year (Optional)',
                prefixIcon: Icon(Icons.event_outlined),
              ),
            ),
          ],
          if (showLegalStatus) ...[
            const SizedBox(height: 12),
            _stringDropdown(
              labelText: 'Legal status (Optional)',
              icon: Icons.verified_outlined,
              options: _divorceStatusOptions(),
              selectedValue: row.divorceStatus,
              fallbackPrefix: 'Legal status',
              loading: false,
              onChanged: (value) => setState(() => row.divorceStatus = value),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChildrenEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _saving ? null : _addChild,
            icon: const Icon(Icons.add),
            label: const Text('Add child'),
          ),
        ),
        if (_childRows.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'No children added.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          )
        else ...[
          const SizedBox(height: 10),
          for (var index = 0; index < _childRows.length; index++) ...[
            _buildChildRowEditor(index, _childRows[index]),
            const SizedBox(height: 12),
          ],
        ],
      ],
    );
  }

  Widget _buildChildRowEditor(int index, _ChildEditRow row) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Child ${index + 1}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Remove',
                onPressed: _saving ? null : () => _removeChild(index),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _stringDropdown(
            labelText: 'Gender',
            icon: Icons.person_outline,
            options: _childGenderOptions(),
            selectedValue: row.gender,
            fallbackPrefix: 'Gender',
            loading: false,
            onChanged: (value) => setState(() => row.gender = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: row.ageController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Age',
              prefixIcon: Icon(Icons.cake_outlined),
            ),
          ),
          const SizedBox(height: 12),
          _intDropdown(
            labelText: 'Living with (Optional)',
            icon: Icons.home_outlined,
            options: _childLivingWithOptions,
            selectedId: row.childLivingWithId,
            fallbackPrefix: 'Living with',
            loading: _maritalLifestyleOptionsLoading,
            onChanged: (value) => setState(() => row.childLivingWithId = value),
          ),
        ],
      ),
    );
  }

  void _addChild() {
    if (!_maritalStatusShowsDetails(_currentMaritalStatusKey())) return;
    setState(() {
      _selectedHasChildren = true;
      _childRows.add(_ChildEditRow(sortOrder: _childRows.length));
    });
  }

  void _removeChild(int index) {
    setState(() {
      final removed = _childRows.removeAt(index);
      removed.dispose();
    });
  }

  void _addAddressRow(List<_AddressEditRow> rows, String defaultTypeKey) {
    setState(() {
      rows.add(_AddressEditRow(addressTypeKey: defaultTypeKey));
    });
  }

  void _removeAddressRow(List<_AddressEditRow> rows, _AddressEditRow row) {
    setState(() {
      rows.remove(row);
      row.dispose();
      _syncCurrentAddressFromSelfRows();
    });
  }

  Widget _buildAddressRepeater({
    required String title,
    required List<_AddressEditRow> rows,
    required String defaultTypeKey,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _saving
                  ? null
                  : () => _addAddressRow(rows, defaultTypeKey),
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (rows.isEmpty)
          OutlinedButton.icon(
            onPressed: _saving
                ? null
                : () => _addAddressRow(rows, defaultTypeKey),
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('Add address'),
          )
        else
          ...rows.map((row) {
            final index = rows.indexOf(row);
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == rows.length - 1 ? 0 : 14,
              ),
              child: _buildAddressRowEditor(
                row: row,
                rows: rows,
                defaultTypeKey: defaultTypeKey,
                rowLabel: 'Address ${index + 1}',
              ),
            );
          }),
      ],
    );
  }

  Widget _buildAddressRowEditor({
    required _AddressEditRow row,
    required List<_AddressEditRow> rows,
    required String defaultTypeKey,
    required String rowLabel,
  }) {
    final selectedType =
        _addressTypeOptions.any((option) => option['key'] == row.addressTypeKey)
        ? row.addressTypeKey
        : defaultTypeKey;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  rowLabel,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: 'Remove address',
                onPressed: _saving ? null : () => _removeAddressRow(rows, row),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: selectedType,
            isExpanded: true,
            items: _addressTypeOptions
                .map(
                  (option) => DropdownMenuItem<String>(
                    value: option['key'],
                    child: Text(option['label'] ?? option['key'] ?? 'Address'),
                  ),
                )
                .toList(),
            onChanged: _saving
                ? null
                : (value) {
                    setState(() {
                      row.addressTypeKey = value ?? defaultTypeKey;
                      _syncCurrentAddressFromSelfRows();
                    });
                  },
            decoration: const InputDecoration(
              labelText: 'Address type',
              prefixIcon: Icon(Icons.bookmark_border),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: row.addressLineController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Address line (Optional)',
              prefixIcon: Icon(Icons.home_outlined),
            ),
            onChanged: (_) {
              if (_currentSelfAddressRow() == row) {
                _syncCurrentAddressFromSelfRows();
              }
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: row.locationController,
            decoration: const InputDecoration(
              labelText: 'Location',
              hintText: 'Search city or village',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
            onChanged: (value) => _scheduleAddressLocationSearch(row, value),
          ),
          _buildSuggestions(
            suggestions: row.locationSuggestions,
            fallbackPrefix: 'Location',
            loading: row.locationSearching,
            onSelect: (location) => _selectAddressLocation(row, location),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicSection() {
    final selectedGenderValue =
        _genders.any((row) => _readInt(row['id']) == _selectedGenderId)
        ? _selectedGenderId
        : null;

    return _sectionCard(
      title: 'Basic details',
      icon: Icons.badge_outlined,
      children: [
        TextField(
          controller: _fullNameController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Full name',
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<int>(
          initialValue: selectedGenderValue,
          isExpanded: true,
          items: _genders
              .map((gender) {
                final id = _readInt(gender['id']);
                if (id == null) return null;
                return DropdownMenuItem<int>(
                  value: id,
                  child: Text(_optionLabel(gender, AppStrings.brideGroom)),
                );
              })
              .whereType<DropdownMenuItem<int>>()
              .toList(),
          onChanged: _saving || _gendersLoading
              ? null
              : (value) => setState(() => _selectedGenderId = value),
          decoration: InputDecoration(
            labelText: AppStrings.profileType,
            hintText: _gendersLoading
                ? AppStrings.loading
                : AppStrings.brideGroom,
            prefixIcon: const Icon(Icons.wc_outlined),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _dobController,
          readOnly: true,
          decoration: const InputDecoration(
            labelText: 'Date of birth',
            prefixIcon: Icon(Icons.calendar_today_outlined),
          ),
          onTap: _pickDob,
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _religionController,
          decoration: const InputDecoration(
            labelText: 'Religion',
            prefixIcon: Icon(Icons.account_balance_outlined),
          ),
          onChanged: _onReligionChanged,
          onTap: () => _onReligionChanged(_religionController.text),
        ),
        _buildSuggestions(
          suggestions: _religionSuggestions,
          fallbackPrefix: 'Religion',
          loading: _religionsLoading,
          onSelect: _selectReligion,
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _casteController,
          enabled: _selectedReligionId != null && !_castesLoading,
          decoration: InputDecoration(
            labelText: 'Caste',
            hintText: _selectedReligionId == null
                ? 'Select religion first'
                : null,
            prefixIcon: const Icon(Icons.group_outlined),
          ),
          onChanged: _onCasteChanged,
          onTap: () => _onCasteChanged(_casteController.text),
        ),
        _buildSuggestions(
          suggestions: _casteSuggestions,
          fallbackPrefix: 'Caste',
          loading: _castesLoading,
          onSelect: _selectCaste,
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _subCasteController,
          enabled: _selectedCasteId != null,
          decoration: InputDecoration(
            labelText: 'Sub-caste (Optional)',
            hintText: _selectedCasteId == null ? 'Select caste first' : null,
            prefixIcon: const Icon(Icons.account_tree_outlined),
          ),
          onChanged: _searchSubCastes,
        ),
        _buildSuggestions(
          suggestions: _subCasteSuggestions,
          fallbackPrefix: 'Sub-caste',
          loading: _subCasteSearching,
          onSelect: _selectSubCaste,
        ),
        const SizedBox(height: 18),
        _buildAddressRepeater(
          title: 'Self addresses',
          rows: _selfAddressRows,
          defaultTypeKey: 'current',
        ),
      ],
    );
  }

  Widget _buildBirthSection() {
    return _sectionCard(
      title: 'Birth details',
      icon: Icons.event_available_outlined,
      children: [
        TextField(
          controller: _birthTimeController,
          readOnly: true,
          decoration: InputDecoration(
            labelText: 'Birth time (Optional)',
            hintText: 'HH:MM',
            prefixIcon: const Icon(Icons.schedule_outlined),
            suffixIcon: _birthTimeController.text.trim().isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear birth time',
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _birthTimeController.clear();
                      });
                    },
                  ),
          ),
          onTap: _pickBirthTime,
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _birthPlaceController,
          decoration: const InputDecoration(
            labelText: 'Birth place (Optional)',
            hintText: 'Search city or village',
            prefixIcon: Icon(Icons.place_outlined),
          ),
          onChanged: _scheduleBirthPlaceSearch,
        ),
        _buildSuggestions(
          suggestions: _birthPlaceSuggestions,
          fallbackPrefix: 'Location',
          loading: _birthPlaceSearching,
          onSelect: _selectBirthPlace,
        ),
        const SizedBox(height: 14),
        _intDropdown(
          labelText: 'Mother tongue (Optional)',
          icon: Icons.translate_outlined,
          options: _motherTongueOptions,
          selectedId: _selectedMotherTongueId,
          fallbackPrefix: 'Mother tongue',
          onChanged: (value) {
            setState(() {
              _selectedMotherTongueId = value;
            });
          },
        ),
      ],
    );
  }

  Widget _occupationDropdown() {
    final items = <DropdownMenuItem<String>>[
      ..._occupationOptions.map((occupation) {
        final id = _readInt(occupation['id']);
        if (id == null) return null;
        final label = _optionLabel(occupation, 'Occupation');
        return DropdownMenuItem<String>(
          value: 'master:$id',
          child: Text(label, overflow: TextOverflow.ellipsis),
        );
      }).whereType<DropdownMenuItem<String>>(),
      ..._customOccupationOptions.map((occupation) {
        final id = _readInt(occupation['id']);
        if (id == null) return null;
        final label = _optionLabel(occupation, 'Occupation');
        return DropdownMenuItem<String>(
          value: 'custom:$id',
          child: Text('$label (Custom)', overflow: TextOverflow.ellipsis),
        );
      }).whereType<DropdownMenuItem<String>>(),
    ];

    final selectedChoice = _selectedOccupationChoice();
    final selectedValue = items.any((item) => item.value == selectedChoice)
        ? selectedChoice
        : null;

    return DropdownButtonFormField<String>(
      key: ValueKey('occupation-${items.length}-${selectedValue ?? 'none'}'),
      initialValue: selectedValue,
      isExpanded: true,
      items: items,
      onChanged: _saving || items.isEmpty ? null : _selectOccupationChoice,
      decoration: InputDecoration(
        labelText: 'Occupation (Optional)',
        hintText: _educationCareerOptionsLoading
            ? AppStrings.loading
            : _selectedOccupationLabel ?? 'Optional',
        prefixIcon: const Icon(Icons.work_outline),
        suffixIcon:
            (_selectedOccupationMasterId == null &&
                _selectedOccupationCustomId == null)
            ? null
            : IconButton(
                tooltip: 'Clear occupation',
                icon: const Icon(Icons.close),
                onPressed: _saving ? null : () => _selectOccupationChoice(null),
              ),
      ),
    );
  }

  Widget _familyOccupationDropdown({
    required String labelText,
    required bool father,
  }) {
    final items = <DropdownMenuItem<String>>[
      ..._familyOccupationOptions.map((occupation) {
        final id = _readInt(occupation['id']);
        if (id == null) return null;
        final label = _optionLabel(occupation, 'Occupation');
        return DropdownMenuItem<String>(
          value: 'master:$id',
          child: Text(label, overflow: TextOverflow.ellipsis),
        );
      }).whereType<DropdownMenuItem<String>>(),
      ..._familyCustomOccupationOptions.map((occupation) {
        final id = _readInt(occupation['id']);
        if (id == null) return null;
        final label = _optionLabel(occupation, 'Occupation');
        return DropdownMenuItem<String>(
          value: 'custom:$id',
          child: Text('$label (Custom)', overflow: TextOverflow.ellipsis),
        );
      }).whereType<DropdownMenuItem<String>>(),
    ];

    final selectedChoice = father
        ? _occupationChoiceValue(
            _selectedFatherOccupationMasterId,
            _selectedFatherOccupationCustomId,
          )
        : _occupationChoiceValue(
            _selectedMotherOccupationMasterId,
            _selectedMotherOccupationCustomId,
          );
    final selectedValue = items.any((item) => item.value == selectedChoice)
        ? selectedChoice
        : null;
    final selectedLabel = father
        ? _selectedFatherOccupationLabel
        : _selectedMotherOccupationLabel;
    final hasSelection = father
        ? (_selectedFatherOccupationMasterId != null ||
              _selectedFatherOccupationCustomId != null)
        : (_selectedMotherOccupationMasterId != null ||
              _selectedMotherOccupationCustomId != null);

    return DropdownButtonFormField<String>(
      key: ValueKey('$labelText-${items.length}-${selectedValue ?? 'none'}'),
      initialValue: selectedValue,
      isExpanded: true,
      items: items,
      onChanged: _saving || items.isEmpty
          ? null
          : (value) =>
                _selectFamilyOccupationChoice(father: father, value: value),
      decoration: InputDecoration(
        labelText: labelText,
        hintText: _remainingProfileOptionsLoading
            ? AppStrings.loading
            : selectedLabel ?? 'Optional',
        prefixIcon: const Icon(Icons.work_outline),
        suffixIcon: !hasSelection
            ? null
            : IconButton(
                tooltip: 'Clear occupation',
                icon: const Icon(Icons.close),
                onPressed: _saving
                    ? null
                    : () => _selectFamilyOccupationChoice(
                        father: father,
                        value: null,
                      ),
              ),
      ),
    );
  }

  List<Map<String, dynamic>> _incomeValueTypeOptions() => const [
    {'key': 'exact', 'label': 'Exact'},
    {'key': 'approximate', 'label': 'Approximate'},
    {'key': 'range', 'label': 'Range'},
    {'key': 'undisclosed', 'label': 'Undisclosed'},
  ];

  List<Map<String, dynamic>> _incomePeriodOptions() => const [
    {'key': 'annual', 'label': 'Annual'},
    {'key': 'monthly', 'label': 'Monthly'},
    {'key': 'weekly', 'label': 'Weekly'},
    {'key': 'daily', 'label': 'Daily'},
  ];

  void _setPersonalIncomeGroupEnabled(bool value) {
    setState(() {
      _showIncomeGroup = value;
      if (value) {
        _selectedIncomeValueType ??= 'approximate';
        _selectedIncomePeriod ??= 'annual';
        _selectedIncomeCurrencyId ??= _defaultCurrencyId();
      }
    });
  }

  void _setFamilyIncomeGroupEnabled(bool value) {
    setState(() {
      _showFamilyIncomeGroup = value;
      if (value) {
        _selectedFamilyIncomeValueType ??= 'approximate';
        _selectedFamilyIncomePeriod ??= 'annual';
        _selectedFamilyIncomeCurrencyId ??=
            _selectedIncomeCurrencyId ?? _defaultCurrencyId();
      }
    });
  }

  Widget _incomeEditor({
    required String title,
    required bool enabled,
    required ValueChanged<bool> onEnabledChanged,
    required String? valueType,
    required ValueChanged<String?> onValueTypeChanged,
    required String? period,
    required ValueChanged<String?> onPeriodChanged,
    required TextEditingController amountController,
    required TextEditingController minAmountController,
    required TextEditingController maxAmountController,
    required int? currencyId,
    required ValueChanged<int?> onCurrencyChanged,
    required bool private,
    required ValueChanged<bool> onPrivateChanged,
  }) {
    final effectiveValueType = valueType ?? 'approximate';
    final effectivePeriod = period ?? 'annual';
    final effectiveCurrencyId = currencyId ?? _defaultCurrencyId();
    final showSingleAmount =
        effectiveValueType == 'exact' || effectiveValueType == 'approximate';
    final showRange = effectiveValueType == 'range';
    final currencyText = _currencyLabel(effectiveCurrencyId);
    final subtitle = enabled
        ? _editableIncomeSummary(
                valueType: effectiveValueType,
                amountController: amountController,
                minAmountController: minAmountController,
                maxAmountController: maxAmountController,
                private: private,
              ) ??
              'Add income details'
        : 'Not added';

    String incomeTypeLabel(String key) {
      return switch (key) {
        'exact' => 'Exact',
        'approximate' => 'Approximate income',
        'range' => 'Range',
        'undisclosed' => 'Undisclosed',
        _ => key,
      };
    }

    String periodLabel(String key) {
      return switch (key) {
        'monthly' => 'monthly',
        'weekly' => 'weekly',
        'daily' => 'daily',
        _ => 'annual',
      };
    }

    Widget amountField({
      required TextEditingController controller,
      required String labelText,
    }) {
      return TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          labelText: labelText,
          suffixIcon: PopupMenuButton<int>(
            enabled: _incomeCurrencyOptions.isNotEmpty && !_saving,
            initialValue: effectiveCurrencyId,
            tooltip: 'Currency',
            onSelected: (value) {
              setState(() => onCurrencyChanged(value));
            },
            itemBuilder: (context) => _incomeCurrencyOptions
                .map((option) {
                  final id = _readInt(option['id']);
                  if (id == null) return null;
                  return PopupMenuItem<int>(
                    value: id,
                    child: Text(_optionLabel(option, 'Currency')),
                  );
                })
                .whereType<PopupMenuItem<int>>()
                .toList(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                widthFactor: 1,
                child: Text(
                  currencyText,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return _connectedToggleGroup(
      title: '$title (Optional)',
      subtitle: subtitle,
      icon: Icons.payments_outlined,
      value: enabled,
      onChanged: onEnabledChanged,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _incomeValueTypeOptions().map((option) {
            final key = _readText(option['key']);
            if (key == null) return const SizedBox.shrink();

            return ChoiceChip(
              label: Text(incomeTypeLabel(key)),
              selected: effectiveValueType == key,
              onSelected: _saving
                  ? null
                  : (selected) {
                      if (!selected) return;
                      setState(() {
                        onValueTypeChanged(key);
                        if (period == null) {
                          onPeriodChanged('annual');
                        }
                        if (currencyId == null) {
                          onCurrencyChanged(_defaultCurrencyId());
                        }
                      });
                    },
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        _stringDropdown(
          labelText: 'Income period',
          icon: Icons.calendar_month_outlined,
          options: _incomePeriodOptions(),
          selectedValue: effectivePeriod,
          fallbackPrefix: 'Period',
          loading: false,
          onChanged: (value) => setState(() {
            onPeriodChanged(value ?? 'annual');
            if (currencyId == null) {
              onCurrencyChanged(_defaultCurrencyId());
            }
          }),
        ),
        if (showSingleAmount) ...[
          const SizedBox(height: 14),
          amountField(
            controller: amountController,
            labelText: effectiveValueType == 'exact'
                ? 'Exact ${periodLabel(effectivePeriod)} income'
                : 'Approximate ${periodLabel(effectivePeriod)} income',
          ),
        ],
        if (showRange) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: amountField(
                  controller: minAmountController,
                  labelText: 'Minimum amount',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: amountField(
                  controller: maxAmountController,
                  labelText: 'Maximum amount',
                ),
              ),
            ],
          ),
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Keep ${title.toLowerCase()} private'),
          value: private,
          onChanged: _saving
              ? null
              : (value) => setState(() => onPrivateChanged(value)),
        ),
      ],
    );
  }

  Widget _charanDropdown() {
    final validCharans = _validCharansForSelection();
    final currentCharan = _selectedCharan;
    final selectedValue =
        currentCharan != null && validCharans.contains(currentCharan)
        ? currentCharan
        : null;

    return DropdownButtonFormField<int>(
      key: ValueKey(
        'charan-${validCharans.join('-')}-${selectedValue ?? 'none'}',
      ),
      initialValue: selectedValue,
      isExpanded: true,
      items: validCharans
          .map(
            (charan) => DropdownMenuItem<int>(
              value: charan,
              child: Text(charan.toString()),
            ),
          )
          .toList(),
      onChanged: _saving ? null : _selectCharan,
      decoration: InputDecoration(
        labelText: 'Charan (Optional)',
        hintText: 'Optional',
        prefixIcon: const Icon(Icons.filter_4),
        suffixIcon: _selectedCharan == null || _saving
            ? null
            : IconButton(
                tooltip: 'Clear charan',
                icon: const Icon(Icons.close),
                onPressed: () => _selectCharan(null),
              ),
      ),
    );
  }

  Widget _buildEducationCareerSection() {
    return _sectionCard(
      title: 'Education & Career',
      icon: Icons.school_outlined,
      children: [
        TextField(
          controller: _educationController,
          decoration: InputDecoration(
            labelText: 'Highest education',
            hintText: _educationCareerOptionsLoading
                ? AppStrings.loading
                : 'Search or type education',
            prefixIcon: const Icon(Icons.school_outlined),
          ),
          onChanged: _onEducationChanged,
          onTap: () => _onEducationChanged(_educationController.text),
        ),
        _buildSuggestions(
          suggestions: _educationSuggestions,
          fallbackPrefix: 'Education',
          loading: _educationCareerOptionsLoading,
          onSelect: _selectEducation,
        ),
        const SizedBox(height: 14),
        _occupationDropdown(),
        const SizedBox(height: 14),
        TextField(
          controller: _companyNameController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Company name (Optional)',
            prefixIcon: Icon(Icons.business_outlined),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _workLocationController,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Work location (Optional)',
            hintText: 'Search city or type work location',
            prefixIcon: Icon(Icons.location_city_outlined),
          ),
          onChanged: _scheduleWorkLocationSearch,
        ),
        _buildSuggestions(
          suggestions: _workLocationSuggestions,
          fallbackPrefix: 'Location',
          loading: _workLocationSearching,
          onSelect: _selectWorkLocation,
        ),
        const SizedBox(height: 18),
        _incomeEditor(
          title: 'Personal income',
          enabled: _showIncomeGroup,
          onEnabledChanged: _setPersonalIncomeGroupEnabled,
          valueType: _selectedIncomeValueType,
          onValueTypeChanged: (value) => _selectedIncomeValueType = value,
          period: _selectedIncomePeriod,
          onPeriodChanged: (value) => _selectedIncomePeriod = value,
          amountController: _incomeAmountController,
          minAmountController: _incomeMinAmountController,
          maxAmountController: _incomeMaxAmountController,
          currencyId: _selectedIncomeCurrencyId,
          onCurrencyChanged: (value) => _selectedIncomeCurrencyId = value,
          private: _incomePrivate,
          onPrivateChanged: (value) => _incomePrivate = value,
        ),
        if (_educationCareerOptionsError != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _educationCareerOptionsError!,
              style: TextStyle(color: Colors.amber.shade900),
            ),
          ),
      ],
    );
  }

  Widget _buildPhysicalSection() {
    return _sectionCard(
      title: 'Physical details',
      icon: Icons.accessibility_new_outlined,
      children: [
        Row(
          children: [
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () async {
                  final value = await _pickNumber(
                    title: 'Select height',
                    values: _heightValues(),
                    selected: _selectedHeightCm,
                    labelBuilder: _heightLabel,
                  );
                  if (!mounted) return;
                  if (value == null) return;
                  setState(() {
                    _selectedHeightCm = value == _clearNumberSelection
                        ? null
                        : value;
                  });
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Height',
                    prefixIcon: Icon(Icons.straighten),
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    _selectedHeightCm == null
                        ? 'Not selected'
                        : _heightLabel(_selectedHeightCm!),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () async {
                  final value = await _pickNumber(
                    title: 'Select weight',
                    values: _weightValues(),
                    selected: _selectedWeightKg,
                    labelBuilder: _weightLabel,
                  );
                  if (!mounted) return;
                  if (value == null) return;
                  setState(() {
                    _selectedWeightKg = value == _clearNumberSelection
                        ? null
                        : value;
                  });
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Weight',
                    prefixIcon: Icon(Icons.monitor_weight_outlined),
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    _selectedWeightKg == null
                        ? 'Not selected'
                        : _weightLabel(_selectedWeightKg!),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _intDropdown(
          labelText: 'Complexion (Optional)',
          icon: Icons.color_lens_outlined,
          options: _complexionOptions,
          selectedId: _selectedComplexionId,
          fallbackPrefix: 'Complexion',
          onChanged: (value) => setState(() => _selectedComplexionId = value),
        ),
        const SizedBox(height: 14),
        _intDropdown(
          labelText: 'Blood group (Optional)',
          icon: Icons.favorite_border,
          options: _bloodGroupOptions,
          selectedId: _selectedBloodGroupId,
          fallbackPrefix: 'Blood group',
          onChanged: (value) => setState(() => _selectedBloodGroupId = value),
        ),
        const SizedBox(height: 14),
        _intDropdown(
          labelText: 'Physical build (Optional)',
          icon: Icons.accessibility_new_outlined,
          options: _physicalBuildOptions,
          selectedId: _selectedPhysicalBuildId,
          fallbackPrefix: 'Physical build',
          onChanged: (value) =>
              setState(() => _selectedPhysicalBuildId = value),
        ),
        const SizedBox(height: 14),
        _stringDropdown(
          labelText: 'Spectacles / Lens (Optional)',
          icon: Icons.visibility_outlined,
          options: _spectaclesLensOptions,
          selectedValue: _selectedSpectaclesLens,
          fallbackPrefix: 'Spectacles / Lens',
          onChanged: (value) => setState(() => _selectedSpectaclesLens = value),
        ),
        const SizedBox(height: 14),
        _stringDropdown(
          labelText: 'Physical condition (Optional)',
          icon: Icons.health_and_safety_outlined,
          options: _physicalConditionOptions,
          selectedValue: _selectedPhysicalCondition,
          fallbackPrefix: 'Physical condition',
          onChanged: (value) =>
              setState(() => _selectedPhysicalCondition = value),
        ),
        if (_optionsLoading)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: LinearProgressIndicator(),
          ),
        if (_optionsError != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _optionsError!,
              style: TextStyle(color: Colors.amber.shade900),
            ),
          ),
      ],
    );
  }

  void _addParentContactSlot({required bool father}) {
    setState(() {
      if (father) {
        if (!_showFatherContact2) {
          _showFatherContact2 = true;
          _fatherContact2Removed = false;
        } else if (_supportsParentContact3) {
          _showFatherContact3 = true;
          _fatherContact3Removed = false;
        }
      } else {
        if (!_showMotherContact2) {
          _showMotherContact2 = true;
          _motherContact2Removed = false;
        } else if (_supportsParentContact3) {
          _showMotherContact3 = true;
          _motherContact3Removed = false;
        }
      }
    });
  }

  void _removeParentContactSlot({required bool father, required int slot}) {
    setState(() {
      final contact2Controller = father
          ? _fatherContact2Controller
          : _motherContact2Controller;
      final contact3Controller = father
          ? _fatherContact3Controller
          : _motherContact3Controller;
      final showContact3 = father ? _showFatherContact3 : _showMotherContact3;

      if (slot == 2) {
        if (showContact3 && contact3Controller.text.trim().isNotEmpty) {
          contact2Controller.text = contact3Controller.text;
          contact3Controller.clear();
          if (father) {
            _showFatherContact2 = true;
            _showFatherContact3 = false;
            _fatherContact2Removed = false;
            _fatherContact3Removed = true;
          } else {
            _showMotherContact2 = true;
            _showMotherContact3 = false;
            _motherContact2Removed = false;
            _motherContact3Removed = true;
          }
        } else {
          contact2Controller.clear();
          contact3Controller.clear();
          if (father) {
            _showFatherContact2 = false;
            _showFatherContact3 = false;
            _fatherContact2Removed = true;
            _fatherContact3Removed = true;
          } else {
            _showMotherContact2 = false;
            _showMotherContact3 = false;
            _motherContact2Removed = true;
            _motherContact3Removed = true;
          }
        }
        return;
      }

      contact3Controller.clear();
      if (father) {
        _showFatherContact3 = false;
        _fatherContact3Removed = true;
      } else {
        _showMotherContact3 = false;
        _motherContact3Removed = true;
      }
    });
  }

  Widget _buildParentContactFields({
    required String title,
    required bool father,
    required TextEditingController contact1Controller,
    required TextEditingController contact2Controller,
    required TextEditingController contact3Controller,
    required bool showContact2,
    required bool showContact3,
  }) {
    Widget contactRow(
      TextEditingController controller,
      String label, {
      VoidCallback? onAdd,
      VoidCallback? onRemove,
    }) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: label,
                hintText: 'Optional',
                prefixIcon: const Icon(Icons.call_outlined),
              ),
            ),
          ),
          if (onAdd != null) ...[
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Add another contact',
              onPressed: onAdd,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
          if (onRemove != null) ...[
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Remove this contact',
              onPressed: onRemove,
              icon: const Icon(Icons.remove_circle_outline),
            ),
          ],
        ],
      );
    }

    final canAddContact2 = !showContact2;
    final canAddContact3 =
        showContact2 && _supportsParentContact3 && !showContact3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        contactRow(
          contact1Controller,
          'Contact 1',
          onAdd: canAddContact2
              ? () => _addParentContactSlot(father: father)
              : null,
        ),
        if (showContact2) ...[
          const SizedBox(height: 14),
          contactRow(
            contact2Controller,
            'Contact 2',
            onAdd: canAddContact3
                ? () => _addParentContactSlot(father: father)
                : null,
            onRemove: () => _removeParentContactSlot(father: father, slot: 2),
          ),
        ],
        if (_supportsParentContact3 && showContact3) ...[
          const SizedBox(height: 14),
          contactRow(
            contact3Controller,
            'Contact 3',
            onRemove: () => _removeParentContactSlot(father: father, slot: 3),
          ),
        ],
      ],
    );
  }

  Widget _buildFamilyDetailsSection() {
    return _sectionCard(
      title: 'Family details',
      icon: Icons.group_outlined,
      children: [
        TextField(
          controller: _fatherNameController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Father name (Optional)',
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: 14),
        _familyOccupationDropdown(
          labelText: 'Father occupation category (Optional)',
          father: true,
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _fatherOccupationController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Father occupation details (Optional)',
            prefixIcon: Icon(Icons.edit),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _fatherExtraInfoController,
          maxLines: 2,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Father extra info (Optional)',
            prefixIcon: Icon(Icons.notes),
          ),
        ),
        const SizedBox(height: 18),
        _buildParentContactFields(
          title: 'Father contact numbers',
          father: true,
          contact1Controller: _fatherContact1Controller,
          contact2Controller: _fatherContact2Controller,
          contact3Controller: _fatherContact3Controller,
          showContact2: _showFatherContact2,
          showContact3: _showFatherContact3,
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _motherNameController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Mother name (Optional)',
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: 14),
        _familyOccupationDropdown(
          labelText: 'Mother occupation category (Optional)',
          father: false,
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _motherOccupationController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Mother occupation details (Optional)',
            prefixIcon: Icon(Icons.edit),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _motherExtraInfoController,
          maxLines: 2,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Mother extra info (Optional)',
            prefixIcon: Icon(Icons.notes),
          ),
        ),
        const SizedBox(height: 18),
        _buildParentContactFields(
          title: 'Mother contact numbers',
          father: false,
          contact1Controller: _motherContact1Controller,
          contact2Controller: _motherContact2Controller,
          contact3Controller: _motherContact3Controller,
          showContact2: _showMotherContact2,
          showContact3: _showMotherContact3,
        ),
        const SizedBox(height: 18),
        _buildAddressRepeater(
          title: 'Parents addresses',
          rows: _parentsAddressRows,
          defaultTypeKey: 'permanent',
        ),
      ],
    );
  }

  Widget _buildFamilyOverviewSection() {
    return _sectionCard(
      title: 'Family overview',
      icon: Icons.home_outlined,
      children: [
        _intDropdown(
          labelText: 'Family type (Optional)',
          icon: Icons.group,
          options: _familyTypeOptions,
          selectedId: _selectedFamilyTypeId,
          fallbackPrefix: 'Family type',
          loading: _remainingProfileOptionsLoading,
          onChanged: (value) => setState(() => _selectedFamilyTypeId = value),
        ),
        const SizedBox(height: 14),
        _stringDropdown(
          labelText: 'Family status (Optional)',
          icon: Icons.info_outline,
          options: _familyStatusOptions,
          selectedValue: _selectedFamilyStatus,
          fallbackPrefix: 'Family status',
          loading: _remainingProfileOptionsLoading,
          onChanged: (value) => setState(() => _selectedFamilyStatus = value),
        ),
        const SizedBox(height: 14),
        _stringDropdown(
          labelText: 'Family values (Optional)',
          icon: Icons.favorite_border,
          options: _familyValueOptions,
          selectedValue: _selectedFamilyValues,
          fallbackPrefix: 'Family values',
          loading: _remainingProfileOptionsLoading,
          onChanged: (value) => setState(() => _selectedFamilyValues = value),
        ),
        const SizedBox(height: 18),
        _incomeEditor(
          title: 'Family income',
          enabled: _showFamilyIncomeGroup,
          onEnabledChanged: _setFamilyIncomeGroupEnabled,
          valueType: _selectedFamilyIncomeValueType,
          onValueTypeChanged: (value) => _selectedFamilyIncomeValueType = value,
          period: _selectedFamilyIncomePeriod,
          onPeriodChanged: (value) => _selectedFamilyIncomePeriod = value,
          amountController: _familyIncomeAmountController,
          minAmountController: _familyIncomeMinAmountController,
          maxAmountController: _familyIncomeMaxAmountController,
          currencyId: _selectedFamilyIncomeCurrencyId,
          onCurrencyChanged: (value) => _selectedFamilyIncomeCurrencyId = value,
          private: _familyIncomePrivate,
          onPrivateChanged: (value) => _familyIncomePrivate = value,
        ),
      ],
    );
  }

  Widget _buildSiblingsSection() {
    if (_selectedHasSiblings != true) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < _siblingRows.length; index++) ...[
          _buildSiblingRowEditor(index, _siblingRows[index]),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _saving ? null : () => _addSibling('brother'),
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: const Text('Add brother'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _saving ? null : () => _addSibling('sister'),
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: const Text('Add sister'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSiblingRowEditor(int index, _SiblingEditRow row) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Sibling ${index + 1}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Remove',
                onPressed: _saving ? null : () => _removeSibling(index),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _stringDropdown(
            labelText: 'Relation',
            icon: Icons.people_outline,
            options: _siblingRelationOptions(),
            selectedValue: row.relationType,
            fallbackPrefix: 'Relation',
            loading: false,
            onChanged: (value) => setState(() => row.relationType = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: row.nameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Name (Optional)',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          _stringDropdown(
            labelText: 'Marital status (Optional)',
            icon: Icons.favorite_border,
            options: _siblingMaritalStatusOptions(),
            selectedValue: row.maritalStatus,
            fallbackPrefix: 'Marital status',
            loading: false,
            onChanged: (value) => setState(() => row.maritalStatus = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: row.occupationController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Occupation (Optional)',
              prefixIcon: Icon(Icons.work_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: row.addressLineController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Address / City (Optional)',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: row.notesController,
            maxLines: 2,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Notes (Optional)',
              prefixIcon: Icon(Icons.notes_outlined),
            ),
          ),
        ],
      ),
    );
  }

  void _addSibling(String relationType) {
    setState(() {
      _selectedHasSiblings = true;
      _siblingRows.add(
        _SiblingEditRow(
          relationType: relationType,
          maritalStatus: 'unmarried',
          sortOrder: _siblingRows.length,
        ),
      );
    });
  }

  void _removeSibling(int index) {
    setState(() {
      final removed = _siblingRows.removeAt(index);
      removed.dispose();
    });
  }

  Widget _buildRelativesSection() {
    return Column(
      children: [
        _sectionCard(
          title: 'Family relatives',
          icon: Icons.people_outline,
          children: [
            for (var index = 0; index < _relativeRows.length; index++) ...[
              _buildRelativeRowEditor(index, _relativeRows[index]),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving
                        ? null
                        : () => _addRelative('paternal_uncle'),
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    label: const Text('Add paternal'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving
                        ? null
                        : () => _addRelative('maternal_uncle'),
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    label: const Text('Add maternal'),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildAlliancePropertySection(),
        const SizedBox(height: 14),
        _buildAllianceNetworkSection(),
      ],
    );
  }

  Widget _buildRelativeRowEditor(int index, _RelativeEditRow row) {
    final theme = Theme.of(context);
    final addressOnly = row.relationType == 'maternal_address_ajol';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Relative ${index + 1}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Remove',
                onPressed: _saving ? null : () => _removeRelative(index),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _stringDropdown(
            labelText: 'Relation',
            icon: Icons.people_outline,
            options: _relativeRelationOptions(),
            selectedValue: row.relationType,
            fallbackPrefix: 'Relation',
            loading: false,
            onChanged: (value) => setState(() => row.relationType = value),
          ),
          if (!addressOnly) ...[
            const SizedBox(height: 12),
            TextField(
              controller: row.nameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Name (Optional)',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: row.occupationController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Occupation (Optional)',
                prefixIcon: Icon(Icons.work_outline),
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: row.addressLineController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Address / City (Optional)',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          if (!addressOnly) ...[
            const SizedBox(height: 12),
            TextField(
              controller: row.notesController,
              maxLines: 2,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Notes (Optional)',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _addRelative(String relationType) {
    setState(() {
      _relativeRows.add(_RelativeEditRow(relationType: relationType));
    });
  }

  void _removeRelative(int index) {
    setState(() {
      final removed = _relativeRows.removeAt(index);
      removed.dispose();
    });
  }

  Widget _buildAllianceNetworkSection() {
    return _sectionCard(
      title: 'Alliance Network',
      icon: Icons.account_tree_outlined,
      children: [
        for (var index = 0; index < _allianceNetworkRows.length; index++) ...[
          _buildAllianceNetworkRowEditor(index, _allianceNetworkRows[index]),
          const SizedBox(height: 12),
        ],
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _saving ? null : _addAllianceNetwork,
            icon: const Icon(Icons.add),
            label: const Text('Add alliance family'),
          ),
        ),
      ],
    );
  }

  Widget _buildAllianceNetworkRowEditor(
    int index,
    _AllianceNetworkEditRow row,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Alliance family ${index + 1}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Remove',
                onPressed: _saving ? null : () => _removeAllianceNetwork(index),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: row.surnameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Surname',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: row.locationController,
            textInputAction: TextInputAction.next,
            onChanged: (value) => _scheduleAllianceLocationSearch(row, value),
            decoration: const InputDecoration(
              labelText: 'City / Location (Optional)',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          _buildSuggestions(
            suggestions: row.locationSuggestions,
            fallbackPrefix: 'Location',
            loading: row.locationSearching,
            onSelect: (location) => _selectAllianceLocation(row, location),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: row.notesController,
            maxLines: 2,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Notes (Optional)',
              prefixIcon: Icon(Icons.notes_outlined),
            ),
          ),
        ],
      ),
    );
  }

  void _addAllianceNetwork() {
    setState(() {
      _allianceNetworkRows.add(_AllianceNetworkEditRow());
    });
  }

  void _removeAllianceNetwork(int index) {
    setState(() {
      final removed = _allianceNetworkRows.removeAt(index);
      removed.dispose();
    });
  }

  Widget _buildAlliancePropertySection() {
    return _sectionCard(
      title: 'Alliance details',
      icon: Icons.account_tree_outlined,
      children: [
        TextField(
          controller: _otherRelativesController,
          maxLines: 3,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Other relatives (Optional)',
            helperText: 'Contact numbers किंवा private details टाकू नका.',
            prefixIcon: Icon(Icons.people_outline),
          ),
        ),
      ],
    );
  }

  Widget _buildPropertySection() {
    return _sectionCard(
      title: 'Property',
      icon: Icons.real_estate_agent_outlined,
      children: [
        TextField(
          controller: _propertyDetailsController,
          maxLines: 3,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Property details (Optional)',
            helperText: 'Public-safe summary only.',
            prefixIcon: Icon(Icons.home_outlined),
          ),
        ),
      ],
    );
  }

  Widget _buildHoroscopeAstroSection() {
    return _sectionCard(
      title: 'Horoscope',
      icon: Icons.star_border,
      children: [
        _intDropdown(
          labelText: 'Rashi (Optional)',
          icon: Icons.brightness_3,
          options: _rashiOptionsForSelection(),
          selectedId: _selectedRashiId,
          fallbackPrefix: 'Rashi',
          loading: _remainingProfileOptionsLoading,
          onChanged: _selectRashi,
        ),
        const SizedBox(height: 14),
        _intDropdown(
          labelText: 'Nakshatra (Optional)',
          icon: Icons.star_border,
          options: _nakshatraOptionsForSelection(),
          selectedId: _selectedNakshatraId,
          fallbackPrefix: 'Nakshatra',
          loading: _remainingProfileOptionsLoading,
          onChanged: _selectNakshatra,
        ),
        const SizedBox(height: 14),
        _charanDropdown(),
        const SizedBox(height: 14),
        _intDropdown(
          labelText: 'Gan (Optional)',
          icon: Icons.category,
          options: _ganOptions,
          selectedId: _selectedGanId,
          fallbackPrefix: 'Gan',
          loading: _remainingProfileOptionsLoading,
          onChanged: (value) => setState(() => _selectedGanId = value),
        ),
        const SizedBox(height: 14),
        _intDropdown(
          labelText: 'Nadi (Optional)',
          icon: Icons.opacity,
          options: _nadiOptions,
          selectedId: _selectedNadiId,
          fallbackPrefix: 'Nadi',
          loading: _remainingProfileOptionsLoading,
          onChanged: (value) => setState(() => _selectedNadiId = value),
        ),
        const SizedBox(height: 14),
        _intDropdown(
          labelText: 'Yoni (Optional)',
          icon: Icons.spa,
          options: _yoniOptionsForSelection(),
          selectedId: _selectedYoniId,
          fallbackPrefix: 'Yoni',
          loading: _remainingProfileOptionsLoading,
          onChanged: (value) => setState(() => _selectedYoniId = value),
        ),
        const SizedBox(height: 14),
        _intDropdown(
          labelText: 'Varna (Optional)',
          icon: Icons.layers,
          options: _varnaOptions,
          selectedId: _selectedVarnaId,
          fallbackPrefix: 'Varna',
          loading: _remainingProfileOptionsLoading,
          onChanged: (value) => setState(() => _selectedVarnaId = value),
        ),
        const SizedBox(height: 14),
        _intDropdown(
          labelText: 'Vashya (Optional)',
          icon: Icons.device_hub,
          options: _vashyaOptions,
          selectedId: _selectedVashyaId,
          fallbackPrefix: 'Vashya',
          loading: _remainingProfileOptionsLoading,
          onChanged: (value) => setState(() => _selectedVashyaId = value),
        ),
        const SizedBox(height: 14),
        _intDropdown(
          labelText: 'Rashi lord (Optional)',
          icon: Icons.wb_sunny,
          options: _rashiLordOptions,
          selectedId: _selectedRashiLordId,
          fallbackPrefix: 'Rashi lord',
          loading: _remainingProfileOptionsLoading,
          onChanged: (value) => setState(() => _selectedRashiLordId = value),
        ),
        const SizedBox(height: 14),
        _intDropdown(
          labelText: 'Mangal dosh type (Optional)',
          icon: Icons.warning,
          options: _mangalDoshTypeOptions,
          selectedId: _selectedMangalDoshTypeId,
          fallbackPrefix: 'Mangal dosh',
          loading: _remainingProfileOptionsLoading,
          onChanged: (value) =>
              setState(() => _selectedMangalDoshTypeId = value),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _devakController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Devak (Optional)',
            prefixIcon: Icon(Icons.account_balance_outlined),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _kulController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Kul (Optional)',
            prefixIcon: Icon(Icons.account_tree_outlined),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _gotraController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Gotra (Optional)',
            prefixIcon: Icon(Icons.account_tree_outlined),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _navrasNameController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Navras name (Optional)',
            prefixIcon: Icon(Icons.badge_outlined),
          ),
        ),
        const SizedBox(height: 14),
        _stringDropdown(
          labelText: 'Birth weekday (Optional)',
          icon: Icons.calendar_today_outlined,
          options: _birthWeekdayOptions,
          selectedValue: _selectedBirthWeekday,
          fallbackPrefix: 'Birth weekday',
          loading: _remainingProfileOptionsLoading,
          onChanged: (value) => setState(() => _selectedBirthWeekday = value),
        ),
        if (_remainingProfileOptionsLoading)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: LinearProgressIndicator(),
          ),
        if (_remainingProfileOptionsError != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _remainingProfileOptionsError!,
              style: TextStyle(color: Colors.amber.shade900),
            ),
          ),
      ],
    );
  }

  Widget _buildAboutMeSection() {
    return _sectionCard(
      title: 'About me',
      icon: Icons.notes,
      children: [
        TextField(
          controller: _aboutMeController,
          maxLines: 5,
          textInputAction: TextInputAction.newline,
          decoration: const InputDecoration(
            labelText: 'About me (Optional)',
            alignLabelWithHint: true,
            prefixIcon: Icon(Icons.edit),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoSection() {
    final photoUrl = ApiClient.resolveProfilePhotoUrl(
      _lastLoadedProfile ?? ApiClient.currentUserProfile,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ClipOval(
              child: Container(
                width: 72,
                height: 72,
                color: Colors.grey.shade100,
                child: photoUrl == null
                    ? Icon(
                        Icons.person_outline,
                        color: Colors.grey.shade600,
                        size: 36,
                      )
                    : Image.network(
                        photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.person_outline,
                          color: Colors.grey.shade600,
                          size: 36,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                photoUrl == null
                    ? 'No profile photo uploaded yet.'
                    : 'Profile photo uploaded.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _saving ? null : _openPhotoManager,
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Manage profile photo'),
          ),
        ),
      ],
    );
  }

  void _setPreferredLocationRows(List<Map<String, dynamic>> rows) {
    final next = <Map<String, dynamic>>[];
    final seen = <int>{};
    for (final row in rows) {
      final normalized = _normalizePreferredLocationRow(row);
      if (normalized == null) continue;
      final id = _readInt(normalized['id']);
      if (id == null || seen.contains(id)) continue;
      seen.add(id);
      next.add(normalized);
    }

    setState(() {
      _preferredLocationsTouched = true;
      _selectedPreferredLocationRows = next;
      _syncPreferredLocationIdSetsFromRows(_selectedPreferredLocationRows);
    });
  }

  String? _preferredLocationMetaLabel(Map<String, dynamic> row) {
    final source = _readText(row['source']);
    final distance = _readDouble(row['distance_km']);
    if (source == 'own_taluka' || distance == 0) {
      return 'Your taluka';
    }
    if (distance != null && distance > 0) {
      final rounded = distance.round();
      return rounded > 0 ? '$rounded km' : '${distance.toStringAsFixed(1)} km';
    }
    return null;
  }

  Widget _buildPreferredLocationsField() {
    final theme = Theme.of(context);
    final suggestionsAvailable = _preferredLocationSuggestionRows.isNotEmpty;
    final canReset =
        suggestionsAvailable &&
        !_sameLocationRowOrder(
          _selectedPreferredLocationRows,
          _preferredLocationSuggestionRows,
        );

    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Preferred locations (Optional)',
        prefixIcon: const Icon(Icons.place_outlined),
        border: const OutlineInputBorder(),
        helperText: _selectedPreferredLocationRows.isEmpty
            ? 'Nearby taluka suggestions backend मधून येतात.'
            : 'नको असलेले taluka save करण्यापूर्वी काढा.',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedPreferredLocationRows.isEmpty)
            Text(
              suggestionsAvailable
                  ? 'No locations selected.'
                  : 'Location suggestions are not available yet.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade700,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedPreferredLocationRows.map((row) {
                final label = _readText(row['label']) ?? 'Location';
                final meta = _preferredLocationMetaLabel(row);

                return InputChip(
                  label: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label),
                      if (meta != null)
                        Text(
                          meta,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                  avatar: const Icon(Icons.location_on_outlined, size: 18),
                  onDeleted: _saving
                      ? null
                      : () {
                          final next = _selectedPreferredLocationRows
                              .where(
                                (item) =>
                                    _readInt(item['id']) != _readInt(row['id']),
                              )
                              .toList(growable: false);
                          _setPreferredLocationRows(next);
                        },
                );
              }).toList(),
            ),
          if (suggestionsAvailable) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _saving || !canReset
                    ? null
                    : () => _setPreferredLocationRows(
                        _preferredLocationSuggestionRows,
                      ),
                icon: const Icon(Icons.refresh),
                label: const Text('Reset to suggested locations'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPartnerPreferencesSection() {
    final preferredCasteOptions = _preferredCasteOptionsForSelectedReligions();

    return _sectionCard(
      title: 'Partner Preferences',
      icon: Icons.tune_outlined,
      children: [
        _preferredAgeRangeField(),
        const SizedBox(height: 14),
        _preferredHeightRangeField(),
        const SizedBox(height: 14),
        _preferredIncomeRangeField(),
        const SizedBox(height: 14),
        _multiSelectPickerField(
          labelText: 'Preferred religions (Optional)',
          icon: Icons.temple_hindu_outlined,
          options: _preferredReligionOptions,
          selectedIds: _selectedPreferredReligionIds,
          fallbackPrefix: 'Religion',
          loading: _partnerPreferenceOptionsLoading,
          onChanged: (value) {
            setState(() {
              _selectedPreferredReligionIds
                ..clear()
                ..addAll(value);
              _removeInvalidPreferredCastes();
            });
          },
        ),
        const SizedBox(height: 14),
        if (_selectedPreferredReligionIds.isEmpty)
          const InputDecorator(
            decoration: InputDecoration(
              labelText: 'Preferred castes (Optional)',
              prefixIcon: Icon(Icons.groups_outlined),
              border: OutlineInputBorder(),
              helperText: 'Preferred caste निवडण्यासाठी आधी religion निवडा.',
            ),
            child: Text('Not selected'),
          )
        else
          _multiSelectPickerField(
            labelText: 'Preferred castes (Optional)',
            icon: Icons.groups_outlined,
            options: preferredCasteOptions,
            selectedIds: _selectedPreferredCasteIds,
            fallbackPrefix: 'Caste',
            loading: _partnerPreferenceOptionsLoading,
            onChanged: (value) {
              setState(() {
                _selectedPreferredCasteIds
                  ..clear()
                  ..addAll(value.where(_isPreferredCasteAllowed));
              });
            },
          ),
        const SizedBox(height: 14),
        _compactSwitchRow(
          title: 'Open to intercaste matches',
          icon: Icons.diversity_3_outlined,
          value: _selectedPreferredIntercaste == true,
          onChanged: (value) =>
              setState(() => _selectedPreferredIntercaste = value),
        ),
        const SizedBox(height: 14),
        _multiSelectPickerField(
          labelText: 'Preferred mother tongues (Optional)',
          icon: Icons.translate_outlined,
          options: _preferredMotherTongueOptions,
          selectedIds: _selectedPreferredMotherTongueIds,
          fallbackPrefix: 'Mother tongue',
          loading: _partnerPreferenceOptionsLoading,
          onChanged: (value) {
            setState(() {
              _selectedPreferredMotherTongueIds
                ..clear()
                ..addAll(value);
            });
          },
        ),
        const SizedBox(height: 14),
        _multiSelectPickerField(
          labelText: 'Preferred education (Optional)',
          icon: Icons.school_outlined,
          options: _preferredEducationDegreeOptions,
          selectedIds: _selectedPreferredEducationDegreeIds,
          fallbackPrefix: 'Education',
          loading: _partnerPreferenceOptionsLoading,
          onChanged: (value) {
            setState(() {
              _preferredEducationTouched = true;
              _selectedPreferredEducationDegreeIds
                ..clear()
                ..addAll(value);
            });
          },
        ),
        const SizedBox(height: 14),
        _multiSelectPickerField(
          labelText: 'Preferred occupations (Optional)',
          icon: Icons.work_outline,
          options: _preferredOccupationOptions,
          selectedIds: _selectedPreferredOccupationMasterIds,
          fallbackPrefix: 'Occupation',
          loading: _partnerPreferenceOptionsLoading,
          onChanged: (value) {
            setState(() {
              _preferredOccupationTouched = true;
              _selectedPreferredOccupationMasterIds
                ..clear()
                ..addAll(value);
            });
          },
        ),
        const SizedBox(height: 14),
        _intDropdown(
          labelText: 'Marriage type preference (Optional)',
          icon: Icons.favorite_border,
          options: _marriageTypePreferenceOptions,
          selectedId: _selectedMarriageTypePreferenceId,
          fallbackPrefix: 'Marriage type',
          loading: _partnerPreferenceOptionsLoading,
          onChanged: (value) =>
              setState(() => _selectedMarriageTypePreferenceId = value),
        ),
        const SizedBox(height: 14),
        _multiSelectChips(
          labelText: 'Preferred marital statuses (Optional)',
          icon: Icons.favorite_border,
          options: _preferredMaritalStatusOptions,
          selectedIds: _selectedPreferredMaritalStatusIds,
          fallbackPrefix: 'Marital status',
          loading: _partnerPreferenceOptionsLoading,
          onChanged: (value) {
            setState(() {
              _selectedPreferredMaritalStatusIds
                ..clear()
                ..addAll(value);
            });
          },
        ),
        const SizedBox(height: 14),
        _stringDropdown(
          labelText: 'Partner profile with children (Optional)',
          icon: Icons.child_care_outlined,
          options: _partnerProfileWithChildrenOptions,
          selectedValue: _selectedPartnerProfileWithChildren,
          fallbackPrefix: 'With children',
          loading: _partnerPreferenceOptionsLoading,
          onChanged: (value) =>
              setState(() => _selectedPartnerProfileWithChildren = value),
        ),
        const SizedBox(height: 14),
        _stringDropdown(
          labelText: 'Preferred profile managed by (Optional)',
          icon: Icons.manage_accounts_outlined,
          options: _preferredProfileManagedByOptions,
          selectedValue: _selectedPreferredProfileManagedBy,
          fallbackPrefix: 'Managed by',
          loading: _partnerPreferenceOptionsLoading,
          onChanged: (value) =>
              setState(() => _selectedPreferredProfileManagedBy = value),
        ),
        const SizedBox(height: 14),
        _compactSwitchRow(
          title: 'Willing to relocate',
          icon: Icons.flight_takeoff_outlined,
          value: _selectedWillingToRelocate == true,
          onChanged: (value) =>
              setState(() => _selectedWillingToRelocate = value),
        ),
        const SizedBox(height: 14),
        _multiSelectChips(
          labelText: 'Preferred diet (Optional)',
          icon: Icons.restaurant_outlined,
          options: _preferredDietOptions,
          selectedIds: _selectedPreferredDietIds,
          fallbackPrefix: 'Diet',
          loading: _partnerPreferenceOptionsLoading,
          onChanged: (value) {
            setState(() {
              _selectedPreferredDietIds
                ..clear()
                ..addAll(value);
            });
          },
        ),
        const SizedBox(height: 14),
        _buildPreferredLocationsField(),
        const SizedBox(height: 14),
        TextField(
          controller: _expectationsController,
          maxLines: 5,
          textInputAction: TextInputAction.newline,
          decoration: const InputDecoration(
            labelText: 'Expectations (Optional)',
            helperText: 'Partner बद्दल अपेक्षा थोडक्यात लिहा.',
            alignLabelWithHint: true,
            prefixIcon: Icon(Icons.notes_outlined),
          ),
        ),
        if (_partnerPreferenceOptionsLoading)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: LinearProgressIndicator(),
          ),
        if (_partnerPreferenceOptionsError != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _partnerPreferenceOptionsError!,
              style: TextStyle(color: Colors.amber.shade900),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_expandedSectionHasChanges(),
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBackPressed();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Edit All Profile')),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  controller: _scrollController,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_loadError != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            _loadError!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      Text(
                        'Edit profile sections',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'एकावेळी एक section edit करा. Save केल्यानंतर profile fresh reload होईल.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ..._profileSections.map(_buildSectionManagerCard),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
