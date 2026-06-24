import 'package:flutter/material.dart';
import '../../core/app_strings.dart';
import '../../core/api_client.dart';
import 'widgets/profile_display_section.dart';

class ViewProfileScreen extends StatefulWidget {
  const ViewProfileScreen({super.key});

  @override
  State<ViewProfileScreen> createState() => _ViewProfileScreenState();
}

class _ViewProfileScreenState extends State<ViewProfileScreen> {
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _display;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    // स्क्रीन सुरू झाल्यावर, सर्व्हरवरून प्रोफाइलची ताजी माहिती मागवा
    try {
      final response = await ApiClient.getMyProfile();
      if (!mounted) return;

      if (response['success'] == true && response['profile'] != null) {
        setState(() {
          _profile = response['profile'];
          _display = response['display'] is Map
              ? Map<String, dynamic>.from(response['display'])
              : null;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'प्रोफाइल लोड होऊ शकले नाही.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'एक अनपेक्षित एरर आली: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.myProfile),
        actions: [
          // 'रिफ्रेश' बटण जेणेकरून युझर माहिती पुन्हा लोड करू शकेल
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_isLoading) return; // आधीच लोड होत असल्यास काही करू नका
              setState(() {
                _isLoading = true;
                _errorMessage = null;
                _profile = null;
                _display = null;
              });
              _fetchProfile();
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  // स्क्रीनचा मुख्य भाग तयार करणारा विजेट
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.red, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_profile == null) {
      return Center(child: Text(AppStrings.noProfileData));
    }

    final photoUrl = ApiClient.resolveProfilePhotoUrl(_profile);
    final location = ApiClient.profileLocationLabel(
      _profile,
      allowIdFallback: false,
    );
    final visibleSections = _ownProfileDisplaySections(_profile!, location);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _buildProfileHero(photoUrl, _profile!['full_name'], location),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            children: visibleSections
                .map((section) => ProfileDisplaySection(section: section))
                .toList(),
          ),
        ),
      ],
    );
  }

  List<ProfileDisplaySectionData> _displaySections() {
    final rawSections = _display?['sections'];
    if (rawSections is! List) return const <ProfileDisplaySectionData>[];

    return rawSections
        .map(ProfileDisplaySectionData.fromMap)
        .whereType<ProfileDisplaySectionData>()
        .toList();
  }

  List<ProfileDisplaySectionData> _ownProfileDisplaySections(
    Map<String, dynamic> profile,
    String? location,
  ) {
    final rawSections = _fallbackDisplaySections(profile, location);
    return rawSections.isNotEmpty ? rawSections : _displaySections();
  }

  List<ProfileDisplaySectionData> _fallbackDisplaySections(
    Map<String, dynamic> profile,
    String? location,
  ) {
    final basicItems = <ProfileDisplayItemData>[];
    final physicalItems = <ProfileDisplayItemData>[];
    final careerItems = <ProfileDisplayItemData>[];
    final familyItems = <ProfileDisplayItemData>[];
    final siblingItems = <ProfileDisplayItemData>[];
    final relativeItems = <ProfileDisplayItemData>[];
    final propertyItems = <ProfileDisplayItemData>[];
    final horoscopeItems = <ProfileDisplayItemData>[];
    final aboutItems = <ProfileDisplayItemData>[];
    final preferenceItems = <ProfileDisplayItemData>[];
    final photoItems = <ProfileDisplayItemData>[];
    final maritalStatusKey = ApiClient.safeDisplayLabel(
      profile['marital_status_key'],
    );
    final showMarriageChildren = _showsMarriageChildren(maritalStatusKey);

    _addDisplayItem(basicItems, AppStrings.name, profile['full_name']);
    _addDisplayItem(
      basicItems,
      AppStrings.dateOfBirth,
      profile['date_of_birth'],
    );
    _addDisplayItem(
      basicItems,
      'Gender',
      profile['gender_label'] ?? profile['gender_name'] ?? profile['gender'],
    );
    _addDisplayItem(
      basicItems,
      'Community',
      ApiClient.profileCommunityLabel(profile),
    );
    _addDisplayItem(basicItems, AppStrings.location, location);
    final selfAddressLabel = _fallbackAddressRowsLabel(
      profile,
      'self_addresses',
    );
    if (selfAddressLabel != null) {
      _addDisplayItem(basicItems, 'Self Addresses', selfAddressLabel);
    } else {
      _addDisplayItem(basicItems, 'Address Line', profile['address_line']);
    }
    _addDisplayItem(
      basicItems,
      'Mother Tongue',
      profile['mother_tongue_label'],
    );
    _addDisplayItem(basicItems, 'Birth Time', profile['birth_time']);
    _addDisplayItem(
      basicItems,
      'Birth Place',
      profile['birth_place_label'] ??
          profile['birth_place_text'] ??
          profile['birth_place'],
    );
    _addDisplayItem(
      basicItems,
      'Marital Status',
      profile['marital_status_label'] ?? profile['marital_status_key'],
    );
    if (showMarriageChildren) {
      _addDisplayItem(
        basicItems,
        'Marriage History',
        _fallbackMarriageHistoryLabel(profile, maritalStatusKey),
      );
      _addDisplayItem(basicItems, 'Children', _fallbackChildrenLabel(profile));
    }
    _addDisplayItem(
      physicalItems,
      'Height',
      ApiClient.profileHeightLabel(profile),
    );
    _addDisplayItem(
      physicalItems,
      'Weight',
      profile['weight_kg'] == null ? null : '${profile['weight_kg']} kg',
    );
    _addDisplayItem(physicalItems, 'Complexion', profile['complexion_label']);
    _addDisplayItem(physicalItems, 'Blood Group', profile['blood_group_label']);
    _addDisplayItem(
      physicalItems,
      'Physical Build',
      profile['physical_build_label'],
    );
    _addDisplayItem(
      physicalItems,
      'Spectacles / Lens',
      profile['spectacles_lens'],
    );
    _addDisplayItem(
      physicalItems,
      'Physical Condition',
      profile['physical_condition'],
    );
    _addDisplayItem(physicalItems, 'Diet', profile['diet_label']);
    _addDisplayItem(physicalItems, 'Smoking', profile['smoking_status_label']);
    _addDisplayItem(
      physicalItems,
      'Drinking',
      profile['drinking_status_label'],
    );

    _addDisplayItem(
      careerItems,
      'Highest Education',
      ApiClient.profileEducationLabel(profile),
    );
    _addDisplayItem(
      careerItems,
      'Occupation',
      profile['occupation_master_label'] ??
          profile['occupation_custom_label'] ??
          ApiClient.profileOccupationLabel(profile),
    );
    _addDisplayItem(careerItems, 'Company Name', profile['company_name']);
    _addDisplayItem(
      careerItems,
      'Work Location',
      profile['work_location_label'] ?? profile['work_location_text'],
    );
    _addDisplayItem(
      careerItems,
      'Annual Income',
      _fallbackIncomeLabel(profile, 'income', 'annual_income') ??
          profile['income_display_label'] ??
          'Not added',
    );
    _addDisplayItem(familyItems, 'Father', _parentSummary(profile, 'father'));
    _addPhoneDisplayItem(
      familyItems,
      'Father Contact 1',
      profile['father_contact_1'],
    );
    _addPhoneDisplayItem(
      familyItems,
      'Father Contact 2',
      profile['father_contact_2'],
    );
    _addPhoneDisplayItem(
      familyItems,
      'Father Contact 3',
      profile['father_contact_3'],
    );
    _addDisplayItem(familyItems, 'Mother', _parentSummary(profile, 'mother'));
    _addPhoneDisplayItem(
      familyItems,
      'Mother Contact 1',
      profile['mother_contact_1'],
    );
    _addPhoneDisplayItem(
      familyItems,
      'Mother Contact 2',
      profile['mother_contact_2'],
    );
    _addPhoneDisplayItem(
      familyItems,
      'Mother Contact 3',
      profile['mother_contact_3'],
    );
    _addDisplayItem(
      familyItems,
      'Family Income',
      _fallbackIncomeLabel(profile, 'family_income', 'family_income') ??
          profile['family_income_display_label'] ??
          'Not added',
    );
    _addDisplayItem(familyItems, 'Family Type', profile['family_type_label']);
    _addDisplayItem(familyItems, 'Family Status', profile['family_status']);
    _addDisplayItem(familyItems, 'Family Values', profile['family_values']);
    _addDisplayItem(
      familyItems,
      'Parents Addresses',
      _fallbackAddressRowsLabel(profile, 'parents_addresses'),
    );
    _addDisplayItem(siblingItems, 'Siblings', _fallbackSiblingsLabel(profile));
    _addDisplayItem(
      relativeItems,
      'Relatives',
      _fallbackRelativesLabel(profile),
    );
    _addDisplayItem(
      relativeItems,
      'Alliance Network',
      _fallbackAllianceNetworksLabel(profile),
    );
    _addDisplayItem(
      relativeItems,
      'Other Relatives',
      profile['other_relatives_text'],
    );
    _addDisplayItem(
      propertyItems,
      'Property Details',
      profile['property_details'],
    );

    _addDisplayItem(horoscopeItems, 'Rashi', profile['rashi_label']);
    _addDisplayItem(horoscopeItems, 'Nakshatra', profile['nakshatra_label']);
    _addDisplayItem(horoscopeItems, 'Charan', profile['charan']);
    _addDisplayItem(horoscopeItems, 'Gan', profile['gan_label']);
    _addDisplayItem(horoscopeItems, 'Nadi', profile['nadi_label']);
    _addDisplayItem(horoscopeItems, 'Yoni', profile['yoni_label']);
    _addDisplayItem(horoscopeItems, 'Varna', profile['varna_label']);
    _addDisplayItem(horoscopeItems, 'Vashya', profile['vashya_label']);
    _addDisplayItem(horoscopeItems, 'Rashi Lord', profile['rashi_lord_label']);
    _addDisplayItem(
      horoscopeItems,
      'Mangal Dosh',
      profile['mangal_dosh_type_label'],
    );
    _addDisplayItem(horoscopeItems, 'Devak', profile['devak']);
    _addDisplayItem(horoscopeItems, 'Kul', profile['kul']);
    _addDisplayItem(horoscopeItems, 'Gotra', profile['gotra']);
    _addDisplayItem(horoscopeItems, 'Navras Name', profile['navras_name']);
    _addDisplayItem(horoscopeItems, 'Birth Weekday', profile['birth_weekday']);

    _addDisplayItem(aboutItems, 'About Me', profile['narrative_about_me']);
    _addDisplayItem(
      aboutItems,
      'Expectations',
      profile['narrative_expectations'],
    );

    _addDisplayItem(
      preferenceItems,
      'Age Range',
      _rangeLabel(profile['preferred_age_min'], profile['preferred_age_max']),
    );
    _addDisplayItem(
      preferenceItems,
      'Height Range',
      _rangeLabel(
        profile['preferred_height_min_cm'],
        profile['preferred_height_max_cm'],
        suffix: ' cm',
      ),
    );
    _addDisplayItem(
      preferenceItems,
      'Income Range',
      profile['preferred_income_label'] ??
          _rangeLabel(
            profile['preferred_income_min'],
            profile['preferred_income_max'],
            prefix: '₹',
          ),
    );
    _addDisplayItem(
      preferenceItems,
      'Marriage Type',
      profile['marriage_type_preference_label'],
    );
    _addDisplayItem(
      preferenceItems,
      'Partner With Children',
      profile['partner_profile_with_children_label'],
    );
    _addDisplayItem(
      preferenceItems,
      'Profile Managed By',
      profile['preferred_profile_managed_by_label'],
    );
    _addDisplayItem(
      preferenceItems,
      'Willing To Relocate',
      profile['willing_to_relocate'],
    );
    _addDisplayItem(
      preferenceItems,
      'Preferred Marital Status',
      _joinDisplayValues(profile['preferred_marital_status_labels']),
    );
    _addDisplayItem(
      preferenceItems,
      'Preferred Diet',
      _joinDisplayValues(profile['preferred_diet_labels']),
    );
    _addDisplayItem(
      preferenceItems,
      'Preferred Religion',
      _joinDisplayValues(profile['preferred_religion_labels']),
    );
    _addDisplayItem(
      preferenceItems,
      'Preferred Caste',
      _joinDisplayValues(profile['preferred_caste_labels']),
    );
    _addDisplayItem(
      preferenceItems,
      'Preferred Education',
      _joinDisplayValues(profile['preferred_education_degree_labels']),
    );
    _addDisplayItem(
      preferenceItems,
      'Preferred Occupation',
      _joinDisplayValues(profile['preferred_occupation_master_labels']),
    );
    _addDisplayItem(photoItems, 'Photo Status', _photoStatusLabel(profile));

    return [
      if (basicItems.isNotEmpty)
        ProfileDisplaySectionData(
          key: 'basic-info',
          title: 'Basic Information',
          items: basicItems,
        ),
      if (physicalItems.isNotEmpty)
        ProfileDisplaySectionData(
          key: 'physical',
          title: 'Physical',
          items: physicalItems,
        ),
      if (careerItems.isNotEmpty)
        ProfileDisplaySectionData(
          key: 'education-career',
          title: 'Education & Career',
          items: careerItems,
        ),
      if (familyItems.isNotEmpty)
        ProfileDisplaySectionData(
          key: 'family-details',
          title: 'Family Details',
          items: familyItems,
        ),
      if (siblingItems.isNotEmpty)
        ProfileDisplaySectionData(
          key: 'siblings',
          title: 'Siblings',
          items: siblingItems,
        ),
      if (relativeItems.isNotEmpty)
        ProfileDisplaySectionData(
          key: 'relatives',
          title: 'Relatives',
          items: relativeItems,
        ),
      if (propertyItems.isNotEmpty)
        ProfileDisplaySectionData(
          key: 'property',
          title: 'Property',
          items: propertyItems,
        ),
      if (horoscopeItems.isNotEmpty)
        ProfileDisplaySectionData(
          key: 'horoscope',
          title: 'Horoscope',
          items: horoscopeItems,
        ),
      if (aboutItems.isNotEmpty)
        ProfileDisplaySectionData(
          key: 'about-me',
          title: 'About Me',
          items: aboutItems,
        ),
      if (preferenceItems.isNotEmpty)
        ProfileDisplaySectionData(
          key: 'about-preferences',
          title: 'Partner Preferences',
          items: preferenceItems,
        ),
      if (photoItems.isNotEmpty)
        ProfileDisplaySectionData(
          key: 'photo',
          title: 'Photo',
          items: photoItems,
        ),
    ];
  }

  bool _readBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;

    final text = value?.toString().trim().toLowerCase();
    return text == '1' || text == 'true' || text == 'yes' || text == 'y';
  }

  bool _showsMarriageChildren(String? maritalStatusKey) {
    return const {
      'divorced',
      'annulled',
      'separated',
      'widowed',
    }.contains(maritalStatusKey);
  }

  String? _parentSummary(Map<String, dynamic> profile, String prefix) {
    final name = ApiClient.safeDisplayLabel(profile['${prefix}_name']);
    final occupation =
        ApiClient.safeDisplayLabel(
          profile['${prefix}_occupation_master_label'],
        ) ??
        ApiClient.safeDisplayLabel(
          profile['${prefix}_occupation_custom_label'],
        ) ??
        ApiClient.safeDisplayLabel(profile['${prefix}_occupation']);
    final extra = ApiClient.safeDisplayLabel(profile['${prefix}_extra_info']);
    final parts = [
      name,
      occupation,
      extra,
    ].whereType<String>().where((value) => value.trim().isNotEmpty).toList();

    return parts.isEmpty ? null : parts.join(' - ');
  }

  String? _photoStatusLabel(Map<String, dynamic> profile) {
    if (ApiClient.resolveProfilePhotoUrl(profile) != null) {
      return 'Photo uploaded';
    }

    final status = ApiClient.safeDisplayLabel(profile['photo_status']);
    if (status != null) return status;

    final approved = profile['photo_approved'];
    if (approved == false || approved == 0 || approved == '0') {
      return 'Photo pending or not approved';
    }

    return 'No approved photo';
  }

  String? _scalarDisplayText(dynamic value) {
    if (value == null || value is Map || value is List) return null;

    final text = value.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return null;

    return text;
  }

  String? _joinDisplayValues(dynamic value) {
    if (value is List) {
      final parts = value
          .map(ApiClient.safeDisplayLabel)
          .whereType<String>()
          .where((item) => item.trim().isNotEmpty)
          .toList();

      return parts.isEmpty ? null : parts.join(', ');
    }

    return ApiClient.safeDisplayLabel(value);
  }

  String? _rangeLabel(
    dynamic min,
    dynamic max, {
    String prefix = '',
    String suffix = '',
  }) {
    final minText = _scalarDisplayText(min);
    final maxText = _scalarDisplayText(max);
    if (minText == null && maxText == null) return null;
    if (minText != null && maxText != null) {
      return '$prefix$minText$suffix - $prefix$maxText$suffix';
    }
    if (minText != null) return '$prefix$minText$suffix+';

    return 'Up to $prefix$maxText$suffix';
  }

  String? _fallbackAddressRowsLabel(Map<String, dynamic> profile, String key) {
    final raw = profile[key];
    if (raw is! List) return null;

    final rows = raw
        .whereType<Map>()
        .map((row) {
          final map = Map<String, dynamic>.from(row);
          final type =
              ApiClient.safeDisplayLabel(map['address_type_label']) ??
              ApiClient.safeDisplayLabel(map['address_type_key']);
          final location =
              ApiClient.safeDisplayLabel(map['location_label']) ??
              ApiClient.safeDisplayLabel(map['display']);
          final line = ApiClient.safeDisplayLabel(map['address_line']);
          return [type, location, line]
              .whereType<String>()
              .where((value) => value.trim().isNotEmpty)
              .join(': ');
        })
        .where((value) => value.trim().isNotEmpty)
        .toList();

    if (rows.isEmpty) return null;
    return rows.take(3).join('; ');
  }

  String? _fallbackIncomeLabel(
    Map<String, dynamic> profile,
    String prefix,
    String legacyKey,
  ) {
    final valueType = ApiClient.safeDisplayLabel(
      profile['${prefix}_value_type'],
    );
    if (valueType == 'undisclosed') return 'Undisclosed';

    final currency =
        ApiClient.safeDisplayLabel(profile['${prefix}_currency_symbol']) ?? '₹';
    if (valueType == 'range') {
      final min = _scalarDisplayText(profile['${prefix}_min_amount']);
      final max = _scalarDisplayText(profile['${prefix}_max_amount']);
      if (min != null && max != null) return '$currency$min - $currency$max';
      if (min != null) return '$currency$min+';
      if (max != null) return 'Up to $currency$max';
      return null;
    }

    final amount =
        _scalarDisplayText(profile['${prefix}_amount']) ??
        _scalarDisplayText(profile[legacyKey]);
    if (amount == null) return null;
    if (valueType == 'approximate') return 'Approx. $currency$amount';

    return '$currency$amount';
  }

  String? _fallbackSiblingsLabel(Map<String, dynamic> profile) {
    final rows = profile['siblings'];
    if (rows is! List || rows.isEmpty) return 'No siblings';

    final parts = <String>[];
    for (final row in rows.take(3)) {
      if (row is! Map) continue;
      final relation =
          ApiClient.safeDisplayLabel(row['relation_type_label']) ??
          _siblingRelationLabel(
            ApiClient.safeDisplayLabel(row['relation_type']),
          );
      final name = ApiClient.safeDisplayLabel(row['name']);
      final maritalStatus =
          ApiClient.safeDisplayLabel(row['marital_status_label']) ??
          _siblingMaritalStatusLabel(
            ApiClient.safeDisplayLabel(row['marital_status']),
          );
      final occupation =
          ApiClient.safeDisplayLabel(row['occupation']) ??
          ApiClient.safeDisplayLabel(row['occupation_master_label']) ??
          ApiClient.safeDisplayLabel(row['occupation_custom_label']);
      final location =
          ApiClient.safeDisplayLabel(row['address_line']) ??
          ApiClient.safeDisplayLabel(row['city_label']);
      final item = [relation, name, maritalStatus, occupation, location]
          .whereType<String>()
          .where((value) => value.trim().isNotEmpty)
          .join(' - ');
      if (item.isNotEmpty) parts.add(item);
    }

    final remaining = rows.length - parts.length;
    if (remaining > 0) parts.add('+$remaining more');

    final countLabel = '${rows.length} sibling${rows.length == 1 ? '' : 's'}';
    return parts.isEmpty ? countLabel : '$countLabel - ${parts.join('; ')}';
  }

  String? _fallbackMarriageHistoryLabel(
    Map<String, dynamic> profile,
    String? maritalStatusKey,
  ) {
    final rows = profile['marriages'];
    if (rows is! List || rows.isEmpty) return null;

    final parts = <String>[];
    for (final row in rows.take(1)) {
      if (row is! Map) continue;
      final marriageYear = _scalarDisplayText(row['marriage_year']);
      final separationYear = maritalStatusKey == 'separated'
          ? _scalarDisplayText(row['separation_year'])
          : null;
      final divorceYear =
          maritalStatusKey == 'divorced' || maritalStatusKey == 'annulled'
          ? _scalarDisplayText(row['divorce_year'])
          : null;
      final spouseDeathYear = maritalStatusKey == 'widowed'
          ? _scalarDisplayText(row['spouse_death_year'])
          : null;
      final legalStatus =
          maritalStatusKey == 'divorced' ||
              maritalStatusKey == 'annulled' ||
              maritalStatusKey == 'separated'
          ? ApiClient.safeDisplayLabel(row['divorce_status_label']) ??
                _divorceStatusLabel(
                  ApiClient.safeDisplayLabel(row['divorce_status']),
                )
          : null;
      final item = [
        if (marriageYear != null) 'Marriage $marriageYear',
        if (separationYear != null) 'Separated $separationYear',
        if (divorceYear != null)
          maritalStatusKey == 'annulled'
              ? 'Annulment $divorceYear'
              : 'Divorce $divorceYear',
        if (spouseDeathYear != null) 'Spouse death $spouseDeathYear',
        legalStatus,
      ].whereType<String>().join(' - ');
      if (item.isNotEmpty) parts.add(item);
    }

    return parts.isEmpty ? null : parts.join('; ');
  }

  String? _fallbackChildrenLabel(Map<String, dynamic> profile) {
    final rows = profile['children'];
    if (rows is! List || rows.isEmpty || !_readBool(profile['has_children'])) {
      return 'No children';
    }

    final parts = <String>[];
    var index = 0;
    for (final row in rows.take(3)) {
      if (row is! Map) continue;
      index++;
      final name =
          ApiClient.safeDisplayLabel(row['child_name']) ?? 'Child $index';
      final age = _scalarDisplayText(row['age']);
      final gender =
          ApiClient.safeDisplayLabel(row['gender_label']) ??
          _childGenderLabel(ApiClient.safeDisplayLabel(row['gender']));
      final livingWith = ApiClient.safeDisplayLabel(
        row['child_living_with_label'],
      );
      final item = [
        name,
        if (age != null) '$age years',
        gender,
        livingWith,
      ].whereType<String>().join(' - ');
      if (item.isNotEmpty) parts.add(item);
    }

    final remaining = rows.length - parts.length;
    if (remaining > 0) parts.add('+$remaining more');

    final countLabel = '${rows.length} child${rows.length == 1 ? '' : 'ren'}';
    return parts.isEmpty ? countLabel : '$countLabel - ${parts.join('; ')}';
  }

  String? _fallbackRelativesLabel(Map<String, dynamic> profile) {
    final rows = profile['relatives'];
    if (rows is! List || rows.isEmpty) return null;

    final parts = <String>[];
    for (final row in rows.take(3)) {
      if (row is! Map) continue;
      final relation =
          ApiClient.safeDisplayLabel(row['relation_type_label']) ??
          _relativeRelationLabel(
            ApiClient.safeDisplayLabel(row['relation_type']),
          );
      final name = ApiClient.safeDisplayLabel(row['name']);
      final occupation =
          ApiClient.safeDisplayLabel(row['occupation']) ??
          ApiClient.safeDisplayLabel(row['occupation_master_label']) ??
          ApiClient.safeDisplayLabel(row['occupation_custom_label']);
      final location =
          ApiClient.safeDisplayLabel(row['address_line']) ??
          ApiClient.safeDisplayLabel(row['city_label']);
      final item = [relation, name, occupation, location]
          .whereType<String>()
          .where((value) => value.trim().isNotEmpty)
          .join(' - ');
      if (item.isNotEmpty) parts.add(item);
    }

    final remaining = rows.length - parts.length;
    if (remaining > 0) parts.add('+$remaining more');

    return parts.isEmpty ? null : parts.join('; ');
  }

  String? _fallbackAllianceNetworksLabel(Map<String, dynamic> profile) {
    final rows = profile['alliance_networks'];
    if (rows is! List || rows.isEmpty) return null;

    final parts = <String>[];
    for (final row in rows.take(3)) {
      if (row is! Map) continue;
      final surname = ApiClient.safeDisplayLabel(row['surname']);
      final location =
          [
                ApiClient.safeDisplayLabel(row['city_label']),
                ApiClient.safeDisplayLabel(row['taluka_label']),
                ApiClient.safeDisplayLabel(row['district_label']),
                ApiClient.safeDisplayLabel(row['state_label']),
              ]
              .whereType<String>()
              .where((value) => value.trim().isNotEmpty)
              .join(', ');
      final item = [
        surname,
        if (location.isNotEmpty) location,
      ].whereType<String>().join(' - ');
      if (item.isNotEmpty) parts.add(item);
    }

    final remaining = rows.length - parts.length;
    if (remaining > 0) parts.add('+$remaining more');

    return parts.isEmpty ? null : parts.join('; ');
  }

  String? _divorceStatusLabel(String? value) {
    switch (value) {
      case 'pending':
        return 'Pending';
      case 'finalized':
        return 'Finalized';
      case 'mutual':
        return 'Mutual';
      case 'contested':
        return 'Contested';
      default:
        return value;
    }
  }

  String? _childGenderLabel(String? value) {
    switch (value) {
      case 'male':
        return 'Male';
      case 'female':
        return 'Female';
      case 'other':
        return 'Other';
      case 'prefer_not_say':
        return 'Prefer not to say';
      default:
        return value;
    }
  }

  String? _siblingRelationLabel(String? value) {
    switch (value) {
      case 'brother':
        return 'Brother';
      case 'sister':
        return 'Sister';
      case 'brother_wife':
        return "Brother's wife";
      case 'sister_husband':
        return "Sister's husband";
      default:
        return value;
    }
  }

  String? _siblingMaritalStatusLabel(String? value) {
    switch (value) {
      case 'married':
        return 'Married';
      case 'unmarried':
        return 'Unmarried';
      default:
        return value;
    }
  }

  String? _relativeRelationLabel(String? value) {
    switch (value) {
      case 'paternal_grandfather':
        return 'Paternal Grandfather';
      case 'paternal_grandmother':
        return 'Paternal Grandmother';
      case 'paternal_uncle':
        return 'Paternal Uncle';
      case 'wife_paternal_uncle':
        return 'Wife of Paternal Uncle';
      case 'paternal_aunt':
        return 'Paternal Aunt';
      case 'husband_paternal_aunt':
        return 'Husband of Paternal Aunt';
      case 'Cousin':
        return 'Cousin';
      case 'maternal_address_ajol':
        return 'Maternal address (Ajol)';
      case 'maternal_grandfather':
        return 'Maternal Grandfather';
      case 'maternal_grandmother':
        return 'Maternal Grandmother';
      case 'maternal_uncle':
        return 'Maternal Uncle';
      case 'wife_maternal_uncle':
        return "Maternal Uncle's wife";
      case 'maternal_aunt':
        return 'Maternal Aunt';
      case 'husband_maternal_aunt':
        return 'Husband of Maternal Aunt';
      case 'maternal_cousin':
        return 'Cousin';
      default:
        return value;
    }
  }

  void _addDisplayItem(
    List<ProfileDisplayItemData> items,
    String label,
    dynamic value,
  ) {
    final displayValue = ApiClient.safeDisplayLabel(value);
    if (displayValue == null || displayValue.isEmpty) return;

    items.add(ProfileDisplayItemData(label: label, value: displayValue));
  }

  String? _phoneDisplayText(dynamic value) {
    return _scalarDisplayText(value);
  }

  void _addPhoneDisplayItem(
    List<ProfileDisplayItemData> items,
    String label,
    dynamic value,
  ) {
    final displayValue = _phoneDisplayText(value);
    if (displayValue == null || displayValue.isEmpty) return;

    items.add(ProfileDisplayItemData(label: label, value: displayValue));
  }

  Widget _buildProfileHero(
    String? photoUrl,
    dynamic fullName,
    String? location,
  ) {
    final heroHeight = (MediaQuery.of(context).size.height * 0.52)
        .clamp(360.0, 520.0)
        .toDouble();
    final name = ApiClient.safeDisplayLabel(fullName);
    final title = name != null && name.isNotEmpty
        ? name.toUpperCase()
        : AppStrings.noInformation;

    return SizedBox(
      width: double.infinity,
      height: heroHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (photoUrl != null)
            Image.network(
              photoUrl,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (context, error, stackTrace) {
                return _buildProfileHeroFallback();
              },
            )
          else
            _buildProfileHeroFallback(),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.05),
                  Colors.black.withValues(alpha: 0.72),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                if (location != null && location.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    location,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeroFallback() {
    return Container(
      color: Colors.grey.shade300,
      alignment: Alignment.center,
      child: Icon(Icons.person, size: 132, color: Colors.grey.shade600),
    );
  }
}
