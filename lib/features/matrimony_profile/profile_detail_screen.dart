import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

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
  bool _isShortlisted = false;
  bool _isHidden = false;
  bool _isBlocked = false;
  bool? _canShortlist;
  bool? _canHide;
  bool? _canBlock;
  bool _isProfileActionInFlight = false;

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
        final display = _safeMap(response['display']);
        final actions = _safeMap(display?['actions']);
        setState(() {
          _profile = profile;
          _display = display;
          _isShortlisted =
              _displaySafeBool(actions?['is_shortlisted']) ?? false;
          _isHidden = _displaySafeBool(actions?['is_hidden']) ?? false;
          _isBlocked = _displaySafeBool(actions?['is_blocked']) ?? false;
          _canShortlist = _displaySafeBool(actions?['can_shortlist']);
          _canHide = _displaySafeBool(actions?['can_hide']);
          _canBlock = _displaySafeBool(actions?['can_block']);
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
        enabled: !_isProfileActionInFlight,
        icon: const Icon(Icons.more_vert, color: Colors.white),
        onSelected: _handleMenuAction,
        itemBuilder: (context) {
          final items = <PopupMenuEntry<String>>[
            const PopupMenuItem(
              value: 'share',
              child: ListTile(
                dense: true,
                leading: Icon(Icons.ios_share),
                title: Text('Share profile'),
              ),
            ),
          ];

          if (_canShowShortlistAction()) {
            items.add(
              PopupMenuItem(
                value: _isShortlisted ? 'unshortlist' : 'shortlist',
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    _isShortlisted ? Icons.bookmark : Icons.bookmark_border,
                  ),
                  title: Text(
                    _isShortlisted
                        ? 'Remove from Shortlist'
                        : 'Add to Shortlist',
                  ),
                ),
              ),
            );
          }

          if (_canShowHideAction()) {
            items.add(
              const PopupMenuItem(
                value: 'hide',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.visibility_off_outlined),
                  title: Text('Hide this Profile'),
                ),
              ),
            );
          }

          if (_canShowBlockAction()) {
            items.add(
              const PopupMenuItem(
                value: 'block',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.block),
                  title: Text('Block this Profile'),
                ),
              ),
            );
          }

          items.addAll(
            const [
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'report',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.flag_outlined),
                  title: Text('Report this Profile'),
                ),
              ),
            ],
          );

          return items;
        },
      ),
    );
  }

  bool _canShowShortlistAction() {
    if (_isViewingOwnProfile()) return false;
    if (_isBlocked) return false;
    if (_isShortlisted) return ApiClient.authToken != null;

    return _canShortlist ?? ApiClient.authToken != null;
  }

  bool _canShowHideAction() {
    if (_isViewingOwnProfile() || _isHidden || _isBlocked) return false;

    return _canHide ?? ApiClient.authToken != null;
  }

  bool _canShowBlockAction() {
    if (_isViewingOwnProfile() || _isBlocked) return false;

    return _canBlock ?? ApiClient.authToken != null;
  }

  bool _isViewingOwnProfile() {
    final profile = _profile;
    if (profile == null) return false;

    final currentUserProfileId = _displayInt(ApiClient.currentUserProfile?['id']);
    final viewingProfileId = _displayInt(profile['id']) ?? widget.profileId;
    return currentUserProfileId != null &&
        currentUserProfileId == viewingProfileId;
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

  Future<void> _handleMenuAction(String action) async {
    switch (action) {
      case 'share':
        await Future<void>.delayed(Duration.zero);
        if (!mounted) return;
        await _shareProfile();
        break;
      case 'shortlist':
      case 'unshortlist':
        _toggleShortlist();
        break;
      case 'block':
        _confirmAndBlockProfile();
        break;
      case 'hide':
        _confirmAndHideProfile();
        break;
      case 'report':
        await Future<void>.delayed(Duration.zero);
        if (!mounted) return;
        await _reportProfile();
        break;
    }
  }

  Future<void> _toggleShortlist() async {
    if (_isProfileActionInFlight || _profile == null) return;

    final shouldShortlist = !_isShortlisted;
    setState(() {
      _isProfileActionInFlight = true;
    });

    try {
      final response = shouldShortlist
          ? await ApiClient.shortlistProfile(widget.profileId)
          : await ApiClient.unshortlistProfile(widget.profileId);
      if (!mounted) return;

      if (_responseSuccess(response)) {
        _applyActionStateFromResponse(
          response,
          fallbackShortlisted: shouldShortlist,
        );
        _showSnackBar(
          _backendMessage(
            response,
            shouldShortlist
                ? 'Shortlist मध्ये जोडले.'
                : 'Shortlist मधून काढले.',
          ),
          Colors.green,
        );
        return;
      }

      setState(() {
        _isProfileActionInFlight = false;
      });
      _showSnackBar(
        _responseErrorMessage(
          response,
          shouldShortlist
              ? 'Shortlist करता आली नाही.'
              : 'Shortlist मधून काढता आली नाही.',
        ),
        Colors.red,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isProfileActionInFlight = false;
      });
      _showSnackBar(
        shouldShortlist
            ? 'Shortlist करता आली नाही.'
            : 'Shortlist मधून काढता आली नाही.',
        Colors.red,
      );
    }
  }

  Future<void> _confirmAndHideProfile() async {
    if (_isProfileActionInFlight || _profile == null) return;

    final confirmed = await _confirmProfileAction(
      title: 'Hide profile?',
      message: 'This profile will be hidden from your browse/search list.',
      confirmLabel: 'Hide',
    );
    if (!mounted || !confirmed) return;

    setState(() {
      _isProfileActionInFlight = true;
    });

    try {
      final response = await ApiClient.hideProfile(widget.profileId);
      if (!mounted) return;

      if (_responseSuccess(response)) {
        _applyActionStateFromResponse(response, fallbackHidden: true);
        _showSnackBar(
          _backendMessage(response, 'Profile hidden.'),
          Colors.green,
        );
        Navigator.pop(context, {
          'profileId': widget.profileId,
          'action': 'hidden',
        });
        return;
      }

      setState(() {
        _isProfileActionInFlight = false;
      });
      _showSnackBar(
        _responseErrorMessage(response, 'Profile hide करता आली नाही.'),
        Colors.red,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isProfileActionInFlight = false;
      });
      _showSnackBar('Profile hide करता आली नाही.', Colors.red);
    }
  }

  Future<void> _confirmAndBlockProfile() async {
    if (_isProfileActionInFlight || _profile == null) return;

    final confirmed = await _confirmProfileAction(
      title: 'Block profile?',
      message:
          'Blocking will remove interests/shortlists between both profiles and hide this profile from you.',
      confirmLabel: 'Block',
      isDestructive: true,
    );
    if (!mounted || !confirmed) return;

    setState(() {
      _isProfileActionInFlight = true;
    });

    try {
      final response = await ApiClient.blockProfile(widget.profileId);
      if (!mounted) return;

      if (_responseSuccess(response)) {
        _applyActionStateFromResponse(
          response,
          fallbackShortlisted: false,
          fallbackBlocked: true,
        );
        _showSnackBar(
          _backendMessage(response, 'Profile blocked.'),
          Colors.green,
        );
        Navigator.pop(context, {
          'profileId': widget.profileId,
          'action': 'blocked',
        });
        return;
      }

      setState(() {
        _isProfileActionInFlight = false;
      });
      _showSnackBar(
        _responseErrorMessage(response, 'Profile block करता आली नाही.'),
        Colors.red,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isProfileActionInFlight = false;
      });
      _showSnackBar('Profile block करता आली नाही.', Colors.red);
    }
  }

  Future<bool> _confirmProfileAction({
    required String title,
    required String message,
    required String confirmLabel,
    bool isDestructive = false,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: isDestructive
                  ? ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                    )
                  : null,
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );

    return confirmed == true;
  }

  void _applyActionStateFromResponse(
    Map<String, dynamic> response, {
    bool? fallbackShortlisted,
    bool? fallbackHidden,
    bool? fallbackBlocked,
  }) {
    final state = _safeMap(response['state']);
    setState(() {
      _isProfileActionInFlight = false;
      _isShortlisted = _displaySafeBool(state?['shortlisted']) ??
          fallbackShortlisted ??
          _isShortlisted;
      _isHidden =
          _displaySafeBool(state?['hidden']) ?? fallbackHidden ?? _isHidden;
      _isBlocked =
          _displaySafeBool(state?['blocked']) ?? fallbackBlocked ?? _isBlocked;

      if (state?.containsKey('shortlisted') == true ||
          fallbackShortlisted != null) {
        _canShortlist = !_isShortlisted && !_isBlocked;
      }
      if (state?.containsKey('hidden') == true || fallbackHidden != null) {
        _canHide = !_isHidden && !_isBlocked;
      }
      if (state?.containsKey('blocked') == true || fallbackBlocked != null) {
        _canBlock = !_isBlocked;
        if (_isBlocked) {
          _canShortlist = false;
          _canHide = false;
        }
      }
    });
  }

  bool _responseSuccess(Map<String, dynamic> response) {
    return _responseStatusCode(response) == 200 && response['success'] == true;
  }

  int? _responseStatusCode(Map<String, dynamic> response) {
    return _displayInt(response['statusCode']);
  }

  String _backendMessage(Map<String, dynamic> response, String fallback) {
    return _displayString(response['message']) ?? fallback;
  }

  String _responseErrorMessage(
    Map<String, dynamic> response,
    String fallback,
  ) {
    final statusCode = _responseStatusCode(response);
    if (statusCode == 401) return 'Auth expired. पुन्हा login करा.';

    return _backendMessage(response, fallback);
  }

  Future<void> _copyProfileShareText() async {
    final profile = _profile;
    if (profile == null) return;

    await Clipboard.setData(ClipboardData(text: _fallbackProfileShareText()));
    if (!mounted) return;
    _showSnackBar('Profile details copy झाले.', Colors.green);
  }

  Future<void> _shareProfile() async {
    final payload = _publicSharePayload();
    if (payload == null) {
      await _copyProfileShareText();
      return;
    }

    try {
      await Share.share(payload['text']!, subject: payload['title']);
      if (!mounted) return;
      _showSnackBar('Profile link ready to share.', Colors.green);
    } catch (_) {
      try {
        await Clipboard.setData(ClipboardData(text: payload['text']!));
        if (!mounted) return;
        _showSnackBar('Profile link copied.', Colors.green);
      } catch (_) {
        if (!mounted) return;
        _showSnackBar('Profile share करता आली नाही.', Colors.red);
      }
    }
  }

  Map<String, String>? _publicSharePayload() {
    final share = _displayShare();
    final actions = _displayActions();
    final rawUrl =
        _displayString(share?['url']) ?? _displayString(actions?['share_url']);
    final url = _cleanShareUrl(rawUrl);
    if (url == null) return null;

    final title = _displayString(share?['title']) ?? _shareTitle();
    final backendText =
        _displayString(share?['text']) ?? _displayString(actions?['share_text']);
    final text = _shareTextWithUrl(
      backendText: backendText,
      title: title,
      url: url,
    );

    return {'url': url, 'title': title, 'text': text};
  }

  String? _cleanShareUrl(String? rawUrl) {
    final value = rawUrl?.trim();
    if (value == null || value.isEmpty) return null;

    final uri = Uri.tryParse(value);
    if (uri == null) return null;
    final scheme = uri.scheme.toLowerCase();
    if ((scheme != 'https' && scheme != 'http') || uri.host.isEmpty) {
      return null;
    }

    return value;
  }

  String _shareTitle() {
    final profile = _profile;
    final hero = _displayHero();
    final name = _displayString(hero?['name']) ??
        (profile != null ? _nameText(profile) : 'Profile');
    final age = _displayInt(hero?['age']) ??
        _calculateAge(profile?['date_of_birth']?.toString());

    return age != null
        ? '$name, $age - Navri Mile Navryala'
        : '$name - Navri Mile Navryala';
  }

  String _shareTextWithUrl({
    required String? backendText,
    required String title,
    required String url,
  }) {
    final cleanedBackendText = backendText?.trim();
    if (cleanedBackendText != null && cleanedBackendText.isNotEmpty) {
      if (cleanedBackendText.contains(url)) {
        return cleanedBackendText;
      }

      return '$cleanedBackendText\n\nView profile:\n$url';
    }

    final profile = _profile;
    final hero = _displayHero();
    final communityLabel = _displayString(hero?['community_label']) ??
        (profile != null ? _communityText(profile) : null);
    final location = _displayString(hero?['location_label']) ??
        (profile != null
            ? ApiClient.profileLocationLabel(
                profile,
                allowIdFallback: false,
              )
            : null);
    final parts = <String>[
      title,
      if (communityLabel != null || location != null) '',
      if (communityLabel != null) communityLabel,
      if (location != null) location,
      '',
      'View profile:',
      url,
    ];

    return parts.join('\n').trim();
  }

  String _fallbackProfileShareText() {
    final profile = _profile;
    if (profile == null) return 'Profile ID: ${widget.profileId}';

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

    return parts.join('\n');
  }

  Future<String?> _askReportReason() {
    return showDialog<String>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => const _ReportReasonDialog(),
    );
  }

  Future<void> _reportProfile() async {
    if (_isProfileActionInFlight || _profile == null) return;

    final reason = await _askReportReason();
    if (!mounted || reason == null) return;

    final trimmedReason = reason.trim();
    if (trimmedReason.length < 10) {
      _showSnackBar('Report reason किमान 10 अक्षरांचे असावे.', Colors.orange);
      return;
    }

    setState(() {
      _isProfileActionInFlight = true;
    });

    try {
      final response = await ApiClient.reportProfile(
        profileId: widget.profileId,
        reason: trimmedReason,
      );
      if (!mounted) return;

      setState(() {
        _isProfileActionInFlight = false;
      });

      if (_responseSuccess(response)) {
        _showSnackBar(
          _backendMessage(response, 'Report submitted.'),
          Colors.green,
        );
        return;
      }

      _showSnackBar(
        _responseErrorMessage(response, 'Report submit करता आला नाही.'),
        Colors.red,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isProfileActionInFlight = false;
      });
      _showSnackBar('Report submit करता आला नाही.', Colors.red);
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

  Map<String, dynamic>? _displayShare() {
    return _safeMap(_display?['share']);
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
    if (!mounted) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.showSnackBar(
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

class _ReportReasonDialog extends StatefulWidget {
  const _ReportReasonDialog();

  @override
  State<_ReportReasonDialog> createState() => _ReportReasonDialogState();
}

class _ReportReasonDialogState extends State<_ReportReasonDialog> {
  final TextEditingController _reasonController = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _reasonController.text.trim();
    if (reason.length < 10) {
      setState(() {
        _errorText = 'Report reason किमान 10 अक्षरांचे असावे.';
      });
      return;
    }

    Navigator.of(context, rootNavigator: true).pop(reason);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Report profile'),
      content: TextField(
        controller: _reasonController,
        autofocus: true,
        minLines: 3,
        maxLines: 5,
        onChanged: (_) {
          if (_errorText == null) return;
          setState(() {
            _errorText = null;
          });
        },
        decoration: InputDecoration(
          hintText: 'कृपया report चे कारण लिहा',
          border: const OutlineInputBorder(),
          errorText: _errorText,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context, rootNavigator: true).pop(null);
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Submit'),
        ),
      ],
    );
  }
}
