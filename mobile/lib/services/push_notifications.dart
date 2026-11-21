import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'auth_service.dart';
import 'notification_inbox.dart';

@pragma('vm:entry-point')
Future<void> careBackgroundMessage(RemoteMessage message) async {
  await initializeCareFirebase();
}

Future<FirebaseApp> initializeCareFirebase() => Firebase.initializeApp(
  options: const String.fromEnvironment('FIREBASE_APP_ID') == ''
      ? null
      : const FirebaseOptions(
          apiKey: String.fromEnvironment('FIREBASE_API_KEY'),
          appId: String.fromEnvironment('FIREBASE_APP_ID'),
          messagingSenderId: String.fromEnvironment('FIREBASE_SENDER_ID'),
          projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
          iosBundleId: String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID'),
        ),
);

/// Opt-in configuration: builds without Firebase keep a working in-app inbox.
class PushNotifications {
  static final instance = PushNotifications();
  bool _ready = false;
  Future<void> Function(String?)? onOpen;
  void Function(RemoteMessage)? onForegroundMessage;
  Future<void> initialize() async {
    if (_ready ||
        kIsWeb ||
        ![
          TargetPlatform.android,
          TargetPlatform.iOS,
        ].contains(defaultTargetPlatform)) {
      return;
    }
    try {
      debugPrint('[FCM] Đang khởi tạo Firebase...');
      await initializeCareFirebase();
      FirebaseMessaging.onBackgroundMessage(careBackgroundMessage);
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );
      FirebaseMessaging.onMessage.listen((message) {
        NotificationInbox.instance.refresh();
        onForegroundMessage?.call(message);
      });
      FirebaseMessaging.onMessageOpenedApp.listen(
        (message) => onOpen?.call(message.data['notification_id']),
      );
      FirebaseMessaging.instance.onTokenRefresh.listen(
        (token) => _register(token).catchError((_) {}),
      );
      _ready = true;
      debugPrint('[FCM] Firebase đã khởi tạo thành công.');

      // Lấy và hiển thị FCM Token ngay khi khởi tạo
      try {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          debugPrint('====================================');
          debugPrint('[FCM Token] $token');
          debugPrint('====================================');
          await _register(token);
        }
      } catch (tokenErr) {
        debugPrint('[FCM] Chưa lấy được Token: $tokenErr');
      }

      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) await onOpen?.call(initial.data['notification_id']);
    } catch (e, stack) {
      debugPrint('[FCM Error] Không thể khởi tạo Firebase: $e');
      debugPrint(stack.toString());
    }
  }

  Future<void> _register(String token) async {
    debugPrint('[FCM Token] $token');
    if (!NotificationInbox.instance.available) return;
    await AuthService.instance.authorizedRequest(
      'PUT',
      '/notifications/device',
      body: {
        'token': token,
        'platform': defaultTargetPlatform == TargetPlatform.iOS
            ? 'ios'
            : 'android',
      },
    );
  }

  Future<bool> enable() async {
    await initialize();
    if (!_ready) return false;
    try {
      final permission = await FirebaseMessaging.instance.requestPermission();
      if (permission.authorizationStatus != AuthorizationStatus.authorized &&
          permission.authorizationStatus != AuthorizationStatus.provisional) {
        return false;
      }
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return false;
      await _register(token);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> sync() async {
    await initialize();
    if (!_ready) return;
    try {
      final permission = await FirebaseMessaging.instance
          .getNotificationSettings();
      if (permission.authorizationStatus == AuthorizationStatus.authorized ||
          permission.authorizationStatus == AuthorizationStatus.provisional) {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) await _register(token);
      }
    } catch (_) {}
  }
}
