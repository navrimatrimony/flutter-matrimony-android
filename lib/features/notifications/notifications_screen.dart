import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_strings.dart';
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
    final action = _safeMap(notification['action']);
    final routeHint = _stringValue(
      action?['route_hint'] ?? notification['route_hint'],
    );
    final profileId = _asInt(
      action?['profile_id'] ?? notification['profile_id'],
    );

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
      return const Center(child: CircularProgressIndicator());
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
    final title = _stringValue(
      notification['title'],
      fallback: AppStrings.notificationsTitle,
    );
    final message = _stringValue(notification['message']);
    final createdAt = _displayDate(notification['created_at']);
    final isUnread = notification['is_unread'] == true;
    final isBusy = _busyIds.contains(id);

    return Card(
      elevation: 0,
      color: isUnread ? _surface : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isUnread ? _brandColor : const Color(0xFFE8DDD7),
          width: isUnread ? 1.2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: isBusy ? null : () => _handleNotificationTap(notification),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isUnread ? _brandColor : const Color(0xFFF1E7E2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isUnread ? Icons.notifications : Icons.notifications_none,
                  color: isUnread ? Colors.white : const Color(0xFF6B4B4B),
                  size: 20,
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
                            title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isUnread
                                  ? FontWeight.w900
                                  : FontWeight.w800,
                              color: const Color(0xFF35191D),
                            ),
                          ),
                        ),
                        if (isBusy)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    if (message.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        message,
                        style: const TextStyle(
                          color: Color(0xFF594044),
                          height: 1.25,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          createdAt,
                          style: const TextStyle(
                            color: Color(0xFF8A7770),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          isUnread
                              ? AppStrings.notificationsUnread
                              : AppStrings.notificationsRead,
                          style: TextStyle(
                            color: isUnread
                                ? _brandColor
                                : const Color(0xFF8A7770),
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
