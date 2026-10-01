import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';
import 'package:kortex/src/features/notifications/domain/entities/notification_item_entity.dart';
import 'package:kortex/src/features/study_rooms/domain/entities/study_room_entity.dart';

/// Centralized router for parsing notification payloads and executing deep-linking.
class NotificationRouter {
  const NotificationRouter();

  /// Routes a raw string payload (from FCM, local notifications, or deep links)
  /// to the appropriate screen using [AutoRouter].
  Future<bool> handlePayloadString({
    required StackRouter router,
    required String payload,
  }) async {
    final clean = _cleanPayload(payload);
    if (clean.isEmpty) return false;

    debugPrint('[NotificationRouter] Handling payload string: "$clean"');

    try {
      // 1. Dashboard (pop to root)
      if (clean == '/dashboard' || clean == 'dashboard') {
        router.popUntilRoot();
        return true;
      }

      // 2. Planner / Exam timetable
      if (clean == '/planner' ||
          clean == 'planner' ||
          clean.startsWith('/exam') ||
          clean.startsWith('exam:') ||
          clean == '/timetable') {
        await router.push(const ExamTimetableRoute());
        return true;
      }

      // 3. Decks root
      if (clean == '/decks' || clean == 'decks') {
        await router.push(const DecksRoute());
        return true;
      }

      // 4. Past Questions
      if (clean == '/past-questions' || clean == 'past-questions') {
        await router.push(PastQuestionsBoardRoute());
        return true;
      }

      // 5. Ingestion / Document synthesis
      if (clean == '/ingestion' ||
          clean == 'ingestion' ||
          clean.startsWith('doc:')) {
        await router.push(DocumentIngestionRoute());
        return true;
      }

      // 6. Syllabot Chat
      if (clean == '/chat' ||
          clean == 'chat' ||
          clean == 'syllabot' ||
          clean == '/syllabot' ||
          clean == '/syllabot-chat') {
        await router.push(SyllabotChatRoute());
        return true;
      }

      // 7. Paywall / Subscription
      if (clean == '/paywall' ||
          clean == 'paywall' ||
          clean == '/subscription' ||
          clean == 'subscription') {
        await router.push(PaywallRoute());
        return true;
      }

      // 8. Notifications screen
      if (clean == '/notifications' || clean == 'notifications') {
        await router.push(const NotificationsRoute());
        return true;
      }

      // 9. Leaderboard
      if (clean == '/leaderboard' || clean == 'leaderboard') {
        await router.push(const LeaderboardRoute());
        return true;
      }

      // 10. Analytics
      if (clean == '/analytics' || clean == 'analytics') {
        await router.push(const AnalyticsDetailRoute());
        return true;
      }

      // 11. Curate Courses
      if (clean == '/courses' || clean == 'courses') {
        await router.push(CurateCoursesRoute());
        return true;
      }

      // 12. Create Deck
      if (clean == '/create-deck' || clean == 'create-deck') {
        await router.push(CreateDeckRoute());
        return true;
      }

      // 13. Settings / Preferences
      if (clean == '/settings' ||
          clean == 'settings' ||
          clean == '/preferences' ||
          clean == 'preferences') {
        await router.push(const AppPreferencesRoute());
        return true;
      }

      // 14. Deck prefixed routes: deck:123 or deck:123:study
      if (clean.startsWith('deck:')) {
        final parts = clean.substring(5).split(':');
        final deckId = parts.first;
        final mode = parts.length > 1 ? parts[1] : '';
        if (mode == 'study') {
          await router.push(StudySessionRoute(deckId: deckId));
        } else {
          await router.push(DeckDetailRoute(deckId: deckId));
        }
        return true;
      }

      // 15. Study prefixed routes: study:123
      if (clean.startsWith('study:')) {
        final deckId = clean.substring(6);
        await router.push(StudySessionRoute(deckId: deckId));
        return true;
      }

      // 16. Study Session routes (e.g. /study-session?deckId=xxx or /study?deckId=xxx)
      if (clean == '/study' ||
          clean == 'study' ||
          clean == '/study-session' ||
          clean.startsWith('/study-session?') ||
          clean.startsWith('/study?')) {
        final uri = Uri.tryParse(clean);
        final deckId = uri?.queryParameters['deckId'] ??
            uri?.queryParameters['deck_id'];
        if (deckId != null && deckId.isNotEmpty) {
          await router.push(StudySessionRoute(deckId: deckId));
        } else {
          await router.push(const DecksRoute());
        }
        return true;
      }

      // 17. Deck Detail route (/deck-detail?deckId=xxx or /deck-detail?documentId=xxx)
      if (clean == '/deck-detail' || clean.startsWith('/deck-detail?')) {
        final uri = Uri.tryParse(clean);
        final deckId = uri?.queryParameters['deckId'] ??
            uri?.queryParameters['deck_id'];
        final documentId = uri?.queryParameters['documentId'] ??
            uri?.queryParameters['document_id'];
        if (deckId != null && deckId.isNotEmpty) {
          await router.push(DeckDetailRoute(deckId: deckId));
        } else if (documentId != null && documentId.isNotEmpty) {
          await router.push(DocumentIngestionRoute());
        } else {
          await router.push(const DecksRoute());
        }
        return true;
      }

      // 18. Forum Thread detail: /forum/post/$postId or forum:$postId
      if (clean.startsWith('/forum/post/') || clean.startsWith('forum:')) {
        final postId = clean.startsWith('/forum/post/')
            ? clean.substring('/forum/post/'.length)
            : clean.substring('forum:'.length);
        if (postId.isNotEmpty) {
          return _navigateToForumPost(router, postId);
        }
        await router.push(const CommunityHubRoute());
        return true;
      }

      // 19. Live Study Room: /study-room?roomId=xxx or room:xxx
      if (clean == '/study-room' ||
          clean.startsWith('/study-room?') ||
          clean.startsWith('room:')) {
        final uri = Uri.tryParse(clean);
        final roomId = clean.startsWith('room:')
            ? clean.substring(5)
            : (uri?.queryParameters['roomId'] ??
                uri?.queryParameters['room_id']);
        if (roomId != null && roomId.isNotEmpty) {
          final room = StudyRoomEntity(
            id: roomId,
            title: uri?.queryParameters['title'] ?? 'Live Study Room',
            subject: uri?.queryParameters['subject'] ?? 'Academic Co-Working',
            createdBy: uri?.queryParameters['hostId'] ?? 'host-user',
          );
          await router.push(LiveStudyRoomRoute(room: room));
          return true;
        }
        await router.push(const StudyHubRoute());
        return true;
      }

      // 20. Quiz Duel: /quiz-duel, /quiz-duel?duelId=xxx, duel:xxx
      if (clean == '/quiz-duel' ||
          clean.startsWith('/quiz-duel?') ||
          clean.startsWith('duel:') ||
          clean == 'quiz_duel' ||
          clean == 'quiz-duel') {
        final uri = Uri.tryParse(clean);
        final deckId = uri?.queryParameters['deckId'] ??
            uri?.queryParameters['deck_id'];
        if (deckId != null && deckId.isNotEmpty) {
          await router.push(QuizWorkspaceRoute(deckId: deckId));
          return true;
        }
        await router.push(const CommunityHubRoute());
        return true;
      }

      // 21. Community Hub
      if (clean == '/community' || clean == 'community') {
        await router.push(const CommunityHubRoute());
        return true;
      }

      // 22. Study Hub
      if (clean == '/study-hub' || clean == 'study-hub') {
        await router.push(const StudyHubRoute());
        return true;
      }

      // Generic fallback for standard slash paths
      if (clean.startsWith('/')) {
        await router.pushPath(clean);
        return true;
      }

      return false;
    } on Object catch (err) {
      debugPrint('[NotificationRouter] Payload routing error: $err');
      return false;
    }
  }

