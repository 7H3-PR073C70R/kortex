import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_state.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Bottom modal sheet allowing students to configure and start a timed CBT practice test.
void showPastQuestionsTestConfigSheet(BuildContext context, PastQuestionsState state) {
  final colors = context.colors;
  final typography = context.typography;
  final isDark = context.isDarkMode;

  final defaultYears = state.availableYears.isNotEmpty
      ? state.availableYears
      : const [2024, 2023, 2022, 2021, 2020, 2019, 2018];

  var isRandomSelection = state.selectedYear == null;
  var selectedYear = state.selectedYear ?? (defaultYears.isNotEmpty ? defaultYears.first : 2024);
  var selectedCount = state.questions.length > 10 ? 10 : (state.questions.isEmpty ? 10 : state.questions.length);
  var isTimedMode = true;

  unawaited(
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 38,
                          height: 4,
                          decoration: BoxDecoration(
                            color: colors.surfaceBorder,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Configure ${state.selectedExam.displayName} Test',
                        style: typography.title3.bold.copyWith(
                          color: colors.textPrimary,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Practice a specific past paper year or generate a randomized mock test.',
                        style: typography.footnote.regular.copyWith(
                          color: colors.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 1. Question Source: Random vs Exam Year
                      Text(
                        'Question Selection Mode',
                        style: typography.caption.bold.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ModeOptionCard(
                              title: 'Random Mock',
                              subtitle: 'Shuffle across all years',
                              icon: Icons.shuffle_rounded,
                              isSelected: isRandomSelection,
                              onTap: () => setSheetState(() => isRandomSelection = true),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ModeOptionCard(
                              title: 'Specific Year',
                              subtitle: 'Target an official paper',
                              icon: Icons.calendar_today_rounded,
                              isSelected: !isRandomSelection,
                              onTap: () => setSheetState(() => isRandomSelection = false),
                            ),
                          ),
                        ],
                      ),

                      // If specific year selected, show year pills
                      if (!isRandomSelection) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Select Exam Year',
                          style: typography.caption.bold.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: defaultYears.map((yr) {
                              final isSelected = selectedYear == yr;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text('$yr'),
                                  selected: isSelected,
                                  onSelected: (_) => setSheetState(() => selectedYear = yr),
                                  selectedColor: colors.primary.withAlpha(isDark ? 60 : 35),
                                  backgroundColor: colors.surfaceSecondary.withAlpha(100),
                                  labelStyle: typography.caption.bold.copyWith(
                                    color: isSelected ? colors.primary : colors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // 2. Simulation Mode
                      Text(
                        'Test Simulation Mode',
                        style: typography.caption.bold.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ModeOptionCard(
                              title: 'Timed CBT Exam',
                              subtitle: 'Strict countdown & score',
                              icon: Icons.timer_outlined,
                              isSelected: isTimedMode,
                              onTap: () => setSheetState(() => isTimedMode = true),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ModeOptionCard(
                              title: 'Self-Paced Drill',
                              subtitle: 'Instant answer reveal',
                              icon: Icons.school_outlined,
                              isSelected: !isTimedMode,
                              onTap: () => setSheetState(() => isTimedMode = false),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 3. Question Count Pills
                      Text(
                        'Question Count',
                        style: typography.caption.bold.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [5, 10, 20, 40].map((count) {
                          final isSelected = selectedCount == count;

                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text('$count Qs'),
                              selected: isSelected,
                              onSelected: (_) => setSheetState(() => selectedCount = count),
                              selectedColor: colors.primary.withAlpha(isDark ? 60 : 35),
                              backgroundColor: colors.surfaceSecondary.withAlpha(100),
                              labelStyle: typography.caption.bold.copyWith(
                                color: isSelected ? colors.primary : colors.textSecondary,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 22),

                      // 4. Launch CTA
                      ShrinkableButton(
                        onTap: () {
                          Navigator.pop(bottomSheetContext);

                          // Pool questions
                          var pool = List<PastQuestionEntity>.from(state.questions);
                          if (!isRandomSelection) {
                            final filtered = pool.where((q) => q.year == selectedYear).toList();
                            if (filtered.isNotEmpty) {
                              pool = filtered;
                            }
                          } else {
                            pool.shuffle();
                          }

                          final count = selectedCount > pool.length && pool.isNotEmpty
                              ? pool.length
                              : selectedCount;

                          final testQuestions = pool
                              .take(count)
                              .map(QuizQuestionEntity.fromPastQuestion)
                              .toList();

                          final testTitle = isRandomSelection
                              ? '${state.selectedExam.displayName} Random CBT Mock'
                              : '${state.selectedExam.displayName} $selectedYear Past Paper';

                          unawaited(
                            context.router.push(
                              QuizWorkspaceRoute(
                                deckId: 'cbt_${state.selectedExam.code}_${isRandomSelection ? "random" : selectedYear}',
                                deckTitle: testTitle,
                                subject: state.selectedSubject == 'All'
                                    ? state.selectedExam.displayName
                                    : state.selectedSubject,
                                durationMinutes: isTimedMode
                                    ? (count * 1.5).round().clamp(5, 90)
                                    : null,
                                initialQuestions: testQuestions,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            color: colors.primary,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: colors.primary.withAlpha(90),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              isRandomSelection
                                  ? 'Start Random CBT ($selectedCount Questions)'
                                  : 'Start $selectedYear Past Paper ($selectedCount Qs)',
                              style: typography.callout.bold.copyWith(
                                color: colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ),
  );
}

class ModeOptionCard extends StatelessWidget {
  const ModeOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return ShrinkableButton(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.primary.withAlpha(isDark ? 40 : 20)
              : colors.surfaceSecondary.withAlpha(80),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? colors.primary
                : colors.surfaceBorder.withAlpha(80),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? colors.primary : colors.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: typography.caption.bold.copyWith(
                      color: isSelected ? colors.primary : colors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: typography.footnote.regular.copyWith(
                      color: colors.textSecondary,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
