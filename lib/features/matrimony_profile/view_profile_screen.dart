import 'package:flutter/material.dart';
import '../../core/app_strings.dart';
import '../../core/api_client.dart';

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
    final education = ApiClient.profileEducationLabel(_profile);
    final location = ApiClient.profileLocationLabel(_profile);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          // युझरचा फोटो दाखवण्यासाठी
          Center(
            child: CircleAvatar(
              radius: 80,
              backgroundColor: Colors.grey.shade300,
              backgroundImage: (photoUrl != null) ? NetworkImage(photoUrl) : null,
              child: (photoUrl == null)
                  ? const Icon(Icons.person, size: 80, color: Colors.grey)
                  : null,
            ),
          ),
          const SizedBox(height: 24),

          // प्रोफाइलची इतर माहिती दाखवण्यासाठी
          _buildProfileDetail(AppStrings.name, _profile!['full_name']),
          _buildProfileDetail(
            AppStrings.dateOfBirth,
            _profile!['date_of_birth'],
          ),
          _buildProfileDetail(AppStrings.caste, _profile!['caste']),
          _buildProfileDetail(AppStrings.education, education),
          _buildProfileDetail(AppStrings.location, location),
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
                value?.toString() ?? AppStrings.noInformation,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