  /// Routes a notification item entity to the appropriate screen using AutoRouter.
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
      // 1. If explicit actionRoute is provided, try payload string routing first
      if (routeStr.isNotEmpty) {
        final handled = await handlePayloadString(
          router: router,
          payload: routeStr,
        );
        if (handled) return true;
      }

      // 2. Quiz Duel / Challenge
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

      // 3. Forum Reply / Community Thread
      if (routeStr.contains('forum') ||
          routeStr.contains('thread') ||
          metadata['type'] == 'forum_reply' ||
          metadata['type'] == 'forum_mention' ||
          metadata['thread_id'] != null ||
          metadata['post_id'] != null) {
        final threadId = metadata['thread_id']?.toString() ??
            metadata['post_id']?.toString() ??
            metadata['threadId']?.toString() ??
            metadata['postId']?.toString();
        final replyId = metadata['reply_id']?.toString() ??
            metadata['replyId']?.toString();

        if (threadId != null && threadId.isNotEmpty) {
          return _navigateToForumPost(router, threadId, replyId: replyId);
        }
        await router.push(const CommunityHubRoute());
        return true;
      }

      // 4. FSRS Cards Due / Spaced Repetition Study
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

      // 5. Exam Countdown / Cram Planner
      if (routeStr.contains('exam') ||
          routeStr.contains('planner') ||
          routeStr.contains('timetable') ||
          metadata['type'] == 'exam_countdown') {
        await router.push(const ExamTimetableRoute());
        return true;
      }

