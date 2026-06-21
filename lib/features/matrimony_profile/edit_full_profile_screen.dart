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

  String? _loadError;
  String? _optionsError;
  String? _educationCareerOptionsError;
  String? _selectedReligionLabel;
  String? _selectedCasteLabel;
  String? _selectedSubCasteLabel;
  String? _selectedLocationLabel;
  String? _selectedBirthPlaceLabel;
  String? _selectedEducationDegreeLabel;
  String? _selectedOccupationLabel;
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
  int? _selectedEducationDegreeId;
  int? _selectedOccupationMasterId;
  int? _selectedOccupationCustomId;

  int _subCasteSearchRequest = 0;
  int _locationSearchRequest = 0;
  int _birthPlaceSearchRequest = 0;
  int _workLocationSearchRequest = 0;

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
  List<Map<String, dynamic>> _educationDegreeOptions = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _educationSuggestions = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _occupationOptions = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _customOccupationOptions =
      <Map<String, dynamic>>[];

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
    super.dispose();
  }

  int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
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

  Future<void> _searchLocations(String query) async {
    final requestId = ++_locationSearchRequest;
    final trimmedQuery = query.trim();

    if (_selectedLocationLabel == null ||
        trimmedQuery != _selectedLocationLabel) {
      _selectedLocationId = null;
      _selectedLocationLabel = null;
    }

    if (trimmedQuery.length < 2) {
      setState(() {
        _locationSearching = false;
        _locationSuggestions = <Map<String, dynamic>>[];
      });
      return;
    }

    setState(() {
      _locationSearching = true;
    });

    try {
      final results = await ApiClient.searchLocations(trimmedQuery);
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

  Future<void> _searchBirthPlaces(String query) async {
    final requestId = ++_birthPlaceSearchRequest;
    final trimmedQuery = query.trim();

    if (_selectedBirthPlaceLabel == null ||
        trimmedQuery != _selectedBirthPlaceLabel) {
      _selectedBirthCityId = null;
      _selectedBirthPlaceLabel = null;
    }

    if (trimmedQuery.length < 2) {
      setState(() {
        _birthPlaceSearching = false;
        _birthPlaceSuggestions = <Map<String, dynamic>>[];
      });
      return;
    }

    setState(() {
      _birthPlaceSearching = true;
    });

    try {
      final results = await ApiClient.searchLocations(trimmedQuery);
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

  Future<void> _searchWorkLocations(String query) async {
    final requestId = ++_workLocationSearchRequest;
    final trimmedQuery = query.trim();

    if (_selectedWorkLocationLabel == null ||
        trimmedQuery != _selectedWorkLocationLabel) {
      _selectedWorkLocationLabel = null;
    }

    if (trimmedQuery.length < 2) {
      setState(() {
        _workLocationSearching = false;
        _workLocationSuggestions = <Map<String, dynamic>>[];
      });
      return;
    }

    setState(() {
      _workLocationSearching = true;
    });

    try {
      final results = await ApiClient.searchLocations(trimmedQuery);
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
      'occupation_master_id': _selectedOccupationMasterId,
      'occupation_custom_id': _selectedOccupationCustomId,
      'company_name': _nullableText(_companyNameController),
      'work_location_text': _nullableText(_workLocationController),
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
  }) {
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
        hintText: _optionsLoading
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
          onChanged: _searchLocations,
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
          onChanged: _searchBirthPlaces,
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
          onChanged: _searchWorkLocations,
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
                          _buildBirthSection(),
                          _buildPhysicalSection(),
                          _buildEducationCareerSection(),
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
