import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_event.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_state.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_session_cubit.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_session_state.dart';
import 'package:kortex/src/features/quiz/presentation/pages/quiz_workspace_page.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/latex_rich_viewer.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/workspace/quiz_workspace_action_bar.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/workspace/quiz_workspace_options_list.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/workspace/quiz_workspace_palette_sheet.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/workspace/quiz_workspace_prompt_card.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/workspace/quiz_workspace_question_header.dart';
import 'package:kortex/src/shared/widgets/app_logo_loader.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/pump_app.dart';

class MockQuizSessionCubit extends MockCubit<QuizSessionState>
    implements QuizSessionCubit {}

class MockDecksBloc extends MockBloc<DecksEvent, DecksState>
    implements DecksBloc {}

void main() {
  setUpAll(() {
    registerFallbackValue(AssessmentMode.discoveryMode);
  });

  group('QuizWorkspacePage Widget Tests', () {
    late MockQuizSessionCubit mockQuizSessionCubit;
    late MockDecksBloc mockDecksBloc;

    setUp(() {
      mockQuizSessionCubit = MockQuizSessionCubit();
      mockDecksBloc = MockDecksBloc();

      when(() => mockDecksBloc.state).thenReturn(const DecksState());
      when(
        () => mockQuizSessionCubit.startQuizFromDeck(
          deckId: any(named: 'deckId'),
          deckTitle: any(named: 'deckTitle'),
          questionCount: any(named: 'questionCount'),
          durationMinutes: any(named: 'durationMinutes'),
          assessmentMode: any(named: 'assessmentMode'),
        ),
      ).thenAnswer((_) async {});
    });

    testWidgets('renders AppLogoLoader on loading status', (tester) async {
      when(() => mockQuizSessionCubit.state).thenReturn(
        const QuizSessionState(status: QuizSessionStatus.loading),
      );

      await tester.pumpApp(
        QuizWorkspacePage(
          deckId: 'deck_1',
          quizSessionCubit: mockQuizSessionCubit,
          decksBloc: mockDecksBloc,
        ),
      );

      expect(find.byType(AppLogoLoader), findsOneWidget);
    });

    testWidgets('renders error headline and retry action on error status', (
      tester,
    ) async {
      when(() => mockQuizSessionCubit.state).thenReturn(
        const QuizSessionState(
          status: QuizSessionStatus.error,
          errorMessage: 'Unable to reach quiz service',
        ),
      );

      await tester.pumpApp(
        QuizWorkspacePage(
          deckId: 'deck_1',
          quizSessionCubit: mockQuizSessionCubit,
          decksBloc: mockDecksBloc,
        ),
      );

      expect(find.text('We could not load this quiz'), findsOneWidget);
      expect(find.text('Unable to reach quiz service'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('renders question prompt, options, header, and action bar', (
      tester,
    ) async {
      const question = QuizQuestionEntity(
        id: 'q_1',
        type: QuizQuestionType.multipleChoice,
        prompt: 'What is the principal organ of photosynthesis in plants?',
        options: ['Leaf', 'Root', 'Stem', 'Flower'],
        correctAnswer: 'Leaf',
        subTopic: 'Plant Physiology',
        explanation: 'Leaves contain chloroplasts with chlorophyll.',
      );

      when(() => mockQuizSessionCubit.state).thenReturn(
        const QuizSessionState(
          status: QuizSessionStatus.inProgress,
          quizTitle: 'Biology 101 Quiz',
          questions: [question],
        ),
      );

      await tester.pumpApp(
        QuizWorkspacePage(
          deckId: 'deck_1',
          quizSessionCubit: mockQuizSessionCubit,
          decksBloc: mockDecksBloc,
        ),
      );
      await tester.pump();

      expect(find.byType(QuizWorkspaceQuestionHeader), findsOneWidget);
      expect(find.byType(QuizPromptCard), findsOneWidget);
      expect(find.byType(LatexRichViewer), findsWidgets);
      expect(find.byType(QuizWorkspaceOptionsList), findsOneWidget);
      expect(find.byType(QuizActionBar), findsOneWidget);
      expect(find.text('Leaf'), findsOneWidget);
      expect(find.text('Root'), findsOneWidget);
    });

    testWidgets('opens question palette drawer when palette icon tapped', (
      tester,
    ) async {
      const question = QuizQuestionEntity(
        id: 'q_1',
        type: QuizQuestionType.multipleChoice,
        prompt: 'What is photosynthesis?',
        options: ['A', 'B', 'C', 'D'],
        correctAnswer: 'A',
        subTopic: 'Biology',
        explanation: '',
      );

      when(() => mockQuizSessionCubit.state).thenReturn(
        const QuizSessionState(
          status: QuizSessionStatus.inProgress,
          quizTitle: 'Biology Quiz',
          questions: [question],
        ),
      );

      await tester.pumpApp(
        QuizWorkspacePage(
          deckId: 'deck_1',
          quizSessionCubit: mockQuizSessionCubit,
          decksBloc: mockDecksBloc,
        ),
      );
      await tester.pump();

      final paletteButton = find.byTooltip('Question Palette');
      expect(paletteButton, findsOneWidget);

      await tester.tap(paletteButton);
      await tester.pumpAndSettle();

      expect(find.byType(QuestionPaletteSheet), findsOneWidget);
      expect(find.text('All questions'), findsOneWidget);
    });
  });
}