      // 6. Live Study Room Invite
      if (routeStr.contains('room') || metadata['type'] == 'room_invite') {
        final roomId = metadata['room_id']?.toString() ??
            metadata['roomId']?.toString();
        if (roomId != null && roomId.isNotEmpty) {
          final room = StudyRoomEntity(
            id: roomId,
            title: metadata['title']?.toString() ?? 'Live Study Room',
            subject: metadata['subject']?.toString() ?? 'Academic Co-Working',
            createdBy: metadata['host_id']?.toString() ?? 'host-user',
          );
          await router.push(LiveStudyRoomRoute(room: room));
          return true;
        }
        await router.push(const StudyHubRoute());
        return true;
      }

      // 7. Deck Marketplace Clones
      if (routeStr.contains('marketplace') ||
          metadata['type'] == 'deck_cloned') {
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

  /// Resolves the synchronous [PageRouteInfo] for a given string payload if available.
  PageRouteInfo? resolveRouteFromPayload(String payload) {
    final clean = _cleanPayload(payload);
    if (clean.isEmpty) return null;

    if (clean == '/planner' ||
        clean == 'planner' ||
        clean.startsWith('/exam') ||
        clean.startsWith('exam:')) {
      return const ExamTimetableRoute();
    }
    if (clean == '/decks' || clean == 'decks') {
      return const DecksRoute();
    }
    if (clean == '/past-questions' || clean == 'past-questions') {
      return PastQuestionsBoardRoute();
    }
    if (clean == '/ingestion' ||
        clean == 'ingestion' ||
        clean.startsWith('doc:')) {
      return DocumentIngestionRoute();
    }
    if (clean == '/chat' || clean == 'syllabot' || clean == '/syllabot') {
      return SyllabotChatRoute();
    }
    if (clean == '/paywall' || clean == '/subscription') {
      return PaywallRoute();
    }
    if (clean == '/notifications') {
      return const NotificationsRoute();
    }
    if (clean == '/leaderboard') {
      return const LeaderboardRoute();
    }
    if (clean == '/analytics') {
      return const AnalyticsDetailRoute();
    }
    if (clean == '/courses') {
      return CurateCoursesRoute();
    }
    if (clean.startsWith('study:')) {
      return StudySessionRoute(deckId: clean.substring(6));
    }
    if (clean.startsWith('deck:')) {
      final parts = clean.substring(5).split(':');
      final deckId = parts.first;
      final mode = parts.length > 1 ? parts[1] : '';
      return mode == 'study'
          ? StudySessionRoute(deckId: deckId)
          : DeckDetailRoute(deckId: deckId);
    }
    if (clean == '/study-session' || clean.startsWith('/study-session?')) {
      final uri = Uri.tryParse(clean);
      final deckId = uri?.queryParameters['deckId'] ??
          uri?.queryParameters['deck_id'];
      return deckId != null && deckId.isNotEmpty
          ? StudySessionRoute(deckId: deckId)
          : const DecksRoute();
    }
    if (clean == '/deck-detail' || clean.startsWith('/deck-detail?')) {
      final uri = Uri.tryParse(clean);
      final deckId = uri?.queryParameters['deckId'] ??
          uri?.queryParameters['deck_id'];
      return deckId != null && deckId.isNotEmpty
          ? DeckDetailRoute(deckId: deckId)
          : const DecksRoute();
    }
    if (clean == '/quiz-duel' || clean.startsWith('/quiz-duel?')) {
      final uri = Uri.tryParse(clean);
      final deckId = uri?.queryParameters['deckId'] ??
          uri?.queryParameters['deck_id'];
      return QuizWorkspaceRoute(
        deckId: deckId != null && deckId.isNotEmpty ? deckId : 'deck-default',
      );
    }
    return null;
  }

  static String _cleanPayload(String payload) {
    var clean = payload.trim();
    if (clean.startsWith('route:')) {
      clean = clean.substring(6).trim();
    }
    return clean;
  }

  static Future<bool> _navigateToForumPost(
    StackRouter router,
    String postId, {
    String? replyId,
  }) async {
    if (locator.isRegistered<CommunityRepository>()) {
      try {
        final repo = locator<CommunityRepository>();
        final treeRes = await repo.fetchForumThreadTree(postId: postId);
        final tree = treeRes.fold((_) => null, (val) => val);
        if (tree != null) {
          await router.push(
            ForumThreadDetailRoute(
              post: tree.post,
              highlightReplyId: replyId,
            ),
          );
          return true;
        }
      } on Object catch (e) {
        debugPrint('[NotificationRouter] Error fetching thread tree: $e');
      }
    }

    // Fallback: create entity placeholder so navigation succeeds even offline
    final fallbackPost = ForumPostEntity(
      id: postId,
      title: 'Academic Discussion',
      content: '',
      authorId: 'user-unknown',
      authorName: 'Scholar',
      track: 'General',
      createdAt: DateTime.now(),
    );
    await router.push(
      ForumThreadDetailRoute(
        post: fallbackPost,
        highlightReplyId: replyId,
      ),
    );
    return true;
  }
}
