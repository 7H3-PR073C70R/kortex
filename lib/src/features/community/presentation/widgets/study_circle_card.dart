import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/community/domain/entities/study_circle_entity.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class StudyCircleCard extends StatelessWidget {
  const StudyCircleCard({
    required this.circle,
    required this.onJoinTap,
    super.key,
  });

  final StudyCircleEntity circle;
  final VoidCallback onJoinTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final l10n = context.l10n;

    final progress = circle.weeklyProgressPercent;
    final isJoined = circle.isCurrentUserMember;
    final isFull = circle.isFull;

    return PlatformHoverBuilder(
      builder: (context, isHovered, child) {
        return AnimatedContainer(
          duration: AppMotion.snappy,
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isHovered
                ? (isDark
                    ? colors.surfaceSecondary.withAlpha(220)
                    : colors.surfacePrimary)
                : (isDark ? colors.surfaceSecondary : colors.surfacePrimary),
            borderRadius: AppRadius.radiusPanel,
            border: Border.all(
              color: isHovered
                  ? colors.primary.withAlpha(isDark ? 160 : 120)
                  : (isJoined
                      ? colors.primary.withAlpha(isDark ? 120 : 90)
                      : colors.primary.withAlpha(isDark ? 40 : 25)),
              width: (isJoined || isHovered) ? 1.5 : 1.0,
            ),
          ),
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Track Badge + Member Count Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colors.primary.withAlpha(30),
                  borderRadius: AppRadius.radiusBadge,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.diversity_3_rounded,
                      size: 13,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      circle.track.toUpperCase(),
                      style: typography.caption.bold.copyWith(
                        color: colors.primary,
                        fontSize: 11,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isFull
                      ? colors.warning.withAlpha(30)
                      : colors.success.withAlpha(30),
                  borderRadius: AppRadius.radiusBadge,
                ),
                child: Text(
                  '${circle.memberCount}/${circle.maxMembers} Scholars',
                  style: typography.caption.bold.copyWith(
                    color: isFull ? colors.warning : colors.success,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Circle Name
          Text(
            circle.name,
            style: typography.headline.bold.copyWith(
              color: colors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),

          // Target Weekly Focus
          Text(
            '${circle.totalMinutesCompleted} / ${circle.targetWeeklyMinutes} mins focused together this week',
            style: typography.caption.regular.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),

          // Linear Progress Indicator
          ClipRRect(
            borderRadius: AppRadius.radiusMicro,
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: colors.primary.withAlpha(30),
              valueColor: AlwaysStoppedAnimation<Color>(
                progress >= 1.0 ? colors.success : colors.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Group Pod Quest Milestone
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colors.primary.withAlpha(isDark ? 35 : 18),
              borderRadius: AppRadius.radiusBadge,
              border: Border.all(color: colors.primary.withAlpha(50)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.military_tech_rounded,
                  size: 14,
                  color: colors.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    circle.podQuest,
                    style: typography.caption.bold.copyWith(
                      color: colors.primary,
                      fontSize: 10.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          if (circle.members.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? colors.surfaceSecondary.withAlpha(80)
                    : colors.surfacePrimary.withAlpha(120),
                borderRadius: AppRadius.radiusCard,
                border: Border.all(
                  color: colors.primary.withAlpha(isDark ? 25 : 15),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'POD MEMBER CONTRIBUTIONS',
                    style: typography.caption.bold.copyWith(
                      color: colors.textSecondary,
                      fontSize: 9,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: circle.members.map((member) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary.withAlpha(isDark ? 30 : 15),
                          borderRadius: AppRadius.radiusMicro,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              member.userName,
                              style: typography.caption.bold.copyWith(
                                color: colors.textPrimary,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${member.weeklyMinutesContributed}m',
                              style: typography.caption.bold.copyWith(
                                color: colors.primary,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),

          // Action Button & Member Avatars Preview
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Pod Member Avatars stack
              Row(
                children: [
                  for (var i = 0; i < circle.members.take(4).length; i++)
                    Align(
                      widthFactor: 0.7,
                      child: CircleAvatar(
                        radius: 13,
                        backgroundColor: colors.primary,
                        child: Text(
                          circle.members[i].userName.isNotEmpty
                              ? circle.members[i].userName[0].toUpperCase()
                              : 'P',
                          style: typography.caption.bold.copyWith(
                            color: colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  if (circle.members.isEmpty)
                    Text(
                      l10n.firstToJoinCircle,
                      style: typography.caption.medium.copyWith(
                        color: colors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),

              // Join / Joined Action
              PlatformHoverBuilder(
                builder: (context, isBtnHovered, child) {
                  return ShrinkableButton(
                    onTap: (isFull && !isJoined)
                        ? null
                        : () {
                            unawaited(HapticFeedback.lightImpact());
                            onJoinTap();
                          },
                    child: AnimatedContainer(
                      duration: AppMotion.snappy,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: isJoined
                            ? (isBtnHovered
                                  ? colors.success.withAlpha(isDark ? 60 : 40)
                                  : colors.success.withAlpha(isDark ? 40 : 25))
                            : (isFull
                                  ? colors.surfaceSecondary
                                  : (isBtnHovered
                                        ? colors.primary.withAlpha(240)
                                        : colors.primary)),
                        borderRadius: AppRadius.radiusCard,
                        border: isJoined
                            ? Border.all(color: colors.success.withAlpha(80))
                            : null,
                        boxShadow: (isBtnHovered && !isJoined && !isFull)
                            ? [
                                BoxShadow(
                                  color: colors.primary.withAlpha(isDark ? 80 : 50),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isJoined
                                ? Icons.check_circle_rounded
                                : (isFull
                                      ? Icons.lock_outline_rounded
                                      : Icons.group_add_rounded),
                            color: isJoined
                                ? colors.success
                                : (isFull ? colors.textSecondary : colors.white),
                            size: 14,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isJoined
                                ? l10n.yourPodLabel
                                : (isFull ? l10n.podFullLabel : l10n.joinPodLabel),
                            style: typography.caption.bold.copyWith(
                              color: isJoined
                                  ? colors.success
                                  : (isFull ? colors.textSecondary : colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              if (isJoined) ...[
                const SizedBox(width: 8),
                PlatformHoverBuilder(
                  builder: (context, isNudgeHovered, child) {
                    return ShrinkableButton(
                      onTap: () {
                        unawaited(HapticFeedback.lightImpact());
                        context.showSnackBar(
                          message: l10n.studyNudgeSentNotice,
                          type: SnackBarType.success,
                        );
                      },
                      child: AnimatedContainer(
                        duration: AppMotion.snappy,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: isNudgeHovered
                              ? colors.primary.withAlpha(isDark ? 60 : 40)
                              : colors.primary.withAlpha(isDark ? 40 : 25),
                          borderRadius: AppRadius.radiusCard,
                          border: Border.all(
                            color: colors.primary.withAlpha(80),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.bolt_rounded,
                              size: 14,
                              color: colors.warning,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              l10n.nudgeAction,
                              style: typography.caption.bold.copyWith(
                                color: colors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  },
);
}
}
