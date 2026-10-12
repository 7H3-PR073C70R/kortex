import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/planner/domain/entities/exam_event_entity.dart';
import 'package:kortex/src/features/planner/domain/logic/cram_workload_calculator.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_cubit.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_state.dart';
import 'package:kortex/src/features/planner/presentation/widgets/manage_exam/manage_exam_actions_dock.dart';
import 'package:kortex/src/features/planner/presentation/widgets/manage_exam/manage_exam_detail_card.dart';
import 'package:kortex/src/features/planner/presentation/widgets/manage_exam/manage_exam_milestones_list.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_sheet.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';

export 'manage_exam/conclude_grade_modal_sheet.dart';
export 'manage_exam/manage_exam_actions_dock.dart';
export 'manage_exam/manage_exam_detail_card.dart';
export 'manage_exam/manage_exam_milestones_list.dart';

/// Modal sheet for managing academic milestones, viewing readiness, switching tracked exams,
/// or concluding, postponing, and cancelling assessments.
class ManageExamModalSheet extends StatelessWidget {
  const ManageExamModalSheet({
    this.scopedCourseCode,
    this.scopedCourseTitle,
    this.initialExamId,
    super.key,
  });

  final String? scopedCourseCode;
  final String? scopedCourseTitle;
  final String? initialExamId;

  static const _calculator = CramWorkloadCalculator();

  static Future<void> show(
    BuildContext context, {
    String? scopedCourseCode,
    String? scopedCourseTitle,
    String? initialExamId,
    CramPlannerCubit? cubit,
  }) {
    final cramPlannerCubit = cubit ?? context.read<CramPlannerCubit>();
    return AppAdaptiveSheet.showModal<void>(
      context: context,
      maxWidth: 600,
      builder: (sheetContext) => BlocProvider.value(
        value: cramPlannerCubit,
        child: ManageExamModalSheet(
          scopedCourseCode: scopedCourseCode,
          scopedCourseTitle: scopedCourseTitle,
          initialExamId: initialExamId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    return BlocBuilder<CramPlannerCubit, CramPlannerState>(
      builder: (context, state) {
        final cleanCode = (scopedCourseCode ?? '').trim().toLowerCase();
        final cleanTitle = (scopedCourseTitle ?? '').trim().toLowerCase();
        final isScoped = cleanCode.isNotEmpty || cleanTitle.isNotEmpty;

        final allExams = isScoped
            ? state.activeExams.where((e) {
                final track = e.subjectTrack.toLowerCase();
                final name = e.examName.toLowerCase();
                return (cleanCode.isNotEmpty &&
                        (track.contains(cleanCode) ||
                            name.contains(cleanCode))) ||
                    (cleanTitle.isNotEmpty &&
                        (track.contains(cleanTitle) ||
                            name.contains(cleanTitle)));
              }).toList()
            : state.activeExams;

        final ExamEventEntity? resolvedExam;
        if (initialExamId != null &&
            allExams.any((e) => e.id == initialExamId)) {
          resolvedExam = allExams.firstWhere((e) => e.id == initialExamId);
        } else if (state.selectedExam != null &&
            allExams.any((e) => e.id == state.selectedExam!.id)) {
          resolvedExam = state.selectedExam;
        } else {
          resolvedExam = allExams.firstOrNull;
        }

        final cubit = context.read<CramPlannerCubit>();

        if (resolvedExam == null) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.dialog),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isScoped
                        ? 'No Active Assessment for ${scopedCourseCode ?? scopedCourseTitle}'
                        : 'No Active Assessment',
                    style: typography.title3.bold.copyWith(
                      color: colors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  AppButton(
                    text: l10n.addExamTitle,
                    onPressed: () {
                      final nav = Navigator.of(context)..pop();
                      unawaited(
                        nav.context.router.push(
                          AddAcademicAssessmentRoute(
                            preselectedCourseCode: scopedCourseCode,
                            preselectedCourseTitle: scopedCourseTitle,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        }

        final exam = resolvedExam;
        final days = exam.daysRemaining;
        final pace = state.dynamicDailyTarget;
        final urgency = _calculator.getUrgencyLevel(
          days,
          type: exam.assessmentType,
        );
        final badgeColor = switch (urgency) {
          ExamUrgencyLevel.normal => colors.primary,
          ExamUrgencyLevel.warning => colors.warning,
          ExamUrgencyLevel.critical => colors.error,
        };

        final isDesktop = AppAdaptiveSheet.isDesktopOrWeb(context);

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 34),
            decoration: BoxDecoration(
              color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
              borderRadius: isDesktop
                  ? BorderRadius.circular(AppRadius.dialog)
                  : const BorderRadius.vertical(
                      top: Radius.circular(AppRadius.dialog),
                    ),
              border: Border.all(
                color: colors.primary.withAlpha(isDark ? 60 : 30),
              ),
              boxShadow: isDesktop
                  ? [
                      BoxShadow(
                        color: colors.black.withAlpha(isDark ? 100 : 35),
                        blurRadius: 28,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Manage Academic Milestones',
                      style: typography.title3.bold.copyWith(
                        color: colors.textPrimary,
                        fontSize: 18,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: colors.textSecondary,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Active Exam Card
                ManageExamDetailCard(
                  exam: exam,
                  pace: pace,
                  badgeColor: badgeColor,
                ),
                const SizedBox(height: 18),

                // Milestones Switch List & Timetable Link
                ManageExamMilestonesList(
                  currentExamId: exam.id,
                  allExams: allExams,
                  cubit: cubit,
                  scopedCourseCode: scopedCourseCode,
                  scopedCourseTitle: scopedCourseTitle,
                ),
                const SizedBox(height: 14),

                // Actions Dock
                ManageExamActionsDock(
                  exam: exam,
                  cubit: cubit,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
