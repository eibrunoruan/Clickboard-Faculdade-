import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

Future<void> handleBackgroundMessage(RemoteMessage message) async {
  debugPrint('Title : ${message.notification?.title}');
  debugPrint('Body : ${message.notification?.body}');
  debugPrint('Payload : ${message.data}');
}

class FirebaseMessagingApi {
  final _firebaseMessaging = FirebaseMessaging.instance;

  Future<void> initNotifications() async {
    await _firebaseMessaging.requestPermission();
    await initPushNotifications();
    await initLocalNotification();
    await _logFcmToken();
  }

  Future<void> _logFcmToken() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        final apnsToken = await _firebaseMessaging.getAPNSToken();
        if (apnsToken == null) {
          debugPrint('APNS token is not available yet; skipping FCM token.');
          return;
        }
      }

      final fcmToken = await _firebaseMessaging.getToken();
      debugPrint('TOKEN : $fcmToken');
    } on FirebaseException catch (e) {
      if (e.code == 'apns-token-not-set') {
        debugPrint('APNS token is not available yet; skipping FCM token.');
        return;
      }
      rethrow;
    }
  }

  Future<void> initPushNotifications() async {
    await _firebaseMessaging.setForegroundNotificationPresentationOptions(
        alert: true, badge: true, sound: true);
    _firebaseMessaging.getInitialMessage().then(handleMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(handleMessage);
    FirebaseMessaging.onBackgroundMessage(handleBackgroundMessage);
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;
      _localNotifications.show(
          id: notification.hashCode,
          title: notification.title,
          body: notification.body,
          notificationDetails: NotificationDetails(
              android: AndroidNotificationDetails(
                  _androidChannel.id, _androidChannel.name,
                  icon: '@drawable/ic_launcher')),
          payload: jsonEncode(message.toMap()));
    });
  }

  void handleMessage(RemoteMessage? message) {
    if (message == null) return;
    //TODO: Navigator
  }

  final _localNotifications = FlutterLocalNotificationsPlugin();
  final _androidChannel = const AndroidNotificationChannel(
      'high_importance_channel', 'High Importance Notifications',
      description: 'This Channel is used for important notifications',
      importance: Importance.defaultImportance);

  Future<void> initLocalNotification() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@drawable/ic_launcher');
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings();
    const InitializationSettings initializationSettings =
        InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsDarwin,
            macOS: initializationSettingsDarwin);
    await _localNotifications.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: onDidReceiveNotificationResponse);
    final platform = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await platform?.createNotificationChannel(_androidChannel);
  }

  void onDidReceiveNotificationResponse(
      NotificationResponse notificationResponse) async {
    if (notificationResponse.payload != null) {
      final message =
          RemoteMessage.fromMap(jsonDecode(notificationResponse.payload!));
      handleMessage(message);
    }
  }
}
