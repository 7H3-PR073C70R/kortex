import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/notification_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_event.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_hub_bloc.dart';
import 'package:kortex/src/features/study_rooms/domain/entities/study_circle_entity.dart';
import 'package:kortex/src/shared/widgets/app_avatar.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class StudyCircleDetailSheet extends StatelessWidget {
  const StudyCircleDetailSheet({
    required this.circle,
    super.key,
  });

  final StudyCircleEntity circle;

  static Future<void> show(
    BuildContext context,
    StudyCircleEntity circle, {
    CommunityHubBloc? bloc,
  }) {
    final hubBloc = bloc ?? context.read<CommunityHubBloc>();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: hubBloc,
        child: StudyCircleDetailSheet(circle: circle),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final progress = circle.weeklyProgressPercent;
    final isJoined = circle.isCurrentUserMember;
    final isFull = circle.isFull;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: colors.primary.withAlpha(isDark ? 40 : 20),
          ),
          boxShadow: [
            BoxShadow(
              color: colors.black.withAlpha(isDark ? 80 : 30),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.textSecondary.withAlpha(80),
                  borderRadius: AppRadius.radiusMicro,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                      const SizedBox(height: 8),
                      Text(
                        circle.name,
                        style: typography.title3.bold.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close_rounded,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Weekly Target Progress Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.primary.withAlpha(isDark ? 30 : 15),
                borderRadius: AppRadius.radiusCard,
                border: Border.all(
                  color: colors.primary.withAlpha(50),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Pod Weekly Focus Goal',
                        style: typography.caption.bold.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        '${circle.totalMinutesCompleted} / ${circle.targetWeeklyMinutes} mins',
                        style: typography.caption.bold.copyWith(
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: AppRadius.radiusMicro,
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: colors.primary.withAlpha(30),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progress >= 1.0 ? colors.success : colors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
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
                          style: typography.caption.medium.copyWith(
                            color: colors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Pod Members Section Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'POD MEMBERS (${circle.memberCount}/${circle.maxMembers})',
                  style: typography.caption.bold.copyWith(
                    color: colors.textSecondary,
                    fontSize: 11,
                    letterSpacing: 0.8,
                  ),
                ),
                if (isJoined)
                  Text(
                    'Active Pod Member',
                    style: typography.caption.bold.copyWith(
                      color: colors.success,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Member List
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: circle.members.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final member = circle.members[index];
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? colors.backgroundPrimary.withAlpha(120)
                          : colors.surfacePrimary,
                      borderRadius: AppRadius.radiusCard,
                      border: Border.all(
                        color: colors.primary.withAlpha(isDark ? 20 : 10),
                      ),
                    ),
                    child: Row(
                      children: [
                        AppAvatar(
                          name: member.userName,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    member.userName,
                                    style: typography.body.bold.copyWith(
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                  if (member.role == 'creator') ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colors.warning.withAlpha(30),
                                        borderRadius: AppRadius.radiusMicro,
                                      ),
                                      child: Text(
                                        'FOUNDER',
                                        style: typography.caption.bold.copyWith(
                                          color: colors.warning,
                                          fontSize: 9,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${member.weeklyMinutesContributed} mins contributed',
                                style: typography.caption.regular.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // Bottom Action Buttons: Nudge & Join/Leave
            Row(
              children: [
                if (isJoined) ...[
                  Expanded(
                    child: ShrinkableButton(
                      onTap: () {
                        unawaited(HapticFeedback.mediumImpact());
                        context.read<CommunityHubBloc>().add(
                          NudgeStudyCircleEvent(
                            circleId: circle.id,
                            circleName: circle.name,
                          ),
                        );
                        if (locator.isRegistered<NotificationService>()) {
                          unawaited(
                            locator<NotificationService>()
                                .showLocalNotification(
                                  id:
                                      DateTime.now().millisecondsSinceEpoch ~/
                                      1000,
                                  title: '⚡ Pod Focus Nudge Sent!',
                                  body:
                                      'Nudge sent to scholars in "${circle.name}". Time to crush weekly targets!',
                                ),
                          );
                        }
                        context.showSnackBar(
                          message:
                              '⚡ Nudge sent! We notified scholars in "${circle.name}" to jump into focus.',
                          type: SnackBarType.success,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: colors.primary.withAlpha(30),
                          borderRadius: AppRadius.radiusCard,
                          border: Border.all(
                            color: colors.primary.withAlpha(80),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.bolt_rounded,
                              size: 18,
                              color: colors.warning,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Nudge Pod Members',
                              style: typography.caption.bold.copyWith(
                                color: colors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: ShrinkableButton(
                    onTap: (isFull && !isJoined)
                        ? null
                        : () {
                            unawaited(HapticFeedback.lightImpact());
                            if (isJoined) {
                              context
                                  .read<CommunityHubBloc>()
                                  .add(LeaveStudyCircleEvent(circle.id));
                              Navigator.of(context).pop();
                              context.showSnackBar(
                                message: 'You have left "${circle.name}".',
                              );
                            } else {
                              context
                                  .read<CommunityHubBloc>()
                                  .add(JoinStudyCircleEvent(circle.id));
                              Navigator.of(context).pop();
                            }
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isJoined
                            ? colors.error.withAlpha(30)
                            : (isFull
                                  ? colors.surfaceSecondary
                                  : colors.primary),
                        borderRadius: AppRadius.radiusCard,
                        border: isJoined
                            ? Border.all(
                                color: colors.error.withAlpha(80),
                              )
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isJoined
                                ? Icons.exit_to_app_rounded
                                : (isFull
                                      ? Icons.lock_outline_rounded
                                      : Icons.group_add_rounded),
                            color: isJoined
                                ? colors.error
                                : (isFull
                                      ? colors.textSecondary
                                      : colors.white),
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isJoined
                                ? 'Leave Circle'
                                : (isFull ? 'Pod Full' : 'Join Pod'),
                            style: typography.caption.bold.copyWith(
                              color: isJoined
                                  ? colors.error
                                  : (isFull
                                        ? colors.textSecondary
                                        : colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
