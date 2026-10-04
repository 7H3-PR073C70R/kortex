import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/services/user_activity_service.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/core/sync/app_sync_engine.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/core/utils/uuid_utils.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/data/data_sources/community_remote_data_source.dart';
import 'package:kortex/src/features/community/data/models/forum_post_model.dart';
import 'package:kortex/src/features/community/data/repositories/community_repository_impl.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';
import 'package:kortex/src/features/community/domain/services/forum_offline_sync_queue.dart';
import 'package:kortex/src/features/dashboard/data/client/dashboard_api_client.dart';
import 'package:kortex/src/features/dashboard/data/data_sources/dashboard_remote_data_source_impl.dart';
import 'package:kortex/src/features/dashboard/data/models/dashboard_feed_model.dart';
import 'package:kortex/src/features/decks/data/client/decks_api_client.dart';
import 'package:kortex/src/features/decks/data/data_sources/card_sync_queue.dart';
import 'package:kortex/src/features/decks/data/data_sources/decks_remote_data_source_impl.dart';
import 'package:kortex/src/features/decks/data/models/deck_model.dart';
import 'package:kortex/src/features/decks/domain/logic/fsrs_scheduler.dart';
import 'package:kortex/src/features/decks/domain/repositories/decks_repository.dart';
import 'package:kortex/src/features/decks/domain/services/study_engine_router.dart';
import 'package:kortex/src/features/ingestion/domain/repositories/ingestion_repository.dart';
import 'package:kortex/src/features/planner/data/models/exam_event_model.dart';
import 'package:kortex/src/features/planner/data/repositories/planner_repository_impl.dart';
import 'package:kortex/src/features/quiz/data/repositories/quiz_repository_impl.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:mocktail/mocktail.dart';
import 'package:retrofit/retrofit.dart';

class MockLocalStorageService extends Mock implements LocalStorageService {}

class MockUserStorageService extends Mock implements UserStorageService {}

class MockDio extends Mock implements Dio {}

class MockConnectivity extends Mock implements Connectivity {}

class MockCommunityRemoteDataSource extends Mock
    implements CommunityRemoteDataSource {}

class MockCommunityRepository extends Mock implements CommunityRepository {}

class MockDashboardApiClient extends Mock implements DashboardApiClient {}

class MockDecksApiClient extends Mock implements DecksApiClient {}

class MockDecksRepository extends Mock implements DecksRepository {}

class MockIngestionRepository extends Mock implements IngestionRepository {}

