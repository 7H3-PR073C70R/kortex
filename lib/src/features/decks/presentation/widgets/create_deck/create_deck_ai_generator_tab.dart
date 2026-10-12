import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Form tab allowing users to prompt AI to generate a set of flashcards.
class CreateDeckAiGeneratorTab extends StatelessWidget {
  const CreateDeckAiGeneratorTab({
    required this.topicController,
    required this.cardCount,
    required this.onCardCountChanged,
    required this.isGenerating,
    required this.onGenerate,
    super.key,
  });

  final TextEditingController topicController;
  final int cardCount;
  final ValueChanged<int> onCardCountChanged;
  final bool isGenerating;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfaceSecondary.withAlpha(120)
            : colors.surfacePrimary,
        borderRadius: AppRadius.radiusPanel,
        border: Border.all(
          color: isDark
              ? colors.surfaceBorderHighlight.withAlpha(50)
              : colors.surfaceBorder.withAlpha(120),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI Flashcard Generator',
            style: typography.callout.bold.copyWith(
              color: colors.textPrimary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Enter a topic or paste notes to automatically generate active recall flashcards.',
            style: typography.footnote.regular.copyWith(
              color: colors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          AppTextField(
            controller: topicController,
            label: 'Topic or Study Notes',
            hintText:
                'e.g. Organic chemistry reaction mechanisms and IUPAC naming',
            maxLines: 3,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                'Cards:',
                style: typography.caption.bold.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(width: 10),
              ...[5, 10, 15, 20].map((count) {
                final isSelected = cardCount == count;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ShrinkableButton(
                    onTap: () {
                      AppFeedback.selection();
                      onCardCountChanged(count);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colors.primary
                            : (isDark
                                ? colors.surfaceTertiary.withAlpha(80)
                                : colors.surfaceSecondary),
                        borderRadius: AppRadius.radiusBadge,
                      ),
                      child: Text(
                        '$count',
                        style: typography.caption.bold.copyWith(
                          color: isSelected
                              ? colors.white
                              : colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              text: isGenerating ? 'Generating...' : '✨ Generate & Add Cards',
              isLoading: isGenerating,
              onPressed: isGenerating ? null : onGenerate,
            ),
          ),
        ],
      ),
    );
  }
}
