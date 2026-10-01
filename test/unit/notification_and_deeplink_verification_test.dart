import 'package:auto_route/auto_route.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/services/dynamic_link_service.dart';
import 'package:kortex/src/core/services/notification_service.dart';
import 'package:kortex/src/features/notifications/domain/services/notification_router.dart';
import 'package:mocktail/mocktail.dart';

class MockStackRouter extends Mock implements StackRouter {}
class FakePageRouteInfo extends Fake implements PageRouteInfo<dynamic> {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockStackRouter mockRouter;
  late DynamicLinkService dynamicLinkService;
  const notificationRouter = NotificationRouter();

  setUpAll(() {
    registerFallbackValue(FakePageRouteInfo());
  });

  setUp(() {
    mockRouter = MockStackRouter();
    when(() => mockRouter.push(any())).thenAnswer((_) async => null);
    when(() => mockRouter.popUntilRoot()).thenReturn(null);
    when(() => mockRouter.pushPath(any())).thenAnswer((_) async => null);

    dynamicLinkService = DynamicLinkService();
  });

  group('NotificationService - buildPayloadFromData verification', () {
    test('merges extra keys into query parameters when route is provided', () {
      final payload = NotificationService.buildPayloadFromData({
        'route': '/study-session',
        'deckId': 'deck-math-101',
        'action': 'spaced_repetition_due',
      });

      final uri = Uri.parse(payload);
      expect(uri.path, equals('/study-session'));
      expect(uri.queryParameters['deckId'], equals('deck-math-101'));
      expect(uri.queryParameters['action'], equals('spaced_repetition_due'));
    });

    test('infers /study-session?deckId=xxx for spaced_repetition_due with deckId', () {
      final payload = NotificationService.buildPayloadFromData({
        'action': 'spaced_repetition_due',
        'deck_id': 'deck-bio-202',
      });

      expect(payload, equals('/study-session?deckId=deck-bio-202'));
    });

    test('infers /decks for spaced_repetition_due without deckId', () {
      final payload = NotificationService.buildPayloadFromData({
        'action': 'spaced_repetition_due',
      });

      expect(payload, equals('/decks'));
    });

    test('infers /dashboard for daily_streak_reminder and streak_milestone', () {
      expect(
        NotificationService.buildPayloadFromData({'action': 'daily_streak_reminder'}),
        equals('/dashboard'),
      );
      expect(
        NotificationService.buildPayloadFromData({'action': 'streak_milestone', 'streakDays': '10'}),
        equals('/dashboard'),
      );
    });

    test('infers /planner for exam_milestones and exam_countdown', () {
      expect(
        NotificationService.buildPayloadFromData({'action': 'exam_milestones', 'examId': 'exam-1'}),
        equals('/planner'),
      );
      expect(
        NotificationService.buildPayloadFromData({'action': 'exam_countdown'}),
        equals('/planner'),
      );
    });

    test('infers /quiz-duel with duelId and deckId', () {
      final payload = NotificationService.buildPayloadFromData({
        'action': 'quiz_duel_challenge',
        'duelId': 'duel-777',
        'deckId': 'deck-physics',
      });

      expect(payload, contains('/quiz-duel?'));
      expect(payload, contains('duelId=duel-777'));
      expect(payload, contains('deckId=deck-physics'));
    });

    test('infers /study-room with roomId for room_started', () {
      final payload = NotificationService.buildPayloadFromData({
        'action': 'room_started',
        'roomId': 'room-focus-42',
      });

      expect(payload, equals('/study-room?roomId=room-focus-42'));
    });

    test('infers /deck-detail with documentId for document_completed', () {
      final payload = NotificationService.buildPayloadFromData({
        'action': 'document_completed',
        'documentId': 'doc-summary-1',
      });

      expect(payload, equals('/deck-detail?documentId=doc-summary-1'));
    });

    test('infers /forum/post/xxx for forum_solution_verified and forum_reply', () {
      final payload = NotificationService.buildPayloadFromData({
        'action': 'forum_solution_verified',
        'postId': 'post-socratic-9',
      });

      expect(payload, equals('/forum/post/post-socratic-9'));
    });

    test('infers /paywall for subscription_expiry', () {
      final payload = NotificationService.buildPayloadFromData({
        'action': 'subscription_expiry',
        'daysLeft': '3',
      });

      expect(payload, equals('/paywall'));
    });
  });

