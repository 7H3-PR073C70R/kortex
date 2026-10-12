import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/latex_rich_viewer.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/quiz_audio_reader_button.dart';
import 'package:kortex/src/shared/widgets/app_multimodal_image.dart';

/// The question itself, with its figure and working, on one calm card.
class QuizPromptCard extends StatelessWidget {
  const QuizPromptCard({
    required this.question,
    super.key,
  });

  final QuizQuestionEntity question;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
        borderRadius: AppRadius.radiusPanel,
        border: Border.all(color: colors.surfaceBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: colors.black.withAlpha(isDark ? 30 : 6),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: LatexRichViewer(
                  text: question.prompt,
                  style: typography.title3.bold.copyWith(
                    color: colors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              QuizAudioReaderButton(
                questionText: question.prompt,
                options: question.options,
                size: 34,
              ),
            ],
          ),
          if (question.imageUrl != null &&
              question.imageUrl!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            AppMultimodalImage(
              imageUrl: question.imageUrl!,
              borderRadius: AppRadius.radiusCard,
            ),
          ],
          if (question.latexFormula != null &&
              question.latexFormula!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            LatexFormulaBlock(formula: question.latexFormula!),
          ],
        ],
      ),
    );
  }
}
