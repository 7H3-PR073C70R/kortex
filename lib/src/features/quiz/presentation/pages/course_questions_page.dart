import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_bloc.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_event.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_state.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/add_past_question_modal_sheet.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/past_question_card.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/past_questions_test_config_sheet.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/quiz_shell.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_back_button.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';
import 'package:kortex/src/shared/widgets/shimmer_placeholder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

@RoutePage()
class CourseQuestionsPage extends StatelessWidget {
  const CourseQuestionsPage({
    required this.courseTitle,
    this.courseCode,
    this.examCategory = ExamCategory.waec,
    this.initialYear,
    super.key,
  });

  final String courseTitle;
  final String? courseCode;
  final ExamCategory examCategory;
  final int? initialYear;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PastQuestionsBloc>(
      create: (_) => locator<PastQuestionsBloc>()
        ..add(
          LoadPastQuestionsEvent(
            examCategory: examCategory,
            subject: courseTitle,
            year: initialYear,
            courseCode: courseCode,
          ),
        ),
      child: _CourseQuestionsView(
        courseTitle: courseTitle,
        courseCode: courseCode,
        examCategory: examCategory,
        initialYear: initialYear,
      ),
    );
  }
}

class _CourseQuestionsView extends HookWidget {
  const _CourseQuestionsView({
    required this.courseTitle,
    required this.examCategory,
    this.courseCode,
    this.initialYear,
  });

  final String courseTitle;
  final String? courseCode;
  final ExamCategory examCategory;
  final int? initialYear;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final l10n = context.l10n;
    final reduceMotion = quizReduceMotion(context);
    final searchController = useTextEditingController();
    final debounceTimer = useRef<Timer?>(null);

    useEffect(
      () =>
          () => debounceTimer.value?.cancel(),
      const [],
    );

