import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/features/planner/domain/entities/exam_event_entity.dart';
import 'package:kortex/src/features/planner/domain/logic/cram_workload_calculator.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_cubit.dart';
import 'package:kortex/src/l10n/l10n.dart';

/// Consolidated study capacity workload bar and horizontal multi-milestone pill strip.
class MultiMilestonePillStrip extends StatelessWidget {
  const MultiMilestonePillStrip({
    required this.selectedExam,
    required this.allExams,
    required this.totalCombinedDailyTarget,
    required this.estimatedDailyMinutes,
    required this.topPriorityExamId,
    super.key,
  });

  final ExamEventEntity selectedExam;
  final List<ExamEventEntity> allExams;
  final int totalCombinedDailyTarget;
  final int estimatedDailyMinutes;
  final String? topPriorityExamId;

  static const _calculator = CramWorkloadCalculator();

  @override
  Widget build(BuildContext context) {
    final neural = context.neural;
    final typography = context.typography;
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Consolidated Study Capacity Bar
        if (allExams.length > 1 && totalCombinedDailyTarget > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: neural.obsidian800.withAlpha(150),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: neural.hairline),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.stacked_line_chart_rounded,
                    size: 13,
                    color: neural.emerald400,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.combinedTodayWorkload(
                        totalCombinedDailyTarget,
                        allExams
                            .where((e) => !e.isCompleted && !e.isPast)
                            .length,
                        estimatedDailyMinutes,
                      ),
                      style: typography.caption.medium.copyWith(
                        color: neural.slate300,
                        fontSize: 10.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Multi-Milestone Horizontal Pill Strip
        if (allExams.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...allExams.map((e) {
                    final isSelected = e.id == selectedExam.id;
                    final isPillPriority = e.id == topPriorityExamId;
                    final eUrgency = _calculator.getUrgencyLevel(
                      e.daysRemaining,
                      type: e.assessmentType,
                    );
                    final eColor = switch (eUrgency) {
                      ExamUrgencyLevel.normal => neural.emerald400,
                      ExamUrgencyLevel.warning => neural.amber400,
                      ExamUrgencyLevel.critical => neural.pink400,
                    };

                    final pillTimeStr = e.isCompleted
                        ? 'Done'
                        : (e.timeRemaining.inHours < 24 && !e.isPast
                            ? '${e.timeRemaining.inHours}h'
                            : '${e.daysRemaining}d');

                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        onTap: () {
                          AppFeedback.selection();
                          context.read<CramPlannerCubit>().selectExam(e.id);
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: AppMotion.snappy,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4.5,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? eColor.withAlpha(40)
                                : neural.obsidian800.withAlpha(160),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? eColor.withAlpha(160)
                                  : neural.hairline,
                              width: isSelected ? 1.4 : 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                e.assessmentType.icon,
                                size: 12,
                                color: isSelected ? eColor : neural.slate400,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                e.examName,
                                style: typography.caption.bold.copyWith(
                                  color: isSelected
                                      ? neural.slate100
                                      : neural.slate400,
                                  fontSize: 11,
                                ),
                              ),
                              if (isPillPriority) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.bolt_rounded,
                                  size: 11,
                                  color: neural.amber400,
                                ),
                              ],
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4.5,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: eColor.withAlpha(50),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  pillTimeStr,
                                  style: typography.caption.bold.copyWith(
                                    color: eColor,
                                    fontSize: 9.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  // Quick Add pill
                  InkWell(
                    onTap: () => unawaited(
                      context.router.push(
                        AddAcademicAssessmentRoute(),
                      ),
                    ),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4.5,
                      ),
                      decoration: BoxDecoration(
                        color: neural.obsidian800.withAlpha(140),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: neural.hairline),
                      ),
                      child: Icon(
                        Icons.add_rounded,
                        size: 13,
                        color: neural.slate400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
