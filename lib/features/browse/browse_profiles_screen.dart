import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_loading.dart';
import '../../core/app_strings.dart';
import '../../core/api_client.dart';
import '../../core/app_storage.dart';
import '../../core/locked_teaser.dart';
import '../../core/profile_network_image.dart';
import '../../core/profile_photo_hero.dart';
import '../interests/received_interests_screen.dart';
import '../interests/sent_interests_screen.dart';
import '../contact/contact_inbox_screen.dart';
import '../matrimony_profile/profile_detail_screen.dart';
import 'matches_filter_screen.dart';
import '../../core/app_language.dart';

/// ===============================
/// MATCHES / BROWSE PROFILES SCREEN
/// ===============================
class BrowseProfilesScreen extends StatefulWidget {
  const BrowseProfilesScreen({super.key});

  @override
  State<BrowseProfilesScreen> createState() => _BrowseProfilesScreenState();
}

class _BrowseProfilesScreenState extends State<BrowseProfilesScreen>
    with SingleTickerProviderStateMixin {
  static const Color _brandColor = Color(0xFFDC2626);
  static const Color _brandDark = Color(0xFFB91C1C);
  static const Color _brandSoft = Color(0xFFFEE2E2);
  static const Color _surfaceWarm = Color(0xFFFFF8F5);
  static const Color _trustGreen = Color(0xFF16A085);
  static const Color _premiumGold = Color(0xFFF2A900);
  static const List<String> _moreSectionOrder = <String>[
    'looking_for_me',
    'recently_viewed',
    'matching_my_preference',
    'nearby',
    'recent_visitors',
    'you_may_like',
  ];
  static const int _navMatches = 1;
  static const int _navConnect = 2;
  static const int _tabSearch = 0;
  static const int _tabNew = 1;
  static const int _tabDaily = 2;
  static const int _tabMyMatches = 3;
  static const int _tabNearMe = 4;
  static const int _tabMore = 5;
  static const MethodChannel _nativeLocationChannel = MethodChannel(
    'navri_matrimony/native_location',
  );

  List<dynamic> _profiles = [];
  List<Map<String, dynamic>> _moreSections = <Map<String, dynamic>>[];
  Map<String, dynamic>? _viewerContext;
  bool _isLoading = true;
  bool _moreSectionsLoading = false;
  bool _moreSectionsLoaded = false;
  bool _nearbyLocationBusy = false;
  String? _errorMessage;
  String? _moreSectionsError;
  String? _nearbyLocationMessage;
  int _selectedTabIndex = _tabNew;
  int _activeMainNavIndex = _navMatches;
  int _selectedConnectTabIndex = 0;
  bool _routeArgumentsRead = false;
  bool _forceRecommendationDeck = false;
  bool _dailyRecommendationChecked = false;
  bool _recommendationDeckClosed = false;
  bool _showRecommendationDeck = false;
  bool _recommendationComplete = false;
  bool _recommendationActionBusy = false;
  bool _recommendationDragging = false;
  bool _recommendationExiting = false;
  int _notificationUnreadCount = 0;
  int _recommendationIndex = 0;
  double _recommendationDragDx = 0;
  Timer? _recommendationCompletionTimer;
  final Set<int> _sendingInterestIds = <int>{};
  final Set<String> _failedPhotoUrls = <String>{};
  MatchesFilterState _filters = const MatchesFilterState();
  MatchesFilterState _nearbyFilters = const MatchesFilterState();
  late final AnimationController _recommendationHintController;
  late final Animation<double> _recommendationHintOffset;

  @override
  void initState() {
    super.initState();
    _recommendationHintController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    );
    _recommendationHintOffset =
        TweenSequence<double>([
          TweenSequenceItem(tween: ConstantTween<double>(0), weight: 10),
          TweenSequenceItem(
            tween: Tween<double>(begin: 0, end: -86),
            weight: 18,
          ),
          TweenSequenceItem(tween: ConstantTween<double>(-86), weight: 12),
          TweenSequenceItem(
            tween: Tween<double>(begin: -86, end: 0),
            weight: 16,
          ),
          TweenSequenceItem(tween: ConstantTween<double>(0), weight: 8),
          TweenSequenceItem(
            tween: Tween<double>(begin: 0, end: 92),
            weight: 18,
          ),
          TweenSequenceItem(tween: ConstantTween<double>(92), weight: 12),
          TweenSequenceItem(
            tween: Tween<double>(begin: 92, end: 0),
            weight: 16,
          ),
        ]).animate(
          CurvedAnimation(
            parent: _recommendationHintController,
            curve: Curves.easeInOutCubic,
          ),
        );
    _fetchProfileList(feed: _feedForTab(_selectedTabIndex));
    _loadNotificationUnreadCount();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routeArgumentsRead) return;
    _routeArgumentsRead = true;
    final arguments = ModalRoute.of(context)?.settings.arguments;
    if (arguments is Map) {
      if (arguments['initialTab'] == 'more') {
        setState(() {
          _selectedTabIndex = _tabMore;
          _activeMainNavIndex = _navMatches;
        });
        _fetchMoreSections();
      }
      if (arguments['showRecommendationDeck'] == true) {
        _forceRecommendationDeck = true;
        _scheduleRecommendationDeckCheck();
      }
    }
  }

  @override
  void dispose() {
    _recommendationCompletionTimer?.cancel();
    _recommendationHintController.dispose();
    super.dispose();
  }

  Future<void> _fetchProfileList({
    MatchesFilterState? filters,
    String? feed,
  }) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _failedPhotoUrls.clear();
    });

    try {
      final activeFilters = filters;
      final response = await ApiClient.getProfileList(
        ageFrom: activeFilters?.ageFrom,
        ageTo: activeFilters?.ageTo,
        heightFromCm: activeFilters?.heightFromCm,
        heightToCm: activeFilters?.heightToCm,
        religionId: activeFilters?.religionId,
        casteId: activeFilters?.casteId,
        caste: activeFilters?.casteQuery,
        countryId: activeFilters?.countryId,
        stateId: activeFilters?.stateId,
        districtId: activeFilters?.districtId,
        locationId: activeFilters?.locationId,
        photoAvailable: activeFilters?.photoAvailable,
        verifiedPhoto: activeFilters?.verifiedPhoto,
        recentlyActive: activeFilters?.recentlyActive,
        educationId: activeFilters?.educationId,
        occupationId: activeFilters?.occupationId,
        maritalStatusId: activeFilters?.maritalStatusId,
        feed: feed,
      );
      if (!mounted) return;

      final statusCode = response['statusCode'];

      if (statusCode == 401) {
        setState(() {
          _errorMessage = appText.authExpiredLoginAgain;
          _isLoading = false;
        });
        return;
      }

      if (statusCode == 404) {
        setState(() {
          _errorMessage = _emptyProfilesMessage(prefixIcon: true);
          _isLoading = false;
        });
        return;
      }

      if (response['success'] == true && response['profiles'] is List) {
        setState(() {
          _profiles = List<dynamic>.from(response['profiles']);
          _isLoading = false;
        });
        _scheduleRecommendationDeckCheck();
      } else {
        setState(() {
          _profiles = [];
          _errorMessage = _emptyProfilesMessage(prefixIcon: true);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = appText.unexpectedErrorOccurred(e.toString());
        _isLoading = false;
      });
    }
  }

  void _scheduleRecommendationDeckCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowRecommendationDeck();
    });
  }

  Future<void> _maybeShowRecommendationDeck() async {
    if (!mounted ||
        _isLoading ||
        _showRecommendationDeck ||
        _recommendationDeckClosed) {
      return;
    }

    final profiles = _recommendationProfiles();
    if (profiles.isEmpty) return;

    final force = _forceRecommendationDeck;
    if (!force) {
      if (_dailyRecommendationChecked) return;
      _dailyRecommendationChecked = true;
      final shownDate = await AppStorage.instance
          .readDailyRecommendationShownDate();
      if (shownDate == _todayKey()) return;
    }

    await AppStorage.instance.markDailyRecommendationShownDate(_todayKey());
    if (!mounted) return;

    setState(() {
      _forceRecommendationDeck = false;
      _showRecommendationDeck = true;
      _recommendationComplete = false;
      _recommendationDragging = false;
      _recommendationExiting = false;
      _recommendationIndex = 0;
      _recommendationDragDx = 0;
    });
    _runRecommendationHint();
  }

  void _runRecommendationHint() {
    _recommendationHintController
      ..reset()
      ..forward();
  }

  String _todayKey() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  String? _feedForTab(int tabIndex) {
    return switch (tabIndex) {
      _tabNew => 'new',
      _tabDaily => 'daily',
      _tabMyMatches => 'my_matches',
      _tabNearMe => 'nearby',
      _ => null,
    };
  }

  Future<void> _fetchProfileListForCurrentTab() async {
    if (_selectedTabIndex == _tabSearch && !_filters.hasActiveFilters) {
      setState(() {
        _profiles = <dynamic>[];
        _isLoading = false;
        _errorMessage = null;
        _failedPhotoUrls.clear();
      });
      return;
    }

    if (_selectedTabIndex == _tabNearMe &&
        _nearbyLocationOnlyFilters()?.hasLocationFilter != true) {
      setState(() {
        _profiles = <dynamic>[];
        _isLoading = false;
        _errorMessage = null;
        _failedPhotoUrls.clear();
      });
      return;
    }

    return _fetchProfileList(
      filters: _filtersForCurrentTab(),
      feed: _feedForTab(_selectedTabIndex),
    );
  }

  MatchesFilterState? _filtersForCurrentTab() {
    return switch (_selectedTabIndex) {
      _tabSearch => _filters,
      _tabNearMe => _nearbyLocationOnlyFilters(),
      _ => null,
    };
  }

  MatchesFilterState? _nearbyLocationOnlyFilters() {
    final source = _nearbyFilters.hasLocationFilter ? _nearbyFilters : _filters;
    if (!source.hasLocationFilter) return null;

    return MatchesFilterState(
      countryId: source.countryId,
      countryLabel: source.countryLabel,
      stateId: source.stateId,
      stateLabel: source.stateLabel,
      districtId: source.districtId,
      districtLabel: source.districtLabel,
      locationId: source.locationId,
      locationLabel: source.locationLabel,
    );
  }

  Future<void> _fetchMoreSections({bool force = false}) async {
    if (_moreSectionsLoading) return;
    if (_moreSectionsLoaded && !force) return;

    setState(() {
      _moreSectionsLoading = true;
      _moreSectionsError = null;
      _failedPhotoUrls.clear();
    });

    try {
      final response = await ApiClient.getMoreMatchSections();
      if (!mounted) return;

      final sections = response['sections'];
      final viewerContext = response['viewer_context'];
      final ok = response['success'] == true && sections is List;

      setState(() {
        _moreSectionsLoaded = true;
        _moreSectionsLoading = false;
        _moreSections = ok
            ? sections
                  .whereType<Map>()
                  .map((row) => Map<String, dynamic>.from(row))
                  .toList()
            : <Map<String, dynamic>>[];
        _viewerContext = viewerContext is Map
            ? Map<String, dynamic>.from(viewerContext)
            : _viewerContext;
        _moreSectionsError = ok
            ? null
            : appText.moreMatchesSectionsUnavailable;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _moreSectionsLoaded = true;
        _moreSectionsLoading = false;
        _moreSections = <Map<String, dynamic>>[];
        _moreSectionsError = appText.moreMatchesSectionsUnavailable;
      });
    }
  }

  int? _calculateAge(String? dateOfBirth) {
    if (dateOfBirth == null || dateOfBirth.isEmpty) return null;

    try {
      final dob = DateTime.parse(dateOfBirth);
      final now = DateTime.now();
      var age = now.year - dob.year;
      if (now.month < dob.month ||
          (now.month == dob.month && now.day < dob.day)) {
        age--;
      }
      return age > 0 ? age : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _openFilterScreen() async {
    final result = await Navigator.push<MatchesFilterState>(
      context,
      MaterialPageRoute(
        builder: (_) => MatchesFilterScreen(initialFilters: _filters),
      ),
    );
    if (!mounted || result == null || result == _filters) return;

    setState(() {
      _filters = result;
      _activeMainNavIndex = _navMatches;
      _selectedTabIndex = _tabSearch;
      _failedPhotoUrls.clear();
    });
    await _fetchProfileListForCurrentTab();
  }

  @override
  Widget build(BuildContext context) {
    final recommendationProfiles = _recommendationProfiles();
    if (_showRecommendationDeck &&
        recommendationProfiles.isNotEmpty &&
        _recommendationIndex < recommendationProfiles.length) {
      return _buildRecommendationScaffold(recommendationProfiles);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.browseProfiles),
        centerTitle: true,
        backgroundColor: _brandColor,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: true,
        actions: [
          IconButton(
            tooltip: appText.notificationsTitle,
            icon: _buildNotificationIcon(),
            onPressed: _openNotifications,
          ),
          IconButton(
            tooltip: AppStrings.matchesFilter,
            icon: const Icon(Icons.filter_alt),
            onPressed: _openFilterScreen,
          ),
        ],
      ),
      backgroundColor: _surfaceWarm,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildTopDiscoveryArea(),
            Expanded(child: _buildProfileListBody()),
          ],
        ),
      ),
      bottomNavigationBar: _buildMatchesBottomNav(),
    );
  }

  Widget _buildTopDiscoveryArea() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildTopSubmenu(),
          if (_activeSummaryVisible()) _buildActiveFilterSummary(),
        ],
      ),
    );
  }

  bool _activeSummaryVisible() {
    if (_activeMainNavIndex != _navMatches) return false;
    if (_selectedTabIndex == _tabSearch) return _filters.hasActiveFilters;
    if (_selectedTabIndex == _tabNearMe) {
      return _nearbyLocationOnlyFilters()?.hasLocationFilter == true;
    }
    return false;
  }

  Widget _buildActiveFilterSummary() {
    final isNearby = _selectedTabIndex == _tabNearMe;
    final summary = isNearby
        ? _locationSummary(_nearbyLocationOnlyFilters())
        : _searchSummary(_filters);
    final title = isNearby
        ? (appText.nearbyLocation)
        : (appText.searchFilters);
    final clearLabel = isNearby
        ? (appText.clearLocation)
        : (appText.clearFilter);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _brandColor.withValues(alpha: 0.18)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
          child: Row(
            children: [
              Icon(
                isNearby
                    ? Icons.my_location_rounded
                    : Icons.manage_search_rounded,
                color: _brandColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF442328),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF6B4C51),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: isNearby
                    ? _clearNearbyLocation
                    : _clearSearchFilters,
                style: TextButton.styleFrom(
                  foregroundColor: _brandColor,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                ),
                child: Text(clearLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _searchSummary(MatchesFilterState filters) {
    final parts = <String>[
      if (filters.religionLabel?.trim().isNotEmpty == true)
        filters.religionLabel!.trim(),
      if (filters.casteLabel?.trim().isNotEmpty == true)
        filters.casteLabel!.trim(),
      if (filters.ageFrom != null || filters.ageTo != null)
        '${filters.ageFrom ?? 18}-${filters.ageTo ?? 70}',
      if (filters.heightFromCm != null || filters.heightToCm != null)
        '${filters.heightFromCm ?? 137}-${filters.heightToCm ?? 213} cm',
      if (filters.educationLabel?.trim().isNotEmpty == true)
        filters.educationLabel!.trim(),
      if (filters.occupationLabel?.trim().isNotEmpty == true)
        filters.occupationLabel!.trim(),
      if (filters.maritalStatusLabel?.trim().isNotEmpty == true)
        filters.maritalStatusLabel!.trim(),
      if (filters.photoAvailable)
        appText.photoAvailable,
      if (filters.recentlyActive)
        appText.recentlyActive,
      if (filters.hasLocationFilter) _locationSummary(filters),
    ];

    if (parts.isEmpty) {
      return appText.chooseSearchFilters;
    }
    return parts.take(4).join(' • ');
  }

  String _locationSummary(MatchesFilterState? filters) {
    if (filters == null) return '';
    final parts = <String>[
      if (filters.locationLabel?.trim().isNotEmpty == true)
        filters.locationLabel!.trim(),
      if (filters.districtLabel?.trim().isNotEmpty == true)
        filters.districtLabel!.trim(),
      if (filters.stateLabel?.trim().isNotEmpty == true)
        filters.stateLabel!.trim(),
      if (filters.countryLabel?.trim().isNotEmpty == true)
        filters.countryLabel!.trim(),
    ];
    return parts.isEmpty
        ? (appText.locationSelected)
        : parts.take(3).join(' • ');
  }

  Widget _buildMatchesBottomNav() {
    // Home = Dashboard, My Profile, Upload Photos, Shortlist
    // Matches = Search/New/Daily/My Matches/Near Me/More
    // Connect = Interests, Contact Requests, WhatsApp Response/Mediation when mobile support exists
    // Chat = Conversations when mobile chat API exists
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 18,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Row(
          children: [
            _buildBottomNavItem(
              icon: Icons.home_outlined,
              label: AppStrings.bottomHome,
              onTap: () => Navigator.pushNamed(context, '/home'),
            ),
            _buildBottomNavItem(
              icon: Icons.favorite,
              label: AppStrings.bottomMatches,
              active: _activeMainNavIndex == _navMatches,
              onTap: _activateMatchesNav,
            ),
            _buildBottomNavItem(
              icon: Icons.wc_rounded,
              label: AppStrings.bottomConnect,
              active: _activeMainNavIndex == _navConnect,
              onTap: _activateConnectNav,
            ),
            _buildBottomNavItem(
              icon: Icons.chat_bubble_outline,
              label: AppStrings.bottomChat,
              onTap: _openChatOrSoon,
            ),
          ],
        ),
      ),
    );
  }

  Scaffold _buildRecommendationScaffold(List<Map<String, dynamic>> profiles) {
    if (_recommendationComplete) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FFF8),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildRecommendationHeader(),
                Expanded(child: _buildRecommendationCompleteState()),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FFF8),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildRecommendationHeader(),
              const SizedBox(height: 14),
              Expanded(child: _buildRecommendationDeck(profiles)),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildRecommendationActionBar(),
    );
  }

  Widget _buildRecommendationHeader() {
    return SizedBox(
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 54),
              child: FittedBox(
                alignment: Alignment.center,
                fit: BoxFit.scaleDown,
                child: Text(
                  appText.recommendationTitle,
                  maxLines: 1,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 44,
              height: 44,
              child: IconButton(
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: _closeRecommendationDeck,
                icon: const Icon(Icons.close_rounded, size: 30),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationCompleteState() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF86EFAC), width: 1.4),
              ),
              child: const Icon(
                Icons.done_all_rounded,
                color: Color(0xFF15803D),
                size: 42,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              appText.todaysRecommendationsComplete,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Color(0xFF111827),
                fontSize: 22,
                fontWeight: FontWeight.w900,
                height: 1.12,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              appText.newSetWillAppearHere,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _closeRecommendationDeck,
                icon: const Icon(Icons.favorite_border_rounded),
                label: Text(appText.viewMatches),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              appText.matchesScreenWillAppearSoon,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationActionBar() {
    final disabled =
        _recommendationActionBusy ||
        _recommendationExiting ||
        _recommendationComplete;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
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
                child: OutlinedButton.icon(
                  onPressed: disabled ? null : _skipRecommendationProfile,
                  icon: const Icon(Icons.close_rounded, size: 20),
                  label: Text(
                    appText.skip,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    foregroundColor: _brandColor,
                    side: const BorderSide(color: _brandColor, width: 1.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: disabled ? null : _sendRecommendationInterest,
                  icon: _recommendationActionBusy
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.favorite_rounded, size: 20),
                  label: Text(
                    appText.suchakRequestInterested,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: _brandColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecommendationDeck(List<Map<String, dynamic>> profiles) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final current = profiles[_recommendationIndex];
        final nextIndex = _recommendationIndex + 1;
        final next = nextIndex < profiles.length ? profiles[nextIndex] : null;

        return AnimatedBuilder(
          animation: _recommendationHintController,
          builder: (context, child) {
            final hintOffset = _recommendationDragDx == 0
                ? _recommendationHintOffset.value
                : 0.0;
            final offset = _recommendationDragDx + hintOffset;
            final reveal = (offset.abs() / width).clamp(0.0, 1.0).toDouble();

            return Stack(
              clipBehavior: Clip.none,
              children: [
                if (next != null)
                  Positioned.fill(
                    top: 12 - (reveal * 10),
                    child: Transform.scale(
                      scale: 0.96 + (reveal * 0.035),
                      child: Opacity(
                        opacity: 0.55 + (reveal * 0.20),
                        child: _buildRecommendationCard(
                          next,
                          height,
                          nextIndex,
                        ),
                      ),
                    ),
                  ),
                Semantics(
                  label: appText.swipeInterestHint,
                  child: GestureDetector(
                    onHorizontalDragStart: (_) {
                      if (_recommendationActionBusy ||
                          _recommendationExiting ||
                          _recommendationComplete) {
                        return;
                      }
                      _recommendationHintController.stop();
                      setState(() {
                        _recommendationDragging = true;
                      });
                    },
                    onHorizontalDragUpdate: (details) {
                      if (_recommendationActionBusy ||
                          _recommendationExiting ||
                          _recommendationComplete) {
                        return;
                      }
                      setState(() {
                        _recommendationDragDx =
                            (_recommendationDragDx + details.delta.dx).clamp(
                              -width,
                              width,
                            );
                      });
                    },
                    onHorizontalDragEnd: (details) {
                      if (_recommendationActionBusy ||
                          _recommendationExiting ||
                          _recommendationComplete) {
                        return;
                      }
                      final velocity = details.primaryVelocity ?? 0;
                      final threshold = width * 0.24;
                      setState(() {
                        _recommendationDragging = false;
                      });
                      if (_recommendationDragDx > threshold || velocity > 650) {
                        _sendRecommendationInterest();
                        return;
                      }
                      if (_recommendationDragDx < -threshold ||
                          velocity < -650) {
                        _skipRecommendationProfile();
                        return;
                      }
                      setState(() {
                        _recommendationDragDx = 0;
                      });
                    },
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey<int>(_recommendationIndex),
                      tween: Tween<double>(end: offset),
                      duration: _recommendationDragging
                          ? Duration.zero
                          : const Duration(milliseconds: 260),
                      curve: _recommendationExiting
                          ? Curves.easeInCubic
                          : Curves.easeOutCubic,
                      builder: (context, animatedOffset, child) {
                        final progress = (animatedOffset / width)
                            .clamp(-1.0, 1.0)
                            .toDouble();
                        final rotation = progress * 0.18;
                        final lift =
                            -8 * (animatedOffset.abs() / width).clamp(0, 1);
                        final pivot = _recommendationRotationPivot(
                          animatedOffset,
                        );

                        return Transform.translate(
                          offset: Offset(animatedOffset, lift.toDouble()),
                          child: Transform.rotate(
                            alignment: pivot,
                            angle: rotation,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                _buildRecommendationCard(
                                  current,
                                  height,
                                  _recommendationIndex,
                                ),
                                _buildRecommendationSwipeLabel(animatedOffset),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Alignment _recommendationRotationPivot(double offset) {
    if (offset > 0) return Alignment.bottomRight;
    if (offset < 0) return Alignment.bottomLeft;
    return Alignment.bottomCenter;
  }

  Widget _buildRecommendationCard(
    Map<String, dynamic> profile,
    double height,
    int deckIndex,
  ) {
    return _buildMatchCard(
      profile,
      height: height,
      margin: EdgeInsets.zero,
      showActionStrip: false,
      // The deck stacks the current card and the one behind it at the same
      // time, so the scope is the deck position rather than the deck itself.
      photoHeroScope: 'deck:$deckIndex',
    );
  }

  Widget _buildRecommendationSwipeLabel(double offset) {
    if (offset.abs() < 24) return const SizedBox.shrink();
    final interested = offset > 0;
    final color = interested ? const Color(0xFF16A34A) : _brandColor;
    return Positioned(
      top: 32,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Text(
            interested
                ? appText.suchakRequestInterested.toUpperCase()
                : appText.skip.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _sendRecommendationInterest() async {
    if (_recommendationActionBusy || _recommendationExiting) return;
    final profiles = _recommendationProfiles();
    if (_recommendationIndex >= profiles.length) return;
    final profile = profiles[_recommendationIndex];
    final exitWidth = MediaQuery.sizeOf(context).width + 160;

    setState(() {
      _recommendationActionBusy = true;
      _recommendationDragging = false;
      _recommendationExiting = true;
      _recommendationDragDx = exitWidth;
    });
    final sent = await _sendInterestFromCard(profile);
    if (!mounted) return;
    setState(() {
      _recommendationActionBusy = false;
    });
    if (sent) {
      _finishRecommendationAdvance();
    } else if (mounted) {
      setState(() {
        _recommendationDragDx = 0;
        _recommendationExiting = false;
      });
    }
  }

  void _skipRecommendationProfile() {
    if (_recommendationActionBusy || _recommendationExiting) return;
    unawaited(_advanceRecommendationDeck(direction: -1));
  }

  Future<void> _advanceRecommendationDeck({required int direction}) async {
    final profiles = _recommendationProfiles();
    if (_recommendationIndex >= profiles.length) return;
    final exitWidth = MediaQuery.sizeOf(context).width + 160;
    setState(() {
      _recommendationDragging = false;
      _recommendationExiting = true;
      _recommendationDragDx = direction * exitWidth;
    });

    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;

    _finishRecommendationAdvance();
  }

  void _finishRecommendationAdvance() {
    final profiles = _recommendationProfiles();
    if (_recommendationIndex >= profiles.length) return;

    if (_recommendationIndex + 1 >= profiles.length) {
      _showRecommendationCompletion();
      return;
    }

    setState(() {
      _recommendationIndex += 1;
      _recommendationDragDx = 0;
      _recommendationExiting = false;
    });
  }

  void _showRecommendationCompletion() {
    _recommendationCompletionTimer?.cancel();
    setState(() {
      _recommendationComplete = true;
      _recommendationActionBusy = false;
      _recommendationDragging = false;
      _recommendationExiting = false;
      _recommendationDragDx = 0;
    });

    _recommendationCompletionTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      _closeRecommendationDeck();
    });
  }

  void _closeRecommendationDeck() {
    _recommendationCompletionTimer?.cancel();
    setState(() {
      _showRecommendationDeck = false;
      _recommendationDeckClosed = true;
      _recommendationComplete = false;
      _recommendationActionBusy = false;
      _recommendationDragging = false;
      _recommendationExiting = false;
      _recommendationDragDx = 0;
    });
  }

  Widget _buildBottomNavItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
  }) {
    final color = active ? _brandColor : const Color(0xFF6B5C60);

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _activateMatchesNav() {
    setState(() {
      _activeMainNavIndex = _navMatches;
    });
  }

  void _activateConnectNav() {
    setState(() {
      _activeMainNavIndex = _navConnect;
    });
  }

  Future<void> _loadNotificationUnreadCount() async {
    try {
      final response = await ApiClient.getNotificationUnreadCount();
      if (!mounted) return;
      if (response['success'] == true) {
        setState(() {
          _notificationUnreadCount = _displayInt(response['unread_count']) ?? 0;
        });
      }
    } catch (_) {
      // Unread badge is best-effort; the Notifications screen shows errors.
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.pushNamed(context, '/notifications');
    if (!mounted) return;
    await _loadNotificationUnreadCount();
  }

  Widget _buildNotificationIcon() {
    if (_notificationUnreadCount <= 0) {
      return const Icon(Icons.notifications_none);
    }

    final count = _notificationUnreadCount > 99
        ? '99+'
        : _notificationUnreadCount.toString();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.notifications_none),
        Positioned(
          right: -6,
          top: -7,
          child: Container(
            constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: _premiumGold,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white, width: 1),
            ),
            alignment: Alignment.center,
            child: Text(
              count,
              style: const TextStyle(
                color: Color(0xFF35191D),
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _openReceivedInterests() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ReceivedInterestsScreen()),
    );
  }

  void _openSentInterests() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SentInterestsScreen()),
    );
  }

  void _openChatOrSoon() {
    Navigator.pushNamed(context, '/chats');
  }

  Widget _buildTopSubmenu() {
    if (_activeMainNavIndex == _navConnect) {
      return _buildConnectTabs();
    }

    return _buildTabs();
  }

  Widget _buildConnectTabs() {
    // Future mobile-backed tabs: Contact Requests, WhatsApp Response/Mediation,
    // and Chat. Add them here only when real mobile APIs exist.
    final tabs = [
      AppStrings.connectContactRequests,
      AppStrings.connectReceived,
      AppStrings.connectSent,
      AppStrings.connectUpgrade,
    ];

    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
        itemCount: tabs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = _selectedConnectTabIndex == index;

          return ChoiceChip(
            label: Text(
              tabs[index],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            selected: selected,
            showCheckmark: false,
            selectedColor: _brandColor,
            backgroundColor: const Color(0xFFF7F0EC),
            side: BorderSide(
              color: selected ? _brandColor : const Color(0xFFE6D8D3),
            ),
            labelStyle: TextStyle(
              color: selected ? Colors.white : const Color(0xFF594044),
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
            onSelected: (_) {
              setState(() {
                _selectedConnectTabIndex = index;
              });
              if (index == 0) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ContactInboxScreen()),
                );
              } else if (index == 1) {
                _openReceivedInterests();
              } else if (index == 2) {
                _openSentInterests();
              } else {
                Navigator.pushNamed(context, '/plans');
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildTabs() {
    final tabs = [
      AppStrings.matchesTabSearch,
      AppStrings.matchesTabNew,
      AppStrings.matchesTabDaily,
      AppStrings.matchesTabMyMatches,
      AppStrings.matchesTabNearMe,
      AppStrings.matchesTabMore,
    ];

    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
        itemCount: tabs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final tabIndex = index;
          final selected = _selectedTabIndex == tabIndex;
          final label = tabs[tabIndex];
          return ChoiceChip(
            label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            selected: selected,
            showCheckmark: false,
            selectedColor: _brandColor,
            backgroundColor: const Color(0xFFF7F0EC),
            side: BorderSide(
              color: selected ? _brandColor : const Color(0xFFE6D8D3),
            ),
            labelStyle: TextStyle(
              color: selected ? Colors.white : const Color(0xFF594044),
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
            onSelected: (_) {
              setState(() {
                _selectedTabIndex = tabIndex;
                _activeMainNavIndex = _navMatches;
                _failedPhotoUrls.clear();
              });
              if (tabIndex == _tabMore) {
                _fetchMoreSections();
              } else {
                _fetchProfileListForCurrentTab();
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildProfileListBody() {
    if (_isLoading) {
      return AppLoadingState.matches();
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
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
                onPressed: _fetchProfileListForCurrentTab,
                child: Text(AppStrings.retry),
              ),
            ],
          ),
        ),
      );
    }

    final profiles = _profileRows();
    if (_selectedTabIndex == _tabSearch && !_filters.hasActiveFilters) {
      return _buildPromptList(_buildSearchPromptCard());
    }

    if (_selectedTabIndex == _tabNearMe &&
        _nearbyLocationOnlyFilters()?.hasLocationFilter != true) {
      return _buildPromptList(_buildNearMePromptCard());
    }

    if (profiles.isEmpty && _selectedTabIndex != _tabMore) {
      return Center(
        child: Text(
          _emptyProfilesMessage(),
          style: const TextStyle(fontSize: 16),
          textAlign: TextAlign.center,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _selectedTabIndex == _tabMore
          ? () => _fetchMoreSections(force: true)
          : _fetchProfileListForCurrentTab,
      child: _selectedTabIndex == _tabMore
          ? _buildMoreMatchesList(profiles)
          : _buildStandardMatchesList(profiles),
    );
  }

  Widget _buildPromptList(Widget child) {
    return RefreshIndicator(
      onRefresh: _fetchProfileListForCurrentTab,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.52,
            child: Center(child: child),
          ),
        ],
      ),
    );
  }

  Widget _buildStandardMatchesList(List<Map<String, dynamic>> profiles) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pageHeight = constraints.maxHeight;

        return PageView.builder(
          scrollDirection: Axis.vertical,
          physics: const PageScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          itemCount: profiles.length,
          itemBuilder: (context, index) {
            final profile = profiles[index];
            final cardHeight = (pageHeight - 34).clamp(360.0, 720.0);

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              child: _buildMatchCard(
                profile,
                height: cardHeight.toDouble(),
                margin: EdgeInsets.zero,
                photoHeroScope: 'matches:$index',
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSearchPromptCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _brandColor.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: _BrowseProfilesScreenState._brandSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.manage_search_rounded,
                  color: _BrowseProfilesScreenState._brandColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appText.chooseSearchFilters,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF443337),
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      appText.searchWithAgeCommunityLocationAnd,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _openFilterScreen,
            icon: const Icon(Icons.tune_rounded),
            label: Text(AppStrings.matchesFilter),
            style: ElevatedButton.styleFrom(
              backgroundColor: _brandColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              textStyle: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNearMePromptCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _brandColor.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: _BrowseProfilesScreenState._brandSoft,
                  shape: BoxShape.circle,
                ),
                child: _nearbyLocationBusy
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(
                        Icons.my_location_rounded,
                        color: _BrowseProfilesScreenState._brandColor,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appText.useLocationForNearby,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF443337),
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _nearbyLocationMessage ??
                          (appText.allowLocationToApplyTheClosest),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _nearbyLocationBusy
                      ? null
                      : _useCurrentLocationForNearby,
                  icon: const Icon(Icons.near_me_outlined),
                  label: Text(
                    appText.useLocation,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    textStyle: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openFilterScreen,
                  icon: const Icon(Icons.tune_rounded),
                  label: Text(AppStrings.matchesFilter),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _brandColor,
                    side: const BorderSide(color: _brandColor),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    textStyle: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _useCurrentLocationForNearby() async {
    setState(() {
      _nearbyLocationBusy = true;
      _nearbyLocationMessage = appText.gettingLocation;
    });

    try {
      final payload = await _nativeLocationChannel
          .invokeMapMethod<String, dynamic>('getApproximateLocation', {
            'locale': appLanguageCode(currentAppLanguage),
          });
      if (!mounted) return;

      final location = await _findBestAppLocation(payload ?? const {});
      if (!mounted) return;

      if (location == null) {
        setState(() {
          _nearbyLocationBusy = false;
          _nearbyLocationMessage = appText.locationFoundButNoMatchingApp;
        });
        _showSnackBar(
          appText.chooseCityDistrictFromFilters,
        );
        return;
      }

      final locationId = ApiClient.locationIdFrom(location);
      final label = ApiClient.locationSuggestionLabel(location);
      setState(() {
        _nearbyFilters = MatchesFilterState(
          locationId: locationId,
          locationLabel: label,
        );
        _nearbyLocationBusy = false;
        _nearbyLocationMessage = AppStrings.isMarathi
            ? '$label लागू केले.'
            : '$label applied.';
      });
      await _fetchProfileListForCurrentTab();
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() {
        _nearbyLocationBusy = false;
        _nearbyLocationMessage = _nearbyLocationErrorMessage(error);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _nearbyLocationBusy = false;
        _nearbyLocationMessage = appText.couldNotUseLocation;
      });
    }
  }

  void _clearSearchFilters() {
    setState(() {
      _filters = const MatchesFilterState();
      if (_selectedTabIndex == _tabSearch) {
        _profiles = <dynamic>[];
        _errorMessage = null;
        _isLoading = false;
      }
    });
  }

  void _clearNearbyLocation() {
    setState(() {
      _nearbyFilters = const MatchesFilterState();
      if (_filters.hasLocationFilter) {
        _filters = _filters.copyWith(
          countryId: null,
          countryLabel: null,
          stateId: null,
          stateLabel: null,
          districtId: null,
          districtLabel: null,
          locationId: null,
          locationLabel: null,
        );
      }
      _nearbyLocationMessage = null;
      if (_selectedTabIndex == _tabNearMe && !_filters.hasLocationFilter) {
        _profiles = <dynamic>[];
        _errorMessage = null;
        _isLoading = false;
      }
    });
  }

  Future<Map<String, dynamic>?> _findBestAppLocation(
    Map<String, dynamic> payload,
  ) async {
    final seen = <String>{};
    for (final term in _nearbySearchTerms(payload)) {
      final key = term.toLowerCase();
      if (!seen.add(key)) continue;

      final results = await ApiClient.searchLocations(
        term,
        limit: 6,
        locale: appLanguageCode(currentAppLanguage),
      );
      if (results.isNotEmpty) return results.first;
    }
    return null;
  }

  Iterable<String> _nearbySearchTerms(Map<String, dynamic> payload) sync* {
    const keys = [
      'locality',
      'locality_en',
      'sub_locality',
      'sub_locality_en',
      'district',
      'district_en',
      'state',
      'state_en',
    ];

    for (final key in keys) {
      final value = _displayString(payload[key]);
      if (value != null && value.length >= 2) yield value;
    }

    for (final key in ['address_line', 'address_line_en']) {
      final address = _displayString(payload[key]);
      if (address == null) continue;
      for (final part in address.split(',')) {
        final term = part.trim();
        if (term.length >= 2) yield term;
      }
    }
  }

  String _nearbyLocationErrorMessage(PlatformException error) {
    return switch (error.code) {
      'PERMISSION_DENIED' =>
        appText.locationPermissionIsNeededForNearby,
      'LOCATION_DISABLED' =>
        appText.deviceLocationIsOffTurnOn,
      'LOCATION_TIMEOUT' =>
        appText.locationTookTooLongTryAgain,
      'LOCATION_PENDING' =>
        appText.aLocationRequestIsAlreadyRunning,
      _ =>
        appText.couldNotUseLocation,
    };
  }

  ListView _buildMoreMatchesList(List<Map<String, dynamic>> profiles) {
    if (!_moreSectionsLoaded && !_moreSectionsLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _fetchMoreSections();
        }
      });
    }

    final sections = _orderedMoreSections();
    final hasBackendSections = sections.isNotEmpty;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
      children: [
        if (_moreSectionsLoading) _buildMoreSectionsLoadingCard(),
        if (_moreSectionsLoading) const SizedBox(height: 16),
        if (hasBackendSections)
          for (final section in sections) ..._buildBackendSection(section)
        else ...[
          if (_moreSectionsError != null) _buildMoreSectionsFallbackNotice(),
          if (_moreSectionsError != null) const SizedBox(height: 14),
          // This branch deliberately shows the first few profiles twice — once
          // in the strip, again in the cards below — so the two copies must be
          // scoped apart or they would claim one tag each and crash the flight.
          _buildMiniCarousel(profiles, scope: 'fallback_mini'),
          if (profiles.isNotEmpty) const SizedBox(height: 16),
          for (final (index, profile) in profiles.indexed)
            _buildMatchCard(profile, photoHeroScope: 'fallback_card:$index'),
        ],
      ],
    );
  }

  List<Map<String, dynamic>> _orderedMoreSections() {
    final byKey = <String, Map<String, dynamic>>{};
    for (final section in _moreSections) {
      final key = _displayString(section['key']);
      if (key != null && _moreSectionOrder.contains(key)) {
        byKey[key] = section;
      }
    }

    return _moreSectionOrder
        .map((key) => byKey[key])
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  /// The More tab renders every server section at once, and the server builds
  /// them independently with no cross-section de-duplication — one profile can
  /// legitimately be in `matching_my_preference`, `nearby` and `you_may_like`
  /// together. The section key is therefore part of every photo's hero scope, so
  /// those copies never collide. `_orderedMoreSections` keys the sections by
  /// name, so a key can only be laid out once.
  List<Widget> _buildBackendSection(Map<String, dynamic> section) {
    final key = _displayString(section['key']) ?? '';
    final profiles = _sectionProfiles(section);

    if (key == 'recent_visitors') {
      final visitorCards = _recentVisitorCards(section);
      return [
        _buildSectionHeader(_sectionTitle(section), _sectionSubtitle(section)),
        if (visitorCards.isEmpty)
          _buildRecentVisitorsEmptyCard(section)
        else
          _buildCompactMixedGrid(visitorCards),
        const SizedBox(height: 18),
      ];
    }

    if (profiles.isEmpty) {
      return <Widget>[];
    }

    return [
      _buildSectionHeader(_sectionTitle(section), _sectionSubtitle(section)),
      switch (key) {
        'looking_for_me' => _buildHorizontalProfileCarousel(
          profiles,
          scope: key,
        ),
        'recently_viewed' => _buildRecentlyViewedStrip(profiles, scope: key),
        'matching_my_preference' => _buildMatchingPreferenceLayout(
          profiles,
          scope: key,
        ),
        'nearby' => _buildNearbyProfileStrip(profiles, scope: key),
        'you_may_like' => _buildCompactProfileGrid(profiles, scope: key),
        _ => _buildCompactProfileGrid(profiles, scope: key),
      },
      const SizedBox(height: 18),
    ];
  }

  List<Map<String, dynamic>> _sectionProfiles(Map<String, dynamic> section) {
    final profiles = section['profiles'];
    if (profiles is! List) return <Map<String, dynamic>>[];

    return profiles
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  List<Map<String, dynamic>> _sectionTeasers(Map<String, dynamic> section) {
    final teasers = section['teasers'];
    if (teasers is! List) return <Map<String, dynamic>>[];

    return teasers
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  List<Widget> _recentVisitorCards(Map<String, dynamic> section) {
    const scope = 'recent_visitors';
    final rows = section['rows'];
    if (rows is List && rows.isNotEmpty) {
      final cards = <Widget>[];
      for (final (index, rawRow) in rows.whereType<Map>().indexed) {
        final row = Map<String, dynamic>.from(rawRow);
        final mode = _displayString(row['mode'])?.toLowerCase();
        if (mode == 'profile') {
          final profile = _safeMap(row['profile']);
          if (profile != null) {
            cards.add(
              _buildCompactProfileCard(
                profile,
                photoHeroScope: '$scope:$index',
              ),
            );
          }
        } else if (mode == 'teaser') {
          final teaser = _safeMap(row['teaser']);
          if (teaser != null) cards.add(_buildRecentVisitorTeaserCard(teaser));
        }
      }
      return cards;
    }

    return <Widget>[
      for (final (index, profile) in _sectionProfiles(section).indexed)
        _buildCompactProfileCard(profile, photoHeroScope: '$scope:$index'),
      ..._sectionTeasers(section).map(_buildRecentVisitorTeaserCard),
    ];
  }

  Widget _buildCompactMixedGrid(List<Widget> cards) {
    if (cards.isEmpty) return const SizedBox.shrink();

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.66,
      children: cards,
    );
  }

  String _sectionTitle(Map<String, dynamic> section) {
    final currentTitle = AppStrings.isMarathi
        ? _displayString(section['title_mr'])
        : _displayString(section['title_en']);
    if (currentTitle != null) return currentTitle;

    return AppStrings.moreMatchesSectionTitle(
      _displayString(section['key']) ?? '',
      _targetGender(),
    );
  }

  String _sectionSubtitle(Map<String, dynamic> section) {
    final subtitle = AppStrings.isMarathi
        ? _displayString(section['subtitle_mr'])
        : _displayString(section['subtitle_en']);
    return subtitle ??
        AppStrings.moreMatchesSectionSubtitle(
          _displayString(section['key']) ?? '',
        );
  }

  Widget _buildMoreSectionsLoadingCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _brandColor.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Text(
            AppStrings.loading,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildMoreSectionsFallbackNotice() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _brandSoft),
      ),
      child: Text(
        appText.moreMatchesSectionsAreUnavailableShowing,
        style: TextStyle(
          color: Colors.grey.shade700,
          fontWeight: FontWeight.w700,
          height: 1.25,
        ),
      ),
    );
  }

  Widget _buildRecentVisitorsEmptyCard(Map<String, dynamic> section) {
    final locked =
        _displayBool(section['locked']) == true ||
        _displayBool(section['requires_upgrade']) == true;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _brandColor.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: _BrowseProfilesScreenState._brandSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              locked ? Icons.lock_outline : Icons.visibility_off_outlined,
              color: _BrowseProfilesScreenState._brandColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              AppStrings.recentVisitorsEmpty,
              style: const TextStyle(
                color: Color(0xFF443337),
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactProfileGrid(
    List<Map<String, dynamic>> profiles, {
    required String scope,
  }) {
    if (profiles.isEmpty) return const SizedBox.shrink();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: profiles.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.66,
      ),
      itemBuilder: (context, index) {
        return _buildCompactProfileCard(
          profiles[index],
          photoHeroScope: '$scope:$index',
        );
      },
    );
  }

  Widget _buildCompactProfileCard(
    Map<String, dynamic> profile, {
    String? photoHeroScope,
  }) {
    final data = _cardData(profile);
    final photoHeroTag = ProfilePhotoHero.tagFor(
      profileId: data.profileId,
      scope: photoHeroScope,
      photoUrl: data.photoUrl,
    );
    final detailLine = _joinNonEmpty([
      data.ageShortLabel,
      data.locationLabel,
      data.communityLabel,
    ]);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openProfile(profile, photoHeroTag: photoHeroTag),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  data.photoUrl != null
                      ? ProfilePhotoHero(
                          tag: photoHeroTag,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(18),
                          ),
                          child: ProfileNetworkImage(
                            url: data.photoUrl!,
                            placeholder: _buildCompactPhotoFallback(),
                            // Two columns with 12 between them.
                            decodeWidth:
                                (MediaQuery.sizeOf(context).width - 12) / 2,
                          ),
                        )
                      : _buildCompactPhotoFallback(),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0x99000000)],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: 9,
                    child: Text(
                      data.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    detailLine ?? AppStrings.noInformation,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey.shade800,
                      fontSize: 12,
                      height: 1.22,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildMiniInterestButton(profile, data),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A recent visitor the plan has not revealed. The photo fills the top of the
  /// tile so the blurred person reads as a person, the server's headline sits
  /// on the scrim as the loudest thing on the card, and the curiosity pills and
  /// the single call to action stack underneath. Nothing here is invented — the
  /// tile only ever draws keys the server sent, and it never routes into the
  /// hidden profile.
  Widget _buildRecentVisitorTeaserCard(Map<String, dynamic> rawTeaser) {
    final teaser = LockedTeaser.fromJson(rawTeaser) ?? const LockedTeaser();
    final headline = teaser.headline ?? appText.lockedVisitor;
    final summary = teaser.viewedSummary;
    void openUpgrade() => _showSnackBar(AppStrings.upgradeToSeeVisitors);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: openUpgrade,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: LockedTeaserPhotoFrame(
                teaser: teaser,
                cornerRadius: 0,
                scrim: true,
                lockAlignment: Alignment.topRight,
                topStartOverlay: summary == null
                    ? null
                    : LockedTeaserGlassChip(label: summary),
                bottomOverlay: LockedTeaserHeadline(
                  text: headline,
                  onPhoto: true,
                  fontSize: 14.5,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LockedTeaserLines(
                    teaser: teaser,
                    attributeMaxLines: 1,
                    attributeFontSize: 11.5,
                    showSummary: false,
                    compactAccent: true,
                  ),
                  const SizedBox(height: 9),
                  LockedTeaserUnlockButton(
                    label: AppStrings.upgrade,
                    dense: true,
                    expand: true,
                    onPressed: openUpgrade,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactPhotoFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFEE2E2), Color(0xFFDC2626)],
        ),
      ),
      child: const Icon(Icons.person, color: Colors.white, size: 46),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF2E2528),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalProfileCarousel(
    List<Map<String, dynamic>> profiles, {
    required String scope,
  }) {
    if (profiles.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 228,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: profiles.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return _buildCarouselProfileCard(
            profiles[index],
            photoHeroScope: '$scope:$index',
          );
        },
      ),
    );
  }

  Widget _buildCarouselProfileCard(
    Map<String, dynamic> profile, {
    String? photoHeroScope,
  }) {
    final data = _cardData(profile);
    final photoHeroTag = ProfilePhotoHero.tagFor(
      profileId: data.profileId,
      scope: photoHeroScope,
      photoUrl: data.photoUrl,
    );
    final details = _joinNonEmpty([
      data.ageShortLabel,
      data.heightLabel,
      data.communityLabel,
    ]);

    return SizedBox(
      width: 164,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openProfile(profile, photoHeroTag: photoHeroTag),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 118,
                child: data.photoUrl != null
                    ? ProfilePhotoHero(
                        tag: photoHeroTag,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(18),
                        ),
                        child: ProfileNetworkImage(
                          url: data.photoUrl!,
                          placeholder: _buildCompactPhotoFallback(),
                          decodeWidth: 164,
                        ),
                      )
                    : _buildCompactPhotoFallback(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF2E2528),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      details ?? AppStrings.noInformation,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 11.5,
                        height: 1.18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildMiniInterestButton(profile, data),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentlyViewedStrip(
    List<Map<String, dynamic>> profiles, {
    required String scope,
  }) {
    if (profiles.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 184,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: profiles.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final profile = profiles[index];
          final viewedAt = _displayString(profile['viewed_at_human']);
          return _buildViewedProfileCard(
            profile,
            viewedAt,
            photoHeroScope: '$scope:$index',
          );
        },
      ),
    );
  }

  Widget _buildViewedProfileCard(
    Map<String, dynamic> profile,
    String? viewedAt, {
    String? photoHeroScope,
  }) {
    final data = _cardData(profile);
    final photoHeroTag = ProfilePhotoHero.tagFor(
      profileId: data.profileId,
      scope: photoHeroScope,
      photoUrl: data.photoUrl,
    );

    return SizedBox(
      width: 148,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openProfile(profile, photoHeroTag: photoHeroTag),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFECDDD8)),
          ),
          child: Column(
            children: [
              _buildCircularPhoto(data.photoUrl, 58, heroTag: photoHeroTag),
              const SizedBox(height: 8),
              Text(
                data.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 3),
              Text(
                _joinNonEmpty([data.ageShortLabel, data.locationLabel]) ??
                    AppStrings.noInformation,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 11),
              ),
              const Spacer(),
              Text(
                viewedAt ??
                    (appText.viewedRecently),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _BrowseProfilesScreenState._brandDark,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMatchingPreferenceLayout(
    List<Map<String, dynamic>> profiles, {
    required String scope,
  }) {
    if (profiles.isEmpty) return const SizedBox.shrink();

    final featured = profiles.first;
    final rest = profiles.skip(1).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFeaturedPreferenceCard(
          featured,
          photoHeroScope: '$scope:featured',
        ),
        if (rest.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildCompactProfileGrid(rest, scope: '$scope:rest'),
        ],
      ],
    );
  }

  Widget _buildFeaturedPreferenceCard(
    Map<String, dynamic> profile, {
    String? photoHeroScope,
  }) {
    final data = _cardData(profile);
    final photoHeroTag = ProfilePhotoHero.tagFor(
      profileId: data.profileId,
      scope: photoHeroScope,
      photoUrl: data.photoUrl,
    );
    final detailLine = _joinNonEmpty([
      data.ageShortLabel,
      data.heightLabel,
      data.communityLabel,
    ]);
    final workLine = _joinNonEmpty([data.educationLabel, data.occupationLabel]);

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _openProfile(profile, photoHeroTag: photoHeroTag),
      child: Container(
        height: 164,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _brandColor.withValues(alpha: 0.14)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(20),
              ),
              child: SizedBox(
                width: 122,
                height: double.infinity,
                child: data.photoUrl != null
                    ? ProfilePhotoHero(
                        tag: photoHeroTag,
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(20),
                        ),
                        child: ProfileNetworkImage(
                          url: data.photoUrl!,
                          placeholder: _buildCompactPhotoFallback(),
                          decodeWidth: 122,
                        ),
                      )
                    : _buildCompactPhotoFallback(),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF2E2528),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    if (detailLine != null)
                      Text(
                        detailLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    if (workLine != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        workLine,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                          height: 1.18,
                        ),
                      ),
                    ],
                    const Spacer(),
                    _buildMiniInterestButton(profile, data),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNearbyProfileStrip(
    List<Map<String, dynamic>> profiles, {
    required String scope,
  }) {
    if (profiles.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 172,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: profiles.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          return _buildNearbyProfileCard(
            profiles[index],
            photoHeroScope: '$scope:$index',
          );
        },
      ),
    );
  }

  Widget _buildNearbyProfileCard(
    Map<String, dynamic> profile, {
    String? photoHeroScope,
  }) {
    final data = _cardData(profile);
    final photoHeroTag = ProfilePhotoHero.tagFor(
      profileId: data.profileId,
      scope: photoHeroScope,
      photoUrl: data.photoUrl,
    );

    return SizedBox(
      width: 196,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openProfile(profile, photoHeroTag: photoHeroTag),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _brandColor.withValues(alpha: 0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildCircularPhoto(data.photoUrl, 50, heroTag: photoHeroTag),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      data.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF2E2528),
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.place_outlined,
                    color: _BrowseProfilesScreenState._brandColor,
                    size: 17,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      data.locationLabel ?? AppStrings.chooseLocationFilter,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade800,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        height: 1.18,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildMiniInterestButton(profile, data),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniCarousel(
    List<Map<String, dynamic>> profiles, {
    required String scope,
  }) {
    final suggestions = profiles.take(5).toList();
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 154,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: suggestions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final profile = suggestions[index];
          final data = _cardData(profile);
          final photoHeroTag = ProfilePhotoHero.tagFor(
            profileId: data.profileId,
            scope: '$scope:$index',
            photoUrl: data.photoUrl,
          );
          return InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _openProfile(profile, photoHeroTag: photoHeroTag),
            child: Container(
              width: 126,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFECDDD8)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildCircularPhoto(data.photoUrl, 54, heroTag: photoHeroTag),
                  const SizedBox(height: 8),
                  Text(
                    data.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _joinNonEmpty([data.ageShortLabel, data.heightLabel]) ??
                        AppStrings.noInformation,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                  ),
                  const Spacer(),
                  _buildMiniInterestButton(profile, data),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMatchCard(
    Map<String, dynamic> profile, {
    double? height,
    EdgeInsetsGeometry margin = const EdgeInsets.only(bottom: 18),
    bool showActionStrip = true,
    String? photoHeroScope,
  }) {
    final data = _cardData(profile);
    final photoHeroTag = ProfilePhotoHero.tagFor(
      profileId: data.profileId,
      scope: photoHeroScope,
      photoUrl: data.photoUrl,
    );
    final cardHeight =
        height ??
        (MediaQuery.sizeOf(context).height * 0.58)
            .clamp(390.0, 520.0)
            .toDouble();

    return Container(
      margin: margin,
      height: cardHeight,
      decoration: BoxDecoration(
        // The card owns an opaque fill so the page background can never show
        // through while the photo loads. Same tone as the app's skeletons.
        color: const Color(0xFFF2E7E2),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openProfile(profile, photoHeroTag: photoHeroTag),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildCardPhoto(data, photoHeroTag),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x20000000),
                      Color(0x00000000),
                      Color(0xD9000000),
                    ],
                    stops: [0, 0.43, 1],
                  ),
                ),
              ),
              Positioned(
                top: 14,
                left: 14,
                right: 14,
                child: _buildTopBadges(data),
              ),
              Positioned(
                left: 18,
                right: 18,
                bottom: 18,
                child: _buildCardOverlay(
                  profile,
                  data,
                  showActionStrip: showActionStrip,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardPhoto(_MatchCardData data, String? heroTag) {
    if (data.photoUrl == null) {
      return _buildPhotoPlaceholder();
    }

    return ProfilePhotoHero(
      tag: heroTag,
      borderRadius: BorderRadius.circular(22),
      child: ProfileNetworkImage(
        url: data.photoUrl!,
        placeholder: _buildPhotoPlaceholder(),
        decodeWidth: MediaQuery.sizeOf(context).width,
        onError: () {
          final failedUrl = data.photoUrl;
          if (failedUrl != null && !_failedPhotoUrls.contains(failedUrl)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                _failedPhotoUrls.add(failedUrl);
              });
            });
          }
        },
      ),
    );
  }

  Widget _buildPhotoPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFEE2E2), Color(0xFFDC2626)],
        ),
      ),
      child: Center(
        child: Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.20),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white54, width: 1.4),
          ),
          child: const Icon(Icons.person, color: Colors.white, size: 52),
        ),
      ),
    );
  }

  Widget _buildTopBadges(_MatchCardData data) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (data.premium)
          _buildGlassBadge(
            appText.biodataTemplatePremium,
            Icons.workspace_premium,
            _premiumGold,
          ),
        const Spacer(),
        if (data.verified) _buildGlassIcon(Icons.verified, _trustGreen),
        if (data.photoUrl != null && data.photoCount > 0) ...[
          const SizedBox(width: 8),
          _buildGlassBadge('${data.photoCount}', Icons.photo_library, null),
        ],
        // No overflow-menu icon here: there is no card-level menu to open, and
        // a kebab that does nothing promises an action the card cannot deliver.
      ],
    );
  }

  Widget _buildGlassBadge(String label, IconData icon, Color? accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: accent ?? Colors.white, size: 15),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassIcon(IconData icon, Color color) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.38),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildCardOverlay(
    Map<String, dynamic> profile,
    _MatchCardData data, {
    bool showActionStrip = true,
  }) {
    final communityLine = _joinNonEmpty([
      data.heightLabel,
      data.communityLabel,
    ]);
    final workLine = _joinNonEmpty([data.occupationLabel, data.educationLabel]);
    final chips = _statusChips(data);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          data.titleLine,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 8),
        if (communityLine != null)
          _buildOverlayLine(communityLine, fontWeight: FontWeight.w800),
        if (workLine != null) _buildOverlayLine(workLine),
        if (data.locationLabel != null)
          _buildOverlayLine(data.locationLabel!, icon: Icons.place),
        if (chips.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: chips),
        ],
        if (showActionStrip) ...[
          const SizedBox(height: 14),
          _buildCardActionStrip(profile, data),
        ],
      ],
    );
  }

  Widget _buildOverlayLine(
    String text, {
    IconData? icon,
    FontWeight fontWeight = FontWeight.w600,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white.withValues(alpha: 0.88), size: 16),
            const SizedBox(width: 5),
          ],
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.94),
                fontWeight: fontWeight,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _statusChips(_MatchCardData data) {
    return [
      if (data.comparisonLabel != null)
        _buildStatusChip(
          AppStrings.comparisonLabel(data.comparisonLabel!),
          Icons.compare_arrows,
          _brandColor,
        ),
      // Verified is not repeated here — the tick badge at the top of the card
      // already carries it.
      if (data.hasAstro)
        _buildStatusChip(appText.astro, Icons.auto_awesome, _premiumGold),
      if (data.premium)
        _buildStatusChip(
          appText.biodataTemplatePremium,
          Icons.workspace_premium,
          _premiumGold,
        ),
    ];
  }

  Widget _buildStatusChip(String label, IconData icon, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: accent, size: 15),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardActionStrip(
    Map<String, dynamic> profile,
    _MatchCardData data,
  ) {
    final canSend = _canSendInterest(profile);
    final sent = _interestSent(profile);
    final busy =
        data.profileId != null && _sendingInterestIds.contains(data.profileId);
    final ctaLabel = sent ? AppStrings.interestSent : AppStrings.sendInterest;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 7, 8, 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _brandSoft.withValues(alpha: 0.85)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: canSend && !busy
                  ? () => _sendInterestFromCard(profile)
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppStrings.likeThisProfile,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      ctaLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: sent ? _brandDark : _brandColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _buildRoundInterestButton(profile, canSend && !busy, sent, busy),
        ],
      ),
    );
  }

  Widget _buildRoundInterestButton(
    Map<String, dynamic> profile,
    bool enabled,
    bool sent,
    bool busy,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: enabled ? () => _sendInterestFromCard(profile) : null,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: enabled
              ? const LinearGradient(
                  colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: enabled ? null : (sent ? _brandSoft : const Color(0xFFF1E4E1)),
        ),
        child: Center(
          child: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Icon(
                  sent ? Icons.check : Icons.favorite,
                  color: sent ? _brandColor : Colors.white,
                  size: 24,
                ),
        ),
      ),
    );
  }

  Widget _buildMiniInterestButton(
    Map<String, dynamic> profile,
    _MatchCardData data,
  ) {
    final canSend = _canSendInterest(profile);
    final sent = _interestSent(profile);
    final busy =
        data.profileId != null && _sendingInterestIds.contains(data.profileId);

    return SizedBox(
      height: 28,
      child: OutlinedButton.icon(
        onPressed: canSend && !busy
            ? () => _sendInterestFromCard(profile)
            : null,
        icon: busy
            ? const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(sent ? Icons.check : Icons.favorite_border, size: 13),
        label: Text(
          sent ? AppStrings.interestSent : AppStrings.sendInterest,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: sent ? Colors.grey.shade600 : _brandColor,
          side: BorderSide(
            color: sent
                ? Colors.grey.shade300
                : _brandColor.withValues(alpha: 0.45),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _buildCircularPhoto(String? photoUrl, double size, {String? heroTag}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _brandColor.withValues(alpha: 0.20)),
      ),
      child: ClipOval(
        child: photoUrl != null
            ? ProfilePhotoHero(
                tag: heroTag,
                // The flight is drawn outside this ClipOval, so the round shape
                // has to travel with it — otherwise the avatar would snap
                // square the moment it lifted off.
                borderRadius: BorderRadius.circular(size / 2),
                child: ProfileNetworkImage(
                  url: photoUrl,
                  placeholder: _buildCircleFallback(),
                  decodeWidth: size,
                ),
              )
            : _buildCircleFallback(),
      ),
    );
  }

  Widget _buildCircleFallback() {
    return Container(
      color: const Color(0xFFF1DDD8),
      child: const Icon(
        Icons.person,
        color: _BrowseProfilesScreenState._brandColor,
      ),
    );
  }

  Future<void> _openProfile(
    Map<String, dynamic> profile, {
    String? photoHeroTag,
  }) async {
    final profileId = _displayInt(profile['id']);
    if (profileId == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileDetailScreen(
          profileId: profileId,
          profileIds: _visibleProfileIds(),
          initialProfile: profile,
          photoHeroTag: photoHeroTag,
        ),
      ),
    );
    if (!mounted) return;
    _handleProfileDetailResult(result);
  }

  List<int> _visibleProfileIds() {
    final ids = <int>[];

    void addProfileId(dynamic rawProfile) {
      final row = _safeMap(rawProfile);
      final id = _displayInt(row?['id']);
      if (id != null && !ids.contains(id)) {
        ids.add(id);
      }
    }

    for (final profile in _profiles) {
      addProfileId(profile);
    }

    for (final section in _moreSections) {
      for (final profile in _sectionProfiles(section)) {
        addProfileId(profile);
      }

      final rows = section['rows'];
      if (rows is List) {
        for (final rawRow in rows) {
          final row = _safeMap(rawRow);
          if (_displayString(row?['mode']) == 'profile') {
            addProfileId(row?['profile']);
          }
        }
      }
    }

    return ids;
  }

  Future<bool> _sendInterestFromCard(Map<String, dynamic> profile) async {
    final profileId = _displayInt(profile['id']);
    if (profileId == null || _sendingInterestIds.contains(profileId)) {
      return false;
    }

    if (!_canSendInterest(profile)) {
      _showSnackBar(
        _interestSent(profile)
            ? appText.interestAlreadySent
            : appText.cannotSendInterestForThisProfile,
      );
      return _interestSent(profile);
    }

    setState(() {
      _sendingInterestIds.add(profileId);
    });

    try {
      final response = await ApiClient.sendInterest(profileId);
      if (!mounted) return false;

      final statusCode = _displayInt(response['statusCode']);
      final success =
          _displayBool(response['success']) == true ||
          statusCode == 200 ||
          statusCode == 409;

      if (success) {
        _markInterestSent(profileId);
        _showSnackBar(AppStrings.interestSent);
        return true;
      } else {
        _showSnackBar(
          _displayString(response['message']) ??
              appText.couldNotSendInterest,
        );
        return false;
      }
    } catch (_) {
      if (!mounted) return false;
      _showSnackBar(appText.couldNotSendInterest);
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _sendingInterestIds.remove(profileId);
        });
      }
    }
  }

  void _markInterestSent(int profileId) {
    setState(() {
      _profiles = _profiles
          .map((profile) => _markInterestSentInRow(profile, profileId))
          .toList();
      _moreSections = _moreSections.map((section) {
        final profiles = section['profiles'];
        if (profiles is List) {
          section['profiles'] = profiles
              .map((profile) => _markInterestSentInRow(profile, profileId))
              .toList();
        }
        final rows = section['rows'];
        if (rows is List) {
          section['rows'] = rows.map((rawRow) {
            final row = _safeMap(rawRow);
            if (row == null || _displayString(row['mode']) != 'profile') {
              return rawRow;
            }
            row['profile'] = _markInterestSentInRow(row['profile'], profileId);
            return row;
          }).toList();
        }
        return section;
      }).toList();
    });
  }

  dynamic _markInterestSentInRow(dynamic profile, int profileId) {
    final row = _safeMap(profile);
    if (row == null || _displayInt(row['id']) != profileId) {
      return profile;
    }

    final display = _safeMap(row['display']) ?? <String, dynamic>{};
    final actions = _safeMap(display['actions']) ?? <String, dynamic>{};
    actions['interest_sent'] = true;
    actions['can_send_interest'] = false;
    display['actions'] = actions;
    row['display'] = display;
    return row;
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _handleProfileDetailResult(dynamic result) {
    final actionResult = _safeMap(result);
    if (actionResult == null) return;

    final profileId = _displayInt(actionResult['profileId']);
    final action = _displayString(actionResult['action']);
    if (profileId == null || (action != 'hidden' && action != 'blocked')) {
      return;
    }

    setState(() {
      _profiles = _profiles.where((profile) {
        final row = _safeMap(profile);
        return _displayInt(row?['id']) != profileId;
      }).toList();
    });
  }

  List<Map<String, dynamic>> _profileRows() {
    final rows = _profiles
        .map(_safeMap)
        .whereType<Map<String, dynamic>>()
        .toList();
    if (_selectedTabIndex != _tabSearch || !_filters.hasActiveFilters) {
      return rows;
    }

    return rows.where(_matchesVisibleFilters).toList();
  }

  List<Map<String, dynamic>> _recommendationProfiles() {
    return _profileRows().where(_hasRecommendationPhoto).take(13).toList();
  }

  bool _matchesVisibleFilters(Map<String, dynamic> profile) {
    final data = _cardData(profile);

    if (_filters.heightFromCm != null || _filters.heightToCm != null) {
      final heightCm = _heightCmFromProfile(profile, data.heightLabel);
      if (heightCm != null) {
        if (_filters.heightFromCm != null &&
            heightCm < _filters.heightFromCm!) {
          return false;
        }
        if (_filters.heightToCm != null && heightCm > _filters.heightToCm!) {
          return false;
        }
      }
    }

    if (_filters.photoAvailable &&
        data.photoUrl == null &&
        data.photoCount <= 0) {
      return false;
    }

    if (_filters.verifiedPhoto && !data.verified) {
      return false;
    }

    if (!_labelMatches(data.educationLabel, _filters.educationLabel)) {
      return false;
    }

    if (!_labelMatches(data.occupationLabel, _filters.occupationLabel)) {
      return false;
    }

    if (!_labelMatches(
      _profileMaritalStatusLabel(profile),
      _filters.maritalStatusLabel,
    )) {
      return false;
    }

    if (_filters.recentlyActive && !_profileLooksRecentlyActive(profile)) {
      return false;
    }

    return true;
  }

  bool _labelMatches(String? source, String? selected) {
    final selectedText = selected?.trim().toLowerCase();
    if (selectedText == null || selectedText.isEmpty) return true;

    final sourceText = source?.trim().toLowerCase();
    if (sourceText == null || sourceText.isEmpty) return true;
    return sourceText.contains(selectedText) ||
        selectedText.contains(sourceText);
  }

  int? _heightCmFromProfile(Map<String, dynamic> profile, String? label) {
    for (final key in ['height_cm', 'height_in_cm']) {
      final value = _displayInt(profile[key]);
      if (value != null && value > 0) return value;
    }

    final text = label ?? _displayString(profile['height']);
    if (text == null) return null;

    final cmMatch = RegExp(
      r'(\d{2,3})\s*cm',
      caseSensitive: false,
    ).firstMatch(text);
    if (cmMatch != null) return int.tryParse(cmMatch.group(1)!);

    final feetMatch = RegExp(r"(\d)\s*'\s*(\d{1,2})").firstMatch(text);
    if (feetMatch != null) {
      final feet = int.tryParse(feetMatch.group(1)!);
      final inches = int.tryParse(feetMatch.group(2)!);
      if (feet != null && inches != null) {
        return ((feet * 12 + inches) * 2.54).round();
      }
    }

    return null;
  }

  String? _profileMaritalStatusLabel(Map<String, dynamic> profile) {
    return ApiClient.safeDisplayLabel(profile['marital_status_label']) ??
        ApiClient.safeDisplayLabel(profile['marital_status']) ??
        ApiClient.safeDisplayLabel(profile['marital_status_key']);
  }

  bool _profileLooksRecentlyActive(Map<String, dynamic> profile) {
    final display = _safeMap(profile['display']);
    final card = _safeMap(display?['card']) ?? _safeMap(display?['hero']);
    final explicit =
        _displayBool(card?['recently_active']) ??
        _displayBool(profile['recently_active']) ??
        _displayBool(profile['is_recently_active']);
    if (explicit != null) return explicit;

    final activityLabel =
        _displayString(card?['activity_label']) ??
        _displayString(profile['activity_label']) ??
        _displayString(profile['last_active_label']);
    if (activityLabel == null) return true;

    final normalized = activityLabel.toLowerCase();
    return normalized.contains('today') ||
        normalized.contains('yesterday') ||
        normalized.contains('recent') ||
        normalized.contains('आज') ||
        normalized.contains('काल') ||
        normalized.contains('active');
  }

  bool _hasRecommendationPhoto(Map<String, dynamic> profile) {
    final display = _safeMap(profile['display']);
    final card = _safeMap(display?['card']) ?? _safeMap(display?['hero']);
    final primaryPhotoUrl = ApiClient.normalizeProfilePhotoUrl(
      _displayString(card?['primary_photo_url']),
    );
    final resolvedPhotoUrl =
        primaryPhotoUrl ?? ApiClient.resolveProfilePhotoUrl(profile);

    return resolvedPhotoUrl != null &&
        !_failedPhotoUrls.contains(resolvedPhotoUrl);
  }

  _MatchCardData _cardData(Map<String, dynamic> profile) {
    final display = _safeMap(profile['display']);
    final card = _safeMap(display?['card']) ?? _safeMap(display?['hero']);

    final age =
        _displayInt(card?['age']) ??
        _calculateAge(_displayString(profile['date_of_birth']));
    final ageLabel =
        _displayString(card?['age_label']) ??
        (age != null ? AppStrings.years(age) : null);
    final name =
        _displayString(card?['name']) ??
        ApiClient.safeDisplayLabel(profile['full_name']) ??
        ApiClient.safeDisplayLabel(profile['name']) ??
        appText.nameNotAvailable;
    final primaryPhotoUrl = ApiClient.normalizeProfilePhotoUrl(
      _displayString(card?['primary_photo_url']),
    );
    final resolvedPhotoUrl =
        primaryPhotoUrl ?? ApiClient.resolveProfilePhotoUrl(profile);
    final photoUrl =
        resolvedPhotoUrl != null && _failedPhotoUrls.contains(resolvedPhotoUrl)
        ? null
        : resolvedPhotoUrl;
    final heightLabel =
        _displayString(card?['height_label']) ??
        ApiClient.profileHeightLabel(profile);
    final communityLabel =
        _displayString(card?['community_label']) ??
        ApiClient.profileCommunityLabel(profile);
    final educationLabel =
        _displayString(card?['education_label']) ??
        ApiClient.profileEducationLabel(profile);
    final occupationLabel =
        _displayString(card?['occupation_label']) ??
        ApiClient.profileOccupationLabel(profile);
    final locationLabel =
        _displayString(card?['location_label']) ??
        ApiClient.profileLocationLabel(profile, allowIdFallback: false);
    final rawPhotoCount = _displayInt(card?['photo_count']) ?? 0;
    final photoCount = photoUrl == null ? 0 : rawPhotoCount;

    return _MatchCardData(
      profileId: _displayInt(profile['id']),
      name: name,
      age: age,
      ageLabel: ageLabel,
      photoUrl: photoUrl,
      heightLabel: heightLabel,
      communityLabel: communityLabel,
      educationLabel: educationLabel,
      occupationLabel: occupationLabel,
      locationLabel: locationLabel,
      verified: _displayBool(card?['verified']) == true,
      premium: _displayBool(card?['premium']) == true,
      photoCount: photoCount,
      comparisonLabel: _displayString(card?['comparison_label']),
      hasAstro: _displayBool(card?['has_astro']) == true,
    );
  }

  Map<String, dynamic>? _displayActions(Map<String, dynamic> profile) {
    final display = _safeMap(profile['display']);
    return _safeMap(display?['actions']);
  }

  bool _interestSent(Map<String, dynamic> profile) {
    final actions = _displayActions(profile);
    final profileId = _displayInt(profile['id']);
    return _displayBool(actions?['interest_sent']) == true ||
        _displayBool(actions?['is_interested']) == true ||
        (profileId != null &&
            ApiClient.sentInterestProfileIds.contains(profileId));
  }

  bool _canSendInterest(Map<String, dynamic> profile) {
    if (_interestSent(profile)) return false;

    final actions = _displayActions(profile);
    final explicit = _displayBool(actions?['can_send_interest']);
    return explicit ?? true;
  }

  Map<String, dynamic>? _safeMap(dynamic value) {
    if (value is! Map) return null;
    try {
      return Map<String, dynamic>.from(value);
    } catch (_) {
      return null;
    }
  }

  String? _displayString(dynamic value) {
    if (value == null) return null;
    if (value is Map || value is List) return null;
    if (value is bool) return value ? appText.yes : appText.no;

    final text = value.toString().trim();
    if (text.isEmpty) return null;
    if (text.startsWith('{') || text.startsWith('[')) return null;
    if (text.contains('=>')) return null;
    if (text.toLowerCase().startsWith('location id:')) return null;

    return text;
  }

  int? _displayInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  bool? _displayBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value == 1;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (['true', '1', 'yes'].contains(normalized)) return true;
      if (['false', '0', 'no'].contains(normalized)) return false;
    }
    return null;
  }

  String _emptyProfilesMessage({bool prefixIcon = false}) {
    final message = appText.noProfilesFoundTryReducingFilters;
    return prefixIcon ? '❌ $message' : message;
  }

  String? _targetGender() {
    final fromContext = _normalizeGender(_viewerContext?['target_gender']);
    if (fromContext != null) return fromContext;

    final userProfile = ApiClient.currentUserProfile;
    final viewerGender = _normalizeGender(
      userProfile?['gender'] ??
          userProfile?['gender_key'] ??
          userProfile?['profile_gender'],
    );

    return switch (viewerGender) {
      'male' => 'female',
      'female' => 'male',
      _ => null,
    };
  }

  String? _normalizeGender(dynamic value) {
    final text = value?.toString().trim().toLowerCase();
    if (text == null || text.isEmpty) return null;
    if (text.contains('female') || text.contains('स्त्री')) return 'female';
    if (text.contains('male') || text.contains('पुरुष')) return 'male';
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
}

class _MatchCardData {
  const _MatchCardData({
    required this.profileId,
    required this.name,
    required this.age,
    required this.ageLabel,
    required this.photoUrl,
    required this.heightLabel,
    required this.communityLabel,
    required this.educationLabel,
    required this.occupationLabel,
    required this.locationLabel,
    required this.verified,
    required this.premium,
    required this.photoCount,
    required this.comparisonLabel,
    required this.hasAstro,
  });

  final int? profileId;
  final String name;
  final int? age;
  final String? ageLabel;
  final String? photoUrl;
  final String? heightLabel;
  final String? communityLabel;
  final String? educationLabel;
  final String? occupationLabel;
  final String? locationLabel;
  final bool verified;
  final bool premium;
  final int photoCount;
  final String? comparisonLabel;
  final bool hasAstro;

  String get titleLine {
    if (age != null) return '$name, $age';
    if (ageLabel != null) return '$name, $ageLabel';
    return name;
  }

  String? get ageShortLabel => age != null ? '$age' : ageLabel;
}
