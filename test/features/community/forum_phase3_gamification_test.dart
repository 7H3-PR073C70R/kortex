import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/community/data/client/community_api_client.dart';
import 'package:kortex/src/features/community/data/data_sources/community_remote_data_source_impl.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_event.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_hub_bloc.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_state.dart';
import 'package:kortex/src/features/community/presentation/widgets/subject_master_badge.dart';
import 'package:kortex/src/features/community/presentation/widgets/track_forum_post_card.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:retrofit/retrofit.dart';

class MockCommunityApiClient extends Mock implements CommunityApiClient {}

class MockCommunityRepository extends Mock implements CommunityRepository {}

class MockUserStorageService extends Mock implements UserStorageService {}

Widget _buildTestApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  final dummyResponse = Response<dynamic>(
    requestOptions: RequestOptions(),
  );

  group('Phase 3: Gamification, Social Dynamics & Scholar Tiers Tests', () {
    test('ScholarTier.fromKarma calculates accurate progression thresholds', () {
      expect(ScholarTier.fromKarma(0), equals(ScholarTier.novice));
      expect(ScholarTier.fromKarma(50), equals(ScholarTier.novice));
      expect(ScholarTier.fromKarma(100), equals(ScholarTier.scholar));
      expect(ScholarTier.fromKarma(250), equals(ScholarTier.scholar));
      expect(ScholarTier.fromKarma(300), equals(ScholarTier.specialist));
      expect(ScholarTier.fromKarma(599), equals(ScholarTier.specialist));
      expect(ScholarTier.fromKarma(600), equals(ScholarTier.maven));
      expect(ScholarTier.fromKarma(999), equals(ScholarTier.maven));
      expect(ScholarTier.fromKarma(1000), equals(ScholarTier.master));
      expect(ScholarTier.fromKarma(1999), equals(ScholarTier.master));
      expect(ScholarTier.fromKarma(2000), equals(ScholarTier.grandmaster));
      expect(ScholarTier.fromKarma(5000), equals(ScholarTier.grandmaster));
    });

    test('ScholarTier.fromVerifiedAnswers calculates accurate answer milestones', () {
      expect(ScholarTier.fromVerifiedAnswers(0), equals(ScholarTier.novice));
      expect(ScholarTier.fromVerifiedAnswers(1), equals(ScholarTier.scholar));
      expect(ScholarTier.fromVerifiedAnswers(4), equals(ScholarTier.scholar));
      expect(ScholarTier.fromVerifiedAnswers(5), equals(ScholarTier.specialist));
      expect(ScholarTier.fromVerifiedAnswers(9), equals(ScholarTier.specialist));
      expect(ScholarTier.fromVerifiedAnswers(10), equals(ScholarTier.maven));
      expect(ScholarTier.fromVerifiedAnswers(24), equals(ScholarTier.maven));
      expect(ScholarTier.fromVerifiedAnswers(25), equals(ScholarTier.master));
      expect(ScholarTier.fromVerifiedAnswers(49), equals(ScholarTier.master));
      expect(ScholarTier.fromVerifiedAnswers(50), equals(ScholarTier.grandmaster));
      expect(ScholarTier.fromVerifiedAnswers(100), equals(ScholarTier.grandmaster));
    });

    testWidgets('SubjectMasterBadge renders dynamic tier and rich tooltip', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          const SubjectMasterBadge(
            track: 'Mathematics',
            tier: ScholarTier.master,
            karmaScore: 1250,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Math Master'), findsOneWidget);
      expect(find.byIcon(Icons.military_tech_rounded), findsOneWidget);

      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, contains('Math Master • 1250 Karma XP'));
    });

    testWidgets('SubjectMasterBadge renders legacy track config when no tier is specified', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          const SubjectMasterBadge(
            track: 'WAEC',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('WAEC Specialist'), findsOneWidget);
      expect(find.byIcon(Icons.workspace_premium_rounded), findsOneWidget);
    });

    test('ForumPostEntity and ForumReplyEntity correctly identify anonymous authors while preserving real authorId', () {
      final anonPost = ForumPostEntity(
        id: 'anon-1',
        authorId: 'user-real-123',
        authorName: 'Anonymous Scholar',
        track: 'WAEC',
        title: 'Need help with Chemistry',
        content: 'Is this reaction exothermic?',
        isAnonymous: true,
        createdAt: DateTime.now(),
      );
      expect(anonPost.isAnonymous, isTrue);
      expect(anonPost.authorId, equals('user-real-123'));

      final publicPost = ForumPostEntity(
        id: 'pub-1',
        authorId: 'user-123',
        authorName: 'AdaLovelace',
        track: 'Mathematics',
        title: 'Calculus derivatives',
        content: 'd/dx of sin(x)?',
        createdAt: DateTime.now(),
      );
      expect(publicPost.isAnonymous, isFalse);

      final anonReply = ForumReplyEntity(
        id: 'rep-anon-1',
        postId: 'anon-1',
        authorId: 'user-real-456',
        authorName: 'Anonymous Scholar',
        content: 'Yes, because delta H is negative.',
        isAnonymous: true,
        createdAt: DateTime.now(),
      );
      expect(anonReply.isAnonymous, isTrue);
      expect(anonReply.authorId, equals('user-real-456'));

      final publicReply = ForumReplyEntity(
        id: 'rep-pub-1',
        postId: 'anon-1',
        authorId: 'user-456',
        authorName: 'Newton',
        content: 'Yes, exothermic reactions release heat.',
        createdAt: DateTime.now(),
      );
      expect(publicReply.isAnonymous, isFalse);
    });

    testWidgets('TrackForumPostCard displays Incognito badge and privacy mask for anonymous posts', (tester) async {
      final anonPost = ForumPostEntity(
        id: 'post-anon-card',
        authorId: 'user-real-secret',
        authorName: 'Anonymous Scholar',
        track: 'Physics',
        title: 'Wave optics interference question',
        content: 'What happens to fringe width when wavelength increases?',
        isQuestion: true,
        isAnonymous: true,
        karmaBounty: 150,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        _buildTestApp(
          TrackForumPostCard(
            post: anonPost,
            onTap: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify privacy mask icon is present
      expect(find.byIcon(Icons.visibility_off_rounded), findsOneWidget);
      // Verify Incognito chip is displayed
      expect(find.text('Incognito'), findsOneWidget);
      // Verify author name is shown without '@'
      expect(find.text('Anonymous Scholar'), findsOneWidget);
      expect(find.text('@Anonymous Scholar'), findsNothing);
      // Verify bounty pill is displayed
      expect(find.text('+150 XP'), findsOneWidget);
    });

    test('CommunityRemoteDataSourceImpl.replyToForumPost preserves genuine author_id and flags is_anonymous', () async {
      final mockClient = MockCommunityApiClient();
      final mockUserStorage = MockUserStorageService();

      when(mockUserStorage.getUserId).thenReturn('user-real-999');
      when(mockUserStorage.getUserDisplayName).thenReturn('RealScholar');
      when(mockUserStorage.getUserAvatarUrl).thenReturn('https://avatar.url/real.png');

      Map<String, dynamic>? capturedPayload;
      when(() => mockClient.replyToForumPost(any())).thenAnswer((inv) async {
        capturedPayload = inv.positionalArguments[0] as Map<String, dynamic>;
        return HttpResponse<dynamic>(
          [
            {
              'id': 'reply-anon-created',
              'post_id': 'post-1',
              'author_id': 'user-real-999',
              'author_name': 'Anonymous Scholar',
              'content': 'Secret solution',
              'is_anonymous': true,
              'created_at': DateTime.now().toIso8601String(),
            }
          ],
          dummyResponse,
        );
      });

      final dataSource = CommunityRemoteDataSourceImpl(
        mockClient,
        userStorage: mockUserStorage,
      );

      final reply = await dataSource.replyToForumPost(
        postId: 'post-1',
        content: 'Secret solution',
        isAnonymous: true,
      );

      expect(reply.isAnonymous, isTrue);
      expect(reply.authorId, equals('user-real-999'));
      expect(capturedPayload, isNotNull);
      expect(capturedPayload!['author_name'], equals('Anonymous Scholar'));
      // Legal & audit trail verification: author_id MUST NOT be null or empty
      expect(capturedPayload!['author_id'], equals('user-real-999'));
      expect(capturedPayload!['author_avatar'], isNull);
      expect(capturedPayload!['is_anonymous'], isTrue);
    });

    test('CommunityHubBloc handles VerifyForumReplyEvent and rewards verified solution', () async {
      final mockRepo = MockCommunityRepository();
      final post = ForumPostEntity(
        id: 'post-solve-1',
        authorId: 'op-1',
        authorName: 'QuestionAsker',
        track: 'Chemistry',
        title: 'Equilibrium constant calculation',
        content: 'How to calculate Kp from Kc?',
        isQuestion: true,
        karmaBounty: 200,
        createdAt: DateTime.now(),
        replies: [
          ForumReplyEntity(
            id: 'rep-solution-1',
            postId: 'post-solve-1',
            authorId: 'helper-1',
            authorName: 'MasterChemist',
            content: 'Use Kp = Kc * (RT)^(delta n)',
            createdAt: DateTime.now(),
          ),
        ],
      );

      when(
        () => mockRepo.verifyForumReply(
          postId: any(named: 'postId'),
          replyId: any(named: 'replyId'),
        ),
      ).thenAnswer((_) async => const Right(true));

      final bloc = CommunityHubBloc(
        repository: mockRepo,
      );

      // Seed the state with our post
      when(() => mockRepo.fetchForumPosts(offset: any(named: 'offset'), limit: any(named: 'limit')))
          .thenAnswer((_) async => Right([post]));

      bloc.add(
        const VerifyForumReplyEvent(
          postId: 'post-solve-1',
          replyId: 'rep-solution-1',
        ),
      );

      await expectLater(
        bloc.stream,
        emits(
          predicate<CommunityState>((state) {
            return state.verifiedSolutionNotice != null &&
                state.verifiedSolutionNotice!.contains('+100 Scholar XP awarded');
          }),
        ),
      );

      await bloc.close();
    });
  });
}
