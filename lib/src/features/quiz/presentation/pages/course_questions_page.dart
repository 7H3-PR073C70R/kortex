import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_bloc.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_event.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_state.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/add_past_question_modal_sheet.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/past_question_card.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/past_questions_test_config_sheet.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';
import 'package:kortex/src/l10n/l10n.dart';
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
    final searchController = useTextEditingController();
    final debounceTimer = useRef<Timer?>(null);

    useEffect(() => () => debounceTimer.value?.cancel(), const []);

    return Scaffold(
      backgroundColor:
          isDark ? colors.backgroundPrimary : colors.surfacePrimary,
      appBar: AppBar(
        backgroundColor: colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: colors.textPrimary,
            size: 18,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
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
                      hintText: 'Search within $courseTitle...',
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
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: isInstant
                                ? colors.primary.withAlpha(isDark ? 45 : 25)
                                : colors.surfaceSecondary,
                            borderRadius: BorderRadius.circular(14),
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

            // 2. Year Filter Chips Horizontal Scroll
            BlocBuilder<PastQuestionsBloc, PastQuestionsState>(
              builder: (context, state) {
                final years = state.availableYears.isNotEmpty
                    ? state.availableYears
                    : [2024, 2023, 2022, 2021, 2020, 2019, 2018];
                final selectedYear = state.selectedYear;

                return SizedBox(
                  height: 38,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: years.length + 1,
                    separatorBuilder: (_, index) => const SizedBox(width: 8),
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
                                    : colors.surfacePrimary),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? colors.primary
                                  : colors.surfaceBorder,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: colors.primary.withAlpha(60),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              isAll ? 'All Years' : '$year',
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
                        ShimmerPlaceholder(height: 160, borderRadius: 18),
                        SizedBox(height: 12),
                        ShimmerPlaceholder(height: 160, borderRadius: 18),
                        SizedBox(height: 12),
                        ShimmerPlaceholder(height: 160, borderRadius: 18),
                      ],
                    );
                  }

                  if (state.questions.isEmpty) {
                    final isSpecificYear = state.selectedYear != null;
                    final syllabotPrompt =
                        'Please generate 5 official-style ${examCategory.displayName} practice questions for $courseTitle right now'
                        '${isSpecificYear ? ' following the ${state.selectedYear} syllabus format' : ''}. '
                        'For each question, provide 4 options labeled A, B, C, and D, clearly indicate the correct answer, and explain the step-by-step solution.';

                    return Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 32,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color:
                                    colors.primary.withAlpha(isDark ? 35 : 18),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.auto_stories_outlined,
                                size: 38,
                                color: colors.primary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              isSpecificYear
                                  ? 'No ${state.selectedYear} Questions for $courseTitle'
                                  : 'No Questions Found for $courseTitle',
                              textAlign: TextAlign.center,
                              style: typography.title3.bold.copyWith(
                                color: colors.textPrimary,
                                fontSize: 16.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isSpecificYear
                                  ? 'Official past papers for ${state.selectedYear} are currently syncing. You can generate instant practice questions with Syllabot AI or switch to all years.'
                                  : 'Verified exam questions for $courseTitle are being populated. Practice immediately with Syllabot AI or add your own custom questions.',
                              textAlign: TextAlign.center,
                              style: typography.footnote.regular.copyWith(
                                color: colors.textSecondary,
                                fontSize: 12.5,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 22),
                            ShrinkableButton(
                              onTap: () {
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
                              child: Container(
                                width: double.infinity,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: colors.primary,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: colors.primary.withAlpha(80),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.auto_awesome_rounded,
                                      size: 16,
                                      color: colors.white,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Generate AI Practice Questions',
                                      style: typography.caption.bold.copyWith(
                                        color: colors.white,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (isSpecificYear) ...[
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () {
                                  AppFeedback.selection();
                                  context.read<PastQuestionsBloc>().add(
                                        const ChangeYearEvent(null),
                                      );
                                },
                                child: Text(
                                  'Switch to All Years',
                                  style: typography.caption.bold.copyWith(
                                    color: colors.primary,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    physics: const BouncingScrollPhysics(),
                    itemCount: state.questions.length,
                    itemBuilder: (context, index) {
                      final question = state.questions[index];
                      return PastQuestionCard(
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
      bottomNavigationBar: BlocBuilder<PastQuestionsBloc, PastQuestionsState>(
        builder: (context, state) {
          if (state.questions.isEmpty) return const SizedBox.shrink();

          return Container(
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
                        borderRadius: BorderRadius.circular(13),
                        boxShadow: [
                          BoxShadow(
                            color: colors.primary.withAlpha(80),
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
                            'Timed CBT Drill',
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
                      borderRadius: BorderRadius.circular(13),
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
          );
        },
      ),
    );
  }
}
