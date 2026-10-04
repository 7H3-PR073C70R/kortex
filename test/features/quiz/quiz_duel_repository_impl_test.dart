import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';
import 'package:kortex/src/features/decks/domain/repositories/decks_repository.dart';
import 'package:kortex/src/features/quiz/data/client/quiz_duel_websocket_client.dart';
import 'package:kortex/src/features/quiz/data/repositories/quiz_duel_repository_impl.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_duel_entity.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/repositories/past_questions_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockQuizDuelWebSocketClient extends Mock
    implements QuizDuelWebSocketClient {}

class MockPastQuestionsRepository extends Mock
    implements PastQuestionsRepository {}

class MockDecksRepository extends Mock implements DecksRepository {}

class FakeQuizQuestionEntity extends Fake implements QuizQuestionEntity {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeQuizQuestionEntity());
  });

  group('QuizDuelRepositoryImpl Question Sourcing Tests', () {
    late MockQuizDuelWebSocketClient mockClient;
    late MockPastQuestionsRepository mockPastRepo;
    late MockDecksRepository mockDecksRepo;
    late QuizDuelRepositoryImpl repository;

    setUp(() {
      mockClient = MockQuizDuelWebSocketClient();
      mockPastRepo = MockPastQuestionsRepository();
      mockDecksRepo = MockDecksRepository();

      repository = QuizDuelRepositoryImpl(
        client: mockClient,
        pastQuestionsRepository: mockPastRepo,
        decksRepository: mockDecksRepo,
      );
    });

    test(
      'returns NoQuizQuestionsFailure when no past questions, no decks, and remote generation is empty',
      () async {
        // 1. Past questions returns empty
        when(
          () => mockPastRepo.getPastQuestions(
            subject: any(named: 'subject'),
            courseCode: any(named: 'courseCode'),
          ),
        ).thenAnswer((_) async => const Right(<PastQuestionEntity>[]));

        // 2. Decks returns empty
        when(() => mockDecksRepo.getUserDecks())
            .thenAnswer((_) async => const Right(<DeckEntity>[]));

        // 3. Remote generation returns empty (offline or no backend questions)
        when(
          () => mockClient.fetchRemoteDuelQuestions(
            any(),
            any(),
            count: any(named: 'count'),
          ),
        ).thenAnswer((_) async => const <QuizQuestionEntity>[]);

        final result = await repository.findOrCreateDuel(
          subject: 'Operating Systems',
          examBoard: 'BSC',
          userId: 'user_1',
          displayName: 'Scholar One',
          avatarUrl: '⚡',
        );

        expect(result.isLeft, isTrue);
        result.fold(
          (failure) {
            expect(failure, isA<NoQuizQuestionsFailure>());
            final noQFailure = failure as NoQuizQuestionsFailure;
            expect(noQFailure.subject, equals('Operating Systems'));
            expect(
              noQFailure.message,
              contains('No questions found for "Operating Systems"'),
            );
          },
          (_) => fail('Expected failure but got match'),
        );

        // Verify findOrCreateDuel on client is NOT called with dummy questions
        verifyNever(
          () => mockClient.findOrCreateDuel(
            subject: any(named: 'subject'),
            examBoard: any(named: 'examBoard'),
            userId: any(named: 'userId'),
            displayName: any(named: 'displayName'),
            avatarUrl: any(named: 'avatarUrl'),
            questionCount: any(named: 'questionCount'),
            customQuestions: any(named: 'customQuestions'),
            roomCode: any(named: 'roomCode'),
            fallbackToDefaultQuestions: any(
              named: 'fallbackToDefaultQuestions',
            ),
          ),
        );
      },
    );

    test(
      'uses remote questions when local past questions and decks are empty but remote succeeds',
      () async {
        when(
          () => mockPastRepo.getPastQuestions(
            subject: any(named: 'subject'),
            courseCode: any(named: 'courseCode'),
          ),
        ).thenAnswer((_) async => const Right(<PastQuestionEntity>[]));

        when(() => mockDecksRepo.getUserDecks())
            .thenAnswer((_) async => const Right(<DeckEntity>[]));

        const remoteQ = QuizQuestionEntity(
          id: 'remote_q1',
          prompt: 'What is a deadlock in OS?',
          type: QuizQuestionType.multipleChoice,
          options: ['Condition A', 'Condition B', 'Condition C', 'Condition D'],
          correctAnswer: 'Condition A',
          explanation: 'A deadlock is a permanent blocking condition.',
          subTopic: 'Concurrency',
        );

        when(
          () => mockClient.fetchRemoteDuelQuestions(
            any(),
            any(),
            count: any(named: 'count'),
          ),
        ).thenAnswer((_) async => const [remoteQ]);

        const expectedMatch = QuizDuelMatch(
          duelId: 'duel_remote_1',
          subject: 'Operating Systems',
          examBoard: 'BSC',
          questions: [remoteQ],
          player1: QuizDuelParticipant(
            userId: 'user_1',
            displayName: 'Scholar One',
            avatarUrl: '⚡',
          ),
        );

        when(
          () => mockClient.findOrCreateDuel(
            subject: 'Operating Systems',
            examBoard: 'BSC',
            userId: 'user_1',
            displayName: 'Scholar One',
            avatarUrl: '⚡',
            customQuestions: const [remoteQ],
            fallbackToDefaultQuestions: false,
          ),
        ).thenAnswer((_) async => expectedMatch);

        final result = await repository.findOrCreateDuel(
          subject: 'Operating Systems',
          examBoard: 'BSC',
          userId: 'user_1',
          displayName: 'Scholar One',
          avatarUrl: '⚡',
        );

        expect(result.isRight, isTrue);
        expect(result.fold((_) => null, (m) => m), equals(expectedMatch));
      },
    );

    test(
      'synthesizes questions from user flashcards when past questions are empty',
      () async {
        when(
          () => mockPastRepo.getPastQuestions(
            subject: any(named: 'subject'),
            courseCode: any(named: 'courseCode'),
          ),
        ).thenAnswer((_) async => const Right(<PastQuestionEntity>[]));

        const deck = DeckEntity(
          id: 'deck_os_1',
          title: 'Operating Systems',
          subject: 'Operating Systems',
          totalCards: 2,
          dueCards: 0,
          masteryRate: 0.5,
          category: 'Computer Science',
        );

        when(() => mockDecksRepo.getUserDecks())
            .thenAnswer((_) async => const Right([deck]));

        const card1 = FlashcardEntity(
          id: 'c1',
          deckId: 'deck_os_1',
          front: 'What is a Semaphore?',
          back: 'A synchronization variable',
        );
        const card2 = FlashcardEntity(
          id: 'c2',
          deckId: 'deck_os_1',
          front: 'What is Virtual Memory?',
          back: 'An OS memory management capability',
        );

        when(() => mockDecksRepo.getDeckCards('deck_os_1'))
            .thenAnswer((_) async => const Right([card1, card2]));

        when(
          () => mockClient.fetchRemoteDuelQuestions(
            any(),
            any(),
            count: any(named: 'count'),
          ),
        ).thenAnswer((_) async => const <QuizQuestionEntity>[]);

        when(
          () => mockClient.findOrCreateDuel(
            subject: any(named: 'subject'),
            examBoard: any(named: 'examBoard'),
            userId: any(named: 'userId'),
            displayName: any(named: 'displayName'),
            avatarUrl: any(named: 'avatarUrl'),
            questionCount: any(named: 'questionCount'),
            customQuestions: any(named: 'customQuestions'),
            fallbackToDefaultQuestions: false,
          ),
        ).thenAnswer(
          (invocation) async => QuizDuelMatch(
            duelId: 'duel_flashcards',
            subject: 'Operating Systems',
            examBoard: 'BSC',
            questions: invocation.namedArguments[#customQuestions]
                as List<QuizQuestionEntity>,
            player1: const QuizDuelParticipant(
              userId: 'user_1',
              displayName: 'Scholar One',
              avatarUrl: '⚡',
            ),
          ),
        );

        final result = await repository.findOrCreateDuel(
          subject: 'Operating Systems',
          examBoard: 'BSC',
          userId: 'user_1',
          displayName: 'Scholar One',
          avatarUrl: '⚡',
          questionCount: 2,
        );

        expect(result.isRight, isTrue);
        final match = result.fold((_) => null, (m) => m)!;
        expect(match.questions.length, equals(2));
        expect(
          match.questions.any((q) => q.prompt == 'What is a Semaphore?'),
          isTrue,
        );
        expect(
          match.questions.any((q) => q.prompt == 'What is Virtual Memory?'),
          isTrue,
        );
      },
    );
  });
}
