import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/dashboard/domain/entities/dashboard_feed_entity.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_bloc.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_event.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_state.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_duel_cubit.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/add_past_question_modal_sheet.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/board/board_course_grouping_helper.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/board/board_desktop_workspace.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/board/board_hero_track_banner.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/board/board_search_filter_header.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/board/course_overview_card.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/past_questions_test_config_sheet.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/quiz_shell.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_app_bar.dart';
import 'package:kortex/src/shared/widgets/app_breadcrumbs.dart';
import 'package:kortex/src/shared/widgets/shimmer_placeholder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

export 'package:kortex/src/features/quiz/presentation/widgets/board/board_course_grouping_helper.dart';
export 'package:kortex/src/features/quiz/presentation/widgets/board/board_desktop_workspace.dart';
export 'package:kortex/src/features/quiz/presentation/widgets/board/board_hero_track_banner.dart';
export 'package:kortex/src/features/quiz/presentation/widgets/board/board_search_filter_header.dart';
export 'package:kortex/src/features/quiz/presentation/widgets/board/course_overview_card.dart';

@RoutePage()
class PastQuestionsBoardPage extends StatelessWidget {
  const PastQuestionsBoardPage({
    @queryParam this.initialExamCode,
    @queryParam this.initialSubject,
    this.pastQuestionsBloc,
    this.quizDuelCubit,
    super.key,
  });

  final String? initialExamCode;
  final String? initialSubject;
  final PastQuestionsBloc? pastQuestionsBloc;
  final QuizDuelCubit? quizDuelCubit;

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
    final userProfile = context.read<AuthBloc?>()?.state.userProfile;
    final userTrack = userProfile?.targetTrack;
    final dashboardFeed = context.read<DashboardBloc?>()?.state.feed;
    final enrolledCourses =
        dashboardFeed?.curatedCourses ?? const <CuratedCourseEntity>[];
    final enrolledCodes = enrolledCourses
        .map((c) => c.courseCode)
        .where((code) => code.trim().isNotEmpty)
        .toList();
    final enrolledIds = enrolledCourses.map((c) => c.id).toList();

    final initialExam = resolveExamCategory(initialExamCode, userTrack);

