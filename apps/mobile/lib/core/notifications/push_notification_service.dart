import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../network/api_client.dart';
import 'notification_router.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
}

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  bool _firebaseReady = false;
  bool _started = false;
  String? _currentToken;
  ApiClient? _api;

  Future<void> initializeFirebase() async {
    if (kIsWeb) return;
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      _firebaseReady = true;
    } catch (e) {
      debugPrint('Firebase init skipped: $e');
      _firebaseReady = false;
    }
  }

  Future<void> start(ApiClient api) async {
    _api = api;
    if (kIsWeb || !_firebaseReady || _started) return;
    _started = true;

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    if (Platform.isIOS) {
      await messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: true,
        sound: false,
      );
    }

    try {
      final token = await messaging.getToken();
      await _registerToken(api, token);
    } catch (e) {
      debugPrint('FCM token unavailable: $e');
    }

    messaging.onTokenRefresh.listen((token) {
      _registerToken(_api ?? api, token);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      openFromNotification(notificationDataOf(message.data));
    });

    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await openFromNotification(notificationDataOf(initial.data));
    }
  }

  Future<void> stop(ApiClient api) async {
    _started = false;
    final token = _currentToken;
    _currentToken = null;
    if (token == null || token.isEmpty) return;
    try {
      await api.deleteDeviceToken(token);
    } catch (_) {}
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
  }

  Future<void> _registerToken(ApiClient api, String? token) async {
    if (token == null || token.isEmpty) return;
    _currentToken = token;
    final platform = Platform.isIOS ? 'ios' : 'android';
    try {
      await api.upsertDeviceToken(token: token, platform: platform);
    } catch (e) {
      debugPrint('Device token upload failed: $e');
    }
  }
}
