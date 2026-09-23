import 'dart:async';
import 'dart:ui';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/features/planner/domain/logic/cram_workload_calculator.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_cubit.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_state.dart';
import 'package:kortex/src/features/planner/presentation/widgets/add_exam_modal_sheet.dart';
import 'package:kortex/src/features/planner/presentation/widgets/manage_exam_modal_sheet.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';

class ExamCountdownBanner extends StatelessWidget {
  const ExamCountdownBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final neural = context.neural;
    final typography = context.typography;
    final l10n = context.l10n;

    return BlocBuilder<CramPlannerCubit, CramPlannerState>(
      builder: (context, state) {
        final exam = state.selectedExam;

        if (exam == null) {
          // Nearest upcoming exam drives the "Target ... in N days" subtitle
          final upcoming =
              state.activeExams.where((e) => e.daysRemaining > 0).toList()
                ..sort((a, b) => a.daysRemaining.compareTo(b.daysRemaining));
          final targetExam = upcoming.firstOrNull;

          return Semantics(
            container: true,
            button: true,
            label: l10n.addExamTitle,
            child:
                PlatformHoverBuilder(
                      builder: (context, isHovered, child) {
                        return AnimatedContainer(
                          duration: AppMotion.snappy,
                          curve: Curves.easeOutCubic,
                          transform: Matrix4.translationValues(
                            0,
                            isHovered ? -1.5 : 0,
                            0,
                          ),
                          child: InkWell(
                            onTap: () {
                              unawaited(AddExamModalSheet.show(context));
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 16,
                                  sigmaY: 16,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: neural.glassPanel,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isHovered
                                          ? neural.emerald.withAlpha(102)
                                          : neural.hairline,
                                    ),
                                  ),
                                  child: child,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: neural.emerald.withAlpha(26),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: neural.emerald.withAlpha(51),
                              ),
                            ),
                            child: Icon(
                              Icons.access_alarm_rounded,
                              color: neural.emerald400,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.addExamTitle,
                                  style: typography.callout.semiBold.copyWith(
                                    color: neural.slate200,
                                    fontSize: 14,
                                  ),
                                ),
                                if (targetExam != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    l10n.examTargetInDays(
                                      targetExam.examName,
                                      targetExam.daysRemaining,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: typography.caption.regular.copyWith(
                                      color: neural.slate400,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: neural.obsidian800,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.chevron_right_rounded,
                              size: 16,
                              color: neural.slate400,
                            ),
                          ),
                        ],
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 400.ms, curve: Curves.easeOut)
                    .slideY(
                      begin: 0.1,
                      end: 0,
                      duration: 400.ms,
                      curve: Curves.easeOutQuint,
                    ),
          );
        }

        final days = exam.daysRemaining;
        final pace = state.dynamicDailyTarget;
        final urgency = state.urgencyLevel;

        final badgeColor = switch (urgency) {
          ExamUrgencyLevel.normal => neural.emerald400,
          ExamUrgencyLevel.warning => neural.amber400,
          ExamUrgencyLevel.critical => neural.pink400,
        };

        final bannerLabel =
            'Exam Countdown: ${l10n.daysUntilExam(days, exam.examName)}. '
            '${l10n.recommendedDailyPace(pace)}';

        return Semantics(
          container: true,
          button: true,
          label: bannerLabel,
          child:
              PlatformHoverBuilder(
                    builder: (context, isHovered, child) {
                      return AnimatedContainer(
                        duration: AppMotion.snappy,
                        curve: Curves.easeOutCubic,
                        transform: Matrix4.translationValues(
                          0,
                          isHovered ? -2 : 0,
                          0,
                        ),
                        child: InkWell(
                          onTap: () {
                            unawaited(
                              context.router.push(
                                MockExamLobbyRoute(
                                  examId: exam.id,
                                  examName: exam.examName,
                                ),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: neural.glassPanel,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isHovered
                                        ? neural.emerald.withAlpha(102)
                                        : neural.hairline,
                                  ),
                                ),
                                child: child,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: neural.obsidian800,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: badgeColor.withAlpha(51),
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
                                    Flexible(
                                      child: Text(
                                        '${exam.subjectTrack} Track',
                                        style: typography.caption.bold.copyWith(
                                          fontSize: 11,
                                          color: badgeColor,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  onTap: () {
                                    unawaited(
                                      ManageExamModalSheet.show(context),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: neural.obsidian850.withAlpha(204),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: neural.hairlineStrong,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.tune_rounded,
                                          size: 12,
                                          color: neural.slate300,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Manage',
                                          style: typography.caption.medium
                                              .copyWith(
                                                color: neural.slate300,
                                                fontSize: 11,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: Icon(
                                    Icons.add_rounded,
                                    color: neural.slate400,
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
                            color: neural.slate100,
                            fontSize: 15.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.auto_graph_rounded,
                              size: 16,
                              color: neural.emerald400,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                l10n.recommendedDailyPace(pace),
                                style: typography.footnote.semiBold.copyWith(
                                  color: neural.emerald400,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 500.ms, curve: Curves.easeOut)
                  .scale(
                    begin: const Offset(0.95, 0.95),
                    end: const Offset(1, 1),
                    duration: 500.ms,
                    curve: Curves.easeOutQuint,
                  ),
        );
      },
    );
  }
}
