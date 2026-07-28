import 'package:flutter/material.dart';
import '../../core/app_language.dart';
import '../../core/app_loading.dart';
import '../../core/app_strings.dart';
import '../../core/api_client.dart';
import '../../core/profile_network_image.dart';
import 'edit_full_profile_screen.dart';
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
    _seedCachedProfile();
    _fetchProfile();
  }

  void _seedCachedProfile() {
    final cachedProfile = ApiClient.currentUserProfile;
    if (cachedProfile == null || cachedProfile.isEmpty) return;

    _profile = Map<String, dynamic>.from(cachedProfile);
    _isLoading = false;
  }

  Future<void> _fetchProfile({bool forceRefresh = false}) async {
    // स्क्रीन सुरू झाल्यावर, सर्व्हरवरून प्रोफाइलची ताजी माहिती मागवा
    try {
      final response = await ApiClient.getMyProfile(forceRefresh: forceRefresh);
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
          _errorMessage = response['message'] ?? appText.couldNotLoadProfile;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = appText.unexpectedErrorOccurred(e.toString());
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
              });
              _fetchProfile(forceRefresh: true);
            },
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomActions(),
      body: _buildBody(),
    );
  }

  Widget _buildBottomActions() {
    final enabled = !_isLoading && _profile != null;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: enabled ? _openEditProfile : null,
                icon: const Icon(Icons.edit_outlined),
                label: Text(AppStrings.editProfile),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: enabled
                    ? () => Navigator.pushNamed(context, '/biodata-export')
                    : null,
                icon: const Icon(Icons.print_outlined),
                label: Text(AppStrings.biodataPrintAction),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openEditProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditFullProfileScreen(initialProfile: _profile),
      ),
    );
  }

  // स्क्रीनचा मुख्य भाग तयार करणारा विजेट
  Widget _buildBody() {
    if (_isLoading && _profile == null) {
      return AppLoadingState.profile();
    }

    if (_errorMessage != null && _profile == null) {
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
        if (_isLoading) const LinearProgressIndicator(minHeight: 3),
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
      appText.gender,
      profile['gender_label'] ?? profile['gender_name'] ?? profile['gender'],
    );
    _addDisplayItem(
      basicItems,
      appText.community,
      ApiClient.profileCommunityLabel(profile),
    );
    _addDisplayItem(basicItems, AppStrings.location, location);
    final selfAddressLabel = _fallbackAddressRowsLabel(
      profile,
      'self_addresses',
    );
    if (selfAddressLabel != null) {
      _addDisplayItem(basicItems, appText.labelSelfAddresses, selfAddressLabel);
    } else {
      _addDisplayItem(
        basicItems,
        appText.labelAddressLine,
        profile['address_line'],
      );
    }
    _addDisplayItem(
      basicItems,
      appText.motherTongue2,
      profile['mother_tongue_label'],
    );
    _addDisplayItem(basicItems, appText.labelBirthTime, profile['birth_time']);
    _addDisplayItem(
      basicItems,
      appText.labelBirthPlace,
      profile['birth_place_label'] ??
          profile['birth_place_text'] ??
          profile['birth_place'],
    );
    _addDisplayItem(
      basicItems,
      appText.maritalStatus,
      profile['marital_status_label'] ?? profile['marital_status_key'],
    );
    if (showMarriageChildren) {
      _addDisplayItem(
        basicItems,
        appText.labelMarriageHistory,
        _fallbackMarriageHistoryLabel(profile, maritalStatusKey),
      );
      _addDisplayItem(
        basicItems,
        appText.labelChildren,
        _fallbackChildrenLabel(profile),
      );
    }
    _addDisplayItem(
      physicalItems,
      appText.heightLabel,
      ApiClient.profileHeightLabel(profile),
    );
    _addDisplayItem(
      physicalItems,
      appText.labelWeight,
      profile['weight_kg'] == null ? null : '${profile['weight_kg']} kg',
    );
    _addDisplayItem(
      physicalItems,
      appText.labelComplexion,
      profile['complexion_label'],
    );
    _addDisplayItem(
      physicalItems,
      appText.labelBloodGroup,
      profile['blood_group_label'],
    );
    _addDisplayItem(
      physicalItems,
      appText.physicalBuild,
      profile['physical_build_label'],
    );
    _addDisplayItem(
      physicalItems,
      appText.spectaclesLens,
      profile['spectacles_lens'],
    );
    _addDisplayItem(
      physicalItems,
      appText.labelPhysicalCondition,
      profile['physical_condition'],
    );
    _addDisplayItem(physicalItems, appText.diet, profile['diet_label']);
    _addDisplayItem(
      physicalItems,
      appText.smoking,
      profile['smoking_status_label'],
    );
    _addDisplayItem(
      physicalItems,
      appText.drinking,
      profile['drinking_status_label'],
    );

    _addDisplayItem(
      careerItems,
      appText.labelHighestEducation,
      ApiClient.profileEducationLabel(profile),
    );
    _addDisplayItem(
      careerItems,
      appText.occupation,
      profile['occupation_master_label'] ??
          profile['occupation_custom_label'] ??
          ApiClient.profileOccupationLabel(profile),
    );
    _addDisplayItem(
      careerItems,
      appText.labelCompanyName,
      profile['company_name'],
    );
    _addDisplayItem(
      careerItems,
      appText.labelWorkLocation,
      profile['work_location_label'] ?? profile['work_location_text'],
    );
    _addDisplayItem(
      careerItems,
      appText.annualIncome,
      _fallbackIncomeLabel(profile, 'income', 'annual_income') ??
          profile['income_display_label'] ??
          appText.valueNotAdded,
    );
    _addDisplayItem(
      familyItems,
      appText.labelFather,
      _parentSummary(profile, 'father'),
    );
    _addPhoneDisplayItem(
      familyItems,
      appText.labelFatherContactNumbered(1),
      profile['father_contact_1'],
    );
    _addPhoneDisplayItem(
      familyItems,
      appText.labelFatherContactNumbered(2),
      profile['father_contact_2'],
    );
    _addPhoneDisplayItem(
      familyItems,
      appText.labelFatherContactNumbered(3),
      profile['father_contact_3'],
    );
    _addDisplayItem(
      familyItems,
      appText.labelMother,
      _parentSummary(profile, 'mother'),
    );
    _addPhoneDisplayItem(
      familyItems,
      appText.labelMotherContactNumbered(1),
      profile['mother_contact_1'],
    );
    _addPhoneDisplayItem(
      familyItems,
      appText.labelMotherContactNumbered(2),
      profile['mother_contact_2'],
    );
    _addPhoneDisplayItem(
      familyItems,
      appText.labelMotherContactNumbered(3),
      profile['mother_contact_3'],
    );
    _addDisplayItem(
      familyItems,
      appText.labelFamilyIncome,
      _fallbackIncomeLabel(profile, 'family_income', 'family_income') ??
          profile['family_income_display_label'] ??
          appText.valueNotAdded,
    );
    _addDisplayItem(
      familyItems,
      appText.labelFamilyType,
      profile['family_type_label'],
    );
    _addDisplayItem(
      familyItems,
      appText.familyStatus,
      profile['family_status'],
    );
    _addDisplayItem(
      familyItems,
      appText.familyValues,
      profile['family_values'],
    );
    _addDisplayItem(
      familyItems,
      appText.labelParentsAddresses,
      _fallbackAddressRowsLabel(profile, 'parents_addresses'),
    );
    _addDisplayItem(
      siblingItems,
      appText.sectionSiblings,
      _fallbackSiblingsLabel(profile),
    );
    _addDisplayItem(
      relativeItems,
      appText.sectionRelatives,
      _fallbackRelativesLabel(profile),
    );
    _addDisplayItem(
      relativeItems,
      appText.labelAllianceNetwork,
      _fallbackAllianceNetworksLabel(profile),
    );
    _addDisplayItem(
      relativeItems,
      appText.labelOtherRelatives,
      profile['other_relatives_text'],
    );
    _addDisplayItem(
      propertyItems,
      appText.labelPropertyDetails,
      profile['property_details'],
    );

    _addDisplayItem(horoscopeItems, appText.rashi, profile['rashi_label']);
    _addDisplayItem(
      horoscopeItems,
      appText.nakshatra,
      profile['nakshatra_label'],
    );
    _addDisplayItem(horoscopeItems, appText.charan, profile['charan']);
    _addDisplayItem(horoscopeItems, appText.labelGan, profile['gan_label']);
    _addDisplayItem(horoscopeItems, appText.labelNadi, profile['nadi_label']);
    _addDisplayItem(horoscopeItems, appText.labelYoni, profile['yoni_label']);
    _addDisplayItem(horoscopeItems, appText.labelVarna, profile['varna_label']);
    _addDisplayItem(
      horoscopeItems,
      appText.labelVashya,
      profile['vashya_label'],
    );
    _addDisplayItem(
      horoscopeItems,
      appText.labelRashiLord,
      profile['rashi_lord_label'],
    );
    _addDisplayItem(
      horoscopeItems,
      appText.mangalDosh,
      profile['mangal_dosh_type_label'],
    );
    _addDisplayItem(horoscopeItems, appText.labelDevak, profile['devak']);
    _addDisplayItem(horoscopeItems, appText.labelKul, profile['kul']);
    _addDisplayItem(horoscopeItems, appText.labelGotra, profile['gotra']);
    _addDisplayItem(
      horoscopeItems,
      appText.labelNavrasName,
      profile['navras_name'],
    );
    _addDisplayItem(
      horoscopeItems,
      appText.labelBirthWeekday,
      profile['birth_weekday'],
    );

    _addDisplayItem(
      aboutItems,
      appText.sectionAboutMe,
      profile['narrative_about_me'],
    );
    _addDisplayItem(
      aboutItems,
      appText.labelExpectations,
      profile['narrative_expectations'],
    );

    _addDisplayItem(
      preferenceItems,
      appText.ageRange,
      _rangeLabel(profile['preferred_age_min'], profile['preferred_age_max']),
    );
    _addDisplayItem(
      preferenceItems,
      appText.labelHeightRange,
      _rangeLabel(
        profile['preferred_height_min_cm'],
        profile['preferred_height_max_cm'],
        suffix: ' cm',
      ),
    );
    _addDisplayItem(
      preferenceItems,
      appText.incomeRange,
      profile['preferred_income_label'] ??
          _rangeLabel(
            profile['preferred_income_min'],
            profile['preferred_income_max'],
            prefix: '₹',
          ),
    );
    _addDisplayItem(
      preferenceItems,
      appText.marriageType,
      profile['marriage_type_preference_label'],
    );
    _addDisplayItem(
      preferenceItems,
      appText.labelPartnerWithChildren,
      profile['partner_profile_with_children_label'],
    );
    _addDisplayItem(
      preferenceItems,
      appText.profileManagedBy,
      profile['preferred_profile_managed_by_label'],
    );
    _addDisplayItem(
      preferenceItems,
      appText.willingToRelocate,
      profile['willing_to_relocate'],
    );
    _addDisplayItem(
      preferenceItems,
      appText.labelPreferredMaritalStatus,
      _joinDisplayValues(profile['preferred_marital_status_labels']),
    );
    _addDisplayItem(
      preferenceItems,
      appText.labelPreferredDiet,
      _joinDisplayValues(profile['preferred_diet_labels']),
    );
    _addDisplayItem(
      preferenceItems,
      appText.labelPreferredReligion,
      _joinDisplayValues(profile['preferred_religion_labels']),
    );
    _addDisplayItem(
      preferenceItems,
      appText.labelPreferredCaste,
      _joinDisplayValues(profile['preferred_caste_labels']),
    );
    _addDisplayItem(
      preferenceItems,
      appText.labelPreferredEducation,
      _joinDisplayValues(profile['preferred_education_degree_labels']),
    );
    _addDisplayItem(
      preferenceItems,
      appText.labelPreferredOccupation,
      _joinDisplayValues(profile['preferred_occupation_master_labels']),
    );
    _addDisplayItem(
      photoItems,
      appText.labelPhotoStatus,
      _photoStatusLabel(profile),
    );

    return [
      if (basicItems.isNotEmpty)
        ProfileDisplaySectionData(
          key: 'basic-info',
          title: appText.sectionBasicInformation,
          items: basicItems,
        ),
      if (physicalItems.isNotEmpty)
        ProfileDisplaySectionData(
          key: 'physical',
          title: appText.sectionPhysical,
          items: physicalItems,
        ),
      if (careerItems.isNotEmpty)
        ProfileDisplaySectionData(
          key: 'education-career',
          title: appText.educationCareer,
          items: careerItems,
        ),
      if (familyItems.isNotEmpty)
        ProfileDisplaySectionData(
          key: 'family-details',
          title: appText.familyDetails,
          items: familyItems,
        ),
      if (siblingItems.isNotEmpty)
        ProfileDisplaySectionData(
          key: 'siblings',
          title: appText.sectionSiblings,
          items: siblingItems,
        ),
      if (relativeItems.isNotEmpty)
        ProfileDisplaySectionData(
          key: 'relatives',
          title: appText.sectionRelatives,
          items: relativeItems,
        ),
      if (propertyItems.isNotEmpty)
        ProfileDisplaySectionData(
          key: 'property',
          title: appText.sectionProperty,
          items: propertyItems,
        ),
      if (horoscopeItems.isNotEmpty)
        ProfileDisplaySectionData(
          key: 'horoscope',
          title: appText.sectionHoroscope,
          items: horoscopeItems,
        ),
      if (aboutItems.isNotEmpty)
        ProfileDisplaySectionData(
          key: 'about-me',
          title: appText.sectionAboutMe,
          items: aboutItems,
        ),
      if (preferenceItems.isNotEmpty)
        ProfileDisplaySectionData(
          key: 'about-preferences',
          title: appText.sectionPartnerPreferences,
          items: preferenceItems,
        ),
      if (photoItems.isNotEmpty)
        ProfileDisplaySectionData(
          key: 'photo',
          title: appText.dashboardPhoto,
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
      return appText.valuePhotoUploaded;
    }

    final status = ApiClient.safeDisplayLabel(profile['photo_status']);
    if (status != null) return status;

    final approved = profile['photo_approved'];
    if (approved == false || approved == 0 || approved == '0') {
      return appText.valuePhotoPendingOrNotApproved;
    }

    return appText.valueNoApprovedPhoto;
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

    return appText.valueUpTo('$prefix$maxText$suffix');
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
    if (valueType == 'undisclosed') return appText.valueUndisclosed;

    final currency =
        ApiClient.safeDisplayLabel(profile['${prefix}_currency_symbol']) ?? '₹';
    if (valueType == 'range') {
      final min = _scalarDisplayText(profile['${prefix}_min_amount']);
      final max = _scalarDisplayText(profile['${prefix}_max_amount']);
      if (min != null && max != null) return '$currency$min - $currency$max';
      if (min != null) return '$currency$min+';
      if (max != null) return appText.valueUpTo('$currency$max');
      return null;
    }

    final amount =
        _scalarDisplayText(profile['${prefix}_amount']) ??
        _scalarDisplayText(profile[legacyKey]);
    if (amount == null) return null;
    if (valueType == 'approximate') {
      return appText.valueApproxAmount('$currency$amount');
    }

    return '$currency$amount';
  }

  String? _fallbackSiblingsLabel(Map<String, dynamic> profile) {
    final rows = profile['siblings'];
    if (rows is! List || rows.isEmpty) return appText.valueNoSiblings;

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
    if (remaining > 0) parts.add(appText.valueMoreCount(remaining));

    final countLabel = rows.length == 1
        ? appText.siblingCountOne
        : appText.siblingCountOther(rows.length);
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
        if (marriageYear != null) appText.valueMarriageYear(marriageYear),
        if (separationYear != null) appText.valueSeparatedYear(separationYear),
        if (divorceYear != null)
          maritalStatusKey == 'annulled'
              ? appText.valueAnnulmentYear(divorceYear)
              : appText.valueDivorceYear(divorceYear),
        if (spouseDeathYear != null)
          appText.valueSpouseDeathYear(spouseDeathYear),
        legalStatus,
      ].whereType<String>().join(' - ');
      if (item.isNotEmpty) parts.add(item);
    }

    return parts.isEmpty ? null : parts.join('; ');
  }

  String? _fallbackChildrenLabel(Map<String, dynamic> profile) {
    final rows = profile['children'];
    if (rows is! List || rows.isEmpty || !_readBool(profile['has_children'])) {
      return appText.noChildren;
    }

    final parts = <String>[];
    var index = 0;
    for (final row in rows.take(3)) {
      if (row is! Map) continue;
      index++;
      final name =
          ApiClient.safeDisplayLabel(row['child_name']) ??
          appText.valueChildNumbered(index);
      final age = _scalarDisplayText(row['age']);
      final gender =
          ApiClient.safeDisplayLabel(row['gender_label']) ??
          _childGenderLabel(ApiClient.safeDisplayLabel(row['gender']));
      final livingWith = ApiClient.safeDisplayLabel(
        row['child_living_with_label'],
      );
      final item = [
        name,
        if (age != null) appText.valueAgeYears(age),
        gender,
        livingWith,
      ].whereType<String>().join(' - ');
      if (item.isNotEmpty) parts.add(item);
    }

    final remaining = rows.length - parts.length;
    if (remaining > 0) parts.add(appText.valueMoreCount(remaining));

    final countLabel = rows.length == 1
        ? appText.childCountOne
        : appText.childCountOther(rows.length);
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
      final details =
          ApiClient.safeDisplayLabel(row['relative_details']) ??
          _legacyRelativeDetails(row);
      final item = [relation, details]
          .whereType<String>()
          .where((value) => value.trim().isNotEmpty)
          .join(' - ');
      if (item.isNotEmpty) parts.add(item);
    }

    final remaining = rows.length - parts.length;
    if (remaining > 0) parts.add(appText.valueMoreCount(remaining));

    return parts.isEmpty ? null : parts.join('; ');
  }

  String? _legacyRelativeDetails(Map<dynamic, dynamic> row) {
    final parts = <String>[
      ?ApiClient.safeDisplayLabel(row['name']),
      ?ApiClient.safeDisplayLabel(row['occupation']),
      ?ApiClient.safeDisplayLabel(row['occupation_master_label']),
      ?ApiClient.safeDisplayLabel(row['occupation_custom_label']),
      ?ApiClient.safeDisplayLabel(row['address_line']),
      ?ApiClient.safeDisplayLabel(row['city_label']),
      ?ApiClient.safeDisplayLabel(row['notes']),
    ].where((value) => value.trim().isNotEmpty).toList();

    if (parts.isEmpty) return null;
    return parts.toSet().join(' - ');
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
    if (remaining > 0) parts.add(appText.valueMoreCount(remaining));

    return parts.isEmpty ? null : parts.join('; ');
  }

  String? _divorceStatusLabel(String? value) {
    switch (value) {
      case 'pending':
        return appText.pending;
      case 'finalized':
        return appText.valueFinalized;
      case 'mutual':
        return appText.valueMutual;
      case 'contested':
        return appText.valueContested;
      default:
        return value;
    }
  }

  String? _childGenderLabel(String? value) {
    switch (value) {
      case 'male':
        return appText.male;
      case 'female':
        return appText.female;
      case 'other':
        return appText.other;
      case 'prefer_not_say':
        return appText.valuePreferNotToSay;
      default:
        return value;
    }
  }

  String? _siblingRelationLabel(String? value) {
    switch (value) {
      case 'brother':
        return appText.brother;
      case 'sister':
        return appText.sister;
      case 'brother_wife':
        return appText.relationBrotherWife;
      case 'sister_husband':
        return appText.relationSisterHusband;
      default:
        return value;
    }
  }

  String? _siblingMaritalStatusLabel(String? value) {
    switch (value) {
      case 'married':
        return appText.valueMarried;
      case 'unmarried':
        return appText.valueUnmarried;
      default:
        return value;
    }
  }

  String? _relativeRelationLabel(String? value) {
    switch (value) {
      case 'paternal_grandfather':
        return appText.relationPaternalGrandfather;
      case 'paternal_grandmother':
        return appText.relationPaternalGrandmother;
      case 'paternal_uncle':
        return appText.relationPaternalUncle;
      case 'wife_paternal_uncle':
        return appText.relationPaternalUncleWife;
      case 'paternal_aunt':
        return appText.relationPaternalAunt;
      case 'husband_paternal_aunt':
        return appText.relationPaternalAuntHusband;
      case 'Cousin':
        return appText.relationCousin;
      case 'maternal_address_ajol':
        return appText.relationMaternalAddressAjol;
      case 'maternal_grandfather':
        return appText.relationMaternalGrandfather;
      case 'maternal_grandmother':
        return appText.relationMaternalGrandmother;
      case 'maternal_uncle':
        return appText.relationMaternalUncle;
      case 'wife_maternal_uncle':
        return appText.relationMaternalUncleWife;
      case 'maternal_aunt':
        return appText.relationMaternalAunt;
      case 'husband_maternal_aunt':
        return appText.relationMaternalAuntHusband;
      case 'maternal_cousin':
        return appText.relationCousin;
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
            ProfileNetworkImage(
              url: photoUrl,
              placeholder: _buildProfileHeroFallback(),
              decodeWidth: MediaQuery.sizeOf(context).width,
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
