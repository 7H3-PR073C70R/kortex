import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_bloc.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_event.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_state.dart';

class SubjectFilterBar extends StatelessWidget {
  const SubjectFilterBar({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return BlocBuilder<PastQuestionsBloc, PastQuestionsState>(
      builder: (context, state) {
        final subjects = ['All', ...state.availableSubjects];

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Row(
            children: subjects.map((subj) {
              final isSelected = state.selectedSubject == subj;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  showCheckmark: false,
                  label: Text(subj),
                  selected: isSelected,
                  onSelected: (_) {
                    unawaited(HapticFeedback.selectionClick());
                    context.read<PastQuestionsBloc>().add(
                          ChangeSubjectEvent(subj),
                        );
                  },
                  selectedColor: colors.primary,
                  backgroundColor: isDark
                      ? colors.surfaceSecondary.withAlpha(100)
                      : colors.surfaceSecondary.withAlpha(60),
                  labelStyle: typography.caption.bold.copyWith(
                    color: isSelected ? colors.white : colors.textSecondary,
                    fontSize: 12,
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? colors.primary
                        : colors.surfaceBorder.withAlpha(80),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class YearFilterButton extends StatelessWidget {
  const YearFilterButton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return BlocBuilder<PastQuestionsBloc, PastQuestionsState>(
      builder: (context, state) {
        final defaultYears = state.availableYears.isNotEmpty
            ? state.availableYears
            : const [2024, 2023, 2022, 2021, 2020, 2019, 2018];
        final isSpecific = state.selectedYear != null;

        return PopupMenuButton<int?>(
          color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: colors.surfaceBorder.withAlpha(isDark ? 80 : 120),
            ),
          ),
          onSelected: (yr) {
            unawaited(HapticFeedback.selectionClick());
            context.read<PastQuestionsBloc>().add(ChangeYearEvent(yr));
          },
          itemBuilder: (context) {
            return [
              const PopupMenuItem<int?>(
                child: Row(
                  children: [
                    Icon(
                      Icons.shuffle_rounded,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Text('All Years (Random)'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              ...defaultYears.map(
                (yr) => PopupMenuItem<int?>(
                  value: yr,
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 14,
                        color: state.selectedYear == yr
                            ? colors.primary
                            : colors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$yr Exam Paper',
                        style: typography.callout.medium.copyWith(
                          color: state.selectedYear == yr
                              ? colors.primary
                              : colors.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ];
          },
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isSpecific
                  ? colors.primary.withAlpha(isDark ? 45 : 20)
                  : (isDark
                      ? colors.surfaceSecondary.withAlpha(120)
                      : colors.surfacePrimary),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSpecific
                    ? colors.primary
                    : colors.surfaceBorder.withAlpha(isDark ? 80 : 120),
                width: isSpecific ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSpecific
                      ? Icons.calendar_today_rounded
                      : Icons.tune_rounded,
                  size: 15,
                  color: isSpecific ? colors.primary : colors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  isSpecific ? '${state.selectedYear}' : 'Year: All',
                  style: typography.caption.bold.copyWith(
                    color: isSpecific ? colors.primary : colors.textPrimary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 3),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: isSpecific ? colors.primary : colors.textSecondary,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
