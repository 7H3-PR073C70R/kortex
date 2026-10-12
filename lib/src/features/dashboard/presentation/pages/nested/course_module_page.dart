import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/curate_courses_cubit.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/course_module/course_module_decks_section.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/course_module/course_module_delete_dialog.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/course_module/course_module_document_ingestion_card.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/course_module/course_module_exam_countdown_card.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/course_module/course_module_header_banner.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/course_module/course_module_past_questions_section.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/course_module/course_module_subject_mapper.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_state.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_cubit.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_bloc.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_event.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_app_bar.dart';
import 'package:kortex/src/shared/widgets/app_breadcrumbs.dart';

@RoutePage()
class CourseModulePage extends StatelessWidget {
  const CourseModulePage({
    @PathParam('courseId') required this.courseId,
    required this.courseCode,
    required this.courseTitle,
    this.pastQuestionsBloc,
    this.cramPlannerCubit,
    this.curateCoursesCubit,
    this.dashboardBloc,
    this.decksBloc,
    super.key,
  });

  final String courseId;
  final String courseCode;
  final String courseTitle;
  final PastQuestionsBloc? pastQuestionsBloc;
  final CramPlannerCubit? cramPlannerCubit;
  final CurateCoursesCubit? curateCoursesCubit;
  final DashboardBloc? dashboardBloc;
  final DecksBloc? decksBloc;

  static String cleanCode(String code) =>
      CourseModuleSubjectMapper.cleanCode(code);

  @override
  Widget build(BuildContext context) {
    final currentProfile = context.read<AuthBloc>().state.userProfile;
    final examCategory = CourseModuleSubjectMapper.getExamCategory(
      track: currentProfile?.targetTrack,
      courseTitle: courseTitle,
      courseCode: courseCode,
    );
    final sanitizedCode = CourseModuleSubjectMapper.cleanCode(courseCode);
    final mappedSubject = CourseModuleSubjectMapper.mapCourseToSubject(
      courseTitle,
      sanitizedCode,
    );

    final effectivePqBloc = pastQuestionsBloc ??
        (locator.isRegistered<PastQuestionsBloc>()
            ? locator<PastQuestionsBloc>()
            : null);

    final effectiveCramCubit = cramPlannerCubit ??
        (locator.isRegistered<CramPlannerCubit>()
            ? locator<CramPlannerCubit>()
            : null);

    return MultiBlocProvider(
      providers: [
        if (effectivePqBloc != null)
          BlocProvider<PastQuestionsBloc>.value(
            value: effectivePqBloc
              ..add(
                LoadPastQuestionsEvent(
                  examCategory: examCategory,
                  subject: mappedSubject,
                  courseId: courseId,
                  courseCode: sanitizedCode,
                ),
              ),
          )
        else
          BlocProvider<PastQuestionsBloc>(
            create: (_) => locator<PastQuestionsBloc>()
              ..add(
                LoadPastQuestionsEvent(
                  examCategory: examCategory,
                  subject: mappedSubject,
                  courseId: courseId,
                  courseCode: sanitizedCode,
                ),
              ),
          ),
        if (effectiveCramCubit != null)
          BlocProvider<CramPlannerCubit>.value(
            value: effectiveCramCubit,
          ),
      ],
      child: _CourseModuleView(
        courseId: courseId,
        courseCode: sanitizedCode,
        courseTitle: courseTitle,
        mappedSubject: mappedSubject,
        examCategory: examCategory,
        curateCoursesCubit: curateCoursesCubit,
        dashboardBloc: dashboardBloc,
        decksBloc: decksBloc,
      ),
    );
  }
}

class _CourseModuleView extends StatelessWidget {
  const _CourseModuleView({
    required this.courseId,
    required this.courseCode,
    required this.courseTitle,
    required this.mappedSubject,
    required this.examCategory,
    this.curateCoursesCubit,
    this.dashboardBloc,
    this.decksBloc,
  });

  final String courseId;
  final String courseCode;
  final String courseTitle;
  final String mappedSubject;
  final ExamCategory examCategory;
  final CurateCoursesCubit? curateCoursesCubit;
  final DashboardBloc? dashboardBloc;
  final DecksBloc? decksBloc;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final effectiveDecksBloc = decksBloc ??
        (context.read<DecksBloc?>() ??
            (locator.isRegistered<DecksBloc>() ? locator<DecksBloc>() : null));

    return BlocBuilder<DecksBloc, DecksState>(
      bloc: effectiveDecksBloc,
      builder: (context, decksState) {
        final allDecks = decksState.allDecks;
        final associatedDecks = allDecks.where((d) {
          if (d.courseId != null && d.courseId == courseId) return true;
          if (d.courseCode != null &&
              d.courseCode!.isNotEmpty &&
              d.courseCode!.toLowerCase() == courseCode.toLowerCase()) {
            return true;
          }
          if (d.subject.toLowerCase() == courseTitle.toLowerCase() ||
              d.subject.toLowerCase() == mappedSubject.toLowerCase()) {
            return true;
          }
          return false;
        }).toList();

        final totalCards = associatedDecks.fold<int>(
          0,
          (sum, d) => sum + d.totalCards,
        );
        final totalDue = associatedDecks.fold<int>(
          0,
          (sum, d) => sum + d.dueCards,
        );

        return Scaffold(
          backgroundColor: colors.backgroundPrimary,
          appBar: AppAdaptiveAppBar(
            backgroundColor: colors.backgroundPrimary,
            breadcrumbs: [
              AppBreadcrumbItem(
                label: 'Dashboard',
                onTap: () {
                  if (context.router.canPop()) {
                    context.router.pop();
                  }
                },
              ),
              AppBreadcrumbItem(
                label: courseCode,
              ),
            ],
            title: Text(
              courseCode,
              style: typography.title3.bold.copyWith(
                color: colors.textPrimary,
                fontSize: 17.5,
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: colors.error.withAlpha(200),
                  size: 22,
                ),
                tooltip: 'Delete Course',
                onPressed: () => CourseModuleDeleteDialog.confirmDelete(
                  context: context,
                  courseId: courseId,
                  courseCode: courseCode,
                  courseTitle: courseTitle,
                  deckCount: associatedDecks.length,
                  curateCoursesCubit: curateCoursesCubit,
                  dashboardBloc: dashboardBloc,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Hero Course Header Banner
                      CourseModuleHeaderBanner(
                        courseCode: courseCode,
                        courseTitle: courseTitle,
                        examCategory: examCategory,
                        deckCount: associatedDecks.length,
                        cardCount: totalCards,
                        dueCount: totalDue,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 16),

                      // 1.5. Course Exam Countdown
                      CourseModuleExamCountdownCard(
                        courseCode: courseCode,
                        courseTitle: courseTitle,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 20),

                      // 2. Document Ingestion Section
                      CourseModuleDocumentIngestionCard(
                        courseId: courseId,
                        courseCode: courseCode,
                        courseTitle: courseTitle,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 28),

                      // 3. Associated Study Decks Section
                      CourseModuleDecksSection(
                        decks: associatedDecks,
                        courseId: courseId,
                        courseCode: courseCode,
                        courseTitle: courseTitle,
                        mappedSubject: mappedSubject,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 28),

                      // 4. Official Past Papers & CBT Questions Section
                      CourseModulePastQuestionsSection(
                        courseId: courseId,
                        courseCode: courseCode,
                        courseTitle: courseTitle,
                        mappedSubject: mappedSubject,
                        examCategory: examCategory,
                        isDark: isDark,
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
  }
}
