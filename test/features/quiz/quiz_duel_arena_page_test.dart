import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/quiz/data/client/quiz_duel_websocket_client.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_duel_entity.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_duel_cubit.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_duel_state.dart';
import 'package:kortex/src/features/quiz/presentation/pages/quiz_duel_arena_page.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class MockQuizDuelCubit extends MockCubit<QuizDuelState>
    implements QuizDuelCubit {}

Widget createTestApp({required Widget child, required QuizDuelCubit cubit}) {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: BlocProvider<QuizDuelCubit>.value(
      value: cubit,
      child: child,
    ),
  );
}

void main() {
  group('QuizDuelArenaPage Widget Test Suite', () {
    late MockQuizDuelCubit mockCubit;
    late QuizDuelMatch testMatch;

    setUp(() {
      mockCubit = MockQuizDuelCubit();
      testMatch = QuizDuelMatch(
        duelId: 'test_duel_123',
        subject: 'Physics',
        examBoard: 'WAEC',
        questions: QuizDuelWebSocketClient.getDefaultDuelQuestions('Physics', 'WAEC'),
        player1: const QuizDuelParticipant(
          userId: 'user_1',
          displayName: 'Scholar One',
          avatarUrl: '⚡',
          score: 120,
        ),
        player2: const QuizDuelParticipant(
          userId: 'ai_bot_1',
          displayName: 'Syllabot Rival',
          avatarUrl: '🧠',
          score: 95,
          isAiOpponent: true,
        ),
        status: QuizDuelStatus.inRound,
      );
    });

    testWidgets('renders countdown view when status is countdown', (tester) async {
      when(() => mockCubit.state).thenReturn(
        QuizDuelState(
          status: QuizDuelStatus.countdown,
          currentUserId: 'user_1',
          match: testMatch.copyWith(status: QuizDuelStatus.countdown),
        ),
      );

      await tester.pumpWidget(
        createTestApp(
          cubit: mockCubit,
          child: const QuizDuelArenaPage(),
        ),
      );

      expect(find.text('MATCH FOUND!'), findsOneWidget);
      expect(find.text('Scholar One'), findsOneWidget);
      expect(find.text('Syllabot Rival'), findsOneWidget);
      expect(find.text('VS'), findsOneWidget);
    });

    testWidgets('renders active question, scoreboard, timer, and options in round', (tester) async {
      when(() => mockCubit.state).thenReturn(
        QuizDuelState(
          status: QuizDuelStatus.inRound,
          currentUserId: 'user_1',
          match: testMatch,
          remainingSeconds: 12,
        ),
      );

      await tester.pumpWidget(
        createTestApp(
          cubit: mockCubit,
          child: const QuizDuelArenaPage(),
        ),
      );

      expect(find.text('Scholar One'), findsOneWidget);
      expect(find.text('120 pts'), findsOneWidget);
      expect(find.text('Syllabot Rival'), findsOneWidget);
      expect(find.text('95 pts'), findsOneWidget);
      expect(find.text('What is the SI unit of electric potential difference?'), findsOneWidget);
      expect(find.text('Volt'), findsOneWidget);
      expect(find.text('Ampere'), findsOneWidget);
    });

    testWidgets('renders victory screen when match finishes with local win', (tester) async {
      when(() => mockCubit.state).thenReturn(
        QuizDuelState(
          status: QuizDuelStatus.finished,
          currentUserId: 'user_1',
          match: testMatch.copyWith(
            status: QuizDuelStatus.finished,
            winnerUserId: 'user_1',
            player1: testMatch.player1.copyWith(score: 450),
            player2: testMatch.player2?.copyWith(score: 300),
          ),
        ),
      );

      await tester.pumpWidget(
        createTestApp(
          cubit: mockCubit,
          child: const QuizDuelArenaPage(),
        ),
      );

      expect(find.text('🏆 VICTORY!'), findsOneWidget);
      expect(find.text('450 pts'), findsOneWidget);
      expect(find.text('300 pts'), findsOneWidget);
      expect(find.text('Rematch ⚡'), findsOneWidget);
      expect(find.text('Exit Arena'), findsOneWidget);
    });
  });
}
