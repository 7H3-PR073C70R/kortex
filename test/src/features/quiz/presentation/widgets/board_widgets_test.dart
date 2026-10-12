import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_bloc.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_state.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/board/board_course_grouping_helper.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/board/board_desktop_workspace.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/board/board_hero_track_banner.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/board/board_search_filter_header.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/board/course_overview_card.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class MockPastQuestionsBloc extends Mock implements PastQuestionsBloc {}

Widget createTestApp(Widget child, {PastQuestionsBloc? pastQuestionsBloc}) {
  final app = MaterialApp(
    theme: AppTheme.lightTheme,
    darkTheme: AppTheme.darkTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );

  if (pastQuestionsBloc != null) {
    return BlocProvider<PastQuestionsBloc>.value(
      value: pastQuestionsBloc,
      child: app,
    );
  }
  return app;
}

void main() {
  group('BoardCourseGroupingHelper Tests', () {
    test('getSubjectIcon returns appropriate icon for subject names', () {
      expect(
        BoardCourseGroupingHelper.getSubjectIcon('Mathematics'),
        Icons.calculate_outlined,
      );
      expect(
        BoardCourseGroupingHelper.getSubjectIcon('Physics'),
        Icons.electric_bolt_outlined,
      );
      expect(
        BoardCourseGroupingHelper.getSubjectIcon('Chemistry'),
        Icons.science_outlined,
      );
      expect(
        BoardCourseGroupingHelper.getSubjectIcon('Biology'),
        Icons.biotech_outlined,
      );
      expect(
        BoardCourseGroupingHelper.getSubjectIcon('English Language'),
        Icons.menu_book_rounded,
      );
      expect(
        BoardCourseGroupingHelper.getSubjectIcon('Economics'),
        Icons.trending_up_rounded,
      );
      expect(
        BoardCourseGroupingHelper.getSubjectIcon('Government'),
        Icons.account_balance_outlined,
      );
      expect(
        BoardCourseGroupingHelper.getSubjectIcon('Computer Science'),
        Icons.terminal_rounded,
      );
      expect(
        BoardCourseGroupingHelper.getSubjectIcon('Agricultural Science'),
        Icons.agriculture_rounded,
      );
      expect(
        BoardCourseGroupingHelper.getSubjectIcon('History'),
        Icons.school_outlined,
      );
    });

    test('groupQuestionsByCourse properly groups and counts questions', () {
      final questions = [
        const PastQuestionEntity(
          id: 'q1',
          subject: 'Physics',
          topic: 'Mechanics',
          examType: ExamCategory.waec,
          year: 2023,
          questionNumber: 1,
          prompt: 'What is force?',
          options: ['Mass times acceleration', 'Energy', 'Power', 'Work'],
          correctOptionIndex: 0,
          correctOptionLabel: 'A',
          explanation: 'F = ma',
          userSelectedOptionIndex: 0,
        ),
        const PastQuestionEntity(
          id: 'q2',
          subject: 'Physics',
          topic: 'Optics',
          examType: ExamCategory.waec,
          year: 2024,
          questionNumber: 2,
          prompt: 'Speed of light',
          options: ['3e8', '2e8', '1e8', '4e8'],
          correctOptionIndex: 0,
          correctOptionLabel: 'A',
          explanation: 'c = 3e8 m/s',
        ),
        const PastQuestionEntity(
          id: 'q3',
          subject: 'Chemistry',
          topic: 'Acids',
          examType: ExamCategory.waec,
          year: 2024,
          questionNumber: 1,
          prompt: 'pH of water',
          options: ['7', '1', '14', '0'],
          correctOptionIndex: 0,
          correctOptionLabel: 'A',
          explanation: 'Neutral is 7',
        ),
      ];

      final summaries = BoardCourseGroupingHelper.groupQuestionsByCourse(
        questions: questions,
        availableSubjects: ['All', 'Physics', 'Chemistry', 'Biology'],
        selectedSubject: 'All',
        searchQuery: '',
      );

      expect(summaries.length, 3);
      final physics = summaries.firstWhere((c) => c.title == 'Physics');
      expect(physics.totalQuestions, 2);
      expect(physics.answeredQuestions, 1);
      expect(physics.yearRange, '2023–2024');

      final chemistry = summaries.firstWhere((c) => c.title == 'Chemistry');
      expect(chemistry.totalQuestions, 1);
      expect(chemistry.answeredQuestions, 0);
      expect(chemistry.yearRange, '2024');

      final biology = summaries.firstWhere((c) => c.title == 'Biology');
      expect(biology.totalQuestions, 0);
      expect(biology.yearRange, 'All Years');
    });
  });

  group('Board Widgets Presentation Tests', () {
    late MockPastQuestionsBloc mockBloc;

    setUp(() {
      mockBloc = MockPastQuestionsBloc();
      when(() => mockBloc.state).thenReturn(
        const PastQuestionsState(
          status: PastQuestionsStatus.loaded,
          selectedSubject: 'Physics',
        ),
      );
      when(() => mockBloc.stream).thenAnswer(
        (_) => Stream.value(
          const PastQuestionsState(
            status: PastQuestionsStatus.loaded,
            selectedSubject: 'Physics',
          ),
        ),
      );
    });

    testWidgets('CourseOverviewCard renders subject details and handles tap', (
      tester,
    ) async {
      var tapped = false;
      const summary = CourseSummary(
        title: 'Physics',
        totalQuestions: 40,
        answeredQuestions: 20,
        yearRange: '2020–2024',
        iconData: Icons.electric_bolt_outlined,
      );

      await tester.pumpWidget(
        createTestApp(
          CourseOverviewCard(
            courseSummary: summary,
            examCategory: ExamCategory.waec,
            onTap: () => tapped = true,
          ),
        ),
      );

      expect(find.text('Physics'), findsOneWidget);
      expect(find.text('WAEC / WASSCE'), findsOneWidget);
      expect(find.text('40 Questions • 2020–2024'), findsOneWidget);
      expect(find.text('20 of 40 practiced'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);

      await tester.tap(find.byType(CourseOverviewCard));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('BoardSearchFilterHeader renders and dispatches text change', (
      tester,
    ) async {
      String? changedQuery;
      final controller = TextEditingController();

      await tester.pumpWidget(
        createTestApp(
          BoardSearchFilterHeader(
            searchController: controller,
            onSearchChanged: (q) => changedQuery = q,
          ),
          pastQuestionsBloc: mockBloc,
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Electromagnetism');
      await tester.pump();

      expect(changedQuery, 'Electromagnetism');
    });

    testWidgets('BoardHeroTrackBanner renders track banner and toggle', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          const BoardHeroTrackBanner(userTrack: 'Science'),
          pastQuestionsBloc: mockBloc,
        ),
      );

      expect(find.text('My Track Scope'), findsOneWidget);
      expect(find.text('Explore All Tracks'), findsOneWidget);
      expect(find.text('My Track: WAEC / WASSCE (Science)'), findsOneWidget);
      expect(find.text('Duel a classmate'), findsOneWidget);
    });

    testWidgets('BoardDesktopWorkspace renders active subject header and Start Test', (
      tester,
    ) async {
      const activeCourse = CourseSummary(
        title: 'Chemistry',
        totalQuestions: 50,
        answeredQuestions: 15,
        yearRange: '2019–2024',
        iconData: Icons.science_outlined,
      );

      await tester.pumpWidget(
        createTestApp(
          const BoardDesktopWorkspace(
            activeCourse: activeCourse,
            courseQuestions: [],
            state: PastQuestionsState(
              status: PastQuestionsStatus.loaded,
            ),
          ),
          pastQuestionsBloc: mockBloc,
        ),
      );

      expect(find.text('Chemistry'), findsOneWidget);
      expect(find.text('Start Test'), findsOneWidget);
      expect(
        find.text('No questions loaded for Chemistry'),
        findsOneWidget,
      );
    });
  });
}
