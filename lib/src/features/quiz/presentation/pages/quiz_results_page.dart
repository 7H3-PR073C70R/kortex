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
    final theme = context.theme;
    final l10n = context.l10n;

    final score = result.scorePercent;
    final isPassed = score >= 70;
    final gradeColor = isPassed ? Colors.greenAccent : Colors.amberAccent;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          result.quizTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
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
                  theme.colorScheme.surface.withValues(alpha: 0.8),
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
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${result.correctAnswers} of ${result.totalQuestions} '
                  'questions correct',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 2. Weakness Breakdown Section Header
          Text(
            l10n.quizTopicWeakness,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),

          // 3. Topic Weakness Tiles
          if (result.weaknesses.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Comprehensive mastery across all topics!',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.greenAccent,
                ),
              ),
            )
          else
            ...result.weaknesses.map((weakness) {
              final acc = (weakness.accuracy * 100).toInt();
              final isWeak = weakness.isWeak;
              final badgeColor = isWeak ? Colors.redAccent : Colors.greenAccent;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isWeak
                        ? Colors.redAccent.withValues(alpha: 0.3)
                        : Colors.white12,
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
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${weakness.correctCount} / ${weakness.totalQuestions} Correct',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white54,
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
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
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
        color: theme.colorScheme.surface,
        child: SafeArea(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.style_rounded, size: 20),
            label: Text(l10n.practiceWeakCards),
            onPressed: () {
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.black,
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
