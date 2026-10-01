import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_duel_entity.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/repositories/quiz_duel_repository.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_duel_cubit.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_duel_state.dart';
import 'package:kortex/src/features/quiz/presentation/pages/quiz_duel_arena_page.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class MockQuizDuelRepository extends Mock implements QuizDuelRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockQuizDuelRepository mockRepo;
  late QuizDuelCubit cubit;

  QuizQuestionEntity fakeQuestion() {
    return const QuizQuestionEntity(
      id: 'q1',
      prompt: "What is Newton's third law?",
      type: QuizQuestionType.multipleChoice,
      options: ['Action equals reaction', 'F=ma', 'Inertia', 'Energy conservation'],
      correctAnswer: 'Action equals reaction',
      explanation: 'Equal and opposite reactions.',
      subTopic: 'Physics',
    );
  }

  QuizDuelMatch fakeMatch({
    QuizDuelStatus status = QuizDuelStatus.finished,
    String? rematchRequestedBy,
    bool isAiOpponent = false,
  }) {
    return QuizDuelMatch(
      duelId: 'duel-test-1',
      subject: 'Physics',
      examBoard: 'WAEC',
      questions: [fakeQuestion()],
      player1: const QuizDuelParticipant(
        userId: 'my-user-id',
        displayName: 'Hero',
        avatarUrl: '⚡',
        score: 500,
      ),
      player2: QuizDuelParticipant(
        userId: isAiOpponent ? 'ai-1' : 'rival-user-id',
        displayName: isAiOpponent ? 'Amina' : 'Rival',
        avatarUrl: '🧠',
        score: 350,
        isAiOpponent: isAiOpponent,
      ),
      status: status,
      rematchRequestedBy: rematchRequestedBy,
    );
  }

  setUp(() {
    mockRepo = MockQuizDuelRepository();
    cubit = QuizDuelCubit(repository: mockRepo);
  });

  tearDown(() async {
    await cubit.close();
  });

  Widget buildWidget(QuizDuelState initialState) {
    cubit.emit(initialState);
    return MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider<QuizDuelCubit>.value(
        value: cubit,
        child: const QuizDuelArenaPage(),
      ),
    );
  }

  testWidgets('renders dedicated matchmaking radar view when status is matching', (tester) async {
    final state = QuizDuelState(
      currentUserId: 'my-user-id',
      match: fakeMatch(status: QuizDuelStatus.matching),
    );

    await tester.pumpWidget(buildWidget(state));
    await tester.pump();

    expect(find.text('Searching for Challenger...'), findsOneWidget);
    expect(find.text('Play with AI Bot Now ⚡'), findsOneWidget);
    expect(find.text('Cancel Search'), findsOneWidget);

    // Tapping Cancel Search responds and calls leaveMatch
    when(() => mockRepo.leaveDuel(duelId: any(named: 'duelId'), userId: any(named: 'userId')))
        .thenAnswer((_) async => const Right(null));

    await tester.tap(find.text('Cancel Search'));
    await tester.pump();

    verify(() => mockRepo.leaveDuel(duelId: 'duel-test-1', userId: 'my-user-id')).called(1);
  });

  testWidgets('renders duel ended view when status is cancelled', (tester) async {
    const state = QuizDuelState(
      currentUserId: 'my-user-id',
      status: QuizDuelStatus.cancelled,
      errorMessage: 'Rival disconnected from the duel.',
    );

    await tester.pumpWidget(buildWidget(state));
    await tester.pump();

    expect(find.text('Duel Ended'), findsOneWidget);
    expect(find.text('Rival disconnected from the duel.'), findsOneWidget);
    expect(find.text('Find Another Duel ⚔️'), findsOneWidget);
    expect(find.text('Return to Dashboard'), findsOneWidget);
  });

  testWidgets('shows incoming rematch challenge banner when rival requests rematch', (tester) async {
    final state = QuizDuelState(
      currentUserId: 'my-user-id',
      status: QuizDuelStatus.finished,
      match: fakeMatch(
        rematchRequestedBy: 'rival-user-id',
      ),
    );

    await tester.pumpWidget(buildWidget(state));
    await tester.pump();

    expect(find.text('Rival challenged you to a rematch!'), findsOneWidget);
    expect(find.text('Accept Rematch! ⚔️'), findsOneWidget);
    expect(find.text('Decline / Return to Dashboard'), findsOneWidget);

    // Clicking Accept Rematch responds immediately
    when(() => mockRepo.acceptRematch(duelId: any(named: 'duelId'), userId: any(named: 'userId')))
        .thenAnswer((_) async => Right(fakeMatch(status: QuizDuelStatus.countdown)));

    await tester.ensureVisible(find.text('Accept Rematch! ⚔️'));
    await tester.tap(find.text('Accept Rematch! ⚔️'));
    await tester.pump();

    verify(() => mockRepo.acceptRematch(duelId: 'duel-test-1', userId: 'my-user-id')).called(1);
  });

  testWidgets('shows waiting banner and AI fallback when user requested rematch', (tester) async {
    final state = QuizDuelState(
      currentUserId: 'my-user-id',
      status: QuizDuelStatus.finished,
      match: fakeMatch(
        rematchRequestedBy: 'my-user-id',
      ),
    );

    await tester.pumpWidget(buildWidget(state));
    await tester.pump();

    expect(find.text('Waiting for Rival to accept...'), findsOneWidget);
    expect(find.text('Play with AI Bot Now ⚡'), findsOneWidget);
    expect(find.text('Cancel Rematch Request'), findsOneWidget);

    // Clicking Cancel Rematch Request responds immediately
    when(() => mockRepo.declineRematch(duelId: any(named: 'duelId'), userId: any(named: 'userId')))
        .thenAnswer((_) async => const Right(null));

    await tester.ensureVisible(find.text('Cancel Rematch Request'));
    await tester.tap(find.text('Cancel Rematch Request'));
    await tester.pump();

    verify(() => mockRepo.declineRematch(duelId: 'duel-test-1', userId: 'my-user-id')).called(1);
  });
}
