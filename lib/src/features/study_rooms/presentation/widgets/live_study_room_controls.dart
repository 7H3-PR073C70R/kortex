import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/features/study_rooms/presentation/bloc/live_room_cubit.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/room_chat_drawer.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_animated_entrance.dart';
import 'package:kortex/src/shared/widgets/app_liquid_glass_tab_bar.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

export 'package:kortex/src/features/study_rooms/presentation/widgets/live_study_room_drawer.dart';

/// Workspace mode selector bar (Focus Pod, Study Deck, Whiteboard).
class InRoomModeSwitcherBar extends StatelessWidget {
  const InRoomModeSwitcherBar({
    required this.activeMode,
    required this.onSelectMode,
    required this.isDark,
    required this.cardsReviewed,
    super.key,
  });

  final RoomViewMode activeMode;
  final ValueChanged<RoomViewMode> onSelectMode;
  final bool isDark;
  final int cardsReviewed;

  static const List<RoomViewMode> _modes = [
    RoomViewMode.stage,
    RoomViewMode.deckStudy,
    RoomViewMode.whiteboard,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tabs = [
      'Focus Pod',
      'Study Deck',
      l10n.whiteboardTabLabel,
    ];
    const icons = [
      Icons.group_rounded,
      Icons.style_rounded,
      Icons.draw_rounded,
    ];

    final currentIndex = _modes.indexOf(activeMode).clamp(0, 2);

    return AppLiquidGlassTabBar(
      tabs: tabs,
      icons: icons,
      selectedIndex: currentIndex,
      onTabSelected: (index) {
        unawaited(HapticFeedback.selectionClick());
        onSelectMode(_modes[index]);
      },
      padding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }
}

/// Minimalist bottom navigation and quick reaction bar.
class MinimalInRoomBottomBar extends StatelessWidget {
  const MinimalInRoomBottomBar({
    required this.state,
    required this.currentUserId,
    required this.colors,
    required this.typography,
    required this.isDark,
    required this.onReact,
    required this.onOpenDrawer,
    required this.onOpenDeckPicker,
    super.key,
  });

  final LiveRoomState state;
  final String currentUserId;
  final AppThemeColorsExtension colors;
  final TypographyThemeExtension typography;
  final bool isDark;
  final ValueChanged<String> onReact;
  final VoidCallback onOpenDrawer;
  final VoidCallback onOpenDeckPicker;

  static const List<String> _quickEmojis = ['🔥', '👏', '💡', '❤️'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
        border: Border(
          top: BorderSide(color: colors.primary.withAlpha(isDark ? 40 : 20)),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drawer trigger button
                ShrinkableButton(
                  onTap: onOpenDrawer,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceTertiary,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colors.surfaceBorder.withAlpha(isDark ? 80 : 50),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.tune_rounded, size: 15, color: colors.primary),
                        const SizedBox(width: 4),
                        Text(
                          'Tools',
                          style: typography.caption.bold.copyWith(
                            color: colors.textPrimary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // Deck switch button
                ShrinkableButton(
                  onTap: onOpenDeckPicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primary.withAlpha(isDark ? 40 : 20),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colors.primary.withAlpha(isDark ? 80 : 40),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_stories_rounded,
                          size: 14,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Decks',
                          style: typography.caption.bold.copyWith(
                            color: colors.primary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Quick reactions
            Row(
              mainAxisSize: MainAxisSize.min,
              children: _quickEmojis.map((emoji) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: ShrinkableButton(
                    onTap: () {
                      unawaited(HapticFeedback.lightImpact());
                      onReact(emoji);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 3,
                        vertical: 2,
                      ),
                      child: Text(
                        emoji,
                        style: context.typography.body.regular.copyWith(fontSize: 17),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom App Bar for LiveStudyRoom with indicators, unread badge, and actions.
class LiveStudyRoomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const LiveStudyRoomAppBar({
    required this.state,
    required this.currentUserId,
    required this.onLeave,
    required this.onOpenTools,
    super.key,
  });

  final LiveRoomState state;
  final String currentUserId;
  final VoidCallback onLeave;
  final VoidCallback onOpenTools;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDesktop = MediaQuery.sizeOf(context).width >= 1024;

    return AppBar(
      backgroundColor: colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      leading: isDesktop
          ? null
          : IconButton(
              icon: Icon(
                Icons.arrow_back_rounded,
                color: colors.textPrimary,
                size: 22,
              ),
              tooltip: 'Leave Room',
              onPressed: onLeave,
            ),
      leadingWidth: isDesktop ? 0 : null,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            state.room.title,
            style: typography.headline.bold.copyWith(
              color: colors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                AppPulsingBeacon(
                  color: state.isReconnecting ? colors.warning : colors.error,
                  size: 5,
                  pulseSpread: 3,
                ),
                const SizedBox(width: 4),
                Text(
                  state.isReconnecting ? 'RECONNECTING' : 'LIVE',
                  style: typography.caption.bold.copyWith(
                    color: state.isReconnecting ? colors.warning : colors.error,
                    fontSize: 10,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '•',
                    style: typography.caption.regular.copyWith(
                      color: colors.textSecondary.withAlpha(120),
                      fontSize: 10,
                    ),
                  ),
                ),
                Text(
                  state.room.subject,
                  style: typography.caption.regular.copyWith(
                    color: colors.textSecondary,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '•',
                    style: typography.caption.regular.copyWith(
                      color: colors.textSecondary.withAlpha(120),
                      fontSize: 10,
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 11,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      state.formattedTimer,
                      style: typography.caption.bold.copyWith(
                        color: colors.primary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (isDesktop)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: onLeave,
              icon: Icon(
                Icons.logout_rounded,
                size: 16,
                color: colors.error,
              ),
              label: Text(
                'Leave Room',
                style: typography.caption.bold.copyWith(
                  color: colors.error,
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: colors.error.withAlpha(25),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: Icon(
                Icons.forum_rounded,
                color: colors.textPrimary,
                size: 21,
              ),
              tooltip: 'Room Discussion',
              onPressed: () => RoomChatDrawer.show(
                context,
                currentUserId: currentUserId,
              ),
            ),
            if (state.unreadChatCount > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: colors.error,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Center(
                    child: Text(
                      '${state.unreadChatCount}',
                      style: typography.caption.bold.copyWith(
                        color: colors.white,
                        fontSize: 9,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        IconButton(
          icon: Icon(
            Icons.tune_rounded,
            color: colors.textPrimary,
            size: 21,
          ),
          tooltip: 'Room Tools & Controls',
          onPressed: onOpenTools,
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}
