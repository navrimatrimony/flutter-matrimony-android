import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_language.dart';
import '../../core/app_storage.dart';
import '../../core/app_strings.dart';
import '../../core/profile_photo_view.dart';
import '../../main.dart';
import '../interests/received_interests_screen.dart';
import '../interests/sent_interests_screen.dart';
import '../matrimony_profile/edit_full_profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  static const Color _brand = Color(0xFFDC2626);
  static const Color _brandDark = Color(0xFF8F1024);
  static const Color _gold = Color(0xFFC79A3B);
  static const Color _ink = Color(0xFF2D2323);
  static const Color _muted = Color(0xFF7C6A64);
  static const Color _cardBorder = Color(0xFFE8DDD7);
  static const Color _success = Color(0xFF12805C);
  static const Color _warning = Color(0xFFC78318);
  static const Color _danger = Color(0xFFDC2626);

  bool _profileLoading = true;
  bool _planLoading = true;
  bool _attentionLoading = true;
  bool _interestsLoading = true;
  bool _listsLoading = true;
  bool _refreshing = false;
  bool _profileMissing = false;
  bool _showCompletedReadiness = false;
  int _loadSerial = 0;

  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _currentPlanResponse;

  int _sentTotal = 0;
  int _sentPending = 0;
  int _receivedTotal = 0;
  int _receivedPending = 0;

  int _chatUnreadCount = 0;
  int _notificationUnreadCount = 0;
  int _contactPendingCount = 0;
  int _shortlistedCount = 0;
  int _blockedCount = 0;
  int _hiddenCount = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    super.didPopNext();
    _loadDashboard(silent: true);
  }

  Future<void> _loadDashboard({bool silent = false}) async {
    final serial = ++_loadSerial;

    if (!silent) {
      setState(() {
        _profileLoading = true;
        _planLoading = true;
        _attentionLoading = true;
        _interestsLoading = true;
        _listsLoading = true;
      });
    } else {
      setState(() {
        _refreshing = true;
      });
    }

    await Future.wait<void>([
      _loadProfile(serial, silent: silent),
      _loadPlan(serial, silent: silent),
      _loadAttention(serial, silent: silent),
      _loadInterests(serial, silent: silent),
      _loadProfileLists(serial, silent: silent),
    ]);

    if (!mounted || serial != _loadSerial) return;
    setState(() {
      _refreshing = false;
    });
  }

  Future<void> _loadProfile(int serial, {required bool silent}) async {
    if (!silent) {
      setState(() {
        _profileLoading = true;
      });
    }

    try {
      final response = await ApiClient.getMyProfile(forceRefresh: silent);
      if (!mounted || serial != _loadSerial) return;

      final statusCode = _intValue(response['statusCode']);
      if (statusCode == 404) {
        setState(() {
          _profileMissing = true;
          _profile = null;
          _profileLoading = false;
        });
        return;
      }

      final profile =
          _safeMap(response['profile']) ??
          _safeMap(_safeMap(response['data'])?['profile']) ??
          _safeMap(ApiClient.currentUserProfile);

      setState(() {
        _profileMissing = false;
        _profile = profile;
        _profileLoading = false;
      });
    } catch (_) {
      if (!mounted || serial != _loadSerial) return;
      setState(() {
        _profile = _profile ?? _safeMap(ApiClient.currentUserProfile);
        _profileLoading = false;
      });
    }
  }

  Future<void> _loadPlan(int serial, {required bool silent}) async {
    if (!silent) {
      setState(() {
        _planLoading = true;
      });
    }

    try {
      final response = await ApiClient.getCurrentPlan();
      if (!mounted || serial != _loadSerial) return;
      setState(() {
        _currentPlanResponse = response;
        _planLoading = false;
      });
    } catch (_) {
      if (!mounted || serial != _loadSerial) return;
      setState(() {
        _planLoading = false;
      });
    }
  }

  Future<void> _loadAttention(int serial, {required bool silent}) async {
    if (!silent) {
      setState(() {
        _attentionLoading = true;
      });
    }

    final results = await Future.wait<Map<String, dynamic>>([
      ApiClient.getChatUnreadCount().catchError((_) => <String, dynamic>{}),
      ApiClient.getNotificationUnreadCount().catchError(
        (_) => <String, dynamic>{},
      ),
      ApiClient.getContactInbox().catchError((_) => <String, dynamic>{}),
    ]);

    if (!mounted || serial != _loadSerial) return;

    final contactRows = _safeMapList(results[2]['received']);
    final pendingContacts = contactRows.where((row) {
      final status = _stringValue(row['status'])?.toLowerCase();
      return status == null || status == 'pending';
    }).length;

    setState(() {
      _chatUnreadCount = _countFrom(results[0], 'unread_count');
      _notificationUnreadCount = _countFrom(results[1], 'unread_count');
      _contactPendingCount = pendingContacts;
      _attentionLoading = false;
    });
  }

  Future<void> _loadInterests(int serial, {required bool silent}) async {
    if (!silent) {
      setState(() {
        _interestsLoading = true;
      });
    }

    try {
      final responses = await Future.wait<Map<String, dynamic>>([
        ApiClient.getSentInterests(),
        ApiClient.getReceivedInterests(),
      ]);
      if (!mounted || serial != _loadSerial) return;

      final sent = _interestStats(responses[0], 'sent');
      final received = _interestStats(responses[1], 'received');

      setState(() {
        _sentTotal = sent.total;
        _sentPending = sent.pending;
        _receivedTotal = received.total;
        _receivedPending = received.pending;
        _interestsLoading = false;
      });
    } catch (_) {
      if (!mounted || serial != _loadSerial) return;
      setState(() {
        _interestsLoading = false;
      });
    }
  }

  Future<void> _loadProfileLists(int serial, {required bool silent}) async {
    if (!silent) {
      setState(() {
        _listsLoading = true;
      });
    }

    final responses = await Future.wait<Map<String, dynamic>>([
      ApiClient.getShortlistedProfiles().catchError((_) => <String, dynamic>{}),
      ApiClient.getBlockedProfiles().catchError((_) => <String, dynamic>{}),
      ApiClient.getHiddenProfiles().catchError((_) => <String, dynamic>{}),
    ]);

    if (!mounted || serial != _loadSerial) return;
    setState(() {
      _shortlistedCount = _safeMapList(responses[0]['profiles']).length;
      _blockedCount = _safeMapList(responses[1]['profiles']).length;
      _hiddenCount = _safeMapList(responses[2]['profiles']).length;
      _listsLoading = false;
    });
  }

  Future<void> _changeLanguage(AppLanguage? language) async {
    if (language == null || language == currentAppLanguage) return;

    setAppLanguage(language);
    setState(() {});
    await AppStorage.instance.saveLanguage(language);
  }

  void _safePushNamed(String routeName) {
    try {
      Navigator.pushNamed(context, routeName);
    } catch (_) {
      _showSnackBar(AppStrings.featureNotAvailable);
    }
  }

  void _openSentInterests() {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SentInterestsScreen()),
      );
    } catch (_) {
      _showSnackBar(AppStrings.featureNotAvailable);
    }
  }

  void _openReceivedInterests() {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ReceivedInterestsScreen()),
      );
    } catch (_) {
      _showSnackBar(AppStrings.featureNotAvailable);
    }
  }

  Future<void> _openEditProfile({
    bool openLocationDetails = false,
    EditProfileTargetSection? targetSection,
  }) async {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EditFullProfileScreen(
            initialProfile: _effectiveProfile ?? ApiClient.currentUserProfile,
            openLocationDetails: openLocationDetails,
            targetSection: targetSection,
          ),
        ),
      );
    } catch (_) {
      _showSnackBar(AppStrings.featureNotAvailable);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _effectiveProfile;
    final photoUrl = ApiClient.resolveProfilePhotoUrl(profile);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.dashboard),
        automaticallyImplyLeading: true,
        actions: [
          IconButton(
            tooltip: AppStrings.refresh,
            onPressed: _refreshing ? null : () => _loadDashboard(silent: true),
            icon: _refreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      drawer: _buildDrawer(photoUrl),
      body: RefreshIndicator(
        onRefresh: () => _loadDashboard(silent: true),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPremiumHero(profile, photoUrl),
              const SizedBox(height: 12),
              _buildPlanStatusBand(),
              const SizedBox(height: 16),
              _buildNextBestActionCard(),
              const SizedBox(height: 18),
              _buildQuickActions(),
              const SizedBox(height: 20),
              _buildReadinessChecklist(),
              const SizedBox(height: 20),
              _buildActivitySection(),
              const SizedBox(height: 20),
              _buildAccountToolsGrid(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(String? photoUrl) {
    return Drawer(
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Container(
              height: 190,
              width: double.infinity,
              color: _brand,
              child: photoUrl != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        ImageFiltered(
                          imageFilter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Image.network(
                            photoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(color: _brand);
                            },
                          ),
                        ),
                        Center(
                          child: Image.network(
                            photoUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return _drawerLogoFallback();
                            },
                          ),
                        ),
                      ],
                    )
                  : _drawerLogoFallback(),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _drawerTile(
                  icon: Icons.home,
                  title: AppStrings.dashboard,
                  selected: true,
                  onTap: () => Navigator.pop(context),
                ),
                _drawerTile(
                  icon: Icons.search,
                  title: AppStrings.browseProfiles,
                  onTap: () {
                    Navigator.pop(context);
                    _safePushNamed('/matches');
                  },
                ),
                _drawerTile(
                  icon: Icons.person,
                  title: AppStrings.myProfile,
                  onTap: () {
                    Navigator.pop(context);
                    _safePushNamed('/view-profile');
                  },
                ),
                _drawerTile(
                  icon: Icons.article_outlined,
                  title: AppStrings.biodataExportMenu,
                  onTap: () {
                    Navigator.pop(context);
                    _safePushNamed('/biodata-export');
                  },
                ),
                _drawerTile(
                  icon: Icons.document_scanner_outlined,
                  title: AppStrings.biodataIntakeMenu,
                  onTap: () {
                    Navigator.pop(context);
                    _safePushNamed('/biodata-intake');
                  },
                ),
                _drawerTile(
                  icon: Icons.bookmarks_outlined,
                  title: AppStrings.profileListsMenu,
                  onTap: () {
                    Navigator.pop(context);
                    _safePushNamed('/profile-lists');
                  },
                ),
                _drawerTile(
                  icon: Icons.chat_bubble_outline,
                  title: AppStrings.chatMenu,
                  onTap: () {
                    Navigator.pop(context);
                    _safePushNamed('/chats');
                  },
                ),
                _drawerTile(
                  icon: Icons.workspace_premium,
                  title: AppStrings.plansUpgradeMenu,
                  onTap: () {
                    Navigator.pop(context);
                    _safePushNamed('/plans');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.translate),
                  title: Text(AppStrings.languageMenu),
                  subtitle: Text(AppStrings.languageSwitchSubtitle),
                  dense: false,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  trailing: DropdownButtonHideUnderline(
                    child: DropdownButton<AppLanguage>(
                      value: currentAppLanguage,
                      isDense: true,
                      items: [
                        DropdownMenuItem(
                          value: AppLanguage.marathi,
                          child: Text(AppStrings.marathi),
                        ),
                        DropdownMenuItem(
                          value: AppLanguage.english,
                          child: Text(AppStrings.english),
                        ),
                      ],
                      onChanged: _changeLanguage,
                    ),
                  ),
                ),
                _drawerTile(
                  icon: Icons.settings,
                  title: AppStrings.settingsTitle,
                  onTap: () {
                    Navigator.pop(context);
                    _safePushNamed('/settings');
                  },
                ),
                _drawerTile(
                  icon: Icons.edit,
                  title: AppStrings.editProfile,
                  onTap: () {
                    Navigator.pop(context);
                    _openEditProfile();
                  },
                ),
                _drawerTile(
                  icon: Icons.photo_camera,
                  title: AppStrings.photosVerification,
                  onTap: () {
                    Navigator.pop(context);
                    _safePushNamed('/photo-gallery');
                  },
                ),
                _drawerTile(
                  icon: Icons.send,
                  title: AppStrings.sentInterests,
                  onTap: () {
                    Navigator.pop(context);
                    _openSentInterests();
                  },
                ),
                _drawerTile(
                  icon: Icons.inbox,
                  title: AppStrings.receivedInterests,
                  onTap: () {
                    Navigator.pop(context);
                    _openReceivedInterests();
                  },
                ),
                const Divider(height: 1),
                _drawerTile(
                  icon: Icons.logout,
                  title: AppStrings.logout,
                  danger: true,
                  onTap: () async {
                    final navigator = Navigator.of(context);
                    Navigator.pop(context);
                    await signOutAndReturnToLogin(navigator);
                  },
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Image.asset(
                'assets/images/brand_logo.png',
                height: 36,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.favorite,
                    size: 36,
                    color: Colors.grey,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerLogoFallback() {
    return Image.asset(
      'assets/images/brand_logo.png',
      height: 190,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return const Center(
          child: Icon(Icons.favorite, size: 60, color: Colors.white),
        );
      },
    );
  }

  Widget _drawerTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool selected = false,
    bool danger = false,
  }) {
    final color = danger ? Colors.red : null;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(
          color: color,
          fontWeight: selected || danger ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      selected: selected,
      selectedTileColor: _brand.withValues(alpha: 0.1),
      dense: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: onTap,
    );
  }

  Widget _buildPremiumHero(Map<String, dynamic>? profile, String? photoUrl) {
    if (_profileLoading && profile == null) {
      return _buildHeroSkeleton();
    }

    final name = _profileName(profile);
    final summary = _profileSummary(profile);
    final hasPremium = _hasActiveSubscription;
    final hasPhoto = _hasPhoto(profile);
    final gradient = hasPremium
        ? const LinearGradient(
            colors: [Color(0xFF7A4B12), Color(0xFFC79A3B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [_brandDark, _brand],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: _brandDark.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeroAvatar(photoUrl, hasPhoto),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.dashboardGreeting(name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      summary ?? AppStrings.dashboardHeroFallback,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _heroPill(
                hasPremium
                    ? AppStrings.dashboardPremiumMember
                    : AppStrings.dashboardFreePlan,
                hasPremium ? Icons.workspace_premium : Icons.lock_open,
              ),
              _heroPill(
                _photoStatusLabel(profile),
                Icons.verified_user_outlined,
              ),
              if (_profileMissing)
                _heroPill(
                  AppStrings.dashboardProfileMissing,
                  Icons.info_outline,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _safePushNamed('/matches'),
                  icon: const Icon(Icons.search),
                  label: Text(
                    AppStrings.dashboardViewMatches,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _brandDark,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _profileMissing
                      ? () => _safePushNamed('/create-profile')
                      : () => _safePushNamed(
                          hasPhoto ? '/view-profile' : '/photo-gallery',
                        ),
                  icon: Icon(
                    hasPhoto ? Icons.person_outline : Icons.photo_camera,
                  ),
                  label: Text(
                    _profileMissing
                        ? AppStrings.dashboardCreateProfile
                        : hasPhoto
                        ? AppStrings.myProfile
                        : AppStrings.uploadPhoto,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroAvatar(String? photoUrl, bool hasPhoto) {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
      ),
      child: ProfilePhotoView(
        photoUrl: photoUrl,
        width: 76,
        height: 76,
        borderRadius: BorderRadius.circular(8),
        backgroundColor: Colors.white.withValues(alpha: 0.18),
        placeholderColor: Colors.white,
        placeholderIcon: hasPhoto ? Icons.person : Icons.add_a_photo_outlined,
        placeholderSize: hasPhoto ? 38 : 34,
      ),
    );
  }

  Widget _heroPill(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanStatusBand() {
    if (_planLoading) {
      return _skeletonCard(height: 58);
    }

    final creditText = _contactCreditText;
    final planName = _planName;
    if (creditText == null && planName == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.workspace_premium, color: _gold),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              creditText ?? planName ?? AppStrings.plansNoCurrentPlan,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _ink, fontWeight: FontWeight.w800),
            ),
          ),
          TextButton(
            onPressed: () => _safePushNamed('/plans'),
            child: Text(
              AppStrings.dashboardChangePlan,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextBestActionCard() {
    final action = _nextBestAction;
    if (_profileLoading && _profile == null) {
      return _skeletonCard(height: 116);
    }

    return _sectionCard(
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: action.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(action.icon, color: action.color, size: 28),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.dashboardNextBestAction,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  action.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  action.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, height: 1.25),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: action.onTap,
            style: IconButton.styleFrom(
              backgroundColor: action.color,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.arrow_forward),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(AppStrings.dashboardQuickActions),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _quickChip(
                icon: Icons.search,
                label: AppStrings.browseProfiles,
                onTap: () => _safePushNamed('/matches'),
              ),
              _quickChip(
                icon: Icons.chat_bubble_outline,
                label: AppStrings.chatMenu,
                badge: _chatUnreadCount,
                loading: _attentionLoading,
                onTap: () => _safePushNamed('/chats'),
              ),
              _quickChip(
                icon: Icons.notifications_none,
                label: AppStrings.notificationsTitle,
                badge: _notificationUnreadCount,
                loading: _attentionLoading,
                onTap: () => _safePushNamed('/notifications'),
              ),
              _quickChip(
                icon: Icons.contact_mail_outlined,
                label: AppStrings.contactRequests,
                badge: _contactPendingCount,
                loading: _attentionLoading,
                onTap: () => _safePushNamed('/contact-inbox'),
              ),
              _quickChip(
                icon: Icons.support_agent,
                label: appText.suchakRequestsTitle,
                onTap: () => _safePushNamed('/suchak-requests'),
              ),
              _quickChip(
                icon: Icons.workspace_premium,
                label: AppStrings.plansUpgradeMenu,
                onTap: () => _safePushNamed('/plans'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _quickChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    int badge = 0,
    bool loading = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _cardBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 19, color: _brandDark),
              const SizedBox(width: 7),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (loading) ...[
                const SizedBox(width: 8),
                _miniSkeleton(width: 18, height: 18, radius: 99),
              ] else if (badge > 0) ...[
                const SizedBox(width: 8),
                _badge(badge),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReadinessChecklist() {
    final items = _readinessItems;
    if (_profileLoading && _profile == null) {
      return _skeletonCard(height: 180);
    }

    final completed = items.where((item) => item.ready).toList();
    final missing = items
        .where((item) => !item.ready && item.filled <= 0)
        .toList();
    final partial = items
        .where((item) => !item.ready && item.filled > 0)
        .toList();
    final progress = items.isEmpty ? 0.0 : completed.length / items.length;
    final summaryText = missing.isNotEmpty
        ? _readinessCopy(
            '${missing.length} sections are missing',
            '${missing.length} विभाग बाकी आहेत',
          )
        : partial.isNotEmpty
        ? _readinessCopy(
            '${partial.length} sections need details',
            '${partial.length} विभाग अर्धवट आहेत',
          )
        : _readinessCopy(
            'All key profile sections are ready',
            'प्रोफाइलचे महत्त्वाचे विभाग तयार आहेत',
          );

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _sectionTitle(AppStrings.dashboardReadiness)),
              _readinessCountChip(
                '${completed.length}/${items.length}',
                _success,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            summaryText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _ink,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: progress.clamp(0.0, 1.0).toDouble(),
              backgroundColor: _cardBorder,
              valueColor: AlwaysStoppedAnimation<Color>(
                missing.isNotEmpty
                    ? _danger
                    : partial.isNotEmpty
                    ? _gold
                    : _success,
              ),
            ),
          ),
          if (missing.isNotEmpty) ...[
            const SizedBox(height: 12),
            _readinessGroupLabel(_readinessCopy('Missing', 'बाकी')),
            const SizedBox(height: 8),
            for (final item in missing) _readinessRow(item),
          ],
          if (partial.isNotEmpty) ...[
            const SizedBox(height: 6),
            _readinessGroupLabel(_readinessCopy('Partial', 'अर्धवट')),
            const SizedBox(height: 8),
            for (final item in partial) _readinessRow(item),
          ],
          if (completed.isNotEmpty)
            _readinessFold(
              title: _readinessCopy(
                '${completed.length} completed sections',
                '${completed.length} पूर्ण विभाग',
              ),
              expanded: _showCompletedReadiness,
              onTap: () => setState(
                () => _showCompletedReadiness = !_showCompletedReadiness,
              ),
              children: completed,
            ),
        ],
      ),
    );
  }

  Widget _readinessRow(_ReadinessItem item) {
    final color = _readinessColor(item);
    final status = _readinessStatusLabel(item);
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: item.onTap,
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: item.ready
                  ? _success.withValues(alpha: 0.035)
                  : color.withValues(alpha: 0.045),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.18)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.11),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(item.icon, color: color, size: 19),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _ink,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _readinessCountChip(status, color),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  item.ready ? Icons.check_circle : Icons.chevron_right,
                  color: color,
                  size: item.ready ? 19 : 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _readinessFold({
    required String title,
    required bool expanded,
    required VoidCallback onTap,
    required List<_ReadinessItem> children,
  }) {
    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  color: _muted,
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Column(
            children: [for (final item in children) _readinessRow(item)],
          ),
          crossFadeState: expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 180),
        ),
      ],
    );
  }

  Widget _readinessGroupLabel(String label) {
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: _muted,
        fontSize: 12,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
    );
  }

  Widget _readinessCountChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  _ReadinessItem _readinessItem({
    required String title,
    required IconData icon,
    required int filled,
    required int total,
    required bool primary,
    required VoidCallback onTap,
    int? readyAt,
  }) {
    final safeTotal = total <= 0 ? 1 : total;
    final safeFilled = filled < 0
        ? 0
        : (filled > safeTotal ? safeTotal : filled);

    return _ReadinessItem(
      title: title,
      icon: icon,
      filled: safeFilled,
      total: safeTotal,
      readyAt: readyAt ?? (((safeTotal * 2) / 3).ceil().clamp(1, safeTotal)),
      primary: primary,
      onTap: onTap,
    );
  }

  Color _readinessColor(_ReadinessItem item) {
    if (item.ready) return _success;
    if (item.filled <= 0) return item.primary ? _danger : _warning;
    return _warning;
  }

  String _readinessStatusLabel(_ReadinessItem item) {
    if (item.ready) {
      return item.total > 1
          ? _readinessCopy(
              'Ready ${item.filled}/${item.total}',
              'पूर्ण ${item.filled}/${item.total}',
            )
          : AppStrings.dashboardReady;
    }
    if (item.filled <= 0) {
      return _readinessCopy('Missing', 'बाकी');
    }

    return '${_readinessCopy('Partial', 'अर्धवट')} ${item.filled}/${item.total}';
  }

  String _readinessCopy(String english, String marathi) {
    return isMarathiApp ? marathi : english;
  }

  int _filledCount(List<bool> values) {
    return values.where((value) => value).length;
  }

  bool _hasAnyProfileValue(Map<String, dynamic>? profile, List<String> keys) {
    if (profile == null) return false;
    return keys.any((key) => _hasUsableValue(profile[key]));
  }

  bool _hasAnyListData(Map<String, dynamic>? profile, List<String> keys) {
    if (profile == null) return false;
    return keys.any((key) => _hasListLikeData(profile[key]));
  }

  bool _hasSiblingDecision(Map<String, dynamic>? profile) {
    if (profile == null) return false;
    if (_hasListLikeData(profile['siblings'])) return true;
    return profile.containsKey('has_siblings') &&
        profile['has_siblings'] != null;
  }

  bool _aboutMeReady(Map<String, dynamic>? profile) {
    final text =
        _stringValue(profile?['narrative_about_me']) ??
        _stringValue(profile?['about_me']) ??
        _stringValue(profile?['profile_summary']);
    return text != null && text.length >= 40;
  }

  int _partnerPreferenceFilledCount(Map<String, dynamic>? profile) {
    final prefs = _partnerPreferenceMap(profile);

    return _filledCount([
      _hasAnyPreferenceValue(profile, prefs, const [
        'preferred_age_min',
        'preferred_age_max',
        'age_min',
        'age_max',
      ]),
      _hasAnyPreferenceValue(profile, prefs, const [
        'preferred_height_min_cm',
        'preferred_height_max_cm',
        'height_min_cm',
        'height_max_cm',
      ]),
      _hasAnyPreferenceValue(profile, prefs, const [
        'preferred_income_min',
        'preferred_income_max',
        'income_min',
        'income_max',
      ]),
      _hasAnyPreferenceValue(profile, prefs, const [
        'marriage_type_preference_id',
        'preferred_marriage_type_id',
        'marriage_type',
      ]),
      _hasAnyPreferenceList(profile, prefs, const [
        'preferred_religion_ids',
        'preferred_religions',
      ]),
      _hasAnyPreferenceList(profile, prefs, const [
        'preferred_mother_tongue_ids',
        'preferred_mother_tongues',
      ]),
      _hasAnyPreferenceList(profile, prefs, const [
        'preferred_education_degree_ids',
        'preferred_education_ids',
        'preferred_educations',
      ]),
      _hasAnyPreferenceList(profile, prefs, const [
        'preferred_diet_ids',
        'preferred_diets',
      ]),
      _hasAnyPreferenceList(profile, prefs, const [
        'preferred_locations',
        'preferred_location_ids',
        'preferred_city_ids',
      ]),
    ]);
  }

  Map<String, dynamic>? _partnerPreferenceMap(Map<String, dynamic>? profile) {
    if (profile == null) return null;
    for (final key in const [
      'partner_preferences',
      'partner_preference',
      'partnerPreference',
      'preferences',
    ]) {
      final map = _safeMap(profile[key]);
      if (map != null && map.isNotEmpty) return map;
    }
    return null;
  }

  bool _hasAnyPreferenceValue(
    Map<String, dynamic>? profile,
    Map<String, dynamic>? prefs,
    List<String> keys,
  ) {
    return keys.any(
      (key) => _hasUsableValue(prefs?[key]) || _hasUsableValue(profile?[key]),
    );
  }

  bool _hasAnyPreferenceList(
    Map<String, dynamic>? profile,
    Map<String, dynamic>? prefs,
    List<String> keys,
  ) {
    return keys.any(
      (key) => _hasListLikeData(prefs?[key]) || _hasListLikeData(profile?[key]),
    );
  }

  bool _hasUsableValue(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value > 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized.isNotEmpty &&
          normalized != '0' &&
          normalized != 'null' &&
          normalized != 'n/a';
    }
    if (value is List) return value.isNotEmpty;
    if (value is Map) return value.isNotEmpty;
    return true;
  }

  bool _hasListLikeData(dynamic value) {
    if (value is List) return value.isNotEmpty;
    if (value is Map) {
      final nested = value['data'] ?? value['items'] ?? value['results'];
      if (nested is List) return nested.isNotEmpty;
      return value.isNotEmpty;
    }
    return false;
  }

  Widget _buildActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(AppStrings.dashboardActivity),
        const SizedBox(height: 10),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.42,
          children: [
            _activityTile(
              title: AppStrings.sentInterests,
              value: _sentTotal,
              subtitle: '${AppStrings.pending}: $_sentPending',
              icon: Icons.send_outlined,
              color: const Color(0xFF2563EB),
              loading: _interestsLoading,
              onTap: _openSentInterests,
            ),
            _activityTile(
              title: AppStrings.receivedInterests,
              value: _receivedTotal,
              subtitle: '${AppStrings.pending}: $_receivedPending',
              icon: Icons.inbox_outlined,
              color: _success,
              loading: _interestsLoading,
              onTap: _openReceivedInterests,
            ),
            _activityTile(
              title: AppStrings.contactRequests,
              value: _contactPendingCount,
              subtitle: AppStrings.pending,
              icon: Icons.contact_mail_outlined,
              color: _warning,
              loading: _attentionLoading,
              onTap: () => _safePushNamed('/contact-inbox'),
            ),
            _activityTile(
              title: AppStrings.profileListsShortlist,
              value: _shortlistedCount,
              subtitle:
                  '${AppStrings.profileListsBlocked}: $_blockedCount • ${AppStrings.profileListsHidden}: $_hiddenCount',
              icon: Icons.bookmark_border,
              color: _brandDark,
              loading: _listsLoading,
              onTap: () => _safePushNamed('/profile-lists'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _activityTile({
    required String title,
    required int value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool loading,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 22),
                const Spacer(),
                if (loading)
                  _miniSkeleton(width: 30, height: 18, radius: 6)
                else
                  Text(
                    '$value',
                    style: TextStyle(
                      color: color,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _ink, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountToolsGrid() {
    final tools = <_ToolAction>[
      _ToolAction(
        icon: Icons.person_outline,
        title: AppStrings.myProfile,
        subtitle: AppStrings.myProfileSubtitle,
        onTap: () => _safePushNamed('/view-profile'),
      ),
      _ToolAction(
        icon: Icons.photo_camera_outlined,
        title: AppStrings.photosVerification,
        subtitle: AppStrings.photosVerificationSubtitle,
        onTap: () => _safePushNamed('/photo-gallery'),
      ),
      _ToolAction(
        icon: Icons.workspace_premium,
        title: AppStrings.plansUpgradeMenu,
        subtitle: AppStrings.dashboardPlanToolSubtitle,
        onTap: () => _safePushNamed('/plans'),
      ),
      _ToolAction(
        icon: Icons.article_outlined,
        title: AppStrings.biodataExportMenu,
        subtitle: AppStrings.biodataExportSubtitle,
        onTap: () => _safePushNamed('/biodata-export'),
      ),
      _ToolAction(
        icon: Icons.document_scanner_outlined,
        title: AppStrings.biodataIntakeMenu,
        subtitle: AppStrings.biodataIntakeSubtitle,
        onTap: () => _safePushNamed('/biodata-intake'),
      ),
      _ToolAction(
        icon: Icons.bookmarks_outlined,
        title: AppStrings.profileListsMenu,
        subtitle: AppStrings.dashboardListsToolSubtitle,
        onTap: () => _safePushNamed('/profile-lists'),
      ),
      _ToolAction(
        icon: Icons.settings_outlined,
        title: AppStrings.settingsTitle,
        subtitle: AppStrings.dashboardSettingsToolSubtitle,
        onTap: () => _safePushNamed('/settings'),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(AppStrings.dashboardAccountTools),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: tools.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.22,
          ),
          itemBuilder: (context, index) => _toolTile(tools[index]),
        ),
      ],
    );
  }

  Widget _toolTile(_ToolAction tool) {
    return InkWell(
      onTap: tool.onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _brand.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(tool.icon, color: _brandDark, size: 20),
            ),
            const Spacer(),
            Text(
              tool.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _ink, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              tool.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _muted, fontSize: 12, height: 1.18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _cardBorder),
      ),
      child: child,
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: _ink,
        fontSize: 18,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Widget _buildHeroSkeleton() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _brand.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _miniSkeleton(width: 76, height: 76, radius: 8),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _miniSkeleton(width: 180, height: 20, radius: 6),
                const SizedBox(height: 10),
                _miniSkeleton(width: double.infinity, height: 14, radius: 6),
                const SizedBox(height: 8),
                _miniSkeleton(width: 120, height: 14, radius: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _skeletonCard({required double height}) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _miniSkeleton(width: double.infinity, height: 16, radius: 6),
          const SizedBox(height: 10),
          _miniSkeleton(width: 160, height: 16, radius: 6),
        ],
      ),
    );
  }

  Widget _miniSkeleton({
    required double width,
    required double height,
    required double radius,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE8DDD7).withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  Widget _badge(int count) {
    return Container(
      constraints: const BoxConstraints(minWidth: 21, minHeight: 21),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: _brand,
        borderRadius: BorderRadius.circular(99),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  _DashboardAction get _nextBestAction {
    final profile = _effectiveProfile;
    if (_profileMissing) {
      return _DashboardAction(
        title: AppStrings.dashboardCreateProfile,
        subtitle: AppStrings.dashboardCreateProfileSubtitle,
        icon: Icons.person_add_alt_1,
        color: _brand,
        onTap: () => _safePushNamed('/create-profile'),
      );
    }

    if (!_hasPhoto(profile)) {
      return _DashboardAction(
        title: AppStrings.uploadPhoto,
        subtitle: AppStrings.dashboardUploadPhotoPrompt,
        icon: Icons.add_a_photo_outlined,
        color: _warning,
        onTap: () => _safePushNamed('/photo-gallery'),
      );
    }

    if (_photoPending(profile)) {
      return _DashboardAction(
        title: AppStrings.photosVerification,
        subtitle: AppStrings.dashboardPhotoPendingSubtitle,
        icon: Icons.pending_actions_outlined,
        color: _warning,
        onTap: () => _safePushNamed('/photo-gallery'),
      );
    }

    if (_criticalProfileMissing(profile)) {
      return _DashboardAction(
        title: AppStrings.dashboardCompleteProfile,
        subtitle: AppStrings.dashboardCompleteProfileSubtitle,
        icon: Icons.edit_note,
        color: _brand,
        onTap: () => _openEditProfile(),
      );
    }

    if (_receivedPending > 0) {
      return _DashboardAction(
        title: AppStrings.dashboardRespondInterests,
        subtitle: AppStrings.dashboardRespondInterestsSubtitle,
        icon: Icons.favorite_border,
        color: _success,
        onTap: _openReceivedInterests,
      );
    }

    if (_chatUnreadCount > 0) {
      return _DashboardAction(
        title: AppStrings.dashboardReplyMessages,
        subtitle: AppStrings.dashboardReplyMessagesSubtitle,
        icon: Icons.chat_bubble_outline,
        color: const Color(0xFF128C7E),
        onTap: () => _safePushNamed('/chats'),
      );
    }

    if (_contactPendingCount > 0) {
      return _DashboardAction(
        title: AppStrings.dashboardReviewContactRequests,
        subtitle: AppStrings.dashboardReviewContactRequestsSubtitle,
        icon: Icons.contact_mail_outlined,
        color: _warning,
        onTap: () => _safePushNamed('/contact-inbox'),
      );
    }

    if (_notificationUnreadCount > 0) {
      return _DashboardAction(
        title: AppStrings.dashboardCheckNotifications,
        subtitle: AppStrings.dashboardCheckNotificationsSubtitle,
        icon: Icons.notifications_none,
        color: const Color(0xFF2563EB),
        onTap: () => _safePushNamed('/notifications'),
      );
    }

    if (!_planLoading && !_hasActiveSubscription) {
      return _DashboardAction(
        title: AppStrings.dashboardUpgradePlan,
        subtitle: AppStrings.dashboardUpgradePlanSubtitle,
        icon: Icons.workspace_premium,
        color: _gold,
        onTap: () => _safePushNamed('/plans'),
      );
    }

    return _DashboardAction(
      title: AppStrings.dashboardViewMatches,
      subtitle: AppStrings.dashboardViewMatchesSubtitle,
      icon: Icons.search,
      color: _brand,
      onTap: () => _safePushNamed('/matches'),
    );
  }

  List<_ReadinessItem> get _readinessItems {
    final profile = _effectiveProfile;
    return [
      _readinessItem(
        title: _readinessCopy('Basic Information', 'Basic Information'),
        icon: Icons.badge_outlined,
        filled: _filledCount([
          _profileName(profile) != AppStrings.profile,
          _hasAnyProfileValue(profile, const ['date_of_birth', 'dob', 'age']),
          _hasAnyProfileValue(profile, const [
            'gender_id',
            'gender',
            'gender_label',
          ]),
          _hasAnyProfileValue(profile, const [
            'religion_id',
            'religion',
            'religion_label',
          ]),
          _hasAnyProfileValue(profile, const [
            'caste_id',
            'caste',
            'caste_label',
          ]),
          _hasResidenceLocation(profile),
        ]),
        total: 6,
        readyAt: 5,
        primary: true,
        onTap: () =>
            _openEditProfile(targetSection: EditProfileTargetSection.basic),
      ),
      _readinessItem(
        title: AppStrings.dashboardPhoto,
        icon: Icons.photo_camera_outlined,
        filled: _hasPhoto(profile) ? 1 : 0,
        total: 1,
        primary: true,
        onTap: () =>
            _openEditProfile(targetSection: EditProfileTargetSection.photo),
      ),
      _readinessItem(
        title: _readinessCopy('Physical', 'Physical'),
        icon: Icons.accessibility_new_outlined,
        filled: _filledCount([
          _hasAnyProfileValue(profile, const ['height_cm', 'height']),
          _hasAnyProfileValue(profile, const ['weight_kg', 'weight']),
          _hasAnyProfileValue(profile, const [
            'complexion_id',
            'complexion',
            'complexion_label',
          ]),
          _hasAnyProfileValue(profile, const ['diet_id', 'diet', 'diet_label']),
        ]),
        total: 4,
        readyAt: 3,
        primary: false,
        onTap: () =>
            _openEditProfile(targetSection: EditProfileTargetSection.physical),
      ),
      _readinessItem(
        title: AppStrings.dashboardEducationCareer,
        icon: Icons.school_outlined,
        filled: _filledCount([
          _profileEducation(profile) != null,
          _profileOccupation(profile) != null,
          _hasAnyProfileValue(profile, const [
            'work_location',
            'work_location_label',
            'work_city_id',
            'work_city',
          ]),
          _hasAnyProfileValue(profile, const [
            'annual_income',
            'income',
            'income_amount',
            'income_range',
          ]),
        ]),
        total: 4,
        readyAt: 2,
        primary: true,
        onTap: () => _openEditProfile(
          targetSection: EditProfileTargetSection.educationCareer,
        ),
      ),
      _readinessItem(
        title: _readinessCopy('Family Details', 'Family Details'),
        icon: Icons.family_restroom_outlined,
        filled: _filledCount([
          _hasAnyProfileValue(profile, const ['father_name']),
          _hasAnyProfileValue(profile, const [
            'father_occupation',
            'father_occupation_label',
          ]),
          _hasAnyProfileValue(profile, const ['mother_name']),
          _hasAnyProfileValue(profile, const [
            'mother_occupation',
            'mother_occupation_label',
          ]),
          _hasAnyListData(profile, const [
            'parents_addresses',
            'family_addresses',
          ]),
          _hasAnyProfileValue(profile, const [
            'family_type_id',
            'family_type',
            'family_type_label',
          ]),
          _hasAnyProfileValue(profile, const [
            'family_status',
            'family_status_label',
            'family_values',
            'family_values_label',
          ]),
        ]),
        total: 7,
        readyAt: 3,
        primary: true,
        onTap: () => _openEditProfile(
          targetSection: EditProfileTargetSection.familyDetails,
        ),
      ),
      _readinessItem(
        title: _readinessCopy('Siblings', 'Siblings'),
        icon: Icons.groups_2_outlined,
        filled: _hasSiblingDecision(profile) ? 1 : 0,
        total: 1,
        primary: false,
        onTap: () =>
            _openEditProfile(targetSection: EditProfileTargetSection.siblings),
      ),
      _readinessItem(
        title: _readinessCopy('Relatives', 'Relatives'),
        icon: Icons.handshake_outlined,
        filled: _filledCount([
          _hasAnyListData(profile, const ['relatives']),
          _hasAnyProfileValue(profile, const ['other_relatives_text']),
          _hasAnyListData(profile, const ['alliance_networks']),
        ]),
        total: 3,
        readyAt: 1,
        primary: false,
        onTap: () =>
            _openEditProfile(targetSection: EditProfileTargetSection.relatives),
      ),
      _readinessItem(
        title: _readinessCopy('Property', 'Property'),
        icon: Icons.home_work_outlined,
        filled:
            _hasAnyProfileValue(profile, const [
              'property_details',
              'property_summary',
            ])
            ? 1
            : 0,
        total: 1,
        primary: false,
        onTap: () =>
            _openEditProfile(targetSection: EditProfileTargetSection.property),
      ),
      _readinessItem(
        title: _readinessCopy('Horoscope', 'Horoscope'),
        icon: Icons.auto_awesome_outlined,
        filled: _filledCount([
          _hasAnyProfileValue(profile, const ['rashi_id', 'rashi']),
          _hasAnyProfileValue(profile, const ['nakshatra_id', 'nakshatra']),
          _hasAnyProfileValue(profile, const ['gan_id', 'gan']),
          _hasAnyProfileValue(profile, const ['devak']),
          _hasAnyProfileValue(profile, const ['kul']),
          _hasAnyProfileValue(profile, const ['gotra']),
        ]),
        total: 6,
        readyAt: 2,
        primary: false,
        onTap: () =>
            _openEditProfile(targetSection: EditProfileTargetSection.horoscope),
      ),
      _readinessItem(
        title: _readinessCopy('About Me', 'About Me'),
        icon: Icons.notes_outlined,
        filled: _aboutMeReady(profile) ? 1 : 0,
        total: 1,
        primary: true,
        onTap: () =>
            _openEditProfile(targetSection: EditProfileTargetSection.aboutMe),
      ),
      _readinessItem(
        title: AppStrings.dashboardPartnerPreference,
        icon: Icons.favorite_border,
        filled: _partnerPreferenceFilledCount(profile),
        total: 9,
        readyAt: 3,
        primary: false,
        onTap: () => _openEditProfile(
          targetSection: EditProfileTargetSection.partnerPreferences,
        ),
      ),
    ];
  }

  _InterestStats _interestStats(Map<String, dynamic> response, String key) {
    final data = _safeMap(response['data']);
    final rows = _safeMapList(data?[key] ?? response[key]);
    var pending = 0;
    var accepted = 0;
    var rejected = 0;

    for (final row in rows) {
      final status = _stringValue(row['status'])?.toLowerCase();
      if (status == 'pending') {
        pending++;
      } else if (status == 'accepted') {
        accepted++;
      } else if (status == 'rejected') {
        rejected++;
      }
    }

    return _InterestStats(
      total: rows.length,
      pending: pending,
      accepted: accepted,
      rejected: rejected,
    );
  }

  Map<String, dynamic>? get _effectiveProfile =>
      _profile ?? _safeMap(ApiClient.currentUserProfile);

  bool get _hasActiveSubscription {
    final response = _currentPlanResponse;
    if (response == null) return false;

    final subscription = _safeMap(response['active_subscription']);
    if (subscription != null && subscription.isNotEmpty) return true;

    final currentPlan = _safeMap(response['current_plan']);
    final status = _stringValue(subscription?['status'])?.toLowerCase();
    return status == 'active' ||
        _boolValue(response['active']) ||
        _boolValue(currentPlan?['is_active_subscription']);
  }

  String? get _planName {
    final currentPlan = _safeMap(_currentPlanResponse?['current_plan']);
    return _stringValue(currentPlan?['display_name']) ??
        _stringValue(currentPlan?['name']);
  }

  String? get _contactCreditText {
    final contactView = _safeMap(_currentPlanResponse?['contact_view']);
    final usage = _safeMap(contactView?['usage']);
    final state = _safeMap(contactView?['state']);
    final remaining =
        _intValue(usage?['remaining']) ?? _intValue(state?['remaining']);
    if (remaining == null) return null;
    return AppStrings.dashboardContactCreditsRemaining(remaining);
  }

  bool _hasBasicDetails(Map<String, dynamic>? profile) {
    if (profile == null) return false;
    return _profileName(profile) != AppStrings.profile &&
        (_stringValue(profile['date_of_birth']) != null ||
            _stringValue(profile['dob']) != null ||
            _intValue(profile['age']) != null);
  }

  bool _criticalProfileMissing(Map<String, dynamic>? profile) {
    if (profile == null) return false;
    return !_hasBasicDetails(profile) ||
        _profileLocation(profile) == null ||
        (_profileEducation(profile) == null &&
            _profileOccupation(profile) == null);
  }

  bool _hasPhoto(Map<String, dynamic>? profile) {
    if (profile == null) return false;
    if (ApiClient.resolveProfilePhotoUrl(profile) != null) return true;
    if (_boolValue(profile['photo_uploaded'])) return true;
    if (_stringValue(profile['profile_photo']) != null) return true;

    for (final key in const ['photos', 'profile_photos']) {
      if (_safeMapList(profile[key]).isNotEmpty) return true;
    }
    return false;
  }

  bool _photoPending(Map<String, dynamic>? profile) {
    if (profile == null) return false;
    final status = _stringValue(profile['photo_status'])?.toLowerCase();
    if (status == 'pending') return true;
    return _boolValue(profile['photo_uploaded']) &&
        !_boolValue(profile['photo_approved']);
  }

  String _photoStatusLabel(Map<String, dynamic>? profile) {
    if (!_hasPhoto(profile)) return AppStrings.dashboardPhotoMissing;
    if (_photoPending(profile)) return AppStrings.dashboardPhotoPending;
    if (_boolValue(profile?['photo_approved']) ||
        ApiClient.resolveProfilePhotoUrl(profile) != null) {
      return AppStrings.dashboardPhotoApproved;
    }
    return AppStrings.dashboardProfileActive;
  }

  String _profileName(Map<String, dynamic>? profile) {
    final display = _safeMap(profile?['display']);
    final card = _safeMap(display?['card']);
    final direct =
        _stringValue(profile?['full_name']) ??
        _stringValue(profile?['name']) ??
        _stringValue(card?['name']);
    if (direct != null) return direct;

    final first = _stringValue(profile?['first_name']);
    final last = _stringValue(profile?['last_name']);
    final combined = _joinNonEmpty([first, last], separator: ' ');
    return combined ?? AppStrings.profile;
  }

  String? _profileSummary(Map<String, dynamic>? profile) {
    return _joinNonEmpty([
      _profileAge(profile),
      _stringValue(profile?['height']) ??
          _stringValue(profile?['height_label']),
      _profileLocation(profile),
      _profileEducation(profile),
    ]);
  }

  String? _profileAge(Map<String, dynamic>? profile) {
    final age = _intValue(profile?['age']);
    if (age != null && age > 0) return AppStrings.years(age);
    return null;
  }

  String? _profileLocation(Map<String, dynamic>? profile) {
    return ApiClient.profileLocationLabel(
      profile,
      allowIdFallback: false,
      includeAddressLineFallback: false,
    );
  }

  bool _hasResidenceLocation(Map<String, dynamic>? profile) {
    if (profile == null) return false;
    if (_profileLocation(profile) != null) return true;

    final topLevelId = _intValue(profile['location_id']);
    if (topLevelId != null && topLevelId > 0) return true;

    final addresses = _safeMapList(profile['self_addresses']);
    for (final row in addresses) {
      final type = _stringValue(
        row['address_type_key'] ?? row['address_type'],
      )?.toLowerCase();
      if (type != null && type != 'current') continue;

      final rowLocationId = _intValue(row['location_id'] ?? row['city_id']);
      if (rowLocationId != null && rowLocationId > 0) return true;

      if (_stringValue(row['location_label'] ?? row['display']) != null) {
        return true;
      }
    }

    return false;
  }

  String? _profileEducation(Map<String, dynamic>? profile) {
    final display = _safeMap(profile?['display']);
    final card = _safeMap(display?['card']);
    return _stringValue(profile?['education']) ??
        _stringValue(profile?['education_label']) ??
        _stringValue(profile?['highest_education']) ??
        _stringValue(card?['education']);
  }

  String? _profileOccupation(Map<String, dynamic>? profile) {
    final display = _safeMap(profile?['display']);
    final card = _safeMap(display?['card']);
    return _stringValue(profile?['occupation']) ??
        _stringValue(profile?['occupation_label']) ??
        _stringValue(profile?['profession']) ??
        _stringValue(card?['occupation']);
  }

  int _countFrom(Map<String, dynamic> response, String key) {
    final data = _safeMap(response['data']);
    return _intValue(response[key]) ?? _intValue(data?[key]) ?? 0;
  }

  List<Map<String, dynamic>> _safeMapList(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
    }

    if (value is Map) {
      final nested = value['data'] ?? value['items'] ?? value['results'];
      if (nested is List) return _safeMapList(nested);
    }

    return <Map<String, dynamic>>[];
  }

  Map<String, dynamic>? _safeMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  int? _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  bool _boolValue(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    }
    return false;
  }

  String? _stringValue(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  String? _joinNonEmpty(List<String?> values, {String separator = ' • '}) {
    final parts = values
        .map((value) => value?.trim())
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toList(growable: false);

    return parts.isEmpty ? null : parts.join(separator);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _DashboardAction {
  const _DashboardAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

class _ReadinessItem {
  const _ReadinessItem({
    required this.title,
    required this.icon,
    required this.filled,
    required this.total,
    required this.readyAt,
    required this.primary,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final int filled;
  final int total;
  final int readyAt;
  final bool primary;
  final VoidCallback onTap;

  bool get ready => filled >= readyAt;
}

class _ToolAction {
  const _ToolAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

class _InterestStats {
  const _InterestStats({
    required this.total,
    required this.pending,
    required this.accepted,
    required this.rejected,
  });

  final int total;
  final int pending;
  final int accepted;
  final int rejected;
}
