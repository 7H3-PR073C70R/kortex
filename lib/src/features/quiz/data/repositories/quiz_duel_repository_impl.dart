import 'dart:math';

import 'package:dio/dio.dart';
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
    Dio? dio,
  })  : _client = client,
        _pastQuestionsRepository = pastQuestionsRepository,
        _decksRepository = decksRepository,
        _dio = dio;

  final QuizDuelWebSocketClient _client;
  final PastQuestionsRepository? _pastQuestionsRepository;
  final DecksRepository? _decksRepository;
  final Dio? _dio;


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

        final allCardsInSubject = <FlashcardEntity>[];
        for (final deck in matching) {
          final cardsRes = await decksRepo.getDeckCards(deck.id);
          final cards = cardsRes.fold(
            (_) => <FlashcardEntity>[],
            (c) => c,
          );
          allCardsInSubject.addAll(cards);
        }

        final distractorPool = allCardsInSubject
            .map((c) => c.back.trim())
            .where((b) => b.isNotEmpty)
            .toSet();

        for (final card in allCardsInSubject) {
          if (card.front.isNotEmpty && card.back.isNotEmpty) {
            if (seenPrompts.add(card.front)) {
              final correct = card.back.trim();
              final potentialDistractors = distractorPool
                  .where((d) => d.toLowerCase() != correct.toLowerCase())
                  .toList()
                ..shuffle();

              final options = <String>[correct];
              for (final d in potentialDistractors) {
                if (options.length >= 4) break;
                if (!options.contains(d)) {
                  options.add(d);
                }
              }

              final fallbackPool = _getSubjectFallbackDistractors(subject)
                ..shuffle();
              for (final fallback in fallbackPool) {
                if (options.length >= 4) break;
                if (!options.contains(fallback) &&
                    fallback.toLowerCase() != correct.toLowerCase()) {
                  options.add(fallback);
                }
              }

              options.shuffle();

              questions.add(
                QuizQuestionEntity(
                  id: card.id,
                  prompt: card.front,
                  type: QuizQuestionType.multipleChoice,
                  options: options,
                  correctAnswer: correct,
                  explanation:
                      'Correct answer from deck study material.',
                  subTopic: subject,
                ),
              );
            }
          }
        }
      }
    }

    questions.shuffle();
    return questions
        .take(count.clamp(1, questions.isEmpty ? 1 : questions.length))
        .toList();
  }

  static List<String> _getSubjectFallbackDistractors(String subject) {
    final clean = subject.trim().toLowerCase();
    if (clean.contains('math') || clean.contains('calc')) {
      return ['0', '1', '-1', '2', '1/2', 'Infinity', 'Undefined'];
    } else if (clean.contains('phys') || clean.contains('chem')) {
      return ['Constant', 'Zero', 'Inversely Proportional', 'Directly Proportional', 'Conserved'];
    } else if (clean.contains('eng') || clean.contains('lit')) {
      return ['Metaphor', 'Simile', 'Irony', 'Oxymoron', 'Hyperbole', 'Personification'];
    }
    return ['None of the above', 'Both A and B', 'Cannot be determined', 'Insufficient data'];
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

  @override
  Future<Either<Failure, Map<String, dynamic>>> recordDuelOutcome(
    QuizDuelMatch match,
  ) async {
    try {
      final dio = _dio ??
          (locator.isRegistered<Dio>() ? locator<Dio>() : null);
      if (dio == null) return const Right({});

      final p1Id = match.player1.userId;
      final p2Id = match.player2?.userId;
      final uuidRegex = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      );

      final validP1 = uuidRegex.hasMatch(p1Id) ? p1Id : null;
      final validP2 = (p2Id != null && uuidRegex.hasMatch(p2Id)) ? p2Id : null;
      final validWinner = (match.winnerUserId != null &&
              uuidRegex.hasMatch(match.winnerUserId!))
          ? match.winnerUserId
          : null;
      final validForfeit = (match.forfeitUserId != null &&
              uuidRegex.hasMatch(match.forfeitUserId!))
          ? match.forfeitUserId
          : null;

      try {
        final response = await dio.post<Map<String, dynamic>>(
          '/rest/v1/rpc/fn_process_quiz_duel_outcome',
          data: {
            'p_duel_id': match.duelId,
            'p_player1_id': validP1,
            'p_player2_id': validP2,
            'p_player1_score': match.player1.score,
            'p_player2_score': match.player2?.score ?? 0,
            'p_winner_id': validWinner,
            'p_is_draw': match.isDraw,
            'p_is_forfeit': match.forfeitUserId != null,
            'p_forfeit_user_id': validForfeit,
          },
        );

        final data = response.data ?? <String, dynamic>{};
        return Right(data);
      } on DioException catch (e) {
        return Left(
          ServerFailure(
            message:
                'RPC fn_process_quiz_duel_outcome not available (${e.response?.statusCode}): ${e.message}',
          ),
        );
      }
    } on Exception catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getEloLeaderboard({
    String? subject,
    int limit = 20,
  }) async {
    try {
      final dio = _dio ??
          (locator.isRegistered<Dio>() ? locator<Dio>() : null);
      if (dio == null) return const Right([]);

      final response = await dio.get<List<dynamic>>(
        '/rest/v1/user_profiles',
        queryParameters: {
          'select': 'id,display_name,avatar_url,elo_rating,department,level',
          'order': 'elo_rating.desc',
          'limit': limit,
        },
      );

      final list = (response.data ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
      return Right(list);
    } on Exception catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, QuizDuelMatch>> createAsyncChallenge({
    required String subject,
    required String examBoard,
    required String userId,
    required String targetUserId,
    required String displayName,
    required String avatarUrl,
  }) async {
    try {
      final questions = await _fetchCuratedQuestions(
        subject: subject,
        examBoard: examBoard,
        count: 10,
      );

      final duelId =
          'async_${DateTime.now().millisecondsSinceEpoch}_${userId.substring(0, min(6, userId.length))}';

      final match = QuizDuelMatch(
        duelId: duelId,
        subject: subject,
        examBoard: examBoard,
        questions: questions,
        player1: QuizDuelParticipant(
          userId: userId,
          displayName: displayName,
          avatarUrl: avatarUrl,
          isReady: true,
          eloRating: 1250,
        ),
        createdAt: DateTime.now(),
      );

      final dio = _dio ??
          (locator.isRegistered<Dio>() ? locator<Dio>() : null);
      if (dio != null) {
        await dio.post<void>(
          '/rest/v1/quiz_duels',
          data: {
            'duel_id': duelId,
            'subject': subject,
            'exam_board': examBoard,
            'player1_id': userId,
            'player2_id': targetUserId,
            'player1_score': 0,
            'player2_score': 0,
            'questions_snapshot': questions
                .map(
                  (q) => {
                    'id': q.id,
                    'prompt': q.prompt,
                    'options': q.options,
                    'correctAnswer': q.correctAnswer,
                    'explanation': q.explanation,
                  },
                )
                .toList(),
          },
        );
      }

      return Right(match);
    } on Exception catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<QuizDuelMatch>>> getPendingAsyncChallenges(
    String userId,
  ) async {
    try {
      final dio = _dio ??
          (locator.isRegistered<Dio>() ? locator<Dio>() : null);
      if (dio == null) return const Right([]);

      final response = await dio.get<List<dynamic>>(
        '/rest/v1/quiz_duels',
        queryParameters: {
          'player2_id': 'eq.$userId',
          'winner_user_id': 'is.null',
          'is_draw': 'eq.false',
          'order': 'created_at.desc',
          'limit': 10,
        },
      );

      final rawList = (response.data ?? []).whereType<Map<String, dynamic>>();
      final matches = <QuizDuelMatch>[];

      for (final row in rawList) {
        final duelId = row['duel_id'] as String? ?? '';
        final subject = row['subject'] as String? ?? 'General';
        final examBoard = row['exam_board'] as String? ?? 'WAEC';
        final p1Id = row['player1_id'] as String? ?? '';

        matches.add(
          QuizDuelMatch(
            duelId: duelId,
            subject: subject,
            examBoard: examBoard,
            player1: QuizDuelParticipant(
              userId: p1Id,
              displayName: 'Challenger',
              avatarUrl: '',
            ),
            player2: QuizDuelParticipant(
              userId: userId,
              displayName: 'You',
              avatarUrl: '',
            ),
            questions: const [],
          ),
        );
      }

      return Right(matches);
    } on Exception catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
