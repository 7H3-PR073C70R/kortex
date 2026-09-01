import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_bloc.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_event.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_state.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_logo_loader.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';
import 'package:kortex/src/shared/widgets/shimmer_placeholder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

@RoutePage()
class PastQuestionsBoardPage extends StatelessWidget {
  const PastQuestionsBoardPage({
    @queryParam this.initialExamCode,
    super.key,
  });

  final String? initialExamCode;

  @override
  Widget build(BuildContext context) {
    var initialExam = ExamCategory.waec;
    if (initialExamCode != null) {
      final code = initialExamCode!.toUpperCase();
      for (final cat in ExamCategory.values) {
        if (cat.code == code) {
          initialExam = cat;
          break;
        }
      }
    }

    return BlocProvider<PastQuestionsBloc>(
      create: (_) => locator<PastQuestionsBloc>()
        ..add(LoadPastQuestionsEvent(examCategory: initialExam)),
      child: const _PastQuestionsBoardView(),
    );
  }
}

class _PastQuestionsBoardView extends HookWidget {
  const _PastQuestionsBoardView();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final l10n = context.l10n;
    final searchController = useTextEditingController();

    return Scaffold(
      backgroundColor:
          isDark ? colors.backgroundPrimary : colors.surfacePrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          l10n.pastQuestionsBankTitle,
          style: typography.title2.bold.copyWith(
            color: colors.textPrimary,
          ),
        ),
        actions: [
          BlocBuilder<PastQuestionsBloc, PastQuestionsState>(
            builder: (context, state) {
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primary.withAlpha(isDark ? 50 : 25),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colors.primary.withAlpha(isDark ? 80 : 50),
                      ),
                    ),
                    child: Text(
                      l10n.pastQuestionsProgressDone(
                        state.answeredQuestions,
                        state.totalQuestions,
                      ),
                      style: typography.caption.bold.copyWith(
                        color: colors.primary,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Exam Category Selector
            const _ExamCategoryBar(),

            // 2. Search & Filter Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: searchController,
                      hintText: l10n.pastQuestionsSearchHint,
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: colors.textSecondary,
                        size: 20,
                      ),
                      onChanged: (query) {
                        context.read<PastQuestionsBloc>().add(
                              LoadPastQuestionsEvent(searchQuery: query),
                            );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // 3. Subject & Year Filters
            const _SubjectAndYearFilterRow(),
            const SizedBox(height: 6),

            // 4. Questions List Feed
            Expanded(
              child: BlocBuilder<PastQuestionsBloc, PastQuestionsState>(
                builder: (context, state) {
                  if (state.status == PastQuestionsStatus.loading) {
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: AppLogoLoader(
                              size: 56,
                              message: l10n.pastQuestionsLoading,
                            ),
                          ),
                        ),
                        const ShimmerPlaceholder(height: 160, borderRadius: 20),
                        const SizedBox(height: 14),
                        const ShimmerPlaceholder(height: 160, borderRadius: 20),
                      ],
                    );
                  }

                  if (state.questions.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.menu_book_rounded,
                              size: 48,
                              color: colors.textSecondary.withAlpha(120),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              l10n.pastQuestionsEmptyTitle,
                              style: typography.title3.bold.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              l10n.pastQuestionsEmptyDesc,
                              textAlign: TextAlign.center,
                              style: typography.footnote.regular.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    physics: const BouncingScrollPhysics(),
                    itemCount: state.questions.length,
                    itemBuilder: (context, index) {
                      final question = state.questions[index];
                      return _PastQuestionCard(
                        question: question,
                        isInstantFeedback: state.isInstantFeedbackMode,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExamCategoryBar extends StatelessWidget {
  const _ExamCategoryBar();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return BlocBuilder<PastQuestionsBloc, PastQuestionsState>(
      builder: (context, state) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: ExamCategory.values.map((exam) {
              final isSelected = state.selectedExam == exam;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ShrinkableButton(
                  onTap: () {
                    unawaited(HapticFeedback.selectionClick());
                    context
                        .read<PastQuestionsBloc>()
                        .add(ChangeExamCategoryEvent(exam));
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colors.primary
                          : (isDark
                              ? colors.surfaceSecondary
                              : colors.surfaceSecondary.withAlpha(90)),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? colors.primary
                            : colors.surfaceBorder.withAlpha(100),
                      ),
                    ),
                    child: Text(
                      exam.displayName,
                      style: typography.caption.bold.copyWith(
                        color: isSelected ? Colors.white : colors.textPrimary,
                      ),
                    ),
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

class _SubjectAndYearFilterRow extends StatelessWidget {
  const _SubjectAndYearFilterRow();

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
            children: [
              // Subject Chips
              ...subjects.map((subj) {
                final isSelected = state.selectedSubject == subj;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(subj),
                    selected: isSelected,
                    onSelected: (_) {
                      context
                          .read<PastQuestionsBloc>()
                          .add(ChangeSubjectEvent(subj));
                    },
                    selectedColor: colors.primary.withAlpha(isDark ? 60 : 35),
                    backgroundColor: isDark
                        ? colors.surfaceSecondary
                        : colors.surfaceSecondary.withAlpha(60),
                    labelStyle: typography.caption.bold.copyWith(
                      color: isSelected ? colors.primary : colors.textSecondary,
                      fontSize: 11.5,
                    ),
                    side: BorderSide(
                      color: isSelected
                          ? colors.primary
                          : colors.surfaceBorder.withAlpha(80),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              }),

              // Year Filter Chips
              if (state.availableYears.isNotEmpty) ...[
                Container(
                  width: 1,
                  height: 20,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  color: colors.surfaceBorder.withAlpha(120),
                ),
                ...state.availableYears.map((yr) {
                  final isSelected = state.selectedYear == yr;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text('$yr'),
                      selected: isSelected,
                      onSelected: (val) {
                        context
                            .read<PastQuestionsBloc>()
                            .add(ChangeYearEvent(val ? yr : null));
                      },
                      selectedColor:
                          colors.syllabotAccent.withAlpha(isDark ? 60 : 35),
                      backgroundColor: isDark
                          ? colors.surfaceSecondary
                          : colors.surfaceSecondary.withAlpha(60),
                      labelStyle: typography.caption.bold.copyWith(
                        color: isSelected
                            ? colors.syllabotAccent
                            : colors.textSecondary,
                        fontSize: 11.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _PastQuestionCard extends StatelessWidget {
  const _PastQuestionCard({
    required this.question,
    required this.isInstantFeedback,
  });

  final PastQuestionEntity question;
  final bool isInstantFeedback;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final optionLetters = ['A', 'B', 'C', 'D', 'E'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? colors.surfaceBorderHighlight.withAlpha(60)
              : colors.surfaceBorder.withAlpha(120),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 40 : 8),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Badge Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primary.withAlpha(isDark ? 40 : 20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${question.subject} • ${question.year} '
                      '#Q${question.questionNumber}',
                      style: typography.caption.bold.copyWith(
                        color: colors.primary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      question.topic,
                      style: typography.caption.medium.copyWith(
                        color: colors.textSecondary,
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(
                  question.isBookmarked
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_outline_rounded,
                  color: question.isBookmarked
                      ? colors.syllabotAccent
                      : colors.textSecondary,
                  size: 20,
                ),
                onPressed: () {
                  context
                      .read<PastQuestionsBloc>()
                      .add(ToggleBookmarkEvent(question.id));
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Reading Passage (if present)
          if (question.passage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.backgroundPrimary.withAlpha(isDark ? 100 : 40),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colors.surfaceBorder.withAlpha(80),
                ),
              ),
              child: Text(
                question.passage!,
                style: typography.subhead.regular.copyWith(
                  color: colors.textSecondary,
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Question Prompt
          Text(
            question.prompt,
            style: typography.body.bold.copyWith(
              color: colors.textPrimary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),

          // Multiple Choice Options
          ...question.options.asMap().entries.map((entry) {
            final idx = entry.key;
            final optionText = entry.value;
            final letter =
                idx < optionLetters.length ? optionLetters[idx] : '$idx';
            final isSelected = question.userSelectedOptionIndex == idx;
            final isCorrect = idx == question.correctOptionIndex;

            var optionBgColor = isDark
                ? colors.backgroundPrimary
                : colors.surfaceSecondary.withAlpha(50);
            var optionBorderColor = colors.surfaceBorder.withAlpha(90);
            var optionTextColor = colors.textPrimary;

            if (question.isAnswered && isInstantFeedback) {
              if (isCorrect) {
                optionBgColor = Colors.green.withAlpha(isDark ? 50 : 25);
                optionBorderColor = Colors.green.withAlpha(180);
                optionTextColor = Colors.green;
              } else if (isSelected) {
                optionBgColor = Colors.red.withAlpha(isDark ? 50 : 25);
                optionBorderColor = Colors.red.withAlpha(180);
                optionTextColor = Colors.red;
              }
            } else if (isSelected) {
              optionBgColor = colors.primary.withAlpha(isDark ? 50 : 25);
              optionBorderColor = colors.primary;
              optionTextColor = colors.primary;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ShrinkableButton(
                onTap: () {
                  unawaited(HapticFeedback.selectionClick());
                  context.read<PastQuestionsBloc>().add(
                        SelectOptionEvent(
                          questionId: question.id,
                          optionIndex: idx,
                        ),
                      );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: optionBgColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: optionBorderColor, width: 1.2),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? colors.primary
                              : colors.surfaceSecondary,
                        ),
                        child: Center(
                          child: Text(
                            letter,
                            style: typography.caption.bold.copyWith(
                              color: isSelected
                                  ? Colors.white
                                  : colors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          optionText,
                          style: typography.subhead.medium.copyWith(
                            color: optionTextColor,
                          ),
                        ),
                      ),
                      if (question.isAnswered && isInstantFeedback) ...[
                        if (isCorrect)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Colors.green,
                            size: 20,
                          )
                        else if (isSelected)
                          const Icon(
                            Icons.cancel_rounded,
                            color: Colors.red,
                            size: 20,
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),

          // Explanation Box (shown once answered in instant feedback mode)
          if (question.isAnswered && isInstantFeedback) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.primary.withAlpha(isDark ? 30 : 15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colors.primary.withAlpha(isDark ? 70 : 40),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb_rounded,
                        color: colors.syllabotAccent,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        context.l10n.pastQuestionsExplanationTitle,
                        style: typography.footnote.bold.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    question.explanation,
                    style: typography.footnote.regular.copyWith(
                      color: colors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Bottom Action: Ask Syllabot AI
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ShrinkableButton(
                onTap: () {
                  unawaited(
                    context.router.push(
                      SyllabotChatRoute(
                        initialPrompt:
                            'Explain this ${question.subject} question '
                            'step-by-step:\n"${question.prompt}"',
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colors.syllabotAccent.withAlpha(isDark ? 45 : 25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colors.syllabotAccent.withAlpha(isDark ? 90 : 50),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        color: colors.syllabotAccent,
                        size: 15,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        context.l10n.pastQuestionsAskSyllabot,
                        style: typography.caption.bold.copyWith(
                          color: colors.syllabotAccent,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
