import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_loading.dart';
import '../../core/app_strings.dart';
import '../../core/locked_teaser.dart';
import '../../core/profile_photo_view.dart';
import '../interests/received_interests_screen.dart';
import '../matrimony_profile/profile_detail_screen.dart';
import '../../core/app_language.dart';

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
        appText.whatsappResponseInboxWillBeAvailable,
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
          IconButton(
            tooltip: appText.notificationSettingsTitle,
            onPressed: () =>
                Navigator.pushNamed(context, '/notification-settings'),
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return AppLoadingState.list(
        title: appText.loadingNotifications,
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
    final teaser = LockedTeaser.fromJson(display?['teaser']);
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
                      isUnread: isUnread,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildNotificationBody(
                        title: title,
                        message: message,
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
    required String message,
    required LockedTeaser teaser,
    required String createdAt,
    required bool isUnread,
    required bool isBusy,
    required Map<String, dynamic>? primaryAction,
  }) {
    final headline = _lockedTeaserHeadline(
      teaser: teaser,
      fallbackMessage: message,
    );
    final timeText = _lockedTeaserMetaText(
      teaser: teaser,
      createdAt: createdAt,
    );
    final radius = BorderRadius.circular(10);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: radius,
        onTap: isBusy ? null : () => _handleNotificationTap(notification),
        child: Ink(
          decoration: BoxDecoration(
            color: isUnread ? _surface : Colors.white,
            borderRadius: radius,
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
                    _buildLockedTeaserAvatar(teaser),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            headline,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _textDark,
                              fontSize: 14.4,
                              fontWeight: isUnread
                                  ? FontWeight.w900
                                  : FontWeight.w800,
                              height: 1.22,
                              letterSpacing: 0,
                            ),
                          ),
                          const SizedBox(height: 6),
                          // The headline no longer absorbs the repeat count, so
                          // the accent line is shown where it belongs: as its
                          // own pill. `viewed_summary` is drawn below as the
                          // time line, which is why it is suppressed here.
                          LockedTeaserLines(
                            teaser: teaser,
                            attributeMaxLines: 2,
                            attributeFontSize: 12,
                            showSummary: false,
                          ),
                          if (timeText.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              timeText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _mutedText,
                                fontSize: 11.8,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          if (isBusy) ...[
                            const SizedBox(height: 7),
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (primaryAction != null) ...[
                  const SizedBox(height: 10),
                  Divider(height: 1, color: _line.withValues(alpha: 0.85)),
                  const SizedBox(height: 10),
                  _buildLockedTeaserUnlockAction(
                    action: primaryAction,
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

  /// The blurred visitor, drawn through the shared frame so a locked row here
  /// looks like a locked row anywhere else. The lock sits on the rim instead of
  /// across the face: the point of the card is that there is a person behind
  /// the blur, and covering the middle of them hid exactly that.
  Widget _buildLockedTeaserAvatar(LockedTeaser teaser) {
    return LockedTeaserPhotoFrame(
      teaser: teaser,
      width: 64,
      height: 64,
      circle: true,
    );
  }

  Widget _buildLockedTeaserUnlockAction({
    required Map<String, dynamic>? action,
    required bool disabled,
  }) {
    if (action == null) {
      return const SizedBox.shrink();
    }

    // The server already localized this label (`display.cta.label`); rendering
    // our own would ignore the CTA mode the admin picked.
    final label = _stringValue(action['label'], fallback: appText.unlock);

    return LockedTeaserUnlockButton(
      label: label,
      expand: true,
      onPressed: disabled ? null : () => _openAction(action),
    );
  }

  /// The teaser's own time line, exactly as the server sent it.
  ///
  /// `teaser_viewed_time` is an admin setting, and on production it is `human`
  /// so this arrives as relative time. This card used to prefer its own
  /// formatted `created_at` instead, which threw that setting away and put a
  /// raw "27/07/2026 22:00" on a card whose whole job is to feel personal. The
  /// notification's timestamp is now only the fallback, for a payload that
  /// carries no summary at all.
  String _lockedTeaserMetaText({
    required LockedTeaser teaser,
    required String createdAt,
  }) {
    final summary = _stringValue(teaser.viewedSummary);

    return summary.isNotEmpty ? summary : createdAt;
  }

  Widget _buildNotificationVisual({
    required String layout,
    required Map<String, dynamic>? actor,
    required bool isUnread,
  }) {
    // Locked teasers never reach here: `_buildNotificationCard` routes them to
    // `_buildLockedTeaserNotificationCard`, which draws the photo through the
    // shared `LockedTeaserPhoto`.
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
    required String title,
    required String message,
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
        if (message.isNotEmpty)
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

  /// The server's headline, rendered exactly as it arrived.
  ///
  /// `name_display` is an admin setting with five modes (`hidden`, `masked`,
  /// `courtesy_from_place`, `first_only`, `full`) and the server has already
  /// resolved whichever one is configured into this one string. This card used
  /// to rebuild the sentence instead — swapping nouns, stripping "तालुका",
  /// re-inflecting the subject, appending the repeat count — which silently
  /// overrode the admin's choice and made the phone disagree with both the
  /// payload and the web inbox. Nothing here rewrites the copy any more.
  ///
  /// The notification's own message is the only fallback, for a payload that
  /// carries no headline at all.
  String _lockedTeaserHeadline({
    required LockedTeaser teaser,
    required String fallbackMessage,
  }) {
    final headline = _stringValue(teaser.headline, fallback: fallbackMessage);

    return headline.isEmpty ? appText.yourProfileWasViewed : headline;
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
      'profile' => appText.viewProfile,
      'contact_inbox' =>
        appText.contactInbox,
      'mediation_inbox' => 'WhatsApp Response',
      'plans' => appText.unlock,
      'matches' => appText.viewMatches,
      'received_interests' =>
        appText.receivedInterests2,
      'who_viewed' => appText.whoViewed,
      _ => appText.open2,
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
