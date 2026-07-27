import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../features/interests/received_interests_screen.dart';
import '../features/matrimony_profile/profile_detail_screen.dart';
import '../main.dart';
import 'api_client.dart';
import 'app_language.dart';

/// Runs in its own isolate when a push arrives while the app is not in the
/// foreground. Android draws `notification` payloads by itself there, so there
/// is nothing to do — but FCM still requires a registered handler, otherwise it
/// logs an error for every background message.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

/// Owns everything Firebase Cloud Messaging in the member app: startup wiring,
/// the device-token registration contract with Laravel, foreground display and
/// notification-tap routing.
///
/// Nothing here may break the app. Firebase can be unreachable, the token
/// endpoint can fail, the push payload can be malformed — in every case the
/// member must still be able to log in and use the app, so every entry point
/// swallows its errors and logs instead.
class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  /// Also named in AndroidManifest.xml as the FCM default channel, so a push
  /// that arrives in the background lands in the same channel as one shown
  /// while the app is open.
  static const String _channelId = 'navri_default';

  static const Duration _networkTimeout = Duration(seconds: 10);

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _initializing = false;
  String? _deviceToken;
  RemoteMessage? _pendingLaunchMessage;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;

  bool get isInitialized => _initialized;

  /// Called once from `main()`, before the app is mounted.
  Future<void> initialize() async {
    if (_initialized || _initializing) return;
    if (!Platform.isAndroid) return;

    _initializing = true;
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      await _localNotifications.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        onDidReceiveNotificationResponse: _onLocalNotificationResponse,
      );
      await _ensureChannel();

      _messageSubscription = FirebaseMessaging.onMessage.listen(
        _showForegroundNotification,
      );
      _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        (message) => _routeTo(message.data),
      );
      _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh
          .listen(_onTokenRefresh);

      // Held back until the app has finished its own startup routing —
      // see [handlePendingLaunchMessage].
      _pendingLaunchMessage = await FirebaseMessaging.instance
          .getInitialMessage();

      _initialized = true;
    } catch (error, stackTrace) {
      _log('initialize failed', error, stackTrace);
    } finally {
      _initializing = false;
    }
  }

  /// Opens the screen behind the notification the app was launched from.
  ///
  /// Called after startup routing has settled, otherwise the bootstrap screen's
  /// own `pushReplacementNamed` would wipe the screen we just opened.
  void handlePendingLaunchMessage() {
    final message = _pendingLaunchMessage;
    if (message == null) return;
    _pendingLaunchMessage = null;
    _routeTo(message.data);
  }

  /// Registers this device's FCM token for the signed-in member.
  ///
  /// Safe to call more than once — the server keeps one row per token.
  Future<void> registerToken() async {
    if (!_initialized) return;
    if (ApiClient.authToken == null) return;

    try {
      final token = await FirebaseMessaging.instance.getToken().timeout(
        _networkTimeout,
      );
      if (token == null || token.isEmpty) return;

      _deviceToken = token;
      await ApiClient.registerDeviceToken(token: token).timeout(_networkTimeout);
    } catch (error, stackTrace) {
      _log('device token registration failed', error, stackTrace);
    }
  }

  /// Drops this device's token server-side.
  ///
  /// Must run while the member is still authenticated — `ApiClient.logout()`
  /// calls this before it clears the auth token.
  Future<void> unregisterToken() async {
    if (!_initialized) return;
    if (ApiClient.authToken == null) return;

    try {
      final token =
          _deviceToken ??
          await FirebaseMessaging.instance.getToken().timeout(_networkTimeout);
      if (token == null || token.isEmpty) return;

      await ApiClient.deleteDeviceToken(token: token).timeout(_networkTimeout);
    } catch (error, stackTrace) {
      _log('device token removal failed', error, stackTrace);
    } finally {
      _deviceToken = null;
    }
  }

  @visibleForTesting
  Future<void> dispose() async {
    await _messageSubscription?.cancel();
    await _openedSubscription?.cancel();
    await _tokenRefreshSubscription?.cancel();
    _messageSubscription = null;
    _openedSubscription = null;
    _tokenRefreshSubscription = null;
    _initialized = false;
  }

  void _onTokenRefresh(String token) {
    _deviceToken = token;
    if (ApiClient.authToken == null) return;

    unawaited(
      ApiClient.registerDeviceToken(token: token)
          .timeout(_networkTimeout)
          .catchError((Object error, StackTrace stackTrace) {
            _log('refreshed device token not saved', error, stackTrace);
            return <String, dynamic>{};
          }),
    );
  }

  /// Android does not draw a `notification` payload while the app is in the
  /// foreground, so the app draws it itself on the same channel.
  Future<void> _showForegroundNotification(RemoteMessage message) async {
    try {
      final notification = message.notification;
      final title = (notification?.title ?? '').trim();
      final body = (notification?.body ?? _stringValue(message.data['body']))
          .trim();
      if (title.isEmpty && body.isEmpty) return;

      await _ensureChannel();

      await _localNotifications.show(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: title.isEmpty ? appText.pushDefaultTitle : title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            appText.pushChannelName,
            channelDescription: appText.pushChannelDescription,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
        payload: jsonEncode(message.data),
      );
    } catch (error, stackTrace) {
      _log('foreground notification not shown', error, stackTrace);
    }
  }

  /// Creating a channel that already exists updates its labels, which is how
  /// the channel follows the language the member picked in the app.
  Future<void> _ensureChannel() async {
    final android = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;

    await android.createNotificationChannel(
      AndroidNotificationChannel(
        _channelId,
        appText.pushChannelName,
        description: appText.pushChannelDescription,
        importance: Importance.high,
      ),
    );
  }

  void _onLocalNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        _routeTo(Map<String, dynamic>.from(decoded));
      }
    } catch (error, stackTrace) {
      _log('notification payload could not be read', error, stackTrace);
    }
  }

  /// Opens the screen a push points at.
  ///
  /// Deliberately forgiving: an unknown or missing type just opens the home
  /// screen, and a push that arrives while nobody is signed in only opens the
  /// app. The server owns the vocabulary, so this must never throw on one it
  /// has not seen.
  void _routeTo(Map<String, dynamic> data) {
    try {
      final navigator = appNavigatorKey.currentState;
      if (navigator == null) return;
      if (ApiClient.authToken == null) return;

      var type = _stringValue(data['type']).toLowerCase();
      if (type.isEmpty) {
        type = _stringValue(data['route_hint']).toLowerCase();
      }

      switch (type) {
        case 'profile':
        case 'profile_view':
        case 'who_viewed':
          final profileId =
              _intValue(data['profile_id']) ?? _intValue(data['id']);
          if (profileId == null) {
            navigator.pushNamed('/matches');
            return;
          }
          navigator.push(
            MaterialPageRoute<void>(
              builder: (_) => ProfileDetailScreen(profileId: profileId),
            ),
          );
          return;
        case 'interest':
        case 'received_interest':
        case 'received_interests':
          navigator.push(
            MaterialPageRoute<void>(
              builder: (_) => const ReceivedInterestsScreen(),
            ),
          );
          return;
        case 'contact_request':
        case 'contact_inbox':
          navigator.pushNamed('/contact-inbox');
          return;
        case 'suchak_request':
        case 'suchak_requests':
          navigator.pushNamed('/suchak-requests');
          return;
        case 'chat':
        case 'message':
          navigator.pushNamed('/chats');
          return;
        case 'plan':
        case 'plans':
        case 'payment':
          navigator.pushNamed('/plans');
          return;
        case 'match':
        case 'matches':
          navigator.pushNamed('/matches');
          return;
        case 'notification':
        case 'notifications':
          navigator.pushNamed('/notifications');
          return;
        default:
          navigator.pushNamed('/home');
          return;
      }
    } catch (error, stackTrace) {
      _log('notification could not be opened', error, stackTrace);
    }
  }

  static String _stringValue(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  static int? _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static void _log(String message, Object error, StackTrace stackTrace) {
    debugPrint('PushNotificationService: $message — $error');
    if (kDebugMode) debugPrintStack(stackTrace: stackTrace);
  }
}
