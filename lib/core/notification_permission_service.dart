import 'dart:io' show Platform;

import 'package:flutter/services.dart';

class NotificationPermissionService {
  NotificationPermissionService._();

  static const MethodChannel _channel = MethodChannel(
    'navri_matrimony/notification_permission',
  );

  static bool _requestedThisLaunch = false;

  static Future<void> requestOnStartup() async {
    if (_requestedThisLaunch || !Platform.isAndroid) return;
    _requestedThisLaunch = true;

    try {
      await _channel.invokeMethod<String>('request');
    } on PlatformException {
      return;
    } on MissingPluginException {
      return;
    }
  }
}
