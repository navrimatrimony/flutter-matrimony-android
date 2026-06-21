import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_language.dart';
import '../../core/app_strings.dart';

class EditFullProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? initialProfile;

  const EditFullProfileScreen({super.key, this.initialProfile});

  @override
  State<EditFullProfileScreen> createState() => _EditFullProfileScreenState();
}

class _EditFullProfileScreenState extends State<EditFullProfileScreen> {
  static const int _clearNumberSelection = -1;
  static const Duration _locationSearchDebounceDuration = Duration(
    milliseconds: 400,
  );
  static const String _defaultPreferredStateName = 'Maharashtra';

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _religionController = TextEditingController();
  final TextEditingController _casteController = TextEditingController();
  final TextEditingController _subCasteController = TextEditingController();
  final TextEditingController _educationController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _birthTimeController = TextEditingController();
  final TextEditingController _birthPlaceController = TextEditingController();
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _workLocationController = TextEditingController();
  final TextEditingController _fatherNameController = TextEditingController();
  final TextEditingController _fatherOccupationController =
      TextEditingController();
  final TextEditingController _fatherExtraInfoController =
      TextEditingController();
  final TextEditingController _motherNameController = TextEditingController();
  final TextEditingController _motherOccupationController =
      TextEditingController();
  final TextEditingController _motherExtraInfoController =
      TextEditingController();
  final TextEditingController _familyStatusController = TextEditingController();
  final TextEditingController _familyValuesController = TextEditingController();
  final TextEditingController _otherRelativesController =
      TextEditingController();
  final TextEditingController _propertyDetailsController =
      TextEditingController();
  final TextEditingController _devakController = TextEditingController();
  final TextEditingController _kulController = TextEditingController();
  final TextEditingController _gotraController = TextEditingController();
  final TextEditingController _navrasNameController = TextEditingController();
  final TextEditingController _birthWeekdayController = TextEditingController();
  final TextEditingController _aboutMeController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _gendersLoading = false;
  bool _religionsLoading = false;
  bool _castesLoading = false;
  bool _subCasteSearching = false;
  bool _locationSearching = false;
  bool _birthPlaceSearching = false;
  bool _workLocationSearching = false;
  bool _optionsLoading = false;
  bool _educationCareerOptionsLoading = false;
  bool _maritalLifestyleOptionsLoading = false;
  bool _remainingProfileOptionsLoading = false;

  String? _loadError;
  String? _optionsError;
  String? _educationCareerOptionsError;
  String? _maritalLifestyleOptionsError;
  String? _remainingProfileOptionsError;
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
  int? _selectedDietId;
  int? _selectedSmokingStatusId;
  int? _selectedDrinkingStatusId;
  int? _selectedEducationDegreeId;
  int? _selectedOccupationMasterId;
  int? _selectedOccupationCustomId;
  int? _selectedFatherOccupationMasterId;
  int? _selectedFatherOccupationCustomId;
  int? _selectedMotherOccupationMasterId;
  int? _selectedMotherOccupationCustomId;
  int? _selectedFamilyTypeId;
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
  int? _preferredStateId;

  int _subCasteSearchRequest = 0;
  int _locationSearchRequest = 0;
  int _birthPlaceSearchRequest = 0;
  int _workLocationSearchRequest = 0;
  Timer? _locationSearchDebounce;
  Timer? _birthPlaceSearchDebounce;
  Timer? _workLocationSearchDebounce;

  List<Map<String, dynamic>> _genders = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _religions = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _religionSuggestions = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _castes = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _casteSuggestions = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _subCasteSuggestions = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _locationSuggestions = <Map<String, dynamic>>[];
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
  List<Map<String, dynamic>> _dietOptions = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _smokingStatusOptions = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _drinkingStatusOptions = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _educationDegreeOptions = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _educationSuggestions = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _occupationOptions = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _customOccupationOptions =
      <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _familyTypeOptions = <Map<String, dynamic>>[];
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
    _locationSearchDebounce?.cancel();
    _birthPlaceSearchDebounce?.cancel();
    _workLocationSearchDebounce?.cancel();
    _fullNameController.dispose();
    _dobController.dispose();
    _religionController.dispose();
    _casteController.dispose();
    _subCasteController.dispose();
    _educationController.dispose();
    _locationController.dispose();
    _birthTimeController.dispose();
    _birthPlaceController.dispose();
    _companyNameController.dispose();
    _workLocationController.dispose();
    _fatherNameController.dispose();
    _fatherOccupationController.dispose();
    _fatherExtraInfoController.dispose();
    _motherNameController.dispose();
    _motherOccupationController.dispose();
    _motherExtraInfoController.dispose();
    _familyStatusController.dispose();
    _familyValuesController.dispose();
    _otherRelativesController.dispose();
    _propertyDetailsController.dispose();
    _devakController.dispose();
    _kulController.dispose();
    _gotraController.dispose();
    _navrasNameController.dispose();
    _birthWeekdayController.dispose();
    _aboutMeController.dispose();
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

