import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/core/utils/uuid_utils.dart';
import 'package:kortex/src/features/decks/data/data_sources/decks_remote_data_source.dart';
import 'package:kortex/src/features/decks/data/models/deck_model.dart';
import 'package:kortex/src/features/decks/data/models/flashcard_model.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';
import 'package:kortex/src/features/decks/domain/services/card_similarity_checker.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_result_entity.dart';

/// Converts failed quiz questions and weakness concepts into an actionable
/// FSRS spaced repetition practice deck for immediate remediation.
class ConvertFailedQuizToDeckUseCase {
  const ConvertFailedQuizToDeckUseCase(
    this._decksDataSource, {
    this.similarityChecker = const CardSimilarityChecker(),
  });

  final DecksRemoteDataSource _decksDataSource;
  final CardSimilarityChecker similarityChecker;

  Future<Either<Failure, DeckModel>> call({
    required QuizResultEntity result,
    required List<QuizQuestionEntity> questions,
    String? courseId,
    String? courseCode,
    List<FlashcardEntity>? existingDeckCards,
  }) async {
    try {
      final incorrectQuestions = questions.where((q) => !q.isCorrect).toList();
      final questionsToUse = incorrectQuestions.isNotEmpty
          ? incorrectQuestions
          : questions;

      if (questionsToUse.isEmpty && result.weaknesses.isEmpty) {
        return const Left(
          ServerFailure(
            message:
                'No questions or weaknesses available to generate flashcards.',
          ),
        );
      }

      final deckId = UuidUtils.generate();
      final resolvedCourseCode = courseCode?.trim();
      final resolvedCourseId = courseId?.trim();

      final deckTitle =
          resolvedCourseCode != null && resolvedCourseCode.isNotEmpty
          ? '$resolvedCourseCode CBT Practice Deck'
          : '${result.quizTitle} - Practice Deck';

      final subject =
          resolvedCourseCode ??
          (result.weaknesses.isNotEmpty
              ? result.weaknesses.first.subTopic
              : 'Quiz Review');

      final cards = <FlashcardModel>[];
      final createdEntities = <FlashcardEntity>[...?existingDeckCards];
      final now = DateTime.now();

      if (questionsToUse.isNotEmpty) {
        for (var i = 0; i < questionsToUse.length; i++) {
          final q = questionsToUse[i];
          
          // Deduplication check using CardSimilarityChecker
          final duplicate = similarityChecker.findDuplicate(
            question: q.prompt,
            existingCards: createdEntities,
            threshold: 0.85,
          );

          if (duplicate != null) {
            // Skip adding duplicate card if a nearly identical card already exists
            continue;
          }

          final explanationPart = q.explanation.isNotEmpty
              ? '\n\n💡 Explanation:\n${q.explanation}'
              : '';

          final cardId = UuidUtils.generate();
          final card = FlashcardModel(
            id: cardId,
            deckId: deckId,
            front: q.prompt,
            back: '${q.correctAnswer}$explanationPart',
            sourceTopic: q.subTopic.isNotEmpty ? q.subTopic : subject,
            interval: 0,
            nextDueDate: now, // Due immediately for practice
          );

          cards.add(card);
          createdEntities.add(
            FlashcardEntity(
              id: cardId,
              deckId: deckId,
              front: q.prompt,
              back: '${q.correctAnswer}$explanationPart',
            ),
          );
        }
      } else {
        for (var i = 0; i < result.weaknesses.length; i++) {
          final w = result.weaknesses[i];
          final frontText = 'Key Focus: ${w.subTopic}';

          final duplicate = similarityChecker.findDuplicate(
            question: frontText,
            existingCards: createdEntities,
            threshold: 0.85,
          );

          if (duplicate != null) continue;

          final cardId = UuidUtils.generate();
          final card = FlashcardModel(
            id: cardId,
            deckId: deckId,
            front: frontText,
            back:
                'Target accuracy: ${(w.accuracy * 100).toInt()}% (${w.correctCount}/${w.totalQuestions} correct). Review core concepts and formulas for this topic.',
            sourceTopic: w.subTopic,
            interval: 0,
            nextDueDate: now,
          );

          cards.add(card);
          createdEntities.add(
            FlashcardEntity(
              id: cardId,
              deckId: deckId,
              front: frontText,
              back: card.back,
            ),
          );
        }
      }

      final deck = DeckModel(
        id: deckId,
        title: deckTitle,
        subject: subject,
        totalCards: cards.length,
        dueCards: cards.length,
        masteryRate: 0,
        category: 'Quiz Review',
        description: 'Practice flashcards generated from CBT test session.',
        cards: cards,
        courseId: resolvedCourseId,
        courseCode: resolvedCourseCode,
      );

      await _decksDataSource.saveGeneratedDeck(
        deck: deck,
        cards: cards,
      );

      return Right(deck);
    } on Exception catch (e) {
      return Left(
        ServerFailure(
          message: 'Failed to convert quiz results to flashcard deck: $e',
        ),
      );
    }
  }
}
