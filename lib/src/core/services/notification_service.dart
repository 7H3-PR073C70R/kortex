import 'dart:async';
import 'dart:developer' as developer;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:kortex/src/core/services/notification_background_handler.dart';

/// Service managing push notifications and local notification display.
class NotificationService {
  NotificationService({
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  })  : _messaging = messaging,
        _localNotifications =
            localNotifications ?? FlutterLocalNotificationsPlugin();

  FirebaseMessaging? _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;

  bool _initialized = false;
  final StreamController<RemoteMessage> _messageStreamController =
      StreamController<RemoteMessage>.broadcast();

  Stream<RemoteMessage> get onMessage => _messageStreamController.stream;

  bool get _isAvailable {
    try {
      if (Firebase.apps.isEmpty) return false;
      _messaging ??= FirebaseMessaging.instance;
      return true;
    } on Object catch (_) {
      return false;
    }
  }

  /// Initialize local notifications and Firebase Messaging listeners.
  Future<void> initialize() async {
    if (_initialized) return;

    // 1. Initialize Local Notifications for foreground heads-up display
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    try {
      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          developer.log(
            'Local notification tapped with payload: ${response.payload}',
          );
        },
      );
    } on Object catch (e) {
      developer.log('Failed to initialize local notifications: $e');
    }

    // 2. Setup Firebase Messaging if available
    if (_isAvailable) {
      try {
        FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler,
        );

        FirebaseMessaging.onMessage.listen((message) {
          developer.log(
            'Received foreground notification: ${message.notification?.title}',
          );
          _messageStreamController.add(message);

          final notification = message.notification;
          if (notification != null) {
            unawaited(
              showLocalNotification(
                id: notification.hashCode,
                title: notification.title ?? 'Kortex',
                body: notification.body ?? '',
                payload: message.data.toString(),
              ),
            );
          }
        });
      } on Object catch (e) {
        developer.log('Failed to setup Firebase Messaging listeners: $e');
      }
    }

    _initialized = true;
  }

  /// Request push notification permissions from user.
  Future<NotificationSettings?> requestPermission() async {
    if (!_isAvailable) return null;
    try {
      final settings = await _messaging!.requestPermission();
      developer.log(
        'Push notification permission status: ${settings.authorizationStatus}',
      );
      return settings;
    } on Object catch (e) {
      developer.log('Error requesting notification permissions: $e');
      return null;
    }
  }

  /// Retrieve the current FCM token for this device.
  Future<String?> getToken() async {
    if (!_isAvailable) return null;
    try {
      return await _messaging!.getToken();
    } on Object catch (e) {
      developer.log('Failed to fetch FCM token: $e');
      return null;
    }
  }

  /// Show a local notification immediately.
  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'kortex_channel',
      'Kortex Notifications',
      channelDescription: 'Notifications for study sessions, cards, and updates',
      importance: Importance.max,
      priority: Priority.high,
    );
    const darwinDetails = DarwinNotificationDetails();
    const platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    try {
      await _localNotifications.show(
        id,
        title,
        body,
        platformDetails,
        payload: payload,
      );
    } on Object catch (e) {
      developer.log('Failed to show local notification: $e');
    }
  }

  void dispose() {
    unawaited(_messageStreamController.close());
  }
}
