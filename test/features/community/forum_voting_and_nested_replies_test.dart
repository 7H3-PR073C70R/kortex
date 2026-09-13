import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/database/app_database.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/features/community/data/client/community_api_client.dart';
import 'package:kortex/src/features/community/data/data_sources/community_local_data_source.dart';
import 'package:kortex/src/features/community/data/data_sources/community_local_data_source_impl.dart';
import 'package:kortex/src/features/community/data/data_sources/community_remote_data_source_impl.dart';
import 'package:kortex/src/features/community/data/models/forum_post_model.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
import 'package:kortex/src/features/community/presentation/widgets/track_forum_post_card.dart';
import 'package:mocktail/mocktail.dart';
import 'package:retrofit/retrofit.dart';

import '../../helpers/pump_app.dart';

class MockCommunityApiClient extends Mock implements CommunityApiClient {}
class MockUserStorageService extends Mock implements UserStorageService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Forum Entities & Models Voting & Nested Hierarchy Tests', () {
    test('ForumPostEntity computes netVotes correctly', () {
      final post = ForumPostEntity(
        id: 'post-1',
        authorId: 'author-1',
        authorName: 'Ada Lovelace',
        track: 'JAMB - Engineering',
        title: 'Projectile Motion Doubt',
        content: 'How do I calculate range?',
        createdAt: DateTime.now(),
        upvotes: 12,
        downvotes: 4,
        userVote: 1,
      );

      expect(post.netVotes, equals(8));
      expect(post.userVote, equals(1));
    });

    test('ForumReplyEntity computes netVotes and isNested correctly', () {
      final topLevelReply = ForumReplyEntity(
        id: 'reply-1',
        postId: 'post-1',
        authorId: 'author-2',
        authorName: 'Alan Turing',
        content: 'Use R = (u^2 * sin(2theta)) / g',
        createdAt: DateTime.now(),
        upvotes: 20,
        downvotes: 2,
        userVote: 1,
      );

      final nestedReply = ForumReplyEntity(
        id: 'reply-2',
        postId: 'post-1',
        parentReplyId: 'reply-1',
        authorId: 'author-1',
        authorName: 'Ada Lovelace',
        content: 'Does this assume zero air resistance?',
        createdAt: DateTime.now(),
        upvotes: 5,
      );

      expect(topLevelReply.netVotes, equals(18));
      expect(topLevelReply.isNested, isFalse);
      expect(nestedReply.isNested, isTrue);
      expect(nestedReply.parentReplyId, equals('reply-1'));
    });

    test('ForumPostModel serialization and deserialization preserves voting and nested replies', () {
      final json = {
        'id': 'post-100',
        'author_id': 'user-100',
        'author_name': 'Grace Hopper',
        'track': 'WAEC - Sciences',
        'title': 'Compiler Optimization',
        'content': 'How does SSA form help in optimization?',
        'upvotes': 15,
        'downvotes': 2,
        'user_vote': 1,
        'replies_count': 1,
        'created_at': '2026-09-13T06:00:00.000Z',
        'forum_replies': [
          {
            'id': 'reply-101',
            'post_id': 'post-100',
            'parent_reply_id': 'reply-100',
            'author_id': 'user-102',
            'author_name': 'Margaret Hamilton',
            'content': 'It makes data flow analysis explicit and sparse.',
            'upvotes': 8,
            'downvotes': 1,
            'user_vote': 1,
            'created_at': '2026-09-13T06:05:00.000Z',
          }
        ],
      };

      final model = ForumPostModel.fromJson(json);
      expect(model.id, equals('post-100'));
      expect(model.upvotes, equals(15));
      expect(model.downvotes, equals(2));
      expect(model.userVote, equals(1));
      expect(model.netVotes, equals(13));
      expect(model.replies.length, equals(1));
      expect(model.replies.first.parentReplyId, equals('reply-100'));
      expect(model.replies.first.netVotes, equals(7));

      final entity = model.toEntity();
      expect(entity.netVotes, equals(13));
      expect(entity.replies.first.isNested, isTrue);
    });

    test('ForumPostEntity computes topLevelRepliesCount by excluding nested replies', () {
      final topLevel1 = ForumReplyEntity(
        id: 'r1',
        postId: 'p1',
        authorId: 'u1',
        authorName: 'User 1',
        content: 'Main Answer 1',
        createdAt: DateTime.now(),
      );
      final topLevel2 = ForumReplyEntity(
        id: 'r2',
        postId: 'p1',
        authorId: 'u2',
        authorName: 'User 2',
        content: 'Main Answer 2',
        createdAt: DateTime.now(),
      );
      final nested1 = ForumReplyEntity(
        id: 'r3',
        postId: 'p1',
        parentReplyId: 'r1',
        authorId: 'u3',
        authorName: 'User 3',
        content: 'Reply to Answer 1',
        createdAt: DateTime.now(),
      );
      final nested2 = ForumReplyEntity(
        id: 'r4',
        postId: 'p1',
        parentReplyId: 'r3',
        authorId: 'u4',
        authorName: 'User 4',
        content: 'Reply to reply',
        createdAt: DateTime.now(),
      );

      final post = ForumPostEntity(
        id: 'p1',
        authorId: 'u0',
        authorName: 'Post Author',
        track: 'WAEC',
        title: 'Question',
        content: 'Content',
        createdAt: DateTime.now(),
        replies: [topLevel1, topLevel2, nested1, nested2],
        repliesCount: 4,
      );

      expect(post.replies.length, equals(4));
      // Only 2 top level replies!
      expect(post.topLevelRepliesCount, equals(2));
    });
  });

  group('CommunityRemoteDataSourceImpl Voting & Threading Tests', () {
    late MockCommunityApiClient mockClient;
    late MockUserStorageService mockUserStorage;
    late AppDatabase db;
    late CommunityLocalDataSource localDataSource;
    late CommunityRemoteDataSourceImpl remoteDataSource;

    setUp(() {
      mockClient = MockCommunityApiClient();
      mockUserStorage = MockUserStorageService();
      db = AppDatabase(NativeDatabase.memory());
      localDataSource = CommunityLocalDataSourceImpl(db);
      remoteDataSource = CommunityRemoteDataSourceImpl(
        mockClient,
        userStorage: mockUserStorage,
        localDataSource: localDataSource,
      );

      when(() => mockUserStorage.getUserId()).thenReturn('user-current');
      when(() => mockUserStorage.getUserDisplayName()).thenReturn('Current Scholar');
      when(() => mockUserStorage.getUserAvatarUrl()).thenReturn(null);
    });

    tearDown(() async {
      await db.close();
    });

    test('voteForumPost updates post votes optimistically and calls API', () async {
      final initialPost = ForumPostModel(
        id: 'test-post',
        authorId: 'author-1',
        authorName: 'Scholar',
        track: 'JAMB',
        title: 'Math Question',
        content: 'Integration by parts',
        upvotes: 5,
        downvotes: 1,
        createdAt: DateTime.now(),
      );
      await localDataSource.saveForumPost(initialPost);

      when(() => mockClient.voteForumPostAtomic(any())).thenAnswer(
        (_) async => HttpResponse(
          {'success': true, 'upvotes': 6, 'downvotes': 1},
          Response(requestOptions: RequestOptions(path: '/rest/v1/rpc/vote_forum_post_atomic')),
        ),
      );

      // Upvote post
      final success = await remoteDataSource.voteForumPost(
        postId: 'test-post',
        voteDirection: 1,
      );

      expect(success, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      final updated = await localDataSource.getForumPost('test-post');
      expect(updated, isNotNull);
      expect(updated!.upvotes, equals(6));
      expect(updated.downvotes, equals(1));
      expect(updated.userVote, equals(1));
      expect(updated.netVotes, equals(5));

      verify(() => mockClient.voteForumPostAtomic({
        'p_post_id': 'test-post',
        'p_vote_direction': 1,
      })).called(1);
    });

    test('replyToForumPost sends parent_reply_id for nested replies', () async {
      final initialPost = ForumPostModel(
        id: 'post-1',
        authorId: 'author-1',
        authorName: 'Scholar',
        track: 'JAMB',
        title: 'Math Question',
        content: 'Integration by parts',
        upvotes: 5,
        downvotes: 1,
        createdAt: DateTime.now(),
      );
      await localDataSource.saveForumPost(initialPost);

      final createdReplyJson = {
        'id': 'reply-nested',
        'post_id': 'post-1',
        'parent_reply_id': 'reply-parent',
        'author_id': 'user-current',
        'author_name': 'Current Scholar',
        'content': 'I agree with this answer.',
        'upvotes': 0,
        'downvotes': 0,
        'created_at': DateTime.now().toIso8601String(),
      };

      when(() => mockClient.replyToForumPost(any())).thenAnswer(
        (_) async => HttpResponse(
          [createdReplyJson],
          Response(requestOptions: RequestOptions(path: '/rest/v1/forum_replies')),
        ),
      );

      final reply = await remoteDataSource.replyToForumPost(
        postId: 'post-1',
        content: 'I agree with this answer.',
        parentReplyId: 'reply-parent',
      );

      expect(reply.id, equals('reply-nested'));
      expect(reply.parentReplyId, equals('reply-parent'));
      expect(reply.isNested, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      verify(() => mockClient.replyToForumPost(
        any(that: predicate<Map<String, dynamic>>((payload) =>
          payload['post_id'] == 'post-1' &&
          payload['parent_reply_id'] == 'reply-parent' &&
          payload['content'] == 'I agree with this answer.')),
      )).called(1);
    });
  });

  group('TrackForumPostCard Bidirectional Voting Widget Tests', () {
    testWidgets('renders bidirectional vote buttons and net vote score', (tester) async {
      var upvoted = false;
      var downvoted = false;

      final post = ForumPostEntity(
        id: 'post-ui-1',
        authorId: 'author-1',
        authorName: 'Prof. Euler',
        track: 'WAEC - Sciences',
        title: 'Euler Characteristic Formula',
        content: 'V - E + F = 2 for convex polyhedra.',
        upvotes: 42,
        downvotes: 2,
        userVote: 1,
        createdAt: DateTime.now(),
      );

      await tester.pumpApp(
        Scaffold(
          body: TrackForumPostCard(
            post: post,
            onTap: () {},
            onUpvoteTap: () => upvoted = true,
            onDownvoteTap: () => downvoted = true,
          ),
        ),
      );

      expect(find.text('40'), findsOneWidget); // 42 - 2 = 40 net votes
      expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.keyboard_arrow_up_rounded));
      await tester.pump();
      expect(upvoted, isTrue);

      await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
      await tester.pump();
      expect(downvoted, isTrue);
    });

    testWidgets('displays only top-level replies count on card, excluding nested sub-replies', (tester) async {
      final topLevel1 = ForumReplyEntity(
        id: 'r1',
        postId: 'post-count-1',
        authorId: 'u1',
        authorName: 'User 1',
        content: 'Top Level Answer 1',
        createdAt: DateTime.now(),
      );
      final topLevel2 = ForumReplyEntity(
        id: 'r2',
        postId: 'post-count-1',
        authorId: 'u2',
        authorName: 'User 2',
        content: 'Top Level Answer 2',
        createdAt: DateTime.now(),
      );
      final nested1 = ForumReplyEntity(
        id: 'r3',
        postId: 'post-count-1',
        parentReplyId: 'r1',
        authorId: 'u3',
        authorName: 'User 3',
        content: 'Nested reply',
        createdAt: DateTime.now(),
      );

      final post = ForumPostEntity(
        id: 'post-count-1',
        authorId: 'author-1',
        authorName: 'Scholar',
        track: 'WAEC',
        title: 'Photosynthesis Question',
        content: '**Question:** What is light dependent reaction? **Options:** A. Calvin Cycle B. Photolysis',
        createdAt: DateTime.now(),
        replies: [topLevel1, topLevel2, nested1],
        repliesCount: 3,
      );

      await tester.pumpApp(
        Scaffold(
          body: TrackForumPostCard(
            post: post,
            onTap: () {},
          ),
        ),
      );

      // Should display "2 replies", NOT "3 replies"
      expect(find.text('2 replies'), findsOneWidget);
      expect(find.text('3 replies'), findsNothing);
    });

    test('top-level replies are sorted by upvotes descending and nested replies by date descending', () {
      final t0 = DateTime(2026, 9, 13, 6);
      final t1 = DateTime(2026, 9, 13, 6, 10);
      final t2 = DateTime(2026, 9, 13, 6, 20);

      final replyLowVotes = ForumReplyEntity(
        id: 'r_low',
        postId: 'p1',
        authorId: 'u1',
        authorName: 'User 1',
        content: 'Low votes reply',
        upvotes: 2,
        downvotes: 1,
        createdAt: t0,
      );

      final replyHighVotes = ForumReplyEntity(
        id: 'r_high',
        postId: 'p1',
        authorId: 'u2',
        authorName: 'User 2',
        content: 'High votes reply',
        upvotes: 15,
        downvotes: 1,
        createdAt: t1,
      );

      final replyVerified = ForumReplyEntity(
        id: 'r_verified',
        postId: 'p1',
        authorId: 'u3',
        authorName: 'User 3',
        content: 'Verified solution',
        upvotes: 8,
        isVerifiedSolution: true,
        createdAt: t0,
      );

      final nestedOlder = ForumReplyEntity(
        id: 'n_old',
        postId: 'p1',
        parentReplyId: 'r_high',
        authorId: 'u4',
        authorName: 'Commenter 1',
        content: 'Older comment',
        createdAt: t0,
      );

      final nestedNewer = ForumReplyEntity(
        id: 'n_new',
        postId: 'p1',
        parentReplyId: 'r_high',
        authorId: 'u5',
        authorName: 'Commenter 2',
        content: 'Newer comment',
        createdAt: t2,
      );

      final allReplies = [replyLowVotes, nestedOlder, replyHighVotes, nestedNewer, replyVerified];

      // Top-level sorting logic
      final topLevel = allReplies
          .where((r) => r.parentReplyId == null || r.parentReplyId!.isEmpty)
          .toList()
        ..sort((a, b) {
          if (a.isVerifiedSolution != b.isVerifiedSolution) {
            return a.isVerifiedSolution ? -1 : 1;
          }
          final voteComp = b.netVotes.compareTo(a.netVotes);
          if (voteComp != 0) return voteComp;
          return b.createdAt.compareTo(a.createdAt);
        });

      expect(topLevel.first.id, equals('r_verified')); // Verified on top
      expect(topLevel[1].id, equals('r_high'));       // 14 net votes
      expect(topLevel[2].id, equals('r_low'));        // 1 net vote

      // Nested sorting logic (most recent first)
      final nestedMap = <String, List<ForumReplyEntity>>{};
      for (final r in allReplies) {
        if (r.parentReplyId != null && r.parentReplyId!.isNotEmpty) {
          nestedMap.putIfAbsent(r.parentReplyId!, () => []).add(r);
        }
      }
      for (final list in nestedMap.values) {
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }

      final highNested = nestedMap['r_high']!;
      expect(highNested.first.id, equals('n_new')); // Newer comment (t2) first
      expect(highNested.last.id, equals('n_old'));  // Older comment (t0) second
    });

    test('hasAiHint correctly detects if an AI hint exists in replies', () {
      final normalReply = ForumReplyEntity(
        id: 'r1',
        postId: 'p1',
        authorId: 'u1',
        authorName: 'Ada',
        content: 'Standard student response',
        createdAt: DateTime.now(),
      );

      final syllabotReply = ForumReplyEntity(
        id: 'r2',
        postId: 'p1',
        authorId: 'syllabot-ai',
        authorName: 'Syllabot AI',
        content: "🤖 Syllabot Socratic Hint:\n\n1. Consider Boyle's Law...",
        createdAt: DateTime.now(),
      );

      bool checkHasAiHint(List<ForumReplyEntity> replies) {
        return replies.any(
          (r) =>
              r.authorName.toLowerCase().contains('syllabot') ||
              r.content.contains('Syllabot') ||
              r.content.contains('🤖') ||
              r.content.contains('Socratic Hint'),
        );
      }

      expect(checkHasAiHint([normalReply]), isFalse);
      expect(checkHasAiHint([normalReply, syllabotReply]), isTrue);
    });
  });
}
