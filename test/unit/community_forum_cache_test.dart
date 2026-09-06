import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/networking/realtime/realtime_client.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/features/community/data/client/community_api_client.dart';
import 'package:kortex/src/features/community/data/data_sources/community_local_data_source.dart';
import 'package:kortex/src/features/community/data/data_sources/community_local_data_source_impl.dart';
import 'package:kortex/src/features/community/data/data_sources/community_remote_data_source_impl.dart';
import 'package:kortex/src/features/community/data/database/community_database_service.dart';
import 'package:kortex/src/features/community/data/models/forum_post_model.dart';
import 'package:mocktail/mocktail.dart';
import 'package:retrofit/retrofit.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MockCommunityApiClient extends Mock implements CommunityApiClient {}

class MockUserStorageService extends Mock implements UserStorageService {}

class MockRealtimeClient extends Mock implements RealtimeClient {}

void main() {
  setUpAll(CommunityDatabaseService.ensureFfiInitialized);

  group('Community Forum SQLite Caching', () {
    late CommunityDatabaseService dbService;
    late CommunityLocalDataSource localDataSource;
    late MockCommunityApiClient mockApiClient;
    late MockUserStorageService mockUserStorage;
    late MockRealtimeClient mockRealtime;
    late CommunityRemoteDataSourceImpl remoteDataSource;

    setUp(() async {
      dbService = CommunityDatabaseService();
      await dbService.initDatabase(customPath: inMemoryDatabasePath);
      localDataSource = CommunityLocalDataSourceImpl(dbService);
      mockApiClient = MockCommunityApiClient();
      mockUserStorage = MockUserStorageService();
      mockRealtime = MockRealtimeClient();

      when(() => mockUserStorage.getUserId()).thenReturn('user_42');
      when(() => mockUserStorage.getUserDisplayName()).thenReturn('Scholar Marie');
      when(() => mockUserStorage.getUserAvatarUrl()).thenReturn(null);

      remoteDataSource = CommunityRemoteDataSourceImpl(
        mockApiClient,
        userStorage: mockUserStorage,
        realtimeClient: mockRealtime,
        localDataSource: localDataSource,
      );
    });

    tearDown(() async {
      await dbService.close();
    });

    test('fetchForumPosts persists remote posts to SQLite for read-through caching', () async {
      final now = DateTime.now().toIso8601String();
      final remoteData = [
        {
          'id': 'post_radioactivity',
          'author_id': 'curie_1',
          'author_name': 'Marie Curie',
          'track': 'Physics',
          'title': 'Isolation of Radium',
          'content': 'Details regarding pitchblende extraction.',
          'upvotes': 15,
          'replies_count': 1,
          'created_at': now,
          'forum_replies': [
            {
              'id': 'reply_radium_1',
              'post_id': 'post_radioactivity',
              'author_id': 'pierre_1',
              'author_name': 'Pierre Curie',
              'content': 'Crystallization parameters verified.',
              'created_at': now,
            },
          ],
        },
      ];

      when(() => mockApiClient.fetchForumPosts(any())).thenAnswer(
        (_) async => HttpResponse<dynamic>(
          remoteData,
          Response(requestOptions: RequestOptions()),
        ),
      );

      final posts = await remoteDataSource.fetchForumPosts();
      expect(posts.length, equals(1));
      expect(posts.first.title, equals('Isolation of Radium'));

      // Verify SQLite cache was populated
      final cachedPosts = await localDataSource.getForumPosts();
      expect(cachedPosts.length, equals(1));
      expect(cachedPosts.first.id, equals('post_radioactivity'));
      expect(cachedPosts.first.replies.length, equals(1));
      expect(cachedPosts.first.replies.first.authorName, equals('Pierre Curie'));
    });

    test('fetchForumPosts returns cached posts when offline without throwing', () async {
      final now = DateTime.now().toIso8601String();
      // Pre-seed SQLite cache
      await localDataSource.saveForumPost(
        ForumPostModel(
          id: 'cached_post_offline',
          authorId: 'user_offline',
          authorName: 'Offline Scholar',
          track: 'Chemistry',
          title: 'Catalytic Hydrogenation',
          content: 'Raney nickel mechanisms',
          createdAt: DateTime.parse(now),
        ),
      );

      // Simulate network disconnection
      when(() => mockApiClient.fetchForumPosts(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(),
          type: DioExceptionType.connectionError,
          message: 'No Internet connection',
        ),
      );

      final posts = await remoteDataSource.fetchForumPosts(track: 'Chemistry');
      expect(posts.length, equals(1));
      expect(posts.first.id, equals('cached_post_offline'));
      expect(posts.first.title, equals('Catalytic Hydrogenation'));
    });

    test('createForumPost stores created post into SQLite cache', () async {
      final now = DateTime.now().toIso8601String();
      final postPayload = {
        'id': 'post_created_new',
        'author_id': 'user_42',
        'author_name': 'Scholar Marie',
        'track': 'Biology',
        'title': 'DNA Polymerase III',
        'content': 'Proofreading activity',
        'created_at': now,
      };

      when(() => mockApiClient.createForumPost(any())).thenAnswer(
        (_) async => HttpResponse<dynamic>(
          [postPayload],
          Response(requestOptions: RequestOptions()),
        ),
      );

      final created = await remoteDataSource.createForumPost(
        title: 'DNA Polymerase III',
        content: 'Proofreading activity',
        track: 'Biology',
      );

      expect(created.id, equals('post_created_new'));

      final cachedPost = await localDataSource.getForumPost('post_created_new');
      expect(cachedPost, isNotNull);
      expect(cachedPost!.title, equals('DNA Polymerase III'));
    });
  });
}
