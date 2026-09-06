import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class CommunityDatabaseService {
  CommunityDatabaseService({Database? database}) : _db = database;

  Database? _db;
  static bool _ffiInitialized = false;

  static void ensureFfiInitialized() {
    if (kIsWeb) return;
    if (!_ffiInitialized) {
      if (Platform.isWindows ||
          Platform.isLinux ||
          Platform.isMacOS ||
          Platform.environment.containsKey('FLUTTER_TEST')) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
        _ffiInitialized = true;
      }
    }
  }

  Future<Database> get database async {
    if (_db != null && _db!.isOpen) {
      return _db!;
    }
    _db = await initDatabase();
    return _db!;
  }

  Future<Database> initDatabase({String? customPath}) async {
    ensureFfiInitialized();

    final String dbPath;
    if (customPath != null) {
      dbPath = customPath;
    } else {
      final databasesPath = await getDatabasesPath();
      dbPath = p.join(databasesPath, 'kortex_community.db');
    }

    final db = await openDatabase(
      dbPath,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _createTables(db);
      },
    );

    _db = db;
    return db;
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE forum_posts (
        id TEXT PRIMARY KEY,
        author_id TEXT NOT NULL,
        author_name TEXT NOT NULL,
        author_avatar TEXT,
        track TEXT NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        latex_content TEXT,
        upvotes INTEGER NOT NULL DEFAULT 0,
        replies_count INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        cached_at TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE forum_replies (
        id TEXT PRIMARY KEY,
        post_id TEXT NOT NULL REFERENCES forum_posts(id) ON DELETE CASCADE,
        author_id TEXT NOT NULL,
        author_name TEXT NOT NULL,
        author_avatar TEXT,
        content TEXT NOT NULL,
        latex_content TEXT,
        upvotes INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        cached_at TEXT NOT NULL
      );
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_forum_posts_track ON forum_posts(track);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_forum_posts_created_at ON forum_posts(created_at DESC);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_forum_replies_post_id ON forum_replies(post_id);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_forum_replies_created_at ON forum_replies(created_at ASC);',
    );
  }

  Future<List<Map<String, dynamic>>> queryForumPosts({String? track}) async {
    final db = await database;
    if (track != null && track.isNotEmpty && track != 'All') {
      return db.query(
        'forum_posts',
        where: 'LOWER(track) = LOWER(?)',
        whereArgs: [track],
        orderBy: 'created_at DESC',
      );
    }
    return db.query(
      'forum_posts',
      orderBy: 'created_at DESC',
    );
  }

  Future<Map<String, dynamic>?> queryForumPost(String id) async {
    final db = await database;
    final results = await db.query(
      'forum_posts',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return results.first;
  }

  Future<List<Map<String, dynamic>>> queryRepliesForPost(String postId) async {
    final db = await database;
    return db.query(
      'forum_replies',
      where: 'post_id = ?',
      whereArgs: [postId],
      orderBy: 'created_at ASC',
    );
  }

  Future<void> batchUpsertPostsAndReplies(
    List<Map<String, dynamic>> posts, {
    List<Map<String, dynamic>> replies = const [],
  }) async {
    if (posts.isEmpty && replies.isEmpty) return;
    final db = await database;
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      final batch = txn.batch();

      for (final p in posts) {
        final post = Map<String, dynamic>.from(p)
          ..putIfAbsent('cached_at', () => now);
        batch.insert(
          'forum_posts',
          post,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final r in replies) {
        final reply = Map<String, dynamic>.from(r)
          ..putIfAbsent('cached_at', () => now);
        batch.insert(
          'forum_replies',
          reply,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit(noResult: true);
    });
  }

  Future<void> upsertPost(Map<String, dynamic> postData) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final post = Map<String, dynamic>.from(postData)
      ..putIfAbsent('cached_at', () => now);

    await db.insert(
      'forum_posts',
      post,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertReply(Map<String, dynamic> replyData) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final reply = Map<String, dynamic>.from(replyData)
      ..putIfAbsent('cached_at', () => now);

    await db.transaction((txn) async {
      await txn.insert(
        'forum_replies',
        reply,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final postId = reply['post_id'] as String?;
      if (postId != null && postId.isNotEmpty) {
        final countResult = await txn.rawQuery(
          'SELECT COUNT(*) as count FROM forum_replies WHERE post_id = ?',
          [postId],
        );
        final count = (countResult.first['count'] as num?)?.toInt() ?? 0;
        await txn.update(
          'forum_posts',
          {'replies_count': count},
          where: 'id = ?',
          whereArgs: [postId],
        );
      }
    });
  }

  Future<void> deletePost(String postId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'forum_replies',
        where: 'post_id = ?',
        whereArgs: [postId],
      );
      await txn.delete(
        'forum_posts',
        where: 'id = ?',
        whereArgs: [postId],
      );
    });
  }

  Future<void> deleteAllPosts() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('forum_replies');
      await txn.delete('forum_posts');
    });
  }

  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }
}
