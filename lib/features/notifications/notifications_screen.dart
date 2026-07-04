import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_loading.dart';
import '../../core/app_strings.dart';
import '../../core/profile_photo_view.dart';
import '../interests/received_interests_screen.dart';
import '../matrimony_profile/profile_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const Color _brandColor = Color(0xFFDC2626);
  static const Color _brandDark = Color(0xFF9F1239);
  static const Color _surface = Color(0xFFFFFBF7);
  static const Color _textDark = Color(0xFF2E2220);
  static const Color _mutedText = Color(0xFF746966);
  static const Color _line = Color(0xFFE8DDD7);
  static const Color _trustGreen = Color(0xFF157F5B);
  static const Color _inkBlue = Color(0xFF235789);

  bool _loading = true;
  bool _markingAll = false;
  String? _errorMessage;
  int _unreadCount = 0;
  List<Map<String, dynamic>> _notifications = <Map<String, dynamic>>[];
  final Set<String> _busyIds = <String>{};

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiClient.getNotifications();
      if (!mounted) return;

      if (_responseSuccess(response)) {
        setState(() {
          _notifications = _safeMapList(response['notifications']);
          _unreadCount = _asInt(response['unread_count']) ?? 0;
          _loading = false;
        });
        return;
      }

      setState(() {
        _errorMessage = _responseMessage(
          response,
          AppStrings.notificationsLoadFailed,
        );
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '${AppStrings.notificationsLoadFailed} $error';
        _loading = false;
      });
    }
  }

  Future<void> _markAllRead() async {
    if (_markingAll || _unreadCount <= 0) return;

    setState(() {
      _markingAll = true;
    });

    try {
      final response = await ApiClient.markAllNotificationsRead();
      if (!mounted) return;

      if (_responseSuccess(response)) {
        setState(() {
          _unreadCount = _asInt(response['unread_count']) ?? 0;
          _notifications = _notifications
              .map(
                (row) => <String, dynamic>{
                  ...row,
                  'is_unread': false,
                  'read_at': row['read_at'] ?? DateTime.now().toIso8601String(),
                },
              )
              .toList();
        });
      } else {
        _showSnackBar(
          _responseMessage(response, AppStrings.notificationsLoadFailed),
        );
      }
    } catch (error) {
      if (!mounted) return;
      _showSnackBar('${AppStrings.notificationsLoadFailed} $error');
    } finally {
      if (mounted) {
        setState(() {
          _markingAll = false;
        });
      }
    }
  }

  Future<void> _handleNotificationTap(Map<String, dynamic> notification) async {
    final id = _stringValue(notification['id']);
    if (id.isEmpty || _busyIds.contains(id)) return;

    final isUnread = notification['is_unread'] == true;
    if (isUnread) {
      setState(() {
        _busyIds.add(id);
      });

      try {
        final response = await ApiClient.markNotificationRead(id);
        if (!mounted) return;

        if (_responseSuccess(response)) {
          final updated = _safeMap(response['notification']);
          setState(() {
            _unreadCount = _asInt(response['unread_count']) ?? _unreadCount;
            _notifications = _notifications.map((row) {
              if (_stringValue(row['id']) != id) return row;
              return updated ?? <String, dynamic>{...row, 'is_unread': false};
            }).toList();
          });
        } else {
          _showSnackBar(
            _responseMessage(response, AppStrings.notificationsLoadFailed),
          );
          return;
        }
      } catch (error) {
        if (!mounted) return;
        _showSnackBar('${AppStrings.notificationsLoadFailed} $error');
        return;
      } finally {
        if (mounted) {
          setState(() {
            _busyIds.remove(id);
          });
        }
      }
    }

    if (!mounted) return;
    _openNotificationAction(notification);
  }

  void _openNotificationAction(Map<String, dynamic> notification) {
    final action = _primaryAction(notification);
    if (action == null) {
      _showSnackBar(AppStrings.notificationsOpenFailed);
      return;
    }

    _openAction(action);
  }

  void _openAction(Map<String, dynamic> action) {
    final routeHint = _stringValue(action['route_hint']);
    final profileId = _asInt(action['profile_id']);

    if (profileId != null && routeHint == 'profile') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProfileDetailScreen(profileId: profileId),
        ),
      );
      return;
    }

    if (routeHint == 'contact_inbox') {
      Navigator.pushNamed(context, '/contact-inbox');
      return;
    }

    if (routeHint == 'mediation_inbox') {
      _showSnackBar(
        AppStrings.isMarathi
            ? 'WhatsApp Response सुविधा mobile मध्ये लवकरच उपलब्ध होईल.'
            : 'WhatsApp Response inbox will be available in the mobile app soon.',
      );
      return;
    }

    if (routeHint == 'received_interests') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ReceivedInterestsScreen()),
      );
      return;
    }

    if (routeHint == 'who_viewed') {
      Navigator.pushNamed(
        context,
        '/matches',
        arguments: const <String, dynamic>{'initialTab': 'more'},
      );
      return;
    }

    if (routeHint == 'plans') {
      Navigator.pushNamed(context, '/plans');
      return;
    }

    if (routeHint == 'matches') {
      Navigator.pushNamed(context, '/matches');
      return;
    }

    _showSnackBar(AppStrings.notificationsOpenFailed);
  }

  Map<String, dynamic>? _primaryAction(Map<String, dynamic> notification) {
    final display = _safeMap(notification['display']);
    final cta = _safeMap(display?['cta']);
    if (cta != null) return cta;

    final action = _safeMap(notification['action']);
    if (action != null) return action;

    final routeHint = _stringValue(notification['route_hint']);
    if (routeHint.isEmpty) return null;

    return <String, dynamic>{
      'route_hint': routeHint,
      'profile_id': notification['profile_id'],
      'request_id': notification['request_id'],
      'action_type': notification['action_type'],
    };
  }

  Map<String, dynamic>? _secondaryAction(Map<String, dynamic> notification) {
    final display = _safeMap(notification['display']);
    return _safeMap(display?['secondary_cta']);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4EF),
      appBar: AppBar(
        title: Text(AppStrings.notificationsTitle),
        actions: [
          TextButton.icon(
            onPressed: _markingAll || _unreadCount <= 0 ? null : _markAllRead,
            icon: _markingAll
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.done_all),
            label: Text(AppStrings.notificationsMarkAllRead),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return AppLoadingState.list(
        title: AppStrings.isMarathi
            ? 'Notifications लोड होत आहेत'
            : 'Loading notifications',
        icon: Icons.notifications_none,
      );
    }

    if (_errorMessage != null) {
      return _buildMessageState(
        icon: Icons.error_outline,
        message: _errorMessage!,
        actionLabel: AppStrings.plansRefresh,
        onAction: _loadNotifications,
      );
    }

    if (_notifications.isEmpty) {
      return _buildMessageState(
        icon: Icons.notifications_none,
        message: AppStrings.notificationsEmpty,
        actionLabel: AppStrings.plansRefresh,
        onAction: _loadNotifications,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
        itemCount: _notifications.length + 1,
        separatorBuilder: (_, index) =>
            index == 0 ? const SizedBox(height: 10) : const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index == 0) return _buildCountHeader();
          return _buildNotificationCard(_notifications[index - 1]);
        },
      ),
    );
  }

  Widget _buildCountHeader() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE8DDD7)),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_active, color: _brandColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${AppStrings.notificationsUnread}: $_unreadCount',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: _brandDark,
              ),
            ),
          ),
          IconButton(
            tooltip: AppStrings.plansRefresh,
            onPressed: _loadNotifications,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final id = _stringValue(notification['id']);
    final display = _safeMap(notification['display']);
    final actor = _safeMap(display?['actor']);
    final teaser = _safeMap(display?['teaser']);
    final layout = _stringValue(display?['layout'], fallback: 'system');
    final title = _stringValue(
      notification['title'],
      fallback: AppStrings.notificationsTitle,
    );
    final message = _stringValue(notification['message']);
    final createdAt = _displayDate(notification['created_at']);
    final isUnread = notification['is_unread'] == true;
    final isBusy = _busyIds.contains(id);
    final primaryAction = _primaryAction(notification);
    final secondaryAction = _secondaryAction(notification);
    final isLockedTeaser = layout == 'locked_teaser' && teaser != null;

    if (isLockedTeaser) {
      return _buildLockedTeaserNotificationCard(
        notification: notification,
        title: title,
        message: message,
        teaser: teaser,
        createdAt: createdAt,
        isUnread: isUnread,
        isBusy: isBusy,
        primaryAction: primaryAction,
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: isBusy ? null : () => _handleNotificationTap(notification),
        child: Ink(
          decoration: BoxDecoration(
            color: isUnread ? _surface : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isUnread ? _brandColor.withValues(alpha: 0.55) : _line,
              width: isUnread ? 1.25 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.035),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildNotificationVisual(
                      layout: layout,
                      actor: actor,
                      teaser: teaser,
                      isUnread: isUnread,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildNotificationBody(
                        layout: layout,
                        title: title,
                        message: message,
                        teaser: teaser,
                        createdAt: createdAt,
                        isUnread: isUnread,
                        isBusy: isBusy,
                      ),
                    ),
                  ],
                ),
                if (primaryAction != null || secondaryAction != null) ...[
                  const SizedBox(height: 10),
                  Divider(height: 1, color: _line.withValues(alpha: 0.85)),
                  const SizedBox(height: 10),
                  _buildActionRow(
                    primaryAction: primaryAction,
                    secondaryAction: secondaryAction,
                    disabled: isBusy,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLockedTeaserNotificationCard({
    required Map<String, dynamic> notification,
    required String title,
    required String message,
    required Map<String, dynamic> teaser,
    required String createdAt,
    required bool isUnread,
    required bool isBusy,
    required Map<String, dynamic>? primaryAction,
  }) {
    final action = primaryAction;
    final radius = BorderRadius.circular(12);

    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: radius,
        onTap: isBusy ? null : () => _handleNotificationTap(notification),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: radius,
            border: Border.all(
              color: isUnread ? _brandColor.withValues(alpha: 0.62) : _line,
              width: isUnread ? 1.35 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6F1D2D).withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 164),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildLockedTeaserPhotoPanel(teaser: teaser),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(13, 12, 12, 12),
                      child: _buildLockedTeaserContent(
                        title: title,
                        message: message,
                        teaser: teaser,
                        createdAt: createdAt,
                        isUnread: isUnread,
                        isBusy: isBusy,
                        action: action,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLockedTeaserPhotoPanel({required Map<String, dynamic> teaser}) {
    return SizedBox(
      width: 118,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildTeaserPhoto(teaser),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x11000000),
                  Color(0x22000000),
                  Color(0xAA000000),
                ],
              ),
            ),
          ),
          Positioned(
            top: 9,
            right: 9,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.50),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
              ),
              child: const Icon(
                Icons.lock_outline,
                color: Colors.white,
                size: 17,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockedTeaserContent({
    required String title,
    required String message,
    required Map<String, dynamic> teaser,
    required String createdAt,
    required bool isUnread,
    required bool isBusy,
    required Map<String, dynamic>? action,
  }) {
    final headline = _lockedTeaserHeadline(
      teaser: teaser,
      fallbackMessage: message,
    );
    final lines = _lockedTeaserDetailLines(teaser);
    final viewedSummary = _stringValue(teaser['viewed_summary']);
    final accentLine = _stringValue(teaser['accent_line']);
    final matchLine = _stringValue(teaser['match_line']);
    final highlightLine = _joinNonEmpty([accentLine, matchLine]);
    final curiosityLine = _lockedCuriosityLine(teaser);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _brandDark,
                  fontSize: 11.6,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ),
            if (isBusy) ...[
              const SizedBox(width: 8),
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ] else
              _buildUnreadDot(isUnread),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          headline,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _textDark,
            fontSize: 15.4,
            fontWeight: FontWeight.w900,
            height: 1.16,
            letterSpacing: 0,
          ),
        ),
        if (highlightLine.isNotEmpty) ...[
          const SizedBox(height: 7),
          _buildLockedHighlightChip(highlightLine),
        ],
        const SizedBox(height: 7),
        Text(
          curiosityLine,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF5A4541),
            fontSize: 12.7,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
        ),
        if (lines.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final line in lines) _buildLockedDetailChip(line)],
          ),
        ],
        const Spacer(),
        const SizedBox(height: 9),
        _buildLockedTeaserFooter(
          action: action,
          teaser: teaser,
          viewedSummary: viewedSummary,
          createdAt: createdAt,
          isUnread: isUnread,
        ),
      ],
    );
  }

  Widget _buildUnreadDot(bool isUnread) {
    return Container(
      width: 8,
      height: 8,
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: isUnread ? _brandColor : const Color(0xFFCBD5E1),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildLockedHighlightChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7F1),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0xFFC7EBDC)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: _trustGreen,
          fontSize: 11.8,
          fontWeight: FontWeight.w900,
          height: 1.1,
        ),
      ),
    );
  }

  Widget _buildLockedDetailChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFF45515E),
          fontSize: 11.4,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildLockedTeaserFooter({
    required Map<String, dynamic>? action,
    required Map<String, dynamic> teaser,
    required String viewedSummary,
    required String createdAt,
    required bool isUnread,
  }) {
    final timeText = viewedSummary.isNotEmpty ? viewedSummary : createdAt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (timeText.isNotEmpty) ...[
          Text(
            timeText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _mutedText,
              fontSize: 11.4,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (action != null)
          ElevatedButton.icon(
            onPressed: () => _openAction(action),
            icon: const Icon(Icons.lock_open_outlined, size: 16),
            label: Text(
              _lockedUnlockLabel(teaser, action),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _brandColor,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              minimumSize: const Size(0, 40),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(
                fontSize: 12.8,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          )
        else
          _buildLockedReadState(isUnread),
      ],
    );
  }

  Widget _buildLockedReadState(bool isUnread) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isUnread
              ? _brandColor.withValues(alpha: 0.10)
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          isUnread
              ? AppStrings.notificationsUnread
              : AppStrings.notificationsRead,
          style: TextStyle(
            color: isUnread ? _brandColor : _mutedText,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationVisual({
    required String layout,
    required Map<String, dynamic>? actor,
    required Map<String, dynamic>? teaser,
    required bool isUnread,
  }) {
    if (layout == 'locked_teaser' && teaser != null) {
      return SizedBox(
        width: 82,
        height: 108,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildTeaserPhoto(teaser),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xAA000000)],
                  ),
                ),
              ),
              Positioned(
                right: 7,
                top: 7,
                child: Container(
                  width: 27,
                  height: 27,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.48),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_outline,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (actor != null) {
      return ProfilePhotoView(
        photoUrl: ApiClient.normalizeProfilePhotoUrl(actor['photo_url']),
        width: 54,
        height: 54,
        circle: true,
        backgroundColor: const Color(0xFFF1E7E3),
        placeholderColor: _brandDark,
        placeholderIcon: Icons.person_outline,
      );
    }

    final visual = _visualForLayout(layout);
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: (isUnread ? visual.color : const Color(0xFFF1E7E2)).withValues(
          alpha: isUnread ? 1 : 0.72,
        ),
        shape: BoxShape.circle,
      ),
      child: Icon(
        visual.icon,
        color: isUnread ? Colors.white : visual.color,
        size: 24,
      ),
    );
  }

  Widget _buildNotificationBody({
    required String layout,
    required String title,
    required String message,
    required Map<String, dynamic>? teaser,
    required String createdAt,
    required bool isUnread,
    required bool isBusy,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: isUnread ? FontWeight.w900 : FontWeight.w800,
                  color: _textDark,
                  height: 1.16,
                ),
              ),
            ),
            if (isBusy) ...[
              const SizedBox(width: 8),
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        if (layout == 'locked_teaser' && teaser != null)
          _buildLockedTeaserBody(teaser: teaser, fallbackMessage: message)
        else if (message.isNotEmpty)
          Text(
            message,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF594044),
              height: 1.28,
              fontWeight: FontWeight.w600,
            ),
          ),
        const SizedBox(height: 9),
        _buildMetaRow(createdAt: createdAt, isUnread: isUnread),
      ],
    );
  }

  Widget _buildLockedTeaserBody({
    required Map<String, dynamic> teaser,
    required String fallbackMessage,
  }) {
    final headline = _stringValue(
      teaser['headline'],
      fallback: fallbackMessage.isEmpty
          ? (AppStrings.isMarathi ? 'लॉक केलेली माहिती' : 'Locked profile')
          : fallbackMessage,
    );
    final lines = _stringList(teaser['lines']).take(3).toList();
    final viewedSummary = _stringValue(teaser['viewed_summary']);
    final accentLine = _stringValue(teaser['accent_line']);
    final matchLine = _stringValue(teaser['match_line']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          headline,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _textDark,
            fontSize: 14.2,
            fontWeight: FontWeight.w900,
            height: 1.20,
          ),
        ),
        if (accentLine.isNotEmpty || matchLine.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            _joinNonEmpty([accentLine, matchLine]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _trustGreen,
              fontSize: 12.4,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
        if (lines.isNotEmpty) ...[
          const SizedBox(height: 5),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              for (final line in lines)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    line,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF45515E),
                      fontSize: 11.8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
        ],
        if (viewedSummary.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            viewedSummary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _mutedText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMetaRow({required String createdAt, required bool isUnread}) {
    return Row(
      children: [
        if (createdAt.isNotEmpty)
          Expanded(
            child: Text(
              createdAt,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _mutedText,
                fontSize: 11.8,
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        else
          const Spacer(),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isUnread
                ? _brandColor.withValues(alpha: 0.10)
                : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            isUnread
                ? AppStrings.notificationsUnread
                : AppStrings.notificationsRead,
            style: TextStyle(
              color: isUnread ? _brandColor : _mutedText,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionRow({
    required Map<String, dynamic>? primaryAction,
    required Map<String, dynamic>? secondaryAction,
    required bool disabled,
  }) {
    final actions = <Widget>[];

    if (primaryAction != null) {
      actions.add(
        Expanded(
          child: ElevatedButton.icon(
            onPressed: disabled ? null : () => _openAction(primaryAction),
            icon: Icon(_actionIcon(primaryAction), size: 17),
            label: Text(
              _actionLabel(primaryAction),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              minimumSize: const Size(0, 40),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      );
    }

    if (secondaryAction != null) {
      actions.add(
        Expanded(
          child: OutlinedButton.icon(
            onPressed: disabled ? null : () => _openAction(secondaryAction),
            icon: Icon(_actionIcon(secondaryAction), size: 17),
            label: Text(
              _actionLabel(secondaryAction),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              minimumSize: const Size(0, 40),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          actions[i],
        ],
      ],
    );
  }

  String _lockedTeaserHeadline({
    required Map<String, dynamic> teaser,
    required String fallbackMessage,
  }) {
    final raw = _stringValue(
      teaser['headline'],
      fallback: fallbackMessage.isEmpty
          ? (AppStrings.isMarathi ? 'Profile पाहिले गेले' : 'Profile viewed')
          : fallbackMessage,
    );
    final cleaned = _sanitizeLockedHeadline(raw);
    if (cleaned.isEmpty) {
      return AppStrings.isMarathi
          ? 'तुमचे profile पाहिले गेले.'
          : 'Your profile was viewed.';
    }

    if (_mentionsProfileView(cleaned)) {
      return cleaned;
    }

    return AppStrings.isMarathi
        ? '$cleaned यांनी तुमचे profile पाहिले.'
        : '$cleaned viewed your profile.';
  }

  String _sanitizeLockedHeadline(String value) {
    var text = value.trim();
    if (text.isEmpty) return '';

    final lower = text.toLowerCase();
    if (lower.contains('someone') || text.contains('कोणीतरी')) {
      return '';
    }

    text = text.replaceAll(RegExp(r',$'), '').trim();
    if (AppStrings.isMarathi) {
      text = text
          .replaceFirst('एक मुलगी', 'वधू')
          .replaceFirst('एक स्त्री', 'वधू')
          .replaceFirst('एक मुलगा', 'वर')
          .replaceFirst('एक पुरुष', 'वर');
      return text;
    }

    return text
        .replaceFirst(RegExp(r'\bA girl\b', caseSensitive: false), 'A bride')
        .replaceFirst(RegExp(r'\bA woman\b', caseSensitive: false), 'A bride')
        .replaceFirst(RegExp(r'\bA boy\b', caseSensitive: false), 'A groom')
        .replaceFirst(RegExp(r'\bA man\b', caseSensitive: false), 'A groom');
  }

  bool _mentionsProfileView(String text) {
    final lower = text.toLowerCase();
    return lower.contains('viewed your profile') ||
        lower.contains('profile पाहिले') ||
        lower.contains('प्रोफाइल पाहिले');
  }

  List<String> _lockedTeaserDetailLines(Map<String, dynamic> teaser) {
    return _stringList(teaser['lines'])
        .where((line) {
          final lower = line.toLowerCase();
          return !lower.contains('someone') && !line.contains('कोणीतरी');
        })
        .take(3)
        .toList();
  }

  String _lockedCuriosityLine(Map<String, dynamic> teaser) {
    final gender = _lockedTeaserGender(teaser);
    if (AppStrings.isMarathi) {
      return switch (gender) {
        _LockedTeaserGender.female => 'तुमच्या profile कडे तिचे लक्ष गेले.',
        _LockedTeaserGender.male => 'तुमच्या profile कडे त्याचे लक्ष गेले.',
        _ => 'या profile viewer ने तुमचे profile पाहिले.',
      };
    }

    return switch (gender) {
      _LockedTeaserGender.female => 'Your profile caught her attention.',
      _LockedTeaserGender.male => 'Your profile caught his attention.',
      _ => 'This profile viewer opened your profile.',
    };
  }

  String _lockedUnlockLabel(
    Map<String, dynamic> teaser,
    Map<String, dynamic> action,
  ) {
    final routeHint = _stringValue(action['route_hint']);
    if (routeHint != 'plans') {
      return _actionLabel(action);
    }

    final gender = _lockedTeaserGender(teaser);
    if (AppStrings.isMarathi) {
      return switch (gender) {
        _LockedTeaserGender.female => 'तिचे profile पाहण्यासाठी Unlock करा',
        _LockedTeaserGender.male => 'त्याचे profile पाहण्यासाठी Unlock करा',
        _ => 'Profile पाहण्यासाठी Unlock करा',
      };
    }

    return switch (gender) {
      _LockedTeaserGender.female => 'Unlock to see her profile',
      _LockedTeaserGender.male => 'Unlock to see his profile',
      _ => 'Unlock to view profile',
    };
  }

  _LockedTeaserGender _lockedTeaserGender(Map<String, dynamic> teaser) {
    final text = [
      _stringValue(teaser['headline']),
      _stringValue(teaser['interest_hint']),
      ..._stringList(teaser['lines']),
    ].join(' ').toLowerCase();

    if (text.contains('bride') ||
        text.contains('girl') ||
        text.contains('woman') ||
        text.contains('वधू') ||
        text.contains('मुलगी') ||
        text.contains('महिला') ||
        text.contains('स्त्री')) {
      return _LockedTeaserGender.female;
    }

    if (text.contains('groom') ||
        text.contains('boy') ||
        text.contains('man') ||
        text.contains('वर') ||
        text.contains('मुलगा') ||
        text.contains('पुरुष')) {
      return _LockedTeaserGender.male;
    }

    return _LockedTeaserGender.unknown;
  }

  Widget _buildTeaserPhoto(Map<String, dynamic> teaser) {
    final avatarStyle = _stringValue(teaser['avatar_style']).toLowerCase();
    final photoUrl = _stringValue(teaser['photo_url']);

    if (avatarStyle == 'blur' &&
        photoUrl.isNotEmpty &&
        !_isPlaceholderPhotoUrl(photoUrl)) {
      return Transform.scale(
        scale: _teaserPhotoScale(teaser),
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(
            sigmaX: _teaserBlurSigma(teaser),
            sigmaY: _teaserBlurSigma(teaser),
          ),
          child: Image.network(
            Uri.encodeFull(photoUrl),
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            errorBuilder: (_, _, _) => _buildTeaserPlaceholder(),
          ),
        ),
      );
    }

    return _buildTeaserPlaceholder();
  }

  bool _isPlaceholderPhotoUrl(String photoUrl) {
    final lower = photoUrl.toLowerCase();
    return lower.contains('/images/placeholders/') ||
        lower.contains('default-profile.svg') ||
        lower.contains('male-profile.svg') ||
        lower.contains('female-profile.svg');
  }

  double _teaserBlurSigma(Map<String, dynamic> teaser) {
    final blurClass = _stringValue(teaser['blur_photo_class']).toLowerCase();
    if (blurClass.contains('blur-sm')) return 4;
    if (blurClass.contains('blur-[3px]')) return 3;
    if (blurClass.contains('blur-[6px]')) return 6;
    if (blurClass.contains('blur-2xl')) return 18;
    if (blurClass.contains('blur-md')) return 10;
    return 10;
  }

  double _teaserPhotoScale(Map<String, dynamic> teaser) {
    final blurClass = _stringValue(teaser['blur_photo_class']).toLowerCase();
    if (blurClass.contains('scale-125')) return 1.25;
    if (blurClass.contains('scale-110')) return 1.10;
    if (blurClass.contains('scale-105')) return 1.05;
    return 1.08;
  }

  Widget _buildTeaserPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF8D9D3), Color(0xFFEAF3F8)],
        ),
      ),
      child: const Icon(Icons.person_outline, color: _brandDark, size: 42),
    );
  }

  _NotificationVisual _visualForLayout(String layout) {
    return switch (layout) {
      'contact_request' => const _NotificationVisual(
        icon: Icons.contact_mail_outlined,
        color: _trustGreen,
      ),
      'mediation' => const _NotificationVisual(
        icon: Icons.support_agent_outlined,
        color: _inkBlue,
      ),
      'locked_action' => const _NotificationVisual(
        icon: Icons.lock_outline,
        color: _brandDark,
      ),
      'profile' => const _NotificationVisual(
        icon: Icons.person_outline,
        color: _brandColor,
      ),
      _ => const _NotificationVisual(
        icon: Icons.notifications_none,
        color: _brandColor,
      ),
    };
  }

  IconData _actionIcon(Map<String, dynamic> action) {
    final routeHint = _stringValue(action['route_hint']);
    return switch (routeHint) {
      'profile' => Icons.person_search_outlined,
      'contact_inbox' => Icons.contact_mail_outlined,
      'mediation_inbox' => Icons.support_agent_outlined,
      'plans' => Icons.lock_open_outlined,
      'matches' => Icons.favorite_border,
      'received_interests' => Icons.inbox_outlined,
      'who_viewed' => Icons.visibility_outlined,
      _ => Icons.open_in_new,
    };
  }

  String _actionLabel(Map<String, dynamic> action) {
    final label = _stringValue(action['label']);
    if (label.isNotEmpty) return label;

    final routeHint = _stringValue(action['route_hint']);
    return switch (routeHint) {
      'profile' => AppStrings.isMarathi ? 'प्रोफाइल पहा' : 'View profile',
      'contact_inbox' =>
        AppStrings.isMarathi ? 'कॉन्टॅक्ट इनबॉक्स' : 'Contact inbox',
      'mediation_inbox' => 'WhatsApp Response',
      'plans' => AppStrings.isMarathi ? 'Unlock करा' : 'Unlock',
      'matches' => AppStrings.isMarathi ? 'जुळण्या पहा' : 'View matches',
      'received_interests' =>
        AppStrings.isMarathi ? 'आलेल्या इच्छा' : 'Received interests',
      'who_viewed' => AppStrings.isMarathi ? 'कोणी पाहिले' : 'Who viewed',
      _ => AppStrings.isMarathi ? 'उघडा' : 'Open',
    };
  }

  Widget _buildMessageState({
    required IconData icon,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _brandColor, size: 42),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  static bool _responseSuccess(Map<String, dynamic> response) {
    final statusCode = _asInt(response['statusCode']) ?? 0;
    return response['success'] == true && statusCode >= 200 && statusCode < 300;
  }

  static String _responseMessage(
    Map<String, dynamic> response,
    String fallback,
  ) {
    final message = _stringValue(response['message']);
    return message.isEmpty ? fallback : message;
  }

  static List<Map<String, dynamic>> _safeMapList(dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];

    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static Map<String, dynamic>? _safeMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return <String>[];

    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static String _joinNonEmpty(List<String> values) {
    return values.where((value) => value.trim().isNotEmpty).join(' • ');
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static String _stringValue(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static String _displayDate(dynamic value) {
    final raw = _stringValue(value);
    if (raw.isEmpty) return '';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final local = parsed.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/${local.year} $hour:$minute';
  }
}

class _NotificationVisual {
  const _NotificationVisual({required this.icon, required this.color});

  final IconData icon;
  final Color color;
}

enum _LockedTeaserGender { female, male, unknown }
