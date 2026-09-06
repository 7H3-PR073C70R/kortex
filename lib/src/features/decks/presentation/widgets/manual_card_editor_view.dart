import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/latex_rich_viewer.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class ManualCardEditorView extends StatelessWidget {
  const ManualCardEditorView({
    required this.frontController,
    required this.backController,
    required this.optionAController,
    required this.optionBController,
    required this.optionCController,
    required this.optionDController,
    required this.manualCorrectOption,
    required this.isMultipleChoice,
    required this.addedCards,
    required this.onAddCard,
    required this.onRemoveCard,
    required this.isSubmitting,
    required this.onSubmit,
    super.key,
  });

  final TextEditingController frontController;
  final TextEditingController backController;
  final TextEditingController optionAController;
  final TextEditingController optionBController;
  final TextEditingController optionCController;
  final TextEditingController optionDController;
  final ValueNotifier<String> manualCorrectOption;
  final ValueNotifier<bool> isMultipleChoice;
  final List<Map<String, dynamic>> addedCards;
  final VoidCallback onAddCard;
  final ValueChanged<int> onRemoveCard;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Add Flashcard / Question',
              style: typography.callout.bold.copyWith(
                color: colors.textPrimary,
                fontSize: 15,
              ),
            ),
            Row(
              children: [
                Text(
                  'Multiple Choice (MCQ)',
                  style: typography.caption.regular.copyWith(
                    color: colors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                Switch.adaptive(
                  value: isMultipleChoice.value,
                  activeThumbColor: colors.primary,
                  onChanged: (val) {
                    AppFeedback.light();
                    isMultipleChoice.value = val;
                  },
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Front (Prompt / Question)
        AppTextField(
          controller: frontController,
          label: 'Question Prompt / Front',
          hintText: r'e.g. What is the derivative of \( f(x) = x^3 \)?',
          maxLines: 3,
        ),
        const SizedBox(height: 12),

        // Multiple Choice Options (If enabled)
        if (isMultipleChoice.value) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? colors.surfaceSecondary.withAlpha(100) : colors.surfaceSecondary,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.surfaceBorder.withAlpha(80)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Options & Correct Answer',
                  style: typography.caption.bold.copyWith(
                    color: colors.textPrimary,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 10),
                AppTextField(controller: optionAController, label: 'Option A', hintText: 'Option A text'),
                const SizedBox(height: 8),
                AppTextField(controller: optionBController, label: 'Option B', hintText: 'Option B text'),
                const SizedBox(height: 8),
                AppTextField(controller: optionCController, label: 'Option C', hintText: 'Option C text'),
                const SizedBox(height: 8),
                AppTextField(controller: optionDController, label: 'Option D', hintText: 'Option D text'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      'Correct Option:',
                      style: typography.caption.bold.copyWith(
                        color: colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 10),
                    ...['A', 'B', 'C', 'D'].map((opt) {
                      final isSelected = manualCorrectOption.value == opt;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ShrinkableButton(
                          onTap: () {
                            AppFeedback.light();
                            manualCorrectOption.value = opt;
                          },
                          child: Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected ? colors.primary : colors.surfaceTertiary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? colors.primary : colors.surfaceBorder,
                              ),
                            ),
                            child: Text(
                              opt,
                              style: typography.caption.bold.copyWith(
                                color: isSelected ? colors.white : colors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Back (Answer & Solution)
        AppTextField(
          controller: backController,
          label: 'Solution / Answer / Back',
          hintText: r'e.g. \( 3x^2 \). Power rule states d/dx[x^n] = n*x^(n-1).',
          maxLines: 3,
        ),
        const SizedBox(height: 12),

        // Add Card Button
        Align(
          alignment: Alignment.centerRight,
          child: ShrinkableButton(
            onTap: onAddCard,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: colors.primary.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.primary.withAlpha(60)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, size: 16, color: colors.primary),
                  const SizedBox(width: 4),
                  Text(
                    'Add Card to Deck',
                    style: typography.caption.bold.copyWith(
                      color: colors.primary,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Added Cards Preview
        if (addedCards.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Added Cards (${addedCards.length})',
                style: typography.callout.bold.copyWith(
                  color: colors.textPrimary,
                  fontSize: 14.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: addedCards.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              final card = addedCards[idx];
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? colors.surfaceSecondary.withAlpha(100) : colors.surfacePrimary,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.surfaceBorder.withAlpha(80)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: colors.primary.withAlpha(25),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${idx + 1}',
                        style: typography.caption.bold.copyWith(
                          color: colors.primary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LatexRichViewer(
                            text: card['front'] as String,
                            style: typography.caption.bold.copyWith(
                              color: colors.textPrimary,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          LatexRichViewer(
                            text: card['back'] as String,
                            style: typography.footnote.regular.copyWith(
                              color: colors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline_rounded, size: 18, color: colors.error),
                      onPressed: () => onRemoveCard(idx),
                      tooltip: 'Remove Card',
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),
        ],

        // Submit Manual Deck Button
        AppButton(
          text: isSubmitting ? 'Creating Study Deck...' : 'Save Deck (${addedCards.length} Cards)',
          isLoading: isSubmitting,
          onPressed: isSubmitting ? null : onSubmit,
          prefixIcon: const Icon(Icons.check_circle_outline_rounded, size: 18),
        ),
      ],
    );
  }
}
