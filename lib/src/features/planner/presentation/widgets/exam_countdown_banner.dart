import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/planner/domain/logic/cram_workload_calculator.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_cubit.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_state.dart';
import 'package:kortex/src/features/planner/presentation/widgets/add_exam_modal_sheet.dart';
import 'package:kortex/src/l10n/l10n.dart';

class ExamCountdownBanner extends StatelessWidget {
  const ExamCountdownBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = context.l10n;

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
                  color: theme.colorScheme.surface.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.alarm_add_rounded,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.addExamTitle,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: theme.colorScheme.primary,
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
          ExamUrgencyLevel.normal => Colors.greenAccent,
          ExamUrgencyLevel.warning => Colors.amberAccent,
          ExamUrgencyLevel.critical => Colors.redAccent,
        };

        final bannerLabel =
            'Exam Countdown: ${l10n.daysUntilExam(days, exam.examName)}. '
            '${l10n.recommendedDailyPace(pace)}';

        return Semantics(
          container: true,
          label: bannerLabel,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  badgeColor.withValues(alpha: 0.15),
                  theme.colorScheme.surface.withValues(alpha: 0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: badgeColor.withValues(alpha: 0.4),
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
                        color: badgeColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: badgeColor.withValues(alpha: 0.5),
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
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: badgeColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.add_rounded,
                        color: Colors.white70,
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
                const SizedBox(height: 12),
                Text(
                  l10n.daysUntilExam(days, exam.examName),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.auto_graph_rounded,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l10n.recommendedDailyPace(pace),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
