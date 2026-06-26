import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api_client.dart';
import '../models/onboarding_option.dart';
import '../models/paged_lookup_response.dart';
import '../widgets/onboarding_picker_field.dart';
import '../widgets/smart_picker_panel.dart';
import 'onboarding_step_helpers.dart';
import 'onboarding_step_scaffold.dart';

class LocationStep extends StatefulWidget {
  const LocationStep({
    super.key,
    required this.data,
    required this.locale,
    required this.loading,
    required this.onSave,
    required this.onBack,
    required this.onMessage,
  });

  final Map<String, dynamic> data;
  final String locale;
  final bool loading;
  final OnboardingStepSaver onSave;
  final VoidCallback onBack;
  final ValueChanged<String> onMessage;

  @override
  State<LocationStep> createState() => _LocationStepState();
}

class _LocationStepState extends State<LocationStep> {
  static const MethodChannel _nativeLocationChannel = MethodChannel(
    'navri_matrimony/native_location',
  );

  final TextEditingController _addressLineController = TextEditingController();

  OnboardingOption? _country;
  OnboardingOption? _state;
  OnboardingOption? _district;
  OnboardingOption? _localArea;
  OnboardingOption? _village;

  List<OnboardingOption> _allStates = const <OnboardingOption>[];
  List<OnboardingOption> _districts = const <OnboardingOption>[];
  List<OnboardingOption> _talukas = const <OnboardingOption>[];

  int? _districtsForStateId;
  int? _talukasForDistrictId;
  int? _pendingLocationRequestId;
  String? _pendingLocationLabel;
  String? _pendingLocationStatus;
  String? _pendingLocationType;
  bool _usingMobileLocation = false;

  bool get _mr => widget.locale == 'mr';
  bool get _hasPendingLocation =>
      _pendingLocationRequestId != null || _pendingLocationStatus == 'pending';
  bool get _showVillagePicker => _locationType(_localArea) == 'taluka';

