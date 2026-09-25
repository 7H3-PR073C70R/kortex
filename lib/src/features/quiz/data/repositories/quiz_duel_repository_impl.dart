import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';
import 'package:kortex/src/features/decks/domain/repositories/decks_repository.dart';
import 'package:kortex/src/features/quiz/data/client/quiz_duel_websocket_client.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_duel_entity.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/repositories/past_questions_repository.dart';
import 'package:kortex/src/features/quiz/domain/repositories/quiz_duel_repository.dart';

/// Implementation of [QuizDuelRepository] wrapping [QuizDuelWebSocketClient].
class QuizDuelRepositoryImpl implements QuizDuelRepository {
  const QuizDuelRepositoryImpl({
    required QuizDuelWebSocketClient client,
    PastQuestionsRepository? pastQuestionsRepository,
    DecksRepository? decksRepository,
  })  : _client = client,
        _pastQuestionsRepository = pastQuestionsRepository,
        _decksRepository = decksRepository;

  final QuizDuelWebSocketClient _client;
  final PastQuestionsRepository? _pastQuestionsRepository;
  final DecksRepository? _decksRepository;

  @override
  Future<Either<Failure, QuizDuelMatch>> findOrCreateDuel({
    required String subject,
    required String examBoard,
    required String userId,
    required String displayName,
    required String avatarUrl,
    int questionCount = 10,
  }) async {
    try {
      final curatedQuestions = await _fetchCuratedQuestions(
        subject: subject,
        examBoard: examBoard,
        count: questionCount,
      );

      final match = await _client.findOrCreateDuel(
        subject: subject,
        examBoard: examBoard,
        userId: userId,
        displayName: displayName,
        avatarUrl: avatarUrl,
        questionCount: questionCount,
        customQuestions: curatedQuestions.isNotEmpty ? curatedQuestions : null,
      );
      return Right(match);
    } on Exception catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  Future<List<QuizQuestionEntity>> _fetchCuratedQuestions({
    required String subject,
    required String examBoard,
    required int count,
  }) async {
    final questions = <QuizQuestionEntity>[];
    final seenPrompts = <String>{};

    // 1. Query official CBT PastQuestionsRepository
    final pastRepo = _pastQuestionsRepository ??
        (locator.isRegistered<PastQuestionsRepository>()
            ? locator<PastQuestionsRepository>()
            : null);

    if (pastRepo != null) {
      final res = await pastRepo.getPastQuestions(
        subject: subject,
        courseCode: subject,
      );
      res.fold(
        (_) {},
        (pastList) {
          for (final q in pastList) {
            final converted = QuizQuestionEntity.fromPastQuestion(q);
            if (converted.options.length >= 2 &&
                seenPrompts.add(converted.prompt)) {
              questions.add(converted);
            }
          }
        },
      );
    }

    // 2. Query DecksRepository if past questions are insufficient
    if (questions.length < count) {
      final decksRepo = _decksRepository ??
          (locator.isRegistered<DecksRepository>()
              ? locator<DecksRepository>()
              : null);

      if (decksRepo != null) {
        final res = await decksRepo.getUserDecks();
        final decks = res.fold(
          (_) => <DeckEntity>[],
          (d) => d,
        );

        final subClean = subject.trim().toLowerCase();
        final matching = decks.where(
          (d) =>
              d.subject.trim().toLowerCase().contains(subClean) ||
              d.title.trim().toLowerCase().contains(subClean),
        );

        for (final deck in matching) {
          final cardsRes = await decksRepo.getDeckCards(deck.id);
          final cards = cardsRes.fold(
            (_) => <FlashcardEntity>[],
            (c) => c,
          );

          for (final card in cards) {
            if (card.front.isNotEmpty && card.back.isNotEmpty) {
              if (seenPrompts.add(card.front)) {
                final options = [
                  card.back,
                  'Option A',
                  'Option B',
                  'Option C',
                ]..shuffle();
                questions.add(
                  QuizQuestionEntity(
                    id: card.id,
                    prompt: card.front,
                    type: QuizQuestionType.multipleChoice,
                    options: options,
                    correctAnswer: card.back,
                    explanation:
                        'Correct answer from deck "${deck.title}".',
                    subTopic: deck.title,
                  ),
                );
              }
            }
          }
        }
      }
    }

    questions.shuffle();
    return questions.take(count.clamp(1, questions.isEmpty ? 1 : questions.length)).toList();
  }

  @override
  Stream<QuizDuelMatch> streamDuel(String duelId) {
    return _client.streamDuel(duelId);
  }

  @override
  Future<Either<Failure, void>> submitDuelAnswer({
    required String duelId,
    required String userId,
    required int questionIndex,
    required int optionIndex,
    required int responseTimeMs,
  }) async {
    try {
      await _client.submitDuelAnswer(
        duelId: duelId,
        userId: userId,
        questionIndex: questionIndex,
        optionIndex: optionIndex,
        responseTimeMs: responseTimeMs,
      );
      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> sendDuelEmote({
    required String duelId,
    required String userId,
    required String emote,
  }) async {
    try {
      await _client.sendDuelEmote(
        duelId: duelId,
        userId: userId,
        emote: emote,
      );
      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> leaveDuel({
    required String duelId,
    required String userId,
  }) async {
    try {
      await _client.leaveDuel(duelId: duelId, userId: userId);
      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> matchWithAiImmediately({
    required String duelId,
  }) async {
    try {
      _client.simulateMatchFoundWithAi(duelId);
      return const Right(null);
    } on Exception catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
