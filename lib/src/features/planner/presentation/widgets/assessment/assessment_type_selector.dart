import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/planner/domain/entities/assessment_type.dart';
import 'package:kortex/src/l10n/l10n.dart';

/// Horizontal chip selector for academic assessment types.
class AssessmentTypeSelector extends StatelessWidget {
  const AssessmentTypeSelector({
    required this.selectedType,
    required this.onTypeChanged,
    super.key,
  });

  final AssessmentType selectedType;
  final ValueChanged<AssessmentType> onTypeChanged;

  static const List<AssessmentType> availableTypes = [
    AssessmentType.quiz,
    AssessmentType.classTest,
    AssessmentType.midterm,
    AssessmentType.finalExam,
    AssessmentType.mockExam,
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.assessmentTypeLabel,
          style: typography.caption.bold.copyWith(
            color: colors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: availableTypes.map((type) {
              final isSelected = selectedType == type;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () => onTypeChanged(type),
                  borderRadius: AppRadius.radiusBadge,
                  child: AnimatedContainer(
                    duration: AppMotion.snappy,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colors.primary
                          : (isDark
                              ? colors.surfacePrimary.withAlpha(120)
                              : colors.surfaceSecondary.withAlpha(90)),
                      borderRadius: AppRadius.radiusBadge,
                      border: Border.all(
                        color: isSelected
                            ? colors.primary
                            : colors.surfaceBorder.withAlpha(80),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          type.icon,
                          size: 15,
                          color: isSelected
                              ? colors.white
                              : colors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          type.displayName,
                          style: typography.caption.bold.copyWith(
                            color: isSelected
                                ? colors.white
                                : colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
