import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/database/app_database.dart';
import 'package:kortex/src/core/networking/realtime/realtime_client.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/data/client/community_api_client.dart';
import 'package:kortex/src/features/community/data/data_sources/community_remote_data_source_impl.dart';
import 'package:kortex/src/features/community/data/repositories/community_repository_impl.dart';
import 'package:kortex/src/features/dashboard/data/client/dashboard_api_client.dart';
import 'package:kortex/src/features/dashboard/data/data_sources/dashboard_remote_data_source_impl.dart';
import 'package:kortex/src/features/decks/data/data_sources/decks_local_data_source.dart';
import 'package:kortex/src/features/decks/data/data_sources/decks_remote_data_source.dart';
import 'package:kortex/src/features/decks/data/models/deck_model.dart';
import 'package:kortex/src/features/decks/data/models/flashcard_model.dart';
import 'package:kortex/src/features/planner/data/repositories/planner_repository_impl.dart';
import 'package:kortex/src/features/planner/domain/logic/cram_workload_calculator.dart';
import 'package:kortex/src/features/quiz/data/data_sources/past_questions_local_data_source.dart';
import 'package:kortex/src/features/quiz/data/data_sources/past_questions_remote_data_source.dart';
import 'package:kortex/src/features/quiz/data/models/past_question_model.dart';
import 'package:kortex/src/features/quiz/data/repositories/past_questions_repository_impl.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/features/syllabot/data/data_sources/syllabot_local_data_source.dart';
import 'package:kortex/src/features/syllabot/data/data_sources/syllabot_remote_data_source.dart';
import 'package:kortex/src/features/syllabot/data/models/chat_message_model.dart';
import 'package:kortex/src/features/syllabot/data/repositories/syllabot_repository_impl.dart';
import 'package:kortex/src/features/syllabot/domain/entities/chat_message_entity.dart';
import 'package:mocktail/mocktail.dart';
import 'package:retrofit/retrofit.dart';

