import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api_client.dart';
import '../../core/app_strings.dart';
import 'widgets/profile_comparison_card.dart';
import 'widgets/profile_contact_card.dart';
import 'widgets/profile_display_section.dart';

/// ===============================
/// PROFILE DETAIL SCREEN (OTHER USER)
/// ===============================
class ProfileDetailScreen extends StatefulWidget {
  final int profileId;
  final List<int> profileIds;

  const ProfileDetailScreen({
    super.key,
    required this.profileId,
    this.profileIds = const <int>[],
  });

  @override
  State<ProfileDetailScreen> createState() => _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends State<ProfileDetailScreen> {
  static final Set<int> _openedProfileIds = <int>{};
  static final Set<int> _knownViewedProfileIds = <int>{};
  late int _currentProfileId;
  late List<int> _profileIds;
  late int _currentProfileIndex;
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _display;
  List<Map<String, dynamic>> _suggestedProfiles = <Map<String, dynamic>>[];
  bool _isLoading = true;
  bool _suggestedProfilesLoading = false;
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
  bool _isContactRevealInFlight = false;
  bool _isContactRequestInFlight = false;
  bool _showGunamilanDetails = false;
  bool _showScrolledStatusStrip = false;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _comparisonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _profileIds = _normalizedProfileIds(widget.profileIds, widget.profileId);
    _currentProfileIndex = _profileIds.indexOf(widget.profileId);
    if (_currentProfileIndex < 0) _currentProfileIndex = 0;
    _currentProfileId = _profileIds[_currentProfileIndex];
    _openedProfileIds.add(_currentProfileId);
    _scrollController.addListener(_handleHeroScroll);
    _fetchProfile();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleHeroScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleHeroScroll() {
    final shouldShow = _headerCollapseProgress() > 0.70;
    if (shouldShow == _showScrolledStatusStrip || !mounted) return;

    setState(() {
      _showScrolledStatusStrip = shouldShow;
    });
  }

  double _headerCollapseProgress() {
    if (!_scrollController.hasClients) return 0;

    return ((_scrollController.offset - 82) / 156).clamp(0.0, 1.0).toDouble();
  }

  double _lerpValue(double start, double end, double progress) {
    return start + ((end - start) * progress);
  }

  List<int> _normalizedProfileIds(List<int> ids, int initialProfileId) {
    final normalized = <int>[];
    for (final id in ids) {
      if (id > 0 && !normalized.contains(id)) {
        normalized.add(id);
      }
    }
    if (!normalized.contains(initialProfileId)) {
      normalized.insert(0, initialProfileId);
    }
    return normalized;
  }

  void _handleHorizontalProfileSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 260 || _profileIds.length < 2) return;

