import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class DeckMetadataSection extends StatelessWidget {
  const DeckMetadataSection({
    required this.selectedYear,
    required this.customYearController,
    required this.titleController,
    required this.descController,
    super.key,
  });

  final ValueNotifier<int?> selectedYear;
  final TextEditingController customYearController;
  final TextEditingController titleController;
  final TextEditingController descController;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final quickYears = [2024, 2023, 2022, 2021, 2020, 2019];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfaceSecondary.withAlpha(120)
            : colors.surfacePrimary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? colors.surfaceBorderHighlight.withAlpha(50)
              : colors.surfaceBorder.withAlpha(120),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_note_rounded, size: 18, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                'Examination Year (Required)',
                style: typography.callout.bold.copyWith(
                  color: colors.textPrimary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '*',
                style: typography.callout.bold.copyWith(
                  color: colors.error,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Calibrates standard questions to the exact testing year curriculum.',
            style: typography.footnote.regular.copyWith(
              color: colors.textSecondary,
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 12),

          // Year selection chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: quickYears.map((yr) {
              final isSelected = selectedYear.value == yr;
              return ShrinkableButton(
                onTap: () {
                  AppFeedback.light();
                  selectedYear.value = yr;
                  customYearController.text = yr.toString();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colors.primary
                        : (isDark ? colors.surfaceTertiary.withAlpha(80) : colors.surfaceSecondary),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? colors.primary
                          : (isDark ? colors.surfaceBorderHighlight.withAlpha(40) : colors.surfaceBorder),
                    ),
                  ),
                  child: Text(
                    yr.toString(),
                    style: typography.caption.bold.copyWith(
                      color: isSelected ? colors.white : colors.textPrimary,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // Custom Year Input
          AppTextField(
            controller: customYearController,
            label: 'Or Enter Custom Year',
            hintText: 'e.g. 2018 or 2025',
            keyboardType: TextInputType.number,
            onChanged: (val) {
              final parsed = int.tryParse(val.trim());
              if (parsed != null) {
                selectedYear.value = parsed;
              }
            },
          ),
          const SizedBox(height: 14),

          // Deck Title
          AppTextField(
            controller: titleController,
            label: 'Deck Title',
            hintText: 'e.g. MTH 101 Calculus Past Paper & Practice',
          ),
          const SizedBox(height: 10),

          // Deck Description (Optional)
          AppTextField(
            controller: descController,
            label: 'Description (Optional)',
            hintText: 'e.g. Verified official questions and step-by-step solutions',
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}
