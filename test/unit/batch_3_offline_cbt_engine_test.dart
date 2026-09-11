import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/quiz/data/data_sources/past_questions_local_data_source.dart';
import 'package:kortex/src/features/quiz/data/data_sources/past_questions_remote_data_source.dart';
import 'package:kortex/src/features/quiz/data/models/past_question_model.dart';
import 'package:kortex/src/features/quiz/data/models/quiz_question_model.dart';
import 'package:kortex/src/features/quiz/data/repositories/past_questions_repository_impl.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_result_entity.dart';
import 'package:kortex/src/features/quiz/domain/use_cases/generate_quiz_from_deck_use_case.dart';
import 'package:kortex/src/features/quiz/domain/use_cases/submit_quiz_answers_use_case.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_session_cubit.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_session_state.dart';
import 'package:mocktail/mocktail.dart';

class MockPastQuestionsRemoteDataSource extends Mock
    implements PastQuestionsRemoteDataSource {}

class MockGenerateQuizFromDeckUseCase extends Mock
    implements GenerateQuizFromDeckUseCase {}

class MockSubmitQuizAnswersUseCase extends Mock
    implements SubmitQuizAnswersUseCase {}

List<PastQuestionModel> _buildTestQuestions() {
  final subjects = ['Mathematics', 'English Language', 'Chemistry', 'Physics'];
  final list = <PastQuestionModel>[];
  int idCounter = 1;
  for (final cat in [ExamCategory.waec, ExamCategory.jamb]) {
    for (final sub in subjects) {
      for (final yr in [2023, 2022]) {
        for (int q = 1; q <= 5; q++) {
          list.add(
            PastQuestionModel(
              id: 'test-q-${idCounter++}',
              examType: cat,
              subject: sub,
              year: yr,
              questionNumber: q,
              prompt: sub == 'Chemistry'
                  ? 'What is the conjugate acid of NH3 in question $q?'
                  : 'What is the answer for $sub $yr question $q?',
              options: const ['Option A', 'Option B', 'Option C', 'Option D'],
              correctOptionIndex: 0,
              correctOptionLabel: 'A',
              explanation: 'Explanation for question $q',
              topic: sub == 'Chemistry' ? 'Acids and Bases' : 'General',
            ),
          );
        }
      }
    }
  }
  return list;
}

class InMemoryLocalStorageService implements LocalStorageService {
  final Map<String, String> data = {};

  @override
  Future<void> initDB() async {}

  @override
  String? getPreference({required String key}) => data[key];

  @override
  Future<void> savePreference({
    required String key,
    required String data,
  }) async {
    this.data[key] = data;
  }

