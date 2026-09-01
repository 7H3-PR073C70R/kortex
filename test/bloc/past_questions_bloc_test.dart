import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/repositories/past_questions_repository.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_bloc.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_event.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_state.dart';
import 'package:mocktail/mocktail.dart';

class MockPastQuestionsRepository extends Mock
    implements PastQuestionsRepository {}

void main() {
  group('PastQuestionsBloc Test Suite', () {
    late MockPastQuestionsRepository mockRepository;
    late PastQuestionsBloc bloc;

    const tQuestion = PastQuestionEntity(
      id: 'waec_math_2024_q1',
      examType: ExamCategory.waec,
      subject: 'Mathematics',
      year: 2024,
      questionNumber: 1,
      prompt: 'If 2^(x+1) + 2^x = 24, find the value of x.',
      options: ['2', '3', '4', '5'],
      correctOptionIndex: 1,
      correctOptionLabel: 'B',
      explanation: 'Factor out 2^x = 8 => x = 3',
      topic: 'Indices',
    );

    setUpAll(() {
      registerFallbackValue(ExamCategory.waec);
    });

    setUp(() {
      mockRepository = MockPastQuestionsRepository();
      bloc = PastQuestionsBloc(repository: mockRepository);
    });

    tearDown(() async {
      await bloc.close();
    });

    test('initial state has correct default values', () {
      expect(bloc.state.status, equals(PastQuestionsStatus.initial));
      expect(bloc.state.selectedExam, equals(ExamCategory.waec));
      expect(bloc.state.selectedSubject, equals('All'));
      expect(bloc.state.questions, isEmpty);
      expect(bloc.state.isInstantFeedbackMode, isTrue);
    });

    blocTest<PastQuestionsBloc, PastQuestionsState>(
      'emits [loading, loaded] when LoadPastQuestionsEvent succeeds',
      build: () {
        when(
          () => mockRepository.getAvailableSubjects(any()),
        ).thenAnswer((_) async => const Right(['Mathematics', 'English']));
        when(
          () => mockRepository.getAvailableYears(any()),
        ).thenAnswer((_) async => const Right([2024, 2023]));
        when(
          () => mockRepository.getPastQuestions(
            examCategory: any(named: 'examCategory'),
            subject: any(named: 'subject'),
            year: any(named: 'year'),
            searchQuery: any(named: 'searchQuery'),
          ),
        ).thenAnswer((_) async => const Right([tQuestion]));
        return bloc;
      },
      act: (b) => b.add(const LoadPastQuestionsEvent()),
      expect: () => [
        const PastQuestionsState(status: PastQuestionsStatus.loading),
        const PastQuestionsState(
          status: PastQuestionsStatus.loaded,
          questions: [tQuestion],
          availableSubjects: ['Mathematics', 'English'],
          availableYears: [2024, 2023],
        ),
      ],
    );

    blocTest<PastQuestionsBloc, PastQuestionsState>(
      'SelectOptionEvent updates userSelectedOptionIndex for question',
      build: () => bloc,
      seed: () => const PastQuestionsState(
        status: PastQuestionsStatus.loaded,
        questions: [tQuestion],
      ),
      act: (b) => b.add(
        const SelectOptionEvent(
          questionId: 'waec_math_2024_q1',
          optionIndex: 1,
        ),
      ),
      expect: () => [
        PastQuestionsState(
          status: PastQuestionsStatus.loaded,
          questions: [
            tQuestion.copyWith(userSelectedOptionIndex: 1),
          ],
        ),
      ],
      verify: (b) {
        expect(b.state.answeredQuestions, equals(1));
        expect(b.state.correctAnswers, equals(1));
      },
    );

    blocTest<PastQuestionsBloc, PastQuestionsState>(
      'ToggleBookmarkEvent updates isBookmarked flag and calls repository',
      build: () {
        when(
          () => mockRepository.toggleBookmarkQuestion('waec_math_2024_q1'),
        ).thenAnswer((_) async => const Right(null));
        return bloc;
      },
      seed: () => const PastQuestionsState(
        status: PastQuestionsStatus.loaded,
        questions: [tQuestion],
      ),
      act: (b) => b.add(
        const ToggleBookmarkEvent('waec_math_2024_q1'),
      ),
      expect: () => [
        PastQuestionsState(
          status: PastQuestionsStatus.loaded,
          questions: [
            tQuestion.copyWith(isBookmarked: true),
          ],
        ),
      ],
    );

    blocTest<PastQuestionsBloc, PastQuestionsState>(
      'TogglePracticeModeEvent toggles isInstantFeedbackMode',
      build: () => bloc,
      act: (b) => b.add(const TogglePracticeModeEvent()),
      expect: () => [
        const PastQuestionsState(
          isInstantFeedbackMode: false,
        ),
      ],
    );
  });
}
