import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:kortex/src/core/networking/api/app_api_endpoint.dart';
import 'package:kortex/src/core/services/notification_background_handler.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

// ── Channel IDs (single source of truth) ──────────────────────────────────────

/// Service managing push notifications, device token synchronization,
/// local notification display, and scheduled study reminders.
class NotificationService {
  NotificationService({
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
    Dio? dio,
  })  : _messaging = messaging,
        _localNotifications =
            localNotifications ?? FlutterLocalNotificationsPlugin(),
        _dio = dio;

  // ── Channel constants ────────────────────────────────────────────────────────

  /// General app channel — document processing, system events.
  static const String channelGeneral = 'kortex_general';

  /// Study reminders channel — spaced repetition due, scheduled review alerts.
  static const String channelStudyReminders = 'kortex_study_reminders';

  /// Streak channel — daily streak reminders, milestone celebrations.
  static const String channelStreak = 'kortex_streak';

  /// Social channel — quiz duels, challenges, results.
  static const String channelSocial = 'kortex_social';

  /// Returns the human-readable name for a channel ID.
  static String channelName(String channelId) {
    switch (channelId) {
      case channelStudyReminders:
        return 'Study Reminders';
      case channelStreak:
        return 'Streak & Milestones';
      case channelSocial:
        return 'Social & Challenges';
      default:
        return 'Kortex Notifications';
    }
  }

  /// Returns the description for a channel ID.
  static String channelDescription(String channelId) {
    switch (channelId) {
      case channelStudyReminders:
        return 'Daily spaced repetition reminders and scheduled review alerts';
      case channelStreak:
        return 'Streak protection reminders and milestone celebrations';
      case channelSocial:
        return 'Quiz duel challenges, invitations, and results';
      default:
        return 'Document processing, system events, and general updates';
    }
  }

  // ── Fields ───────────────────────────────────────────────────────────────────

  FirebaseMessaging? _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;
  final Dio? _dio;

  bool _initialized = false;
  bool _permissionRequested = false;

  final StreamController<RemoteMessage> _messageStreamController =
      StreamController<RemoteMessage>.broadcast();
  final StreamController<String> _payloadStreamController =
      StreamController<String>.broadcast();

  Stream<RemoteMessage> get onMessage => _messageStreamController.stream;
  Stream<String> get onPayloadTapped => _payloadStreamController.stream;

  Dio? get _effectiveDio {
    if (_dio != null) return _dio;
    try {
      if (locator.isRegistered<Dio>()) return locator<Dio>();
    } on Object catch (_) {}
    return null;
  }

  bool get _isAvailable {
    try {
      if (Firebase.apps.isEmpty) return false;
      _messaging ??= FirebaseMessaging.instance;
      return true;
    } on Object catch (_) {
      return false;
    }
  }

  // ── Initialization ───────────────────────────────────────────────────────────

  /// Initialize local notifications, Firebase Messaging listeners, and
  /// the timezone database required for [scheduleStudyReminder].
  Future<void> initialize() async {
    if (_initialized) return;

    // 1. Bootstrap timezone database for zonedSchedule.
    try {
      tz_data.initializeTimeZones();
      final deviceTz = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(deviceTz));
    } on Object catch (e) {
      developer.log('NotificationService: timezone init failed: $e');
    }