  String _optionLabel(Map<String, dynamic> row, String fallbackPrefix) {
    final localizedValue = localizedMapValue(row);
    if (localizedValue != null) return localizedValue;

    for (final key in ['label', 'label_en', 'name', 'display_label', 'key']) {
      final value = _readText(row[key]);
      if (value != null) return value;
    }

    return fallbackPrefix;
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
    _preferredStateId = _profileLocationStateId(profile);

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
    _selectedHasChildren = _readBool(profile['has_children']);
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
    _selectedWorkLocationLabel =
        ApiClient.safeDisplayLabel(profile['work_location_label']) ??
        ApiClient.safeDisplayLabel(profile['work_location_text']);
    _fatherNameController.text =
        ApiClient.safeDisplayLabel(profile['father_name']) ?? '';
    _fatherOccupationController.text =
        ApiClient.safeDisplayLabel(profile['father_occupation']) ?? '';
    _fatherExtraInfoController.text =
        ApiClient.safeDisplayLabel(profile['father_extra_info']) ?? '';
    _motherNameController.text =
        ApiClient.safeDisplayLabel(profile['mother_name']) ?? '';
    _motherOccupationController.text =
        ApiClient.safeDisplayLabel(profile['mother_occupation']) ?? '';
    _motherExtraInfoController.text =
        ApiClient.safeDisplayLabel(profile['mother_extra_info']) ?? '';
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
    _familyStatusController.text =
        ApiClient.safeDisplayLabel(profile['family_status']) ?? '';
    _familyValuesController.text =
        ApiClient.safeDisplayLabel(profile['family_values']) ?? '';
    _selectedHasSiblings = _readBool(profile['has_siblings']);
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
    _birthWeekdayController.text =
        ApiClient.safeDisplayLabel(profile['birth_weekday']) ?? '';
    _aboutMeController.text =
        ApiClient.safeDisplayLabel(profile['narrative_about_me']) ?? '';
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
        _syncSelectedEducationFromText();
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
        _familyTypeOptions =
            results['family_types'] ?? <Map<String, dynamic>>[];
        _familyOccupationOptions =
            results['occupations'] ?? <Map<String, dynamic>>[];
        _familyCustomOccupationOptions =
            results['custom_occupations'] ?? <Map<String, dynamic>>[];
        _rashiOptions = results['rashis'] ?? <Map<String, dynamic>>[];
        _nakshatraOptions = results['nakshatras'] ?? <Map<String, dynamic>>[];
        _ganOptions = results['gans'] ?? <Map<String, dynamic>>[];
        _nadiOptions = results['nadis'] ?? <Map<String, dynamic>>[];
        _yoniOptions = results['yonis'] ?? <Map<String, dynamic>>[];
        _varnaOptions = results['varnas'] ?? <Map<String, dynamic>>[];
        _vashyaOptions = results['vashyas'] ?? <Map<String, dynamic>>[];
        _rashiLordOptions = results['rashi_lords'] ?? <Map<String, dynamic>>[];
        _mangalDoshTypeOptions =
            results['mangal_dosh_types'] ?? <Map<String, dynamic>>[];
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

  void _scheduleLocationSearch(String query) {
    _locationSearchDebounce?.cancel();
    final requestId = ++_locationSearchRequest;
    final trimmedQuery = query.trim();

    setState(() {
      if (_selectedLocationLabel == null ||
          trimmedQuery != _selectedLocationLabel) {
        _selectedLocationId = null;
        _selectedLocationLabel = null;
      }
      if (trimmedQuery.length < 2) {
        _locationSearching = false;
        _locationSuggestions = <Map<String, dynamic>>[];
      } else {
        _locationSearching = true;
      }
    });

    if (trimmedQuery.length < 2) {
      return;
    }

    _locationSearchDebounce = Timer(_locationSearchDebounceDuration, () {
      _runLocationSearch(trimmedQuery, requestId);
    });
  }

  Future<void> _runLocationSearch(String trimmedQuery, int requestId) async {
    try {
      final results = await _searchLocationOptions(trimmedQuery);
      if (!mounted || requestId != _locationSearchRequest) return;
      setState(() {
        _locationSuggestions = results;
        _locationSearching = false;
      });
    } catch (_) {
      if (!mounted || requestId != _locationSearchRequest) return;
      setState(() {
        _locationSearching = false;
        _locationSuggestions = <Map<String, dynamic>>[];
      });
    }
  }

  void _selectLocation(Map<String, dynamic> location) {
    final locationId = ApiClient.locationIdFrom(location);
    if (locationId == null) return;

    final label = _locationLabel(location);
    setState(() {
      _selectedLocationId = locationId;
      _selectedLocationLabel = label;
      _locationController.text = label;
      _locationSuggestions = <Map<String, dynamic>>[];
      _locationSearching = false;
      _preferredStateId = _locationStateId(location) ?? _preferredStateId;
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
    if (_selectedLocationId == null) {
      _showMessage('कृपया suggestions मधून location निवडा.');
      return false;
    }
    return true;
  }

  String? _nullableText(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
  }

  Future<void> _saveProfile() async {
    if (!_validateRequiredFields()) return;

    setState(() {
      _saving = true;
    });

    final casteLabel = _selectedCasteLabel?.trim().isNotEmpty == true
        ? _selectedCasteLabel!.trim()
        : _casteController.text.trim();
    final educationText = _educationController.text.trim();
    final educationDegreeId =
        _selectedEducationDegreeId ??
        _findEducationDegreeIdByText(educationText);

    final payload = <String, dynamic>{
      'full_name': _fullNameController.text.trim(),
      'gender_id': _selectedGenderId,
      'date_of_birth': _dobController.text.trim(),
      'religion_id': _selectedReligionId,
      'caste_id': _selectedCasteId,
      'caste': casteLabel,
      'highest_education': educationText,
      'location_id': _selectedLocationId,
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
      'has_children': _selectedHasChildren,
      'diet_id': _selectedDietId,
      'smoking_status_id': _selectedSmokingStatusId,
      'drinking_status_id': _selectedDrinkingStatusId,
      'occupation_master_id': _selectedOccupationMasterId,
      'occupation_custom_id': _selectedOccupationCustomId,
      'company_name': _nullableText(_companyNameController),
      'work_location_text': _nullableText(_workLocationController),
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
      'family_status': _nullableText(_familyStatusController),
      'family_values': _nullableText(_familyValuesController),
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
      'birth_weekday': _nullableText(_birthWeekdayController),
      'narrative_about_me': _nullableText(_aboutMeController),
    };

    if (educationDegreeId != null) {
      payload['education_slots'] = jsonEncode([
        {'t': 'd', 'id': educationDegreeId},
      ]);
    }

    Map<String, dynamic> response;
    try {
      response = await ApiClient.updateMatrimonyProfile(payload);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
      });
      _showMessage('Profile save करता आली नाही. कृपया पुन्हा प्रयत्न करा.');
      return;
    }

    if (!mounted) return;
    setState(() {
      _saving = false;
    });

    if (response['success'] == true) {
      try {
        await ApiClient.getMyProfile();
      } catch (_) {
        // Save already succeeded; the destination screen also performs a reload.
      }
      if (!mounted) return;
      _showMessage('Profile update यशस्वी!');
      Navigator.pushReplacementNamed(context, '/view-profile');
    } else {
      _showMessage(response['message']?.toString() ?? 'Profile save failed');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
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
  }) {
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
        hintText: _optionsLoading
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

  Widget _boolDropdown({
    required String labelText,
    required IconData icon,
    required bool? selectedValue,
    required ValueChanged<bool?> onChanged,
  }) {
    final selectedKey = selectedValue == null ? -1 : (selectedValue ? 1 : 0);

    return DropdownButtonFormField<int>(
      key: ValueKey('$labelText-${selectedValue?.toString() ?? 'none'}'),
      initialValue: selectedKey,
      isExpanded: true,
      items: const [
        DropdownMenuItem<int>(value: -1, child: Text('Not selected')),
        DropdownMenuItem<int>(value: 0, child: Text('No')),
        DropdownMenuItem<int>(value: 1, child: Text('Yes')),
      ],
      onChanged: _saving
          ? null
          : (value) {
              if (value == null || value < 0) {
                onChanged(null);
              } else {
                onChanged(value == 1);
              }
            },
      decoration: InputDecoration(
        labelText: labelText,
        hintText: 'Optional',
        prefixIcon: Icon(icon),
      ),
    );
  }

  Widget _buildMaritalLifestyleSection() {
    return _sectionCard(
      title: 'Marital & Lifestyle',
      icon: Icons.favorite_border,
      children: [
        _intDropdown(
          labelText: 'Marital status (Optional)',
          icon: Icons.favorite_border,
          options: _maritalStatusOptions,
          selectedId: _selectedMaritalStatusId,
          fallbackPrefix: 'Marital status',
          loading: _maritalLifestyleOptionsLoading,
          onChanged: (value) =>
              setState(() => _selectedMaritalStatusId = value),
        ),
        const SizedBox(height: 14),
        _boolDropdown(
          labelText: 'Has children (Optional)',
          icon: Icons.child_care_outlined,
          selectedValue: _selectedHasChildren,
          onChanged: (value) => setState(() => _selectedHasChildren = value),
        ),
        const SizedBox(height: 14),
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
        const SizedBox(height: 14),
        TextField(
          controller: _locationController,
          decoration: const InputDecoration(
            labelText: 'Current location',
            prefixIcon: Icon(Icons.location_on_outlined),
          ),
          onChanged: _scheduleLocationSearch,
        ),
        _buildSuggestions(
          suggestions: _locationSuggestions,
          fallbackPrefix: 'Location',
          loading: _locationSearching,
          onSelect: _selectLocation,
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

  Widget _charanDropdown() {
    return DropdownButtonFormField<int>(
      key: ValueKey('charan-${_selectedCharan ?? 'none'}'),
      initialValue:
          _selectedCharan != null &&
              _selectedCharan! >= 1 &&
              _selectedCharan! <= 4
          ? _selectedCharan
          : null,
      isExpanded: true,
      items: const [
        DropdownMenuItem<int>(value: 1, child: Text('1')),
        DropdownMenuItem<int>(value: 2, child: Text('2')),
        DropdownMenuItem<int>(value: 3, child: Text('3')),
        DropdownMenuItem<int>(value: 4, child: Text('4')),
      ],
      onChanged: _saving
          ? null
          : (value) => setState(() => _selectedCharan = value),
      decoration: InputDecoration(
        labelText: 'Charan (Optional)',
        hintText: 'Optional',
        prefixIcon: const Icon(Icons.filter_4),
        suffixIcon: _selectedCharan == null || _saving
            ? null
            : IconButton(
                tooltip: 'Clear charan',
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _selectedCharan = null),
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
          labelText: 'Father occupation (Optional)',
          father: true,
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _fatherOccupationController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Father occupation text (Optional)',
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
          labelText: 'Mother occupation (Optional)',
          father: false,
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _motherOccupationController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Mother occupation text (Optional)',
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
        TextField(
          controller: _familyStatusController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Family status (Optional)',
            prefixIcon: Icon(Icons.info_outline),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _familyValuesController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Family values (Optional)',
            prefixIcon: Icon(Icons.favorite_border),
          ),
        ),
        const SizedBox(height: 14),
        _boolDropdown(
          labelText: 'Has siblings (Optional)',
          icon: Icons.people,
          selectedValue: _selectedHasSiblings,
          onChanged: (value) => setState(() => _selectedHasSiblings = value),
        ),
      ],
    );
  }

  Widget _buildAlliancePropertySection() {
    return _sectionCard(
      title: 'Alliance & Property',
      icon: Icons.home_outlined,
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
        const SizedBox(height: 14),
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
      title: 'Horoscope / Astro',
      icon: Icons.star_border,
      children: [
        _intDropdown(
          labelText: 'Rashi (Optional)',
          icon: Icons.brightness_3,
          options: _rashiOptions,
          selectedId: _selectedRashiId,
          fallbackPrefix: 'Rashi',
          loading: _remainingProfileOptionsLoading,
          onChanged: (value) => setState(() => _selectedRashiId = value),
        ),
        const SizedBox(height: 14),
        _intDropdown(
          labelText: 'Nakshatra (Optional)',
          icon: Icons.star_border,
          options: _nakshatraOptions,
          selectedId: _selectedNakshatraId,
          fallbackPrefix: 'Nakshatra',
          loading: _remainingProfileOptionsLoading,
          onChanged: (value) => setState(() => _selectedNakshatraId = value),
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
          options: _yoniOptions,
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
        TextField(
          controller: _birthWeekdayController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Birth weekday (Optional)',
            helperText: 'Backend options नसल्यामुळे text म्हणून save होते.',
            prefixIcon: Icon(Icons.calendar_today_outlined),
          ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit All Profile')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  if (_loadError != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _loadError!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  Expanded(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                      child: Column(
                        children: [
                          _buildBasicSection(),
                          _buildMaritalLifestyleSection(),
                          _buildBirthSection(),
                          _buildPhysicalSection(),
                          _buildEducationCareerSection(),
                          _buildFamilyDetailsSection(),
                          _buildFamilyOverviewSection(),
                          _buildAlliancePropertySection(),
                          _buildHoroscopeAstroSection(),
                          _buildAboutMeSection(),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 18,
                          offset: const Offset(0, -6),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      top: false,
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _saveProfile,
                          child: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Save Profile'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
