import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/decks/data/data_sources/decks_remote_data_source.dart';
import 'package:kortex/src/features/decks/data/models/deck_model.dart';
import 'package:kortex/src/features/decks/data/models/flashcard_model.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_event.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_result_entity.dart';
import 'package:kortex/src/l10n/l10n.dart';

@RoutePage()
class QuizResultsPage extends StatelessWidget {
  const QuizResultsPage({
    required this.result,
    this.questions = const [],
    super.key,
  });

  final QuizResultEntity result;
  final List<QuizQuestionEntity> questions;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final score = result.scorePercent;
    final isPassed = score >= 70;
    final gradeColor = isPassed ? colors.success : colors.warning;

    return Scaffold(
      backgroundColor: colors.transparent,
      appBar: AppBar(
        backgroundColor: colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          result.quizTitle,
          style: typography.title3.bold.copyWith(
            color: colors.white,
          ),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        children: [
          // 1. Grade Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  gradeColor.withValues(alpha: 0.2),
                  colors.surfacePrimary.withValues(alpha: 0.8),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: gradeColor.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  isPassed
                      ? Icons.emoji_events_rounded
                      : Icons.insights_rounded,
                  size: 54,
                  color: gradeColor,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.quizScoreLabel(score),
                  style: typography.largeTitle.bold.copyWith(
                    color: colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${result.correctAnswers} of ${result.totalQuestions} '
                  'questions correct',
                  style: typography.body.regular.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 2. Weakness Breakdown Section Header
          Text(
            l10n.quizTopicWeakness,
            style: typography.title3.bold.copyWith(
              color: colors.white,
            ),
          ),
          const SizedBox(height: 12),

          // 3. Topic Weakness Tiles
          if (result.weaknesses.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Comprehensive mastery across all topics!',
                style: typography.body.regular.copyWith(
                  color: colors.success,
                ),
              ),
            )
          else
            ...result.weaknesses.map((weakness) {
              final acc = (weakness.accuracy * 100).toInt();
              final isWeak = weakness.isWeak;
              final badgeColor = isWeak ? colors.error : colors.success;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: colors.surfacePrimary.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isWeak
                        ? colors.error.withValues(alpha: 0.3)
                        : colors.surfaceBorder,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            weakness.subTopic,
                            style: typography.body.bold.copyWith(
                              color: colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${weakness.correctCount} / ${weakness.totalQuestions} Correct',
                            style: typography.caption.regular.copyWith(
                              color: colors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: badgeColor.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        '$acc%',
                        style: typography.caption.bold.copyWith(
                          color: badgeColor,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
      bottomNavigationBar: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: BoxDecoration(
          color: colors.surfacePrimary,
          border: Border(
            top: BorderSide(
              color: colors.surfaceBorder.withAlpha(isDark ? 60 : 120),
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              icon: Icon(Icons.style_rounded, size: 20, color: colors.white),
              label: Text(
                l10n.practiceWeakCards,
                style: typography.callout.bold.copyWith(color: colors.white),
              ),
              onPressed: () => _handlePracticeWeakFlashcards(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handlePracticeWeakFlashcards(BuildContext context) async {
    unawaited(HapticFeedback.lightImpact());

    // Prioritize questions that were answered incorrectly; fallback to all questions
    final incorrectQuestions = questions.where((q) => !q.isCorrect).toList();
    final questionsToUse = incorrectQuestions.isNotEmpty ? incorrectQuestions : questions;

    if (questionsToUse.isEmpty && result.weaknesses.isEmpty) {
      context.showSnackBar(
        message: 'No questions available to generate flashcards.',
      );
      return;
    }

    final deckId = 'quiz_deck_${DateTime.now().millisecondsSinceEpoch}';
    final deckTitle = '${result.quizTitle} - Practice Deck';
    final subject = result.weaknesses.isNotEmpty
        ? result.weaknesses.first.subTopic
        : 'Quiz Review';

    final cards = <FlashcardModel>[];

    if (questionsToUse.isNotEmpty) {
      for (var i = 0; i < questionsToUse.length; i++) {
        final q = questionsToUse[i];
        final explanationPart =
            q.explanation.isNotEmpty ? '\n\n💡 Explanation:\n${q.explanation}' : '';

        cards.add(
          FlashcardModel(
            id: 'card_${deckId}_$i',
            deckId: deckId,
            front: q.prompt,
            back: '${q.correctAnswer}$explanationPart',
            sourceTopic: q.subTopic,
            nextDueDate: DateTime.now().add(const Duration(days: 1)),
          ),
        );
      }
    } else {
      // Fallback from weaknesses
      for (var i = 0; i < result.weaknesses.length; i++) {
        final w = result.weaknesses[i];
        cards.add(
          FlashcardModel(
            id: 'card_${deckId}_$i',
            deckId: deckId,
            front: 'Key Focus: ${w.subTopic}',
            back: 'Target accuracy: ${(w.accuracy * 100).toInt()}% (${w.correctCount}/${w.totalQuestions} correct). Review core concepts and formulas for this topic.',
            sourceTopic: w.subTopic,
            nextDueDate: DateTime.now().add(const Duration(days: 1)),
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
    );

    // Save to DecksRemoteDataSource
    if (locator.isRegistered<DecksRemoteDataSource>()) {
      await locator<DecksRemoteDataSource>().saveGeneratedDeck(
        deck: deck,
        cards: cards,
      );
    }

    // Refresh DecksBloc
    if (locator.isRegistered<DecksBloc>()) {
      locator<DecksBloc>().add(const DecksRefreshed());
    }

    if (context.mounted) {
      context.showSnackBar(
        message: 'Generated ${cards.length} practice flashcards!',
        type: SnackBarType.success,
      );
      unawaited(
        context.router.replace(
          StudySessionRoute(deckId: deckId),
        ),
      );
    }
  }
}
