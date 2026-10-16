import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/services/user_activity_service.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/features/decks/domain/repositories/decks_repository.dart';
import 'package:kortex/src/features/decks/domain/services/study_engine_router.dart';
import 'package:kortex/src/features/ingestion/domain/repositories/ingestion_repository.dart';
import 'package:kortex/src/features/quiz/data/repositories/quiz_repository_impl.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:mocktail/mocktail.dart';

class MockDecksRepository extends Mock implements DecksRepository {}

class MockIngestionRepository extends Mock implements IngestionRepository {}

class MockStudyEngineRouter extends Mock implements StudyEngineRouter {}

class MockDio extends Mock implements Dio {}

class MockUserActivityService extends Mock implements UserActivityService {}

class MockUserStorageService extends Mock implements UserStorageService {}

class InMemoryLocalStorageService extends Fake implements LocalStorageService {
  final Map<String, String> _store = {};

  @override
  String? getPreference({required String key}) => _store[key];

  @override
  Future<void> savePreference({
    required String key,
    required String data,
  }) async {
    _store[key] = data;
  }

  @override
  Future<void> deletePreference({required String key}) async {
    _store.remove(key);
  }
}

void main() {
  group('CBT Hardened Offline Submission Queue Test Suite (P2-05)', () {
    late MockDecksRepository mockDecksRepo;
    late MockIngestionRepository mockIngestionRepo;
    late MockStudyEngineRouter mockEngineRouter;
    late MockDio mockDio;
    late MockUserActivityService mockUserActivity;
    late MockUserStorageService mockUserStorage;
    late InMemoryLocalStorageService inMemoryStorage;
    late QuizRepositoryImpl repository;

    const testToken = 'valid-jwt-token-xyz';
    const testUserId = 'student-uuid-123';

    setUpAll(() {
      registerFallbackValue(RequestOptions(path: '/'));
      registerFallbackValue(Options());
    });

    setUp(() {
      mockDecksRepo = MockDecksRepository();
      mockIngestionRepo = MockIngestionRepository();
      mockEngineRouter = MockStudyEngineRouter();
      mockDio = MockDio();
      mockUserActivity = MockUserActivityService();
      mockUserStorage = MockUserStorageService();
      inMemoryStorage = InMemoryLocalStorageService();

      when(() => mockUserStorage.getToken()).thenReturn(testToken);
      when(() => mockUserStorage.getUserId()).thenReturn(testUserId);
      when(
        () => mockUserActivity.recordStudySession(
          cardsReviewed: any(named: 'cardsReviewed'),
          durationSeconds: any(named: 'durationSeconds'),
          retentionScore: any(named: 'retentionScore'),
          masteredCards: any(named: 'masteredCards'),
        ),
      ).thenAnswer((_) async {});

      repository = QuizRepositoryImpl(
        decksRepository: mockDecksRepo,
        ingestionRepository: mockIngestionRepo,
        studyEngineRouter: mockEngineRouter,
        dio: mockDio,
        localStorageService: inMemoryStorage,
        userStorageService: mockUserStorage,
        userActivityService: mockUserActivity,
      );
    });

    QuizQuestionEntity createDummyQuestion({
      required String id,
      required String prompt,
    }) {
      return QuizQuestionEntity(
        id: id,
        prompt: prompt,
        type: QuizQuestionType.multipleChoice,
        options: const ['A', 'B', 'C', 'D'],
        correctAnswer: 'A',
        explanation: 'Explanation for $prompt',
        subTopic: 'JAMB General',
        isAnswered: true,
        isCorrect: true,
        userSelectedAnswer: 'A',
      );
    }

    test('1. Concurrency Mutex: Multiple simultaneous flushes execute exactly one pass with zero double-posts', () async {
      // Seed queue with 1 item
      final queuedItem = {
        'id': 'attempt-001',
        'title': 'JAMB English 2024',
        'subject': 'Use of English',
        'total_questions': 10,
        'correct_answers': 9,
        'retry_count': 0,
      };
      await inMemoryStorage.savePreference(
        key: QuizRepositoryImpl.pendingQuizSubmissionsStorageKey,
        data: jsonEncode([queuedItem]),
      );

      var remotePostCount = 0;
      when(
        () => mockDio.post<dynamic>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async {
        remotePostCount++;
        // Simulate network latency
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return Response(
          requestOptions: RequestOptions(path: '/quizzes'),
          statusCode: 201,
          data: {'success': true},
        );
      });

      // Fire 5 concurrent flush calls simultaneously
      final results = await Future.wait([
        repository.flushPendingQuizSubmissions(),
        repository.flushPendingQuizSubmissions(),
        repository.flushPendingQuizSubmissions(),
        repository.flushPendingQuizSubmissions(),
        repository.flushPendingQuizSubmissions(),
      ]);

      // All 5 should resolve with 1 synced item
      for (final count in results) {
        expect(count, 1);
      }

      // Exactly 1 network request was made (zero double-posts)
      expect(remotePostCount, 1);
      expect(
        inMemoryStorage.getPreference(
          key: QuizRepositoryImpl.pendingQuizSubmissionsStorageKey,
        ),
        isNull,
      );
    });

    test('2. Mid-Flush Protection: Newly enqueued items during in-flight flush are preserved and reconciled', () async {
      // Seed item A
      final itemA = {
        'id': 'attempt-A',
        'title': 'JAMB Biology Exam A',
        'subject': 'Biology',
        'retry_count': 0,
      };
      await inMemoryStorage.savePreference(
        key: QuizRepositoryImpl.pendingQuizSubmissionsStorageKey,
        data: jsonEncode([itemA]),
      );

      final inFlightFlushSignal = Completer<void>();

      when(
        () => mockDio.post<dynamic>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((invocation) async {
        final data = invocation.namedArguments[const Symbol('data')] as Map;
        final id = data['id'];

        if (id == 'attempt-A') {
          // Mid-flush event: before item A returns, simulate offline submission of item B
          final rawCurrent = inMemoryStorage.getPreference(
            key: QuizRepositoryImpl.pendingQuizSubmissionsStorageKey,
          );
          final currentList = rawCurrent != null
              ? (jsonDecode(rawCurrent) as List<dynamic>)
              : <dynamic>[];
          final updatedList = List<dynamic>.from(currentList)
            ..add({
              'id': 'attempt-B',
              'title': 'JAMB Physics Exam B',
              'subject': 'Physics',
              'retry_count': 0,
              'payload': {
                'id': 'attempt-B',
                'title': 'JAMB Physics Exam B',
                'subject': 'Physics',
              },
            });

          await inMemoryStorage.savePreference(
            key: QuizRepositoryImpl.pendingQuizSubmissionsStorageKey,
            data: jsonEncode(updatedList),
          );

          if (!inFlightFlushSignal.isCompleted) {
            inFlightFlushSignal.complete();
          }

          return Response(
            requestOptions: RequestOptions(path: '/quizzes'),
            statusCode: 201,
            data: {'success': true},
          );
        }

        if (id == 'attempt-B') {
          return Response(
            requestOptions: RequestOptions(path: '/quizzes'),
            statusCode: 201,
            data: {'success': true},
          );
        }

        return Response(
          requestOptions: RequestOptions(path: '/quizzes'),
          statusCode: 200,
        );
      });

      // Start initial flush
      final synced = await repository.flushPendingQuizSubmissions();
      expect(synced, 1);

      // Verify that after reconciliation, item B is STILL present in storage (not clobbered by item A's flush)
      final afterFlushRaw = inMemoryStorage.getPreference(
        key: QuizRepositoryImpl.pendingQuizSubmissionsStorageKey,
      );
      expect(afterFlushRaw, isNotNull);
      final afterFlushList = jsonDecode(afterFlushRaw!) as List<dynamic>;
      expect(afterFlushList.length, 1);
      final preservedItem = afterFlushList.first as Map<String, dynamic>;
      expect(preservedItem['id'], 'attempt-B');

      // Now run another flush pass: item B flushes cleanly
      final secondSync = await repository.flushPendingQuizSubmissions();
      expect(secondSync, 1);
      expect(
        inMemoryStorage.getPreference(
          key: QuizRepositoryImpl.pendingQuizSubmissionsStorageKey,
        ),
        isNull,
      );
    });

    test('3. Auth Guard: Flush halts immediately when user token is missing/expired, avoiding 403 fallback', () async {
      // Seed queue
      final queuedItem = {
        'id': 'attempt-auth-test',
        'title': 'JAMB Chemistry',
        'subject': 'Chemistry',
        'retry_count': 0,
      };
      await inMemoryStorage.savePreference(
        key: QuizRepositoryImpl.pendingQuizSubmissionsStorageKey,
        data: jsonEncode([queuedItem]),
      );

      // User token is missing
      when(() => mockUserStorage.getToken()).thenReturn(null);

      final syncedCount = await repository.flushPendingQuizSubmissions();
      expect(syncedCount, 0);

      // Dio was never invoked, no unauthorized or apiKey requests
      verifyNever(
        () => mockDio.post<dynamic>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      );

      // Queue is preserved intact waiting for user login
      final raw = inMemoryStorage.getPreference(
        key: QuizRepositoryImpl.pendingQuizSubmissionsStorageKey,
      );
      expect(raw, isNotNull);
    });

    test('4. Queue Capacity Bounding: Max 50 pending submissions prunes oldest items', () async {
      // Simulate offline: Dio throws DioException
      when(
        () => mockDio.post<dynamic>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/quizzes'),
          error: 'Offline',
        ),
      );

      // Submit 55 submissions
      for (var i = 1; i <= 55; i++) {
        final attemptUuid =
            '00000000-0000-0000-0000-${i.toString().padLeft(12, '0')}';
        await repository.submitQuizAnswers(
          quizTitle: 'Quiz #$i',
          questions: [
            createDummyQuestion(id: 'q$i', prompt: 'Question $i'),
          ],
          durationSeconds: 60,
          attemptId: attemptUuid,
        );
      }

      final raw = inMemoryStorage.getPreference(
        key: QuizRepositoryImpl.pendingQuizSubmissionsStorageKey,
      );
      expect(raw, isNotNull);
      final list = jsonDecode(raw!) as List<dynamic>;

      // Strictly bounded at maxPendingSubmissions (50)
      expect(list.length, QuizRepositoryImpl.maxPendingSubmissions);
      expect(list.length, 50);

      // Oldest items (1..5) were dropped; items (6..55) are present
      final firstItem = list.first as Map<String, dynamic>;
      final lastItem = list.last as Map<String, dynamic>;
      expect(firstItem['id'], '00000000-0000-0000-0000-000000000006');
      expect(firstItem['title'], 'Quiz #6');
      expect(lastItem['id'], '00000000-0000-0000-0000-000000000055');
      expect(lastItem['title'], 'Quiz #55');
    });

    test('5. Exponential Backoff: Failed attempts back off and are skipped unless force=true', () async {
      final queuedItem = {
        'id': 'attempt-backoff-test',
        'title': 'JAMB Math',
        'subject': 'Mathematics',
        'retry_count': 0,
      };
      await inMemoryStorage.savePreference(
        key: QuizRepositoryImpl.pendingQuizSubmissionsStorageKey,
        data: jsonEncode([queuedItem]),
      );

      // Simulate remote failure
      when(
        () => mockDio.post<dynamic>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/quizzes'),
          error: 'Connection timeout',
        ),
      );

      final initialSync = await repository.flushPendingQuizSubmissions();
      expect(initialSync, 0);

      final rawAfterFail = inMemoryStorage.getPreference(
        key: QuizRepositoryImpl.pendingQuizSubmissionsStorageKey,
      );
      final listAfterFail = jsonDecode(rawAfterFail!) as List<dynamic>;
      final item = listAfterFail.first as Map<String, dynamic>;

      // Retry count incremented to 1
      expect(item['retry_count'], 1);
      expect(item['next_retry_at'], isNotNull);
      final nextRetryAt = DateTime.parse(item['next_retry_at'] as String);
      expect(nextRetryAt.isAfter(DateTime.now()), isTrue);

      // Immediate subsequent flush (force: false default) should skip this item due to backoff
      final skippedSync = await repository.flushPendingQuizSubmissions();
      expect(skippedSync, 0);

      // Now network is restored and user triggers explicit flush (force: true)
      when(
        () => mockDio.post<dynamic>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/quizzes'),
          statusCode: 201,
          data: {'success': true},
        ),
      );

      final forcedSync = await repository.flushPendingQuizSubmissions(force: true);
      expect(forcedSync, 1);
      expect(
        inMemoryStorage.getPreference(
          key: QuizRepositoryImpl.pendingQuizSubmissionsStorageKey,
        ),
        isNull,
      );
    });

    test('6. Max Retries & Dead-Letter Queue: Items exceeding 5 retries are quarantined', () async {
      // Seed item that has already failed 4 times
      final queuedItem = {
        'id': 'attempt-failing-permanently',
        'title': 'Corrupted Submission',
        'subject': 'General',
        'retry_count': 4,
      };
      await inMemoryStorage.savePreference(
        key: QuizRepositoryImpl.pendingQuizSubmissionsStorageKey,
        data: jsonEncode([queuedItem]),
      );

      // Remote POST continues to fail
      when(
        () => mockDio.post<dynamic>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/quizzes'),
          error: 'Unprocessable Entity 422',
        ),
      );

      // 5th attempt fails
      final syncResult = await repository.flushPendingQuizSubmissions(force: true);
      expect(syncResult, 0);

      // Active pending queue should be empty (quarantined)
      final pendingRaw = inMemoryStorage.getPreference(
        key: QuizRepositoryImpl.pendingQuizSubmissionsStorageKey,
      );
      expect(pendingRaw, isNull);

      // Dead-letter queue contains the quarantined item
      final deadLetterRaw = inMemoryStorage.getPreference(
        key: QuizRepositoryImpl.deadLetterQuizSubmissionsStorageKey,
      );
      expect(deadLetterRaw, isNotNull);
      final deadLetterList = jsonDecode(deadLetterRaw!) as List<dynamic>;
      expect(deadLetterList.length, 1);

      final quarantined = deadLetterList.first as Map<String, dynamic>;
      expect(quarantined['id'], 'attempt-failing-permanently');
      expect(quarantined['retry_count'], QuizRepositoryImpl.maxSubmissionRetries);
      expect(quarantined['retry_count'], 5);
      expect(quarantined['failed_at'], isNotNull);
    });

    test('7. Flaky Network Partition: Partial batch failures update retried items and discard successes', () async {
      final items = [
        {'id': 'item-1', 'title': 'Quiz 1', 'retry_count': 0},
        {'id': 'item-2', 'title': 'Quiz 2', 'retry_count': 0},
        {'id': 'item-3', 'title': 'Quiz 3', 'retry_count': 0},
      ];
      await inMemoryStorage.savePreference(
        key: QuizRepositoryImpl.pendingQuizSubmissionsStorageKey,
        data: jsonEncode(items),
      );

      // item-1: succeeds (201)
      // item-2: fails (DioException)
      // item-3: succeeds (200)
      when(
        () => mockDio.post<dynamic>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer((invocation) async {
        final data = invocation.namedArguments[const Symbol('data')] as Map;
        final id = data['id'];

        if (id == 'item-1') {
          return Response(
            requestOptions: RequestOptions(path: '/quizzes'),
            statusCode: 201,
            data: {'success': true},
          );
        } else if (id == 'item-2') {
          throw DioException(
            requestOptions: RequestOptions(path: '/quizzes'),
            error: 'Network drop',
          );
        } else {
          return Response(
            requestOptions: RequestOptions(path: '/quizzes'),
            statusCode: 200,
            data: {'success': true},
          );
        }
      });

      final syncedCount = await repository.flushPendingQuizSubmissions(force: true);
      expect(syncedCount, 2);

      // Verify active queue only has item-2 with retry_count = 1
      final raw = inMemoryStorage.getPreference(
        key: QuizRepositoryImpl.pendingQuizSubmissionsStorageKey,
      );
      expect(raw, isNotNull);
      final remaining = jsonDecode(raw!) as List<dynamic>;
      expect(remaining.length, 1);
      final remainingItem = remaining.first as Map<String, dynamic>;
      expect(remainingItem['id'], 'item-2');
      expect(remainingItem['retry_count'], 1);
    });
  });
}
