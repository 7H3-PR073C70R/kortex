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
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_bloc.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_event.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_state.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_duel_cubit.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/add_past_question_modal_sheet.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/past_questions_filter_bar.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/past_questions_test_config_sheet.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/quiz_duel_matchmaking_sheet.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/quiz_shell.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_back_button.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shimmer_placeholder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

@RoutePage()
class PastQuestionsBoardPage extends StatelessWidget {
  const PastQuestionsBoardPage({
    @queryParam this.initialExamCode,
    @queryParam this.initialSubject,
    super.key,
  });

  final String? initialExamCode;
  final String? initialSubject;

  static ExamCategory resolveExamCategory(String? code, String? userTrack) {
    final target = (code != null && code.isNotEmpty)
        ? code
        : (userTrack != null && userTrack.isNotEmpty ? userTrack : 'WAEC');
    final upper = target.toUpperCase();
    if (upper.contains('WAEC') || upper.contains('WASSCE')) {
      return ExamCategory.waec;
    }
    if (upper.contains('JAMB') || upper.contains('UTME')) {
      return ExamCategory.jamb;
    }
    if (upper.contains('NECO') || upper.contains('SSCE')) {
      return ExamCategory.neco;
    }
    if (upper.contains('SAT')) return ExamCategory.sat;
    if (upper.contains('TOEFL')) return ExamCategory.toefl;
    if (upper.contains('IELTS')) return ExamCategory.ielts;
    if (upper.contains('MED')) return ExamCategory.medicine;
    if (upper.contains('LAW')) return ExamCategory.law;
    if (upper.contains('ENG')) return ExamCategory.engineering;
    if (upper.contains('BUS') || upper.contains('ACC')) {
      return ExamCategory.business;
    }
    if (upper.contains('CS') || upper.contains('COMP')) {
      return ExamCategory.computerScience;
    }
    return ExamCategory.waec;
  }

  @override
  Widget build(BuildContext context) {
    final userTrack = context.read<AuthBloc?>()?.state.userProfile?.targetTrack;
    final initialExam = resolveExamCategory(initialExamCode, userTrack);

    return MultiBlocProvider(
      providers: [
        BlocProvider<PastQuestionsBloc>(
          create: (_) => locator<PastQuestionsBloc>()
            ..add(
              LoadPastQuestionsEvent(
                examCategory: initialExam,
                subject: initialSubject,
              ),
            ),
        ),
        BlocProvider<QuizDuelCubit>(
          create: (_) => locator<QuizDuelCubit>(),
        ),
      ],
      child: _PastQuestionsBoardView(
        userTrack: userTrack ?? 'WAEC',
        initialSubject: initialSubject,
      ),
    );
  }
}

class _PastQuestionsBoardView extends HookWidget {
  const _PastQuestionsBoardView({
    required this.userTrack,
    this.initialSubject,
  });

