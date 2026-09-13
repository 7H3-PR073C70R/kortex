import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/data/client/community_api_client.dart';
import 'package:kortex/src/features/community/data/data_sources/community_remote_data_source_impl.dart';
import 'package:kortex/src/features/community/data/models/forum_post_model.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_event.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_hub_bloc.dart';
import 'package:mocktail/mocktail.dart';

class MockCommunityApiClient extends Mock implements CommunityApiClient {}

class MockCommunityRepository extends Mock implements CommunityRepository {}

class MockLocalStorageService extends Mock implements LocalStorageService {}

class MockUserStorageService extends Mock implements UserStorageService {}

void main() {
  group('Forum Post Bookmarks & Management Tests', () {
    late MockLocalStorageService mockLocalStorageService;
    late MockUserStorageService mockUserStorageService;

    setUp(() async {
      mockLocalStorageService = MockLocalStorageService();
      mockUserStorageService = MockUserStorageService();

      if (locator.isRegistered<LocalStorageService>()) {
        await locator.unregister<LocalStorageService>();
      }
      locator.registerSingleton<LocalStorageService>(mockLocalStorageService);

      if (locator.isRegistered<UserStorageService>()) {
        await locator.unregister<UserStorageService>();
      }
      locator.registerSingleton<UserStorageService>(mockUserStorageService);
    });

    tearDown(() async {
      if (locator.isRegistered<LocalStorageService>()) {
        await locator.unregister<LocalStorageService>();
      }
      if (locator.isRegistered<UserStorageService>()) {
        await locator.unregister<UserStorageService>();
      }
    });

    test('toggleBookmarkForumPost updates local storage bookmarked IDs set correctly', () async {
      when(() => mockLocalStorageService.getPreference(key: 'forum_bookmarked_post_ids'))
          .thenReturn('["post-1"]');
      when(() => mockLocalStorageService.savePreference(
            key: any(named: 'key'),
            data: any(named: 'data'),
          )).thenAnswer((_) async {});

      final dataSource = CommunityRemoteDataSourceImpl(
        MockCommunityApiClient(),
        localStorage: mockLocalStorageService,
        userStorage: mockUserStorageService,
      );

      final res = await dataSource.toggleBookmarkForumPost('post-2');
      expect(res, isTrue); // Added post-2

      verify(
        () => mockLocalStorageService.savePreference(
          key: 'forum_bookmarked_post_ids',
          data: any(named: 'data', that: contains('post-2')),
        ),
      ).called(1);

      // Now toggle again to remove
      when(() => mockLocalStorageService.getPreference(key: 'forum_bookmarked_post_ids'))
          .thenReturn('["post-1", "post-2"]');
      final removeRes = await dataSource.toggleBookmarkForumPost('post-2');
      expect(removeRes, isFalse); // Removed post-2

      verify(
        () => mockLocalStorageService.savePreference(
          key: 'forum_bookmarked_post_ids',
          data: '["post-1"]',
        ),
      ).called(1);
    });

    test('CommunityHubBloc handles ToggleBookmarkForumPostEvent optimistically', () async {
      final mockRepo = MockCommunityRepository();
      when(() => mockRepo.toggleBookmarkForumPost(any()))
          .thenAnswer((_) async => const Right(true));
      when(mockRepo.getBookmarkedForumPostIds)
          .thenAnswer((_) async => const Right({'post-10'}));

      final bloc = CommunityHubBloc(repository: mockRepo);

      expect(bloc.state.bookmarkedPostIds, isEmpty);

      bloc.add(const ToggleBookmarkForumPostEvent('post-10'));
      await pumpEventQueue();

      expect(bloc.state.bookmarkedPostIds.contains('post-10'), isTrue);

      bloc.add(const ToggleBookmarkForumPostEvent('post-10'));
      await pumpEventQueue();

      expect(bloc.state.bookmarkedPostIds.contains('post-10'), isFalse);

      await bloc.close();
    });

    test('CommunityHubBloc handles DeleteForumPostEvent by removing post from state', () async {
      final mockRepo = MockCommunityRepository();
      when(() => mockRepo.deleteForumPost(any()))
          .thenAnswer((_) async => const Right(true));
      when(() => mockRepo.fetchForumPosts(
        track: any(named: 'track'),
        questionsOnly: any(named: 'questionsOnly'),
        sortFilter: any(named: 'sortFilter'),
        searchQuery: any(named: 'searchQuery'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      )).thenAnswer((_) async => const Right([]));
      when(mockRepo.getBookmarkedForumPostIds)
          .thenAnswer((_) async => const Right({}));

      final testPost = ForumPostEntity(
        id: 'post-delete-1',
        authorId: 'user-1',
        authorName: 'Alex',
        title: 'Delete me',
        content: 'Content',
        track: 'Medicine',
        tags: const ['test'],
        createdAt: DateTime.now(),
      );

      final bloc = CommunityHubBloc(repository: mockRepo);
      bloc.emit(bloc.state.copyWith(forumPosts: [testPost]));

      expect(bloc.state.forumPosts.length, 1);

      bloc.add(const DeleteForumPostEvent('post-delete-1'));
      await pumpEventQueue();

      expect(bloc.state.forumPosts.any((p) => p.id == 'post-delete-1'), isFalse);

      await bloc.close();
    });

    test('ForumPostModel extracts media URLs from content, markdown images, and JSON tags', () {
      final jsonWithComments = {
        'id': 'test-media-1',
        'author_id': 'user-1',
        'author_name': 'Toxic',
        'track': 'WAEC',
        'title': 'Testing post with images',
        'content': "Let's see how this works with some images.\n<!-- media: [\"https://example.com/photo.jpg\", \"/local/path/image.png\"] -->\n<!-- tags: [\"waec\", \"math\"] -->\n<!-- voice: audio/test.wav duration:15 -->",
        'created_at': DateTime.now().toIso8601String(),
      };

      final post = ForumPostModel.fromJson(jsonWithComments);

      expect(post.mediaUrls.length, 2);
      expect(post.mediaUrls, contains('https://example.com/photo.jpg'));
      expect(post.mediaUrls, contains('/local/path/image.png'));
      expect(post.tags, contains('waec'));
      expect(post.tags, contains('math'));
      expect(post.voiceNoteUrl, 'audio/test.wav');
      expect(post.voiceNoteDurationSeconds, 15);
    });

    test('ForumPostModel extracts markdown images and hashtags when metadata comments are absent', () {
      final jsonWithMarkdown = {
        'id': 'test-media-2',
        'author_id': 'user-2',
        'author_name': 'Sarah',
        'track': 'JAMB',
        'title': 'Question with diagram',
        'content': 'Here is the diagram:\n![Circuit diagram](https://example.com/diagram.png)\nWhat is the current? #physics #electricity',
        'created_at': DateTime.now().toIso8601String(),
      };

      final post = ForumPostModel.fromJson(jsonWithMarkdown);

      expect(post.mediaUrls.length, 1);
      expect(post.mediaUrls.first, 'https://example.com/diagram.png');
      expect(post.tags, contains('physics'));
      expect(post.tags, contains('electricity'));
    });

    test('ForumReplyModel extracts media and voice attachments from content', () {
      final replyJson = {
        'id': 'reply-media-1',
        'post_id': 'post-1',
        'author_id': 'user-3',
        'author_name': 'Elena',
        'content':
            'Check this solution step:\n<!-- media: ["https://example.com/sol.png"] -->\n<!-- voice: audio/reply.wav duration:8 -->',
        'created_at': DateTime.now().toIso8601String(),
      };

      final reply = ForumReplyModel.fromJson(replyJson);

      expect(reply.mediaUrls.length, 1);
      expect(reply.mediaUrls.first, 'https://example.com/sol.png');
      expect(reply.voiceNoteUrl, 'audio/reply.wav');
      expect(reply.voiceNoteDurationSeconds, 8);
    });
  });
}
