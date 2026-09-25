import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/planner/domain/entities/exam_event_entity.dart';
import 'package:kortex/src/features/planner/domain/logic/cram_workload_calculator.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_cubit.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_state.dart';
import 'package:intl/intl.dart';
import 'package:kortex/src/features/planner/presentation/widgets/add_exam_modal_sheet.dart';
import 'package:kortex/src/features/planner/presentation/widgets/cancel_exam_modal_sheet.dart';
import 'package:kortex/src/features/planner/presentation/widgets/postpone_exam_modal_sheet.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';
import 'package:kortex/src/shared/widgets/app_dialog.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';

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
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.transparent,
      builder: (sheetContext) => BlocProvider.value(
        value: context.read<CramPlannerCubit>(),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ManageExamModalSheet(
              scopedCourseCode: scopedCourseCode,
              scopedCourseTitle: scopedCourseTitle,
              initialExamId: initialExamId,
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    CramPlannerCubit cubit,
    ExamEventEntity exam,
  ) {
    unawaited(
      AppDialog.show<bool>(
        context: context,
        title: 'Delete Assessment Countdown?',
        description:
            'Are you sure you want to remove the countdown for "${exam.examName}"? You can always add a new one anytime.',
        primaryActionText: 'Delete Countdown',
        isDestructive: true,
        onPrimaryAction: () async {
          AppFeedback.heavy();
          await cubit.deleteExamCountdown(exam.id);
        },
        secondaryActionText: 'Cancel',
      ).then((didDelete) {
        if (didDelete == true && context.mounted) {
          context.showSnackBar(
            message: 'Countdown for "${exam.examName}" deleted',
            type: SnackBarType.success,
          );
          Navigator.of(context).pop();
        }
      }),
    );
  }

  void _showCompleteDialog(
    BuildContext context,
    CramPlannerCubit cubit,
    ExamEventEntity exam,
  ) {
    var score = 85.0;
    var rollover = true;

    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: context.colors.transparent,
        builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setModalState) {
            final colors = ctx.colors;
            final typography = ctx.typography;
            final isDark = ctx.isDarkMode;
            final l10n = ctx.l10n;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 30),
                decoration: BoxDecoration(
                  color:
                      isDark ? colors.surfaceSecondary : colors.surfacePrimary,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.dialog),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Conclude & Record Grade',
                          style: typography.title3.bold.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Record your achieved score for "${exam.examName}". Any difficult or missed flashcards can be rolled over to your continuous review queue.',
                      style: typography.caption.regular.copyWith(
                        color: colors.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Achieved Score',
                          style: typography.body.semiBold.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primary.withAlpha(isDark ? 50 : 25),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: colors.primary.withAlpha(100),
                            ),
                          ),
                          child: Text(
                            '${score.toInt()}%',
                            style: typography.callout.bold.copyWith(
                              color: colors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: score,
                      max: 100,
                      divisions: 100,
                      activeColor: colors.primary,
                      onChanged: (val) {
                        setModalState(() {
                          score = val;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: rollover,
                      activeColor: colors.primary,
                      title: Text(
                        'Rollover unmastered cards to Final Exam review',
                        style: typography.caption.medium.copyWith(
                          color: colors.textPrimary,
                          fontSize: 12.5,
                        ),
                      ),
                      onChanged: (val) {
                        setModalState(() {
                          rollover = val ?? true;
                        });
                      },
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () async {
                        AppFeedback.celebration();
                        await cubit.completeAssessment(
                          examId: exam.id,
                          scorePercent: score / 100.0,
                          rolloverWeakCards: rollover,
                        );
                        if (ctx.mounted) {
                          Navigator.of(ctx).pop();
                          ctx.showSnackBar(
                            message:
                                'Assessment recorded with ${score.toInt()}% score!',
                            type: SnackBarType.success,
                          );
                        }
                      },
                      child: Text(l10n.plannerSaveArchiveMilestone),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ));
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
                      Navigator.of(context).pop();
                      unawaited(
                        AddExamModalSheet.show(
                          context,
                          preselectedCourseCode: scopedCourseCode,
                          preselectedCourseTitle: scopedCourseTitle,
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

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 34),
            decoration: BoxDecoration(
              color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.dialog),
              ),
              border: Border.all(
                color: colors.primary.withAlpha(isDark ? 60 : 30),
              ),
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
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? colors.surfacePrimary.withAlpha(180)
                        : colors.surfaceSecondary.withAlpha(120),
                    borderRadius: AppRadius.radiusPanel,
                    border: Border.all(
                      color: badgeColor.withAlpha(isDark ? 90 : 50),
                      width: 1.2,
                    ),
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
                              color: badgeColor.withAlpha(isDark ? 40 : 25),
                              borderRadius: AppRadius.radiusBadge,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  exam.assessmentType.icon,
                                  size: 13,
                                  color: badgeColor,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  '${exam.assessmentType.displayName.toUpperCase()} • ${exam.subjectTrack}',
                                  style: typography.caption.bold.copyWith(
                                    color: badgeColor,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${exam.targetDate.year}-${exam.targetDate.month.toString().padLeft(2, '0')}-${exam.targetDate.day.toString().padLeft(2, '0')}',
                            style: typography.caption.medium.copyWith(
                              color: colors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        exam.examName,
                        style: typography.callout.bold.copyWith(
                          color: colors.textPrimary,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (exam.isPostponed)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colors.warning.withAlpha(isDark ? 50 : 25),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: colors.warning.withAlpha(80),
                                ),
                              ),
                              child: Text(
                                exam.originalTargetDate != null
                                    ? 'Postponed from ${DateFormat("MMM d").format(exam.originalTargetDate!)}'
                                    : 'Postponed',
                                style: typography.caption.bold.copyWith(
                                  color: colors.warning,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          if (exam.isCancelled)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colors.error.withAlpha(isDark ? 50 : 25),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: colors.error.withAlpha(80),
                                ),
                              ),
                              child: Text(
                                'Cancelled',
                                style: typography.caption.bold.copyWith(
                                  color: colors.error,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          if (exam.isCompleted)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colors.primary.withAlpha(isDark ? 50 : 25),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: colors.primary.withAlpha(80),
                                ),
                              ),
                              child: Text(
                                'Completed: ${exam.achievedScorePercent != null ? (exam.achievedScorePercent! > 1.0 ? exam.achievedScorePercent! : exam.achievedScorePercent! * 100).toInt() : 100}%',
                                style: typography.caption.bold.copyWith(
                                  color: colors.primary,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.surfaceBorder.withAlpha(isDark ? 80 : 50),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${(exam.effectiveWeightPercent > 1.0 ? exam.effectiveWeightPercent : exam.effectiveWeightPercent * 100).toInt()}% of grade',
                              style: typography.caption.semiBold.copyWith(
                                color: colors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          if (exam.scopedTopics.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colors.surfaceBorder.withAlpha(isDark ? 80 : 50),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Topics: ${exam.scopedTopics.join(", ")}',
                                style: typography.caption.regular.copyWith(
                                  color: colors.textSecondary,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Bimodal Knowledge Calibration & Readiness Gauge
                      () {
                        final readiness = _calculator.calculateExamReadinessScore(
                          totalCards: exam.totalCardsCount,
                          masteredCards: exam.masteredCardsCount,
                          averageStability: 18,
                          daysRemaining: exam.daysRemaining,
                          totalLapses: exam.totalLapses,
                          empiricalQuizScorePercent: exam.achievedScorePercent,
                        );
                        final readinessColor = readiness >= 75
                            ? colors.success
                            : (readiness >= 50 ? colors.warning : colors.error);
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surfaceBorder.withAlpha(isDark ? 50 : 30),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.psychology_outlined,
                                        size: 14,
                                        color: readinessColor,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        exam.achievedScorePercent != null
                                            ? 'Bimodal Readiness (FSRS & Quiz)'
                                            : 'Predicted FSRS Retention',
                                        style: typography.caption.bold.copyWith(
                                          color: colors.textSecondary,
                                          fontSize: 10.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '${readiness.toInt()}%',
                                    style: typography.caption.bold.copyWith(
                                      color: readinessColor,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: readiness / 100.0,
                                  backgroundColor: colors.surfaceBorder.withAlpha(80),
                                  valueColor: AlwaysStoppedAnimation<Color>(readinessColor),
                                  minHeight: 4,
                                ),
                              ),
                            ],
                          ),
                        );
                      }(),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 15,
                            color: badgeColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            exam.formattedSubDailyCountdown,
                            style: typography.footnote.semiBold.copyWith(
                              color: badgeColor,
                              fontSize: 13,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.auto_graph_rounded,
                            size: 15,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            l10n.recommendedDailyPace(pace),
                            style: typography.footnote.semiBold.copyWith(
                              color: colors.primary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // If multiple exams exist, show switch list
                if (allExams.length > 1) ...[
                  Text(
                    isScoped
                        ? '${scopedCourseCode ?? scopedCourseTitle} Milestones (${allExams.length})'
                        : 'All Tracked Milestones (${allExams.length})',
                    style: typography.subhead.bold.copyWith(
                      color: colors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...allExams.map((e) {
                    final isSelected = e.id == exam.id;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: PlatformHoverBuilder(
                        builder: (context, isHovered, child) {
                          return AnimatedContainer(
                            duration: AppMotion.snappy,
                            curve: Curves.easeOutCubic,
                            decoration: BoxDecoration(
                              borderRadius: AppRadius.radiusCard,
                              color: isSelected
                                  ? colors.primary.withAlpha(isDark ? 40 : 20)
                                  : (isHovered
                                        ? (isDark
                                              ? colors.surfacePrimary.withAlpha(
                                                  150,
                                                )
                                              : colors.surfaceSecondary
                                                    .withAlpha(130))
                                        : (isDark
                                              ? colors.surfacePrimary.withAlpha(
                                                  100,
                                                )
                                              : colors.surfaceSecondary
                                                    .withAlpha(80))),
                              border: Border.all(
                                color: isSelected
                                    ? colors.primary
                                    : (isHovered
                                          ? colors.primary.withAlpha(120)
                                          : colors.surfaceBorder.withAlpha(80)),
                              ),
                            ),
                            child: InkWell(
                              onTap: () {
                                unawaited(HapticFeedback.selectionClick());
                                cubit.selectExam(e.id);
                              },
                              borderRadius: AppRadius.radiusCard,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                child: child,
                              ),
                            ),
                          );
                        },
                        child: Row(
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_off_rounded,
                              size: 18,
                              color: isSelected
                                  ? colors.primary
                                  : colors.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              e.assessmentType.icon,
                              size: 14,
                              color: isSelected
                                  ? colors.primary
                                  : colors.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                e.examName,
                                style: typography.body.semiBold.copyWith(
                                  color: isSelected
                                      ? colors.primary
                                      : colors.textPrimary,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Text(
                              '${e.daysRemaining}d left',
                              style: typography.caption.medium.copyWith(
                                color: colors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                ],

                // Open Full Timetable Action
                PlatformHoverBuilder(
                  builder: (context, isHovered, child) {
                    return AnimatedContainer(
                      duration: AppMotion.snappy,
                      curve: Curves.easeOutCubic,
                      decoration: BoxDecoration(
                        color: colors.primary.withAlpha(
                          isHovered ? (isDark ? 80 : 45) : (isDark ? 50 : 25),
                        ),
                        borderRadius: AppRadius.radiusCard,
                        border: Border.all(
                          color: colors.primary.withAlpha(
                            isHovered ? 160 : 100,
                          ),
                        ),
                      ),
                      child: InkWell(
                        onTap: () {
                          Navigator.of(context).pop();
                          unawaited(
                            context.router.push(const ExamTimetableRoute()),
                          );
                        },
                        borderRadius: AppRadius.radiusCard,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.calendar_month_rounded,
                        size: 18,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'View Full Timetable & Pacing',
                        style: typography.callout.bold.copyWith(
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Primary Status Action
                if (exam.isCancelled)
                  FilledButton.icon(
                    onPressed: () async {
                      AppFeedback.heavy();
                      await cubit.restoreAssessment(exam.id);
                      if (context.mounted) {
                        context.showSnackBar(
                          message: '${exam.examName} restored to active study schedule',
                          type: SnackBarType.success,
                        );
                      }
                    },
                    icon: const Icon(Icons.restore_rounded, size: 17),
                    label: const Text('Restore to Active Schedule'),
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.radiusCard,
                      ),
                    ),
                  )
                else if (exam.isCompleted)
                  OutlinedButton.icon(
                    onPressed: () async {
                      AppFeedback.selection();
                      await cubit.reopenAssessment(exam.id);
                      if (context.mounted) {
                        context.showSnackBar(
                          message: '${exam.examName} reopened for study planning',
                        );
                      }
                    },
                    icon: const Icon(Icons.replay_rounded, size: 16),
                    label: Text(l10n.plannerReopenMilestone),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: colors.primary.withAlpha(120)),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.radiusCard,
                      ),
                    ),
                  )
                else
                  FilledButton.icon(
                    onPressed: () => _showCompleteDialog(context, cubit, exam),
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 17),
                    label: Text(l10n.plannerConcludeMilestone),
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          exam.isPast ? colors.warning : colors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.radiusCard,
                      ),
                    ),
                  ),
                const SizedBox(height: 10),

                // Postpone & Cancel Actions Row (for uncompleted exams)
                if (!exam.isCompleted && !exam.isCancelled) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            unawaited(
                              PostponeExamModalSheet.show(
                                context,
                                exam: exam,
                              ),
                            );
                          },
                          icon: Icon(Icons.update_rounded, size: 16, color: colors.warning),
                          label: Text(
                            'Postpone',
                            style: TextStyle(color: colors.warning),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: colors.warning.withAlpha(120)),
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.radiusCard,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            unawaited(
                              CancelExamModalSheet.show(
                                context,
                                exam: exam,
                              ),
                            );
                          },
                          icon: Icon(Icons.cancel_outlined, size: 16, color: colors.error),
                          label: Text(
                            'Cancel',
                            style: TextStyle(color: colors.error),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: colors.error.withAlpha(120)),
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.radiusCard,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],

                // Action Buttons Row: Edit and Add
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          unawaited(
                            AddExamModalSheet.show(
                              context,
                              initialExam: exam,
                            ),
                          );
                        },
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: Text(l10n.commonEdit),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: colors.surfaceBorder),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.radiusCard,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          unawaited(AddExamModalSheet.show(context));
                        },
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: Text(l10n.commonAddNew),
                        style: FilledButton.styleFrom(
                          backgroundColor: colors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.radiusCard,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Delete Button
                TextButton.icon(
                  onPressed: () => _confirmDelete(context, cubit, exam),
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 16,
                    color: colors.error,
                  ),
                  label: Text(
                    'Delete This Countdown',
                    style: typography.caption.bold.copyWith(
                      color: colors.error,
                      fontSize: 13,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
