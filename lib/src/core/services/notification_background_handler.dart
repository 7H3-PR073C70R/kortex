import 'dart:developer' as developer;
import 'package:firebase_messaging/firebase_messaging.dart';

/// Top-level background message handler for Firebase Messaging.
/// Must be annotated with `@pragma('vm:entry-point')`.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  developer.log('Handling background notification: ${message.messageId}');
}
