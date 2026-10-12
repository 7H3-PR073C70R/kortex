import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/duel/quiz_duel_course_chips.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/duel/quiz_duel_invite_friend_tab.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/duel/quiz_duel_join_code_tab.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/duel/quiz_duel_matchmaking_actions_dock.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/duel/quiz_duel_matchmaking_header.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/duel/quiz_duel_quick_match_tab.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/duel/quiz_duel_searching_radar_view.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';

Widget _buildTestApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: child,
    ),
  );
}

void main() {
  group('QuizDuelMatchmakingHeader Tests', () {
    testWidgets('renders header title and ELO tier badge', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          const QuizDuelMatchmakingHeader(
            userElo: 1400,
            isDesktop: false,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('1v1 Academic Duel'), findsOneWidget);
      expect(
        find.text('Real-time battle of speed and academic mastery.'),
        findsOneWidget,
      );
    });
  });

  group('QuizDuelSearchingRadarView Tests', () {
    testWidgets('renders private room code and action buttons', (tester) async {
      late AnimationController controller;
      await tester.pumpWidget(
        _buildTestApp(
          Builder(
            builder: (context) {
              controller = AnimationController(
                vsync: const TestVSync(),
                duration: const Duration(seconds: 1),
              );
              return QuizDuelSearchingRadarView(
                pulseController: controller,
                activeRoomCode: 'AB12CD',
                searchSeconds: 3,
                selectedSubject: 'Mathematics',
                resolvedExamBoard: 'WAEC',
                selectedQuestionCount: 10,
                onCopyCode: (_) {},
                onShareInvite: (_) {},
              );
            },
          ),
        ),
      );
      await tester.pump();

      expect(find.text('AB12CD'), findsOneWidget);
      expect(find.text('ROOM CODE: '), findsOneWidget);
      expect(find.text('Waiting for friend to join with code...'), findsOneWidget);
      expect(find.text('Share Code & Invite'), findsOneWidget);
    });

    testWidgets('renders public scanning text when no room code is present', (tester) async {
      late AnimationController controller;
      await tester.pumpWidget(
        _buildTestApp(
          Builder(
            builder: (context) {
              controller = AnimationController(
                vsync: const TestVSync(),
                duration: const Duration(seconds: 1),
              );
              return QuizDuelSearchingRadarView(
                pulseController: controller,
                activeRoomCode: null,
                searchSeconds: 2,
                selectedSubject: 'Physics',
                resolvedExamBoard: 'WAEC',
                selectedQuestionCount: 10,
                onCopyCode: (_) {},
                onShareInvite: (_) {},
              );
            },
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text('Scanning online scholars in Physics…'),
        findsOneWidget,
      );
    });
  });

  group('QuizDuelQuickMatchTab Tests', () {
    testWidgets('renders subjects and questions choice chips', (tester) async {
      String? selectedSub;
      int? selectedCount;

      await tester.pumpWidget(
        _buildTestApp(
          QuizDuelQuickMatchTab(
            subjects: const ['Math', 'Physics', 'Biology'],
            selectedSubject: 'Math',
            selectedQuestionCount: 10,
            hasCustomCourses: true,
            onSelectSubject: (s) => selectedSub = s,
            onSelectQuestionCount: (c) => selectedCount = c,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Math'), findsOneWidget);
      expect(find.text('Physics'), findsOneWidget);
      expect(find.text('Biology'), findsOneWidget);

      await tester.tap(find.text('Physics'));
      await tester.pump();
      expect(selectedSub, equals('Physics'));

      await tester.tap(find.text('5 questions'));
      await tester.pump();
      expect(selectedCount, equals(5));
    });
  });

  group('QuizDuelInviteFriendTab Tests', () {
    testWidgets('renders private duel code and regenerate button', (tester) async {
      var regenerated = false;

      await tester.pumpWidget(
        _buildTestApp(
          QuizDuelInviteFriendTab(
            generatedCode: 'XYZ987',
            subjects: const ['Chemistry'],
            selectedSubject: 'Chemistry',
            hasCustomCourses: true,
            onCopyCode: (_) {},
            onGenerateNewCode: () => regenerated = true,
            onShareInvite: (_) {},
            onSelectSubject: (_) {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('XYZ987'), findsOneWidget);
      expect(find.text('Generate New Code'), findsOneWidget);
      expect(find.text('Share Code'), findsOneWidget);

      await tester.tap(find.text('Generate New Code'));
      await tester.pump();
      expect(regenerated, isTrue);
    });
  });

  group('QuizDuelJoinCodeTab Tests', () {
    testWidgets('renders code input field', (tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        _buildTestApp(
          QuizDuelJoinCodeTab(
            enteredCodeController: controller,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('ENTER 6-DIGIT ROOM CODE'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });
  });

  group('QuizDuelMatchmakingActionsDock Tests', () {
    testWidgets('renders quick match actions on Tab 0', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          QuizDuelMatchmakingActionsDock(
            isSearching: false,
            activeTab: 0,
            generatedCode: 'CODE12',
            onMatchWithAiImmediately: () {},
            onCancelSearch: () {},
            onQuickMatch: () {},
            onQuickMatchWithAi: () {},
            onStartRoomLobby: () {},
            onJoinRoomWithCode: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Find a classmate'), findsOneWidget);
      expect(find.text('Practice Solo with AI'), findsOneWidget);
    });

    testWidgets('renders lobby start action on Tab 1', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          QuizDuelMatchmakingActionsDock(
            isSearching: false,
            activeTab: 1,
            generatedCode: 'CODE12',
            onMatchWithAiImmediately: () {},
            onCancelSearch: () {},
            onQuickMatch: () {},
            onQuickMatchWithAi: () {},
            onStartRoomLobby: () {},
            onJoinRoomWithCode: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Start Room Lobby (CODE12)'), findsOneWidget);
    });

    testWidgets('renders searching actions when isSearching is true', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          QuizDuelMatchmakingActionsDock(
            isSearching: true,
            activeTab: 0,
            generatedCode: 'CODE12',
            onMatchWithAiImmediately: () {},
            onCancelSearch: () {},
            onQuickMatch: () {},
            onQuickMatchWithAi: () {},
            onStartRoomLobby: () {},
            onJoinRoomWithCode: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Practice with AI now'), findsOneWidget);
      expect(find.text('Cancel search'), findsOneWidget);
    });
  });

  group('QuizDuelCourseChips Tests', () {
    testWidgets('DefaultSubjectsBanner renders default subjects info', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          const DefaultSubjectsBanner(),
        ),
      );
      await tester.pump();

      expect(find.text('Default Foundational Subjects'), findsOneWidget);
      expect(find.text('Add Courses'), findsOneWidget);
    });
  });
}
