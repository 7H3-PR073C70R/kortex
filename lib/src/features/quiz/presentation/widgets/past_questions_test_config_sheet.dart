import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_state.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_session_state.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/quiz_shell.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Bottom modal sheet allowing students to configure and start a timed CBT practice test.
void showPastQuestionsTestConfigSheet(
  BuildContext context,
  PastQuestionsState state,
) {
  final colors = context.colors;
  final typography = context.typography;
  final isDark = context.isDarkMode;

  final defaultYears = state.availableYears.isNotEmpty
      ? state.availableYears
      : const [2024, 2023, 2022, 2021, 2020, 2019, 2018];

  var isRandomSelection = state.selectedYear == null;
  var selectedYear =
      state.selectedYear ??
      (defaultYears.isNotEmpty ? defaultYears.first : 2024);
  var selectedCount = state.questions.length > 10
      ? 10
      : (state.questions.isEmpty ? 10 : state.questions.length);
  var isTimedMode = true;
  var isMillionaireMode = false;

  unawaited(
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.dialog),
        ),
      ),
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              top: false,
              child: Align(
                alignment: Alignment.bottomCenter,
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
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
                                borderRadius: BorderRadius.circular(
                                  AppRadius.micro,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Practice ${state.selectedExam.displayName}',
                            style: typography.title3.bold.copyWith(
                              color: colors.textPrimary,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Pick your questions and how the quiz should run.',
                            style: typography.footnote.regular.copyWith(
                              color: colors.textSecondary,
                              fontSize: 11.5,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 1. Question Source: mix every year, or one paper
                          const QuizSectionLabel(label: 'Questions'),
                          Row(
                            children: [
                              Expanded(
                                child: QuizChoiceCard(
                                  title: 'Mix of all years',
                                  subtitle: 'Shuffled across every past paper',
                                  icon: Icons.shuffle_rounded,
                                  selected: isRandomSelection,
                                  onTap: () => setSheetState(
                                    () => isRandomSelection = true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: QuizChoiceCard(
                                  title: 'One paper year',
                                  subtitle: 'Questions from a single exam year',
                                  icon: Icons.calendar_today_rounded,
                                  selected: !isRandomSelection,
                                  onTap: () => setSheetState(
                                    () => isRandomSelection = false,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // If specific year selected, show year pills
                          if (!isRandomSelection) ...[
                            const SizedBox(height: 12),
                            Text(
                              'Which year?',
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
                                      onSelected: (_) => setSheetState(
                                        () => selectedYear = yr,
                                      ),
                                      selectedColor: colors.primary.withAlpha(
                                        isDark ? 60 : 35,
                                      ),
                                      backgroundColor: colors.surfaceSecondary
                                          .withAlpha(100),
                                      labelStyle: typography.caption.bold
                                          .copyWith(
                                            color: isSelected
                                                ? colors.primary
                                                : colors.textSecondary,
                                            fontSize: 12,
                                          ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],

                          const SizedBox(height: 16),

                          // 2. How the quiz runs
                          const SizedBox(height: 16),
                          const QuizSectionLabel(label: 'How it runs'),
                          Row(
                            children: [
                              Expanded(
                                child: QuizChoiceCard(
                                  title: 'Practice',
                                  subtitle: 'Hints and feedback as you go',
                                  icon: Icons.school_outlined,
                                  accentColor: colors.syllabotAccent,
                                  selected: !isTimedMode && !isMillionaireMode,
                                  onTap: () => setSheetState(() {
                                    isTimedMode = false;
                                    isMillionaireMode = false;
                                  }),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: QuizChoiceCard(
                                  title: 'Exam',
                                  subtitle: 'Timed, results at the end',
                                  icon: Icons.timer_outlined,
                                  selected: isTimedMode && !isMillionaireMode,
                                  onTap: () => setSheetState(() {
                                    isTimedMode = true;
                                    isMillionaireMode = false;
                                  }),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: QuizChoiceCard(
                                  title: 'Millionaire',
                                  subtitle: 'Climb 12 tiers, bank your prize',
                                  icon: Icons.military_tech_rounded,
                                  accentColor: colors.warning,
                                  selected: isMillionaireMode,
                                  onTap: () => setSheetState(() {
                                    isMillionaireMode = true;
                                    selectedCount = 12;
                                  }),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // 3. Question Count Pills
                          const QuizSectionLabel(label: 'Question count'),
                          Row(
                            children:
                                (isMillionaireMode ? [12] : [5, 10, 20, 40])
                                    .map((count) {
                                      final isSelected = selectedCount == count;

                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          right: 8,
                                        ),
                                        child: ChoiceChip(
                                          label: Text(
                                            isMillionaireMode
                                                ? '12 questions'
                                                : '$count questions',
                                          ),
                                          selected: isSelected,
                                          onSelected: (_) => setSheetState(
                                            () => selectedCount = count,
                                          ),
                                          selectedColor: colors.primary
                                              .withAlpha(isDark ? 60 : 35),
                                          backgroundColor: colors
                                              .surfaceSecondary
                                              .withAlpha(100),
                                          labelStyle: typography.caption.bold
                                              .copyWith(
                                                color: isSelected
                                                    ? colors.primary
                                                    : colors.textSecondary,
                                              ),
                                        ),
                                      );
                                    })
                                    .toList(),
                          ),
                          const SizedBox(height: 22),

                          // 4. Launch CTA
                          ShrinkableButton(
                            onTap: () {
                              Navigator.pop(bottomSheetContext);

                              // Pool questions
                              var pool = List<PastQuestionEntity>.from(
                                state.questions,
                              );
                              if (!isRandomSelection) {
                                final filtered = pool
                                    .where((q) => q.year == selectedYear)
                                    .toList();
                                if (filtered.isNotEmpty) {
                                  pool = filtered;
                                }
                              } else {
                                pool.shuffle();
                              }

                              final count =
                                  selectedCount > pool.length && pool.isNotEmpty
                                  ? pool.length
                                  : selectedCount;

                              final testQuestions = pool
                                  .take(count)
                                  .map(QuizQuestionEntity.fromPastQuestion)
                                  .toList();

                              final testTitle = isMillionaireMode
                                  ? '${state.selectedExam.displayName} Millionaire Challenge'
                                  : (isRandomSelection
                                        ? '${state.selectedExam.displayName} Mixed Past Papers'
                                        : '${state.selectedExam.displayName} $selectedYear Past Paper');

                              Navigator.of(context).pop();

                              unawaited(
                                context.router.push(
                                  QuizWorkspaceRoute(
                                    deckId:
                                        'cbt_${state.selectedExam.code}_${isRandomSelection ? "random" : selectedYear}',
                                    deckTitle: testTitle,
                                    subject: state.selectedSubject == 'All'
                                        ? state.selectedExam.displayName
                                        : state.selectedSubject,
                                    durationMinutes: isMillionaireMode
                                        ? null
                                        : (isTimedMode ? count : null),
                                    initialQuestions: testQuestions,
                                    assessmentMode: isMillionaireMode
                                        ? AssessmentMode.millionaireMode
                                        : (isTimedMode
                                              ? AssessmentMode
                                                    .examSimulationMode
                                              : AssessmentMode.discoveryMode),
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              width: double.infinity,
                              height: 50,
                              decoration: BoxDecoration(
                                color: colors.primary,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.panel,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.black.withAlpha(
                                      isDark ? 50 : 20,
                                    ),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  isMillionaireMode
                                      ? 'Start 12 tiers · Millionaire'
                                      : (isTimedMode
                                            ? 'Start $selectedCount questions • $selectedCount min'
                                            : 'Start $selectedCount questions'),
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
          borderRadius: BorderRadius.circular(AppRadius.card),
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
