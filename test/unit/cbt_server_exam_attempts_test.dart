import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/services/user_activity_service.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/core/utils/uuid_utils.dart';
import 'package:kortex/src/features/quiz/data/repositories/quiz_repository_impl.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_result_entity.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

class MockUserStorageService extends Mock implements UserStorageService {}

class MockUserActivityService extends Mock implements UserActivityService {}

class InMemoryLocalStorageService implements LocalStorageService {
  final Map<String, String> _data = {};

  @override
  Future<void> initDB() async {}

  @override
  String? getPreference({required String key}) => _data[key];

  @override
  Future<void> savePreference({
    required String key,
    required String data,
  }) async {
    _data[key] = data;
  }

  @override
  Future<void> deletePreference({required String key}) async {
    _data.remove(key);
  }

  @override
  Future<void> clearAllPreferences() async {
    _data.clear();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P2-03 · Server-Side Graded Exam Attempts & RPC Security Hardening', () {
    late MockDio mockDio;
    late MockUserStorageService mockUserStorage;
    late MockUserActivityService mockUserActivity;
    late InMemoryLocalStorageService inMemoryStorage;
    late QuizRepositoryImpl repository;

    setUp(() {
      mockDio = MockDio();
      mockUserStorage = MockUserStorageService();
      mockUserActivity = MockUserActivityService();
      inMemoryStorage = InMemoryLocalStorageService();

      when(mockUserStorage.getToken).thenReturn('valid_jwt_token');
      when(mockUserStorage.getUserId).thenReturn('user_uuid_123');

      repository = QuizRepositoryImpl(
        dio: mockDio,
        localStorageService: inMemoryStorage,
        userStorageService: mockUserStorage,
        userActivityService: mockUserActivity,
      );
    });

    group('submitCbtMockAttempt RPC invocation', () {
      test('submits valid attempt parameters to /rest/v1/rpc/submit_cbt_mock_attempt', () async {
        final sessionId = UuidUtils.generate();
        Map<String, dynamic>? capturedData;
        Options? capturedOptions;

        when(
          () => mockDio.post<dynamic>(
            any(that: contains('/rest/v1/rpc/submit_cbt_mock_attempt')),
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenAnswer((invocation) async {
          capturedData = invocation.namedArguments[#data] as Map<String, dynamic>?;
          capturedOptions = invocation.namedArguments[#options] as Options?;
          return Response<dynamic>(
            requestOptions: RequestOptions(path: '/rest/v1/rpc/submit_cbt_mock_attempt'),
            statusCode: 200,
            data: {
              'success': true,
              'quiz_id': sessionId,
              'score_percent': 80,
              'status': 'completed',
            },
          );
        });

        final result = await repository.submitCbtMockAttempt(
          sessionId: sessionId,
          quizTitle: 'JAMB Physics Mock 2026',
          subject: 'Physics',
          totalQuestions: 20,
          correctAnswers: 16,
          durationSeconds: 1800,
          weakSubtopics: ['Electromagnetism', 'Optics'],
          courseId: 'course_phy_101',
          courseCode: 'PHY101',
        );

        expect(result.isRight, isTrue);
        final data = (result as Right).value as Map<String, dynamic>;
        expect(data['success'], isTrue);
        expect(data['score_percent'], equals(80));

        expect(capturedData, isNotNull);
        expect(capturedData!['p_session_id'], equals(sessionId));
        expect(capturedData!['p_quiz_title'], equals('JAMB Physics Mock 2026'));
        expect(capturedData!['p_subject'], equals('Physics'));
        expect(capturedData!['p_total_questions'], equals(20));
        expect(capturedData!['p_correct_answers'], equals(16));
        expect(capturedData!['p_duration_seconds'], equals(1800));
        expect(capturedData!['p_weak_subtopics'], equals(['Electromagnetism', 'Optics']));
        expect(capturedData!['p_course_id'], equals('course_phy_101'));
        expect(capturedData!['p_course_code'], equals('PHY101'));

        expect(capturedOptions, isNotNull);
        expect(capturedOptions!.headers!['Authorization'], contains('Bearer valid_jwt_token'));
      });

      test('clamps out-of-range counts and negative durations safely before RPC post', () async {
        final sessionId = UuidUtils.generate();
        Map<String, dynamic>? capturedData;

        when(
          () => mockDio.post<dynamic>(
            any(that: contains('/rest/v1/rpc/submit_cbt_mock_attempt')),
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenAnswer((invocation) async {
          capturedData = invocation.namedArguments[#data] as Map<String, dynamic>?;
          return Response<dynamic>(
            requestOptions: RequestOptions(path: '/rest/v1/rpc/submit_cbt_mock_attempt'),
            statusCode: 200,
            data: {'success': true},
          );
        });

        // Test negative and overflow values (e.g. correct > total, negative duration)
        final result = await repository.submitCbtMockAttempt(
          sessionId: sessionId,
          quizTitle: 'Safety Test',
          subject: 'General',
          totalQuestions: 10,
          correctAnswers: 50, // Exceeds total
          durationSeconds: -60, // Negative duration
        );

        expect(result.isRight, isTrue);
        expect(capturedData, isNotNull);
        expect(capturedData!['p_total_questions'], equals(10));
        // correctAnswers clamped to totalQuestions (10)
        expect(capturedData!['p_correct_answers'], equals(10));
        // durationSeconds clamped to 0
        expect(capturedData!['p_duration_seconds'], equals(0));
      });

      test('returns ServerFailure when RPC endpoint returns error response', () async {
        when(
          () => mockDio.post<dynamic>(
            any(that: contains('/rest/v1/rpc/submit_cbt_mock_attempt')),
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/rest/v1/rpc/submit_cbt_mock_attempt'),
            response: Response(
              requestOptions: RequestOptions(path: '/rest/v1/rpc/submit_cbt_mock_attempt'),
              statusCode: 400,
              data: {'message': 'P0003: Exam Expired: Submission rejected'},
            ),
            type: DioExceptionType.badResponse,
          ),
        );

        final result = await repository.submitCbtMockAttempt(
          sessionId: UuidUtils.generate(),
          quizTitle: 'Expired Exam',
          subject: 'Chemistry',
          totalQuestions: 10,
          correctAnswers: 5,
          durationSeconds: 3600,
        );

        expect(result.isLeft, isTrue);
        final failure = (result as Left).value as Failure;
        expect(failure, isA<ServerFailure>());
      });
    });

    group('submitQuizAnswers client bounds check', () {
      test('guarantees score_percent, correct_answers, and duration_seconds satisfy SQL check constraints', () async {
        Map<String, dynamic>? capturedPayload;

        when(() => mockUserActivity.recordStudySession(
              cardsReviewed: any(named: 'cardsReviewed'),
              durationSeconds: any(named: 'durationSeconds'),
              retentionScore: any(named: 'retentionScore'),
              masteredCards: any(named: 'masteredCards'),
              activityCategory: any(named: 'activityCategory'),
              subject: any(named: 'subject'),
            )).thenAnswer((_) async {});

        when(
          () => mockDio.post<dynamic>(
            any(that: contains('/rest/v1/quizzes')),
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenAnswer((invocation) async {
          capturedPayload = invocation.namedArguments[#data] as Map<String, dynamic>?;
          return Response<dynamic>(
            requestOptions: RequestOptions(path: '/rest/v1/quizzes'),
            statusCode: 201,
          );
        });

        const questions = [
          QuizQuestionEntity(
            id: 'q1',
            prompt: 'Question 1',
            type: QuizQuestionType.multipleChoice,
            options: ['A', 'B'],
            correctAnswer: 'A',
            explanation: '',
            subTopic: 'Math',
            userSelectedAnswer: 'A',
            isAnswered: true,
            isCorrect: true,
          ),
        ];

        final result = await repository.submitQuizAnswers(
          quizTitle: 'Algebra Mock',
          questions: questions,
          durationSeconds: -30, // negative duration passed
        );

        expect(result.isRight, isTrue);
        final quizResult = (result as Right).value as QuizResultEntity;

        // Result bounds
        expect(quizResult.durationSeconds, equals(-30)); // original passed duration preserved in entity
        expect(capturedPayload, isNotNull);

        // SQL payload check constraints guaranteed
        final scorePercent = capturedPayload!['score_percent'] as int;
        final correctAnswers = capturedPayload!['correct_answers'] as int;
        final totalQuestions = capturedPayload!['total_questions'] as int;
        final durationSeconds = capturedPayload!['duration_seconds'] as int;

        expect(scorePercent >= 0 && scorePercent <= 100, isTrue);
        expect(correctAnswers >= 0 && correctAnswers <= totalQuestions, isTrue);
        expect(totalQuestions >= 0, isTrue);
        expect(durationSeconds >= 0, isTrue); // Clamped to 0
      });
    });

    group('SQL Migration Integrity Check', () {
      test('migration file 20261016000000_harden_cbt_exam_attempts.sql enforces security specs', () {
        final migrationFile = File('supabase/migrations/20261016000000_harden_cbt_exam_attempts.sql');
        expect(migrationFile.existsSync(), isTrue);

        final sql = migrationFile.readAsStringSync();

        // 1. Table creation with status check
        expect(sql.contains('CREATE TABLE IF NOT EXISTS public.cbt_exam_sessions'), isTrue);
        expect(sql.contains("CHECK (status IN ('in_progress', 'completed', 'expired', 'abandoned'))"), isTrue);
        expect(sql.contains('expires_at TIMESTAMPTZ NOT NULL'), isTrue);

        // 2. CHECK constraints on public.quizzes
        expect(sql.contains('chk_quizzes_score_percent'), isTrue);
        expect(sql.contains('CHECK (score_percent >= 0 AND score_percent <= 100)'), isTrue);
        expect(sql.contains('chk_quizzes_correct_answers'), isTrue);
        expect(sql.contains('CHECK (correct_answers >= 0 AND correct_answers <= total_questions)'), isTrue);
        expect(sql.contains('chk_quizzes_total_questions'), isTrue);
        expect(sql.contains('CHECK (total_questions >= 0)'), isTrue);
        expect(sql.contains('chk_quizzes_duration_seconds'), isTrue);
        expect(sql.contains('CHECK (duration_seconds >= 0)'), isTrue);

        // 3. start_mock_exam security hardening
        expect(sql.contains('CREATE OR REPLACE FUNCTION public.start_mock_exam'), isTrue);
        expect(sql.contains('SET search_path = public, pg_temp'), isTrue);
        expect(sql.contains('REVOKE ALL ON FUNCTION public.start_mock_exam'), isTrue);
        expect(sql.contains('FROM PUBLIC, anon'), isTrue);
        expect(sql.contains('Caller must be authenticated to start a mock exam'), isTrue);

        // 4. submit_cbt_mock_attempt RPC
        expect(sql.contains('CREATE OR REPLACE FUNCTION public.submit_cbt_mock_attempt'), isTrue);
        expect(sql.contains('expires_at + v_grace_period'), isTrue);
        expect(sql.contains('REVOKE ALL ON FUNCTION public.submit_cbt_mock_attempt'), isTrue);
        expect(sql.contains('GRANT EXECUTE ON FUNCTION public.submit_cbt_mock_attempt'), isTrue);
        expect(sql.contains('TO authenticated, service_role'), isTrue);
      });
    });
  });
}
