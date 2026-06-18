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
    final location = ApiClient.profileLocationLabel(
      _profile,
      allowIdFallback: false,
    );
    final community = ApiClient.profileCommunityLabel(_profile);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _buildProfileHero(photoUrl, _profile!['full_name'], location),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            children: [
              // प्रोफाइलची इतर माहिती दाखवण्यासाठी
              _buildProfileDetail(AppStrings.name, _profile!['full_name']),
              _buildProfileDetail(
                AppStrings.dateOfBirth,
                _profile!['date_of_birth'],
              ),
              _buildProfileDetail('समुदाय', community),
              _buildProfileDetail(AppStrings.education, education),
              _buildProfileDetail(AppStrings.location, location),
            ],
          ),
        ),
      ],
    );
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

  // माहिती सुंदर पद्धतीने दाखवण्यासाठी एक मदतनीस विजेट
  Widget _buildProfileDetail(String label, dynamic value) {
    final displayValue = ApiClient.safeDisplayLabel(value);
    if (displayValue == null || displayValue.isEmpty) {
      return const SizedBox.shrink();
    }

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
                displayValue,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
