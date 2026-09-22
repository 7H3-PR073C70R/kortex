import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/community/domain/entities/study_room_entity.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_avatar.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class LiveFocusRoomCard extends StatelessWidget {
  const LiveFocusRoomCard({
    required this.room,
    required this.onJoinTap,
    super.key,
  });

  final StudyRoomEntity room;
  final VoidCallback onJoinTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final semanticsLabel =
        '${room.title}, ${room.subject}, '
        '${l10n.activeParticipantsCount(room.activeParticipantsCount)}';

    return Semantics(
      label: semanticsLabel,
      button: true,
      child: PlatformHoverBuilder(
        builder: (context, isHovered, child) {
          return AnimatedContainer(
            duration: AppMotion.snappy,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isHovered
                  ? (isDark
                        ? colors.surfaceSecondary.withAlpha(220)
                        : colors.surfacePrimary)
                  : (isDark ? colors.surfaceSecondary : colors.surfacePrimary),
              borderRadius: AppRadius.radiusPanel,
              border: Border.all(
                color: isHovered
                    ? colors.primary.withAlpha(isDark ? 140 : 100)
                    : colors.primary.withAlpha(isDark ? 40 : 25),
                width: isHovered ? 1.5 : 1.0,
              ),
              boxShadow: isHovered
                  ? [
                      BoxShadow(
                        color: colors.black.withAlpha(isDark ? 40 : 15),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: colors.black.withAlpha(isDark ? 20 : 5),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Category badge + Live indicator
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
                      child: Text(
                        room.category.toUpperCase(),
                        style: typography.caption.bold.copyWith(
                          color: colors.primary,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.recallEasy,
                          ),
                        ).animate(onPlay: (controller) => controller.repeat())
                         .fadeIn(duration: 800.ms)
                         .then(delay: 200.ms)
                         .fadeOut(duration: 800.ms),
                        const SizedBox(width: 6),
                        Transform.translate(
                          offset: const Offset(0, 0.5), // Optical alignment
                          child: Text(
                            room.isFocusing
                                ? l10n.pomodoroFocus
                                : l10n.pomodoroBreak,
                            style: typography.caption.bold.copyWith(
                              color: room.isFocusing
                                  ? colors.primary
                                  : colors.recallHard,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Title & Subject
                Text(
                  room.title,
                  style: typography.title3.bold.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  room.subject,
                  style: typography.footnote.regular.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),

                // Bottom Row: Active Peer Avatars & Join Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildAvatarStack(context, room.participantAvatars, room.activeParticipantsCount),
                    PlatformHoverBuilder(
                      builder: (context, isBtnHovered, child) {
                        return ShrinkableButton(
                          onTap: onJoinTap,
                          child: AnimatedContainer(
                            duration: AppMotion.snappy,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  colors.primary,
                                  colors.primary.withAlpha(
                                    isBtnHovered ? 250 : 220,
                                  ),
                                ],
                              ),
                              borderRadius: AppRadius.radiusCard,
                              boxShadow: isBtnHovered
                                  ? [
                                      BoxShadow(
                                        color: colors.black.withAlpha(
                                          isDark ? 50 : 20,
                                        ),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Text(
                              l10n.joinRoomButton,
                              style: typography.footnote.bold.copyWith(
                                color: colors.white,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAvatarStack(BuildContext context, List<String> avatars, int totalCount) {
    final colors = context.colors;
    final typography = context.typography;
    
    // Determine how many avatars to show (max 4)
    final displayCount = avatars.length > 4 ? 4 : avatars.length;
    final overflowCount = totalCount - displayCount;
    
    if (displayCount == 0) {
      return Row(
        children: [
          Icon(
            Icons.people_outline_rounded,
            size: 18,
            color: colors.textSecondary,
          ),
          const SizedBox(width: 6),
          Text(
            context.l10n.activeParticipantsCount(totalCount),
            style: typography.footnote.medium.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      );
    }
    
    return Row(
      children: [
        SizedBox(
          width: 24.0 * displayCount + (overflowCount > 0 ? 32.0 : 0),
          height: 32,
          child: Stack(
            children: [
              for (int i = 0; i < displayCount; i++)
                Positioned(
                  left: i * 20.0,
                  child: AppAvatar(
                    imageUrl: avatars[i],
                    size: AppAvatarSize.small,
                    borderColor: context.isDarkMode ? colors.surfaceSecondary : colors.surfacePrimary,
                    borderWidth: 2,
                  ),
                ),
              if (overflowCount > 0)
                Positioned(
                  left: displayCount * 20.0,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: colors.surfaceTertiary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: context.isDarkMode ? colors.surfaceSecondary : colors.surfacePrimary,
                        width: 2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '+$overflowCount',
                      style: typography.caption.bold.copyWith(
                        color: colors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
