import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/quiz_audio_reader_button.dart';

/// Top header row of `PastQuestionCard` displaying subject/year/topic badges,
/// text-to-speech audio reader trigger, and bookmark toggle.
class QuestionHeaderBadges extends StatelessWidget {
  const QuestionHeaderBadges({
    required this.question,
    this.onBookmarkToggle,
    super.key,
  });

  final PastQuestionEntity question;
  final VoidCallback? onBookmarkToggle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (question.isUserAdded)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withAlpha(isDark ? 45 : 20),
                    borderRadius: BorderRadius.circular(AppRadius.badge),
                    border: Border.all(
                      color: colors.primary.withAlpha(70),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.person_outline_rounded,
                        size: 11,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'User Added',
                        style: typography.caption.bold.copyWith(
                          color: colors.primary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              if (question.isTheory)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.syllabotAccent.withAlpha(
                      isDark ? 45 : 20,
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.badge),
                    border: Border.all(
                      color: colors.syllabotAccent.withAlpha(70),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    'Theory / Essay',
                    style: typography.caption.bold.copyWith(
                      color: colors.syllabotAccent,
                      fontSize: 10,
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colors.primary.withAlpha(isDark ? 40 : 20),
                  borderRadius: BorderRadius.circular(AppRadius.badge),
                ),
                child: Text(
                  '${question.subject} • ${question.year} • Q${question.questionNumber}',
                  style: typography.caption.bold.copyWith(
                    color: colors.primary,
                    fontSize: 10.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(AppRadius.badge),
                ),
                child: Text(
                  question.topic,
                  style: typography.caption.medium.copyWith(
                    color: colors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            QuizAudioReaderButton(
              questionText: question.prompt,
              options: question.options,
              size: 32,
              iconSize: 16,
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(
                question.isBookmarked
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_outline_rounded,
                color: question.isBookmarked
                    ? colors.syllabotAccent
                    : colors.textSecondary,
                size: 20,
              ),
              onPressed: onBookmarkToggle,
            ),
          ],
        ),
      ],
    );
  }
}
