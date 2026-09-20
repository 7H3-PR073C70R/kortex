import 'dart:developer' as developer;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:kortex/src/core/services/notification_service.dart';

/// Top-level background message handler for Firebase Messaging.
///
/// This function runs in a separate isolate. It initialises Firebase,
/// then shows a local heads-up notification via [NotificationService] so the
/// user is informed even when the app is fully backgrounded or terminated.
///
/// Must be a top-level function and annotated with `@pragma('vm:entry-point')`.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } on Object catch (e) {
    developer.log('Background isolate: Firebase init failed: $e');
    return;
  }

  developer.log(
    'Background isolate: received message ${message.messageId} '
    '— action: ${message.data['action']}',
  );

  final notification = message.notification;
  if (notification == null) return;

  // Show local heads-up so the user sees it immediately.
  final plugin = FlutterLocalNotificationsPlugin();
  const androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const darwinSettings = DarwinInitializationSettings();
  await plugin.initialize(
    const InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    ),
  );

  final channelId =
      _resolveChannelId(message.data['action']?.toString());

  await plugin.show(
    notification.hashCode,
    notification.title ?? 'Kortex',
    notification.body ?? '',
    NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        NotificationService.channelName(channelId),
        channelDescription:
            NotificationService.channelDescription(channelId),
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    ),
    payload: message.data['route']?.toString(),
  );
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
