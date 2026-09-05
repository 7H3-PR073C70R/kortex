import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/planner/domain/logic/cram_workload_calculator.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_cubit.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_state.dart';
import 'package:kortex/src/features/planner/presentation/widgets/add_exam_modal_sheet.dart';
import 'package:kortex/src/features/planner/presentation/widgets/manage_exam_modal_sheet.dart';
import 'package:kortex/src/l10n/l10n.dart';

class ExamCountdownBanner extends StatelessWidget {
  const ExamCountdownBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    return BlocBuilder<CramPlannerCubit, CramPlannerState>(
      builder: (context, state) {
        final exam = state.selectedExam;

        if (exam == null) {
          return Semantics(
            container: true,
            button: true,
            label: l10n.addExamTitle,
            child: InkWell(
              onTap: () {
                unawaited(AddExamModalSheet.show(context));
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? colors.surfaceSecondary.withAlpha(160)
                      : colors.surfacePrimary.withAlpha(220),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: colors.primary.withAlpha(isDark ? 80 : 50),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.alarm_add_rounded,
                      color: colors.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.addExamTitle,
                        style: typography.callout.bold.copyWith(
                          color: colors.textPrimary,
                          fontSize: 14.5,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: colors.primary,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final days = exam.daysRemaining;
        final pace = state.dynamicDailyTarget;
        final urgency = state.urgencyLevel;

        final badgeColor = switch (urgency) {
          ExamUrgencyLevel.normal => colors.success,
          ExamUrgencyLevel.warning => colors.warning,
          ExamUrgencyLevel.critical => colors.error,
        };

        final bannerLabel =
            'Exam Countdown: ${l10n.daysUntilExam(days, exam.examName)}. '
            '${l10n.recommendedDailyPace(pace)}';

        return Semantics(
          container: true,
          button: true,
          label: bannerLabel,
          child: InkWell(
            onTap: () {
              unawaited(ManageExamModalSheet.show(context));
            },
            borderRadius: BorderRadius.circular(22),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark
                    ? colors.surfaceSecondary.withAlpha(170)
                    : colors.surfacePrimary.withAlpha(225),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: badgeColor.withAlpha(isDark ? 90 : 60),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: badgeColor.withAlpha(isDark ? 30 : 15),
                    blurRadius: 14,
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
                          color: badgeColor.withAlpha(isDark ? 40 : 25),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: badgeColor.withAlpha(100),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.timer_rounded,
                              size: 14,
                              color: badgeColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${exam.subjectTrack} Track',
                              style: typography.caption.bold.copyWith(
                                fontSize: 11,
                                color: badgeColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3.5,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? colors.surfacePrimary.withAlpha(150)
                                  : colors.surfaceSecondary.withAlpha(150),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: colors.surfaceBorder.withAlpha(90),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.tune_rounded,
                                  size: 12,
                                  color: colors.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Manage',
                                  style: typography.caption.medium.copyWith(
                                    color: colors.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(
                              Icons.add_rounded,
                              color: colors.textSecondary,
                              size: 20,
                            ),
                            tooltip: l10n.addExamTitle,
                            onPressed: () {
                              unawaited(AddExamModalSheet.show(context));
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ],
                  ),
                const SizedBox(height: 12),
                Text(
                  l10n.daysUntilExam(days, exam.examName),
                  style: typography.title3.bold.copyWith(
                    color: colors.textPrimary,
                    fontSize: 15.5,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.auto_graph_rounded,
                      size: 16,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l10n.recommendedDailyPace(pace),
                      style: typography.footnote.semiBold.copyWith(
                        color: colors.primary,
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