    return Scaffold(
      backgroundColor: isDark
          ? colors.backgroundPrimary
          : colors.surfacePrimary,
      appBar: AppBar(
        backgroundColor: colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const AppBackButton(),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              courseTitle,
              style: typography.title2.bold.copyWith(
                color: colors.textPrimary,
                fontSize: 17,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              '${examCategory.displayName}${courseCode != null ? ' • $courseCode' : ''}',
              style: typography.caption.medium.copyWith(
                color: colors.primary,
                fontSize: 11,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              Icons.add_circle_outline_rounded,
              color: colors.primary,
              size: 22,
            ),
            tooltip: 'Add Question',
            onPressed: () {
              AppFeedback.light();
              unawaited(
                AddPastQuestionModalSheet.show(
                  context,
                  defaultSubject: courseTitle,
                  onAdded: (newQuestions) {
                    context.read<PastQuestionsBloc>().add(
                      AddPastQuestionsEvent(newQuestions),
                    );
                  },
                ),
              );
            },
          ),
          BlocBuilder<PastQuestionsBloc, PastQuestionsState>(
            builder: (context, state) {
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primary.withAlpha(isDark ? 50 : 25),
                      borderRadius: BorderRadius.circular(AppRadius.badge),
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
                        fontSize: 11,
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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              children: [
                // 1. Search Bar & Instant Feedback Switcher
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: searchController,
                          hintText: 'Search questions in $courseTitle',
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: colors.textSecondary,
                            size: 19,
                          ),
                          onChanged: (query) {
                            debounceTimer.value?.cancel();
                            debounceTimer.value = Timer(
                              const Duration(milliseconds: 300),
                              () {
                                if (context.mounted) {
                                  context.read<PastQuestionsBloc>().add(
                                    LoadPastQuestionsEvent(
                                      searchQuery: query,
                                      subject: courseTitle,
                                      examCategory: examCategory,
                                      courseCode: courseCode,
                                    ),
                                  );
                                }
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      BlocBuilder<PastQuestionsBloc, PastQuestionsState>(
                        builder: (context, state) {
                          final isInstant = state.isInstantFeedbackMode;
                          return ShrinkableButton(
                            onTap: () {
                              AppFeedback.selection();
                              context.read<PastQuestionsBloc>().add(
                                const TogglePracticeModeEvent(),
                              );
                            },
                            child: Container(
                              height: 48,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isInstant
                                    ? colors.primary.withAlpha(isDark ? 45 : 25)
                                    : colors.surfaceSecondary,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.card,
                                ),
                                border: Border.all(
                                  color: isInstant
                                      ? colors.primary.withAlpha(100)
                                      : colors.surfaceBorder,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isInstant
                                        ? Icons.bolt_rounded
                                        : Icons.timer_outlined,
                                    size: 18,
                                    color: isInstant
                                        ? colors.primary
                                        : colors.textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isInstant ? 'Instant' : 'Practice',
                                    style: typography.caption.bold.copyWith(
                                      color: isInstant
                                          ? colors.primary
                                          : colors.textSecondary,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // 2. Results-first context + Year Filter Chips
                BlocBuilder<PastQuestionsBloc, PastQuestionsState>(
                  builder: (context, state) {
                    final years = state.availableYears.isNotEmpty
                        ? state.availableYears
                        : [2024, 2023, 2022, 2021, 2020, 2019, 2018];
                    final selectedYear = state.selectedYear;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                          child: QuizTagPill(
                            icon: Icons.check_circle_outline_rounded,
                            label:
                                '${state.totalQuestions} questions • you have answered ${state.answeredQuestions}',
                            color: colors.primary,
                          ),
                        ),
                        SizedBox(
                          height: 38,
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                            scrollDirection: Axis.horizontal,
                            itemCount: years.length + 1,
                            separatorBuilder: (_, index) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final isAll = index == 0;
                              final year = isAll ? null : years[index - 1];
                              final isSelected = isAll
                                  ? selectedYear == null
                                  : selectedYear == year;

                              return ShrinkableButton(
                                onTap: () {
                                  AppFeedback.selection();
                                  context.read<PastQuestionsBloc>().add(
                                    ChangeYearEvent(year),
                                  );
                                },
                                child: AnimatedContainer(
                                  duration: AppMotion.snappy,
                                  curve: AppMotion.snappyCurve,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? colors.primary
                                        : (isDark
                                              ? colors.surfaceSecondary
                                              : colors.surfacePrimary),
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.badge,
                                    ),
                                    border: Border.all(
                                      color: isSelected
                                          ? colors.primary
                                          : colors.surfaceBorder,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      isAll ? 'All years' : '$year',
                                      style: typography.caption.bold.copyWith(
                                        color: isSelected
                                            ? colors.white
                                            : colors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 10),

                // 3. Question Feed
                Expanded(
                  child: BlocBuilder<PastQuestionsBloc, PastQuestionsState>(
                    builder: (context, state) {
                      if (state.status == PastQuestionsStatus.loading) {
                        return ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          children: const [
                            ShimmerPlaceholder(
                              height: 160,
                              borderRadius: AppRadius.panel,
                            ),
                            SizedBox(height: 12),
                            ShimmerPlaceholder(
                              height: 160,
                              borderRadius: AppRadius.panel,
                            ),
                            SizedBox(height: 12),
                            ShimmerPlaceholder(
                              height: 160,
                              borderRadius: AppRadius.panel,
                            ),
                          ],
                        );
                      }

                      if (state.questions.isEmpty) {
                        final isSpecificYear = state.selectedYear != null;
                        final syllabotPrompt =
                            'Please generate 5 official-style ${examCategory.displayName} practice questions for $courseTitle right now'
                            '${isSpecificYear ? ' following the ${state.selectedYear} syllabus format' : ''}. '
                            'For each question, provide 4 options labeled A, B, C, and D, clearly indicate the correct answer, and explain the step-by-step solution.';

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Expanded(
                              child: QuizEmptyState(
                                icon: Icons.auto_stories_outlined,
                                headline: isSpecificYear
                                    ? 'No ${state.selectedYear} questions yet for $courseTitle'
                                    : 'No questions yet for $courseTitle',
                                message: isSpecificYear
                                    ? 'The ${state.selectedYear} paper is still being added. You can generate practice questions with Syllabot AI, or browse every year you already have.'
                                    : 'Generate practice questions with Syllabot AI, or add your own to get started.',
                                actionLabel: 'Generate AI practice questions',
                                onAction: () {
                                  AppFeedback.light();
                                  unawaited(
                                    context.router.push(
                                      SyllabotChatRoute(
                                        initialPrompt: syllabotPrompt,
                                        initialMode: SocraticMode.examSim,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            if (isSpecificYear)
                              TextButton(
                                onPressed: () {
                                  AppFeedback.selection();
                                  context.read<PastQuestionsBloc>().add(
                                    const ChangeYearEvent(null),
                                  );
                                },
                                child: Text(
                                  'Browse all years instead',
                                  style: typography.caption.bold.copyWith(
                                    color: colors.primary,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                          ],
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        physics: const ClampingScrollPhysics(),
                        itemCount: state.questions.length,
                        itemBuilder: (context, index) {
                          final question = state.questions[index];
                          final card = PastQuestionCard(
                            question: question,
                            isInstantFeedback: state.isInstantFeedbackMode,
                          );
                          // Only the first screenful animates in; items
                          // recycled while scrolling stay put.
                          if (index >= 10) return card;
                          return QuizStaggeredFade(
                            index: index,
                            distance: 10,
                            reduceMotion: reduceMotion,
                            child: card,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BlocBuilder<PastQuestionsBloc, PastQuestionsState>(
        builder: (context, state) {
          if (state.questions.isEmpty) return const SizedBox.shrink();

          return SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? colors.surfacePrimary
                        : colors.surfacePrimary.withAlpha(240),
                    border: Border(
                      top: BorderSide(color: colors.surfaceBorder),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: ShrinkableButton(
                          onTap: () =>
                              showPastQuestionsTestConfigSheet(context, state),
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: colors.primary,
                              borderRadius: BorderRadius.circular(
                                AppRadius.card,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: colors.black.withAlpha(
                                    isDark ? 50 : 20,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.play_circle_filled_rounded,
                                  color: colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Start practice test',
                                  style: typography.callout.bold.copyWith(
                                    color: colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ShrinkableButton(
                        onTap: () {
                          AppFeedback.light();
                          unawaited(
                            context.router.push(
                              SyllabotChatRoute(
                                initialPrompt:
                                    'I need Socratic help understanding key concepts in $courseTitle (${examCategory.displayName}). What are the highest-yield topics I should focus on?',
                                initialMode: SocraticMode.stepByStep,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: colors.primary.withAlpha(isDark ? 40 : 25),
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            border: Border.all(
                              color: colors.primary.withAlpha(isDark ? 80 : 50),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.auto_awesome_rounded,
                                color: colors.primary,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Syllabot AI',
                                style: typography.callout.bold.copyWith(
                                  color: colors.primary,
                                  fontSize: 12.5,
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
          );
        },
      ),
    );
  }
}
