import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Examination year chip selector with custom year text input fallback.
class AddQuestionYearSelector extends StatelessWidget {
  const AddQuestionYearSelector({
    required this.selectedYear,
    required this.isCustomYear,
    required this.customYearController,
    super.key,
  });

  final ValueNotifier<int> selectedYear;
  final ValueNotifier<bool> isCustomYear;
  final TextEditingController customYearController;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final recentYears = [
      DateTime.now().year,
      DateTime.now().year - 1,
      DateTime.now().year - 2,
      DateTime.now().year - 3,
      DateTime.now().year - 4,
    ];

    return ValueListenableBuilder<bool>(
      valueListenable: isCustomYear,
      builder: (context, customYear, _) {
        return ValueListenableBuilder<int>(
          valueListenable: selectedYear,
          builder: (context, currentYear, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Examination Year',
                  style: typography.caption.bold.copyWith(
                    color: colors.textPrimary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ...recentYears.map((yr) {
                        final isSelected = !customYear && currentYear == yr;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ShrinkableButton(
                            onTap: () {
                              AppFeedback.selection();
                              isCustomYear.value = false;
                              selectedYear.value = yr;
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? colors.primary
                                    : (isDark
                                        ? colors.surfaceSecondary
                                        : colors.surfaceBorder.withAlpha(50)),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.badge),
                                border: Border.all(
                                  color: isSelected
                                      ? colors.primary
                                      : colors.surfaceBorder,
                                ),
                              ),
                              child: Text(
                                '$yr',
                                style: typography.caption.bold.copyWith(
                                  color: isSelected
                                      ? colors.white
                                      : colors.textPrimary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                      ShrinkableButton(
                        onTap: () {
                          AppFeedback.selection();
                          isCustomYear.value = true;
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: customYear
                                ? colors.primary
                                : (isDark
                                    ? colors.surfaceSecondary
                                    : colors.surfaceBorder.withAlpha(50)),
                            borderRadius:
                                BorderRadius.circular(AppRadius.badge),
                            border: Border.all(
                              color: customYear
                                  ? colors.primary
                                  : colors.surfaceBorder,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.edit_calendar_rounded,
                                size: 13,
                                color: customYear
                                    ? colors.white
                                    : colors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Other',
                                style: typography.caption.bold.copyWith(
                                  color: customYear
                                      ? colors.white
                                      : colors.textPrimary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (customYear) ...[
                  const SizedBox(height: 10),
                  AppTextField(
                    controller: customYearController,
                    hintText: 'Enter past question year (e.g. 2018)',
                    keyboardType: TextInputType.number,
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}
