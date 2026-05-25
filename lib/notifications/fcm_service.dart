import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../storage/secure_storage.dart';

// Top-level handler required by firebase_messaging for background/terminated state
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  _showLocalNotification(message);
}

final _localNotifications = FlutterLocalNotificationsPlugin();

const _androidChannel = AndroidNotificationChannel(
  'quantix_high_importance',
  'Quantix Notifications',
  description: 'Order updates, assignments and alerts',
  importance: Importance.high,
);

Future<void> _showLocalNotification(RemoteMessage message) async {
  final notification = message.notification;
  if (notification == null) return;

  await _localNotifications.show(
    notification.hashCode,
    notification.title,
    notification.body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        _androidChannel.id,
        _androidChannel.name,
        channelDescription: _androidChannel.description,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    ),
    payload: message.data['route'] as String?,
  );
}

/// Routes notification taps to a deep-link path.
/// Apps register a callback here; FCMService calls it on tap.
typedef NotificationRouter = void Function(String? route, Map<String, dynamic> data);

class FcmService {
  final SecureStorage _storage;
  NotificationRouter? _router;
  StreamSubscription<RemoteMessage>? _fgSub;

  FcmService(this._storage);

  /// Call once from main() after Firebase.initializeApp().
  Future<void> init({NotificationRouter? router}) async {
    _router = router;

    // Create high-importance Android channel
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);

    // Initialise local notifications
    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (details) {
        _handleTap(details.payload, {});
      },
    );

    // Request permission (iOS + Android 13+)
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Register FCM token
    await _registerToken(messaging);

    // Handle token rotation
    messaging.onTokenRefresh.listen((token) async {
      await _storage.saveFcmToken(token);
      await _sendTokenToServer(token);
    });

    // Foreground messages → local notification
    _fgSub = FirebaseMessaging.onMessage.listen((message) {
      _showLocalNotification(message);
    });

    // Background tap (app was in background, user tapped notification)
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleTap(message.data['route'] as String?, message.data);
    });

    // Terminated tap (app launched via notification)
    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      // Delay so router is ready after widget tree mounts
      Future.delayed(const Duration(milliseconds: 500), () {
        _handleTap(initial.data['route'] as String?, initial.data);
      });
    }
  }

  Future<void> _registerToken(FirebaseMessaging messaging) async {
    try {
      final token = await messaging.getToken();
      if (token != null) {
        await _storage.saveFcmToken(token);
        await _sendTokenToServer(token);
      }
    } catch (e) {
      debugPrint('[FCM] Token registration failed: $e');
    }
  }

  // Override this in each app to POST the token to /api/users/fcm-token
  Future<void> _sendTokenToServer(String token) async {
    // Implemented per-app via FcmService subclass or post-init hook.
    debugPrint('[FCM] Token: $token');
  }

  void _handleTap(String? route, Map<String, dynamic> data) {
    _router?.call(route, data);
  }

  /// Call on logout to unregister the device.
  Future<void> clearToken() async {
    try {
      await FirebaseMessaging.instance.deleteToken();
      await _storage.clearFcmToken();
    } catch (_) {}
  }

  void dispose() {
    _fgSub?.cancel();
  }
}

final fcmServiceProvider = Provider<FcmService>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return FcmService(storage);
});
