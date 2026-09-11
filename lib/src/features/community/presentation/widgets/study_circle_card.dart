import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/community/domain/entities/study_circle_entity.dart';
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

    final progress = circle.weeklyProgressPercent;
    final isJoined = circle.isCurrentUserMember;
    final isFull = circle.isFull;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isJoined
              ? colors.primary.withAlpha(isDark ? 120 : 90)
              : colors.primary.withAlpha(isDark ? 40 : 25),
          width: isJoined ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.black.withAlpha(isDark ? 40 : 20),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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
                  borderRadius: BorderRadius.circular(8),
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
                  borderRadius: BorderRadius.circular(8),
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
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: colors.primary.withAlpha(30),
              valueColor: AlwaysStoppedAnimation<Color>(
                progress >= 1.0 ? colors.success : colors.primary,
              ),
            ),
          ),
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
                      'Be the first to join!',
                      style: typography.caption.medium.copyWith(
                        color: colors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),

              // Join / Joined Action
              ShrinkableButton(
                onTap: (isFull && !isJoined)
                    ? null
                    : () {
                        unawaited(HapticFeedback.lightImpact());
                        onJoinTap();
                      },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: isJoined
                        ? colors.success.withAlpha(isDark ? 40 : 25)
                        : (isFull
                            ? colors.surfaceSecondary
                            : colors.primary),
                    borderRadius: BorderRadius.circular(12),
                    border: isJoined
                        ? Border.all(color: colors.success.withAlpha(80))
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
                            : (isFull
                                ? colors.textSecondary
                                : colors.white),
                        size: 14,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isJoined
                            ? 'Your Pod'
                            : (isFull ? 'Pod Full' : 'Join Pod'),
                        style: typography.caption.bold.copyWith(
                          color: isJoined
                              ? colors.success
                              : (isFull
                                  ? colors.textSecondary
                                  : colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
