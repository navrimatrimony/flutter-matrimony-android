import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/api_client.dart';

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

    final photoUrl = ApiClient.resolveProfilePhotoUrl(_profile);
    final education = ApiClient.profileEducationLabel(_profile);
    final location = ApiClient.profileLocationLabel(_profile);
    final age = _calculateAge(_profile!['date_of_birth']?.toString());

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        // ========================================
        // HERO PROFILE PHOTO WITH OVERLAY
        // ========================================
        _buildHeroPhoto(photoUrl, _profile!['full_name'], age),
        
        // Send Interest Button (immediately below hero, always visible)
        if (_shouldShowSendInterestButton())
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
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
              _buildProfileDetail('शिक्षण', education),
              _buildProfileDetail('ठिकाण', location),
            ],
          ),
        ),
      ],
    );
  }

  // Build Hero Photo with Overlay Text (Unified Design: Blurred Background + Clear Foreground)
  Widget _buildHeroPhoto(String? photoUrl, dynamic fullName, int? age) {
    return Container(
      width: double.infinity,
      height: 300, // Large height for dominant visual (280-320px range)
      color: Colors.grey.shade300,
      child: photoUrl != null
          // If profile image exists: Show HERO with blurred background
          ? Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.hardEdge,
              children: [
                // Background layer: Blurred image (fills empty space)
                ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Image.network(
                    photoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      // Fallback: solid color if image fails
                      return Container(
                        color: Colors.grey.shade300,
                      );
                    },
                  ),
                ),
                // Slight dark overlay for contrast (optional)
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.3),
                      ],
                    ),
                  ),
                ),
                // Foreground layer: Clear image (full photo, no crop)
                Center(
                  child: Image.network(
                    photoUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      // Fallback to brand logo if image fails to load
                      return Image.asset(
                        'assets/images/brand_logo.png',
                        height: 200,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.person,
                            size: 120,
                            color: Colors.white,
                          );
                        },
                      );
                    },
                  ),
                ),
                // Dark gradient overlay for text readability (bottom)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: 100,
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
              ],
            )
          // If profile image does NOT exist: Show fallback
          : Stack(
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
