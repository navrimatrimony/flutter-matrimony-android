import 'package:flutter/material.dart';
import '../../core/app_strings.dart';
import '../../core/api_client.dart';
import '../matrimony_profile/profile_detail_screen.dart';

/// ===============================
/// BROWSE PROFILES SCREEN
/// ===============================
class BrowseProfilesScreen extends StatefulWidget {
  const BrowseProfilesScreen({super.key});

  @override
  State<BrowseProfilesScreen> createState() => _BrowseProfilesScreenState();
}

class _BrowseProfilesScreenState extends State<BrowseProfilesScreen> {
  List<dynamic> _profiles = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _locationSearching = false;
  int? _selectedLocationId;
  String? _selectedLocationLabel;
  int _locationSearchRequest = 0;
  List<Map<String, dynamic>> _locationSuggestions = <Map<String, dynamic>>[];

  // ========================================
  // SEARCH / FILTER UI CONTROLLERS (SSOT v2.5)
  // ========================================
  final TextEditingController _ageFromController = TextEditingController();
  final TextEditingController _ageToController = TextEditingController();
  final TextEditingController _casteController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchProfileList();
  }

  @override
  void dispose() {
    _ageFromController.dispose();
    _ageToController.dispose();
    _casteController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _fetchProfileList({
    int? ageFrom,
    int? ageTo,
    String? caste,
    int? locationId,
  }) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiClient.getProfileList(
        ageFrom: ageFrom,
        ageTo: ageTo,
        caste: caste,
        locationId: locationId,
      );
      if (!mounted) return;

      final statusCode = response['statusCode'];

      if (statusCode == 401) {
        setState(() {
          _errorMessage = '🔒 Auth expired! पुन्हा login करा';
          _isLoading = false;
        });
        return;
      }

      if (statusCode == 404) {
        setState(() {
          _errorMessage = '❌ प्रोफाइल सापडली नाही.';
          _isLoading = false;
        });
        return;
      }

      if (response['success'] == true && response['profiles'] is List) {
        setState(() {
          _profiles = List<dynamic>.from(response['profiles']);
          _isLoading = false;
        });
      } else {
        setState(() {
          _profiles = [];
          _errorMessage = '❌ प्रोफाइल सापडली नाही.';
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

  // Calculate age from date_of_birth
  int? _calculateAge(String? dateOfBirth) {
    if (dateOfBirth == null || dateOfBirth.isEmpty) return null;

    try {
      final dob = DateTime.parse(dateOfBirth);
      final now = DateTime.now();
      int age = now.year - dob.year;
      if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
        age--;
      }
      return age;
    } catch (_) {
      return null;
    }
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

    final results = await ApiClient.searchLocations(trimmedQuery);
    if (!mounted || requestId != _locationSearchRequest) return;

    setState(() {
      _locationSuggestions = results;
      _locationSearching = false;
    });
  }

  void _selectLocation(Map<String, dynamic> location) {
    final locationId = ApiClient.locationIdFrom(location);
    if (locationId == null) return;

    final label = ApiClient.locationSuggestionLabel(location);
    setState(() {
      _selectedLocationId = locationId;
      _selectedLocationLabel = label;
      _locationController.text = label;
      _locationSuggestions = <Map<String, dynamic>>[];
      _locationSearching = false;
    });
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.browseProfiles),
        automaticallyImplyLeading: true,
      ),
      backgroundColor: const Color(0xFFFAF7F5),
      body: Column(
        children: [
          // ========================================
          // SEARCH / FILTER UI (SSOT v2.5)
          // ========================================
          _buildSearchFilterUI(),
          // Profile List Body
          Expanded(
            child: _buildProfileListBody(),
          ),
        ],
      ),
    );
  }

  // Build Search/Filter UI form (SSOT v2.5)
  Widget _buildSearchFilterUI() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ageFromController,
                  keyboardType: TextInputType.number,
                  decoration: _filterDecoration('Age From'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _ageToController,
                  keyboardType: TextInputType.number,
                  decoration: _filterDecoration('Age To'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _casteController,
            decoration: _filterDecoration('Caste'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _locationController,
            decoration: _filterDecoration('Location'),
            onChanged: _searchLocations,
          ),
          _buildLocationSuggestions(),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _handleSearch,
            icon: const Icon(Icons.search),
            label: const Text('Search'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _filterDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFFCFBFA),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    );
  }

  Widget _buildLocationSuggestions() {
    if (_locationSearching) {
      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: LinearProgressIndicator(),
      );
    }

    if (_locationSuggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      constraints: const BoxConstraints(maxHeight: 180),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _locationSuggestions.length,
        itemBuilder: (context, index) {
          final location = _locationSuggestions[index];
          final label = ApiClient.locationSuggestionLabel(location);
          final hierarchy = location['hierarchy']?.toString().trim();

          return ListTile(
            dense: true,
            title: Text(label),
            subtitle: hierarchy != null &&
                    hierarchy.isNotEmpty &&
                    hierarchy != label
                ? Text(hierarchy)
                : null,
            onTap: () => _selectLocation(location),
          );
        },
      ),
    );
  }

  // Handle Search button tap
  void _handleSearch() {
    // Read values from fields and convert empty strings to null
    final ageFromText = _ageFromController.text.trim();
    final ageToText = _ageToController.text.trim();
    final casteText = _casteController.text.trim();
    final locationText = _locationController.text.trim();

    int? ageFrom;
    int? ageTo;
    String? caste;

    // Parse age_from
    if (ageFromText.isNotEmpty) {
      ageFrom = int.tryParse(ageFromText);
    }

    // Parse age_to
    if (ageToText.isNotEmpty) {
      ageTo = int.tryParse(ageToText);
    }

    // Set caste (null if empty)
    if (casteText.isNotEmpty) {
      caste = casteText;
    }

    if (locationText.isNotEmpty && _selectedLocationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('कृपया suggestions मधून location निवडा.'),
        ),
      );
      return;
    }

    // Call API with filters
    _fetchProfileList(
      ageFrom: ageFrom,
      ageTo: ageTo,
      caste: caste,
      locationId: _selectedLocationId,
    );
  }

  // Build profile list body with loading, error, and list states
  Widget _buildProfileListBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchProfileList,
                child: const Text('पुन्हा प्रयत्न करा'),
              ),
            ],
          ),
        ),
      );
    }

    if (_profiles.isEmpty) {
      return const Center(
        child: Text(
          'प्रोफाइल सापडली नाही.',
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchProfileList,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: _profiles.length,
        itemBuilder: (context, index) {
          final profile = _profiles[index] as Map<String, dynamic>;
          final photoUrl = ApiClient.resolveProfilePhotoUrl(profile);
          final age = _calculateAge(profile['date_of_birth']?.toString());
          final name = ApiClient.safeDisplayLabel(profile['full_name']) ??
              ApiClient.safeDisplayLabel(profile['name']) ??
              'नाव उपलब्ध नाही';
          final community = ApiClient.profileCommunityLabel(profile);
          final education = ApiClient.profileEducationLabel(profile);
          final location = ApiClient.profileLocationLabel(
            profile,
            allowIdFallback: false,
          );
          final nameLine = age != null ? '$name, $age वर्षे' : name;

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF3D9DE)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                final profileId = profile['id'] as int?;
                if (profileId != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileDetailScreen(profileId: profileId),
                    ),
                  );
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProfileThumb(photoUrl),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nameLine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (community != null) _buildProfileLine(community),
                          if (education != null) _buildProfileLine(education),
                          if (location != null)
                            _buildProfileLine(location, icon: Icons.place),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileThumb(String? photoUrl) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 86,
        height: 108,
        color: Colors.grey.shade300,
        child: photoUrl != null
            ? Image.network(
                photoUrl,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.person, size: 42, color: Colors.grey);
                },
              )
            : const Icon(Icons.person, size: 42, color: Colors.grey),
      ),
    );
  }

  Widget _buildProfileLine(String text, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: Colors.grey.shade700),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade800,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