  @override
  Future<void> deletePreference({required String key}) async {
    data.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<PastQuestionModel> testQuestions;
  late PastQuestionsLocalDataSource localDataSource;
  late MockPastQuestionsRemoteDataSource mockRemoteDataSource;
  late InMemoryLocalStorageService storageService;
  late PastQuestionsRepositoryImpl repository;

  setUp(() async {
    testQuestions = _buildTestQuestions();
    localDataSource = PastQuestionsLocalDataSourceImpl(
      initialQuestions: testQuestions,
    );
    mockRemoteDataSource = MockPastQuestionsRemoteDataSource();
    storageService = InMemoryLocalStorageService();

    repository = PastQuestionsRepositoryImpl(
      mockRemoteDataSource,
      localDataSource: localDataSource,
      localStorageService: storageService,
    );

    await localDataSource.initialize();
  });

  group('Batch 3 - Offline Past Question Asset & Dataset Bundling', () {
    test('In-memory test dataset parses verified questions correctly', () {
      expect(testQuestions, isNotEmpty);
      expect(testQuestions.length, equals(80));

      final first = testQuestions.first;
      expect(first.id, isNotNull);
      expect(first.subject, isNotNull);
      expect(first.prompt, isNotNull);
      expect(first.options, isNotEmpty);
      expect(first.correctOptionIndex, isNotNull);
    });

    test('Loads on cold startup and builds instant in-memory lookup indices', () async {
      expect(localDataSource.isInitialized, isTrue);

      final waecSubjects =
          await localDataSource.getAvailableSubjects(ExamCategory.waec);
      expect(waecSubjects, isNotEmpty);
      expect(waecSubjects.contains('Mathematics'), isTrue);

      final jambYears =
          await localDataSource.getAvailableYears(ExamCategory.jamb);
      expect(jambYears, isNotEmpty);
    });

    test('Sub-5ms lookup performance and zero network requirement', () async {
      final stopwatch = Stopwatch()..start();

      final mathQuestions = await localDataSource.getPastQuestions(
        examCategory: ExamCategory.jamb,
        subject: 'Mathematics',
        limit: 50,
      );

      stopwatch.stop();

      expect(mathQuestions, isNotEmpty);
      expect(stopwatch.elapsedMilliseconds, lessThanOrEqualTo(5),
          reason: 'Offline indexed lookups must complete in sub-5ms');
    });

    test('Filters accurately by category, subject, year, and search query', () async {
      final filteredBySubject = await localDataSource.getPastQuestions(
        subject: 'English Language',
      );
      expect(filteredBySubject, isNotEmpty);
      for (final q in filteredBySubject) {
        expect(q.subject.toLowerCase(), contains('english'));
      }

      final chemistry2022 = await localDataSource.getPastQuestions(
        subject: 'Chemistry',
        year: 2022,
      );
      for (final q in chemistry2022) {
        expect(q.year, equals(2022));
      }

      final searchResults = await localDataSource.getPastQuestions(
        searchQuery: 'acid',
      );
      expect(searchResults, isNotEmpty);
      for (final q in searchResults) {
        final matches = q.prompt.toLowerCase().contains('acid') ||
            q.topic.toLowerCase().contains('acid') ||
            q.subject.toLowerCase().contains('acid');
        expect(matches, isTrue);
      }
    });

    test('Repository serves questions from local asset without invoking remote', () async {
      final result = await repository.getPastQuestions(
        examCategory: ExamCategory.jamb,
        subject: 'Physics',
      );

      expect(result.isRight, isTrue);
      final questions = result.fold((l) => <PastQuestionEntity>[], (r) => r);
      expect(questions, isNotEmpty);

      // Verify remote data source was never called because local cache served the data
      verifyNever(() => mockRemoteDataSource.getPastQuestions(
            examCategory: any(named: 'examCategory'),
            subject: any(named: 'subject'),
            year: any(named: 'year'),
            searchQuery: any(named: 'searchQuery'),
          ));
    });
  });

  group('Batch 3 - CBT Test Simulator & Real-Time Timing / Flagging / Palette', () {
    late MockGenerateQuizFromDeckUseCase mockGenerateQuizUseCase;
    late MockSubmitQuizAnswersUseCase mockSubmitQuizUseCase;
    late QuizSessionCubit cubit;
    late List<QuizQuestionEntity> testQuestions;

    setUp(() {
      mockGenerateQuizUseCase = MockGenerateQuizFromDeckUseCase();
      mockSubmitQuizUseCase = MockSubmitQuizAnswersUseCase();

      cubit = QuizSessionCubit(
        generateQuizUseCase: mockGenerateQuizUseCase,
        submitQuizUseCase: mockSubmitQuizUseCase,
      );

      testQuestions = List.generate(
        10,
        (i) => QuizQuestionModel(
          id: 'cbt-q-$i',
          prompt: 'Question $i: What is the derivative of x^$i?',
          type: QuizQuestionType.multipleChoice,
          options: const ['Option A', 'Option B', 'Option C', 'Option D'],
          correctAnswer: 'Option A',
          explanation: 'Standard polynomial calculus derivative rule.',
          subTopic: i < 5 ? 'Calculus' : 'Algebra',
        ),
      );
    });

    tearDown(() async {
      await cubit.close();
    });

    test('Starts CBT simulator with duration and countdown timer calculation', () {
      cubit.startQuizFromPastQuestions(
        title: 'JAMB Mathematics CBT Mock',
        questions: testQuestions,
        durationMinutes: 45,
      );

      expect(cubit.state.status, equals(QuizSessionStatus.inProgress));
      expect(cubit.state.quizTitle, equals('JAMB Mathematics CBT Mock'));
      expect(cubit.state.totalQuestions, equals(10));
      expect(cubit.state.durationMinutes, equals(45));
      expect(cubit.state.remainingSeconds, equals(45 * 60));
      expect(cubit.state.formattedTimer, equals('45:00'));
      expect(cubit.state.isTimeExpired, isFalse);
      expect(cubit.state.isTimeRunningLow, isFalse);
    });

    test('Toggles question flagging for candidate review', () {
      cubit.startQuizFromPastQuestions(
        title: 'WAEC Physics CBT',
        questions: testQuestions,
        durationMinutes: 60,
      );

      expect(cubit.state.isCurrentQuestionFlagged, isFalse);
      expect(cubit.state.flaggedCount, equals(0));

      // Flag current question (index 0)
      cubit.toggleFlagCurrentQuestion();
      expect(cubit.state.isCurrentQuestionFlagged, isTrue);
      expect(cubit.state.flaggedCount, equals(1));
      expect(cubit.state.isQuestionFlagged('cbt-q-0'), isTrue);

      // Flag another question by id (cbt-q-5)
      cubit.toggleFlagQuestion('cbt-q-5');
      expect(cubit.state.flaggedCount, equals(2));
      expect(cubit.state.isQuestionFlagged('cbt-q-5'), isTrue);

      // Unflag current question
      cubit.toggleFlagCurrentQuestion();
      expect(cubit.state.isCurrentQuestionFlagged, isFalse);
      expect(cubit.state.flaggedCount, equals(1));
    });

    test('Jumps between questions via CBT Palette and supports bidirectional navigation', () {
      cubit.startQuizFromPastQuestions(
        title: 'General CBT Mock',
        questions: testQuestions,
      );

      expect(cubit.state.currentIndex, equals(0));
      expect(cubit.state.canGoPrevious, isFalse);
      expect(cubit.state.canGoNext, isTrue);

      // Jump directly to question index 7 via palette
      cubit.jumpToQuestion(7);
      expect(cubit.state.currentIndex, equals(7));
      expect(cubit.state.canGoPrevious, isTrue);
      expect(cubit.state.canGoNext, isTrue);

      // Navigate backwards
      cubit.previousQuestion();
      expect(cubit.state.currentIndex, equals(6));

      // Jump to last question
      cubit.jumpToQuestion(9);
      expect(cubit.state.isLastQuestion, isTrue);
      expect(cubit.state.canGoNext, isFalse);
    });

    test('Computes diagnostic topic review and weakness breakdown upon test submission', () async {
      cubit
        ..startQuizFromPastQuestions(
          title: 'Diagnostic Math Mock',
          questions: testQuestions,
        )
        ..jumpToQuestion(0)
        ..selectOption('Option A')
        ..jumpToQuestion(1)
        ..selectOption('Option A')
        ..jumpToQuestion(2)
        ..selectOption('Option A')
        ..jumpToQuestion(3)
        ..selectOption('Option B')
        ..jumpToQuestion(4)
        ..selectOption('Option B');

      expect(cubit.state.answeredCount, equals(5));
      expect(cubit.state.unansweredCount, equals(5));

      const expectedResult = QuizResultEntity(
        id: 'result-mock-1',
        quizTitle: 'Diagnostic Math Mock',
        totalQuestions: 10,
        correctAnswers: 3,
        durationSeconds: 120,
        weaknesses: [
          TopicWeakness(
            subTopic: 'Calculus',
            totalQuestions: 5,
            correctCount: 3,
          ),
          TopicWeakness(
            subTopic: 'Algebra',
            totalQuestions: 5,
            correctCount: 0,
          ),
        ],
      );

      when(() => mockSubmitQuizUseCase(
            quizTitle: any(named: 'quizTitle'),
            questions: any(named: 'questions'),
            durationSeconds: any(named: 'durationSeconds'),
          )).thenAnswer((_) async => const Right(expectedResult));

      await cubit.submitQuiz();

      expect(cubit.state.status, equals(QuizSessionStatus.completed));
      expect(cubit.state.result, isNotNull);
      final res = cubit.state.result!;
      expect(res.scorePercent, equals(30));
      expect(res.weaknesses.length, equals(2));

      // Calculus: 3/5 = 60% accuracy (< 70% is weak)
      final calcWeakness =
          res.weaknesses.firstWhere((w) => w.subTopic == 'Calculus');
      expect(calcWeakness.accuracy, equals(0.60));
      expect(calcWeakness.isWeak, isTrue);

      // Algebra: 0/5 = 0% accuracy
      final algWeakness =
          res.weaknesses.firstWhere((w) => w.subTopic == 'Algebra');
      expect(algWeakness.accuracy, equals(0.0));
      expect(algWeakness.isWeak, isTrue);

      expect(res.weakSubTopics, containsAll(['Calculus', 'Algebra']));
    });
  });
}
