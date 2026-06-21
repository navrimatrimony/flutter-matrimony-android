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

    final allSections = rawSections
        .map(ProfileDisplaySectionData.fromMap)
        .whereType<ProfileDisplaySectionData>()
        .toList();
    final sections = allSections.where(_isCurrentEditAllSection).toList();

    final birthSection = _birthDetailsSection(allSections);
    if (birthSection == null) return sections;

    final insertIndex = sections.indexWhere((section) {
      final key = section.key.trim().toLowerCase();
      return key == 'career_education';
    });
    if (insertIndex <= 0) {
      return <ProfileDisplaySectionData>[birthSection, ...sections];
    }

    return <ProfileDisplaySectionData>[
      ...sections.take(insertIndex),
      birthSection,
      ...sections.skip(insertIndex),
    ];
  }

  bool _isCurrentEditAllSection(ProfileDisplaySectionData section) {
    final key = section.key.trim().toLowerCase();
    return key == 'basic' || key == 'career_education';
  }

  ProfileDisplaySectionData? _birthDetailsSection(
    List<ProfileDisplaySectionData> sections,
  ) {
    final astro = _sectionByKey(sections, 'astro');
    final items = <ProfileDisplayItemData>[];

    if (astro != null) {
      for (final item in astro.items) {
        final label = item.label.trim().toLowerCase();
        if (label == 'birth time' || label == 'birth place') {
          items.add(item);
        }
      }
    }

    if (items.isEmpty && _profile != null) {
      _addDisplayItem(items, 'Birth Time', _profile!['birth_time']);
      _addDisplayItem(
        items,
        'Birth Place',
        _profile!['birth_place_label'] ??
            _profile!['birth_place_text'] ??
            _profile!['birth_place'],
      );
    }

    if (items.isEmpty) return null;

    return ProfileDisplaySectionData(
      key: 'birth_details',
      title: 'Birth Details',
      items: items,
    );
  }

  ProfileDisplaySectionData? _sectionByKey(
    List<ProfileDisplaySectionData> sections,
    String key,
  ) {
    for (final section in sections) {
      if (section.key.trim().toLowerCase() == key) return section;
    }
    return null;
  }

  List<ProfileDisplaySectionData> _fallbackDisplaySections(
    Map<String, dynamic> profile,
    String? location,
  ) {
    final basicItems = <ProfileDisplayItemData>[];
    final birthItems = <ProfileDisplayItemData>[];
    final careerItems = <ProfileDisplayItemData>[];

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
    ];
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
