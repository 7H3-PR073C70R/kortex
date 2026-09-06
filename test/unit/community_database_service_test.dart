import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/community/data/database/community_database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(CommunityDatabaseService.ensureFfiInitialized);

  group('CommunityDatabaseService', () {
    late CommunityDatabaseService service;

    setUp(() async {
      service = CommunityDatabaseService();
      await service.initDatabase(customPath: inMemoryDatabasePath);
    });

    tearDown(() async {
      await service.close();
    });

    test('initializes forum_posts and forum_replies tables correctly', () async {
      final db = await service.database;
      final tables = await db.query(
        'sqlite_master',
        where: 'type = ?',
        whereArgs: ['table'],
      );
      final tableNames =
          tables.map((t) => t['name']?.toString()).whereType<String>().toSet();

      expect(tableNames.contains('forum_posts'), isTrue);
      expect(tableNames.contains('forum_replies'), isTrue);
    });

    test('cascades deletion from forum_posts to forum_replies', () async {
      const postId = 'post_101';
      final now = DateTime.now().toIso8601String();

      await service.upsertPost({
        'id': postId,
        'author_id': 'user_1',
        'author_name': 'Isaac Newton',
        'track': 'Physics',
        'title': 'Optics Theory',
        'content': 'Discussion on prisms and light refraction',
        'created_at': now,
      });

      await service.upsertReply({
        'id': 'reply_1',
        'post_id': postId,
        'author_id': 'user_2',
        'author_name': 'Christiaan Huygens',
        'content': 'Wave theory is also relevant here.',
        'created_at': now,
      });

      var replies = await service.queryRepliesForPost(postId);
      expect(replies.length, equals(1));

      // Check that replies_count was updated
      var post = await service.queryForumPost(postId);
      expect(post, isNotNull);
      expect(post!['replies_count'], equals(1));

      // Delete post
      await service.deletePost(postId);

      post = await service.queryForumPost(postId);
      expect(post, isNull);

      replies = await service.queryRepliesForPost(postId);
      expect(replies, isEmpty);
    });

    test('queryForumPosts filters by track correctly and sorts by created_at desc', () async {
      final t1 = DateTime(2026, 9).toIso8601String();
      final t2 = DateTime(2026, 9, 2).toIso8601String();
      final t3 = DateTime(2026, 9, 3).toIso8601String();

      await service.batchUpsertPostsAndReplies([
        {
          'id': 'p1',
          'author_id': 'a1',
          'author_name': 'Scholar 1',
          'track': 'Medicine',
          'title': 'Cardiology',
          'content': 'ECG reading',
          'created_at': t1,
        },
        {
          'id': 'p2',
          'author_id': 'a2',
          'author_name': 'Scholar 2',
          'track': 'Engineering',
          'title': 'Circuits',
          'content': 'Kirchhoff Laws',
          'created_at': t2,
        },
        {
          'id': 'p3',
          'author_id': 'a3',
          'author_name': 'Scholar 3',
          'track': 'Medicine',
          'title': 'Neurology',
          'content': 'Cranial nerves',
          'created_at': t3,
        },
      ]);

      // All posts
      final allPosts = await service.queryForumPosts();
      expect(allPosts.length, equals(3));
      expect(allPosts[0]['id'], equals('p3')); // Most recent first
      expect(allPosts[1]['id'], equals('p2'));
      expect(allPosts[2]['id'], equals('p1'));

      // Filtered by track 'Medicine'
      final medicinePosts = await service.queryForumPosts(track: 'Medicine');
      expect(medicinePosts.length, equals(2));
      expect(medicinePosts[0]['id'], equals('p3'));
      expect(medicinePosts[1]['id'], equals('p1'));
    });
  });
}
