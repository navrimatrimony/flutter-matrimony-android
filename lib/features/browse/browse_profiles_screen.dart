import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/api_routes.dart';
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

  @override
  void initState() {
    super.initState();
    print('🔥 BrowseProfilesScreen initState CALLED');
    _fetchProfileList();
  }

  Future<void> _fetchProfileList() async {
    print('🔥 _fetchProfileList STARTED');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiClient.getProfileList();
      if (!mounted) return;

      // >>>>> DEBUG: RESPONSE PROCESSING <<<<<
      print('=== BROWSE PROFILES SCREEN - PROCESSING RESPONSE ===');
      print('Response received from API');
      print('Response keys: ${response.keys.toList()}');
      
      final statusCode = response['statusCode'];
      print('Status Code: $statusCode');

      if (statusCode == 401) {
        print('❌ Path: StatusCode 401 - Auth expired');
        setState(() {
          _errorMessage = '🔒 Auth expired! पुन्हा login करा';
          _isLoading = false;
        });
        return;
      }

      if (statusCode == 404) {
        print('❌ Path: StatusCode 404 - Profiles not found');
        setState(() {
          _errorMessage = '❌ प्रोफाइल सापडली नाही.';
          _isLoading = false;
        });
        return;
      }

      print('Checking success and profiles...');
      print('response["success"]: ${response['success']}');
      print('response["success"] == true: ${response['success'] == true}');
      print('response["profiles"]: ${response['profiles']}');
      print('response["profiles"] is List: ${response['profiles'] is List}');

      if (response['success'] == true && response['profiles'] is List) {
        print('✅ Path: SUCCESS - Loading profiles list');
        final profilesList = response['profiles'] as List;
        print('Profiles list length: ${profilesList.length}');
        setState(() {
          _profiles = List<dynamic>.from(response['profiles']);
          _isLoading = false;
        });
        print('✅ Profiles loaded: ${_profiles.length} items');
      } else {
        print('❌ Path: ELSE BRANCH - Success/profiles check failed');
        print('Reason: success=${response['success']}, profiles is List=${response['profiles'] is List}');
        setState(() {
          _profiles = [];
          _errorMessage = '❌ प्रोफाइल सापडली नाही.';
          _isLoading = false;
        });
      }
      print('==========================================');

    } catch (e) {
      print('❌ EXCEPTION in _fetchProfileList: $e');
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

  // Construct photo URL using filename-based rule (per SSOT)
  String? _constructPhotoUrl(Map<String, dynamic> profile) {
    // First: Check for full URL fields (if backend provides)
    if (profile['profile_photo_url'] != null && profile['profile_photo_url'].toString().isNotEmpty) {
      return profile['profile_photo_url'].toString();
    } else if (profile['url'] != null && profile['url'].toString().isNotEmpty) {
      return profile['url'].toString();
    } else if (profile['photo_url'] != null && profile['photo_url'].toString().isNotEmpty) {
      return profile['photo_url'].toString();
    }
    // Second: If only filename exists, construct full URL using ApiRoutes.baseUrl
    else if (profile['profile_photo'] != null && profile['profile_photo'].toString().isNotEmpty) {
      final filename = profile['profile_photo'].toString();
      final baseDomain = ApiRoutes.baseUrl.replaceAll('/api', '');
      return '$baseDomain/uploads/matrimony_photos/$filename';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Browse Profiles'),
        automaticallyImplyLeading: true,
      ),
      body: _buildProfileListBody(),
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
        padding: const EdgeInsets.all(16.0),
        itemCount: _profiles.length,
        itemBuilder: (context, index) {
          final profile = _profiles[index] as Map<String, dynamic>;
          final photoUrl = _constructPhotoUrl(profile);
          final age = _calculateAge(profile['date_of_birth']?.toString());

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            child: InkWell(
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
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Photo
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.grey.shade300,
                      backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                      child: photoUrl == null
                          ? const Icon(Icons.person, size: 40, color: Colors.grey)
                          : null,
                    ),
                    const SizedBox(width: 16),
                    // Profile Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile['full_name']?.toString() ?? 'नाव उपलब्ध नाही',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (profile['caste'] != null && profile['caste'].toString().isNotEmpty)
                            Text(
                              'जात: ${profile['caste']}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          if (profile['location'] != null && profile['location'].toString().isNotEmpty)
                            Text(
                              'ठिकाण: ${profile['location']}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          if (age != null)
                            Text(
                              'वय: $age वर्षे',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                              ),
                            ),
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
}
