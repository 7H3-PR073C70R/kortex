import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/database/app_database.dart';

void main() {
  group('AppDatabase Community & Forum Operations', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('upserts forum posts and replies with count tracking', () async {
      const postId = 'post_101';
      final now = DateTime.now();

      await db.upsertForumPost(
        ForumPostsCompanion(
          id: const Value(postId),
          authorId: const Value('user_1'),
          authorName: const Value('Isaac Newton'),
          track: const Value('Physics'),
          title: const Value('Optics Theory'),
          content: const Value('Discussion on prisms and light refraction'),
          createdAt: Value(now),
          cachedAt: Value(now),
        ),
      );

      await db.upsertForumReply(
        ForumRepliesCompanion(
          id: const Value('reply_1'),
          postId: const Value(postId),
          authorId: const Value('user_2'),
          authorName: const Value('Christiaan Huygens'),
          content: const Value('Wave theory is also relevant here.'),
          createdAt: Value(now),
          cachedAt: Value(now),
        ),
      );

      final replies = await db.getForumRepliesForPost(postId);
      expect(replies.length, equals(1));

      // Verify repliesCount was incremented on post
      final post = await db.getForumPostById(postId);
      expect(post, isNotNull);
      expect(post!.repliesCount, equals(1));

      // Cascade delete
      await db.deleteForumPostById(postId);
      final deletedPost = await db.getForumPostById(postId);
      expect(deletedPost, isNull);

      final deletedReplies = await db.getForumRepliesForPost(postId);
      expect(deletedReplies, isEmpty);
    });

    test('getForumPosts filters by track and sorts by createdAt desc', () async {
      final t1 = DateTime(2026, 9, 1);
      final t2 = DateTime(2026, 9, 2);
      final t3 = DateTime(2026, 9, 3);

      await db.batchUpsertForumPostsAndReplies(
        posts: [
          ForumPostsCompanion(
            id: const Value('p1'),
            authorId: const Value('a1'),
            authorName: const Value('Scholar 1'),
            track: const Value('Medicine'),
            title: const Value('Cardiology'),
            content: const Value('ECG reading'),
            createdAt: Value(t1),
            cachedAt: Value(t1),
          ),
          ForumPostsCompanion(
            id: const Value('p2'),
            authorId: const Value('a2'),
            authorName: const Value('Scholar 2'),
            track: const Value('Engineering'),
            title: const Value('Circuits'),
            content: const Value('Kirchhoff Laws'),
            createdAt: Value(t2),
            cachedAt: Value(t2),
          ),
          ForumPostsCompanion(
            id: const Value('p3'),
            authorId: const Value('a3'),
            authorName: const Value('Scholar 3'),
            track: const Value('Medicine'),
            title: const Value('Neurology'),
            content: const Value('Cranial nerves'),
            createdAt: Value(t3),
            cachedAt: Value(t3),
          ),
        ],
      );

      // All posts
      final allPosts = await db.getForumPosts();
      expect(allPosts.length, equals(3));
      expect(allPosts[0].id, equals('p3')); // Most recent first
      expect(allPosts[1].id, equals('p2'));
      expect(allPosts[2].id, equals('p1'));

      // Filtered by track 'Medicine'
      final medicinePosts = await db.getForumPosts(track: 'Medicine');
      expect(medicinePosts.length, equals(2));
      expect(medicinePosts[0].id, equals('p3'));
      expect(medicinePosts[1].id, equals('p1'));
    });
  });
}

