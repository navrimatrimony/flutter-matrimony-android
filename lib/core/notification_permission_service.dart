import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_storage.dart';

/// What Android currently thinks about notifications for this app.
@immutable
class NotificationPermissionState {
  const NotificationPermissionState({
    required this.granted,
    required this.canRequestInApp,
  });

  /// True when notifications can actually reach the member — either the
  /// permission is granted, or the platform has no such permission at all
  /// (pre-Android 13).
  final bool granted;

  /// False once Android has stopped showing the dialog: from there the app can
  /// never ask again and only the system settings screen can turn notifications
  /// back on.
  final bool canRequestInApp;

  /// Used when the platform side cannot answer (non-Android, or the channel is
  /// missing). Deliberately reads as "fine": the app must never accuse the
  /// phone of blocking notifications on a guess.
  static const NotificationPermissionState unknown =
      NotificationPermissionState(granted: true, canRequestInApp: false);
}

/// Dart side of the `navri_matrimony/notification_permission` MethodChannel
/// that MainActivity implements. Android 13 (API 33) silently drops every
/// notification until POST_NOTIFICATIONS is granted at runtime, while FCM still
/// reports the send as successful — so this fails invisibly unless the app asks.
///
/// Deliberately NOT `FirebaseMessaging.requestPermission()` and not a
/// permissions package: the native request already exists here, and a second
/// permission path is exactly the duplication the workspace rules forbid.
class NotificationPermissionService {
  NotificationPermissionService._();

  static const MethodChannel _channel = MethodChannel(
    'navri_matrimony/notification_permission',
  );

  /// A member who said no is not asked again until this much time has passed —
  /// and even then only when Android would still show the dialog. Re-prompting
  /// on every launch is what makes people uninstall.
  static const Duration reAskInterval = Duration(days: 30);

  static bool _askedThisLaunch = false;

  /// Returns `granted`, `denied`, `permanently_denied`, `not_required`
  /// (pre-Android 13), `pending` (a request is already on screen) or
  /// `unavailable` when the platform side is missing. Never throws.
  static Future<String> request() async {
    try {
      final value = await _channel.invokeMethod<String>('request');
      final text = value?.trim();
      return text == null || text.isEmpty ? 'unavailable' : text;
    } on MissingPluginException {
      return 'unavailable';
    } on PlatformException {
      return 'unavailable';
    }
  }

  /// Reads the permission without asking for it.
  ///
  /// "Never asked yet" and "can never ask again" look identical to Android —
  /// both report no rationale — so the app's own record of having asked is what
  /// separates them.
  static Future<NotificationPermissionState> currentState() async {
    if (!Platform.isAndroid) return NotificationPermissionState.unknown;

    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>('status');
      if (raw == null) return NotificationPermissionState.unknown;

      final status = raw['status']?.toString().trim() ?? '';
      if (status == 'granted' || status == 'not_required') {
        return const NotificationPermissionState(
          granted: true,
          canRequestInApp: false,
        );
      }

      final showsRationale = raw['shows_rationale'] == true;
      final askedBefore =
          await AppStorage.instance.readNotificationPromptAt() != null;
      return NotificationPermissionState(
        granted: false,
        canRequestInApp: !askedBefore || showsRationale,
      );
    } on MissingPluginException {
      return NotificationPermissionState.unknown;
    } on PlatformException {
      return NotificationPermissionState.unknown;
    }
  }

  /// Opens this app's notification settings on the phone. The only route left
  /// once Android has permanently denied the permission.
  static Future<bool> openSystemSettings() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('openSettings') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Asks for POST_NOTIFICATIONS at most once per outcome.
  ///
  /// Call it on app open for a member whose session was restored, and right
  /// after a fresh login or registration ([force]). Never on a signed-out cold
  /// start: a permission dialog on the language picker or the landing screen
  /// has no context, gets denied, and Android then makes it far harder to ask
  /// again.
  ///
  /// This never gates device-token registration — the server has to know the
  /// device even when the answer is no, otherwise turning notifications on
  /// later would silently do nothing.
  static Future<String> ensureRequested({bool force = false}) async {
    if (!Platform.isAndroid) return 'not_required';
    if (_askedThisLaunch && !force) return 'skipped';

    if (!force) {
      final askedAt = await AppStorage.instance.readNotificationPromptAt();
      if (askedAt != null) {
        if (DateTime.now().difference(askedAt) < reAskInterval) return 'skipped';
        // The interval alone is not enough: only re-ask when the answer can
        // still change from inside the app.
        final state = await currentState();
        if (state.granted || !state.canRequestInApp) return 'skipped';
      }
    }

    _askedThisLaunch = true;
    final result = await request();
    // `pending` and `unavailable` are not answers — recording them would burn
    // the one prompt this install gets without the member ever seeing a dialog.
    if (result == 'granted' ||
        result == 'denied' ||
        result == 'permanently_denied') {
      await AppStorage.instance.markNotificationPromptNow();
    }
    return result;
  }

  @visibleForTesting
  static void resetForTest() {
    _askedThisLaunch = false;
  }
}