class MockStudyEngineRouter extends Mock implements StudyEngineRouter {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    dotenv.loadFromString(
      envString: 'API_BASE_URL=https://mock.supabase.co\nAPI_KEY=mock_key\n',
    );
    registerFallbackValue(RequestOptions());
    registerFallbackValue(Options());
  });

  group('Offline Data Synchronization Validation Suite', () {
    late MockLocalStorageService mockStorage;
    late MockUserStorageService mockUserStorage;
    late MockDio mockDio;
    final inMemoryStorage = <String, String>{};

    setUp(() {
      inMemoryStorage.clear();
      mockStorage = MockLocalStorageService();
      mockUserStorage = MockUserStorageService();
      mockDio = MockDio();

      when(() => mockStorage.getPreference(key: any(named: 'key')))
          .thenAnswer((inv) => inMemoryStorage[inv.namedArguments[#key] as String]);
      when(() => mockStorage.savePreference(
            key: any(named: 'key'),
            data: any(named: 'data'),
          )).thenAnswer((inv) async {
        inMemoryStorage[inv.namedArguments[#key] as String] =
            inv.namedArguments[#data] as String;
      });
      when(() => mockStorage.deletePreference(key: any(named: 'key')))
          .thenAnswer((inv) async {
        inMemoryStorage.remove(inv.namedArguments[#key] as String);
      });

      when(() => mockUserStorage.getToken()).thenReturn('mock-token-jwt');
      when(() => mockUserStorage.getUserId()).thenReturn('mock-user-uuid');
    });

    tearDown(() async {
      if (locator.isRegistered<CommunityRepository>()) {
        await locator.unregister<CommunityRepository>();
      }
    });

    test('1. Planner: Offline created exam uses valid RFC4122 UUID and is pushed on getActiveExams', () async {
      final repo = PlannerRepositoryImpl(
        storageService: mockStorage,
        userStorageService: mockUserStorage,
        dio: mockDio,
      );

      // Create exam offline (Dio will fail / throw)
      when(() => mockDio.post<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenThrow(DioException(
        requestOptions: RequestOptions(),
        type: DioExceptionType.connectionError,
      ));

      final createRes = await repo.createExam(
        examName: 'WAEC Physics Paper 1',
        subjectTrack: 'Physics',
        targetDate: DateTime.now().add(const Duration(days: 30)),
      );

      expect(createRes.isRight, isTrue);
      final createdExam = createRes.fold((_) => null, (e) => e)!;
      // Must be a valid UUID for remote database compatibility
      expect(UuidUtils.isValidUuid(createdExam.id), isTrue);

      // Simulate network coming back online: getActiveExams() should auto-push local exam to backend
      var pushedToRemote = false;
      when(() => mockDio.post<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer((inv) async {
        pushedToRemote = true;
        return Response(
          requestOptions: RequestOptions(),
          statusCode: 201,
          data: [ExamEventModel.fromEntity(createdExam).toJson()],
        );
      });

      when(() => mockDio.get<dynamic>(
            any(),
            options: any(named: 'options'),
          )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(),
            statusCode: 200,
            data: <Map<String, dynamic>>[],
          ));

      final activeExamsRes = await repo.getActiveExams();
      expect(activeExamsRes.isRight, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(pushedToRemote, isTrue);
      expect(activeExamsRes.fold((_) => <ExamEventModel>[], (l) => l).length, 1);
    });

    test('2. Quiz/CBT: Failed remote submission queues offline and is flushed to backend', () async {
      final repo = QuizRepositoryImpl(
        decksRepository: MockDecksRepository(),
        ingestionRepository: MockIngestionRepository(),
        studyEngineRouter: MockStudyEngineRouter(),
        dio: mockDio,
        localStorageService: mockStorage,
        userStorageService: mockUserStorage,
      );

      // Simulate remote failure when submitting quiz
      when(() => mockDio.post<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenThrow(DioException(
        requestOptions: RequestOptions(),
        type: DioExceptionType.connectionTimeout,
      ));

      const question = QuizQuestionEntity(
        id: 'q-1',
        prompt: 'What is photosynthesis?',
        type: QuizQuestionType.multipleChoice,
        options: ['Light conversion', 'Dark reaction', 'Digestion', 'Respiration'],
        correctAnswer: 'Light conversion',
        explanation: 'Converts light energy to chemical energy',
        subTopic: 'Biology Fundamentals',
        isAnswered: true,
        isCorrect: true,
        userSelectedAnswer: 'Light conversion',
      );

      final saveRes = await repo.submitQuizAnswers(
        quizTitle: 'JAMB Biology Mock',
        questions: const [question],
        durationSeconds: 120,
      );
      expect(saveRes.isRight, isTrue);

      // Verify item queued in local storage
      final queuedRaw = inMemoryStorage['__kortex_pending_quiz_submissions'];
      expect(queuedRaw, isNotNull);
      final queuedList = jsonDecode(queuedRaw!) as List;
      expect(queuedList.length, 1);
      final firstQueued = queuedList.first as Map<String, dynamic>;
      expect(firstQueued['title'], 'JAMB Biology Mock');

      // Now simulate network restoration: flushPendingQuizSubmissions should post to backend and clear queue
      var remoteSyncCount = 0;
      when(() => mockDio.post<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer((_) async {
        remoteSyncCount++;
        return Response(
          requestOptions: RequestOptions(),
          statusCode: 201,
          data: {'success': true},
        );
      });

      final syncedCount = await repo.flushPendingQuizSubmissions();
      expect(syncedCount, 1);
      expect(remoteSyncCount, 1);
      expect(inMemoryStorage['__kortex_pending_quiz_submissions'], isNull);
    });

    test('3. XP & Streak: Offline XP awards accumulate and sync atomically on reconnection', () async {
      final mockCommunityRepo = MockCommunityRepository();
      if (locator.isRegistered<CommunityRepository>()) {
        await locator.unregister<CommunityRepository>();
      }
      locator.registerSingleton<CommunityRepository>(mockCommunityRepo);

      final service = UserActivityServiceImpl(mockStorage);

      // Simulate offline: syncUserProgress fails
      when(() => mockCommunityRepo.syncUserProgress(
            xpDelta: any(named: 'xpDelta'),
            streakDays: any(named: 'streakDays'),
            track: any(named: 'track'),
          )).thenAnswer((_) async => const Left(ServerFailure(message: 'Network offline')));

      await service.awardXp(XpActivityCategory.quizCompletion);
      await service.awardXp(XpActivityCategory.cardReview);

      // Verify pending delta accumulated in storage
      final pendingRaw = inMemoryStorage['__kortex_pending_xp_delta'];
      expect(pendingRaw, isNotNull);
      final totalPendingXp = int.parse(pendingRaw!);
      expect(totalPendingXp, 110); // 100 for quiz completion + 10 for card review

      // Now simulate reconnect: syncUserProgress succeeds
      when(() => mockCommunityRepo.syncUserProgress(
            xpDelta: 110,
            streakDays: any(named: 'streakDays'),
            track: any(named: 'track'),
          )).thenAnswer((_) async => const Right({'status': 'ok'}));

      await service.syncPendingProgressToBackend();

      // Verify pending delta cleared on successful sync
      expect(inMemoryStorage['__kortex_pending_xp_delta'], isNull);
    });

    test('4. Community: Offline post is persisted in ForumOfflineSyncQueue and synced via flushPendingForumActions', () async {
      final mockRemote = MockCommunityRemoteDataSource();
      final queue = ForumOfflineSyncQueue(localStorageService: mockStorage);
      final repo = CommunityRepositoryImpl(
        mockRemote,
        userStorage: mockUserStorage,
        offlineSyncQueue: queue,
      );

      // Simulate remote failure when creating post offline
      when(() => mockRemote.createForumPost(
            title: any(named: 'title'),
            content: any(named: 'content'),
            track: any(named: 'track'),
            latexContent: any(named: 'latexContent'),
            isQuestion: any(named: 'isQuestion'),
            syllabusTag: any(named: 'syllabusTag'),
            tags: any(named: 'tags'),
            mediaUrls: any(named: 'mediaUrls'),
            voiceNoteUrl: any(named: 'voiceNoteUrl'),
            voiceNoteDurationSeconds: any(named: 'voiceNoteDurationSeconds'),
            voiceNoteTranscript: any(named: 'voiceNoteTranscript'),
            isAnonymous: any(named: 'isAnonymous'),
          )).thenThrow(Exception('Simulated offline SocketException'));

      final createRes = await repo.createForumPost(
        title: 'Offline Post Title',
        content: 'Offline question details',
        track: 'WAEC',
      );

      // Optimistic response returned to UI
      expect(createRes.isRight, isTrue);
      expect(queue.hasPendingActions, isTrue);
      expect(queue.queueLength, 1);

      // When network returns, remote call succeeds
      final createdModel = ForumPostModel(
        id: 'remote-post-uuid',
        title: 'Offline Post Title',
        content: 'Offline question details',
        track: 'WAEC',
        authorId: 'mock-user-uuid',
        authorName: 'You',
        createdAt: DateTime.now(),
      );
      when(() => mockRemote.createForumPost(
            title: any(named: 'title'),
            content: any(named: 'content'),
            track: any(named: 'track'),
            latexContent: any(named: 'latexContent'),
            isQuestion: any(named: 'isQuestion'),
            syllabusTag: any(named: 'syllabusTag'),
            tags: any(named: 'tags'),
            mediaUrls: any(named: 'mediaUrls'),
            voiceNoteUrl: any(named: 'voiceNoteUrl'),
            voiceNoteDurationSeconds: any(named: 'voiceNoteDurationSeconds'),
            voiceNoteTranscript: any(named: 'voiceNoteTranscript'),
            isAnonymous: any(named: 'isAnonymous'),
          )).thenAnswer((_) async => createdModel);

      final syncedCount = await repo.flushPendingForumActions();
      expect(syncedCount, 1);
      expect(queue.hasPendingActions, isFalse);
    });

    test('5. Dashboard: Empty remote courses auto-syncs locally saved curated courses', () async {
      final mockClient = MockDashboardApiClient();
      final dataSource = DashboardRemoteDataSourceImpl(
        mockClient,
        storageService: mockStorage,
      );

      // Pre-populate local storage with curated courses saved offline
      final localCourses = [
        const CuratedCourseModel(
          id: 'course-phy',
          courseCode: 'PHY',
          title: 'Physics',
          department: 'Science',
          totalMaterials: 20,
          hasActivePastPapers: true,
          iconName: 'school',
          colorHex: '#6366F1',
        ),
      ];
      inMemoryStorage[PrefKeys.userCuratedCourses] =
          jsonEncode(localCourses.map((c) => c.toJson()).toList());

      // Remote returns empty list
      when(mockClient.getUserCuratedCourses)
          .thenAnswer((_) async => <CuratedCourseModel>[]);

      var syncedToRemote = false;
      when(() => mockClient.syncUserCourses(any())).thenAnswer((_) async {
        syncedToRemote = true;
        return HttpResponse(null, Response(requestOptions: RequestOptions()));
      });

      final result = await dataSource.getUserCuratedCourses();
      expect(result.isNotEmpty, isTrue);
      expect(result.first.courseCode, 'PHY');
      expect(syncedToRemote, isTrue);
    });

    test('6. Flashcards / FSRS: Offline reviews are buffered in CardSyncQueue and flushed via RPC on reconnection', () async {
      final queue = CardSyncQueue(
        dio: mockDio,
        storageService: mockStorage,
        userStorageService: mockUserStorage,
        authToken: 'test-token',
      );

      final log = FsrsReviewLog(
        id: 'log-1',
        transactionUuid: UuidUtils.generate(),
        cardId: 'card-123',
        rating: FsrsRating.good,
        stability: 2.5,
        difficulty: 4,
        elapsedDays: 1,
        scheduledDays: 3,
        reviewedAtUtc: DateTime.now().toUtc(),
        reviewedAtEpoch: DateTime.now().millisecondsSinceEpoch,
        state: FsrsCardState.review,
      );

      // Enqueue offline review
      await queue.enqueueReview(log);
      expect(queue.getPendingCount(), 1);

      // Verify stored locally in storageKey
      final storedLogs = inMemoryStorage[CardSyncQueue.storageKey];
      expect(storedLogs, isNotNull);
      expect(storedLogs!.contains(log.transactionUuid), isTrue);

      // Reconnect and flush
      var rpcCalled = false;
      when(() => mockDio.post<dynamic>(
            any(that: contains('upsert_fsrs_review_batch')),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer((inv) async {
        rpcCalled = true;
        return Response(
          requestOptions: RequestOptions(),
          statusCode: 200,
          data: {'processed': 1},
        );
      });

      final syncedCount = await queue.flushPendingLogs();
      expect(syncedCount, 1);
      expect(rpcCalled, isTrue);
      expect(queue.getPendingCount(), 0);
    });

    test('7. Decks: Offline created deck with UUID is synced to Supabase when back online via getUserDecks', () async {
      final mockDecksClient = MockDecksApiClient();
      final offlineDeckId = UuidUtils.generate();
      final offlineDeck = DeckModel(
        id: offlineDeckId,
        title: 'Offline Chemistry Deck',
        subject: 'Chemistry',
        category: 'General',
        totalCards: 5,
        dueCards: 5,
        masteryRate: 0,
      );

      // Pre-populate offline deck in local storage
      inMemoryStorage[PrefKeys.persistedUserDecks] =
          jsonEncode([offlineDeck.toJson()]);

      final dataSource = DecksRemoteDataSourceImpl(
        mockDecksClient,
        userStorage: mockUserStorage,
        storageService: mockStorage,
      );

      // Remote returns empty list (first time online after offline creation)
      when(mockDecksClient.getUserDecks).thenAnswer((_) async => <DeckModel>[]);

      var createdRemoteRecord = false;
      when(() => mockDecksClient.createDeckRecord(any())).thenAnswer((inv) async {
        createdRemoteRecord = true;
        final data = inv.positionalArguments[0] as Map<String, dynamic>;
        expect(data['id'], offlineDeckId);
        expect(data['title'], 'Offline Chemistry Deck');
        return HttpResponse(null, Response(requestOptions: RequestOptions()));
      });

      final decks = await dataSource.getUserDecks();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(decks.length, 1);
      expect(decks.first.id, offlineDeckId);
      expect(createdRemoteRecord, isTrue);
    });

    test('8. Connectivity Auto-Flush: QuizRepository triggers flushPendingQuizSubmissions on network reconnection', () async {
      final connectivityController = StreamController<List<ConnectivityResult>>.broadcast();
      final mockConnectivity = MockConnectivity();
      when(() => mockConnectivity.onConnectivityChanged)
          .thenAnswer((_) => connectivityController.stream);

      // Queue an offline quiz submission
      final pendingSubmissions = [
        {
          'id': UuidUtils.generate(),
          'quiz_id': 'quiz-offline-1',
          'title': 'Offline Math Exam',
          'score': 85.0,
          'user_id': 'mock-user-uuid',
        }
      ];
      inMemoryStorage['__kortex_pending_quiz_submissions'] =
          jsonEncode(pendingSubmissions);

      var remotePostCount = 0;
      when(() => mockDio.post<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer((_) async {
        remotePostCount++;
        return Response(
          requestOptions: RequestOptions(),
          statusCode: 201,
          data: {'status': 'success'},
        );
      });

      final repo = QuizRepositoryImpl(
        decksRepository: MockDecksRepository(),
        ingestionRepository: MockIngestionRepository(),
        studyEngineRouter: MockStudyEngineRouter(),
        dio: mockDio,
        localStorageService: mockStorage,
        userStorageService: mockUserStorage,
        connectivity: mockConnectivity,
      );

      expect(inMemoryStorage['__kortex_pending_quiz_submissions'], isNotNull);

      // Emit network restored event (wifi)
      connectivityController.add([ConnectivityResult.wifi]);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(remotePostCount, 1);
      expect(inMemoryStorage['__kortex_pending_quiz_submissions'], isNull);

      await connectivityController.close();
      await repo.dispose();
    });

    test('9. Connectivity Auto-Sync: PlannerRepository triggers getActiveExams and flushes deletions on reconnection', () async {
      final connectivityController = StreamController<List<ConnectivityResult>>.broadcast();
      final mockConnectivity = MockConnectivity();
      when(() => mockConnectivity.onConnectivityChanged)
          .thenAnswer((_) => connectivityController.stream);

      // Record a pending deletion offline
      final deletedExamId = UuidUtils.generate();
      inMemoryStorage['__kortex_pending_exam_deletions'] =
          jsonEncode([deletedExamId]);

      var remoteDeleteCalled = false;
      when(() => mockDio.delete<dynamic>(any())).thenAnswer((inv) async {
        remoteDeleteCalled = true;
        return Response(requestOptions: RequestOptions(), statusCode: 204);
      });
      when(() => mockDio.get<dynamic>(any(), options: any(named: 'options')))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(),
                statusCode: 200,
                data: <Map<String, dynamic>>[],
              ));

      final repo = PlannerRepositoryImpl(
        storageService: mockStorage,
        userStorageService: mockUserStorage,
        dio: mockDio,
        connectivity: mockConnectivity,
      );

      // Emit network reconnect
      connectivityController.add([ConnectivityResult.mobile]);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(remoteDeleteCalled, isTrue);
      expect(inMemoryStorage['__kortex_pending_exam_deletions'], isNull);

      await connectivityController.close();
      await repo.dispose();
    });

    test('10. AppSyncEngine: Merges CRDT deltas and dispatches syncAll on network reconnection', () async {
      final connectivityController = StreamController<List<ConnectivityResult>>.broadcast();
      final mockConnectivity = MockConnectivity();
      when(() => mockConnectivity.onConnectivityChanged)
          .thenAnswer((_) => connectivityController.stream);

      final engine = AppSyncEngine(
        dio: mockDio,
        connectivity: mockConnectivity,
        storageService: mockStorage,
        userStorageService: mockUserStorage,
      );

      // Verify CRDT field-level delta merging
      final payload1 = AppSyncPayload(
        id: 'settings_doc',
        type: 'settings',
        data: {'theme': 'dark', 'volume': 80},
        timestampEpoch: 1000,
      );
      final payload2 = AppSyncPayload(
        id: 'settings_doc',
        type: 'settings',
        data: {'volume': 95, 'notifications': true},
        timestampEpoch: 2000,
      );

      final merged = engine.mergeCrdtPayload(payload1, payload2);
      expect(merged.data['theme'], 'dark');
      expect(merged.data['volume'], 95);
      expect(merged.data['notifications'], true);
      expect(merged.timestampEpoch, 2000);

      // Pre-seed storage queue with merged payload to simulate offline state
      inMemoryStorage[AppSyncEngine.storageKey] = jsonEncode([merged.toMap()]);

      // Re-instantiate engine to load persisted queue safely
      final onlineEngine = AppSyncEngine(
        dio: mockDio,
        connectivity: mockConnectivity,
        storageService: mockStorage,
        userStorageService: mockUserStorage,
      );

      var upsertCalled = false;
      when(() => mockDio.post<dynamic>(
            any(that: contains('app_sync_engine_upsert')),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer((inv) async {
        upsertCalled = true;
        return Response(requestOptions: RequestOptions(), statusCode: 200);
      });

      // Emit network online event
      connectivityController.add([ConnectivityResult.wifi]);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(upsertCalled, isTrue);
      expect(inMemoryStorage[AppSyncEngine.storageKey], isNull);

      await connectivityController.close();
      await engine.dispose();
      await onlineEngine.dispose();
    });
  });
}
