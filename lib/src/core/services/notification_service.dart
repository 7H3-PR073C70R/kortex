import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:kortex/src/core/networking/api/app_api_endpoint.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/services/notification_background_handler.dart';
import 'package:kortex/src/core/services/user_activity_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/decks/domain/repositories/decks_repository.dart';

/// Service managing push notifications, device token synchronization,
/// and local notification display.
class NotificationService {
  NotificationService({
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
    Dio? dio,
  })  : _messaging = messaging,
        _localNotifications =
            localNotifications ?? FlutterLocalNotificationsPlugin(),
        _dio = dio;

  FirebaseMessaging? _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;
  final Dio? _dio;

  Dio? get _effectiveDio {
    if (_dio != null) return _dio;
    try {
      if (locator.isRegistered<Dio>()) {
        return locator<Dio>();
      }
    } on Object catch (_) {}
    return null;
  }

  bool _initialized = false;
  final StreamController<RemoteMessage> _messageStreamController =
      StreamController<RemoteMessage>.broadcast();
  final StreamController<String> _payloadStreamController =
      StreamController<String>.broadcast();

  Stream<RemoteMessage> get onMessage => _messageStreamController.stream;
  Stream<String> get onPayloadTapped => _payloadStreamController.stream;

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
          final payload = response.payload;
          developer.log('Local notification tapped with payload: $payload');
          if (payload != null && payload.isNotEmpty) {
            _payloadStreamController.add(payload);
          }
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
            final route = message.data['route']?.toString();
            unawaited(
              showLocalNotification(
                id: notification.hashCode,
                title: notification.title ?? 'Kortex',
                body: notification.body ?? '',
                payload: route ?? message.data.toString(),
              ),
            );
          }
        });

        FirebaseMessaging.onMessageOpenedApp.listen((message) {
          developer.log('App opened via notification: ${message.data}');
          final route = message.data['route']?.toString();
          if (route != null && route.isNotEmpty) {
            _payloadStreamController.add(route);
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

  /// Synchronize the active FCM device registration token with the Supabase backend.
  Future<bool> syncDeviceTokenWithBackend({
    required String userId,
    Dio? dio,
  }) async {
    if (userId.isEmpty) return false;
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) return false;

      final client = dio ?? _effectiveDio;
      if (client == null) return false;

      final platform = kIsWeb
          ? 'web'
          : Platform.isIOS
              ? 'ios'
              : Platform.isAndroid
                  ? 'android'
                  : Platform.isMacOS
                      ? 'macos'
                      : 'windows';

      final response = await client.post<dynamic>(
        '${AppApiEndpoint.baseUri}${AppApiEndpoint.registerDeviceTokenRpc}',
        data: {
          'p_fcm_token': token,
          'p_platform': platform,
          'p_device_name': kIsWeb ? 'Web Browser' : Platform.operatingSystem,
        },
      );

      developer.log(
        'Device token synced with Supabase for user $userId (HTTP ${response.statusCode})',
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } on Object catch (e) {
      developer.log('Failed to sync device token with Supabase: $e');
      return false;
    }
  }

  /// Schedule a study reminder or push alert.
  Future<void> scheduleDailyStudyReminder({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await showLocalNotification(
      id: id,
      title: title,
      body: body,
      payload: payload,
    );
  }

  /// Sends an immediate calibration notification when an exam countdown is scheduled or modified.
  Future<void> sendExamCalibrationNotification({
    required String examName,
    required int daysRemaining,
    required int dailyTarget,
  }) async {
    final title = '🎯 Exam Calibrated: $examName';
    final body = daysRemaining > 0
        ? '$daysRemaining days left. Review $dailyTarget cards daily to stay on track!'
        : 'Exam is scheduled for today! Good luck!';
    await showLocalNotification(
      id: examName.hashCode.abs() % 100000,
      title: title,
      body: body,
      payload: '/planner',
    );
  }

  /// Notify the user that flashcards in a deck are due for review before memory retention decays.
  Future<void> notifyDeckReviewDue({
    required String deckId,
    required String deckTitle,
    required int dueCount,
  }) async {
    final title = '🧠 Review Due: $deckTitle';
    final cardText = dueCount == 1 ? '1 card is' : '$dueCount cards are';
    final body = '$cardText ready for review. Practice now before memory retention decays!';
    await showLocalNotification(
      id: ('deck_due_$deckId').hashCode.abs() % 100000,
      title: title,
      body: body,
      payload: 'study:$deckId',
    );
  }

  /// Notify the user when their active study streak is about to expire.
  Future<void> notifyStreakAtRisk({
    required int currentStreak,
    required int hoursRemaining,
  }) async {
    final title = '🔥 Streak at Risk! ($currentStreak Day${currentStreak == 1 ? '' : 's'})';
    final hourText = hoursRemaining == 1 ? '1 hour' : '$hoursRemaining hours';
    final body = 'Only $hourText left today to protect your streak. Complete a quick review session before midnight!';
    await showLocalNotification(
      id: 99998,
      title: title,
      body: body,
      payload: '/decks',
    );
  }

  /// Evaluates active study streaks and due decks, sending proactive notifications if needed.
  Future<void> checkAndTriggerDueReminders() async {
    final now = DateTime.now();
    final todayKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // 1. Streak reminder check
    try {
      if (locator.isRegistered<UserActivityService>() &&
          locator.isRegistered<LocalStorageService>()) {
        final activityService = locator<UserActivityService>();
        final storage = locator<LocalStorageService>();
        final streak = activityService.getCurrentStreak();

        if (streak > 0 && !activityService.hasStudiedToday()) {
          // Check hours remaining today until midnight
          final midnight = DateTime(now.year, now.month, now.day + 1);
          final hoursRemaining = midnight.difference(now).inHours;

          if (hoursRemaining <= 7) {
            final lastStreakNotifKey = '__kortex_streak_notif_$todayKey';
            final alreadyNotified = storage.getPreference(key: lastStreakNotifKey) == 'true';
            if (!alreadyNotified) {
              await notifyStreakAtRisk(
                currentStreak: streak,
                hoursRemaining: math.max(1, hoursRemaining),
              );
              await storage.savePreference(key: lastStreakNotifKey, data: 'true');
            }
          }
        }
      }
    } on Object catch (e) {
      developer.log('Error checking streak reminder: $e');
    }

    // 2. Due decks reminder check
    try {
      if (locator.isRegistered<DecksRepository>() &&
          locator.isRegistered<LocalStorageService>()) {
        final decksRepo = locator<DecksRepository>();
        final storage = locator<LocalStorageService>();
        final decksRes = await decksRepo.getUserDecks();

        await decksRes.fold(
          (_) async {},
          (decks) async {
            final dueDecks = decks.where((d) => d.dueCards > 0).toList();
            if (dueDecks.isNotEmpty) {
              // Sort by highest due cards first
              dueDecks.sort((a, b) => b.dueCards.compareTo(a.dueCards));
              final topDeck = dueDecks.first;
              final deckNotifKey = '__kortex_deck_due_${topDeck.id}_$todayKey';
              final alreadyNotified = storage.getPreference(key: deckNotifKey) == 'true';
              if (!alreadyNotified) {
                await notifyDeckReviewDue(
                  deckId: topDeck.id,
                  deckTitle: topDeck.title,
                  dueCount: topDeck.dueCards,
                );
                await storage.savePreference(key: deckNotifKey, data: 'true');
              }
            }
          },
        );
      }
    } on Object catch (e) {
      developer.log('Error checking due decks reminder: $e');
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
    unawaited(_payloadStreamController.close());
  }
}
