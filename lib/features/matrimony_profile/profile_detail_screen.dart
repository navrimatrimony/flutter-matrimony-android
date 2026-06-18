import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_client.dart';
import '../../core/app_strings.dart';
import 'widgets/profile_display_section.dart';

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
  Map<String, dynamic>? _display;
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

      final profile = _safeMap(response['profile']);
      if (response['success'] == true && profile != null) {
        setState(() {
          _profile = profile;
          _display = _safeMap(response['display']);
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

  bool _canSendInterestNow() {
    final displayCanSend = _displayBool(_displayActions()?['can_send_interest']);
    if (displayCanSend != null) {
      return displayCanSend && !_isInterestAlreadySent();
    }

    return !_isInterestAlreadySent();
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
    final hero = _displayHero();
    final about = _displayAbout();
    final displaySections = _displaySections();
    final photoUrl = _displayString(hero?['primary_photo_url']) ??
        ApiClient.resolveProfilePhotoUrl(profile);
    final location = _displayString(hero?['location_label']) ??
        ApiClient.profileLocationLabel(
      profile,
      allowIdFallback: false,
    );
    final age = _displayInt(hero?['age']) ??
        _calculateAge(profile['date_of_birth']?.toString());
    final aboutBody = _displayString(about?['body']);
    final aboutTitle = _displayString(about?['title']) ??
        'About ${_displayString(hero?['name']) ?? _nameText(profile)}';

    return ListView(
      padding: EdgeInsets.zero,
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _buildHeroPhoto(
          photoUrl: photoUrl,
          profile: profile,
          hero: hero,
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
              _bottomContentPadding(),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (aboutBody != null) ...[
                  _buildAboutCard(aboutTitle, aboutBody),
                  const SizedBox(height: 4),
                ],
                if (displaySections.isNotEmpty)
                  ...displaySections.map(
                    (section) => ProfileDisplaySection(section: section),
                  )
                else
                  ..._buildFallbackProfileDetails(profile, age, location),
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
    required Map<String, dynamic>? hero,
    required int? age,
    required String? location,
  }) {
    final screenSize = MediaQuery.of(context).size;
    final hasPhoto = photoUrl != null;
    final heroHeight = (screenSize.height * (hasPhoto ? 0.68 : 0.48))
        .clamp(hasPhoto ? 460.0 : 340.0, hasPhoto ? 680.0 : 460.0)
        .toDouble();
    final titleFontSize = screenSize.width < 360 ? 26.0 : 29.0;
    final name = _displayString(hero?['name']) ?? _nameText(profile);
    final heroName = age != null ? '$name, $age' : name;
    final heightLabel = _displayString(hero?['height_label']) ??
        ApiClient.profileHeightLabel(profile);
    final communityLabel =
        _displayString(hero?['community_label']) ?? _communityText(profile);
    final occupationLabel = _displayString(hero?['occupation_label']) ??
        ApiClient.profileOccupationLabel(profile);
    final line1 = _joinNonEmpty([heightLabel, communityLabel]);
    final photoCount =
        _displayInt(hero?['photo_count']) ?? _photoCount(profile, photoUrl);
    final isPremium = _displaySafeBool(hero?['premium']) ??
        (hero == null ? _isPremium(profile) : false);
    final isVerified = _displayBool(hero?['verified']) ?? _isVerified(profile);
    final heroChips = _displayChips(profile);

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
                    if (isPremium) ...[
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
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.w800,
                          height: 1.12,
                        ),
                      ),
                    ),
                    if (isVerified) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.verified,
                        color: Color(0xFF4DA3FF),
                        size: 24,
                      ),
                    ],
                  ],
                ),
                if (line1 != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    line1,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ],
                if (occupationLabel != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    occupationLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                ],
                if (location != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: heroChips,
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
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFB53B61),
            Color(0xFF7D1538),
            Color(0xFF2E2220),
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            right: -44,
            top: 78,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: -36,
            bottom: 84,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Center(
            child: Container(
              width: 118,
              height: 118,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.30),
                  width: 1.4,
                ),
              ),
              child: Icon(
                Icons.person,
                size: 70,
                color: Colors.white.withValues(alpha: 0.86),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 122,
            child: Text(
              'फोटो अजून जोडलेला नाही',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
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

  Widget _buildAboutCard(String title, String body) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEDE2DE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF2E2220),
                ),
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: TextStyle(
              color: Colors.grey.shade800,
              fontSize: 15,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFallbackProfileDetails(
    Map<String, dynamic> profile,
    int? age,
    String? location,
  ) {
    final education = ApiClient.profileEducationLabel(profile);

    return [
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
    ];
  }

  double _bottomContentPadding() {
    return _shouldShowSendInterestButton() ? 132 : 38;
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
    final canSend = _canSendInterestNow();
    final disabledByBackend =
        _displayBool(_displayActions()?['can_send_interest']) == false;

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
                onPressed: (!canSend || _isSendingInterest) ? null : _sendInterest,
                icon: _isSendingInterest
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        alreadySent || disabledByBackend
                            ? Icons.check
                            : Icons.favorite,
                        size: 18,
                      ),
                label: Text(
                  alreadySent
                      ? AppStrings.interestSent
                      : disabledByBackend
                          ? 'Interest उपलब्ध नाही'
                          : AppStrings.sendInterest,
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

    final hero = _displayHero();
    final age = _calculateAge(profile['date_of_birth']?.toString());
    final location = _displayString(hero?['location_label']) ??
        ApiClient.profileLocationLabel(
      profile,
      allowIdFallback: false,
    );
    final ageLabel = _displayString(hero?['age_label']);
    final communityLabel =
        _displayString(hero?['community_label']) ?? _communityText(profile);
    final parts = <String>[
      _displayString(hero?['name']) ?? _nameText(profile),
      if (ageLabel != null)
        ageLabel
      else if (age != null)
        '$age वर्षे',
      if (communityLabel != null) communityLabel,
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

  Map<String, dynamic>? _displayHero() {
    return _safeMap(_display?['hero']);
  }

  Map<String, dynamic>? _displayAbout() {
    return _safeMap(_display?['about']);
  }

  Map<String, dynamic>? _displayActions() {
    return _safeMap(_display?['actions']);
  }

  List<ProfileDisplaySectionData> _displaySections() {
    final sections = _safeMapList(_display?['sections']);
    return sections
        .map(ProfileDisplaySectionData.fromMap)
        .whereType<ProfileDisplaySectionData>()
        .toList();
  }

  List<Widget> _displayChips(Map<String, dynamic> profile) {
    final widgets = <Widget>[];
    final rows = _safeMapList(_display?['chips']);

    for (final row in rows) {
      final label = _displayString(row['label']);
      if (label == null) continue;

      final normalized = label.trim().toLowerCase();
      final iconKey = _displayString(row['icon']);
      if (normalized == 'premium' ||
          normalized == 'verified' ||
          normalized.contains('photo') ||
          iconKey == 'photo') {
        continue;
      }

      widgets.add(
        _buildHeroChip(
          icon: _chipIcon(iconKey),
          label: label,
          iconColor: _chipColor(iconKey, _displayString(row['tone'])),
          onTap: normalized.startsWith('you &') ? _showComparisonSheet : null,
        ),
      );

      if (widgets.length >= 4) return widgets;
    }

    if (widgets.isNotEmpty) return widgets;

    if (_isOnline(profile)) {
      widgets.add(
        _buildHeroChip(
          icon: Icons.circle,
          label: 'Online',
          iconColor: Colors.greenAccent,
        ),
      );
    }

    if (ApiClient.currentUserProfile != null) {
      widgets.add(
        _buildHeroChip(
          icon: Icons.compare_arrows,
          label: _comparisonLabel(profile),
          onTap: _showComparisonSheet,
        ),
      );
    }

    return widgets;
  }

  Map<String, dynamic>? _safeMap(dynamic value) {
    if (value is! Map) return null;
    try {
      return Map<String, dynamic>.from(value);
    } catch (_) {
      return null;
    }
  }

  List<Map<String, dynamic>> _safeMapList(dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];

    final rows = <Map<String, dynamic>>[];
    for (final item in value) {
      final row = _safeMap(item);
      if (row != null) rows.add(row);
    }
    return rows;
  }

  String? _displayString(dynamic value) {
    if (value == null) return null;
    if (value is Map || value is List) return null;
    if (value is bool) return value ? 'Yes' : 'No';

    final text = value.toString().trim();
    if (text.isEmpty) return null;
    if (text.startsWith('{') || text.startsWith('[')) return null;
    if (text.contains('=>')) return null;
    if (text.toLowerCase().startsWith('location id:')) return null;

    return text;
  }

  bool? _displayBool(dynamic value) {
    return value is bool ? value : null;
  }

  bool? _displaySafeBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) {
      if (value == 1) return true;
      if (value == 0) return false;
      return null;
    }

    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }
      if (normalized == 'false' || normalized == '0' || normalized == 'no') {
        return false;
      }
    }

    return null;
  }

  int? _displayInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  String? _joinNonEmpty(List<String?> values) {
    final parts = values
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    return parts.isEmpty ? null : parts.join(' • ');
  }

  IconData _chipIcon(String? icon) {
    switch (icon?.trim().toLowerCase()) {
      case 'compare':
        return Icons.compare_arrows;
      case 'astro':
        return Icons.auto_awesome;
      case 'verified':
        return Icons.verified;
      case 'premium':
        return Icons.workspace_premium;
      case 'photo':
        return Icons.photo_library_outlined;
      default:
        return Icons.circle;
    }
  }

  Color? _chipColor(String? icon, String? tone) {
    final key = icon?.trim().toLowerCase();
    final toneKey = tone?.trim().toLowerCase();
    if (key == 'astro' || toneKey == 'warm') {
      return const Color(0xFFFFC857);
    }
    if (key == 'compare') {
      return Colors.white;
    }
    if (key == 'verified' || toneKey == 'trust') {
      return const Color(0xFF4DA3FF);
    }
    return null;
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
