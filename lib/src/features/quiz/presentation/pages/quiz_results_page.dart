import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_result_entity.dart';
import 'package:kortex/src/l10n/l10n.dart';

@RoutePage()
class QuizResultsPage extends StatelessWidget {
  const QuizResultsPage({
    required this.result,
    super.key,
  });

  final QuizResultEntity result;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;

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
      bottomSheet: Container(
        padding: const EdgeInsets.all(16),
        color: colors.surfacePrimary,
        child: SafeArea(
          child: ElevatedButton.icon(
            icon: Icon(Icons.style_rounded, size: 20, color: colors.white),
            label: Text(
              l10n.practiceWeakCards,
              style: typography.body.bold.copyWith(color: colors.white),
            ),
            onPressed: () {
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: colors.primary,
              foregroundColor: colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
