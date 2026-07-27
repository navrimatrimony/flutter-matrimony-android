import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/app_loading.dart';
import '../../core/app_strings.dart';
import '../../core/locked_teaser.dart';
import '../../core/profile_photo_view.dart';
import '../matrimony_profile/profile_detail_screen.dart';
import '../../core/app_language.dart';

/// ===============================
/// RECEIVED INTERESTS SCREEN
/// ===============================
///
/// Rows the member's plan has not revealed are drawn locked, exactly as
/// `GET /interests/received` describes them: `incoming_reveal_unlocked: false`
/// and a `sender_profile` reduced to `{id, revealed: false}`. The screen never
/// reconstructs the hidden identity — no name, no photo, and no route into the
/// sender's profile.
///
/// A locked row carries the rich teaser block under `teaser` — the blurred
/// photo, courtesy headline, taluka, age, marital status and match hint that
/// `ReceivedInterestTeaserPolicy` allows. It is present only while the row is
/// locked, so [LockedTeaser] reads it here and the shared teaser widgets draw
/// it. A row that arrives without one keeps the same card and the same call to
/// action, just with the person stand-in and the plain locked copy: the screen
/// never invents an attribute to fill the gap.
class ReceivedInterestsScreen extends StatefulWidget {
  const ReceivedInterestsScreen({super.key});

  @override
  State<ReceivedInterestsScreen> createState() =>
      _ReceivedInterestsScreenState();
}

class _ReceivedInterestsScreenState extends State<ReceivedInterestsScreen> {
  static const Color _brandColor = Color(0xFFDC2626);
  static const Color _brandDark = Color(0xFF9F1239);

  List<dynamic> _interests = [];
  bool _isLoading = true;
  String? _errorMessage;

  /// -1 = unlimited, 0 = none, > 0 = reveals per window.
  int _revealLimit = -1;
  String _revealResetPeriod = 'monthly';

  @override
  void initState() {
    super.initState();
    _fetchReceivedInterests();
  }

  Future<void> _fetchReceivedInterests() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiClient.getReceivedInterests();
      if (!mounted) return;

      final statusCode = response['statusCode'];

      if (statusCode == 401) {
        setState(() {
          _errorMessage = appText.authExpiredLoginAgain;
          _isLoading = false;
        });
        return;
      }

      if (statusCode == 403) {
        setState(() {
          _errorMessage = response['message'] ?? 'Unauthorized';
          _isLoading = false;
        });
        return;
      }