class MockCommunityApiClient extends Mock implements CommunityApiClient {}
class MockDashboardApiClient extends Mock implements DashboardApiClient {}
class MockUserStorageService extends Mock implements UserStorageService {}
class MockRealtimeClient extends Mock implements RealtimeClient {}
class MockLocalStorageService extends Mock implements LocalStorageService {}
class MockDecksLocalDataSource extends Mock implements DecksLocalDataSource {}
class MockDecksRemoteDataSource extends Mock implements DecksRemoteDataSource {}
class MockPastQuestionsLocalDataSource extends Mock implements PastQuestionsLocalDataSource {}
class MockPastQuestionsRemoteDataSource extends Mock implements PastQuestionsRemoteDataSource {}
class MockSyllabotLocalDataSource extends Mock implements SyllabotLocalDataSource {}
class MockSyllabotRemoteDataSource extends Mock implements SyllabotRemoteDataSource {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      ChatMessageEntity(
        id: 'fallback_msg',
        sessionId: 'fallback_sess',
        sender: MessageSender.syllabot,
        text: 'fallback',
        timestamp: DateTime.now(),
      ),
    );
    registerFallbackValue(
      const DeckModel(
        id: 'fallback',
        title: 'Fallback',
        subject: 'General',
        totalCards: 0,
        dueCards: 0,
        masteryRate: 0,
        category: 'General',
      ),
    );
    registerFallbackValue(
      const FlashcardModel(id: 'fallback_c', deckId: 'fallback', front: 'Q', back: 'A'),
    );
  });

  group('CommunityRemoteDataSource Offline Resilience', () {
    late MockCommunityApiClient mockApiClient;
    late MockUserStorageService mockUserStorage;
    late MockRealtimeClient mockRealtime;
    late MockLocalStorageService mockLocalStorage;
    late CommunityRemoteDataSourceImpl remoteDataSource;

    setUp(() {
      mockApiClient = MockCommunityApiClient();
      mockUserStorage = MockUserStorageService();
      mockRealtime = MockRealtimeClient();
      mockLocalStorage = MockLocalStorageService();

      when(() => mockUserStorage.getUserId()).thenReturn('user_42');
      when(() => mockUserStorage.getUserDisplayName()).thenReturn('Scholar Marie');

      remoteDataSource = CommunityRemoteDataSourceImpl(
        mockApiClient,
        userStorage: mockUserStorage,
        realtimeClient: mockRealtime,
        localStorage: mockLocalStorage,
      );
    });

    test('fetchStudyRooms returns cached or curated rooms when network throws DioException', () async {
      when(() => mockApiClient.fetchStudyRooms(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(),
          type: DioExceptionType.connectionError,
        ),
      );
      when(() => mockLocalStorage.getPreference(key: PrefKeys.persistedStudyRooms))
          .thenReturn(null);

      final rooms = await remoteDataSource.fetchStudyRooms();
      expect(rooms, isNotEmpty);
      expect(rooms.any((r) => r.title.contains('Pomodoro')), isTrue);
    });

    test('fetchStudyCircles returns curated circles when offline', () async {
      when(() => mockApiClient.fetchStudyCircles(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(),
          type: DioExceptionType.connectionError,
        ),
      );
      when(() => mockLocalStorage.getPreference(key: PrefKeys.persistedStudyCircles))
          .thenReturn(null);

      final circles = await remoteDataSource.fetchStudyCircles(track: 'WAEC');
      expect(circles, isNotEmpty);
      expect(circles.first.track, equals('WAEC'));
    });

    test('fetchSharedDecks returns curated decks when offline', () async {
      when(() => mockApiClient.fetchSharedDecks(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(),
          type: DioExceptionType.connectionError,
        ),
      );
      when(() => mockLocalStorage.getPreference(key: PrefKeys.persistedSharedDecks))
          .thenReturn(null);

      final decks = await remoteDataSource.fetchSharedDecks(subject: 'Physics');
      expect(decks, isNotEmpty);
      expect(decks.first.subject, equals('Physics'));
    });
  });

  group('PastQuestionsRepository Write-Through Caching', () {
    late MockPastQuestionsLocalDataSource mockLocal;
    late MockPastQuestionsRemoteDataSource mockRemote;
    late PastQuestionsRepositoryImpl repository;

    setUp(() {
      mockLocal = MockPastQuestionsLocalDataSource();
      mockRemote = MockPastQuestionsRemoteDataSource();
      when(() => mockLocal.initialize()).thenAnswer((_) async {});
      repository = PastQuestionsRepositoryImpl(
        mockRemote,
        localDataSource: mockLocal,
      );
    });

    test('getPastQuestions saves remote results to local database on cache miss', () async {
      when(
        () => mockLocal.getPastQuestions(
          examCategory: any(named: 'examCategory'),
          subject: any(named: 'subject'),
          year: any(named: 'year'),
          searchQuery: any(named: 'searchQuery'),
          courseId: any(named: 'courseId'),
          courseCode: any(named: 'courseCode'),
        ),
      ).thenAnswer((_) async => []);

      const remoteQuestion = PastQuestionModel(
        id: 'pq_write_through_1',
        examType: ExamCategory.waec,
        subject: 'Math',
        year: 2024,
        questionNumber: 1,
        prompt: 'Solve for x',
        options: ['1', '2', '3', '4'],
        correctOptionIndex: 0,
        correctOptionLabel: 'A',
        explanation: 'x = 1',
        topic: 'Algebra',
      );

      when(
        () => mockRemote.getPastQuestions(
          examCategory: any(named: 'examCategory'),
          subject: any(named: 'subject'),
          year: any(named: 'year'),
          searchQuery: any(named: 'searchQuery'),
          courseId: any(named: 'courseId'),
          courseCode: any(named: 'courseCode'),
        ),
      ).thenAnswer((_) async => [remoteQuestion]);

      when(() => mockLocal.savePastQuestions(any())).thenAnswer((_) async {});

      final result = await repository.getPastQuestions(
        examCategory: ExamCategory.waec,
        subject: 'Math',
      );

      expect(result.isRight, isTrue);
      verify(() => mockLocal.savePastQuestions(any())).called(1);
    });
  });

  group('CommunityRepository Marketplace Deck Cloning Card Persistence', () {
    late MockCommunityApiClient mockApiClient;
    late MockDecksLocalDataSource mockDecksLocal;
    late MockDecksRemoteDataSource mockDecksRemote;
    late MockLocalStorageService mockLocalStorage;

    setUp(() async {
      await locator.reset();
      mockApiClient = MockCommunityApiClient();
      mockDecksLocal = MockDecksLocalDataSource();
      mockDecksRemote = MockDecksRemoteDataSource();
      mockLocalStorage = MockLocalStorageService();

      locator
        ..registerSingleton<DecksLocalDataSource>(mockDecksLocal)
        ..registerSingleton<DecksRemoteDataSource>(mockDecksRemote)
        ..registerSingleton<LocalStorageService>(mockLocalStorage);
    });

    tearDown(locator.reset);

    test('cloneSharedDeck saves extracted flashcards into local DB and cache', () async {
      final remoteDataSource = CommunityRemoteDataSourceImpl(
        mockApiClient,
        localStorage: mockLocalStorage,
      );
      final repo = CommunityRepositoryImpl(remoteDataSource);

      when(() => mockApiClient.cloneSharedDeck(any())).thenAnswer(
        (_) async => HttpResponse<dynamic>(
          {
            'success': true,
            'new_deck_id': 'cloned_123',
            'cloned_cards_count': 1,
            'cards': [
              {
                'id': 'card_orig_1',
                'front': 'Newton Second Law',
                'back': 'F = ma',
              }
            ],
          },
          Response(requestOptions: RequestOptions()),
        ),
      );

      when(() => mockDecksLocal.saveDeck(any(), cards: any(named: 'cards')))
          .thenAnswer((_) async {});
      when(
        () => mockDecksRemote.saveGeneratedDeck(
          deck: any(named: 'deck'),
          cards: any(named: 'cards'),
        ),
      ).thenAnswer((_) async {});
      when(() => mockLocalStorage.savePreference(key: any(named: 'key'), data: any(named: 'data')))
          .thenAnswer((_) async {});
      when(() => mockLocalStorage.getPreference(key: any(named: 'key'))).thenReturn(null);

      final result = await repo.cloneSharedDeck('shared_deck_abc');

      expect(result.isRight, isTrue);
      verify(() => mockDecksLocal.saveDeck(any(), cards: any(named: 'cards'))).called(1);
    });
  });

  group('PlannerRepositoryImpl SQLite Exam Event Deletion Suite', () {
    late AppDatabase appDatabase;
    late MockLocalStorageService mockLocalStorage;
    late PlannerRepositoryImpl plannerRepo;

    setUp(() {
      appDatabase = AppDatabase(NativeDatabase.memory());
      mockLocalStorage = MockLocalStorageService();
      when(() => mockLocalStorage.getPreference(key: any(named: 'key'))).thenReturn(null);
      when(() => mockLocalStorage.savePreference(key: any(named: 'key'), data: any(named: 'data')))
          .thenAnswer((_) async {});

      plannerRepo = PlannerRepositoryImpl(
        calculator: const CramWorkloadCalculator(),
        database: appDatabase,
        storageService: mockLocalStorage,
      );
    });

    tearDown(() async {
      await appDatabase.close();
    });

    test('deleteExam purges exam record from Drift AppDatabase and local state', () async {
      await appDatabase.upsertExamEvent(
        ExamEventsCompanion(
          id: const Value('exam_delete_test'),
          examName: const Value('WAEC Biology 2026'),
          targetDate: Value(DateTime.now().add(const Duration(days: 14))),
          createdAt: Value(DateTime.now()),
        ),
      );

      final before = await appDatabase.getExamEventById('exam_delete_test');
      expect(before, isNotNull);
      expect(before?.examName, equals('WAEC Biology 2026'));

      final result = await plannerRepo.deleteExam('exam_delete_test');
      expect(result.isRight, isTrue);

      final after = await appDatabase.getExamEventById('exam_delete_test');
      expect(after, isNull);
    });
  });

  group('DashboardRemoteDataSourceImpl Course Module SQLite Deletion Suite', () {
    late AppDatabase appDatabase;
    late MockDashboardApiClient mockApiClient;
    late MockLocalStorageService mockLocalStorage;
    late DashboardRemoteDataSourceImpl dashboardRemote;

    setUp(() async {
      await locator.reset();
      appDatabase = AppDatabase(NativeDatabase.memory());
      locator.registerSingleton<AppDatabase>(appDatabase);

      mockApiClient = MockDashboardApiClient();
      mockLocalStorage = MockLocalStorageService();

      when(() => mockLocalStorage.getPreference(key: any(named: 'key'))).thenReturn(null);
      when(() => mockLocalStorage.savePreference(key: any(named: 'key'), data: any(named: 'data')))
          .thenAnswer((_) async {});
      when(() => mockApiClient.syncUserCourses(any()))
          .thenAnswer((_) async => HttpResponse<dynamic>({'success': true}, Response(requestOptions: RequestOptions())));

      dashboardRemote = DashboardRemoteDataSourceImpl(
        mockApiClient,
        storageService: mockLocalStorage,
        database: appDatabase,
      );
    });

    tearDown(() async {
      await locator.reset();
      await appDatabase.close();
    });

    test('deleteCuratedCourse deletes course module from Drift AppDatabase', () async {
      await appDatabase.batchUpsertCourseModules([
        CourseModulesCompanion(
          id: const Value('course_mod_101'),
          courseCode: const Value('MTH 101'),
          title: const Value('Elementary Mathematics'),
          department: const Value('Sciences'),
          updatedAt: Value(DateTime.now()),
        ),
      ]);

      final before = await appDatabase.getCourseModuleById('course_mod_101');
      expect(before, isNotNull);
      expect(before?.courseCode, equals('MTH 101'));

      await dashboardRemote.deleteCuratedCourse('course_mod_101');

      final after = await appDatabase.getCourseModuleById('course_mod_101');
      expect(after, isNull);
    });
  });

  group('CommunityRemoteDataSourceImpl Local Storage Cache Write-Through Suite', () {
    late MockCommunityApiClient mockApiClient;
    late MockUserStorageService mockUserStorage;
    late MockRealtimeClient mockRealtime;
    late MockLocalStorageService mockLocalStorage;
    late CommunityRemoteDataSourceImpl remoteDataSource;

    setUp(() {
      mockApiClient = MockCommunityApiClient();
      mockUserStorage = MockUserStorageService();
      mockRealtime = MockRealtimeClient();
      mockLocalStorage = MockLocalStorageService();

      when(() => mockUserStorage.getUserId()).thenReturn('user_42');
      when(() => mockUserStorage.getUserDisplayName()).thenReturn('Scholar Marie');

      remoteDataSource = CommunityRemoteDataSourceImpl(
        mockApiClient,
        userStorage: mockUserStorage,
        realtimeClient: mockRealtime,
        localStorage: mockLocalStorage,
      );
    });

    test('createStudyRoom persists created room to LocalStorageService', () async {
      when(() => mockApiClient.createStudyRoom(any())).thenAnswer(
        (_) async => HttpResponse<dynamic>(
          [
            {
              'id': 'room_new_1',
              'title': 'Organic Chemistry Focus',
              'subject': 'Chemistry',
              'category': 'JAMB',
              'pomodoro_duration_minutes': 25,
              'pomodoro_state': 'focusing',
              'pomodoro_started_at': DateTime.now().toIso8601String(),
              'active_participants_count': 1,
              'ambient_sound_track': 'lofi',
              'is_silent_focus': true,
              'created_by': 'user_42',
            }
          ],
          Response(requestOptions: RequestOptions()),
        ),
      );

      when(() => mockLocalStorage.getPreference(key: PrefKeys.persistedStudyRooms))
          .thenReturn(null);
      when(() => mockLocalStorage.savePreference(key: any(named: 'key'), data: any(named: 'data')))
          .thenAnswer((_) async {});

      final created = await remoteDataSource.createStudyRoom(
        title: 'Organic Chemistry Focus',
        subject: 'Chemistry',
        category: 'JAMB',
        pomodoroMinutes: 25,
      );

      expect(created.id, equals('room_new_1'));
      verify(
        () => mockLocalStorage.savePreference(
          key: PrefKeys.persistedStudyRooms,
          data: any(named: 'data', that: contains('Organic Chemistry Focus')),
        ),
      ).called(1);
    });
  });

  group('SyllabotRepositoryImpl Remote Messages SQLite Write-Through Suite', () {
    late MockSyllabotRemoteDataSource mockRemote;
    late MockSyllabotLocalDataSource mockLocal;
    late SyllabotRepositoryImpl syllabotRepo;

    setUp(() {
      mockRemote = MockSyllabotRemoteDataSource();
      mockLocal = MockSyllabotLocalDataSource();
      syllabotRepo = SyllabotRepositoryImpl(
        remoteDataSource: mockRemote,
        localDataSource: mockLocal,
      );
    });

    test('getSessionMessages writes remote messages through to local cache', () async {
      final remoteMessages = [
        ChatMessageModel(
          id: 'msg_rem_1',
          sessionId: 'sess_100',
          userId: 'user_42',
          sender: 'syllabot',
          text: 'Kinematics is the branch of classical mechanics...',
          createdAt: DateTime.now(),
        ),
      ];

      when(() => mockRemote.getSessionMessages(sessionId: 'sess_100'))
          .thenAnswer((_) async => remoteMessages);
      when(() => mockLocal.cacheMessage(any())).thenAnswer((_) async {});

      final result = await syllabotRepo.getSessionMessages(sessionId: 'sess_100');

      expect(result.isRight, isTrue);
      final messages = result.fold((l) => <ChatMessageEntity>[], (r) => r);
      expect(messages.length, equals(1));
      expect(messages.first.id, equals('msg_rem_1'));
      verify(() => mockLocal.cacheMessage(any(that: isA<ChatMessageEntity>()))).called(1);
    });
  });
}