    // 2. Create the 4 Android notification channels.
    if (!kIsWeb && Platform.isAndroid) {
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await _createAndroidChannels(androidPlugin);
      }
    }

    // 3. Initialize FlutterLocalNotificationsPlugin.
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
      developer.log('NotificationService: local notifications init failed: $e');
    }

    // 4. Setup Firebase Messaging listeners.
    if (_isAvailable) {
      try {
        FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler,
        );

        // 4a. Handle cold-start notification tap (app terminated).
        final initialMessage = await _messaging!.getInitialMessage();
        if (initialMessage != null) {
          developer.log(
            'NotificationService: app opened from terminated state via '
            'notification: ${initialMessage.data}',
          );
          final route = initialMessage.data['route']?.toString();
          if (route != null && route.isNotEmpty) {
            // Delayed to allow router to be ready after startup.
            Future<void>.delayed(const Duration(milliseconds: 500), () {
              if (!_payloadStreamController.isClosed) {
                _payloadStreamController.add(route);
              }
            });
          }
        }

        // 4b. Foreground messages — show heads-up notification.
        FirebaseMessaging.onMessage.listen((message) {
          developer.log(
            'NotificationService: foreground message '
            '${message.notification?.title}',
          );
          _messageStreamController.add(message);

          final notification = message.notification;
          if (notification != null) {
            final action = message.data['action']?.toString();
            final route = message.data['route']?.toString();
            final channelId = _resolveChannelId(action);
            unawaited(
              showLocalNotification(
                id: notification.hashCode,
                title: notification.title ?? 'Kortex',
                body: notification.body ?? '',
                payload: route ?? message.data.toString(),
                channelId: channelId,
              ),
            );
          }
        });

        // 4c. Background tap — app was backgrounded (not terminated).
        FirebaseMessaging.onMessageOpenedApp.listen((message) {
          developer.log(
            'NotificationService: app opened via notification: ${message.data}',
          );
          final route = message.data['route']?.toString();
          if (route != null && route.isNotEmpty) {
            _payloadStreamController.add(route);
          }
        });
      } on Object catch (e) {
        developer.log(
          'NotificationService: Firebase Messaging setup failed: $e',
        );
      }
    }

    _initialized = true;
  }

  Future<void> _createAndroidChannels(
    AndroidFlutterLocalNotificationsPlugin plugin,
  ) async {
    final channels = [
      const AndroidNotificationChannel(
        channelGeneral,
        'Kortex Notifications',
        description: 'Document processing, system events, and general updates',
      ),
      const AndroidNotificationChannel(
        channelStudyReminders,
        'Study Reminders',
        description: 'Daily spaced repetition reminders and scheduled review alerts',
        importance: Importance.high,
      ),
      const AndroidNotificationChannel(
        channelStreak,
        'Streak & Milestones',
        description: 'Streak protection reminders and milestone celebrations',
        importance: Importance.high,
      ),
      const AndroidNotificationChannel(
        channelSocial,
        'Social & Challenges',
        description: 'Quiz duel challenges, invitations, and results',
        importance: Importance.high,
      ),
    ];

    for (final channel in channels) {
      try {
        await plugin.createNotificationChannel(channel);
      } on Object catch (e) {
        developer.log(
          'NotificationService: failed to create channel ${channel.id}: $e',
        );
      }
    }
  }

  // ── Permissions ──────────────────────────────────────────────────────────────

  StreamSubscription<String>? _tokenRefreshSubscription;

  /// Request push notification permissions from user.
  Future<NotificationSettings?> requestPermission() async {
    await requestLocalPermission();
    if (!_isAvailable) return null;
    try {
      final settings = await _messaging!.requestPermission();
      developer.log(
        'NotificationService: permission status '
        '${settings.authorizationStatus}',
      );
      return settings;
    } on Object catch (e) {
      developer.log('NotificationService: error requesting permissions: $e');
      return null;
    }
  }

  // ── FCM Token ────────────────────────────────────────────────────────────────

  /// Retrieve the current FCM token for this device.
  Future<String?> getToken() async {
    if (!_isAvailable) return null;
    try {
      if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
        final apnsToken = await _messaging!.getAPNSToken();
        if (apnsToken == null) {
          developer.log(
            'NotificationService: APNS token not available yet; '
            'FCM token sync will retry on refresh',
          );
          return null;
        }
      }
      return await _messaging!.getToken();
    } on Object catch (e) {
      developer.log('NotificationService: failed to fetch FCM token: $e');
      return null;
    }
  }

  /// Sets up a listener for token refresh events to keep Supabase synced.
  void setupTokenRefreshListener([String? userId]) {
    final effectiveUserId = (userId != null && userId.isNotEmpty)
        ? userId
        : (locator.isRegistered<UserStorageService>()
            ? locator<UserStorageService>().getUserId() ?? ''
            : '');
    if (!_isAvailable || effectiveUserId.isEmpty) return;
    unawaited(_tokenRefreshSubscription?.cancel());
    try {
      _tokenRefreshSubscription =
          _messaging!.onTokenRefresh.listen((newToken) {
        developer.log('NotificationService: FCM token refreshed');
        unawaited(syncDeviceTokenWithBackend(userId: effectiveUserId));
      });
    } on Object catch (e) {
      developer.log(
        'NotificationService: failed to setup token refresh listener: $e',
      );
    }
  }

  /// Synchronize the active FCM device registration token with the Supabase backend.
  ///
  /// Only requests notification permissions the first time it is called (guarded
  /// by [_permissionRequested]) to avoid re-prompting users on every launch.
  Future<bool> syncDeviceTokenWithBackend({
    String? userId,
    Dio? dio,
  }) async {
    final effectiveUserId = (userId != null && userId.isNotEmpty)
        ? userId
        : (locator.isRegistered<UserStorageService>()
            ? locator<UserStorageService>().getUserId() ?? ''
            : '');
    if (effectiveUserId.isEmpty) return false;
    try {
      // Only prompt for permissions once per app lifecycle.
      if (!_permissionRequested) {
        _permissionRequested = true;
        await requestPermission();
      }

      final token = await getToken();
      if (token == null || token.isEmpty) return false;

      setupTokenRefreshListener(effectiveUserId);

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
        'NotificationService: device token synced for user '
        '$effectiveUserId (HTTP ${response.statusCode})',
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } on Object catch (e) {
      developer.log(
        'NotificationService: failed to sync device token: $e',
      );
      return false;
    }
  }

  // ── Local Notification Display ───────────────────────────────────────────────

  /// Show a local notification immediately.
  ///
  /// [channelId] specifies which Android notification channel to use.
  /// Defaults to [channelGeneral] if not specified.
  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String channelId = channelGeneral,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName(channelId),
      channelDescription: channelDescription(channelId),
      importance: Importance.max,
      priority: Priority.high,
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      presentBanner: true,
      presentList: true,
    );
    final platformDetails = NotificationDetails(
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
      developer.log('NotificationService: failed to show notification: $e');
    }
  }

  // ── Scheduled Notifications ──────────────────────────────────────────────────

  /// Notification ID reserved for the daily study reminder.
  static const int studyReminderNotificationId = 1001;

  /// Schedule a recurring daily study reminder at [hour]:[minute] (local time).
  ///
  /// Cancels any previously scheduled reminder (ID [studyReminderNotificationId])
  /// before scheduling the new one, ensuring only one reminder is ever active.
  ///
  /// The notification will fire at the first upcoming occurrence of [hour]:[minute]
  /// and repeat daily thereafter via [DateTimeComponents.time].
  Future<void> scheduleStudyReminder({
    required int hour,
    required int minute,
    String title = 'Time to review! 🧠',
    String body = 'You have cards due. Keep your streak alive!',
    String payload = '/study',
  }) async {
    // Cancel any existing reminder first.
    await cancelStudyReminder();

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // If the time has already passed today, schedule for tomorrow.
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final androidDetails = AndroidNotificationDetails(
      channelStudyReminders,
      channelName(channelStudyReminders),
      channelDescription: channelDescription(channelStudyReminders),
      importance: Importance.high,
      priority: Priority.high,
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    final platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    try {
      await _localNotifications.zonedSchedule(
        studyReminderNotificationId,
        title,
        body,
        scheduledDate,
        platformDetails,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      developer.log(
        'NotificationService: study reminder scheduled at '
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} local',
      );
    } on Object catch (e) {
      developer.log(
        'NotificationService: failed to schedule study reminder: $e',
      );
    }
  }

  /// Cancel the active scheduled daily study reminder.
  Future<void> cancelStudyReminder() async {
    try {
      await _localNotifications.cancel(studyReminderNotificationId);
    } on Object catch (e) {
      developer.log(
        'NotificationService: failed to cancel study reminder: $e',
      );
    }
  }

  // ── Local Permissions ────────────────────────────────────────────────────────

  /// Request local notification permissions on iOS/macOS and Android.
  Future<bool?> requestLocalPermission() async {
    try {
      if (!kIsWeb && Platform.isIOS) {
        return await _localNotifications
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            );
      } else if (!kIsWeb && Platform.isMacOS) {
        return await _localNotifications
            .resolvePlatformSpecificImplementation<
                MacOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            );
      } else if (!kIsWeb && Platform.isAndroid) {
        return await _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }
    } on Object catch (e) {
      developer.log(
        'NotificationService: error requesting local permission: $e',
      );
    }
    return null;
  }

  // ── Lifecycle Notifications ──────────────────────────────────────────────────

  /// Send a local notification when document processing completes.
  Future<void> notifyDocumentProcessingComplete({
    required String filename,
    int? cardCount,
    String? documentId,
    String? deckId,
  }) async {
    final countText = (cardCount != null && cardCount > 0)
        ? ' ($cardCount conceptual cards synthesized)'
        : '';
    final body = '"$filename" is ready$countText. Tap to review and study.';
    final payload = deckId != null
        ? 'deck:$deckId'
        : (documentId != null ? 'doc:$documentId' : '/ingestion');

    await showLocalNotification(
      id: documentId != null
          ? documentId.hashCode
          : DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: 'Document Ready! ⚡',
      body: body,
      payload: payload,
    );
  }

  /// Send a local notification when document processing fails.
  Future<void> notifyDocumentProcessingFailed({
    required String filename,
    String? documentId,
    String? reason,
  }) async {
    final body = reason != null && reason.isNotEmpty
        ? '"$filename" could not be processed: $reason'
        : '"$filename" could not be processed. Please try again.';

    await showLocalNotification(
      id: documentId != null
          ? documentId.hashCode ^ 0xF
          : DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: 'Processing Failed',
      body: body,
      payload: '/ingestion',
    );
  }

  // ── Topic Management ─────────────────────────────────────────────────────────

  /// Subscribe device to a notification topic (e.g. forum thread notifications).
  Future<bool> subscribeToTopic(String topic) async {
    if (!_isAvailable) return false;
    try {
      final sanitizedTopic =
          topic.replaceAll(RegExp('[^a-zA-Z0-9-_.~%]'), '_');
      await _messaging!.subscribeToTopic(sanitizedTopic);
      developer.log(
        'NotificationService: subscribed to topic $sanitizedTopic',
      );
      return true;
    } on Object catch (e) {
      developer.log(
        'NotificationService: failed to subscribe to topic $topic: $e',
      );
      return false;
    }
  }

  /// Unsubscribe device from a notification topic.
  Future<bool> unsubscribeFromTopic(String topic) async {
    if (!_isAvailable) return false;
    try {
      final sanitizedTopic =
          topic.replaceAll(RegExp('[^a-zA-Z0-9-_.~%]'), '_');
      await _messaging!.unsubscribeFromTopic(sanitizedTopic);
      developer.log(
        'NotificationService: unsubscribed from topic $sanitizedTopic',
      );
      return true;
    } on Object catch (e) {
      developer.log(
        'NotificationService: failed to unsubscribe from $topic: $e',
      );
      return false;
    }
  }

  /// Cancel all pending and scheduled local notifications.
  Future<void> cancelAllNotifications() async {
    try {
      await _localNotifications.cancelAll();
    } on Object catch (e) {
      developer.log(
        'NotificationService: failed to cancel all notifications: $e',
      );
    }
  }

  void dispose() {
    unawaited(_tokenRefreshSubscription?.cancel());
    unawaited(_messageStreamController.close());
    unawaited(_payloadStreamController.close());
  }
}

/// Maps a FCM `action` payload field to the appropriate local channel ID.
String _resolveChannelId(String? action) {
  switch (action) {
    case 'spaced_repetition_due':
    case 'study_reminder':
      return NotificationService.channelStudyReminders;
    case 'daily_streak_reminder':
    case 'streak_milestone':
      return NotificationService.channelStreak;
    case 'quiz_duel_challenge':
    case 'quiz_duel_result':
      return NotificationService.channelSocial;
    default:
      return NotificationService.channelGeneral;
  }
}
