import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/decks/data/data_sources/decks_remote_data_source.dart';
import 'package:kortex/src/features/decks/data/models/deck_model.dart';
import 'package:kortex/src/features/decks/data/models/flashcard_model.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_result_entity.dart';

/// Converts failed quiz questions and weakness concepts into an actionable
/// FSRS spaced repetition practice deck for immediate remediation.
class ConvertFailedQuizToDeckUseCase {
  const ConvertFailedQuizToDeckUseCase(this._decksDataSource);

  final DecksRemoteDataSource _decksDataSource;

  Future<Either<Failure, DeckModel>> call({
    required QuizResultEntity result,
    required List<QuizQuestionEntity> questions,
    String? courseId,
    String? courseCode,
  }) async {
    try {
      final incorrectQuestions = questions.where((q) => !q.isCorrect).toList();
      final questionsToUse =
          incorrectQuestions.isNotEmpty ? incorrectQuestions : questions;

      if (questionsToUse.isEmpty && result.weaknesses.isEmpty) {
        return const Left(
          ServerFailure(
            message: 'No questions or weaknesses available to generate flashcards.',
          ),
        );
      }

      final deckId = 'quiz_deck_${DateTime.now().millisecondsSinceEpoch}';
      final resolvedCourseCode = courseCode?.trim();
      final resolvedCourseId = courseId?.trim();

      final deckTitle = resolvedCourseCode != null && resolvedCourseCode.isNotEmpty
          ? '$resolvedCourseCode CBT Practice Deck'
          : '${result.quizTitle} - Practice Deck';

      final subject = resolvedCourseCode ??
          (result.weaknesses.isNotEmpty
              ? result.weaknesses.first.subTopic
              : 'Quiz Review');

      final cards = <FlashcardModel>[];
      final now = DateTime.now();

      if (questionsToUse.isNotEmpty) {
        for (var i = 0; i < questionsToUse.length; i++) {
          final q = questionsToUse[i];
          final explanationPart = q.explanation.isNotEmpty
              ? '\n\n💡 Explanation:\n${q.explanation}'
              : '';

          cards.add(
            FlashcardModel(
              id: 'card_${deckId}_$i',
              deckId: deckId,
              front: q.prompt,
              back: '${q.correctAnswer}$explanationPart',
              sourceTopic: q.subTopic.isNotEmpty ? q.subTopic : subject,
              interval: 0,
              nextDueDate: now, // Due immediately for practice
            ),
          );
        }
      } else {
        for (var i = 0; i < result.weaknesses.length; i++) {
          final w = result.weaknesses[i];
          cards.add(
            FlashcardModel(
              id: 'card_${deckId}_$i',
              deckId: deckId,
              front: 'Key Focus: ${w.subTopic}',
              back:
                  'Target accuracy: ${(w.accuracy * 100).toInt()}% (${w.correctCount}/${w.totalQuestions} correct). Review core concepts and formulas for this topic.',
              sourceTopic: w.subTopic,
              interval: 0,
              nextDueDate: now,
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