    return MultiBlocProvider(
      providers: [
        BlocProvider<PastQuestionsBloc>(
          create: (_) =>
              pastQuestionsBloc ??
              (locator<PastQuestionsBloc>()
                ..add(
                  LoadPastQuestionsEvent(
                    examCategory: initialExam,
                    subject: initialSubject,
                    isScopedToUserTrack: true,
                    userTrack: userTrack ?? 'WAEC',
                    enrolledCourseCodes: enrolledCodes,
                    enrolledCourseIds: enrolledIds,
                  ),
                )),
        ),
        BlocProvider<QuizDuelCubit>(
          create: (_) => quizDuelCubit ?? locator<QuizDuelCubit>(),
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
      () => () => debounceTimer.value?.cancel(),
      const [],
    );

    final selectedCourseTitle = useState<String?>(null);
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: isDark
          ? colors.backgroundPrimary
          : colors.surfacePrimary,
      appBar: AppAdaptiveAppBar(
        breadcrumbs: [
          AppBreadcrumbItem(
            label: 'Study Hub',
            onTap: () {
              if (context.router.canPop()) {
                context.router.pop();
              }
            },
          ),
          const AppBreadcrumbItem(
            label: 'Past Questions',
          ),
        ],
        titleText: 'Past Questions & Practice',
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
        child: BlocBuilder<PastQuestionsBloc, PastQuestionsState>(
          builder: (context, state) {
            final courses = BoardCourseGroupingHelper.groupQuestionsByCourse(
              questions: state.questions,
              availableSubjects: state.availableSubjects,
              selectedSubject: state.selectedSubject,
              searchQuery: state.searchQuery,
            );

            final activeTitle = (selectedCourseTitle.value != null &&
                    courses.any((c) => c.title == selectedCourseTitle.value))
                ? selectedCourseTitle.value!
                : (courses.isNotEmpty ? courses.first.title : '');

            final activeCourse = courses.firstWhere(
              (c) => c.title == activeTitle,
              orElse: () => CourseSummary(
                title: activeTitle,
                totalQuestions: 0,
                answeredQuestions: 0,
                yearRange: 'All',
                iconData: Icons.school_outlined,
              ),
            );

            final courseQuestions = state.questions
                .where((q) =>
                    q.subject.toLowerCase() == activeTitle.toLowerCase())
                .toList();

            if (isDesktop) {
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // LEFT PANEL: Subject Directory & Filters
                    SizedBox(
                      width: 440,
                      child: Column(
                        children: [
                          BoardHeroTrackBanner(userTrack: userTrack),
                          BoardSearchFilterHeader(
                            searchController: searchController,
                            padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
                            hintText: 'Search subjects...',
                            onSearchChanged: (query) {
                              debounceTimer.value?.cancel();
                              debounceTimer.value = Timer(
                                const Duration(milliseconds: 300),
                                () {
                                  if (context.mounted) {
                                    context.read<PastQuestionsBloc>().add(
                                          LoadPastQuestionsEvent(
                                              searchQuery: query),
                                        );
                                  }
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: state.status == PastQuestionsStatus.loading
                                ? ListView.separated(
                                    itemCount: 4,
                                    separatorBuilder: (context, index) =>
                                        const SizedBox(height: 10),
                                    itemBuilder: (context, index) =>
                                        const ShimmerPlaceholder(
                                      height: 90,
                                      borderRadius: AppRadius.panel,
                                    ),
                                  )
                                : (courses.isEmpty
                                    ? const QuizEmptyState(
                                        icon: Icons.search_off_rounded,
                                        headline: 'No matching subjects',
                                        message:
                                            'Try a different filter or search.',
                                      )
                                    : ListView.separated(
                                        itemCount: courses.length,
                                        separatorBuilder: (context, index) =>
                                            const SizedBox(height: 10),
                                        itemBuilder: (context, index) {
                                          final course = courses[index];
                                          return CourseOverviewCard(
                                            courseSummary: course,
                                            examCategory: state.selectedExam,
                                            selectedYear: state.selectedYear,
                                            isSelected:
                                                course.title == activeTitle,
                                            onTap: () {
                                              selectedCourseTitle.value =
                                                  course.title;
                                            },
                                          );
                                        },
                                      )),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),

                    // RIGHT PANEL: Active Subject Questions & Practice Workspace
                    Expanded(
                      child: BoardDesktopWorkspace(
                        activeCourse: activeCourse,
                        courseQuestions: courseQuestions,
                        state: state,
                      ),
                    ),
                  ],
                ),
              );
            }

            // MOBILE SINGLE-COLUMN VIEW
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Column(
                  children: [
                    BoardHeroTrackBanner(userTrack: userTrack),
                    BoardSearchFilterHeader(
                      searchController: searchController,
                      onSearchChanged: (query) {
                        debounceTimer.value?.cancel();
                        debounceTimer.value = Timer(
                          const Duration(milliseconds: 300),
                          () {
                            if (context.mounted) {
                              context.read<PastQuestionsBloc>().add(
                                    LoadPastQuestionsEvent(
                                        searchQuery: query),
                                  );
                            }
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: state.status == PastQuestionsStatus.loading
                          ? ListView.separated(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              itemCount: 4,
                              separatorBuilder: (_, index) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (_, index) =>
                                  const ShimmerPlaceholder(
                                height: 108,
                                borderRadius: AppRadius.panel,
                              ),
                            )
                          : (courses.isEmpty
                              ? const QuizEmptyState(
                                  icon: Icons.search_off_rounded,
                                  headline: 'No subjects match your filters',
                                  message:
                                      'Try a different search, clear the subject filter, or change the exam year.',
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(
                                      16, 8, 16, 24),
                                  physics: const ClampingScrollPhysics(),
                                  itemCount: courses.length,
                                  separatorBuilder: (_, index) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final course = courses[index];
                                    final card = CourseOverviewCard(
                                      courseSummary: course,
                                      examCategory: state.selectedExam,
                                      selectedYear: state.selectedYear,
                                    );
                                    if (index >= 10) return card;
                                    return QuizStaggeredFade(
                                      index: index,
                                      distance: 10,
                                      reduceMotion: reduceMotion,
                                      child: card,
                                    );
                                  },
                                )),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: BlocBuilder<PastQuestionsBloc, PastQuestionsState>(
        builder: (context, state) {
          if (state.status == PastQuestionsStatus.loading ||
              state.totalQuestions == 0 ||
              isDesktop) {
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
}
