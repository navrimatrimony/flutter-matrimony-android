import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/api_routes.dart';

/// ===============================
/// PROFILE DETAIL SCREEN (OTHER USER)
/// ===============================
class ProfileDetailScreen extends StatefulWidget {
  final int profileId;

  const ProfileDetailScreen({
    super.key,
    required this.profileId,
  });

  @override
  State<ProfileDetailScreen> createState() => _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends State<ProfileDetailScreen> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isSendingInterest = false;
  bool _interestSent = false;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final response = await ApiClient.getProfileDetail(widget.profileId);
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
  String? _constructPhotoUrl(Map<String, dynamic>? profile) {
    if (profile == null) return null;

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

  // Send interest to this profile
  Future<void> _sendInterest() async {
    if (_profile == null) return;

    setState(() {
      _isSendingInterest = true;
    });

    try {
      final response = await ApiClient.sendInterest(widget.profileId);
      if (!mounted) return;

      final statusCode = response['statusCode'];

      if (statusCode == 200 && response['success'] == true) {
        setState(() {
          _interestSent = true;
          _isSendingInterest = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Interest sent successfully.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else if (statusCode == 409) {
        setState(() {
          _interestSent = true;
          _isSendingInterest = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ℹ️ Interest already sent.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      } else if (statusCode == 401) {
        setState(() {
          _isSendingInterest = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔒 Auth expired! पुन्हा login करा'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        setState(() {
          _isSendingInterest = false;
        });
        final errorMessage = response['message'] ?? 'Interest send करता आला नाही.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ $errorMessage'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSendingInterest = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ एक अनपेक्षित एरर आली: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Check if Send Interest button should be visible
  bool _shouldShowSendInterestButton() {
    // User must be logged in
    if (ApiClient.authToken == null) return false;

    // Profile must be loaded
    if (_profile == null) return false;

    // Must not be viewing own profile
    final currentUserProfileId = ApiClient.currentUserProfile?['id'];
    final viewingProfileId = _profile!['id'];
    if (currentUserProfileId != null && currentUserProfileId == viewingProfileId) {
      return false;
    }

    return true;
  }

  // Check if interest is already sent
  bool _isInterestAlreadySent() {
    return ApiClient.sentInterestProfileIds.contains(widget.profileId) || _interestSent;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('प्रोफाइल'),
      ),
      body: _buildBody(),
    );
  }

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

    final photoUrl = _constructPhotoUrl(_profile);
    final age = _calculateAge(_profile!['date_of_birth']?.toString());

    return ListView(
      children: [
        // ========================================
        // HERO PROFILE PHOTO WITH OVERLAY (UI-ONLY CHANGE)
        // ========================================
        _buildHeroPhoto(photoUrl, _profile!['full_name'], age),
        
        // Profile Details Section
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // All 7 profile fields
          _buildProfileDetail('नाव', _profile!['full_name']),
          _buildProfileDetail('जन्मतारीख', _profile!['date_of_birth']),
          if (age != null)
            _buildProfileDetail('वय', '$age वर्षे'),
          _buildProfileDetail('जात', _profile!['caste']),
          _buildProfileDetail('शिक्षण', _profile!['education']),
          _buildProfileDetail('ठिकाण', _profile!['location']),

              // Send Interest Button
              if (_shouldShowSendInterestButton())
                Padding(
                  padding: const EdgeInsets.only(top: 24, bottom: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_isInterestAlreadySent() || _isSendingInterest) ? null : _sendInterest,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ).copyWith(
                        // Apply disabled style when interest is already sent
                        backgroundColor: _isInterestAlreadySent() && !_isSendingInterest
                            ? MaterialStateProperty.all(Colors.grey.shade400)
                            : null,
                      ),
                      child: _isSendingInterest
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              _isInterestAlreadySent() ? 'Interest Sent ✓' : 'Send Interest',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // Build Hero Photo with Overlay Text (UI-ONLY)
  Widget _buildHeroPhoto(String? photoUrl, dynamic fullName, int? age) {
    return Container(
      width: double.infinity,
      height: 300, // Large height for dominant visual
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        image: photoUrl != null
            ? DecorationImage(
                image: NetworkImage(photoUrl),
                fit: BoxFit.cover,
                onError: (exception, stackTrace) {
                  // Handle image load error silently
                },
              )
            : null,
      ),
      child: Stack(
        children: [
          // Dark gradient overlay for text readability
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.7),
                ],
              ),
            ),
          ),
          // Overlay text: Full Name and Age
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Text(
              age != null
                  ? '${fullName?.toString().toUpperCase() ?? 'नाव उपलब्ध नाही'}, $age'
                  : fullName?.toString().toUpperCase() ?? 'नाव उपलब्ध नाही',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    offset: Offset(1, 1),
                    blurRadius: 3,
                    color: Colors.black54,
                  ),
                ],
              ),
            ),
          ),
          // Fallback icon if no photo
          if (photoUrl == null)
            const Center(
              child: Icon(
                Icons.person,
                size: 120,
                color: Colors.grey,
              ),
            ),
        ],
      ),
    );
  }

  // Helper widget to display profile detail in card format
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
