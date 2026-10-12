import 'dart:async';
import 'dart:ui';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/features/dashboard/domain/logic/cbt_readiness_calculator.dart';
import 'package:kortex/src/features/planner/domain/entities/assessment_type.dart';
import 'package:kortex/src/features/planner/domain/entities/exam_event_entity.dart';
import 'package:kortex/src/features/planner/presentation/widgets/countdown/cbt_readiness_breakdown_sheet.dart';
import 'package:kortex/src/features/planner/presentation/widgets/manage_exam_modal_sheet.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_tour_keys.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';

/// Interactive card presenting the active milestone details, CBT readiness, and primary CTA.
class ActiveMilestoneCard extends StatelessWidget {
  const ActiveMilestoneCard({
    required this.exam,
    required this.pace,
    required this.badgeColor,
    required this.isTopPriority,
    required this.readinessResult,
    required this.countdownHeadline,
    required this.actionLabel,
    required this.onPrimaryAction,
    super.key,
  });

  final ExamEventEntity exam;
  final int pace;
  final Color badgeColor;
  final bool isTopPriority;
  final CbtReadinessResult readinessResult;
  final String countdownHeadline;
  final String actionLabel;
  final VoidCallback onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    final neural = context.neural;
    final typography = context.typography;
    final l10n = context.l10n;

    return PlatformHoverBuilder(
      builder: (context, isHovered, child) {
        return AnimatedContainer(
          duration: AppMotion.snappy,
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(
            0,
            isHovered ? -2 : 0,
            0,
          ),
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
                        ? badgeColor.withAlpha(120)
                        : (exam.isCriticalCrunch
                            ? badgeColor.withAlpha(100)
                            : neural.hairline),
                    width: exam.isCriticalCrunch ? 1.4 : 1.0,
                  ),
                ),
                child: child,
              ),
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Wrap(
                  spacing: 5,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      key: AppTourKeys.countdownBadgeKey,
                      constraints: const BoxConstraints(maxWidth: 210),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3.5,
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
                            exam.assessmentType.icon,
                            size: 12,
                            color: badgeColor,
                          ),
                          const SizedBox(width: 4.5),
                          Flexible(
                            child: Text(
                              '${exam.assessmentType.displayName.toUpperCase()} • ${exam.subjectTrack}${exam.subjectTrack.toLowerCase().contains('track') ? '' : ' Track'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: typography.caption.bold.copyWith(
                                fontSize: 10,
                                color: badgeColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Grade Weight Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: neural.obsidian800,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                          color: neural.hairlineStrong,
                        ),
                      ),
                      child: Text(
                        l10n.gradeWeightBadge(
                          (exam.effectiveWeightPercent > 1.0
                                  ? exam.effectiveWeightPercent
                                  : exam.effectiveWeightPercent * 100)
                              .toInt()
                              .toString(),
                        ),
                        style: typography.caption.medium.copyWith(
                          fontSize: 9.5,
                          color: neural.slate300,
                        ),
                      ),
                    ),
                    // Dynamic CBT Readiness Index Badge
                    InkWell(
                      onTap: () {
                        AppFeedback.selection();
                        CbtReadinessBreakdownSheet.show(
                          context,
                          exam: exam,
                          readiness: readinessResult,
                        );
                      },
                      borderRadius: BorderRadius.circular(7),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3.5,
                        ),
                        decoration: BoxDecoration(
                          color: readinessResult.statusColor.withAlpha(25),
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(
                            color: readinessResult.statusColor.withAlpha(90),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.analytics_rounded,
                              size: 11,
                              color: readinessResult.statusColor,
                            ),
                            const SizedBox(width: 3.5),
                            Text(
                              'Readiness: ${readinessResult.scorePercent}%',
                              style: typography.caption.bold.copyWith(
                                fontSize: 9.5,
                                color: readinessResult.statusColor,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.info_outline_rounded,
                              size: 10,
                              color: readinessResult.statusColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Top Priority Flag
                    if (isTopPriority)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: neural.amber400.withAlpha(30),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: neural.amber400.withAlpha(80),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.bolt_rounded,
                              size: 11,
                              color: neural.amber400,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              l10n.topPriorityBadge,
                              style: typography.caption.bold.copyWith(
                                fontSize: 9,
                                color: neural.amber400,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () {
                      unawaited(ManageExamModalSheet.show(context));
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
                            style: typography.caption.medium.copyWith(
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
                      unawaited(
                        context.router.push(
                          AddAcademicAssessmentRoute(),
                        ),
                      );
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Countdown Headline
          Text(
            countdownHeadline,
            style: typography.title3.bold.copyWith(
              color: neural.slate100,
              fontSize: 15.5,
            ),
          ),

          // Scoped Topics Tag Strip
          if (exam.scopedTopics.isNotEmpty) ...[
            const SizedBox(height: 5),
            Row(
              children: [
                Icon(
                  Icons.topic_outlined,
                  size: 12,
                  color: neural.slate400,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    l10n.topicsCoveredLabel(
                      exam.scopedTopics.join(' • '),
                    ),
                    style: typography.caption.regular.copyWith(
                      color: neural.slate400,
                      fontSize: 10.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],

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

          const SizedBox(height: 12),

          // Contextual Action Button (Primary CTA)
          SizedBox(
            width: double.infinity,
            child: InkWell(
              onTap: onPrimaryAction,
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: AppMotion.snappy,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8.5,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      badgeColor.withAlpha(200),
                      badgeColor.withAlpha(140),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: badgeColor.withAlpha(50),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      exam.assessmentType == AssessmentType.quiz
                          ? Icons.bolt_rounded
                          : Icons.play_arrow_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      actionLabel,
                      style: typography.footnote.bold.copyWith(
                        color: Colors.white,
                        fontSize: 12.5,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