  @override
  void initState() {
    super.initState();
    _prefill();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDefaultCountryState();
    });
  }

  @override
  void didUpdateWidget(covariant LocationStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!mapEquals(oldWidget.data, widget.data)) {
      _prefill();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadDefaultCountryState();
      });
    }
  }

  @override
  void dispose() {
    _addressLineController.dispose();
    super.dispose();
  }

  void _prefill() {
    final data = widget.data;
    _addressLineController.text = onboardingText(data['address_line']) ?? '';
    _pendingLocationRequestId = onboardingInt(
      data['pending_location_request_id'],
    );
    _pendingLocationLabel = onboardingText(data['pending_location_label']);
    _pendingLocationStatus = onboardingText(data['pending_location_status']);
    _pendingLocationType = onboardingText(data['pending_location_type']);

    final location =
        optionFromData(data['location_option']) ??
        _placeholder(data['location_id']);
    _clearHierarchy();
    final country = optionFromData(data['country_option']);
    final state = optionFromData(data['state_option']);
    final district = optionFromData(data['district_option']);
    final localArea = optionFromData(data['local_area_option']);
    final village = optionFromData(data['village_option']);
    if (country != null ||
        state != null ||
        district != null ||
        localArea != null ||
        village != null) {
      _country = country;
      _state = state;
      _district = district;
      _localArea = localArea;
      _village = village;
    } else if (location != null && _locationType(location) != 'unknown') {
      _setHierarchyFromLocation(location);
    }
  }

  String _t(String en, String mr) => _mr ? mr : en;
  String get _addLocationLabel =>
      _t('Add new location', 'नवीन location entry करा');

  String _locationNotFoundTitle(String query) {
    final text = query.trim();
    if (text.isNotEmpty) {
      return _t(
        '$text not found. Add new location.',
        '$text सापडले नाही. नवीन location entry करा.',
      );
    }

    return _t('No locations found.', 'ठिकाण सापडले नाही.');
  }

  String _emptyLocationMessage(String query) => '';

  List<SmartPickerFilterOption> get _districtLevelFilters =>
      <SmartPickerFilterOption>[
        SmartPickerFilterOption(key: 'all', label: _t('All', 'सर्व')),
        SmartPickerFilterOption(key: 'taluka', label: _t('Taluka', 'तालुका')),
        SmartPickerFilterOption(
          key: 'urban',
          label: _t('City / Suburban', 'शहर / उपनगर'),
        ),
      ];

  List<SmartPickerFilterOption> get _talukaLevelFilters =>
      <SmartPickerFilterOption>[
        SmartPickerFilterOption(key: 'all', label: _t('All', 'सर्व')),
        SmartPickerFilterOption(
          key: 'urban',
          label: _t('City / Suburban', 'शहर / उपनगर'),
        ),
        SmartPickerFilterOption(key: 'rural', label: _t('Rural', 'ग्रामीण')),
      ];

  OnboardingOption? _placeholder(dynamic id) {
    return selectedValuePlaceholderOption(
      id,
      widget.locale,
      failed: true,
      meta: const <String, dynamic>{'type': 'unknown'},
    );
  }

  void _clearHierarchy() {
    _country = null;
    _state = null;
    _district = null;
    _localArea = null;
    _village = null;
    _districts = const <OnboardingOption>[];
    _talukas = const <OnboardingOption>[];
    _districtsForStateId = null;
    _talukasForDistrictId = null;
  }

  bool _locationEnabled(OnboardingOption option) {
    if (_isPendingLocationOption(option)) return true;
    return option.metaBool('is_final_node') == true &&
        option.metaText('status') == 'approved';
  }

  bool _isPendingLocationOption(OnboardingOption option) {
    return option.metaBool('is_pending_location') == true ||
        option.metaBool('is_custom_location') == true ||
        option.metaText('status') == 'pending';
  }

  String? _locationType(OnboardingOption? option) {
    if (option == null) return null;
    return option.metaText('type') ??
        option.metaText('hierarchy') ??
        onboardingText(option.raw['hierarchy']);
  }

  bool _isApprovedRow(OnboardingOption option) {
    final status = option.metaText('status');
    return status == null || status == 'approved';
  }

  int? _parentId(OnboardingOption? option) => option?.metaInt('parent_id');

  Future<void> _loadDefaultCountryState() async {
    try {
      if (!mounted) return;

      final country = _country ?? await _findLocationByType('India', 'country');
      if (!mounted) return;
      if (_country == null && country != null) {
        setState(() => _country = country);
      }

      if (_state != null) {
        final state = _state;
        if (state != null) {
          await _ensureDistrictsForState(state);
        }
        final district = _district;
        if (district != null) {
          await _ensureTalukasForDistrict(district);
        }
        return;
      }

      final states = await _ensureStates();
      if (!mounted || _state != null) return;

      final countryId = country?.intId;
      final state = _findNamedOption(
        states.where((option) {
          if (countryId == null) return true;
          return _parentId(option) == countryId;
        }).toList(),
        'Maharashtra',
      );

      if (!mounted || state == null) return;
      setState(() {
        _country =
            country ??
            OnboardingOption(
              id: _parentId(state),
              label: 'India',
              meta: const <String, dynamic>{
                'type': 'country',
                'status': 'approved',
              },
            );
        _state = state;
        _district = null;
        _localArea = null;
        _village = null;
      });
      await _ensureDistrictsForState(state);
    } catch (_) {
      // The pickers can still load on demand and display their own retry state.
    }
  }

  Future<List<OnboardingOption>> _ensureStates() async {
    if (_allStates.isNotEmpty) return _allStates;
    final rows = await ApiClient.getInternalLocationStates();
    final options = rows
        .map((row) => _hierarchyOption(row, 'state'))
        .where((option) => option.intId != null)
        .toList();
    if (mounted) {
      setState(() => _allStates = options);
    } else {
      _allStates = options;
    }
    return options;
  }

  Future<List<OnboardingOption>> _ensureDistrictsForState(
    OnboardingOption state,
  ) async {
    final stateId = state.intId;
    if (stateId == null) return const <OnboardingOption>[];
    if (_districtsForStateId == stateId) return _districts;

    final rows = await ApiClient.getInternalLocationDistricts(stateId: stateId);
    final options = rows
        .map((row) => _hierarchyOption(row, 'district'))
        .where((option) => option.intId != null)
        .toList();
    if (mounted) {
      setState(() {
        _districts = options;
        _districtsForStateId = stateId;
      });
    } else {
      _districts = options;
      _districtsForStateId = stateId;
    }
    return options;
  }

  Future<List<OnboardingOption>> _ensureTalukasForDistrict(
    OnboardingOption district,
  ) async {
    final districtId = district.intId;
    if (districtId == null) return const <OnboardingOption>[];
    if (_talukasForDistrictId == districtId) return _talukas;

    final rows = await ApiClient.getInternalLocationTalukas(
      districtId: districtId,
    );
    final options = rows
        .map((row) => _hierarchyOption(row, 'taluka'))
        .where((option) => option.intId != null)
        .toList();
    if (mounted) {
      setState(() {
        _talukas = options;
        _talukasForDistrictId = districtId;
      });
    } else {
      _talukas = options;
      _talukasForDistrictId = districtId;
    }
    return options;
  }

  OnboardingOption _hierarchyOption(Map<String, dynamic> row, String type) {
    final id = onboardingInt(row['id'] ?? row['location_id']);
    final label =
        onboardingText(row['label'] ?? row['name'] ?? row['display_label']) ??
        onboardingSelectedFailureLabel(widget.locale);
    final parentId = onboardingInt(row['parent_id']);

    return OnboardingOption(
      id: id,
      key: onboardingText(row['slug'] ?? row['key']),
      label: label,
      meta: <String, dynamic>{
        'type': type,
        'hierarchy': type,
        'status': 'approved',
        'is_final_node': false,
        if (parentId != null) 'parent_id': parentId,
      },
      raw: <String, dynamic>{
        ...row,
        'id': id,
        'location_id': id,
        'label': label,
        'type': type,
        'hierarchy': type,
        if (parentId != null) 'parent_id': parentId,
      },
    );
  }

  Future<OnboardingOption?> _findLocationByType(
    String query,
    String type,
  ) async {
    final page = await _locationPage(query, 1, 20);
    for (final option in page.results) {
      if (_locationType(option) == type && _isApprovedRow(option)) {
        return option;
      }
    }
    return null;
  }

  OnboardingOption? _findNamedOption(
    List<OnboardingOption> options,
    String name,
  ) {
    final wanted = name.trim().toLowerCase();
    for (final option in options) {
      if (option.label.trim().toLowerCase() == wanted) return option;
    }
    for (final option in options) {
      if (option.label.trim().toLowerCase().contains(wanted)) return option;
    }
    return null;
  }

  Future<PagedLookupResponse> _locationPage(
    String query,
    int page,
    int limit,
  ) async {
    if (query.trim().length < 2) {
      return PagedLookupResponse.fromOptions(const []);
    }
    return PagedLookupResponse.fromJson(
      await ApiClient.searchLocationsForOnboarding(
        query: query,
        page: page,
        limit: limit,
        locale: widget.locale,
      ),
    );
  }

  Future<PagedLookupResponse> _childrenPage({
    required OnboardingOption parent,
    required String query,
    required int page,
    required int limit,
    String? filter,
  }) async {
    final parentId = parent.intId;
    if (parentId == null) return PagedLookupResponse.fromOptions(const []);

    return PagedLookupResponse.fromJson(
      await ApiClient.getInternalLocationChildren(
        parentId: parentId,
        query: query.trim().length < 2 ? null : query.trim(),
        page: page,
        limit: limit,
        locale: widget.locale,
        filter: filter == null || filter == 'all' ? null : filter,
      ),
    );
  }

  Future<PagedLookupResponse> _countryPage(
    String query,
    int page,
    int limit,
  ) async {
    if (query.trim().length < 2) {
      return PagedLookupResponse.fromOptions(
        _country == null ? const [] : [_country!],
      );
    }

    final response = await _locationPage(query, page, limit);
    return PagedLookupResponse(
      success: response.success,
      locale: response.locale,
      results: response.results
          .where((option) => _locationType(option) == 'country')
          .toList(),
      pagination: const LookupPagination(hasMore: false),
      message: response.message,
      raw: response.raw,
    );
  }

  Future<PagedLookupResponse> _statePage(
    String query,
    int page,
    int limit,
  ) async {
    final states = await _ensureStates();
    final countryId = _country?.intId;
    final filtered = countryId == null
        ? states
        : states.where((option) => _parentId(option) == countryId).toList();
    return _optionPage(filtered, query, page, limit);
  }

  Future<PagedLookupResponse> _districtPage(
    String query,
    int page,
    int limit,
  ) async {
    final state = _state;
    if (state == null) return PagedLookupResponse.fromOptions(const []);
    final districts = await _ensureDistrictsForState(state);
    return _optionPage(districts, query, page, limit);
  }

  Future<PagedLookupResponse> _localAreaPage(
    String query,
    int page,
    int limit,
  ) {
    return _localAreaFilteredPage(query, page, limit, null);
  }

  Future<PagedLookupResponse> _localAreaFilteredPage(
    String query,
    int page,
    int limit,
    String? filter,
  ) async {
    final district = _district;
    if (district == null) return PagedLookupResponse.fromOptions(const []);

    final trimmed = query.trim();
    final response = await _childrenPage(
      parent: district,
      query: trimmed,
      page: page,
      limit: limit,
      filter: filter,
    );

    return PagedLookupResponse(
      success: response.success,
      locale: response.locale,
      results: _uniqueOptions(response.results),
      pagination: response.pagination,
      message: response.message,
      raw: response.raw,
    );
  }

  Future<PagedLookupResponse> _villagePage(String query, int page, int limit) {
    return _villageFilteredPage(query, page, limit, null);
  }

  Future<PagedLookupResponse> _villageFilteredPage(
    String query,
    int page,
    int limit,
    String? filter,
  ) async {
    final localArea = _localArea;
    if (!_showVillagePicker || localArea == null || localArea.intId == null) {
      return PagedLookupResponse.fromOptions(const []);
    }
    final trimmed = query.trim();
    final response = await _childrenPage(
      parent: localArea,
      query: trimmed,
      page: page,
      limit: limit,
      filter: filter,
    );
    return PagedLookupResponse(
      success: response.success,
      locale: response.locale,
      results: _uniqueOptions(response.results),
      pagination: response.pagination,
      message: response.message,
      raw: response.raw,
    );
  }

  PagedLookupResponse _optionPage(
    List<OnboardingOption> options,
    String query,
    int page,
    int limit,
  ) {
    final q = query.trim().toLowerCase();
    final rows = options.where((option) {
      return q.isEmpty ||
          option.label.toLowerCase().startsWith(q) ||
          (option.key?.toLowerCase().startsWith(q) ?? false);
    }).toList();
    final start = (page - 1) * limit;
    final pageRows = start >= rows.length
        ? <OnboardingOption>[]
        : rows.skip(start).take(limit).toList();
    return PagedLookupResponse(
      success: true,
      results: pageRows,
      pagination: LookupPagination(
        page: page,
        perPage: limit,
        total: rows.length,
        hasMore: start + pageRows.length < rows.length,
      ),
    );
  }

  List<OnboardingOption> _uniqueOptions(List<OnboardingOption> options) {
    final seen = <String>{};
    final out = <OnboardingOption>[];
    for (final option in options) {
      if (seen.add(option.identity)) out.add(option);
    }
    return out;
  }

  Future<void> _save() async {
    final localArea = _localArea;
    final selectedLocation =
        _village ??
        (localArea != null && _locationEnabled(localArea) ? localArea : null);
    if (selectedLocation == null || !_locationEnabled(selectedLocation)) {
      if (_localArea != null || _district != null) {
        widget.onMessage(
          _t(
            'Select a city, suburb, village, or add your location.',
            'शहर, उपनगर, गाव निवडा किंवा तुमचे location add करा.',
          ),
        );
        return;
      }
      widget.onMessage(
        _t('Select district and location.', 'जिल्हा आणि ठिकाण निवडा.'),
      );
      return;
    }

    final isPendingLocation = _isPendingLocationOption(selectedLocation);
    final pendingDisplayLabel = _pendingLocationDisplayLabel(selectedLocation);
    final pendingSimpleLabel = _pendingLocationSimpleLabel(selectedLocation);
    final addressLine = _addressLineController.text.trim();
    final payload = compactPayload({
      'location_id': isPendingLocation ? null : selectedLocation.intId,
      'address_line': isPendingLocation && addressLine.isEmpty
          ? pendingDisplayLabel
          : addressLine,
      'location_option': selectedLocation.toJson(),
      if (_country?.intId != null) 'country_option': _country!.toJson(),
      if (_state?.intId != null) 'state_option': _state!.toJson(),
      if (_district?.intId != null) 'district_option': _district!.toJson(),
      if (_localArea != null) 'local_area_option': _localArea!.toJson(),
      if (_village != null) 'village_option': _village!.toJson(),
    });
    if (isPendingLocation) {
      payload['location_id'] = null;
      payload.addAll({
        'pending_location_request_id':
            selectedLocation.metaInt('pending_location_request_id') ??
            _pendingLocationRequestId,
        'pending_location_label': pendingSimpleLabel,
        'pending_location_status':
            selectedLocation.metaText('pending_location_status') ??
            selectedLocation.metaText('status') ??
            _pendingLocationStatus ??
            'pending',
        'pending_location_type':
            selectedLocation.metaText('pending_location_type') ??
            _pendingLocationType ??
            _locationType(selectedLocation) ??
            'village',
      });
    } else {
      payload.addAll(const {
        'pending_location_request_id': null,
        'pending_location_label': null,
        'pending_location_status': null,
        'pending_location_type': null,
      });
    }

    await widget.onSave('location', payload, saveProfile: true);
  }

  String _pendingLocationDisplayLabel(OnboardingOption option) {
    return option.metaText('pending_location_display_label') ??
        option.metaText('profile_display_label') ??
        option.metaText('display_label') ??
        option.metaText('location_label') ??
        option.metaText('pending_location_label') ??
        _pendingLocationLabel ??
        option.label;
  }

  String _pendingLocationSimpleLabel(OnboardingOption option) {
    return option.metaText('pending_location_label') ?? option.label;
  }

  String _customLocationDisplayLabel(
    String locationName, {
    required OnboardingOption district,
    OnboardingOption? taluka,
  }) {
    return _joinLocationDisplayParts([
      locationName,
      if (taluka != null) taluka.label,
      district.label,
    ]);
  }

  String _joinLocationDisplayParts(List<String> parts) {
    final clean = <String>[];
    for (final part in parts) {
      final value = part.trim();
      if (value.isEmpty) continue;
      final last = clean.isEmpty ? null : clean.last.toLowerCase();
      if (last != null && last == value.toLowerCase()) continue;
      clean.add(value);
    }
    return clean.join(', ');
  }

  Future<void> _useMobileLocation() async {
    if (_usingMobileLocation || widget.loading) return;
    setState(() => _usingMobileLocation = true);

    try {
      final data = await _nativeLocationChannel
          .invokeMapMethod<String, dynamic>('getApproximateLocation');
      if (!mounted) return;
      if (data == null) {
        widget.onMessage(
          _t('Could not read mobile location.', 'मोबाईल location मिळाली नाही.'),
        );
        return;
      }

      OnboardingOption? match;
      try {
        match = await _findMobileLocationMatch(data);
      } catch (_) {
        match = null;
      }
      if (!mounted) return;
      if (match == null) {
        var hierarchyFilled = false;
        try {
          hierarchyFilled = await _fillMobileKnownHierarchy(data);
        } catch (_) {
          hierarchyFilled = false;
        }
        if (!mounted) return;
        final addressFilled = _fillMobileAddressLine(data);
        if (hierarchyFilled || addressFilled) {
          widget.onMessage(
            _t(
              'We found your mobile location. Please select the nearest location from the list.',
              'मोबाईल location मिळाले. कृपया यादीतून जवळचे ठिकाण निवडा.',
            ),
          );
          return;
        }
        widget.onMessage(
          _t('Could not read mobile location.', 'मोबाईल location मिळाली नाही.'),
        );
        return;
      }

      await _applyLocationOption(match, mobileData: data);
      if (!mounted) return;
      widget.onMessage(
        _t(
          'Mobile location matched. Please review it before continuing.',
          'मोबाईल location match झाली. Continue करण्यापूर्वी तपासा.',
        ),
      );
    } on PlatformException catch (error) {
      if (!mounted) return;
      if (error.code == 'LOCATION_DISABLED') {
        await _openLocationSettings();
      }
      if (!mounted) return;
      widget.onMessage(_nativeLocationErrorMessage(error));
    } catch (_) {
      if (!mounted) return;
      widget.onMessage(
        _t(
          'Could not use mobile location.',
          'मोबाईल location वापरता आली नाही.',
        ),
      );
    } finally {
      if (mounted) setState(() => _usingMobileLocation = false);
    }
  }

  Future<void> _openLocationSettings() async {
    try {
      await _nativeLocationChannel.invokeMethod<bool>('openLocationSettings');
    } catch (_) {
      // The message still tells the user what to do if Android settings cannot open.
    }
  }

  Future<OnboardingOption?> _findMobileLocationMatch(
    Map<String, dynamic> data,
  ) async {
    for (final term in _mobileLocationSearchTerms(data)) {
      final page = await _locationPage(term, 1, 12);
      final match = _bestMobileLocationMatch(page.results, data, term);
      if (match != null) return match;
    }
    return null;
  }

  OnboardingOption? _bestMobileLocationMatch(
    List<OnboardingOption> options,
    Map<String, dynamic> data,
    String searchTerm,
  ) {
    final approved = options.where(_locationEnabled).toList();
    if (approved.isEmpty) return null;
    approved.sort(
      (a, b) => _mobileLocationScore(
        b,
        data,
        searchTerm,
      ).compareTo(_mobileLocationScore(a, data, searchTerm)),
    );
    final best = approved.first;
    return _mobileLocationScore(best, data, searchTerm) > 0 ? best : null;
  }

  int _mobileLocationScore(
    OnboardingOption option,
    Map<String, dynamic> data,
    String searchTerm,
  ) {
    final haystack = [
      option.label,
      option.metaText('display_hierarchy'),
      option.metaText('type'),
      option.metaText('tag'),
      _parentLabel(option, 'state'),
      _parentLabel(option, 'district'),
      _parentLabel(option, 'taluka'),
      _parentLabel(option, 'city'),
    ].whereType<String>().join(' ').toLowerCase();

    var score = 0;
    final normalizedSearchTerm = searchTerm.trim().toLowerCase();
    if (normalizedSearchTerm.isNotEmpty &&
        haystack.contains(normalizedSearchTerm)) {
      score += 6;
    }
    for (final entry in const [
      MapEntry('locality', 5),
      MapEntry('sub_locality', 5),
      MapEntry('feature_name', 4),
      MapEntry('district', 3),
      MapEntry('state', 2),
    ]) {
      final text = _mobileLocationText(data[entry.key])?.toLowerCase();
      if (text != null && haystack.contains(text)) score += entry.value;
    }
    return score;
  }

  List<String> _mobileLocationSearchTerms(Map<String, dynamic> data) {
    final seen = <String>{};
    final terms = <String>[];
    for (final value in [
      data['sub_locality'],
      data['locality'],
      data['feature_name'],
      data['district'],
    ]) {
      final text = _mobileLocationText(value);
      if (text == null || text.length < 2) continue;
      if (seen.add(text.toLowerCase())) terms.add(text);
    }
    return terms;
  }

  Future<bool> _fillMobileKnownHierarchy(Map<String, dynamic> data) async {
    final countryText = _mobileLocationText(data['country']);
    final stateText = _mobileLocationText(data['state']);
    final districtText = _mobileLocationText(data['district']);

    final country = countryText == null
        ? _country
        : await _findLocationByType(countryText, 'country');
    final states = await _ensureStates();
    final countryId = country?.intId;
    final state = stateText == null
        ? null
        : _findNamedOption(
            states.where((option) {
              if (countryId == null) return true;
              return _parentId(option) == countryId;
            }).toList(),
            stateText,
          );
    final districts = state == null
        ? const <OnboardingOption>[]
        : await _ensureDistrictsForState(state);
    final district = districtText == null
        ? null
        : _findNamedOption(districts, districtText);

    if (!mounted) return false;
    var changed = false;
    setState(() {
      if (country != null && _country?.identity != country.identity) {
        _country = country;
        changed = true;
      }
      if (state != null && _state?.identity != state.identity) {
        _state = state;
        _district = null;
        _localArea = null;
        _village = null;
        changed = true;
      }
      if (district != null && _district?.identity != district.identity) {
        _district = district;
        _localArea = null;
        _village = null;
        changed = true;
      }
    });
    if (district != null) {
      await _ensureTalukasForDistrict(district);
    }
    return changed;
  }

  Future<void> _applyLocationOption(
    OnboardingOption option, {
    Map<String, dynamic>? mobileData,
  }) async {
    final countryText = _mobileLocationText(mobileData?['country']) ?? 'India';
    final country =
        await _findLocationByType(countryText, 'country') ?? _country;
    final state = _parentOption(option, 'state');
    final district = _parentOption(option, 'district');
    final taluka = _parentOption(option, 'taluka');
    final type = _locationType(option);

    if (!mounted) return;
    setState(() {
      if (country != null) _country = country;
      if (state != null) _state = state;
      if (district != null) _district = district;
      if (type == 'village') {
        _localArea = taluka;
        _village = option;
      } else if (type == 'city' || type == 'suburb') {
        _localArea = option;
        _village = null;
      } else if (type == 'taluka') {
        _localArea = option;
        _village = null;
      } else if (type == 'district') {
        _district = option;
        _localArea = null;
        _village = null;
      }
    });
    final selectedDistrict = _district;
    if (selectedDistrict != null) {
      await _ensureTalukasForDistrict(selectedDistrict);
    }
  }

  void _setHierarchyFromLocation(OnboardingOption option) {
    final state = _parentOption(option, 'state');
    final district = _parentOption(option, 'district');
    final taluka = _parentOption(option, 'taluka');
    final type = _locationType(option);

    _state = state;
    _district = district;
    if (type == 'village') {
      _localArea = taluka;
      _village = option;
    } else if (type == 'city' || type == 'suburb') {
      _localArea = option;
      _village = null;
    } else if (type == 'taluka') {
      _localArea = option;
      _village = null;
    } else if (type == 'district') {
      _district = option;
      _localArea = null;
      _village = null;
    } else {
      _localArea = option;
    }
  }

  OnboardingOption? _parentOption(OnboardingOption option, String key) {
    final parent = option.raw['parent'];
    if (parent is! Map) return null;
    final value = parent[key];
    if (value is! Map) return null;
    final id = onboardingInt(value['id']);
    final label = onboardingText(value['label'] ?? value['name']);
    if (id == null || label == null) return null;
    return OnboardingOption(
      id: id,
      label: label,
      meta: <String, dynamic>{
        'type': key,
        'hierarchy': key,
        'status': 'approved',
        'is_final_node': false,
      },
      raw: <String, dynamic>{
        'id': id,
        'location_id': id,
        'label': label,
        'name': label,
        'type': key,
        'hierarchy': key,
      },
    );
  }

  String? _parentLabel(OnboardingOption option, String key) {
    final parent = option.raw['parent'];
    if (parent is! Map) return null;
    final value = parent[key];
    if (value is Map) {
      return onboardingText(value['label'] ?? value['name']);
    }
    return onboardingText(value);
  }

  String? _mobileLocationText(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  bool _fillMobileAddressLine(Map<String, dynamic> data) {
    if (_addressLineController.text.trim().isNotEmpty) return false;
    final addressLine = _mobileReadableAddressLine(data);
    if (addressLine == null) return false;
    _addressLineController.text = addressLine;
    return true;
  }

  String? _mobileReadableAddressLine(Map<String, dynamic> data) {
    final direct = _mobileLocationText(data['address_line']);
    if (direct != null) return direct;

    final seen = <String>{};
    final parts = <String>[];
    for (final value in [
      data['sub_locality'],
      data['locality'],
      data['feature_name'],
      data['district'],
      data['state'],
      data['country'],
    ]) {
      final text = _mobileLocationText(value);
      if (text == null) continue;
      final key = text.toLowerCase();
      if (seen.add(key)) parts.add(text);
    }

    return parts.isEmpty ? null : parts.join(', ');
  }

  String _nativeLocationErrorMessage(PlatformException error) {
    switch (error.code) {
      case 'PERMISSION_DENIED':
        return _t(
          'Location permission was denied.',
          'Location permission नाकारली आहे.',
        );
      case 'LOCATION_DISABLED':
        return _t(
          'Turn on device location in Android settings and try again.',
          'Android settings मध्ये device location चालू करून पुन्हा प्रयत्न करा.',
        );
      case 'LOCATION_TIMEOUT':
        return _t(
          'Mobile location timed out. Try again or search manually.',
          'मोबाईल location वेळेत मिळाले नाही. पुन्हा प्रयत्न करा किंवा manually शोधा.',
        );
      case 'LOCATION_PENDING':
        return _t(
          'Mobile location is already running.',
          'मोबाईल location आधीच चालू आहे.',
        );
      default:
        return _t(
          'Could not use mobile location.',
          'मोबाईल location वापरता आली नाही.',
        );
    }
  }

  Future<void> _showSuggestionDialog() async {
    if (_country == null || _state == null) {
      await _loadDefaultCountryState();
    }

    OnboardingOption? selectedCountry = _country;
    OnboardingOption? selectedState = _state;
    OnboardingOption? selectedDistrict = _district;
    OnboardingOption? selectedTaluka = _locationType(_localArea) == 'taluka'
        ? _localArea
        : null;
    String? dialogError;
    var submitting = false;

    final villageName = TextEditingController();
    final pincode = TextEditingController();
    final notes = TextEditingController();

    Future<PagedLookupResponse> countryPage(
      String query,
      int page,
      int limit,
    ) async {
      if (query.trim().length < 2) {
        return PagedLookupResponse.fromOptions(
          selectedCountry == null ? const [] : [selectedCountry!],
        );
      }

      final response = await _locationPage(query, page, limit);
      return PagedLookupResponse(
        success: response.success,
        locale: response.locale,
        results: response.results
            .where((option) => _locationType(option) == 'country')
            .toList(),
        pagination: const LookupPagination(hasMore: false),
        message: response.message,
        raw: response.raw,
      );
    }

    Future<PagedLookupResponse> statePage(
      String query,
      int page,
      int limit,
    ) async {
      final states = await _ensureStates();
      final countryId = selectedCountry?.intId;
      final filtered = countryId == null
          ? states
          : states.where((option) => _parentId(option) == countryId).toList();
      return _optionPage(filtered, query, page, limit);
    }

    Future<PagedLookupResponse> districtPage(
      String query,
      int page,
      int limit,
    ) async {
      final state = selectedState;
      if (state == null) return PagedLookupResponse.fromOptions(const []);
      final districts = await _ensureDistrictsForState(state);
      return _optionPage(districts, query, page, limit);
    }

    Future<PagedLookupResponse> talukaPage(
      String query,
      int page,
      int limit,
    ) async {
      final district = selectedDistrict;
      if (district == null) return PagedLookupResponse.fromOptions(const []);
      final talukas = await _ensureTalukasForDistrict(district);
      return _optionPage(talukas, query, page, limit);
    }

    try {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, dialogSetState) {
              return AlertDialog(
                title: Text(
                  _t(
                    'Create / add your location',
                    'तुमचे location create / add करा',
                  ),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (dialogError != null) ...[
                        Text(
                          dialogError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      OnboardingPickerField(
                        label: _t('Country', 'देश'),
                        selectedItems: selectedCountry == null
                            ? const []
                            : [selectedCountry!],
                        placeholder: _t('Select country', 'देश निवडा'),
                        searchHint: _t('Search country', 'देश शोधा'),
                        loadPage: countryPage,
                        showOptionSubtitles: false,
                        onChanged: (items) {
                          dialogSetState(() {
                            selectedCountry = items.isEmpty
                                ? null
                                : items.first;
                            selectedState = null;
                            selectedDistrict = null;
                            selectedTaluka = null;
                            dialogError = null;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      OnboardingPickerField(
                        label: _t('State', 'राज्य'),
                        selectedItems: selectedState == null
                            ? const []
                            : [selectedState!],
                        placeholder: _t('Select state', 'राज्य निवडा'),
                        searchHint: _t('Search state', 'राज्य शोधा'),
                        loadPage: statePage,
                        enabled: selectedCountry != null,
                        showOptionSubtitles: false,
                        onChanged: (items) {
                          dialogSetState(() {
                            selectedState = items.isEmpty ? null : items.first;
                            selectedDistrict = null;
                            selectedTaluka = null;
                            dialogError = null;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      OnboardingPickerField(
                        label: _t('District', 'जिल्हा'),
                        selectedItems: selectedDistrict == null
                            ? const []
                            : [selectedDistrict!],
                        placeholder: _t('Select district', 'जिल्हा निवडा'),
                        searchHint: _t('Search district', 'जिल्हा शोधा'),
                        loadPage: districtPage,
                        enabled: selectedState != null,
                        showOptionSubtitles: false,
                        onChanged: (items) {
                          dialogSetState(() {
                            selectedDistrict = items.isEmpty
                                ? null
                                : items.first;
                            selectedTaluka = null;
                            dialogError = null;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      OnboardingPickerField(
                        label: _t('Taluka', 'तालुका'),
                        selectedItems: selectedTaluka == null
                            ? const []
                            : [selectedTaluka!],
                        placeholder: _t(
                          'Select taluka optional',
                          'तालुका निवडा ऐच्छिक',
                        ),
                        searchHint: _t('Search taluka', 'तालुका शोधा'),
                        loadPage: talukaPage,
                        enabled: selectedDistrict != null,
                        showOptionSubtitles: false,
                        onChanged: (items) {
                          dialogSetState(() {
                            selectedTaluka = items.isEmpty ? null : items.first;
                            dialogError = null;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      _dialogField(
                        villageName,
                        _t('Village / location name', 'गाव / location नाव'),
                        enabled: selectedDistrict != null,
                      ),
                      _dialogField(
                        pincode,
                        _t('Pincode optional', 'Pincode optional'),
                        keyboardType: TextInputType.number,
                        enabled: selectedDistrict != null,
                      ),
                      _dialogField(
                        notes,
                        _t('Extra note optional', 'Extra note optional'),
                        maxLines: 2,
                        enabled: selectedDistrict != null,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _t(
                          'We will add this only if it is not already available.',
                          'हे location आधीपासून उपलब्ध नसेल तरच add request जाईल.',
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: submitting ? null : () => Navigator.pop(context),
                    child: Text(_t('Cancel', 'Cancel')),
                  ),
                  ElevatedButton(
                    onPressed: submitting
                        ? null
                        : () async {
                            final name = villageName.text.trim();
                            final country = selectedCountry;
                            final state = selectedState;
                            final district = selectedDistrict;
                            final taluka = selectedTaluka;
                            final parent = taluka ?? district;
                            final selectedTag = taluka == null
                                ? 'city'
                                : 'rural';
                            if (country == null ||
                                state == null ||
                                district == null ||
                                parent == null ||
                                name.length < 2) {
                              dialogSetState(() {
                                dialogError = _t(
                                  'Select country, state, district and enter location name.',
                                  'देश, राज्य, जिल्हा निवडा आणि location नाव भरा.',
                                );
                              });
                              return;
                            }

                            dialogSetState(() {
                              submitting = true;
                              dialogError = null;
                            });

                            final existing =
                                await _findExistingLocationUnderParent(
                                  name,
                                  parent,
                                );
                            if (!context.mounted) return;
                            if (existing != null) {
                              Navigator.pop(context);
                              if (!mounted) return;
                              _applyAddedLocationOption(
                                option: existing,
                                country: country,
                                state: state,
                                district: district,
                                taluka: taluka,
                                isRuralUnderTaluka: taluka != null,
                              );
                              widget.onMessage(
                                _t(
                                  'This location already exists. It has been selected.',
                                  'हे location आधीपासून आहे. ते select केले आहे.',
                                ),
                              );
                              return;
                            }

                            final suggestionType = _suggestionTypeForTag(
                              selectedTag,
                            );
                            final body = compactPayload({
                              'type': suggestionType,
                              'tag': selectedTag,
                              'name': name,
                              'country_id': country.intId,
                              'state_id': state.intId,
                              'district_id': district.intId,
                              if (taluka?.intId != null)
                                'taluka_id': taluka!.intId,
                              'parent_id': parent.intId,
                              'pincode': pincode.text.trim(),
                              'notes': notes.text.trim(),
                            });
                            late final Map<String, dynamic> response;
                            try {
                              response =
                                  await ApiClient.submitLocationSuggestion(
                                    body,
                                  );
                            } catch (_) {
                              if (!context.mounted) return;
                              dialogSetState(() {
                                submitting = false;
                                dialogError = _friendlyLocationRequestError();
                              });
                              return;
                            }
                            if (!context.mounted) return;
                            Navigator.pop(context);
                            if (response['success'] != true) {
                              widget.onMessage(
                                _friendlyLocationRequestError(response),
                              );
                              return;
                            }

                            final request = response['request'];
                            final requestMap = request is Map
                                ? Map<String, dynamic>.from(request)
                                : <String, dynamic>{};
                            final submittedLabel =
                                onboardingText(requestMap['label']) ?? name;
                            final requestId = onboardingInt(requestMap['id']);
                            final requestStatus =
                                onboardingText(requestMap['status']) ??
                                'pending';
                            final requestType =
                                onboardingText(requestMap['type']) ??
                                suggestionType;
                            final displayLabel = _customLocationDisplayLabel(
                              submittedLabel,
                              district: district,
                              taluka: taluka,
                            );
                            final tempOption = _temporaryLocationOption(
                              label: submittedLabel,
                              displayLabel: displayLabel,
                              parent: parent,
                              tag: selectedTag,
                              requestId: requestId,
                              status: requestStatus,
                              type: requestType,
                            );
                            final draftPayload = <String, dynamic>{
                              'location_id': null,
                              'address_line': displayLabel,
                              'pending_location_request_id': requestId,
                              'pending_location_label': submittedLabel,
                              'pending_location_status': requestStatus,
                              'pending_location_type': requestType,
                              'location_option': tempOption.toJson(),
                              if (country.intId != null)
                                'country_option': country.toJson(),
                              if (state.intId != null)
                                'state_option': state.toJson(),
                              if (district.intId != null)
                                'district_option': district.toJson(),
                              if (taluka != null)
                                'local_area_option': taluka.toJson(),
                              if (taluka != null)
                                'village_option': tempOption.toJson()
                              else
                                'local_area_option': tempOption.toJson(),
                            };
                            if (!mounted) return;
                            _applyAddedLocationOption(
                              option: tempOption,
                              country: country,
                              state: state,
                              district: district,
                              taluka: taluka,
                              isRuralUnderTaluka: taluka != null,
                            );
                            _addressLineController.text = displayLabel;
                            final saved = await widget.onSave(
                              'location',
                              draftPayload,
                              saveProfile: false,
                              advance: false,
                            );
                            if (!mounted || !saved) return;
                            setState(() {
                              _pendingLocationRequestId = requestId;
                              _pendingLocationLabel = displayLabel;
                              _pendingLocationStatus = requestStatus;
                              _pendingLocationType = requestType;
                            });
                            widget.onMessage(
                              _t(
                                'Location entry added. You can continue.',
                                'Location entry add झाली. तुम्ही पुढे जाऊ शकता.',
                              ),
                            );
                          },
                    child: submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_t('Create / add', 'Create / add')),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      villageName.dispose();
      pincode.dispose();
      notes.dispose();
    }
  }

  String _friendlyLocationRequestError([Map<String, dynamic>? response]) {
    final fallback = _t(
      'Could not submit location request. Check the selected district and taluka, then try again.',
      'Location request submit झाली नाही. निवडलेला जिल्हा आणि तालुका तपासा, मग पुन्हा प्रयत्न करा.',
    );
    if (response == null) return fallback;

    final raw = readableApiError(response, fallback);
    final lower = raw.toLowerCase();
    if (lower.contains('_id') ||
        lower.contains('validation') ||
        lower.contains('required') ||
        lower.contains('belongs to') ||
        lower.contains('selected')) {
      return fallback;
    }
    return raw;
  }

  Future<OnboardingOption?> _findExistingLocationUnderParent(
    String name,
    OnboardingOption parent,
  ) async {
    final wanted = name.trim().toLowerCase();
    if (wanted.length < 2 || parent.intId == null) return null;

    final response = await _childrenPage(
      parent: parent,
      query: name,
      page: 1,
      limit: 50,
    );
    for (final option in response.results) {
      if (!_locationEnabled(option)) continue;
      if (option.label.trim().toLowerCase() == wanted) return option;
    }

    return null;
  }

  OnboardingOption _temporaryLocationOption({
    required String label,
    required String displayLabel,
    required OnboardingOption parent,
    required String tag,
    required int? requestId,
    required String status,
    required String type,
  }) {
    final parentId = parent.intId;
    final key = 'pending-location:${requestId ?? label.toLowerCase()}';
    final groupLabel = _groupLabelForTag(tag);
    return OnboardingOption(
      id: key,
      key: key,
      label: label,
      meta: <String, dynamic>{
        'type': type,
        'tag': tag,
        'group': tag,
        if (groupLabel != null) 'group_label': groupLabel,
        'display_label': displayLabel,
        'profile_display_label': displayLabel,
        'location_label': displayLabel,
        'pending_location_label': label,
        'pending_location_display_label': displayLabel,
        'status': status,
        'pending_location_status': status,
        'pending_location_type': type,
        if (requestId != null) 'pending_location_request_id': requestId,
        if (parentId != null) 'parent_id': parentId,
        'is_active': false,
        'is_final_node': true,
        'is_pending_location': true,
        'is_custom_location': true,
      },
      raw: <String, dynamic>{
        'id': key,
        'key': key,
        'label': label,
        'name': label,
        'display_label': displayLabel,
        'profile_display_label': displayLabel,
        'location_label': displayLabel,
        'pending_location_label': label,
        'pending_location_display_label': displayLabel,
        'type': type,
        'tag': tag,
        if (groupLabel != null) 'group_label': groupLabel,
        if (requestId != null) 'pending_location_request_id': requestId,
        if (parentId != null) 'parent_id': parentId,
        'status': status,
        'is_final_node': true,
        'is_pending_location': true,
        'is_custom_location': true,
      },
    );
  }

  void _applyAddedLocationOption({
    required OnboardingOption option,
    required OnboardingOption country,
    required OnboardingOption state,
    required OnboardingOption district,
    required OnboardingOption? taluka,
    required bool isRuralUnderTaluka,
  }) {
    setState(() {
      _country = country;
      _state = state;
      _district = district;
      if (isRuralUnderTaluka) {
        _localArea = taluka;
        _village = option;
      } else {
        _localArea = option;
        _village = null;
      }
      _pendingLocationRequestId = option.metaInt('pending_location_request_id');
      _pendingLocationLabel = _pendingLocationDisplayLabel(option);
      _pendingLocationStatus =
          option.metaText('pending_location_status') ??
          option.metaText('status') ??
          'pending';
      _pendingLocationType =
          option.metaText('pending_location_type') ??
          _locationType(option) ??
          'village';
    });
  }

  String _suggestionTypeForTag(String tag) {
    return switch (tag) {
      'city' => 'city',
      'suburban' => 'suburb',
      _ => 'village',
    };
  }

  String? _groupLabelForTag(String tag) {
    return switch (tag) {
      'city' => 'City',
      'suburban' => 'Suburban',
      'rural' => 'Rural',
      _ => null,
    };
  }

  Widget _dialogField(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    int maxLines = 1,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  void _selectCountry(List<OnboardingOption> items) {
    final next = items.isEmpty ? null : items.first;
    setState(() {
      _country = next;
      _state = null;
      _district = null;
      _localArea = null;
      _village = null;
      _districts = const <OnboardingOption>[];
      _talukas = const <OnboardingOption>[];
      _districtsForStateId = null;
      _talukasForDistrictId = null;
    });
  }

  void _selectState(List<OnboardingOption> items) {
    final next = items.isEmpty ? null : items.first;
    setState(() {
      _state = next;
      _district = null;
      _localArea = null;
      _village = null;
      _districts = const <OnboardingOption>[];
      _talukas = const <OnboardingOption>[];
      _districtsForStateId = null;
      _talukasForDistrictId = null;
    });
    if (next != null) {
      _ensureDistrictsForState(
        next,
      ).catchError((_) => const <OnboardingOption>[]);
    }
  }

  void _selectDistrict(List<OnboardingOption> items) {
    final next = items.isEmpty ? null : items.first;
    setState(() {
      _district = next;
      _localArea = null;
      _village = null;
      _talukas = const <OnboardingOption>[];
      _talukasForDistrictId = null;
    });
    if (next != null) {
      _ensureTalukasForDistrict(
        next,
      ).catchError((_) => const <OnboardingOption>[]);
    }
  }

  void _selectLocalArea(List<OnboardingOption> items) {
    final next = items.isEmpty ? null : items.first;
    setState(() {
      _localArea = next;
      _village = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingStepScaffold(
      title: _t('Location', 'ठिकाण'),
      subtitle: _t(
        'Choose where the profile lives.',
        'प्रोफाइलचे सध्याचे ठिकाण निवडा.',
      ),
      loading: widget.loading,
      onBack: widget.onBack,
      onContinue: _save,
      children: [
        if (_hasPendingLocation) ...[
          _pendingLocationCard(context),
          const SizedBox(height: 12),
        ],
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: widget.loading || _usingMobileLocation
                ? null
                : _useMobileLocation,
            icon: _usingMobileLocation
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location_outlined),
            label: Text(
              _t('Use mobile location', 'मोबाईल location वापरून भरा'),
            ),
          ),
        ),
        const SizedBox(height: 12),
        OnboardingPickerField(
          label: _t('Country', 'देश'),
          selectedItems: _country == null ? const [] : [_country!],
          placeholder: _t('Select country', 'देश निवडा'),
          searchHint: _t('Search country', 'देश शोधा'),
          loadPage: _countryPage,
          showOptionSubtitles: false,
          onChanged: _selectCountry,
        ),
        const SizedBox(height: 12),
        OnboardingPickerField(
          label: _t('State', 'राज्य'),
          selectedItems: _state == null ? const [] : [_state!],
          placeholder: _t('Select state', 'राज्य निवडा'),
          searchHint: _t('Search state', 'राज्य शोधा'),
          loadPage: _statePage,
          enabled: _country != null,
          showOptionSubtitles: false,
          onChanged: _selectState,
        ),
        if (_state != null) ...[
          const SizedBox(height: 12),
          OnboardingPickerField(
            label: _t('District', 'जिल्हा'),
            selectedItems: _district == null ? const [] : [_district!],
            placeholder: _t('Select district', 'जिल्हा निवडा'),
            searchHint: _t('Search district', 'जिल्हा शोधा'),
            loadPage: _districtPage,
            showOptionSubtitles: false,
            onChanged: _selectDistrict,
          ),
        ],
        if (_district != null) ...[
          const SizedBox(height: 12),
          OnboardingPickerField(
            label: _t('Taluka / City / Suburban', 'तालुका / शहर / उपनगर'),
            selectedItems: _localArea == null ? const [] : [_localArea!],
            placeholder: _t(
              'Select taluka, city or suburb',
              'तालुका, शहर किंवा उपनगर निवडा',
            ),
            searchHint: _t(
              'Search taluka, city or suburb',
              'तालुका, शहर किंवा उपनगर शोधा',
            ),
            loadPage: _localAreaPage,
            filteredLoadPage: _localAreaFilteredPage,
            showDividers: true,
            showOptionSubtitles: false,
            groupOptions: true,
            filterOptions: _districtLevelFilters,
            emptyTitleBuilder: _locationNotFoundTitle,
            emptyMessageBuilder: _emptyLocationMessage,
            allowRequestToAdd: true,
            requestToAddOnlyAfterQuery: true,
            onRequestToAdd: _showSuggestionDialog,
            requestToAddLabel: _addLocationLabel,
            onChanged: _selectLocalArea,
          ),
        ],
        if (_showVillagePicker) ...[
          const SizedBox(height: 12),
          OnboardingPickerField(
            label: _t('Location', 'ठिकाण'),
            selectedItems: _village == null ? const [] : [_village!],
            placeholder: _t('Select location', 'ठिकाण निवडा'),
            searchHint: _t('Search location', 'ठिकाण शोधा'),
            loadPage: _villagePage,
            filteredLoadPage: _villageFilteredPage,
            optionEnabled: _locationEnabled,
            showDividers: true,
            showOptionSubtitles: false,
            groupOptions: true,
            filterOptions: _talukaLevelFilters,
            emptyTitleBuilder: _locationNotFoundTitle,
            emptyMessageBuilder: _emptyLocationMessage,
            allowRequestToAdd: true,
            requestToAddOnlyAfterQuery: true,
            onRequestToAdd: _showSuggestionDialog,
            requestToAddLabel: _addLocationLabel,
            onChanged: (items) => setState(() {
              _village = items.isEmpty ? null : items.first;
            }),
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _addressLineController,
          decoration: InputDecoration(
            labelText: _t('Address line optional', 'पत्ता ओळ ऐच्छिक'),
          ),
        ),
      ],
    );
  }

  Widget _pendingLocationCard(BuildContext context) {
    final label =
        _pendingLocationLabel ?? _t('Requested location', 'Requested location');
    final type = _pendingLocationType;
    final requestId = _pendingLocationRequestId;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade300),
        color: Colors.orange.shade50,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.pending_actions, color: Colors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (type != null) type,
                    if (requestId != null) '#$requestId',
                    _t(
                      'Saved for now; admin can approve the master location later.',
                      'सध्या save झाले आहे; admin नंतर master location approve करू शकतो.',
                    ),
                  ].join(' • '),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
