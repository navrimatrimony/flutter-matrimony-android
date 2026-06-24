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
    final displaySections = _displaySections();
    final visibleSections = displaySections.isNotEmpty
        ? displaySections
        : _fallbackDisplaySections(_profile!, location);

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

  List<ProfileDisplaySectionData> _fallbackDisplaySections(
    Map<String, dynamic> profile,
    String? location,
  ) {
    final basicItems = <ProfileDisplayItemData>[];
    final birthItems = <ProfileDisplayItemData>[];
    final careerItems = <ProfileDisplayItemData>[];
    final familyItems = <ProfileDisplayItemData>[];
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
    _addDisplayItem(
      basicItems,
      'Height',
      ApiClient.profileHeightLabel(profile),
    );
    _addDisplayItem(
      basicItems,
      'Weight',
      profile['weight_kg'] == null ? null : '${profile['weight_kg']} kg',
    );
    _addDisplayItem(basicItems, 'Complexion', profile['complexion_label']);
    _addDisplayItem(basicItems, 'Blood Group', profile['blood_group_label']);
    _addDisplayItem(
      basicItems,
      'Physical Build',
      profile['physical_build_label'],
    );

    _addDisplayItem(birthItems, 'Birth Time', profile['birth_time']);
    _addDisplayItem(
      birthItems,
      'Birth Place',
      profile['birth_place_label'] ??
          profile['birth_place_text'] ??
          profile['birth_place'],
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
    if (!_readBool(profile['income_private'])) {
      _addDisplayItem(
        careerItems,
        'Annual Income',
        profile['income_display_label'] ??
            _fallbackIncomeLabel(profile, 'income', 'annual_income'),
      );
    }
    if (!_readBool(profile['family_income_private'])) {
      _addDisplayItem(
        familyItems,
        'Family Income',
        profile['family_income_display_label'] ??
            _fallbackIncomeLabel(profile, 'family_income', 'family_income'),
      );
    }
    if (showMarriageChildren) {
      _addDisplayItem(
        familyItems,
        'Marriage History',
        _fallbackMarriageHistoryLabel(profile, maritalStatusKey),
      );
      if (_readBool(profile['has_children'])) {
        _addDisplayItem(
          familyItems,
          'Children',
          _fallbackChildrenLabel(profile),
        );
      }
    }
    _addDisplayItem(
      familyItems,
      'Parents Addresses',
      _fallbackAddressRowsLabel(profile, 'parents_addresses'),
    );
    _addDisplayItem(familyItems, 'Siblings', _fallbackSiblingsLabel(profile));
    _addDisplayItem(familyItems, 'Relatives', _fallbackRelativesLabel(profile));
    _addDisplayItem(
      familyItems,
      'Alliance Network',
      _fallbackAllianceNetworksLabel(profile),
    );

    return [
      if (basicItems.isNotEmpty)
        ProfileDisplaySectionData(
          key: 'basic',
          title: 'Basic Details',
          items: basicItems,
        ),
      if (birthItems.isNotEmpty)
        ProfileDisplaySectionData(
          key: 'birth_details',
          title: 'Birth Details',
          items: birthItems,
        ),
      if (careerItems.isNotEmpty)
        ProfileDisplaySectionData(
          key: 'career_education',
          title: 'Career & Education',
          items: careerItems,
        ),
      if (familyItems.isNotEmpty)
        ProfileDisplaySectionData(
          key: 'family',
          title: 'Family Details',
          items: familyItems,
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
    if (valueType == 'undisclosed') return null;

    final currency =
        ApiClient.safeDisplayLabel(profile['${prefix}_currency_symbol']) ?? '₹';
    if (valueType == 'range') {
      final min = ApiClient.safeDisplayLabel(profile['${prefix}_min_amount']);
      final max = ApiClient.safeDisplayLabel(profile['${prefix}_max_amount']);
      if (min != null && max != null) return '$currency$min - $currency$max';
      if (min != null) return '$currency$min+';
      if (max != null) return 'Up to $currency$max';
      return null;
    }

    final amount =
        ApiClient.safeDisplayLabel(profile['${prefix}_amount']) ??
        ApiClient.safeDisplayLabel(profile[legacyKey]);
    return amount == null ? null : '$currency$amount';
  }

  String? _fallbackSiblingsLabel(Map<String, dynamic> profile) {
    final rows = profile['siblings'];
    if (rows is! List || rows.isEmpty) return null;

    var brothers = 0;
    var sisters = 0;
    var others = 0;
    for (final row in rows) {
      if (row is! Map) continue;
      switch (ApiClient.safeDisplayLabel(row['relation_type'])) {
        case 'brother':
          brothers++;
          break;
        case 'sister':
          sisters++;
          break;
        default:
          others++;
          break;
      }
    }

    final parts = <String>[
      if (brothers > 0) '$brothers Brother${brothers == 1 ? '' : 's'}',
      if (sisters > 0) '$sisters Sister${sisters == 1 ? '' : 's'}',
      if (others > 0) '$others Sibling${others == 1 ? '' : 's'}',
    ];

    return parts.isEmpty ? null : parts.join(', ');
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
      final marriageYear = ApiClient.safeDisplayLabel(row['marriage_year']);
      final separationYear = maritalStatusKey == 'separated'
          ? ApiClient.safeDisplayLabel(row['separation_year'])
          : null;
      final divorceYear =
          maritalStatusKey == 'divorced' || maritalStatusKey == 'annulled'
          ? ApiClient.safeDisplayLabel(row['divorce_year'])
          : null;
      final spouseDeathYear = maritalStatusKey == 'widowed'
          ? ApiClient.safeDisplayLabel(row['spouse_death_year'])
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
    if (rows is! List || rows.isEmpty) return null;

    final parts = <String>[];
    var index = 0;
    for (final row in rows.take(3)) {
      if (row is! Map) continue;
      index++;
      final name =
          ApiClient.safeDisplayLabel(row['child_name']) ?? 'Child $index';
      final age = ApiClient.safeDisplayLabel(row['age']);
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

    return parts.isEmpty ? null : parts.join('; ');
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
