import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';

/// Form tab for typing and adding manual flashcard question/answer pairs.
class CreateDeckManualEntryTab extends StatelessWidget {
  const CreateDeckManualEntryTab({
    required this.frontController,
    required this.backController,
    required this.onAddCard,
    super.key,
  });

  final TextEditingController frontController;
  final TextEditingController backController;
  final VoidCallback onAddCard;

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
            'Add Card to Deck',
            style: typography.callout.bold.copyWith(
              color: colors.textPrimary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: frontController,
            label: 'Front (Question / Term / Concept)',
            hintText: "e.g. State Le Chatelier's principle",
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: backController,
            label: 'Back (Answer / Definition / Formula)',
            hintText:
                'e.g. When a system at equilibrium is subjected to change, it adjusts to counteract the change.',
            maxLines: 3,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              text: '+ Add Flashcard',
              onPressed: onAddCard,
              prefixIcon: const Icon(
                Icons.add_rounded,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
