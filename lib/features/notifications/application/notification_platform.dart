import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Thin boundary for native operations; keeps service tests off method channels.
abstract class NotificationPlatform {
  Stream<RemoteMessage> get messages;
  Stream<RemoteMessage> get openedMessages;
  Stream<String> get tokenRefresh;
  Future<void> initializeLocal(void Function(NotificationResponse) onTap);
  Future<NotificationResponse?> initialLocalResponse();
  Future<RemoteMessage?> initialMessage();
  Future<AuthorizationStatus> requestPermission();
  Future<String?> getToken();
  Future<void> showLocal(RemoteMessage message);
}

class DeviceNotificationPlatform implements NotificationPlatform {
  final _local = FlutterLocalNotificationsPlugin();
  static const _channel = AndroidNotificationChannel(
    'celtas_default',
    'Celtas',
    description: 'Novedades de tus pedidos y cupones',
    importance: Importance.high,
  );

  @override
  Stream<RemoteMessage> get messages => FirebaseMessaging.onMessage;
  @override
  Stream<RemoteMessage> get openedMessages =>
      FirebaseMessaging.onMessageOpenedApp;
  @override
  Stream<String> get tokenRefresh => FirebaseMessaging.instance.onTokenRefresh;

  @override
  Future<void> initializeLocal(
    void Function(NotificationResponse) onTap,
  ) async {
    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_stat_celtas'),
        // Only the explicit Firebase permission flow may ask the user.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: onTap,
    );
  }

  @override
  Future<NotificationResponse?> initialLocalResponse() async {
    final details = await _local.getNotificationAppLaunchDetails();
    return details?.didNotificationLaunchApp == true
        ? details?.notificationResponse
        : null;
  }

  @override
  Future<RemoteMessage?> initialMessage() =>
      FirebaseMessaging.instance.getInitialMessage();
  @override
  Future<AuthorizationStatus> requestPermission() async =>
      (await FirebaseMessaging.instance.requestPermission())
          .authorizationStatus;
  @override
  Future<String?> getToken() => FirebaseMessaging.instance.getToken();

  @override
  Future<void> showLocal(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    await _local.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
  }
}