  group('NotificationService - Channels definition', () {
    test('all 7 notification channels have descriptive names and descriptions', () {
      final channelIds = [
        NotificationService.channelDefault,
        NotificationService.channelGeneral,
        NotificationService.channelStudyReminders,
        NotificationService.channelStreak,
        NotificationService.channelSocial,
        NotificationService.channelSystem,
        NotificationService.channelProcessing,
      ];

      for (final id in channelIds) {
        expect(NotificationService.channelName(id), isNotEmpty);
        expect(NotificationService.channelDescription(id), isNotEmpty);
      }
    });
  });

  group('NotificationRouter - handlePayloadString verification', () {
    test('handles /dashboard by popping to root', () async {
      final handled = await notificationRouter.handlePayloadString(
        router: mockRouter,
        payload: '/dashboard',
      );

      expect(handled, isTrue);
      verify(() => mockRouter.popUntilRoot()).called(1);
    });

    test('handles route: prefix stripping correctly', () async {
      final handled = await notificationRouter.handlePayloadString(
        router: mockRouter,
        payload: 'route:/dashboard',
      );

      expect(handled, isTrue);
      verify(() => mockRouter.popUntilRoot()).called(1);
    });

    test('handles /study-session?deckId=xxx routing to StudySessionRoute', () async {
      final handled = await notificationRouter.handlePayloadString(
        router: mockRouter,
        payload: '/study-session?deckId=deck-chem-1',
      );

      expect(handled, isTrue);
      verify(
        () => mockRouter.push(
          any(that: isA<StudySessionRoute>().having((r) => r.args?.deckId, 'deckId', 'deck-chem-1')),
        ),
      ).called(1);
    });

    test('handles /study fallback routing to DecksRoute', () async {
      final handled = await notificationRouter.handlePayloadString(
        router: mockRouter,
        payload: '/study',
      );

      expect(handled, isTrue);
      verify(() => mockRouter.push(any(that: isA<DecksRoute>()))).called(1);
    });

    test('handles deck:xxx:study format routing to StudySessionRoute', () async {
      final handled = await notificationRouter.handlePayloadString(
        router: mockRouter,
        payload: 'deck:deck-geo-2:study',
      );

      expect(handled, isTrue);
      verify(
        () => mockRouter.push(
          any(that: isA<StudySessionRoute>().having((r) => r.args?.deckId, 'deckId', 'deck-geo-2')),
        ),
      ).called(1);
    });

    test('handles deck:xxx format routing to DeckDetailRoute', () async {
      final handled = await notificationRouter.handlePayloadString(
        router: mockRouter,
        payload: 'deck:deck-geo-2',
      );

      expect(handled, isTrue);
      verify(
        () => mockRouter.push(
          any(that: isA<DeckDetailRoute>().having((r) => r.args?.deckId, 'deckId', 'deck-geo-2')),
        ),
      ).called(1);
    });

    test('handles study:xxx format routing to StudySessionRoute', () async {
      final handled = await notificationRouter.handlePayloadString(
        router: mockRouter,
        payload: 'study:deck-calc-9',
      );

      expect(handled, isTrue);
      verify(
        () => mockRouter.push(
          any(that: isA<StudySessionRoute>().having((r) => r.args?.deckId, 'deckId', 'deck-calc-9')),
        ),
      ).called(1);
    });

    test('handles /planner and exam:xxx routing to ExamTimetableRoute', () async {
      final handledPlanner = await notificationRouter.handlePayloadString(
        router: mockRouter,
        payload: '/planner',
      );
      expect(handledPlanner, isTrue);
      verify(() => mockRouter.push(any(that: isA<ExamTimetableRoute>()))).called(1);

      final handledExam = await notificationRouter.handlePayloadString(
        router: mockRouter,
        payload: 'exam:exam-final-cbt',
      );
      expect(handledExam, isTrue);
      verify(() => mockRouter.push(any(that: isA<ExamTimetableRoute>()))).called(1);
    });

    test('handles /paywall and /subscription routing to PaywallRoute', () async {
      final handledPaywall = await notificationRouter.handlePayloadString(
        router: mockRouter,
        payload: '/paywall',
      );
      expect(handledPaywall, isTrue);
      verify(() => mockRouter.push(any(that: isA<PaywallRoute>()))).called(1);

      final handledSub = await notificationRouter.handlePayloadString(
        router: mockRouter,
        payload: '/subscription',
      );
      expect(handledSub, isTrue);
      verify(() => mockRouter.push(any(that: isA<PaywallRoute>()))).called(1);
    });

    test('handles /chat and route:/syllabot routing to SyllabotChatRoute', () async {
      final handled = await notificationRouter.handlePayloadString(
        router: mockRouter,
        payload: 'route:/syllabot',
      );
      expect(handled, isTrue);
      verify(() => mockRouter.push(any(that: isA<SyllabotChatRoute>()))).called(1);
    });

    test('handles /study-room?roomId=xxx routing to LiveStudyRoomRoute', () async {
      final handled = await notificationRouter.handlePayloadString(
        router: mockRouter,
        payload: '/study-room?roomId=room-algebra&title=Algebra+Focus',
      );
      expect(handled, isTrue);
      verify(
        () => mockRouter.push(
          any(that: isA<LiveStudyRoomRoute>().having((r) => r.args?.room.id, 'id', 'room-algebra')),
        ),
      ).called(1);
    });

    test('handles /forum/post/xxx routing to ForumThreadDetailRoute', () async {
      final handled = await notificationRouter.handlePayloadString(
        router: mockRouter,
        payload: '/forum/post/post-calculus-limit',
      );
      expect(handled, isTrue);
      verify(
        () => mockRouter.push(
          any(that: isA<ForumThreadDetailRoute>().having((r) => r.args?.post.id, 'id', 'post-calculus-limit')),
        ),
      ).called(1);
    });

    test('handles /quiz-duel?deckId=xxx routing to QuizWorkspaceRoute', () async {
      final handled = await notificationRouter.handlePayloadString(
        router: mockRouter,
        payload: '/quiz-duel?deckId=deck-maths-fast',
      );
      expect(handled, isTrue);
      verify(
        () => mockRouter.push(
          any(that: isA<QuizWorkspaceRoute>().having((r) => r.args?.deckId, 'deckId', 'deck-maths-fast')),
        ),
      ).called(1);
    });

    test('handles /past-questions routing to PastQuestionsBoardRoute', () async {
      final handled = await notificationRouter.handlePayloadString(
        router: mockRouter,
        payload: '/past-questions',
      );
      expect(handled, isTrue);
      verify(() => mockRouter.push(any(that: isA<PastQuestionsBoardRoute>()))).called(1);
    });

    test('handles /notifications routing to NotificationsRoute', () async {
      final handled = await notificationRouter.handlePayloadString(
        router: mockRouter,
        payload: '/notifications',
      );
      expect(handled, isTrue);
      verify(() => mockRouter.push(any(that: isA<NotificationsRoute>()))).called(1);
    });

    test('handles /leaderboard routing to LeaderboardRoute', () async {
      final handled = await notificationRouter.handlePayloadString(
        router: mockRouter,
        payload: '/leaderboard',
      );
      expect(handled, isTrue);
      verify(() => mockRouter.push(any(that: isA<LeaderboardRoute>()))).called(1);
    });

    test('handles /analytics routing to AnalyticsDetailRoute', () async {
      final handled = await notificationRouter.handlePayloadString(
        router: mockRouter,
        payload: '/analytics',
      );
      expect(handled, isTrue);
      verify(() => mockRouter.push(any(that: isA<AnalyticsDetailRoute>()))).called(1);
    });

    test('handles /courses routing to CurateCoursesRoute', () async {
      final handled = await notificationRouter.handlePayloadString(
        router: mockRouter,
        payload: '/courses',
      );
      expect(handled, isTrue);
      verify(() => mockRouter.push(any(that: isA<CurateCoursesRoute>()))).called(1);
    });

    test('handles /settings and /preferences routing to AppPreferencesRoute', () async {
      final handled = await notificationRouter.handlePayloadString(
        router: mockRouter,
        payload: '/preferences',
      );
      expect(handled, isTrue);
      verify(() => mockRouter.push(any(that: isA<AppPreferencesRoute>()))).called(1);
    });
  });

