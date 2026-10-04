import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';
import 'package:kortex/src/features/notifications/domain/entities/notification_item_entity.dart';
import 'package:kortex/src/features/notifications/domain/services/notification_router.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/past_question_card.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/pump_app.dart';

class MockStackRouter extends Mock implements StackRouter {}

class MockCommunityRepository extends Mock implements CommunityRepository {}

class FakePageRouteInfo extends Fake implements PageRouteInfo<dynamic> {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(FakePageRouteInfo());
  });

  group('Phase 2: Ecosystem Interconnectivity Tests', () {
    late MockStackRouter mockRouter;
    late MockCommunityRepository mockCommunityRepo;

    final testPost = ForumPostEntity(
      id: 'post-eco-1',
      title: 'How to calculate molar mass in waec chemistry?',
      content: 'Can someone explain the step by step breakdown for stoichiometry?',
      authorId: 'user-1',
      authorName: 'Adaobi',
      authorAvatar: '',
      track: 'Chemistry',
      syllabusTag: 'Stoichiometry',
      isQuestion: true,
      createdAt: DateTime.now(),
      upvotes: 10,
      downvotes: 1,
      repliesCount: 2,
    );

    setUp(() async {
      mockRouter = MockStackRouter();
      mockCommunityRepo = MockCommunityRepository();

      if (locator.isRegistered<CommunityRepository>()) {
        await locator.unregister<CommunityRepository>();
      }
      locator.registerSingleton<CommunityRepository>(mockCommunityRepo);
    });

    tearDown(() async {
      if (locator.isRegistered<CommunityRepository>()) {
        await locator.unregister<CommunityRepository>();
      }
    });

    test('ForumThreadDetailRoute carries highlightReplyId properly', () {
      final route = ForumThreadDetailRoute(
        post: testPost,
        highlightReplyId: 'reply-highlight-99',
      );

      expect(route.args?.post.id, equals('post-eco-1'));
      expect(route.args?.highlightReplyId, equals('reply-highlight-99'));

      final sameRoute = ForumThreadDetailRoute(
        post: testPost,
        highlightReplyId: 'reply-highlight-99',
      );
      expect(route.args == sameRoute.args, isTrue);
    });

    test('NotificationRouter routes forum_reply notification with thread tree fetch and highlightReplyId', () async {
      when(() => mockRouter.push(any())).thenAnswer((_) async => null);
      when(() => mockCommunityRepo.fetchForumThreadTree(postId: 'post-eco-1'))
          .thenAnswer((_) async => Right((post: testPost, replies: const <ForumReplyEntity>[])));

      const router = NotificationRouter();
      final notification = NotificationItemEntity(
        id: 'notif-forum-1',
        title: 'New Reply to Your Question',
        message: 'Kester replied: Remember that molar mass is g/mol!',
        category: NotificationCategory.community,
        actionRoute: '/forum/thread',
        timestamp: DateTime.now(),
        metadata: const {
          'type': 'forum_reply',
          'post_id': 'post-eco-1',
          'reply_id': 'reply-highlight-99',
        },
      );

      final navigated = await router.handleNotificationNavigation(
        router: mockRouter,
        notification: notification,
      );

      expect(navigated, isTrue);
      verify(() => mockCommunityRepo.fetchForumThreadTree(postId: 'post-eco-1')).called(1);

      final captured = verify(() => mockRouter.push(captureAny())).captured;
      expect(captured.isNotEmpty, isTrue);
      final pushedRoute = captured.first;
      expect(pushedRoute, isA<ForumThreadDetailRoute>());
      final forumArgs = (pushedRoute as ForumThreadDetailRoute).args;
      expect(forumArgs?.post.id, equals('post-eco-1'));
      expect(forumArgs?.highlightReplyId, equals('reply-highlight-99'));
    });

    test('NotificationRouter falls back to CommunityHubRoute if post fetch fails', () async {
      when(() => mockRouter.push(any())).thenAnswer((_) async => null);
      when(() => mockCommunityRepo.fetchForumThreadTree(postId: 'missing-post'))
          .thenAnswer((_) async => const Left(ServerFailure(message: 'Thread deleted')));

      const router = NotificationRouter();
      final notification = NotificationItemEntity(
        id: 'notif-forum-2',
        title: 'Deleted Question',
        message: 'A discussion was updated.',
        category: NotificationCategory.community,
        actionRoute: '/forum/thread',
        timestamp: DateTime.now(),
        metadata: const {
          'type': 'forum_reply',
          'post_id': 'missing-post',
        },
      );

      final navigated = await router.handleNotificationNavigation(
        router: mockRouter,
        notification: notification,
      );

      expect(navigated, isTrue);
      final captured = verify(() => mockRouter.push(captureAny())).captured;
      expect(captured.first, isA<CommunityHubRoute>());
    });

    testWidgets('PastQuestionCard renders both Discuss with Peers and Ask Syllabot AI action buttons', (tester) async {
      const testQuestion = PastQuestionEntity(
        id: 'pq-1',
        examType: ExamCategory.waec,
        subject: 'Physics',
        year: 2024,
        questionNumber: 15,
        prompt: 'Calculate the acceleration due to gravity on a planet of mass 2M and radius 2R.',
        options: [
          'g / 2',
          '2g',
          '4g',
          'g / 4',
        ],
        correctOptionIndex: 0,
        correctOptionLabel: 'A',
        explanation: 'g_p = G(2M)/(2R)^2 = 2GM/(4R^2) = g/2.',
        topic: 'Gravitational Fields',
      );

      await tester.pumpApp(
        const Scaffold(
          body: SingleChildScrollView(
            child: PastQuestionCard(
              question: testQuestion,
              isInstantFeedback: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Discuss with Peers'), findsOneWidget);
      expect(find.text('Ask Syllabot AI'), findsOneWidget);
      expect(find.byIcon(Icons.forum_outlined), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
    });
  });
}
