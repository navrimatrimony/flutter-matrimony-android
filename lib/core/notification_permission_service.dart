import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import 'app_storage.dart';

class NotificationPermissionService {
  NotificationPermissionService._();

  static const MethodChannel _channel = MethodChannel(
    'navri_matrimony/notification_permission',
  );

  static bool _requestedThisLaunch = false;

  static Future<void> requestOnStartup() async {
    if (_requestedThisLaunch || !Platform.isAndroid) return;
    _requestedThisLaunch = true;

    if (await AppStorage.instance.hasPromptedNotificationPermission()) {
      return;
    }

    try {
      final result = await _channel.invokeMethod<String>('request');
      if (result == 'granted' || result == 'denied') {
        await AppStorage.instance.markNotificationPermissionPrompted();
      }
    } on PlatformException {
      return;
    } on MissingPluginException {
      return;
    }
  }
}