  final String userTrack;
  final String? initialSubject;

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
        title: Text(
          'Past Questions & Practice',
          style: typography.title2.bold.copyWith(
            color: colors.textPrimary,
            fontSize: 18,
          ),
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
              final state = context.read<PastQuestionsBloc>().state;
              unawaited(
                AddPastQuestionModalSheet.show(
                  context,
                  defaultSubject: state.selectedSubject.isNotEmpty
                      ? state.selectedSubject
                      : initialSubject,
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
                      horizontal: 10,
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
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              children: [
                // 1. Hero Practice Banner (CBT Test & 1v1 Duel Quick Actions)
                _HeroTrackBanner(userTrack: userTrack),

                // 2. Search Field with Year Filter Button
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: searchController,
                          hintText: 'Search subjects and topics',
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
                                    LoadPastQuestionsEvent(searchQuery: query),
                                  );
                                }
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      const YearFilterButton(),
                    ],
                  ),
                ),

                // 3. Subject Filter Chips (All, Mathematics, English, etc.)
                const SubjectFilterBar(),
                const SizedBox(height: 8),

                // 4. Course Cards Grid/List
                Expanded(
                  child: BlocBuilder<PastQuestionsBloc, PastQuestionsState>(
                    builder: (context, state) {
                      if (state.status == PastQuestionsStatus.loading) {
                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: 4,
                          separatorBuilder: (_, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (_, index) => const ShimmerPlaceholder(
                            height: 108,
                            borderRadius: AppRadius.panel,
                          ),
                        );
                      }

                      final courses = _groupQuestionsByCourse(
                        state.questions,
                        state.availableSubjects,
                        state.selectedSubject,
                        state.searchQuery,
                      );

                      if (courses.isEmpty) {
                        return const QuizEmptyState(
                          icon: Icons.search_off_rounded,
                          headline: 'No subjects match your filters',
                          message:
                              'Try a different search, clear the subject filter, or change the exam year.',
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        physics: const ClampingScrollPhysics(),
                        itemCount: courses.length,
                        separatorBuilder: (_, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final course = courses[index];
                          final card = _CourseOverviewCard(
                            courseSummary: course,
                            examCategory: state.selectedExam,
                            selectedYear: state.selectedYear,
                          );
                          // Only the first screenful animates in; recycled
                          // cards while scrolling stay put.
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
          if (state.status == PastQuestionsStatus.loading ||
              state.totalQuestions == 0) {
            return const SizedBox.shrink();
          }
          return SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: ShrinkableButton(
                    onTap: () {
                      AppFeedback.medium();
                      showPastQuestionsTestConfigSheet(context, state);
                    },
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        boxShadow: [
                          BoxShadow(
                            color: colors.black.withAlpha(isDark ? 50 : 20),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.play_arrow_rounded,
                            color: colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Start practice test',
                            style: typography.callout.bold.copyWith(
                              color: colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<_CourseSummary> _groupQuestionsByCourse(
    List<PastQuestionEntity> questions,
    List<String> availableSubjects,
    String selectedSubject,
    String searchQuery,
  ) {
    final map = <String, List<PastQuestionEntity>>{};

    // Group questions by subject
    for (final q in questions) {
      map.putIfAbsent(q.subject, () => []).add(q);
    }

    // Ensure all known available subjects appear even if syncing questions
    for (final subj in availableSubjects) {
      if (subj != 'All' && !map.containsKey(subj)) {
        map[subj] = [];
      }
    }

    // Filter by selectedSubject if not 'All'
    final filteredEntries =
        map.entries.where((entry) {
          if (selectedSubject != 'All' &&
              !entry.key.toLowerCase().contains(
                selectedSubject.toLowerCase(),
              )) {
            return false;
          }
          if (searchQuery.isNotEmpty) {
            final query = searchQuery.toLowerCase();
            final matchSubject = entry.key.toLowerCase().contains(query);
            final matchTopic = entry.value.any(
              (q) =>
                  q.topic.toLowerCase().contains(query) ||
                  q.prompt.toLowerCase().contains(query),
            );
            return matchSubject || matchTopic;
          }
          return true;
        }).toList()..sort((a, b) {
          final countCompare = b.value.length.compareTo(a.value.length);
          if (countCompare != 0) return countCompare;
          return a.key.compareTo(b.key);
        });

    return filteredEntries.map((e) {
      final qs = e.value;
      final years = qs.map((q) => q.year).toSet().toList()..sort();
      final yearRange = years.isEmpty
          ? 'All Years'
          : (years.length == 1
                ? '${years.first}'
                : '${years.first}–${years.last}');
      final answered = qs.where((q) => q.isAnswered).length;

      return _CourseSummary(
        title: e.key,
        totalQuestions: qs.length,
        answeredQuestions: answered,
        yearRange: yearRange,
        iconData: _getSubjectIcon(e.key),
        courseCode: qs.isNotEmpty ? qs.first.courseCode : null,
      );
    }).toList();
  }

  IconData _getSubjectIcon(String subject) {
    final lower = subject.toLowerCase();
    if (lower.contains('math') || lower.contains('calculus')) {
      return Icons.calculate_outlined;
    }
    if (lower.contains('physic')) return Icons.electric_bolt_outlined;
    if (lower.contains('chem')) return Icons.science_outlined;
    if (lower.contains('bio')) return Icons.biotech_outlined;
    if (lower.contains('english') || lower.contains('lit')) {
      return Icons.menu_book_rounded;
    }
    if (lower.contains('econ') ||
        lower.contains('acc') ||
        lower.contains('commerce')) {
      return Icons.trending_up_rounded;
    }
    if (lower.contains('gov') || lower.contains('civic')) {
      return Icons.account_balance_outlined;
    }
    if (lower.contains('comp') || lower.contains('cs')) {
      return Icons.terminal_rounded;
    }
    if (lower.contains('agric')) return Icons.agriculture_rounded;
    return Icons.school_outlined;
  }
}

class _CourseSummary {
  const _CourseSummary({
    required this.title,
    required this.totalQuestions,
    required this.answeredQuestions,
    required this.yearRange,
    required this.iconData,
    this.courseCode,
  });

  final String title;
  final int totalQuestions;
  final int answeredQuestions;
  final String yearRange;
  final IconData iconData;
  final String? courseCode;
}

class _CourseOverviewCard extends StatelessWidget {
  const _CourseOverviewCard({
    required this.courseSummary,
    required this.examCategory,
    this.selectedYear,
  });

  final _CourseSummary courseSummary;
  final ExamCategory examCategory;
  final int? selectedYear;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final hasQuestions = courseSummary.totalQuestions > 0;
    final progress = hasQuestions
        ? (courseSummary.answeredQuestions / courseSummary.totalQuestions)
              .clamp(0.0, 1.0)
        : 0.0;

    return PlatformHoverBuilder(
      builder: (context, isHovered, child) {
        return ShrinkableButton(
          onTap: () {
            AppFeedback.light();
            unawaited(
              context.router.push(
                CourseQuestionsRoute(
                  courseTitle: courseSummary.title,
                  courseCode: courseSummary.courseCode,
                  examCategory: examCategory,
                  initialYear: selectedYear,
                ),
              ),
            );
          },
          child: AnimatedContainer(
            duration: AppMotion.snappy,
            curve: AppMotion.snappyCurve,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isHovered
                  ? (isDark
                        ? colors.surfaceSecondary.withAlpha(245)
                        : colors.surfacePrimary.withAlpha(245))
                  : (isDark ? colors.surfaceSecondary : colors.surfacePrimary),
              borderRadius: BorderRadius.circular(AppRadius.panel),
              border: Border.all(
                color: isHovered
                    ? colors.primary.withAlpha(isDark ? 110 : 70)
                    : colors.primary.withAlpha(isDark ? 50 : 25),
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.black.withAlpha(
                    isHovered ? (isDark ? 80 : 20) : (isDark ? 60 : 12),
                  ),
                  blurRadius: isHovered ? 14 : 10,
                  offset: Offset(0, isHovered ? 5 : 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Subject Icon Container
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colors.primary.withAlpha(isDark ? 60 : 35),
                            colors.primary.withAlpha(isDark ? 30 : 15),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        border: Border.all(
                          color: colors.primary.withAlpha(isDark ? 80 : 45),
                        ),
                      ),
                      child: Icon(
                        courseSummary.iconData,
                        color: colors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Title and details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            courseSummary.title,
                            style: typography.callout.bold.copyWith(
                              color: colors.textPrimary,
                              fontSize: 15.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.primary.withAlpha(
                                    isDark ? 40 : 20,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.badge,
                                  ),
                                ),
                                child: Text(
                                  examCategory.displayName,
                                  style: typography.caption.bold.copyWith(
                                    color: colors.primary,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                hasQuestions
                                    ? '${courseSummary.totalQuestions} Questions • ${courseSummary.yearRange}'
                                    : 'Available for AI Practice',
                                style: typography.caption.medium.copyWith(
                                  color: colors.textSecondary,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: colors.textSecondary,
                    ),
                  ],
                ),
                if (hasQuestions) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.micro),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      backgroundColor: colors.primary.withAlpha(
                        isDark ? 30 : 20,
                      ),
                      valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${courseSummary.answeredQuestions} of ${courseSummary.totalQuestions} practiced',
                        style: typography.caption.regular.copyWith(
                          color: colors.textSecondary,
                          fontSize: 10.5,
                        ),
                      ),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: typography.caption.bold.copyWith(
                          color: colors.primary,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeroTrackBanner extends StatelessWidget {
  const _HeroTrackBanner({required this.userTrack});

  final String userTrack;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return BlocBuilder<PastQuestionsBloc, PastQuestionsState>(
      builder: (context, state) {
        final exam = state.selectedExam;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.dialog),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colors.primary.withAlpha(isDark ? 55 : 30),
                    colors.surfaceSecondary.withAlpha(isDark ? 180 : 230),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppRadius.dialog),
                border: Border.all(
                  color: colors.primary.withAlpha(isDark ? 80 : 45),
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.black.withAlpha(isDark ? 40 : 15),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary.withAlpha(isDark ? 60 : 30),
                          borderRadius: BorderRadius.circular(AppRadius.badge),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified_rounded,
                              size: 13,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              exam.displayName,
                              style: typography.caption.bold.copyWith(
                                color: colors.primary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${state.totalQuestions} questions available',
                        style: typography.caption.medium.copyWith(
                          color: colors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${exam.displayName} Question Bank',
                    style: typography.title3.bold.copyWith(
                      color: colors.textPrimary,
                      letterSpacing: -0.2,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Pick a subject to practice questions, filter by year, or run a full timed exam.',
                    style: typography.caption.regular.copyWith(
                      color: colors.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ShrinkableButton(
                          onTap: () async {
                            AppFeedback.light();
                            await QuizDuelMatchmakingSheet.show(
                              context,
                              initialSubject: state.selectedSubject != 'All'
                                  ? state.selectedSubject
                                  : 'Physics',
                              initialExamBoard: state.selectedExam.displayName,
                            );
                          },
                          child: Container(
                            height: 42,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [colors.secondary, colors.primary],
                              ),
                              borderRadius: BorderRadius.circular(
                                AppRadius.card,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: colors.black.withAlpha(
                                    isDark ? 50 : 20,
                                  ),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.flash_on_rounded,
                                  color: colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Duel a classmate',
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
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
