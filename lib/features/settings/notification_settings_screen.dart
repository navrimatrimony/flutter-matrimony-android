import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_language.dart';
import '../../core/app_loading.dart';
import '../../core/app_strings.dart';
import '../../core/notification_permission_service.dart';

/// Lets a member switch off the notifications they do not want.
///
/// SERVER-DRIVEN BY DESIGN: the category list, its labels and its grouping all
/// come from `GET /notification-preferences`. Nothing about a notification type
/// is hardcoded here, so the server can add a type and every installed app
/// shows it — no new APK. Labels and descriptions arrive already localized and
/// are rendered as-is; only this screen's own chrome goes through the ARB.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen>
    with WidgetsBindingObserver {
  bool _loading = true;
  String? _errorMessage;
  List<_PushCategory> _categories = <_PushCategory>[];
  _QuietHours? _quietHours;
  final Set<String> _busyKeys = <String>{};
  bool _savingQuietHours = false;

  /// The OS-level permission, which sits above every switch on this screen: if
  /// Android is blocking notifications, none of these categories can arrive no
  /// matter what the server has stored.
  NotificationPermissionState _permission =
      NotificationPermissionState.unknown;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _refreshPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// The member can only fix a blocked permission outside the app, so the
  /// banner has to re-check itself when they come back from phone settings.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshPermission();
  }

  Future<void> _refreshPermission() async {
    final state = await NotificationPermissionService.currentState();
    if (!mounted) return;
    setState(() => _permission = state);
  }

  Future<void> _enableNotifications() async {
    if (_permission.canRequestInApp) {
      // The in-app dialog while Android still offers it; the settings screen
      // once it does not.
      await NotificationPermissionService.ensureRequested(force: true);
    } else {
      await NotificationPermissionService.openSystemSettings();
    }
    await _refreshPermission();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiClient.getNotificationPreferences();
      if (!mounted) return;

      if (_responseSuccess(response)) {
        setState(() {
          _apply(response);
          _loading = false;
        });
        return;
      }

      setState(() {
        _errorMessage = _responseMessage(response, AppStrings.settingsLoadFailed);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '${AppStrings.settingsLoadFailed} $error';
        _loading = false;
      });
    }
  }

  /// Reads the payload from wherever the server puts it — flat, or under
  /// `data` / `preferences` — so a wrapper change does not blank the screen.
  void _apply(Map<String, dynamic> response) {
    final payload =
        _firstMapWithCategories(<dynamic>[
          response,
          response['data'],
          response['preferences'],
          response['notification_preferences'],
        ]) ??
        response;

    _categories = _categoriesFrom(payload['categories']);
    _quietHours = _QuietHours.from(_safeMap(payload['quiet_hours']));
  }

  Map<String, dynamic>? _firstMapWithCategories(List<dynamic> candidates) {
    for (final candidate in candidates) {
      final map = _safeMap(candidate);
      if (map != null && map.containsKey('categories')) return map;
    }

    return null;
  }

  /// Accepts both a list of rows and a map keyed by category key, because the
  /// two shapes are equally natural to produce server-side.
  List<_PushCategory> _categoriesFrom(dynamic value) {
    if (value is List) {
      return value
          .map((row) => _PushCategory.from(_safeMap(row)))
          .whereType<_PushCategory>()
          .toList();
    }

    if (value is Map) {
      return value.entries
          .map((entry) {
            final row = _safeMap(entry.value);
            if (row == null) return null;
            return _PushCategory.from(<String, dynamic>{
              'key': entry.key.toString(),
              ...row,
            });
          })
          .whereType<_PushCategory>()
          .toList();
    }

    return <_PushCategory>[];
  }

  Future<void> _toggleCategory(_PushCategory category, bool value) async {
    if (_busyKeys.contains(category.key)) return;

    final previous = category.enabled;
    setState(() {
      category.enabled = value;
      _busyKeys.add(category.key);
    });

    try {
      final response = await ApiClient.updateNotificationPreferences(
        categories: <String, bool>{category.key: value},
      );
      if (!mounted) return;

      if (!_responseSuccess(response)) {
        _revertCategory(category, previous, _responseMessage(response, null));
        return;
      }
    } catch (error) {
      if (!mounted) return;
      _revertCategory(category, previous, error.toString());
      return;
    } finally {
      if (mounted) setState(() => _busyKeys.remove(category.key));
    }
  }

  Future<void> _toggleQuietHours(bool value) async {
    final quietHours = _quietHours;
    if (quietHours == null || _savingQuietHours) return;

    final previous = quietHours.enabled;
    setState(() {
      quietHours.enabled = value;
      _savingQuietHours = true;
    });

    try {
      final response = await ApiClient.updateNotificationPreferences(
        quietHoursEnabled: value,
      );
      if (!mounted) return;

      if (!_responseSuccess(response)) {
        setState(() => quietHours.enabled = previous);
        _showError(_responseMessage(response, null));
        return;
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => quietHours.enabled = previous);
      _showError(error.toString());
      return;
    } finally {
      if (mounted) setState(() => _savingQuietHours = false);
    }
  }

  /// A failed save must never look like it worked, so the switch goes back and
  /// the member is told why.
  void _revertCategory(_PushCategory category, bool previous, String? detail) {
    setState(() => category.enabled = previous);
    _showError(detail);
  }

  void _showError(String? detail) {
    final message = detail == null || detail.trim().isEmpty
        ? appText.notificationSettingsSaveFailed
        : '${appText.notificationSettingsSaveFailed} $detail';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(appText.notificationSettingsTitle)),
      // The banner sits outside `_buildBody` on purpose: a blocked permission
      // is true whether the preferences loaded, failed or came back empty, and
      // it outranks all three.
      body: Column(
        children: [
          if (!_permission.granted) _buildPermissionBanner(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  /// Says plainly that the phone is switched off rather than showing a column
  /// of switches that cannot do anything.
  Widget _buildPermissionBanner() {
    final scheme = Theme.of(context).colorScheme;
    final canAsk = _permission.canRequestInApp;

    return Material(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.notifications_off_outlined,
                  color: scheme.onErrorContainer,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    appText.notificationPermissionOffTitle,
                    style: TextStyle(
                      color: scheme.onErrorContainer,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              canAsk
                  ? appText.notificationPermissionOffBody
                  : appText.notificationPermissionBlockedBody,
              style: TextStyle(color: scheme.onErrorContainer, height: 1.3),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _enableNotifications,
                icon: Icon(
                  canAsk
                      ? Icons.notifications_active_outlined
                      : Icons.open_in_new_rounded,
                  color: scheme.onErrorContainer,
                ),
                label: Text(
                  canAsk
                      ? appText.notificationPermissionEnable
                      : appText.notificationPermissionOpenSettings,
                  style: TextStyle(
                    color: scheme.onErrorContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return AppLoadingState.list(
        title: appText.loadingSettings,
        icon: Icons.notifications_active_outlined,
      );
    }

    if (_errorMessage != null) {
      return _buildMessageState(
        icon: Icons.error_outline,
        message: _errorMessage!,
      );
    }

    final quietHours = _quietHours;
    if (_categories.isEmpty && quietHours == null) {
      return _buildMessageState(
        icon: Icons.notifications_off_outlined,
        message: appText.notificationSettingsEmpty,
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          Text(
            appText.notificationSettingsIntro,
            style: const TextStyle(fontWeight: FontWeight.w600, height: 1.3),
          ),
          const SizedBox(height: 14),
          if (quietHours != null) ...[
            _buildQuietHoursCard(quietHours),
            const SizedBox(height: 14),
          ],
          if (_categories.isEmpty)
            _buildEmptyCategoriesCard()
          else
            ..._buildGroupedCategories(),
        ],
      ),
    );
  }

  List<Widget> _buildGroupedCategories() {
    final groups = <String, List<_PushCategory>>{};
    for (final category in _categories) {
      groups.putIfAbsent(category.groupLabel, () => <_PushCategory>[]).add(category);
    }

    final cards = <Widget>[];
    groups.forEach((groupLabel, rows) {
      cards.add(_buildCategoryCard(groupLabel, rows));
      cards.add(const SizedBox(height: 14));
    });

    if (cards.isNotEmpty) cards.removeLast();
    return cards;
  }

  Widget _buildCategoryCard(String groupLabel, List<_PushCategory> rows) {
    return _card(
      // Empty when the server sends an ungrouped list — then the card simply
      // carries the screen's own heading instead of a server one.
      title: groupLabel.isEmpty ? appText.notificationSettingsManage : groupLabel,
      icon: Icons.notifications_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final row in rows)
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: row.enabled,
              onChanged: _busyKeys.contains(row.key)
                  ? null
                  : (value) => _toggleCategory(row, value),
              title: Text(
                row.label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: row.description.isEmpty ? null : Text(row.description),
            ),
        ],
      ),
    );
  }

  Widget _buildQuietHoursCard(_QuietHours quietHours) {
    final window = quietHours.window;

    return _card(
      title: quietHours.label.isEmpty ? appText.quietHours : quietHours.label,
      icon: Icons.bedtime_outlined,
      child: SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        value: quietHours.enabled,
        onChanged: _savingQuietHours ? null : _toggleQuietHours,
        title: Text(
          quietHours.label.isEmpty ? appText.quietHours : quietHours.label,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: window.isEmpty ? null : Text(window),
      ),
    );
  }

  Widget _buildEmptyCategoriesCard() {
    return _card(
      title: appText.notificationSettingsManage,
      icon: Icons.notifications_off_outlined,
      child: Text(appText.notificationSettingsEmpty),
    );
  }

  Widget _card({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildMessageState({required IconData icon, required String message}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary, size: 42),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: Text(appText.retry),
            ),
          ],
        ),
      ),
    );
  }

  static bool _responseSuccess(Map<String, dynamic> response) {
    final statusCode = _asInt(response['statusCode']) ?? 0;
    return response['success'] != false &&
        statusCode >= 200 &&
        statusCode < 300;
  }

  static String? _responseMessage(
    Map<String, dynamic> response,
    String? fallback,
  ) {
    final message = response['message']?.toString().trim() ?? '';
    return message.isEmpty ? fallback : message;
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

/// One server-defined notification category.
class _PushCategory {
  _PushCategory({
    required this.key,
    required this.label,
    required this.description,
    required this.groupLabel,
    required this.enabled,
  });

  final String key;
  final String label;
  final String description;
  final String groupLabel;
  bool enabled;

  static _PushCategory? from(Map<String, dynamic>? row) {
    if (row == null) return null;

    final key = _text(row['key'] ?? row['type']);
    if (key.isEmpty) return null;

    return _PushCategory(
      key: key,
      // Falls back to the key so a category with missing copy is still
      // switchable instead of showing an unusable blank row.
      label: _text(row['label']).isEmpty ? key : _text(row['label']),
      description: _text(row['description']),
      groupLabel: _text(row['group_label'] ?? row['group']),
      enabled: _flag(row['push_enabled'] ?? row['enabled'] ?? row['push']),
    );
  }
}

/// The server-supplied quiet window. The app never computes or formats the
/// times itself — it shows what the server sent.
class _QuietHours {
  _QuietHours({
    required this.enabled,
    required this.label,
    required this.window,
  });

  bool enabled;
  final String label;
  final String window;

  static _QuietHours? from(Map<String, dynamic>? row) {
    if (row == null) return null;

    final startsAt = _text(row['starts_at']);
    final endsAt = _text(row['ends_at']);
    final description = _text(row['description']);
    final window = description.isNotEmpty
        ? description
        : (startsAt.isEmpty || endsAt.isEmpty ? '' : '$startsAt – $endsAt');

    return _QuietHours(
      enabled: _flag(row['enabled']),
      label: _text(row['label']),
      window: window,
    );
  }
}

/// Server copy is rendered as-is except for one thing: numerals are forced to
/// Latin 0-9. That is a frozen product rule and a time like "22:00" is exactly
/// where a Devanagari numeral would slip through unnoticed.
String _text(dynamic value) {
  final raw = value?.toString().trim() ?? '';
  if (raw.isEmpty) return '';

  const devanagariZero = 0x0966;
  final buffer = StringBuffer();
  for (final rune in raw.runes) {
    if (rune >= devanagariZero && rune <= devanagariZero + 9) {
      buffer.writeCharCode(0x0030 + (rune - devanagariZero));
    } else {
      buffer.writeCharCode(rune);
    }
  }

  return buffer.toString();
}

bool _flag(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final text = value.trim().toLowerCase();
    return text == '1' || text == 'true' || text == 'yes' || text == 'on';
  }

  return false;
}
