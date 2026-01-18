import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/api_routes.dart';

class ViewProfileScreen extends StatefulWidget {
  const ViewProfileScreen({super.key});

  @override
  State<ViewProfileScreen> createState() => _ViewProfileScreenState();
}

class _ViewProfileScreenState extends State<ViewProfileScreen> {
  Map<String, dynamic>? _profile;
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
        // Debug print - Profile response check करा
        print('=== VIEW PROFILE - FETCH PROFILE DEBUG ===');
        print('Full Response: $response');
        print('Profile Keys: ${response['profile'].keys.toList()}');
        print('profile_photo: ${response['profile']['profile_photo']}');
        print('profile_photo_url: ${response['profile']['profile_photo_url']}');
        print('url: ${response['profile']['url']}');
        print('photo_url: ${response['profile']['photo_url']}');
        print('==========================================');
        
        setState(() {
          _profile = response['profile'];
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
        title: const Text('माझे प्रोफाइल'),
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
      return const Center(child: Text('प्रोफाइल डेटा उपलब्ध नाही.'));
    }

    // सर्व्हरवरून फोटोची URL मिळवा
    // Backend GET profile मध्ये फक्त filename पाठवते, full URL नाही
    String? photoUrl;
    
    // First: Check for full URL fields (if backend provides)
    if (_profile!['profile_photo_url'] != null && _profile!['profile_photo_url'].toString().isNotEmpty) {
      photoUrl = _profile!['profile_photo_url'].toString();
    } else if (_profile!['url'] != null && _profile!['url'].toString().isNotEmpty) {
      photoUrl = _profile!['url'].toString();
    } else if (_profile!['photo_url'] != null && _profile!['photo_url'].toString().isNotEmpty) {
      photoUrl = _profile!['photo_url'].toString();
    }
    // Second: If only filename exists, construct full URL using ApiRoutes.baseUrl
    else if (_profile!['profile_photo'] != null && _profile!['profile_photo'].toString().isNotEmpty) {
      final filename = _profile!['profile_photo'].toString();
      // Extract base domain from ApiRoutes.baseUrl (remove '/api')
      final baseDomain = ApiRoutes.baseUrl.replaceAll('/api', '');
      // Construct URL: baseDomain + uploads path
      photoUrl = '$baseDomain/uploads/matrimony_photos/$filename';
    }
    
    // Debug print - Photo URL check करा
    print('=== VIEW PROFILE - PHOTO URL DEBUG ===');
    print('All Profile Keys: ${_profile!.keys.toList()}');
    print('profile_photo_url: ${_profile!['profile_photo_url']}');
    print('url: ${_profile!['url']}');
    print('profile_photo (filename): ${_profile!['profile_photo']}');
    print('photo_url: ${_profile!['photo_url']}');
    print('Final photoUrl (constructed): $photoUrl');
    print('=====================================');

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          // युझरचा फोटो दाखवण्यासाठी
          Center(
            child: CircleAvatar(
              radius: 80,
              backgroundColor: Colors.grey.shade300,
              backgroundImage: (photoUrl != null) ? NetworkImage(photoUrl as String) : null,
              child: (photoUrl == null)
                  ? const Icon(Icons.person, size: 80, color: Colors.grey)
                  : null,
            ),
          ),
          const SizedBox(height: 24),

          // प्रोफाइलची इतर माहिती दाखवण्यासाठी
          _buildProfileDetail('नाव', _profile!['full_name']),
          _buildProfileDetail('जन्मतारीख', _profile!['date_of_birth']),
          _buildProfileDetail('जात', _profile!['caste']),
          _buildProfileDetail('शिक्षण', _profile!['education']),
          _buildProfileDetail('ठिकाण', _profile!['location']),
        ],
      ),
    );
  }

  // माहिती सुंदर पद्धतीने दाखवण्यासाठी एक मदतनीस विजेट
  Widget _buildProfileDetail(String label, dynamic value) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Expanded(
              child: Text(
                value?.toString() ?? 'माहिती नाही',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}