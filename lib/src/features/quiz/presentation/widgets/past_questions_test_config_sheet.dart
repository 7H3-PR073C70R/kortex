import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_state.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_session_state.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/quiz_shell.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_sheet.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Modal sheet allowing students to configure and start a timed CBT practice test.
void showPastQuestionsTestConfigSheet(
  BuildContext context,
  PastQuestionsState state,
) {
  final colors = context.colors;
  final typography = context.typography;
  final isDark = context.isDarkMode;
  final isDesktop = AppAdaptiveSheet.isDesktopOrWeb(context);

  final availableYears = state.availableYears.isNotEmpty
      ? state.availableYears
      : const [2024, 2023, 2022, 2021, 2020, 2019, 2018];

  var selectedYear = state.selectedYear;
  var isTimedMode = true;
  var isMillionaireMode = false;

  final defaultCount = state.questions.length >= 20
      ? 20
      : (state.questions.length >= 10
            ? 10
            : (state.questions.isEmpty ? 10 : state.questions.length));
  var selectedCount = defaultCount;

  unawaited(
    AppAdaptiveSheet.showModal<void>(
      context: context,
      maxWidth: 640,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filteredPool = selectedYear == null
                ? state.questions
                : state.questions.where((q) => q.year == selectedYear).toList();
            final availableCount = filteredPool.isEmpty
                ? state.questions.length
                : filteredPool.length;

            return SafeArea(
              top: isDesktop,
              child: Align(
                alignment: isDesktop ? Alignment.center : Alignment.bottomCenter,
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
                      borderRadius: isDesktop
                          ? BorderRadius.circular(AppRadius.dialog)
                          : const BorderRadius.vertical(
                              top: Radius.circular(AppRadius.dialog),
                            ),
                      border: isDesktop ? Border.all(color: colors.surfaceBorder) : null,
                      boxShadow: isDesktop
                          ? [
                              BoxShadow(
                                color: colors.black.withAlpha(isDark ? 100 : 35),
                                blurRadius: 32,
                                offset: const Offset(0, 12),
                              ),
                            ]
                          : null,
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isDesktop) ...[
                            // 1. Accessible Drag Handle (mobile only)
                            Center(
                              child: Container(
                                width: 36,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: colors.surfaceBorderHighlight,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.micro,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],

                          // 2. Header
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Practice ${state.selectedExam.displayName}',
                                      style: typography.title2.bold.copyWith(
                                        color: colors.textPrimary,
                                        fontSize: 18,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      state.selectedSubject == 'All'
                                          ? 'All Subjects • Past Questions Bank'
                                          : '${state.selectedSubject} • Past Questions Bank',
                                      style: typography.caption.regular.copyWith(
                                        color: colors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: colors.textMuted,
                                  size: 20,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                onPressed: () =>
                                    Navigator.of(bottomSheetContext).pop(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // 3. Mode Selection (Segmented Control + Dynamic Caption)
                          const QuizSectionLabel(label: 'Quiz Mode'),
                          QuizModeSegmentedControl(
                            currentMode: isMillionaireMode
                                ? QuizPracticeMode.millionaire
                                : (isTimedMode
                                      ? QuizPracticeMode.exam
                                      : QuizPracticeMode.practice),
                            onModeSelected: (mode) {
                              setSheetState(() {
                                switch (mode) {
                                  case QuizPracticeMode.practice:
                                    isTimedMode = false;
                                    isMillionaireMode = false;
                                  case QuizPracticeMode.exam:
                                    isTimedMode = true;
                                    isMillionaireMode = false;
                                  case QuizPracticeMode.millionaire:
                                    isTimedMode = false;
                                    isMillionaireMode = true;
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          QuizModeDescription(
                            mode: isMillionaireMode
                                ? QuizPracticeMode.millionaire
                                : (isTimedMode
                                      ? QuizPracticeMode.exam
                                      : QuizPracticeMode.practice),
                          ),
                          const SizedBox(height: 18),

                          // 4. Question Source / Exam Year (Single-Row Horizontal Pills)
                          QuizSectionLabel(
                            label: 'Exam Year',
                            trailing: Text(
                              selectedYear == null
                                  ? 'All years shuffled'
                                  : 'Paper year $selectedYear',
                              style: typography.caption.bold.copyWith(
                                color: colors.primary,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              children: [
                                QuizYearPill(
                                  label: 'All Years',
                                  icon: Icons.shuffle_rounded,
                                  isSelected: selectedYear == null,
                                  onTap: () {
                                    AppFeedback.light();
                                    setSheetState(() => selectedYear = null);
                                  },
                                ),
                                ...availableYears.map((yr) {
                                  return Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: QuizYearPill(
                                      label: '$yr',
                                      isSelected: selectedYear == yr,
                                      onTap: () {
                                        AppFeedback.light();
                                        setSheetState(() => selectedYear = yr);
                                      },
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),

                          // 5. Question Count (Evenly Expanded Pills - Zero Overflow)
                          QuizSectionLabel(
                            label: 'Question Count',
                            trailing: Text(
                              isMillionaireMode
                                  ? '12 Tiers Fixed'
                                  : (isTimedMode
                                        ? '${selectedCount}m limit'
                                        : '$availableCount available'),
                              style: typography.caption.bold.copyWith(
                                color: isMillionaireMode
                                    ? colors.warning
                                    : colors.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          if (isMillionaireMode)
                            const QuizMillionaireNotice()
                          else
                            Row(
                              children: [5, 10, 20, 40].map((count) {
                                final isSelected = selectedCount == count;
                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 3,
                                    ),
                                    child: QuizCountOptionPill(
                                      count: count,
                                      isSelected: isSelected,
                                      onTap: () {
                                        AppFeedback.light();
                                        setSheetState(
                                          () => selectedCount = count,
                                        );
                                      },
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          const SizedBox(height: 24),

                          // 6. Launch CTA Button
                          ShrinkableButton(
                            onTap: () {
                              AppFeedback.medium();
                              Navigator.of(bottomSheetContext).pop();

                              // Pool questions
                              var pool = List<PastQuestionEntity>.from(
                                state.questions,
                              );
                              if (selectedYear != null) {
                                final filtered = pool
                                    .where((q) => q.year == selectedYear)
                                    .toList();
                                if (filtered.isNotEmpty) {
                                  pool = filtered;
                                }
                              } else {
                                pool.shuffle();
                              }

                              final count = isMillionaireMode
                                  ? 12
                                  : (selectedCount > pool.length &&
                                            pool.isNotEmpty
                                        ? pool.length
                                        : selectedCount);

                              final testQuestions = pool
                                  .take(count)
                                  .map(QuizQuestionEntity.fromPastQuestion)
                                  .toList();

                              final testTitle = isMillionaireMode
                                  ? '${state.selectedExam.displayName} Millionaire Challenge'
                                  : (selectedYear == null
                                        ? '${state.selectedExam.displayName} Mixed Past Papers'
                                        : '${state.selectedExam.displayName} $selectedYear Past Paper');

                              final router = context.router;
                              unawaited(
                                router.push(
                                  QuizWorkspaceRoute(
                                    deckId:
                                        'cbt_${state.selectedExam.code}_${selectedYear ?? "random"}',
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
                                color: isMillionaireMode
                                    ? colors.warning
                                    : colors.primary,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.panel,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        (isMillionaireMode
                                                ? colors.warning
                                                : colors.primary)
                                            .withAlpha(isDark ? 60 : 30),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    isMillionaireMode
                                        ? Icons.workspace_premium_rounded
                                        : (isTimedMode
                                              ? Icons.timer_outlined
                                              : Icons.play_arrow_rounded),
                                    color: colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isMillionaireMode
                                        ? 'Start 12-Tier Millionaire'
                                        : (isTimedMode
                                              ? 'Start $selectedCount Questions • ${selectedCount}m'
                                              : 'Start $selectedCount Questions'),
                                    style: typography.callout.bold.copyWith(
                                      color: colors.white,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
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