    if (velocity < 0) {
      _openAdjacentProfile(1);
    } else {
      _openAdjacentProfile(-1);
    }
  }

  void _openAdjacentProfile(int delta) {
    final nextIndex = _currentProfileIndex + delta;
    if (nextIndex < 0 || nextIndex >= _profileIds.length) return;

    setState(() {
      _currentProfileIndex = nextIndex;
      _currentProfileId = _profileIds[nextIndex];
      _openedProfileIds.add(_currentProfileId);
      _profile = null;
      _display = null;
      _suggestedProfiles = <Map<String, dynamic>>[];
      _errorMessage = null;
      _isLoading = true;
      _suggestedProfilesLoading = false;
      _isSendingInterest = false;
      _interestSent = false;
      _isShortlisted = false;
      _isHidden = false;
      _isBlocked = false;
      _canShortlist = null;
      _canHide = null;
      _canBlock = null;
      _isProfileActionInFlight = false;
      _isContactRevealInFlight = false;
      _isContactRequestInFlight = false;
      _showScrolledStatusStrip = false;
    });

    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final requestedProfileId = _currentProfileId;
    try {
      final response = await ApiClient.getProfileDetail(requestedProfileId);
      if (!mounted) return;
      if (requestedProfileId != _currentProfileId) return;

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
        _fetchSuggestedProfiles();
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

  Future<void> _fetchSuggestedProfiles() async {
    if (!mounted || _suggestedProfilesLoading) return;
    final requestedProfileId = _currentProfileId;

    setState(() {
      _suggestedProfilesLoading = true;
    });

    final suggestions = <Map<String, dynamic>>[];
    try {
      final sectionsResponse = await ApiClient.getMoreMatchSections();
      suggestions.addAll(_suggestedProfilesFromSections(sectionsResponse));

      if (suggestions.length < 6) {
        final listResponse = await ApiClient.getProfileList(feed: 'my_matches');
        suggestions.addAll(_safeMapList(listResponse['profiles']));
      }
    } catch (_) {
      // Suggestions are optional; the main profile must stay usable.
    }

    final filtered = _filterSuggestedProfiles(suggestions);
    if (!mounted) return;
    if (requestedProfileId != _currentProfileId) return;

    setState(() {
      _suggestedProfiles = filtered.take(6).toList(growable: false);
      _suggestedProfilesLoading = false;
    });
  }

  List<Map<String, dynamic>> _suggestedProfilesFromSections(
    Map<String, dynamic> response,
  ) {
    final sections = _safeMapList(response['sections']);
    const preferredKeys = <String>[
      'matching_my_preference',
      'you_may_like',
      'nearby',
      'looking_for_me',
    ];

    final rows = <Map<String, dynamic>>[];
    for (final section in sections) {
      final key = _displayString(section['key'])?.trim().toLowerCase();
      if (key != 'recently_viewed') continue;
      for (final profile in _safeMapList(section['profiles'])) {
        final id = _displayInt(profile['id']);
        if (id != null) _knownViewedProfileIds.add(id);
      }
    }

    for (final preferredKey in preferredKeys) {
      for (final section in sections) {
        final key = _displayString(section['key'])?.trim().toLowerCase();
        if (key != preferredKey) continue;
        rows.addAll(_safeMapList(section['profiles']));
      }
    }

    return rows;
  }

  List<Map<String, dynamic>> _filterSuggestedProfiles(
    List<Map<String, dynamic>> rows,
  ) {
    final seen = <int>{};
    final filtered = <Map<String, dynamic>>[];

    for (final row in rows) {
      final id = _displayInt(row['id']);
      if (id == null || id == _currentProfileId) continue;
      if (seen.contains(id) ||
          _openedProfileIds.contains(id) ||
          _knownViewedProfileIds.contains(id)) {
        continue;
      }
      if (_wasProfileAlreadyViewed(row)) continue;
      if (_suggestedPhotoUrl(row) == null) continue;

      seen.add(id);
      filtered.add(row);
      if (filtered.length >= 6) break;
    }

    return filtered;
  }

  bool _wasProfileAlreadyViewed(Map<String, dynamic> profile) {
    final viewedFields = <dynamic>[
      profile['viewed_at'],
      profile['viewed_at_human'],
      profile['last_viewed_at'],
      profile['profile_viewed_at'],
    ];

    for (final value in viewedFields) {
      if (_displayString(value) != null) return true;
    }

    final display = _safeMap(profile['display']);
    final actions = _safeMap(display?['actions']);
    return _displaySafeBool(actions?['viewed']) == true ||
        _displaySafeBool(actions?['is_viewed']) == true;
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
      final response = await ApiClient.sendInterest(_currentProfileId);
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
    return currentUserProfileId == null ||
        currentUserProfileId != viewingProfileId;
  }

  bool _canSendInterestNow() {
    final displayCanSend = _displayBool(
      _displayActions()?['can_send_interest'],
    );
    if (displayCanSend != null) {
      return displayCanSend && !_isInterestAlreadySent();
    }

    return !_isInterestAlreadySent();
  }

  bool _isInterestAlreadySent() {
    return ApiClient.sentInterestProfileIds.contains(_currentProfileId) ||
        _interestSent;
  }

  @override
  Widget build(BuildContext context) {
    final overlayStyle =
        (_showScrolledStatusStrip
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark)
            .copyWith(statusBarColor: Colors.transparent);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        backgroundColor: const Color(0xFFFAF7F5),
        body: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragEnd: _handleHorizontalProfileSwipe,
                child: _buildBody(),
              ),
            ),
            _buildScrolledStatusStrip(),
            _buildMovingHeroIdentity(),
            _buildFixedBackButton(),
          ],
        ),
        bottomNavigationBar: _buildBottomActionBar(),
      ),
    );
  }

  Widget _buildFixedBackButton() {
    return Positioned(
      top: 0,
      left: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 0, 0),
          child: _buildRoundIconButton(
            icon: Icons.arrow_back,
            tooltip: 'Back',
            onTap: () => Navigator.maybePop(context),
          ),
        ),
      ),
    );
  }

  Widget _buildScrolledStatusStrip() {
    final statusHeight = MediaQuery.of(context).padding.top;
    final profile = _profile;
    if (profile == null || _isLoading) {
      return const SizedBox.shrink();
    }
    final headerHeight = statusHeight + 58;
    final primary = Theme.of(context).colorScheme.primary;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        animation: _scrollController,
        builder: (context, child) {
          final progress = Curves.easeOutCubic.transform(
            _headerCollapseProgress(),
          );

          return IgnorePointer(
            ignoring: progress < 0.98,
            child: Opacity(
              opacity: progress,
              child: Transform.translate(
                offset: Offset(0, -18 * (1 - progress)),
                child: Container(
                  height: headerHeight,
                  decoration: BoxDecoration(
                    color: primary,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMovingHeroIdentity() {
    final profile = _profile;
    if (profile == null || _isLoading) {
      return const SizedBox.shrink();
    }

    final hero = _displayHero();
    final photoUrl =
        _displayString(hero?['primary_photo_url']) ??
        ApiClient.resolveProfilePhotoUrl(profile);
    final statusHeight = MediaQuery.of(context).padding.top;
    final heroHeight = _heroHeight(photoUrl != null);
    final screenWidth = MediaQuery.of(context).size.width;
    final age =
        _displayInt(hero?['age']) ??
        _calculateAge(profile['date_of_birth']?.toString());
    final name = _displayString(hero?['name']) ?? _nameText(profile);
    final heroName = age != null ? '$name, $age' : name;
    final heightLabel =
        _displayString(hero?['height_label']) ??
        ApiClient.profileHeightLabel(profile);
    final communityLabel =
        _displayString(hero?['community_label']) ?? _communityText(profile);
    final occupationLabel =
        _displayString(hero?['occupation_label']) ??
        ApiClient.profileOccupationLabel(profile);
    final location =
        _displayString(hero?['location_label']) ??
        ApiClient.profileLocationLabel(profile, allowIdFallback: false);
    final line1 = _joinNonEmpty([heightLabel, communityLabel]);
    final compactLine = line1 ?? location;
    final isVerified = _displayBool(hero?['verified']) ?? _isVerified(profile);
    final heroChips = _displayChips(
      profile,
      hasComparisonCard: _comparisonData() != null,
    );

    return AnimatedBuilder(
      animation: _scrollController,
      builder: (context, child) {
        final progress = Curves.easeOutCubic.transform(
          _headerCollapseProgress(),
        );
        final startTop = (statusHeight + heroHeight - 172)
            .clamp(statusHeight + 112, statusHeight + heroHeight - 92)
            .toDouble();
        final top = _lerpValue(startTop, statusHeight + 7, progress);
        final left = _lerpValue(16, 64, progress);
        final titleSize = _lerpValue(screenWidth < 360 ? 28 : 32, 18, progress);
        final subtitleSize = _lerpValue(15, 12.5, progress);
        final titleMaxLines = progress > 0.78 ? 1 : 2;
        final showHeroDetails = progress < 0.76;
        final detailsOpacity = (1 - ((progress - 0.18) / 0.58))
            .clamp(0.0, 1.0)
            .toDouble();

        return Positioned(
          top: top,
          left: left,
          right: 16,
          child: IgnorePointer(
            ignoring: progress > 0.82,
            child: DefaultTextStyle(
              style: const TextStyle(color: Colors.white),
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
                          maxLines: titleMaxLines,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: titleSize,
                            fontWeight: FontWeight.w800,
                            height: 1.08,
                          ),
                        ),
                      ),
                      if (isVerified) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.verified,
                          color: const Color(0xFF4DA3FF),
                          size: _lerpValue(24, 18, progress),
                        ),
                      ],
                    ],
                  ),
                  if (compactLine != null) ...[
                    SizedBox(height: _lerpValue(8, 3, progress)),
                    Text(
                      compactLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: subtitleSize,
                        fontWeight: FontWeight.w600,
                        height: 1.18,
                      ),
                    ),
                  ],
                  if (showHeroDetails && occupationLabel != null) ...[
                    const SizedBox(height: 5),
                    Opacity(
                      opacity: detailsOpacity,
                      child: Text(
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
                    ),
                  ],
                  if (showHeroDetails && location != null && line1 != null) ...[
                    const SizedBox(height: 5),
                    Opacity(
                      opacity: detailsOpacity,
                      child: Text(
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
                    ),
                  ],
                  if (showHeroDetails && heroChips.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Opacity(
                      opacity: detailsOpacity,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: heroChips,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
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
    final comparison = _comparisonData();
    final contact = _contactData();
    final gunamilan = _gunamilanMap();
    final displaySections = _displaySections();
    final photoUrl =
        _displayString(hero?['primary_photo_url']) ??
        ApiClient.resolveProfilePhotoUrl(profile);
    final galleryPhotos = _profileGalleryPhotos(profile, hero);
    final statusHeight = MediaQuery.of(context).padding.top;
    final heroHeight = _heroHeight(photoUrl != null);
    final location =
        _displayString(hero?['location_label']) ??
        ApiClient.profileLocationLabel(profile, allowIdFallback: false);
    final age =
        _displayInt(hero?['age']) ??
        _calculateAge(profile['date_of_birth']?.toString());
    final aboutBody = _displayString(about?['body']);
    final aboutTitle =
        _displayString(about?['title']) ??
        'About ${_displayString(hero?['name']) ?? _nameText(profile)}';

    return Stack(
      children: [
        Positioned(
          top: statusHeight,
          left: 0,
          right: 0,
          height: heroHeight,
          child: _buildHeroPhoto(photoUrl: photoUrl),
        ),
        ListView(
          controller: _scrollController,
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: galleryPhotos.isEmpty ? null : _openPhotoGallery,
              child: SizedBox(height: statusHeight + heroHeight - 18),
            ),
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFFFAF7F5),
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              padding: EdgeInsets.fromLTRB(16, 24, 16, _bottomContentPadding()),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (aboutBody != null) ...[
                    _buildAboutCard(aboutTitle, aboutBody),
                    const SizedBox(height: 4),
                  ],
                  if (displaySections.isNotEmpty)
                    ..._buildDisplaySectionsWithContact(
                      displaySections,
                      contact,
                    )
                  else ...[
                    if (contact != null) _buildContactCard(contact),
                    ..._buildFallbackProfileDetails(profile, age, location),
                  ],
                  if (gunamilan != null) _buildGunamilanCard(gunamilan),
                  if (comparison != null)
                    KeyedSubtree(
                      key: _comparisonKey,
                      child: ProfileComparisonCard(comparison: comparison),
                    ),
                  if (_suggestedProfiles.isNotEmpty)
                    _buildSuggestedProfilesSection(),
                ],
              ),
            ),
          ],
        ),
        _buildHeroTopActions(
          profile: profile,
          hero: hero,
          galleryPhotos: galleryPhotos,
        ),
      ],
    );
  }

  double _heroHeight(bool hasPhoto) {
    final screenHeight = MediaQuery.of(context).size.height;
    return (screenHeight * (hasPhoto ? 0.64 : 0.42))
        .clamp(hasPhoto ? 440.0 : 300.0, hasPhoto ? 640.0 : 420.0)
        .toDouble();
  }

  Widget _buildHeroPhoto({required String? photoUrl}) {
    final hasPhoto = photoUrl != null;
    final heroHeight = _heroHeight(hasPhoto);

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
        ],
      ),
    );
  }

  Widget _buildHeroTopActions({
    required Map<String, dynamic> profile,
    required Map<String, dynamic>? hero,
    required List<_ProfilePhotoItem> galleryPhotos,
  }) {
    final statusHeight = MediaQuery.of(context).padding.top;
    final photoUrl =
        _displayString(hero?['primary_photo_url']) ??
        ApiClient.resolveProfilePhotoUrl(profile);
    final photoCount =
        _displayInt(hero?['photo_count']) ??
        (galleryPhotos.isNotEmpty
            ? galleryPhotos.length
            : _photoCount(profile, photoUrl));
    final isPremium =
        _displaySafeBool(hero?['premium']) ??
        (hero == null ? _isPremium(profile) : false);

    return Positioned(
      top: statusHeight + 8,
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        animation: _scrollController,
        builder: (context, child) {
          final progress = _headerCollapseProgress();
          final opacity = (1 - progress).clamp(0.0, 1.0).toDouble();

          return IgnorePointer(
            ignoring: opacity < 0.08,
            child: Opacity(opacity: opacity, child: child),
          );
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(72, 0, 12, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
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
                  onTap: _openPhotoGallery,
                ),
                const SizedBox(width: 8),
              ],
              _buildMoreMenu(),
            ],
          ),
        ),
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
          colors: [Color(0xFFB53B61), Color(0xFF7D1538), Color(0xFF2E2220)],
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

          items.addAll(const [
            PopupMenuDivider(),
            PopupMenuItem(
              value: 'report',
              child: ListTile(
                dense: true,
                leading: Icon(Icons.flag_outlined),
                title: Text('Report this Profile'),
              ),
            ),
          ]);

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

    final currentUserProfileId = _displayInt(
      ApiClient.currentUserProfile?['id'],
    );
    final viewingProfileId = _displayInt(profile['id']) ?? _currentProfileId;
    return currentUserProfileId != null &&
        currentUserProfileId == viewingProfileId;
  }

  Widget _buildStatusPill({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
        ),
      ),
    );
  }

  void _openPhotoGallery() {
    final profile = _profile;
    if (profile == null) return;

    final photos = _profileGalleryPhotos(profile, _displayHero());
    if (photos.isEmpty) {
      _showSnackBar('फोटो उपलब्ध नाही.', Colors.black87);
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (routeContext) {
          return _ProfilePhotoGalleryViewer(
            photos: photos,
            title: _galleryTitle(profile),
            subtitle: _gallerySubtitle(profile),
            onMenuAction: (action) async {
              if (action == 'share') {
                await _shareProfile();
              } else if (action == 'report') {
                await _reportProfile();
              }
            },
          );
        },
      ),
    );
  }

  String _galleryTitle(Map<String, dynamic> profile) {
    final hero = _displayHero();
    final name = _displayString(hero?['name']) ?? _nameText(profile);
    final age =
        _displayInt(hero?['age']) ??
        _calculateAge(profile['date_of_birth']?.toString());

    return age != null ? '$name, $age' : name;
  }

  String? _gallerySubtitle(Map<String, dynamic> profile) {
    final hero = _displayHero();
    final heightLabel =
        _displayString(hero?['height_label']) ??
        ApiClient.profileHeightLabel(profile);
    final communityLabel =
        _displayString(hero?['community_label']) ?? _communityText(profile);
    final location =
        _displayString(hero?['location_label']) ??
        ApiClient.profileLocationLabel(profile, allowIdFallback: false);

    return _joinNonEmpty([
      _joinNonEmpty([heightLabel, communityLabel]),
      location,
    ]);
  }

  List<_ProfilePhotoItem> _profileGalleryPhotos(
    Map<String, dynamic> profile,
    Map<String, dynamic>? hero,
  ) {
    final photos = <_ProfilePhotoItem>[];
    final seen = <String>{};

    void addPhoto(dynamic rawValue) {
      final url = ApiClient.normalizeProfilePhotoUrl(rawValue);
      if (url == null || seen.contains(url)) return;

      seen.add(url);
      photos.add(_ProfilePhotoItem(url: url));
    }

    void addPhotoFromMap(Map<String, dynamic> row) {
      if (!_photoRowAllowsDisplay(row)) return;

      for (final key in const [
        'primary_photo_url',
        'profile_photo_url',
        'photo_url',
        'image_url',
        'avatar_url',
        'url',
        'path',
        'file_path',
        'profile_photo',
      ]) {
        addPhoto(row[key]);
      }
    }

    addPhoto(hero?['primary_photo_url']);
    addPhotoFromMap(profile);

    for (final key in const ['photos', 'profile_photos']) {
      final rows = profile[key];
      if (rows is List) {
        for (final item in rows) {
          final row = _safeMap(item);
          if (row != null) {
            addPhotoFromMap(row);
          } else {
            addPhoto(item);
          }
        }
        continue;
      }

      final rowMap = _safeMap(rows);
      final nested = rowMap?['data'] ?? rowMap?['items'] ?? rowMap?['results'];
      if (nested is List) {
        for (final item in nested) {
          final row = _safeMap(item);
          if (row != null) {
            addPhotoFromMap(row);
          } else {
            addPhoto(item);
          }
        }
      }
    }

    if (photos.isEmpty) {
      addPhoto(ApiClient.resolveProfilePhotoUrl(profile));
    }

    return photos;
  }

  bool _photoRowAllowsDisplay(Map<String, dynamic> row) {
    for (final key in const ['photo_approved', 'approved', 'is_approved']) {
      if (_displaySafeBool(row[key]) == false) return false;
    }

    for (final key in const [
      'status',
      'approval_status',
      'approved_status',
      'photo_status',
      'moderation_status',
      'admin_override_status',
    ]) {
      final normalized = row[key]?.toString().trim().toLowerCase();
      if (normalized == null || normalized.isEmpty) continue;
      if (normalized.contains('reject') ||
          normalized == 'pending' ||
          normalized == 'review' ||
          normalized == 'processing' ||
          normalized == 'error') {
        return false;
      }
    }

    return true;
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
      _buildProfileDetail(AppStrings.dateOfBirth, profile['date_of_birth']),
      _buildProfileDetail('समुदाय', _communityText(profile)),
      _buildProfileDetail(AppStrings.education, education),
      _buildProfileDetail(AppStrings.location, location),
    ];
  }

  List<Widget> _buildDisplaySectionsWithContact(
    List<ProfileDisplaySectionData> sections,
    ProfileContactData? contact,
  ) {
    final widgets = <Widget>[];
    var contactInserted = false;

    for (var index = 0; index < sections.length; index++) {
      final section = sections[index];
      widgets.add(ProfileDisplaySection(section: section));

      if (contact != null &&
          !contactInserted &&
          _shouldPlaceContactAfterSection(section, index)) {
        widgets.add(_buildContactCard(contact));
        contactInserted = true;
      }
    }

    if (contact != null && !contactInserted) {
      widgets.insert(0, _buildContactCard(contact));
    }

    return widgets;
  }

  bool _shouldPlaceContactAfterSection(
    ProfileDisplaySectionData section,
    int index,
  ) {
    final key = section.key.trim().toLowerCase();
    final title = section.title.trim().toLowerCase();

    return index == 0 ||
        key.contains('basic') ||
        title.contains('basic') ||
        title.contains('profile information') ||
        title.contains('प्रोफाइल माहिती');
  }

  Widget _buildContactCard(ProfileContactData contact) {
    return ProfileContactCard(
      contact: contact,
      onCopy: _copyContactValue,
      onPrimaryAction: _handleContactPrimaryAction,
      onWhatsAppResponse: _handleWhatsAppResponseAction,
      primaryActionLoading:
          _isContactRevealInFlight || _isContactRequestInFlight,
    );
  }

  Widget _buildGunamilanCard(Map<String, dynamic> gunamilan) {
    final available = _displaySafeBool(gunamilan['available']) == true;
    final rows = _safeMapList(gunamilan['rows']);
    final missingFields = _safeMapList(gunamilan['missing_fields']);
    final visibleRows = _showGunamilanDetails || rows.length <= 4
        ? rows
        : rows.take(4);
    final summary =
        _displayString(gunamilan['summary_label']) ??
        _gunamilanScoreLabel(gunamilan);
    final message =
        _displayString(gunamilan['message']) ??
        (available ? null : AppStrings.gunamilanIncomplete);
    final disclaimer =
        _displayString(gunamilan['disclaimer']) ??
        AppStrings.gunamilanDisclaimer;
    final progress = _gunamilanProgress(gunamilan);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF9B1B46).withValues(alpha: 0.09),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Color(0xFF9B1B46),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.gunamilanTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF2E2220),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      available
                          ? AppStrings.gunamilanScore
                          : AppStrings.gunamilanIncomplete,
                      style: const TextStyle(
                        color: Color(0xFF6E625F),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (summary != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF7F0),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    summary,
                    style: const TextStyle(
                      color: Color(0xFF1D7A4D),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(
                color: Color(0xFF6E625F),
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (progress != null) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: const Color(0xFFF1ECE9),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF2F9E67),
                ),
              ),
            ),
          ],
          if (available && rows.isNotEmpty) ...[
            const SizedBox(height: 14),
            ...visibleRows.map(_buildGunamilanRow),
            if (rows.length > 4)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _showGunamilanDetails = !_showGunamilanDetails;
                    });
                  },
                  icon: Icon(
                    _showGunamilanDetails
                        ? Icons.expand_less
                        : Icons.expand_more,
                    size: 19,
                  ),
                  label: Text(
                    _showGunamilanDetails
                        ? AppStrings.gunamilanHideDetails
                        : AppStrings.gunamilanViewDetails,
                  ),
                ),
              ),
          ],
          if (!available && missingFields.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...missingFields.take(5).map(_buildGunamilanMissingRow),
          ],
          const SizedBox(height: 12),
          Text(
            disclaimer,
            style: const TextStyle(
              color: Color(0xFF8B6F6A),
              fontSize: 11.5,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGunamilanRow(Map<String, dynamic> row) {
    final label =
        _displayString(row['guna_name']) ??
        _displayString(row['label']) ??
        AppStrings.noInformation;
    final score = _gunamilanRowScore(row);
    final note = _displayString(row['note']);
    final matchLabel = _displayString(row['match_label']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: Color(0xFFFFF3E8),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.stars_outlined,
              color: Color(0xFFC47A1B),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: Color(0xFF2E2220),
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (score != null)
                      Text(
                        score,
                        style: const TextStyle(
                          color: Color(0xFF1D7A4D),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                  ],
                ),
                if (matchLabel != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    matchLabel,
                    style: const TextStyle(
                      color: Color(0xFF6E625F),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
                if (note != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    note,
                    style: const TextStyle(
                      color: Color(0xFF8B6F6A),
                      fontSize: 12,
                      height: 1.3,
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

  Widget _buildGunamilanMissingRow(Map<String, dynamic> row) {
    final label = _displayString(row['label']);
    if (label == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 16, color: Color(0xFF8B6F6A)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF6E625F),
                fontSize: 12.5,
                height: 1.3,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestedProfilesSection() {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'More profiles you may like',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF2E2220),
                  ),
                ),
              ),
              Text(
                '${_suggestedProfiles.length}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF9B1B46),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 142,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _suggestedProfiles.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                return _buildSuggestedProfileCard(_suggestedProfiles[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestedProfileCard(Map<String, dynamic> profile) {
    final profileId = _displayInt(profile['id']);
    final photoUrl = _suggestedPhotoUrl(profile);
    final name = _suggestedName(profile);
    final age = _suggestedAge(profile);
    final title = age == null ? name : '$name, $age';
    final community = _suggestedCommunity(profile);
    final location = _suggestedLocation(profile);

    return SizedBox(
      width: 110,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: profileId == null
              ? null
              : () => _openSuggestedProfile(profileId),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      photoUrl!,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: const Color(0xFFF1E7E3),
                          child: const Icon(
                            Icons.person_outline,
                            size: 30,
                            color: Color(0xFF9B1B46),
                          ),
                        );
                      },
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.64),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 8,
                      right: 8,
                      bottom: 8,
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (community != null)
                      Text(
                        community,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2E2220),
                          fontSize: 12,
                        ),
                      ),
                    if (location != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openSuggestedProfile(int profileId) {
    final ids = <int>[
      _currentProfileId,
      ..._suggestedProfiles
          .map((profile) => _displayInt(profile['id']))
          .whereType<int>(),
    ].whereType<int>().toSet().toList(growable: false);

    setState(() {
      _openedProfileIds.add(profileId);
      _knownViewedProfileIds.add(profileId);
      _suggestedProfiles = _suggestedProfiles
          .where((profile) => _displayInt(profile['id']) != profileId)
          .toList(growable: false);
    });

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ProfileDetailScreen(profileId: profileId, profileIds: ids),
      ),
    );
  }

  Map<String, dynamic>? _suggestedCard(Map<String, dynamic> profile) {
    final display = _safeMap(profile['display']);
    return _safeMap(display?['card']) ?? _safeMap(display?['hero']);
  }

  String? _suggestedPhotoUrl(Map<String, dynamic> profile) {
    final card = _suggestedCard(profile);
    return _displayString(card?['primary_photo_url']) ??
        ApiClient.resolveProfilePhotoUrl(profile);
  }

  String _suggestedName(Map<String, dynamic> profile) {
    final card = _suggestedCard(profile);
    return _displayString(card?['name']) ??
        ApiClient.safeDisplayLabel(profile['full_name']) ??
        ApiClient.safeDisplayLabel(profile['name']) ??
        'Profile';
  }

  int? _suggestedAge(Map<String, dynamic> profile) {
    final card = _suggestedCard(profile);
    return _displayInt(card?['age']) ??
        _calculateAge(_displayString(profile['date_of_birth']));
  }

  String? _suggestedCommunity(Map<String, dynamic> profile) {
    final card = _suggestedCard(profile);
    return _displayString(card?['community_label']) ??
        ApiClient.profileCommunityLabel(profile);
  }

  String? _suggestedLocation(Map<String, dynamic> profile) {
    final card = _suggestedCard(profile);
    return _displayString(card?['location_label']) ??
        ApiClient.profileLocationLabel(profile, allowIdFallback: false);
  }

  double _bottomContentPadding() {
    return _shouldShowSendInterestButton() ? 96 : 20;
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
    final canPressInterest = canSend && !_isSendingInterest;

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
                child: OutlinedButton.icon(
                  onPressed: _showChatComingSoon,
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text(
                    'Chat',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFF9B1B46)),
                    foregroundColor: const Color(0xFF9B1B46),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: canPressInterest ? _sendInterest : null,
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
                    alreadySent
                        ? AppStrings.interestSent
                        : AppStrings.sendInterest,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showChatComingSoon() {
    _showSnackBar('Chat सुविधा लवकरच उपलब्ध होईल.', Colors.black87);
  }

  Future<void> _copyContactValue(String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    _showSnackBar('$label copied.', Colors.black87);
  }

  Future<void> _handleContactPrimaryAction(ProfileContactCtaData cta) async {
    final action = cta.action.trim().toLowerCase();
    if (action == 'upgrade') {
      Navigator.pushNamed(context, '/plans');
      return;
    }

    if (action == 'send_contact_request') {
      await _handleSendContactRequest(cta);
      return;
    }

    if (action != 'view_contact') {
      _showSnackBar('Contact unlock सुविधा लवकरच उपलब्ध होईल.', Colors.black87);
      return;
    }

    if (_isContactRevealInFlight) return;

    if (!cta.enabled) {
      _showSnackBar('Contact unlock सध्या उपलब्ध नाही.', Colors.black87);
      return;
    }

    final requestedProfileId = _currentProfileId;
    setState(() {
      _isContactRevealInFlight = true;
    });

    try {
      final response = await ApiClient.revealProfileContact(requestedProfileId);
      if (!mounted) return;
      if (requestedProfileId != _currentProfileId) return;

      if (_responseSuccess(response)) {
        final refreshedDisplay = _safeMap(response['display']);
        final refreshedContact = _safeMap(refreshedDisplay?['contact']);

        if (refreshedContact != null) {
          setState(() {
            final currentDisplay = Map<String, dynamic>.from(
              _display ?? <String, dynamic>{},
            );
            currentDisplay['contact'] = refreshedContact;
            _display = currentDisplay;
            _isContactRevealInFlight = false;
          });
        } else {
          setState(() {
            _isContactRevealInFlight = false;
          });
          await _fetchProfile();
        }

        if (!mounted) return;
        _showSnackBar(
          _backendMessage(response, 'Contact details unlocked.'),
          Colors.green,
        );
        return;
      }

      setState(() {
        _isContactRevealInFlight = false;
      });
      _showSnackBar(
        _responseErrorMessage(response, 'Contact unlock करता आली नाही.'),
        Colors.red,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isContactRevealInFlight = false;
      });
      _showSnackBar('एक अनपेक्षित एरर आली: ${e.toString()}', Colors.red);
    }
  }

  Future<void> _handleSendContactRequest(ProfileContactCtaData cta) async {
    if (_isContactRequestInFlight) return;

    if (!cta.enabled) {
      _showSnackBar('Contact request सध्या उपलब्ध नाही.', Colors.black87);
      return;
    }

    final options = _contactData()?.requestOptions;
    if (options == null || !options.isUsable) {
      _showSnackBar('Contact request options उपलब्ध नाहीत.', Colors.red);
      return;
    }

    final draft = await _showContactRequestDialog(options);
    if (draft == null) return;

    final requestedProfileId = _currentProfileId;
    setState(() {
      _isContactRequestInFlight = true;
    });

    try {
      final response = await ApiClient.sendContactRequest(
        profileId: requestedProfileId,
        reason: draft.reason,
        requestedScopes: draft.requestedScopes,
        otherReasonText: draft.otherReasonText,
      );
      if (!mounted) return;
      if (requestedProfileId != _currentProfileId) return;

      if (_responseSuccess(response)) {
        final refreshedDisplay = _safeMap(response['display']);
        final refreshedContact = _safeMap(refreshedDisplay?['contact']);

        if (refreshedContact != null) {
          setState(() {
            final currentDisplay = Map<String, dynamic>.from(
              _display ?? <String, dynamic>{},
            );
            currentDisplay['contact'] = refreshedContact;
            _display = currentDisplay;
            _isContactRequestInFlight = false;
          });
        } else {
          setState(() {
            _isContactRequestInFlight = false;
          });
          await _fetchProfile();
        }

        if (!mounted) return;
        _showSnackBar(
          _backendMessage(response, 'Contact request sent.'),
          Colors.green,
        );
        return;
      }

      setState(() {
        _isContactRequestInFlight = false;
      });
      _showSnackBar(
        _responseErrorMessage(response, 'Contact request पाठवता आली नाही.'),
        Colors.red,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isContactRequestInFlight = false;
      });
      _showSnackBar('एक अनपेक्षित एरर आली: ${e.toString()}', Colors.red);
    }
  }

  Future<_ContactRequestDraft?> _showContactRequestDialog(
    ProfileContactRequestOptionsData options,
  ) async {
    final reasonOptions = options.reasons;
    final scopeOptions = options.scopes;
    if (reasonOptions.isEmpty || scopeOptions.isEmpty) return null;

    var selectedReason = reasonOptions.first.key;
    final validScopes = scopeOptions.map((scope) => scope.key).toSet();
    final selectedScopes = options.defaultScopes
        .where(validScopes.contains)
        .toSet();
    final otherController = TextEditingController();

    try {
      return await showModalBottomSheet<_ContactRequestDraft>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        builder: (sheetContext) {
          String? errorText;

          return StatefulBuilder(
            builder: (context, setSheetState) {
              void submit() {
                if (selectedScopes.isEmpty) {
                  setSheetState(() {
                    errorText = 'किमान एक contact method निवडा.';
                  });
                  return;
                }

                final otherText = otherController.text.trim();
                if (selectedReason == 'other' && otherText.isEmpty) {
                  setSheetState(() {
                    errorText = 'Other reason लिहा.';
                  });
                  return;
                }

                Navigator.pop(
                  sheetContext,
                  _ContactRequestDraft(
                    reason: selectedReason,
                    requestedScopes: selectedScopes.toList(growable: false),
                    otherReasonText: selectedReason == 'other'
                        ? otherText
                        : null,
                  ),
                );
              }

              return SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    18,
                    18,
                    18,
                    MediaQuery.of(context).viewInsets.bottom + 18,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Request Contact',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF2E2220),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedReason,
                        decoration: const InputDecoration(
                          labelText: 'Reason',
                          prefixIcon: Icon(Icons.help_outline),
                        ),
                        items: reasonOptions
                            .map(
                              (reason) => DropdownMenuItem<String>(
                                value: reason.key,
                                child: Text(reason.label),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          if (value == null) return;
                          setSheetState(() {
                            selectedReason = value;
                            errorText = null;
                          });
                        },
                      ),
                      if (selectedReason == 'other') ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: otherController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Other reason',
                            prefixIcon: Icon(Icons.edit_note),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      const Text(
                        'Contact methods',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF594044),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: scopeOptions
                            .map((scope) {
                              final selected = selectedScopes.contains(
                                scope.key,
                              );
                              return FilterChip(
                                label: Text(scope.label),
                                selected: selected,
                                showCheckmark: true,
                                onSelected: (value) {
                                  setSheetState(() {
                                    if (value) {
                                      selectedScopes.add(scope.key);
                                    } else {
                                      selectedScopes.remove(scope.key);
                                    }
                                    errorText = null;
                                  });
                                },
                              );
                            })
                            .toList(growable: false),
                      ),
                      if (errorText != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          errorText!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      ElevatedButton.icon(
                        onPressed: submit,
                        icon: const Icon(Icons.mark_email_unread_outlined),
                        label: const Text('Send Request'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      otherController.dispose();
    }
  }

  void _handleWhatsAppResponseAction() {
    _showSnackBar(
      'WhatsApp Response सुविधा लवकरच उपलब्ध होईल.',
      Colors.black87,
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
          ? await ApiClient.shortlistProfile(_currentProfileId)
          : await ApiClient.unshortlistProfile(_currentProfileId);
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
      final response = await ApiClient.hideProfile(_currentProfileId);
      if (!mounted) return;

      if (_responseSuccess(response)) {
        _applyActionStateFromResponse(response, fallbackHidden: true);
        _showSnackBar(
          _backendMessage(response, 'Profile hidden.'),
          Colors.green,
        );
        Navigator.pop(context, {
          'profileId': _currentProfileId,
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
      final response = await ApiClient.blockProfile(_currentProfileId);
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
          'profileId': _currentProfileId,
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
      _isShortlisted =
          _displaySafeBool(state?['shortlisted']) ??
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

  String _responseErrorMessage(Map<String, dynamic> response, String fallback) {
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
        _displayString(share?['text']) ??
        _displayString(actions?['share_text']);
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
    final name =
        _displayString(hero?['name']) ??
        (profile != null ? _nameText(profile) : 'Profile');
    final age =
        _displayInt(hero?['age']) ??
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
    final communityLabel =
        _displayString(hero?['community_label']) ??
        (profile != null ? _communityText(profile) : null);
    final location =
        _displayString(hero?['location_label']) ??
        (profile != null
            ? ApiClient.profileLocationLabel(profile, allowIdFallback: false)
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
    if (profile == null) return 'Profile ID: $_currentProfileId';

    final hero = _displayHero();
    final age = _calculateAge(profile['date_of_birth']?.toString());
    final location =
        _displayString(hero?['location_label']) ??
        ApiClient.profileLocationLabel(profile, allowIdFallback: false);
    final ageLabel = _displayString(hero?['age_label']);
    final communityLabel =
        _displayString(hero?['community_label']) ?? _communityText(profile);
    final parts = <String>[
      _displayString(hero?['name']) ?? _nameText(profile),
      if (ageLabel != null) ageLabel else if (age != null) '$age वर्षे',
      if (communityLabel != null) communityLabel,
      if (location != null) location,
      'Profile ID: $_currentProfileId',
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
        profileId: _currentProfileId,
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

  void _scrollToComparisonCard() {
    final comparisonContext = _comparisonKey.currentContext;
    if (comparisonContext == null) return;

    Scrollable.ensureVisible(
      comparisonContext,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
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

  Map<String, dynamic>? _contactMap() {
    return _safeMap(_display?['contact']);
  }

  ProfileContactData? _contactData() {
    final contact = _contactMap();
    if (contact == null) return null;
    if (_displaySafeBool(contact['enabled']) != true) return null;

    final state = _contactState(contact['state']);
    final primaryCta = _contactPrimaryCta(contact['primary_cta'], state);
    final whatsapp = _contactWhatsAppResponse(contact['whatsapp_response']);
    final requestOptions = _contactRequestOptions(contact['request_options']);
    final phone = _displayString(contact['phone']);
    final email = _displayString(contact['email']);
    final message =
        _displayString(contact['message']) ?? _fallbackContactMessage(state);

    final hasVisibleData =
        phone != null ||
        email != null ||
        message != null ||
        primaryCta != null ||
        whatsapp.visible;
    if (!hasVisibleData) return null;

    return ProfileContactData(
      title: _displayString(contact['title']) ?? 'Contact Information',
      state: state,
      message: message,
      phone: phone,
      email: email,
      primaryCta: primaryCta,
      requestOptions: requestOptions,
      whatsAppResponse: whatsapp,
    );
  }

  String _contactState(dynamic value) {
    final state = _displayString(value)?.trim().toLowerCase();
    if (state == 'revealed' ||
        state == 'locked' ||
        state == 'unlock_available' ||
        state == 'upgrade_required' ||
        state == 'whatsapp_response_available' ||
        state == 'contact_request_available' ||
        state == 'contact_request_pending' ||
        state == 'contact_request_rejected' ||
        state == 'contact_request_unavailable' ||
        state == 'unavailable') {
      return state!;
    }

    return 'unavailable';
  }

  ProfileContactCtaData? _contactPrimaryCta(dynamic value, String state) {
    final map = _safeMap(value);
    final label = _displayString(map?['label']) ?? _fallbackContactCta(state);
    if (label == null) return null;

    return ProfileContactCtaData(
      label: label,
      style: _displayString(map?['style']) ?? 'disabled',
      action: _displayString(map?['action']) ?? 'none',
      enabled: _displaySafeBool(map?['enabled']) ?? false,
    );
  }

  ProfileContactWhatsAppData _contactWhatsAppResponse(dynamic value) {
    final map = _safeMap(value);
    return ProfileContactWhatsAppData(
      visible: _displaySafeBool(map?['visible']) ?? false,
      label: _displayString(map?['label']) ?? 'WhatsApp Response',
      message: _displayString(map?['message']),
      enabled: _displaySafeBool(map?['enabled']) ?? false,
    );
  }

  ProfileContactRequestOptionsData _contactRequestOptions(dynamic value) {
    final map = _safeMap(value);
    if (map == null) return const ProfileContactRequestOptionsData();

    return ProfileContactRequestOptionsData(
      reasons: _contactOptionList(map['reasons']),
      scopes: _contactOptionList(map['scopes']),
      defaultScopes: _stringList(map['default_scopes']),
    );
  }

  List<ProfileContactOptionData> _contactOptionList(dynamic value) {
    return _safeMapList(value)
        .map((item) {
          final key =
              _displayString(item['key']) ??
              _displayString(item['id']) ??
              _displayString(item['value']);
          final label =
              _displayString(item['label']) ??
              _displayString(item['name']) ??
              key;
          if (key == null || label == null) return null;

          return ProfileContactOptionData(key: key, label: label);
        })
        .whereType<ProfileContactOptionData>()
        .toList(growable: false);
  }

  List<String> _stringList(dynamic value) {
    if (value is! List) return const <String>[];

    return value
        .map(_displayString)
        .whereType<String>()
        .toList(growable: false);
  }

  String? _fallbackContactMessage(String state) {
    switch (state) {
      case 'revealed':
        return 'Contact information is available.';
      case 'unlock_available':
      case 'locked':
        return 'Contact details पाहण्यासाठी unlock आवश्यक आहे.';
      case 'upgrade_required':
        return 'Contact details पाहण्यासाठी upgrade आवश्यक आहे.';
      case 'whatsapp_response_available':
        return 'WhatsApp Response उपलब्ध आहे.';
      case 'contact_request_available':
        return 'या profile साठी contact request पाठवू शकता.';
      case 'contact_request_pending':
        return 'तुमची contact request pending आहे.';
      case 'contact_request_rejected':
        return 'तुमची contact request reject झाली आहे.';
      case 'contact_request_unavailable':
        return 'Contact request सध्या उपलब्ध नाही.';
      case 'unavailable':
        return 'Contact information सध्या उपलब्ध नाही.';
      default:
        return null;
    }
  }

  String? _fallbackContactCta(String state) {
    switch (state) {
      case 'unlock_available':
        return 'View Contact';
      case 'upgrade_required':
        return 'Upgrade to View Contact';
      case 'contact_request_available':
        return 'Request Contact';
      default:
        return null;
    }
  }

  Map<String, dynamic>? _comparisonMap() {
    return _safeMap(_display?['comparison']);
  }

  Map<String, dynamic>? _gunamilanMap() {
    return _safeMap(_display?['gunamilan']);
  }

  double? _gunamilanProgress(Map<String, dynamic> gunamilan) {
    final score =
        _displayDouble(gunamilan['score']) ??
        _displayDouble(gunamilan['total_score']);
    final maxScore = _displayDouble(gunamilan['max_score']);
    if (score == null || maxScore == null || maxScore <= 0) return null;

    return (score / maxScore).clamp(0.0, 1.0).toDouble();
  }

  String? _gunamilanScoreLabel(Map<String, dynamic> gunamilan) {
    final score =
        _displayDouble(gunamilan['score']) ??
        _displayDouble(gunamilan['total_score']);
    final maxScore = _displayDouble(gunamilan['max_score']);
    if (score == null || maxScore == null || maxScore <= 0) return null;

    return '${_numberLabel(score)}/${_numberLabel(maxScore)}';
  }

  String? _gunamilanRowScore(Map<String, dynamic> row) {
    final points =
        _displayDouble(row['obtained']) ?? _displayDouble(row['points']);
    final maxPoints =
        _displayDouble(row['max']) ?? _displayDouble(row['max_points']);
    if (points == null || maxPoints == null || maxPoints <= 0) return null;

    return '${_numberLabel(points)}/${_numberLabel(maxPoints)}';
  }

  List<Map<String, dynamic>> _comparisonItems(Map<String, dynamic> comparison) {
    final rows = _safeMapList(comparison['rows']);
    if (rows.isNotEmpty) return rows;

    return _safeMapList(comparison['items']);
  }

  String? _comparisonString(dynamic value) {
    return _displayString(value);
  }

  bool? _comparisonBoolOrNull(dynamic value) {
    return _displaySafeBool(value);
  }

  ProfileComparisonData? _comparisonData() {
    final comparison = _comparisonMap();
    if (comparison == null) return null;
    if (_displaySafeBool(comparison['enabled']) != true) return null;

    final title = _comparisonString(comparison['title']) ?? 'Comparison';
    final viewer = _safeMap(comparison['viewer']);
    final target = _safeMap(comparison['target']);

    final items = <ProfileComparisonItemData>[];
    for (final row in _comparisonItems(comparison)) {
      final label = _comparisonString(row['label']);
      if (label == null) continue;

      final status = _comparisonStatus(row);
      final viewerValue = _comparisonString(row['viewer_value']);
      final targetValue =
          _comparisonString(row['target_value']) ??
          _comparisonString(row['target_preference']);
      if (targetValue == null && viewerValue == null) continue;

      items.add(
        ProfileComparisonItemData(
          key: _comparisonString(row['key']),
          label: label,
          status: status,
          statusLabel: _comparisonString(row['status_label']),
          targetValue: targetValue,
          viewerValue: viewerValue,
          isCounted: _comparisonBoolOrNull(row['is_counted']) ?? false,
        ),
      );
    }

    if (items.isEmpty) return null;

    return ProfileComparisonData(
      title: title,
      summary: _comparisonString(comparison['summary']),
      viewerName: _comparisonString(viewer?['name']) ?? 'You',
      viewerPhotoUrl: _comparisonString(viewer?['photo_url']),
      targetName: _comparisonString(target?['name']) ?? 'Profile',
      targetPhotoUrl: _comparisonString(target?['photo_url']),
      matchedCount: _displayInt(comparison['matched_count']),
      totalCount: _displayInt(comparison['total_count']),
      items: items,
    );
  }

  String _comparisonStatus(Map<String, dynamic> row) {
    final rawStatus = _comparisonString(row['status'])?.toLowerCase().trim();
    if (rawStatus == 'strong' ||
        rawStatus == 'match' ||
        rawStatus == 'near' ||
        rawStatus == 'neutral') {
      return rawStatus!;
    }

    final matched = _comparisonBoolOrNull(row['matched']);
    return matched == true ? 'match' : 'neutral';
  }

  List<ProfileDisplaySectionData> _displaySections() {
    final sections = _safeMapList(_display?['sections']);
    return sections
        .map(ProfileDisplaySectionData.fromMap)
        .whereType<ProfileDisplaySectionData>()
        .where((section) => !_isLegacyComparisonSection(section))
        .toList();
  }

  bool _isLegacyComparisonSection(ProfileDisplaySectionData section) {
    final key = section.key.trim().toLowerCase();
    if (key == 'partner_match') return true;
    if (key != 'match' && key != 'comparison') return false;

    final title = section.title.trim().toLowerCase();
    if (title.startsWith('you &') ||
        title.contains('match') ||
        title.contains('comparison')) {
      return true;
    }

    return section.items.any((item) {
      final label = item.label.trim().toLowerCase();
      final value = item.value.trim().toLowerCase();
      return label.contains('preference') ||
          value.contains('not matched') ||
          value.contains('review');
    });
  }

  List<Widget> _displayChips(
    Map<String, dynamic> profile, {
    required bool hasComparisonCard,
  }) {
    final widgets = <Widget>[];
    final rows = _safeMapList(_display?['chips']);
    final comparisonTitle = _comparisonData()?.title;
    final shouldShowComparisonChip = hasComparisonCard;
    var hasComparisonChip = false;

    for (final row in rows) {
      final label = _displayString(row['label']);
      if (label == null) continue;

      final normalized = label.trim().toLowerCase();
      final iconKey = _displayString(row['icon']);
      final isComparisonChip = normalized.startsWith('you &');
      if (isComparisonChip && !hasComparisonCard) continue;
      if (isComparisonChip) hasComparisonChip = true;
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
          onTap: isComparisonChip ? _scrollToComparisonCard : null,
        ),
      );

      if (widgets.length >= 4) break;
    }

    if (widgets.isNotEmpty) {
      if (shouldShowComparisonChip && !hasComparisonChip) {
        if (widgets.length >= 4) widgets.removeLast();
        widgets.add(
          _buildHeroChip(
            icon: Icons.compare_arrows,
            label: comparisonTitle ?? _comparisonLabel(profile),
            onTap: _scrollToComparisonCard,
          ),
        );
      }
      return widgets;
    }

    if (_isOnline(profile)) {
      widgets.add(
        _buildHeroChip(
          icon: Icons.circle,
          label: 'Online',
          iconColor: Colors.greenAccent,
        ),
      );
    }

    if (shouldShowComparisonChip) {
      widgets.add(
        _buildHeroChip(
          icon: Icons.compare_arrows,
          label: comparisonTitle ?? _comparisonLabel(profile),
          onTap: _scrollToComparisonCard,
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

  double? _displayDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  String _numberLabel(double value) {
    if ((value - value.round()).abs() < 0.01) {
      return value.round().toString();
    }

    return value.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
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
    return [
      '1',
      'true',
      'yes',
      'active',
      'online',
      'verified',
      'approved',
    ].contains(normalized);
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
    final gender = ApiClient.safeDisplayLabel(
      profile['gender'],
    )?.trim().toLowerCase();
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

class _ProfilePhotoItem {
  const _ProfilePhotoItem({required this.url});

  final String url;
}

class _ContactRequestDraft {
  const _ContactRequestDraft({
    required this.reason,
    required this.requestedScopes,
    required this.otherReasonText,
  });

  final String reason;
  final List<String> requestedScopes;
  final String? otherReasonText;
}

class _ProfilePhotoGalleryViewer extends StatefulWidget {
  const _ProfilePhotoGalleryViewer({
    required this.photos,
    required this.title,
    required this.subtitle,
    required this.onMenuAction,
  });

  final List<_ProfilePhotoItem> photos;
  final String title;
  final String? subtitle;
  final Future<void> Function(String action) onMenuAction;

  @override
  State<_ProfilePhotoGalleryViewer> createState() =>
      _ProfilePhotoGalleryViewerState();
}

class _ProfilePhotoGalleryViewerState
    extends State<_ProfilePhotoGalleryViewer> {
  late final PageController _pageController;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.photos[_index];

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildBlurredBackdrop(current.url),
                  PageView.builder(
                    controller: _pageController,
                    itemCount: widget.photos.length,
                    onPageChanged: (value) {
                      setState(() {
                        _index = value;
                      });
                    },
                    itemBuilder: (context, index) {
                      return _buildPhotoPage(widget.photos[index].url);
                    },
                  ),
                ],
              ),
            ),
            _buildBottomPanel(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.maybePop(context),
          ),
          Expanded(
            child: Text(
              'Photos ${_index + 1}/${widget.photos.length}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Photo actions',
            color: Colors.white,
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: widget.onMenuAction,
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
                value: 'report',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.flag_outlined),
                  title: Text('Report this Profile'),
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildBlurredBackdrop(String photoUrl) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Image.network(
            photoUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return const ColoredBox(color: Colors.black);
            },
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.62),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoPage(String photoUrl) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = (constraints.maxWidth - 28).clamp(
          1.0,
          double.infinity,
        );
        final maxHeight = (constraints.maxHeight - 16).clamp(
          1.0,
          double.infinity,
        );
        var frameWidth = maxWidth;
        var frameHeight = frameWidth * 4 / 3;

        if (frameHeight > maxHeight) {
          frameHeight = maxHeight;
          frameWidth = frameHeight * 3 / 4;
        }

        return Center(
          child: SizedBox(
            width: frameWidth,
            height: frameHeight,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: DecoratedBox(
                decoration: const BoxDecoration(color: Colors.black),
                child: Image.network(
                  photoUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white70,
                        size: 54,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomPanel(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset > 0 ? 10 : 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.88),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (widget.subtitle != null) ...[
            const SizedBox(height: 3),
            Text(
              widget.subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            height: 58,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.photos.length,
              separatorBuilder: (context, index) => const SizedBox(width: 9),
              itemBuilder: (context, index) {
                final selected = index == _index;
                return GestureDetector(
                  onTap: () => _pageController.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 44,
                    height: 58,
                    padding: EdgeInsets.all(selected ? 2 : 0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFFE11D48)
                            : Colors.white.withValues(alpha: 0.26),
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: Image.network(
                        widget.photos[index].url,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return ColoredBox(
                            color: Colors.white.withValues(alpha: 0.10),
                            child: const Icon(
                              Icons.photo_outlined,
                              color: Colors.white70,
                              size: 20,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
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
        ElevatedButton(onPressed: _submit, child: const Text('Submit')),
      ],
    );
  }
}