  group('DynamicLinkService - Route Resolution for DeepLinkBuilder', () {
    test('routeForPayload resolves DeckDetailRoute for deck without study mode', () {
      const payload = DynamicLinkPayload(
        type: DynamicLinkType.deck,
        targetId: 'deck-physics-1',
      );

      final route = dynamicLinkService.routeForPayload(payload);
      expect(route, isA<DeckDetailRoute>());
      if (route is DeckDetailRoute) {
        expect(route.args?.deckId, equals('deck-physics-1'));
      }
    });

    test('routeForPayload resolves StudySessionRoute for deck with study mode', () {
      const payload = DynamicLinkPayload(
        type: DynamicLinkType.deck,
        targetId: 'deck-physics-1',
        parameters: {'mode': 'study'},
      );

      final route = dynamicLinkService.routeForPayload(payload);
      expect(route, isA<StudySessionRoute>());
      if (route is StudySessionRoute) {
        expect(route.args?.deckId, equals('deck-physics-1'));
      }
    });

    test('routeForPayload resolves ForumThreadDetailRoute for forum payload', () {
      const payload = DynamicLinkPayload(
        type: DynamicLinkType.forum,
        targetId: 'post-101',
        title: 'Mechanics Discussion',
      );

      final route = dynamicLinkService.routeForPayload(payload);
      expect(route, isA<ForumThreadDetailRoute>());
      if (route is ForumThreadDetailRoute) {
        expect(route.args?.post.id, equals('post-101'));
        expect(route.args?.post.title, equals('Mechanics Discussion'));
      }
    });

    test('routeForPayload resolves QuizWorkspaceRoute for quizDuel', () {
      const payload = DynamicLinkPayload(
        type: DynamicLinkType.quizDuel,
        targetId: 'duel-500',
        parameters: {'deckId': 'deck-optics'},
      );

      final route = dynamicLinkService.routeForPayload(payload);
      expect(route, isA<QuizWorkspaceRoute>());
      if (route is QuizWorkspaceRoute) {
        expect(route.args?.deckId, equals('deck-optics'));
      }
    });

    test('routeForPayload resolves LiveStudyRoomRoute for studyRoom', () {
      const payload = DynamicLinkPayload(
        type: DynamicLinkType.studyRoom,
        targetId: 'room-botany',
        title: 'Botany Sprint',
      );

      final route = dynamicLinkService.routeForPayload(payload);
      expect(route, isA<LiveStudyRoomRoute>());
      if (route is LiveStudyRoomRoute) {
        expect(route.args?.room.id, equals('room-botany'));
        expect(route.args?.room.title, equals('Botany Sprint'));
      }
    });

    test('routeForPayload resolves PaywallRoute for promo', () {
      const payload = DynamicLinkPayload(
        type: DynamicLinkType.promo,
        targetId: 'FLASH50',
      );

      final route = dynamicLinkService.routeForPayload(payload);
      expect(route, isA<PaywallRoute>());
    });

    test('routeForPayload resolves CourseModuleRoute for course', () {
      const payload = DynamicLinkPayload(
        type: DynamicLinkType.course,
        targetId: 'course-mth101',
        parameters: {'code': 'MTH101'},
        title: 'Introductory Calculus',
      );

      final route = dynamicLinkService.routeForPayload(payload);
      expect(route, isA<CourseModuleRoute>());
      if (route is CourseModuleRoute) {
        expect(route.args?.courseId, equals('course-mth101'));
        expect(route.args?.courseCode, equals('MTH101'));
      }
    });

    test('DynamicLinkType.fromString correctly parses hyphenated types', () {
      expect(DynamicLinkType.fromString('quiz-duel'), equals(DynamicLinkType.quizDuel));
      expect(DynamicLinkType.fromString('study-room'), equals(DynamicLinkType.studyRoom));
      expect(DynamicLinkType.fromString('quiz_duel'), equals(DynamicLinkType.quizDuel));
      expect(DynamicLinkType.fromString('study_room'), equals(DynamicLinkType.studyRoom));
    });

    test('parseUri handles promo type without explicit ID', () {
      final uri = Uri.parse('https://kortex-study-app-2026.web.app/share?type=promo&code=SAVE20');
      final payload = dynamicLinkService.parseUri(uri);

      expect(payload, isNotNull);
      expect(payload!.type, equals(DynamicLinkType.promo));
      expect(payload.targetId, equals('SAVE20'));
    });
  });
}
