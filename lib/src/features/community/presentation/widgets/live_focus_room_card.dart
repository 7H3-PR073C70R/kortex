import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/community/domain/entities/study_room_entity.dart';
import 'package:kortex/src/l10n/l10n.dart';
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
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colors.primary.withAlpha(isDark ? 40 : 25),
          ),
          boxShadow: [
            BoxShadow(
              color: colors.black.withAlpha(isDark ? 50 : 15),
              blurRadius: 10,
              offset: const Offset(0, 4),
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
                    borderRadius: BorderRadius.circular(8),
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
                    ),
                    const SizedBox(width: 6),
                    Text(
                      room.isFocusing ? l10n.pomodoroFocus : l10n.pomodoroBreak,
                      style: typography.caption.bold.copyWith(
                        color: room.isFocusing
                            ? colors.primary
                            : colors.recallHard,
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

            // Bottom Row: Active Peer Count & Join Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.people_outline_rounded,
                      size: 18,
                      color: colors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l10n.activeParticipantsCount(
                        room.activeParticipantsCount,
                      ),
                      style: typography.footnote.medium.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
                ShrinkableButton(
                  onTap: onJoinTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colors.primary,
                          colors.primary.withAlpha(220),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      l10n.joinRoomButton,
                      style: typography.footnote.bold.copyWith(
                        color: colors.white,
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
