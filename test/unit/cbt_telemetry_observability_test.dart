import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/services/analytics_service.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/dashboard/domain/logic/cbt_readiness_calculator.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/cbt_readiness_gauge_card.dart';
import 'package:kortex/src/features/quiz/data/models/quiz_question_model.dart';
import 'package:kortex/src/features/quiz/data/repositories/quiz_repository_impl.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_result_entity.dart';
import 'package:kortex/src/features/quiz/domain/use_cases/generate_quiz_from_deck_use_case.dart';
import 'package:kortex/src/features/quiz/domain/use_cases/submit_quiz_answers_use_case.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_session_cubit.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_session_state.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class MockGenerateQuizFromDeckUseCase extends Mock
    implements GenerateQuizFromDeckUseCase {}

class MockSubmitQuizAnswersUseCase extends Mock
    implements SubmitQuizAnswersUseCase {}

class MockDio extends Mock implements Dio {}

class MockUserStorageService extends Mock implements UserStorageService {}

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

Widget createTestApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: child,
    ),
  );
}

QuizQuestionModel createDummyQuestion(String id, {String? answer}) {
  return QuizQuestionModel(
    id: id,
    prompt: 'Sample question $id?',
    type: QuizQuestionType.multipleChoice,
    options: const ['Alpha', 'Beta', 'Gamma', 'Delta'],
    correctAnswer: 'Alpha',
    explanation: 'Explanation for $id',
    subTopic: 'Physics',
    userSelectedAnswer: answer,
    isAnswered: answer != null,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CBT Health & Telemetry Observability Tests', () {
    late AnalyticsService analytics;
    late InMemoryLocalStorageService localStorage;
    late MockGenerateQuizFromDeckUseCase mockGenerateQuiz;
    late MockSubmitQuizAnswersUseCase mockSubmitQuiz;

    setUp(() {
      analytics = AnalyticsService();
      localStorage = InMemoryLocalStorageService();
      mockGenerateQuiz = MockGenerateQuizFromDeckUseCase();
      mockSubmitQuiz = MockSubmitQuizAnswersUseCase();
    });

    test('1. AnalyticsService captures all 8 CBT event schemas deterministically', () async {
      await analytics.logCbtDiagnosticStarted(
        trackOrExamName: 'JAMB UTME',
      );
      await analytics.logCbtDiagnosticCompleted(
        trackOrExamName: 'JAMB UTME',
        scorePercent: 80,
        totalQuestions: 15,
        correctAnswers: 12,
        durationSeconds: 450,
      );
      await analytics.logCbtMockExamStarted(
        examTrack: 'WAEC WASSCE',
        attemptId: 'mock-att-1',
        totalQuestions: 60,
        durationMinutes: 90,
      );
      await analytics.logCbtMockExamSubmitted(
        examTrack: 'WAEC WASSCE',
        attemptId: 'mock-att-1',
        scorePercent: 75,
        totalQuestions: 60,
        correctAnswers: 45,
        elapsedSeconds: 4800,
        isAutoSubmit: false,
      );
      await analytics.logCbtExamResumedAfterInterrupt(
        examTrack: 'WAEC WASSCE',
        attemptId: 'mock-att-1',
        remainingSeconds: 600,
        answeredQuestionsCount: 40,
        totalQuestions: 60,
      );
      await analytics.logCbtOfflineQueueFlushSuccess(
        flushedCount: 5,
        remainingCount: 0,
        durationMs: 250,
      );
      await analytics.logCbtOfflineQueueFlushFailed(
        failedCount: 2,
        errorReason: 'network_timeout',
        retryCount: 3,
      );
      await analytics.logReadinessScoreViewed(
        readinessScore: 78,
        statusTier: 'onTrack',
        confidenceIntervalLabel: 'Readiness: 78% ± 4%',
        standardErrorMargin: 4,
        examTrack: 'JAMB UTME',
      );

      expect(analytics.loggedEventsForTesting.length, 8);
      final names = analytics.loggedEventsForTesting.map((e) => e['name'] as String).toList();
      expect(
        names,
        equals([
          'cbt_diagnostic_started',
          'cbt_diagnostic_completed',
          'cbt_mock_exam_started',
          'cbt_mock_exam_submitted',
          'cbt_exam_resumed_after_interrupt',
          'cbt_offline_queue_flush_success',
          'cbt_offline_queue_flush_failed',
          'readiness_score_viewed',
        ]),
      );
    });

    test('2. QuizSessionCubit emits cbt_diagnostic_started & completed for diagnostic sessions', () async {
      final cubit = QuizSessionCubit(
        generateQuizUseCase: mockGenerateQuiz,
        submitQuizUseCase: mockSubmitQuiz,
        analyticsService: analytics,
        localStorageService: localStorage,
      );

      final questions = [
        createDummyQuestion('diag_1', answer: 'Alpha'),
        createDummyQuestion('diag_2', answer: 'Beta'),
      ];

      when(
        () => mockSubmitQuiz(
          quizTitle: any(named: 'quizTitle'),
          questions: any(named: 'questions'),
          durationSeconds: any(named: 'durationSeconds'),
          attemptId: any(named: 'attemptId'),
        ),
      ).thenAnswer(
        (_) async => const Right(
          QuizResultEntity(
            id: 'res-diag-1',
            quizTitle: 'Day-One Diagnostic Assessment',
            totalQuestions: 2,
            correctAnswers: 1,
            durationSeconds: 120,
            weaknesses: [],
          ),
        ),
      );

      // Start diagnostic
      cubit.startQuizFromPastQuestions(
        title: 'JAMB Day-One Diagnostic',
        questions: questions,
        assessmentMode: AssessmentMode.examSimulationMode,
      );

      expect(
        analytics.loggedEventsForTesting.any((e) => e['name'] == 'cbt_diagnostic_started'),
        isTrue,
      );
      final startEvent = analytics.loggedEventsForTesting.firstWhere(
        (e) => e['name'] == 'cbt_diagnostic_started',
      );
      final startParams = startEvent['parameters'] as Map<String, Object>;
      expect(startParams['track_name'], 'JAMB Day-One Diagnostic');
      expect(startParams['question_count'], 2);

      // Submit diagnostic
      await cubit.submitQuiz();

      expect(
        analytics.loggedEventsForTesting.any((e) => e['name'] == 'cbt_diagnostic_completed'),
        isTrue,
      );
      final completedEvent = analytics.loggedEventsForTesting.firstWhere(
        (e) => e['name'] == 'cbt_diagnostic_completed',
      );
      final compParams = completedEvent['parameters'] as Map<String, Object>;
      expect(compParams['track_name'], 'Day-One Diagnostic Assessment');
      expect(compParams['score_percent'], 50);
      expect(compParams['total_questions'], 2);
      expect(compParams['correct_answers'], 1);

      await cubit.close();
    });

    test('3. QuizSessionCubit emits cbt_mock_exam_started & submitted for exam simulations', () async {
      final cubit = QuizSessionCubit(
        generateQuizUseCase: mockGenerateQuiz,
        submitQuizUseCase: mockSubmitQuiz,
        analyticsService: analytics,
        localStorageService: localStorage,
      );

      final questions = [
        createDummyQuestion('mock_1', answer: 'Alpha'),
        createDummyQuestion('mock_2', answer: 'Beta'),
      ];

      when(
        () => mockSubmitQuiz(
          quizTitle: any(named: 'quizTitle'),
          questions: any(named: 'questions'),
          durationSeconds: any(named: 'durationSeconds'),
          attemptId: any(named: 'attemptId'),
        ),
      ).thenAnswer(
        (_) async => const Right(
          QuizResultEntity(
            id: 'res-mock-1',
            quizTitle: 'WAEC Mock Physics 2026',
            totalQuestions: 2,
            correctAnswers: 2,
            durationSeconds: 300,
            weaknesses: [],
          ),
        ),
      );

      // Start simulation
      cubit.startQuizFromPastQuestions(
        title: 'WAEC Mock Physics 2026',
        questions: questions,
        durationMinutes: 45,
        assessmentMode: AssessmentMode.examSimulationMode,
      );

      expect(
        analytics.loggedEventsForTesting.any((e) => e['name'] == 'cbt_mock_exam_started'),
        isTrue,
      );
      final startEvent = analytics.loggedEventsForTesting.firstWhere(
        (e) => e['name'] == 'cbt_mock_exam_started',
      );
      final startParams = startEvent['parameters'] as Map<String, Object>;
      expect(startParams['exam_track'], 'WAEC Mock Physics 2026');
      expect(startParams['duration_minutes'], 45);
      expect(startParams['is_timed'], 1);

      // Submit simulation
      await cubit.submitQuiz();

      expect(
        analytics.loggedEventsForTesting.any((e) => e['name'] == 'cbt_mock_exam_submitted'),
        isTrue,
      );
      final submitEvent = analytics.loggedEventsForTesting.firstWhere(
        (e) => e['name'] == 'cbt_mock_exam_submitted',
      );
      final submitParams = submitEvent['parameters'] as Map<String, Object>;
      expect(submitParams['exam_track'], 'WAEC Mock Physics 2026');
      expect(submitParams['score_percent'], 100);
      expect(submitParams['total_questions'], 2);
      expect(submitParams['correct_answers'], 2);
      expect(submitParams['is_auto_submit'], 0);

      await cubit.close();
    });

    test('4. QuizSessionCubit emits cbt_exam_resumed_after_interrupt on session restoration', () async {
      final now = DateTime(2026, 10, 16, 12);
      final deadline = now.add(const Duration(minutes: 60));

      final savedSession = {
        'attemptId': 'interrupted-uuid-777',
        'quizTitle': 'JAMB UTME Simulation',
        'currentIndex': 5,
        'startedAt': now.subtract(const Duration(minutes: 10)).toIso8601String(),
        'deadline': deadline.toIso8601String(),
        'durationMinutes': 60,
        'flaggedQuestionIds': ['q2'],
        'assessmentMode': 'examSimulationMode',
        'questions': [
          createDummyQuestion('q1', answer: 'Alpha').toJson(),
          createDummyQuestion('q2').toJson(),
          createDummyQuestion('q3').toJson(),
        ],
      };

      await localStorage.savePreference(
        key: QuizSessionCubit.activeCbtSessionStorageKey,
        data: jsonEncode(savedSession),
      );

      final cubit = QuizSessionCubit(
        generateQuizUseCase: mockGenerateQuiz,
        submitQuizUseCase: mockSubmitQuiz,
        analyticsService: analytics,
        localStorageService: localStorage,
        nowProvider: () => now,
      );

      final restored = await cubit.restoreActiveSession();
      expect(restored, isTrue);

      expect(
        analytics.loggedEventsForTesting.any((e) => e['name'] == 'cbt_exam_resumed_after_interrupt'),
        isTrue,
      );
      final resumeEvent = analytics.loggedEventsForTesting.firstWhere(
        (e) => e['name'] == 'cbt_exam_resumed_after_interrupt',
      );
      final resumeParams = resumeEvent['parameters'] as Map<String, Object>;
      expect(resumeParams['exam_track'], 'JAMB UTME Simulation');
      expect(resumeParams['attempt_id'], 'interrupted-uuid-777');
      expect(resumeParams['remaining_seconds'], 3600);
      expect(resumeParams['answered_count'], 1);
      expect(resumeParams['total_questions'], 3);

      await cubit.close();
    });

    test('5. QuizRepositoryImpl emits cbt_offline_queue_flush_success on successful sync', () async {
      final mockDio = MockDio();
      final mockUserStorage = MockUserStorageService();

      when(mockUserStorage.getToken).thenReturn('valid-jwt-token');
      when(mockUserStorage.getUserId).thenReturn('user-uid-999');

      final queuedSubmission = {
        'id': 'sub-offline-1',
        'payload': {
          'id': 'sub-offline-1',
          'title': 'JAMB Mock Physics',
          'total_questions': 20,
          'correct_answers': 18,
          'score_percent': 90,
          'duration_seconds': 600,
        },
        'retry_count': 0,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };

      await localStorage.savePreference(
        key: QuizRepositoryImpl.pendingQuizSubmissionsStorageKey,
        data: jsonEncode([queuedSubmission]),
      );

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
        ),
      );

      final repo = QuizRepositoryImpl(
        dio: mockDio,
        localStorageService: localStorage,
        userStorageService: mockUserStorage,
        analyticsService: analytics,
      );

      final flushed = await repo.flushPendingQuizSubmissions(force: true);
      expect(flushed, 1);

      expect(
        analytics.loggedEventsForTesting.any((e) => e['name'] == 'cbt_offline_queue_flush_success'),
        isTrue,
      );
      final flushEvent = analytics.loggedEventsForTesting.firstWhere(
        (e) => e['name'] == 'cbt_offline_queue_flush_success',
      );
      final flushParams = flushEvent['parameters'] as Map<String, Object>;
      expect(flushParams['flushed_count'], 1);
      expect(flushParams['remaining_count'], 0);
      expect((flushParams['duration_ms'] as num?)?.toInt(), isNonNegative);

      await repo.dispose();
    });

    test('6. QuizRepositoryImpl emits cbt_offline_queue_flush_failed when retry backoff occurs', () async {
      final mockDio = MockDio();
      final mockUserStorage = MockUserStorageService();

      when(mockUserStorage.getToken).thenReturn('valid-jwt-token');
      when(mockUserStorage.getUserId).thenReturn('user-uid-999');

      final queuedSubmission = {
        'id': 'sub-offline-failed-1',
        'payload': {
          'id': 'sub-offline-failed-1',
          'title': 'WAEC Biology',
          'total_questions': 20,
          'correct_answers': 14,
          'score_percent': 70,
          'duration_seconds': 500,
        },
        'retry_count': 1,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };

      await localStorage.savePreference(
        key: QuizRepositoryImpl.pendingQuizSubmissionsStorageKey,
        data: jsonEncode([queuedSubmission]),
      );

      when(
        () => mockDio.post<dynamic>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/quizzes'),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      final repo = QuizRepositoryImpl(
        dio: mockDio,
        localStorageService: localStorage,
        userStorageService: mockUserStorage,
        analyticsService: analytics,
      );

      final flushed = await repo.flushPendingQuizSubmissions(force: true);
      expect(flushed, 0);

      expect(
        analytics.loggedEventsForTesting.any((e) => e['name'] == 'cbt_offline_queue_flush_failed'),
        isTrue,
      );
      final failedEvent = analytics.loggedEventsForTesting.firstWhere(
        (e) => e['name'] == 'cbt_offline_queue_flush_failed',
      );
      final failedParams = failedEvent['parameters'] as Map<String, Object>;
      expect(failedParams['failed_count'], 1);
      expect(failedParams['retry_count'], 2);

      await repo.dispose();
    });

    testWidgets('7. DayOneDiagnosticBanner emits cbt_diagnostic_started when start CTA tapped', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          DayOneDiagnosticBanner(
            targetTrack: 'JAMB',
            registeredSubjectNames: const ['English', 'Mathematics'],
            analyticsService: analytics,
            onStartDiagnostic: () async {
              await analytics.logCbtDiagnosticStarted(
                trackOrExamName: 'JAMB',
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final ctaFinder = find.text('Start 10-Minute Diagnostic');
      expect(ctaFinder, findsOneWidget);

      await tester.tap(ctaFinder);
      await tester.pumpAndSettle();

      expect(
        analytics.loggedEventsForTesting.any((e) => e['name'] == 'cbt_diagnostic_started'),
        isTrue,
      );
      final event = analytics.loggedEventsForTesting.firstWhere(
        (e) => e['name'] == 'cbt_diagnostic_started',
      );
      final params = event['parameters'] as Map<String, Object>;
      expect(params['track_name'], 'JAMB');
      expect(params['question_count'], 15);
    });

    testWidgets('8. CbtReadinessBreakdownSheet emits readiness_score_viewed on mount', (tester) async {
      const dummyResult = CbtReadinessResult(
        scorePercent: 74,
        statusLabel: 'On Track',
        statusTier: CbtReadinessStatusTier.onTrack,
        statusColorValue: 0xFF10B981,
        syllabusCoverage: 0.80,
        fsrsRetentionRate: 0.85,
        mockScoreRatio: 0.74,
        projectedGrade: 'B2',
        projectedScoreRange: '260–280',
        confidenceIntervalLabel: 'Readiness: 74% ± 5%',
        confidenceMargin: 5,
        totalQuestionsAnswered: 120,
        isSampleSufficient: true,
      );

      await tester.pumpWidget(
        createTestApp(
          SizedBox(
            height: 900,
            width: 450,
            child: CbtReadinessBreakdownSheet(
              readinessResult: dummyResult,
              examTitle: 'JAMB UTME 2026',
              daysRemaining: 28,
              scrollController: ScrollController(),
              analyticsService: analytics,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        analytics.loggedEventsForTesting.any((e) => e['name'] == 'readiness_score_viewed'),
        isTrue,
      );
      final viewEvent = analytics.loggedEventsForTesting.firstWhere(
        (e) => e['name'] == 'readiness_score_viewed',
      );
      final params = viewEvent['parameters'] as Map<String, Object>;
      expect(params['readiness_score'], 74.0);
      expect(params['status_tier'], 'onTrack');
      expect(params['confidence_label'], 'Readiness: 74% ± 5%');
      expect(params['standard_error_margin'], 5.0);
      expect(params['exam_track'], 'JAMB UTME 2026');
    });

    testWidgets('9. CbtReadinessGaugeCard emits readiness_score_viewed on mount', (tester) async {
      const dummyResult = CbtReadinessResult(
        scorePercent: 88,
        statusLabel: 'Mastery Tier',
        statusTier: CbtReadinessStatusTier.onTrack,
        statusColorValue: 0xFF059669,
        syllabusCoverage: 0.95,
        fsrsRetentionRate: 0.90,
        mockScoreRatio: 0.88,
        projectedGrade: 'A1',
        projectedScoreRange: '320–350',
        confidenceIntervalLabel: 'Readiness: 88% ± 3%',
        confidenceMargin: 3,
        totalQuestionsAnswered: 240,
        isSampleSufficient: true,
      );

      await tester.pumpWidget(
        createTestApp(
          CbtReadinessGaugeCard(
            readinessResult: dummyResult,
            examTitle: 'WAEC WASSCE 2026',
            daysRemaining: 14,
            analyticsService: analytics,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        analytics.loggedEventsForTesting.any((e) => e['name'] == 'readiness_score_viewed'),
        isTrue,
      );
      final viewEvent = analytics.loggedEventsForTesting.firstWhere(
        (e) => e['name'] == 'readiness_score_viewed',
      );
      final params = viewEvent['parameters'] as Map<String, Object>;
      expect(params['readiness_score'], 88.0);
      expect(params['status_tier'], 'onTrack');
      expect(params['confidence_label'], 'Readiness: 88% ± 3%');
      expect(params['standard_error_margin'], 3.0);
      expect(params['exam_track'], 'WAEC WASSCE 2026');
    });
  });
}
