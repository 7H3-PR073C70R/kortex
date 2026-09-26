import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/features/notifications/domain/entities/notification_item_entity.dart';

/// Centralized router for parsing notification payloads and executing deep-linking.
class NotificationRouter {
  const NotificationRouter();

  /// Routes a notification payload or action route to the appropriate screen using AutoRouter.
  Future<bool> handleNotificationNavigation({
    required StackRouter router,
    required NotificationItemEntity notification,
  }) async {
    final routeStr = notification.actionRoute?.trim() ?? '';
    final metadata = notification.metadata ?? {};

    debugPrint(
      '[NotificationRouter] Deep-linking notification (id: ${notification.id}, '
      'category: ${notification.category.name}, actionRoute: $routeStr)',
    );

    try {
      // 1. Quiz Duel / Challenge
      if (routeStr.contains('duel') ||
          routeStr.contains('quiz_duel') ||
          metadata['type'] == 'quiz_duel_challenge' ||
          metadata['type'] == 'quiz_duel') {
        final deckId = metadata['deck_id']?.toString() ??
            metadata['deckId']?.toString() ??
            'deck-default';
        await router.push(QuizWorkspaceRoute(deckId: deckId));
        return true;
      }

      // 2. Forum Reply / Community Thread
      if (routeStr.contains('forum') ||
          routeStr.contains('thread') ||
          metadata['type'] == 'forum_reply' ||
          metadata['thread_id'] != null) {
        await router.push(const CommunityHubRoute());
        return true;
      }

      // 3. FSRS Cards Due / Spaced Repetition Study
      if (routeStr.contains('study') ||
          routeStr.contains('fsrs') ||
          routeStr.contains('deck') ||
          metadata['type'] == 'review_due' ||
          metadata['type'] == 'fsrs_due' ||
          metadata['deck_id'] != null) {
        final deckId = metadata['deck_id']?.toString() ??
            metadata['deckId']?.toString() ??
            '';
        if (deckId.isNotEmpty) {
          await router.push(StudySessionRoute(deckId: deckId));
          return true;
        }
      }

      // 4. Exam Countdown / Cram Planner
      if (routeStr.contains('exam') ||
          routeStr.contains('planner') ||
          routeStr.contains('timetable') ||
          metadata['type'] == 'exam_countdown') {
        await router.push(const ExamTimetableRoute());
        return true;
      }

      // 5. Live Study Room Invite
      if (routeStr.contains('room') || metadata['type'] == 'room_invite') {
        await router.push(const StudyHubRoute());
        return true;
      }

      // 6. Deck Marketplace Clones
      if (routeStr.contains('marketplace') || metadata['type'] == 'deck_cloned') {
        await router.push(const StudyHubRoute());
        return true;
      }

      // Fallback: If no matching deep-link route, push to Study Hub
      await router.push(const StudyHubRoute());
      return true;
    } on Object catch (err) {
      debugPrint('[NotificationRouter] Routing error: $err');
      return false;
    }
  }
}
