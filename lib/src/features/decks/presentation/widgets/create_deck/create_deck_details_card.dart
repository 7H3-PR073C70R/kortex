import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';

/// Card containing title, description, and course badge for a new study deck.
class CreateDeckDetailsCard extends StatelessWidget {
  const CreateDeckDetailsCard({
    required this.titleController,
    required this.descController,
    required this.courseCode,
    super.key,
  });

  final TextEditingController titleController;
  final TextEditingController descController;
  final String courseCode;

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
          Row(
            children: [
              Icon(
                Icons.style_rounded,
                size: 18,
                color: colors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Deck Details',
                style: typography.callout.bold.copyWith(
                  color: colors.textPrimary,
                  fontSize: 14.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: colors.primary.withAlpha(
                    isDark ? 40 : 20,
                  ),
                  borderRadius: AppRadius.radiusBadge,
                ),
                child: Text(
                  courseCode,
                  style: typography.caption.bold.copyWith(
                    color: colors.primary,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AppTextField(
            controller: titleController,
            label: 'Deck Name',
            hintText: 'e.g. $courseCode Flashcards',
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: descController,
            label: 'Description (Optional)',
            hintText: 'e.g. Core concepts & formulas for quick recall',
          ),
        ],
      ),
    );
  }
}
