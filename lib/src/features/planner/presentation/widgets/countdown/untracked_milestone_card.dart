import 'dart:async';
import 'dart:ui';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/features/planner/domain/entities/exam_event_entity.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_tour_keys.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';

/// Card displayed when no active exam milestone is currently selected.
class UntrackedMilestoneCard extends StatelessWidget {
  const UntrackedMilestoneCard({
    required this.targetExam,
    super.key,
  });

  final ExamEventEntity? targetExam;

  @override
  Widget build(BuildContext context) {
    final neural = context.neural;
    final typography = context.typography;
    final l10n = context.l10n;

    return Semantics(
      container: true,
      button: true,
      label: l10n.addExamTitle,
      child: PlatformHoverBuilder(
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
                unawaited(
                  context.router.push(
                    AddAcademicAssessmentRoute(),
                  ),
                );
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
              key: AppTourKeys.countdownBadgeKey,
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
                    'Track Assessment Milestone',
                    style: typography.callout.semiBold.copyWith(
                      color: neural.slate200,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    targetExam != null
                        ? l10n.examTargetInDays(
                            targetExam!.examName,
                            targetExam!.daysRemaining,
                          )
                        : 'Set countdown for upcoming tests, quizzes, or exams',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: typography.caption.regular.copyWith(
                      color: neural.slate400,
                      fontSize: 11,
                    ),
                  ),
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
}
