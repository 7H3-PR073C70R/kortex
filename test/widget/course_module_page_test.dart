import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/auth/domain/entities/user_profile_entity.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_event.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_state.dart';
import 'package:kortex/src/features/dashboard/presentation/pages/nested/course_module_page.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/course_module/course_module_cbt_paper_card.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/course_module/course_module_decks_section.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/course_module/course_module_document_ingestion_card.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/course_module/course_module_exam_countdown_card.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/course_module/course_module_header_banner.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/course_module/course_module_past_questions_section.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_event.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_state.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_cubit.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_state.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_bloc.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_event.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_state.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/pump_app.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class MockPastQuestionsBloc
    extends MockBloc<PastQuestionsEvent, PastQuestionsState>
    implements PastQuestionsBloc {}

class MockCramPlannerCubit extends MockCubit<CramPlannerState>
    implements CramPlannerCubit {}

class MockDecksBloc extends MockBloc<DecksEvent, DecksState>
    implements DecksBloc {}

void main() {
  group('CourseModulePage Widget Tests', () {
    late MockAuthBloc mockAuthBloc;
    late MockPastQuestionsBloc mockPastQuestionsBloc;
    late MockCramPlannerCubit mockCramPlannerCubit;
    late MockDecksBloc mockDecksBloc;

    setUp(() {
      mockAuthBloc = MockAuthBloc();
      mockPastQuestionsBloc = MockPastQuestionsBloc();
      mockCramPlannerCubit = MockCramPlannerCubit();
      mockDecksBloc = MockDecksBloc();

      when(() => mockAuthBloc.state).thenReturn(
        const AuthState(
          status: AuthStatus.authenticated,
          userProfile: UserProfileEntity(
            id: 'user_1',
            email: 'student@example.com',
            displayName: 'Alice Student',
            targetTrack: 'COMPUTER SCIENCE',
          ),
        ),
      );

      when(() => mockPastQuestionsBloc.state).thenReturn(
        const PastQuestionsState(
          status: PastQuestionsStatus.loaded,
        ),
      );

      when(() => mockCramPlannerCubit.state).thenReturn(
        const CramPlannerState(
          status: CramPlannerStatus.loaded,
        ),
      );

      when(() => mockDecksBloc.state).thenReturn(
        const DecksState(
          status: DecksStatus.loaded,
        ),
      );
    });

    testWidgets('renders all course module sections correctly', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpApp(
        BlocProvider<AuthBloc>.value(
          value: mockAuthBloc,
          child: CourseModulePage(
            courseId: 'course_101',
            courseCode: 'CSC 201',
            courseTitle: 'Data Structures & Algorithms',
            pastQuestionsBloc: mockPastQuestionsBloc,
            cramPlannerCubit: mockCramPlannerCubit,
            decksBloc: mockDecksBloc,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CourseModuleHeaderBanner), findsOneWidget);
      expect(find.byType(CourseModuleExamCountdownCard), findsOneWidget);
      expect(find.byType(CourseModuleDocumentIngestionCard), findsOneWidget);
      expect(find.byType(CourseModuleDecksSection), findsOneWidget);
      expect(find.byType(CourseModulePastQuestionsSection), findsOneWidget);

      expect(find.text('CSC 201'), findsWidgets);
      expect(find.text('Data Structures & Algorithms'), findsWidgets);
    });

    testWidgets('renders associated study decks when available', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final testDecks = [
        const DeckEntity(
          id: 'deck_1',
          title: 'Binary Trees & Graphs',
          subject: 'Data Structures & Algorithms',
          courseId: 'course_101',
          courseCode: 'CSC 201',
          totalCards: 40,
          dueCards: 5,
          masteryRate: 0.8,
          category: 'Computer Science',
        ),
      ];

      when(() => mockDecksBloc.state).thenReturn(
        DecksState(
          status: DecksStatus.loaded,
          allDecks: testDecks,
        ),
      );

      await tester.pumpApp(
        BlocProvider<AuthBloc>.value(
          value: mockAuthBloc,
          child: CourseModulePage(
            courseId: 'course_101',
            courseCode: 'CSC 201',
            courseTitle: 'Data Structures & Algorithms',
            pastQuestionsBloc: mockPastQuestionsBloc,
            cramPlannerCubit: mockCramPlannerCubit,
            decksBloc: mockDecksBloc,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Binary Trees & Graphs'), findsOneWidget);
      expect(find.text('40 cards'), findsOneWidget);
      expect(find.text('5 due'), findsOneWidget);
    });

    testWidgets('renders CBT mock card when questions are available',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const testQuestions = [
        PastQuestionEntity(
          id: 'q_1',
          examType: ExamCategory.computerScience,
          subject: 'Computer Science',
          year: 2024,
          questionNumber: 1,
          prompt: 'What is the time complexity of binary search?',
          options: ['O(n)', 'O(log n)', 'O(n^2)', 'O(1)'],
          correctOptionIndex: 1,
          correctOptionLabel: 'B',
          explanation: 'Binary search halves the search space each step.',
          topic: 'Algorithms',
        ),
      ];

      when(() => mockPastQuestionsBloc.state).thenReturn(
        const PastQuestionsState(
          status: PastQuestionsStatus.loaded,
          questions: testQuestions,
        ),
      );

      await tester.pumpApp(
        BlocProvider<AuthBloc>.value(
          value: mockAuthBloc,
          child: CourseModulePage(
            courseId: 'course_101',
            courseCode: 'CSC 201',
            courseTitle: 'Data Structures & Algorithms',
            pastQuestionsBloc: mockPastQuestionsBloc,
            cramPlannerCubit: mockCramPlannerCubit,
            decksBloc: mockDecksBloc,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CourseModuleCbtPaperCard), findsWidgets);
      expect(find.text('Full CBT Mock Examination'), findsOneWidget);
      expect(find.text('Quick Practice Drill'), findsOneWidget);
    });
  });
}
