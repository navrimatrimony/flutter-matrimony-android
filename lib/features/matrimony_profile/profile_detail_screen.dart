import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_client.dart';
import '../../core/app_strings.dart';

/// ===============================
/// PROFILE DETAIL SCREEN (OTHER USER)
/// ===============================
class ProfileDetailScreen extends StatefulWidget {
  final int profileId;

  const ProfileDetailScreen({super.key, required this.profileId});

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
          _errorMessage = 'Auth expired. पुन्हा login करा.';
          _isLoading = false;
        });
        return;
      }

      if (statusCode == 404) {
        setState(() {
          _errorMessage = 'प्रोफाइल सापडली नाही.';
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

  int? _calculateAge(String? dateOfBirth) {
    if (dateOfBirth == null || dateOfBirth.isEmpty) return null;

    try {
      final dob = DateTime.parse(dateOfBirth);
      final now = DateTime.now();
      int age = now.year - dob.year;
      if (now.month < dob.month ||
          (now.month == dob.month && now.day < dob.day)) {
        age--;
      }
      return age;
    } catch (_) {
      return null;
    }
  }

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
        _showSnackBar('Interest पाठवला.', Colors.green);
      } else if (statusCode == 409) {
        setState(() {
          _interestSent = true;
          _isSendingInterest = false;
        });
        _showSnackBar('Interest आधीच पाठवला आहे.', Colors.orange);
      } else if (statusCode == 401) {
        setState(() {
          _isSendingInterest = false;
        });
        _showSnackBar('Auth expired. पुन्हा login करा.', Colors.red);
      } else {
        setState(() {
          _isSendingInterest = false;
        });
        final errorMessage =
            response['message'] ?? 'Interest send करता आला नाही.';
        _showSnackBar(errorMessage.toString(), Colors.red);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSendingInterest = false;
      });
      _showSnackBar('एक अनपेक्षित एरर आली: ${e.toString()}', Colors.red);
    }
  }

  bool _shouldShowSendInterestButton() {
    if (ApiClient.authToken == null || _profile == null) return false;

    final currentUserProfileId = ApiClient.currentUserProfile?['id'];
    final viewingProfileId = _profile!['id'];
    return currentUserProfileId == null || currentUserProfileId != viewingProfileId;
  }

  bool _isInterestAlreadySent() {
    return ApiClient.sentInterestProfileIds.contains(widget.profileId) ||
        _interestSent;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F5),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomActionBar(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
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

    final profile = _profile!;
    final photoUrl = ApiClient.resolveProfilePhotoUrl(profile);
    final education = ApiClient.profileEducationLabel(profile);
    final location = ApiClient.profileLocationLabel(
      profile,
      allowIdFallback: false,
    );
    final age = _calculateAge(profile['date_of_birth']?.toString());

    return ListView(
      padding: EdgeInsets.zero,
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _buildHeroPhoto(
          photoUrl: photoUrl,
          profile: profile,
          age: age,
          location: location,
        ),
        Transform.translate(
          offset: const Offset(0, -18),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFFFAF7F5),
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            padding: EdgeInsets.fromLTRB(
              16,
              24,
              16,
              _shouldShowSendInterestButton() ? 108 : 34,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('प्रोफाइल माहिती'),
                const SizedBox(height: 10),
                _buildProfileDetail(AppStrings.name, profile['full_name']),
                _buildProfileDetail(AppStrings.age, _ageText(age)),
                _buildProfileDetail(
                  AppStrings.dateOfBirth,
                  profile['date_of_birth'],
                ),
                _buildProfileDetail('समुदाय', _communityText(profile)),
                _buildProfileDetail(AppStrings.education, education),
                _buildProfileDetail(AppStrings.location, location),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroPhoto({
    required String? photoUrl,
    required Map<String, dynamic> profile,
    required int? age,
    required String? location,
  }) {
    final heroHeight = (MediaQuery.of(context).size.height * 0.68)
        .clamp(460.0, 680.0)
        .toDouble();
    final name = _nameText(profile);
    final heroName = age != null ? '$name, ${AppStrings.years(age)}' : name;
    final factLine = _heroFactLine(profile, location);
    final photoCount = _photoCount(profile, photoUrl);

    return SizedBox(
      width: double.infinity,
      height: heroHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildHeroImage(photoUrl),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.18),
                  Colors.black.withValues(alpha: 0.06),
                  Colors.black.withValues(alpha: 0.82),
                ],
                stops: const [0, 0.48, 1],
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  children: [
                    _buildRoundIconButton(
                      icon: Icons.arrow_back,
                      tooltip: 'Back',
                      onTap: () => Navigator.maybePop(context),
                    ),
                    const Spacer(),
                    if (_isPremium(profile)) ...[
                      _buildStatusPill(
                        icon: Icons.workspace_premium,
                        label: 'Premium',
                        color: const Color(0xFFFFB84D),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (photoCount > 0) ...[
                      _buildStatusPill(
                        icon: Icons.photo_library_outlined,
                        label: photoCount.toString(),
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                    ],
                    _buildMoreMenu(),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 28,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        heroName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          height: 1.08,
                        ),
                      ),
                    ),
                    if (_isVerified(profile)) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.verified,
                        color: Color(0xFF4DA3FF),
                        size: 24,
                      ),
                    ],
                  ],
                ),
                if (factLine.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    factLine,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (_isOnline(profile))
                      _buildHeroChip(
                        icon: Icons.circle,
                        label: 'Online',
                        iconColor: Colors.greenAccent,
                      ),
                    if (ApiClient.currentUserProfile != null)
                      _buildHeroChip(
                        icon: Icons.compare_arrows,
                        label: _comparisonLabel(profile),
                        onTap: _showComparisonSheet,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroImage(String? photoUrl) {
    if (photoUrl == null) {
      return _buildHeroFallback();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Image.network(
            photoUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildHeroFallback();
            },
          ),
        ),
        Image.network(
          photoUrl,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          errorBuilder: (context, error, stackTrace) {
            return _buildHeroFallback();
          },
        ),
      ],
    );
  }

  Widget _buildHeroFallback() {
    return Container(
      color: Colors.grey.shade300,
      alignment: Alignment.center,
      child: Icon(Icons.person, size: 132, color: Colors.grey.shade600),
    );
  }

  Widget _buildRoundIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon, color: Colors.white),
        onPressed: onTap,
      ),
    );
  }

  Widget _buildMoreMenu() {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      child: PopupMenuButton<String>(
        tooltip: 'Profile actions',
        icon: const Icon(Icons.more_vert, color: Colors.white),
        onSelected: _handleMenuAction,
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: 'share',
            child: ListTile(
              dense: true,
              leading: Icon(Icons.ios_share),
              title: Text('Share profile'),
            ),
          ),
          PopupMenuItem(
            value: 'shortlist',
            child: ListTile(
              dense: true,
              leading: Icon(Icons.bookmark_border),
              title: Text('Shortlist'),
            ),
          ),
          PopupMenuItem(
            value: 'hide',
            child: ListTile(
              dense: true,
              leading: Icon(Icons.visibility_off_outlined),
              title: Text('Hide'),
            ),
          ),
          PopupMenuItem(
            value: 'block',
            child: ListTile(
              dense: true,
              leading: Icon(Icons.block),
              title: Text('Block'),
            ),
          ),
          PopupMenuDivider(),
          PopupMenuItem(
            value: 'report',
            child: ListTile(
              dense: true,
              leading: Icon(Icons.flag_outlined),
              title: Text('Report'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroChip({
    required IconData icon,
    required String label,
    Color? iconColor,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.black.withValues(alpha: 0.42),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: iconColor ?? Colors.white),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
    );
  }

  Widget _buildProfileDetail(String label, dynamic value) {
    final displayValue = ApiClient.safeDisplayLabel(
      value,
      allowIdFallback: false,
    );
    if (displayValue == null || displayValue.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              displayValue,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildBottomActionBar() {
    if (!_shouldShowSendInterestButton()) return null;

    final alreadySent = _isInterestAlreadySent();

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'हा प्रोफाइल आवडला?',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: (alreadySent || _isSendingInterest)
                    ? null
                    : _sendInterest,
                icon: _isSendingInterest
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        alreadySent ? Icons.check : Icons.favorite,
                        size: 18,
                      ),
                label: Text(
                  alreadySent ? AppStrings.interestSent : AppStrings.sendInterest,
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'share':
        _copyProfileShareText();
        break;
      case 'shortlist':
      case 'hide':
      case 'block':
        _showSnackBar(
          'ही सुविधा backend API उपलब्ध झाल्यावर जोडता येईल.',
          Colors.orange,
        );
        break;
      case 'report':
        _showReportDialog();
        break;
    }
  }

  Future<void> _copyProfileShareText() async {
    final profile = _profile;
    if (profile == null) return;

    final age = _calculateAge(profile['date_of_birth']?.toString());
    final location = ApiClient.profileLocationLabel(
      profile,
      allowIdFallback: false,
    );
    final parts = <String>[
      _nameText(profile),
      if (age != null) '$age वर्षे',
      if (_communityText(profile) != null) _communityText(profile)!,
      if (location != null) location,
      'Profile ID: ${widget.profileId}',
    ];

    await Clipboard.setData(ClipboardData(text: parts.join('\n')));
    if (!mounted) return;
    _showSnackBar('Profile details copy झाले.', Colors.green);
  }

  Future<void> _showReportDialog() async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Report profile'),
          content: TextField(
            controller: reasonController,
            autofocus: true,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'कृपया report चे कारण लिहा',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, reasonController.text.trim());
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
    reasonController.dispose();

    if (reason == null) return;
    if (!mounted) return;
    if (reason.length < 10) {
      _showSnackBar('Report reason किमान 10 अक्षरांचे असावे.', Colors.orange);
      return;
    }

    try {
      final response = await ApiClient.reportProfile(
        profileId: widget.profileId,
        reason: reason,
      );
      if (!mounted) return;

      if (response['success'] == true) {
        _showSnackBar('Report submit झाला.', Colors.green);
      } else {
        _showSnackBar(
          response['message']?.toString() ?? 'Report submit करता आला नाही.',
          Colors.red,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Report submit करता आला नाही: ${e.toString()}', Colors.red);
    }
  }

  void _showComparisonSheet() {
    final profile = _profile;
    final ownProfile = ApiClient.currentUserProfile;
    if (profile == null || ownProfile == null) {
      _showSnackBar('Comparison साठी तुमचे profile data उपलब्ध नाही.', Colors.orange);
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _comparisonLabel(profile),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                _buildCompareRow(
                  'वय',
                  _ageText(_calculateAge(ownProfile['date_of_birth']?.toString())),
                  _ageText(_calculateAge(profile['date_of_birth']?.toString())),
                ),
                _buildCompareRow(
                  'समुदाय',
                  _communityText(ownProfile),
                  _communityText(profile),
                ),
                _buildCompareRow(
                  'शिक्षण',
                  ApiClient.profileEducationLabel(ownProfile),
                  ApiClient.profileEducationLabel(profile),
                ),
                _buildCompareRow(
                  'ठिकाण',
                  ApiClient.profileLocationLabel(
                    ownProfile,
                    allowIdFallback: false,
                  ),
                  ApiClient.profileLocationLabel(
                    profile,
                    allowIdFallback: false,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompareRow(String label, String? left, String? right) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: Text(left ?? AppStrings.noInformation)),
          const SizedBox(width: 12),
          Expanded(child: Text(right ?? AppStrings.noInformation)),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  String _nameText(Map<String, dynamic> profile) {
    return _firstText(profile, const ['full_name', 'name']) ??
        AppStrings.noInformation;
  }

  String? _ageText(int? age) {
    return age != null ? AppStrings.years(age) : null;
  }

  String _heroFactLine(
    Map<String, dynamic> profile,
    String? location,
  ) {
    final facts = <String>[
      if (_communityText(profile) != null) _communityText(profile)!,
      if (location != null && location.trim().isNotEmpty) location,
    ];

    return facts.join(' • ');
  }

  String? _communityText(Map<String, dynamic> profile) {
    return ApiClient.profileCommunityLabel(profile);
  }

  String? _firstText(Map<String, dynamic>? data, List<String> keys) {
    if (data == null) return null;

    for (final key in keys) {
      final value = ApiClient.safeDisplayLabel(data[key]);
      if (value != null) return value;
    }

    return null;
  }

  bool _truthy(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;

    final normalized = value?.toString().trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return false;
    return ['1', 'true', 'yes', 'active', 'online', 'verified', 'approved']
        .contains(normalized);
  }

  bool _isPremium(Map<String, dynamic> profile) {
    return _truthy(profile['is_premium']) ||
        _truthy(profile['premium']) ||
        _truthy(profile['is_paid_member']) ||
        _truthy(profile['subscription_active']);
  }

  bool _isVerified(Map<String, dynamic> profile) {
    return _truthy(profile['is_verified']) ||
        _truthy(profile['verified']) ||
        _truthy(profile['profile_verified']) ||
        _truthy(profile['kyc_verified']) ||
        _truthy(profile['verification_status']);
  }

  bool _isOnline(Map<String, dynamic> profile) {
    return _truthy(profile['is_online']) ||
        _truthy(profile['online']) ||
        _truthy(profile['online_status']);
  }

  String _comparisonLabel(Map<String, dynamic> profile) {
    final gender = ApiClient.safeDisplayLabel(profile['gender'])
        ?.trim()
        .toLowerCase();
    if (gender == 'female' || gender == 'f' || gender == 'woman') {
      return 'You & Her';
    }
    if (gender == 'male' || gender == 'm' || gender == 'man') {
      return 'You & Him';
    }

    return 'You & Profile';
  }

  int _photoCount(Map<String, dynamic> profile, String? photoUrl) {
    for (final key in ['photos', 'profile_photos']) {
      final value = profile[key];
      if (value is List && value.isNotEmpty) return value.length;
      if (value is Map) {
        final nested = value['data'] ?? value['items'] ?? value['results'];
        if (nested is List && nested.isNotEmpty) return nested.length;
      }
    }

    return photoUrl != null ? 1 : 0;
  }
}