      if (response['success'] == true && response['data'] != null) {
        final data = response['data'] as Map<String, dynamic>;
        final receivedList = data['received'] as List?;
        setState(() {
          _interests = receivedList ?? [];
          _revealLimit = _asInt(data['interest_view_limit']) ?? -1;
          _revealResetPeriod =
              data['interest_view_reset_period']?.toString().trim() ??
              'monthly';
          _isLoading = false;
        });
      } else {
        setState(() {
          _interests = [];
          _errorMessage = response['message'] ?? appText.couldNotLoadInterests;
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

  Future<void> _acceptInterest(int interestId) async {
    try {
      final response = await ApiClient.acceptInterest(interestId);
      if (!mounted) return;

      final statusCode = response['statusCode'];

      if (statusCode == 200 && response['success'] == true) {
        _showSnackBar(appText.interestAccepted, Colors.green);
        _fetchReceivedInterests();
      } else {
        _showSnackBar(
          response['message']?.toString() ?? appText.couldNotAcceptInterest,
          Colors.red,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(appText.unexpectedErrorOccurred(e.toString()), Colors.red);
    }
  }

  Future<void> _rejectInterest(int interestId) async {
    try {
      final response = await ApiClient.rejectInterest(interestId);
      if (!mounted) return;

      final statusCode = response['statusCode'];

      if (statusCode == 200 && response['success'] == true) {
        _showSnackBar(appText.interestRejected, Colors.green);
        _fetchReceivedInterests();
      } else {
        _showSnackBar(
          response['message']?.toString() ?? appText.couldNotRejectInterest,
          Colors.red,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(appText.unexpectedErrorOccurred(e.toString()), Colors.red);
    }
  }

  void _showSnackBar(String message, Color background) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: background,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _openPlans() {
    Navigator.pushNamed(context, '/plans');
  }

  String _getStatusText(String? status) {
    return switch (status) {
      'pending' => appText.pending,
      'accepted' => appText.accepted,
      'rejected' => appText.rejected,
      _ => '',
    };
  }

  Color _getStatusColor(String? status) {
    return switch (status) {
      'pending' => Colors.orange,
      'accepted' => Colors.green,
      'rejected' => Colors.red,
      _ => Colors.grey,
    };
  }

  /// `interest_view_reset_period` is a raw key from the API
  /// (`daily`|`weekly`|`monthly`|`quarterly`|`lifetime`).
  String _revealIntervalLabel(String period) {
    return switch (period) {
      'daily' => appText.intervalEachDay,
      'weekly' => appText.intervalEachWeek,
      'quarterly' => appText.intervalEachQuarter,
      'lifetime' => appText.intervalInTotal,
      _ => appText.intervalEachMonth,
    };
  }

  /// A row the member's plan has not revealed. Both the row flag and the
  /// reduced `sender_profile` say so; either is enough.
  bool _isRevealed(Map<String, dynamic> interest) {
    final flag = interest['incoming_reveal_unlocked'];
    if (flag is bool) return flag;

    final sender = _safeMap(interest['sender_profile']);
    if (sender != null && sender['revealed'] == false) return false;

    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(appText.receivedInterests)),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return AppLoadingState.list(
        title: appText.loadingReceivedInterests,
        icon: Icons.inbox_outlined,
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
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
                onPressed: _fetchReceivedInterests,
                child: Text(AppStrings.retry),
              ),
            ],
          ),
        ),
      );
    }

    final banner = _buildRevealLimitBanner();

    if (_interests.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchReceivedInterests,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            if (banner != null) ...[banner, const SizedBox(height: 16)],
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Text(
                appText.noReceivedInterests,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchReceivedInterests,
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _interests.length + (banner == null ? 0 : 1),
        itemBuilder: (context, index) {
          if (banner != null) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: banner,
              );
            }
            index -= 1;
          }

          final raw = _safeMap(_interests[index]);
          if (raw == null) return const SizedBox.shrink();

          final interestId = _asInt(raw['id']);
          if (interestId == null) return const SizedBox.shrink();

          return _isRevealed(raw)
              ? _buildRevealedCard(raw, interestId)
              : _buildLockedCard(raw, interestId);
        },
      ),
    );
  }

  /// Explains why some rows below are locked. Built only from what the API
  /// already returns alongside the rows.
  Widget? _buildRevealLimitBanner() {
    if (_revealLimit < 0) return null;

    final message = _revealLimit == 0
        ? appText.interestRevealNone
        : appText.interestRevealLimitBanner(
            _revealLimit,
            _revealIntervalLabel(_revealResetPeriod),
          );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE1C8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline, size: 20, color: _brandDark),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                height: 1.3,
                fontWeight: FontWeight.w600,
                color: Color(0xFF5B4636),
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _openPlans,
            style: TextButton.styleFrom(
              foregroundColor: _brandColor,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(0, 34),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
              ),
            ),
            child: Text(appText.unlock),
          ),
        ],
      ),
    );
  }

  Widget _buildRevealedCard(Map<String, dynamic> interest, int interestId) {
    final senderProfile = _safeMap(interest['sender_profile']);
    if (senderProfile == null) return const SizedBox.shrink();

    final status = interest['status']?.toString();
    final photoUrl = ApiClient.resolveProfilePhotoUrl(senderProfile);
    final senderName =
        senderProfile['full_name']?.toString().trim().isNotEmpty == true
        ? senderProfile['full_name'].toString()
        : appText.nameNotAvailable;
    final senderProfileId = _asInt(senderProfile['id']);

    void openProfile() {
      if (senderProfileId == null) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProfileDetailScreen(
            profileId: senderProfileId,
            initialProfile: senderProfile,
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: senderProfileId != null ? openProfile : null,
              child: ProfilePhotoView(
                photoUrl: photoUrl,
                width: 80,
                height: 80,
                circle: true,
                backgroundColor: Colors.grey.shade300,
                placeholderColor: Colors.grey,
                placeholderIcon: Icons.person,
                placeholderSize: 40,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: senderProfileId != null ? openProfile : null,
                    child: Text(
                      senderName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildStatusRow(status),
                  const SizedBox(height: 8),
                  if (status == 'pending')
                    _buildPendingActions(
                      interestId: interestId,
                      acceptLocked: false,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The locked presentation, drawn with the same shared teaser chrome as the
  /// who-viewed tiles and the locked notification rows: one photo frame, one
  /// headline, one attribute line, the curiosity pills, one call to action.
  ///
  /// The teaser block is rendered the moment the API sends one; until then the
  /// same card degrades to the silhouette, the courtesy headline and the plain
  /// locked copy rather than imitating attributes it was not given.
  Widget _buildLockedCard(Map<String, dynamic> interest, int interestId) {
    final teaser = LockedTeaser.fromJson(interest['teaser']);
    final status = interest['status']?.toString();
    final headline = teaser?.headline ?? appText.lockedInterestTitle;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LockedTeaserPhotoFrame(
                  teaser: teaser ?? const LockedTeaser(),
                  width: 96,
                  height: 118,
                  cornerRadius: 14,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LockedTeaserHeadline(text: headline, fontSize: 16.5),
                      const SizedBox(height: 7),
                      if (teaser != null)
                        LockedTeaserLines(
                          teaser: teaser,
                          attributeMaxLines: 2,
                          showInterestHint: true,
                        )
                      else
                        Text(
                          appText.lockedInterestBody,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.3,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      const SizedBox(height: 9),
                      _buildStatusRow(status),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LockedTeaserUnlockButton(
              label: appText.unlock,
              expand: true,
              onPressed: _openPlans,
            ),
            if (status == 'pending') ...[
              const SizedBox(height: 10),
              // Mirrors the server: accepting an unrevealed interest is denied
              // (`INTEREST_ACCEPT_REQUIRES_REVEAL`), declining is allowed.
              _buildPendingActions(interestId: interestId, acceptLocked: true),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String? status) {
    final label = _getStatusText(status);
    if (label.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        Text(
          '${appText.statusLabel}: ',
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: _getStatusColor(status),
          ),
        ),
      ],
    );
  }

  Widget _buildPendingActions({
    required int interestId,
    required bool acceptLocked,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: acceptLocked
                    ? null
                    : () => _acceptInterest(interestId),
                icon: acceptLocked
                    ? const Icon(Icons.lock_outline, size: 15)
                    : const SizedBox.shrink(),
                label: Text(appText.accept),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: () => _rejectInterest(interestId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                child: Text(appText.reject),
              ),
            ),
          ],
        ),
        if (acceptLocked) ...[
          const SizedBox(height: 6),
          Text(
            appText.lockedInterestAcceptHint,
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
          ),
        ],
      ],
    );
  }

  static Map<String, dynamic>? _safeMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }
}
