import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/study_rooms/domain/entities/study_circle_entity.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Individual study circle pod card with weekly progress and member avatars.
class PodPulseCardItem extends StatelessWidget {
  const PodPulseCardItem({
    required this.circle,
    required this.onTap,
    required this.onJoin,
    super.key,
  });

  final StudyCircleEntity circle;
  final VoidCallback onTap;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final neural = context.neural;
    final typography = context.typography;

    final isJoined = circle.isCurrentUserMember;
    final isFull = circle.isFull;
    final memberCount = circle.effectiveMemberCount;
    final maxMembers = circle.maxMembers;
    final progress = circle.weeklyProgressPercent;

    return PlatformHoverBuilder(
      builder: (context, isHovered, _) {
        return ShrinkableButton(
          onTap: onTap,
          child: Container(
            width: 220,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: neural.obsidian850.withAlpha(200),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isJoined
                    ? neural.emerald.withAlpha(128)
                    : (isHovered
                          ? neural.emerald.withAlpha(77)
                          : neural.hairlineSoft),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        circle.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: typography.caption.bold.copyWith(
                          color: neural.slate100,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isJoined
                            ? neural.emerald.withAlpha(38)
                            : (isFull
                                  ? neural.amber400.withAlpha(25)
                                  : neural.cyan.withAlpha(25)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isJoined
                            ? 'JOINED'
                            : (isFull ? 'FULL' : '$memberCount/$maxMembers'),
                        style: typography.caption.bold.copyWith(
                          color: isJoined
                              ? neural.emerald400
                              : (isFull ? neural.amber400 : neural.cyan300),
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  circle.podQuest,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.caption.medium.copyWith(
                    color: neural.slate400,
                    fontSize: 10,
                  ),
                ),

                // Weekly Goal Progress Bar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Weekly Sprint',
                          style: typography.caption.medium.copyWith(
                            color: neural.slate400,
                            fontSize: 9,
                          ),
                        ),
                        Text(
                          '${(progress * 100).toInt()}%',
                          style: typography.caption.bold.copyWith(
                            color: neural.emerald400,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 4,
                        backgroundColor: neural.obsidian800,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          neural.emerald400,
                        ),
                      ),
                    ),
                  ],
                ),

                // Bottom row: Member Avatars / Action Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Member Avatar Stack
                    Row(
                      children: [
                        for (
                          var i = 0;
                          i < (circle.members.length.clamp(0, 3));
                          i++
                        )
                          Align(
                            widthFactor: 0.6,
                            child: CircleAvatar(
                              radius: 9,
                              backgroundColor: neural.emerald.withAlpha(200),
                              child: Text(
                                circle.members[i].userName.isNotEmpty
                                    ? circle.members[i].userName[0]
                                          .toUpperCase()
                                    : 'S',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        if (circle.members.isEmpty)
                          CircleAvatar(
                            radius: 9,
                            backgroundColor: neural.emerald.withAlpha(200),
                            child: const Text(
                              'P',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (!isJoined && !isFull)
                      ShrinkableButton(
                        onTap: onJoin,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: neural.emerald.withAlpha(38),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: neural.emerald.withAlpha(102),
                            ),
                          ),
                          child: Text(
                            'Join Pod',
                            style: typography.caption.bold.copyWith(
                              color: neural.emerald400,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      )
                    else
                      Text(
                        isJoined ? 'Tap details' : 'Pod Full',
                        style: typography.caption.medium.copyWith(
                          color: neural.slate400,
                          fontSize: 10,
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
