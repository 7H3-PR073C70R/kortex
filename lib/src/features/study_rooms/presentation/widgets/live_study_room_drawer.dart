import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/features/study_rooms/presentation/bloc/live_room_cubit.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/live_study_room_banners.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/live_study_room_drawer_audio_controls.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Comprehensive room controls and workspace configurations drawer.
class RoomControlDrawer extends StatelessWidget {
  const RoomControlDrawer({
    required this.state,
    required this.currentUserId,
    required this.currentUserName,
    required this.colors,
    required this.typography,
    required this.isDark,
    required this.l10n,
    required this.onEditGoal,
    required this.onOpenDeckPicker,
    required this.onLaunchSprint,
    required this.onLeaveRoom,
    required this.canBroadcastVoice,
    required this.onVoicePodTapped,
    super.key,
  });

  final LiveRoomState state;
  final String currentUserId;
  final String currentUserName;
  final AppThemeColorsExtension colors;
  final TypographyThemeExtension typography;
  final bool isDark;
  final AppLocalizations l10n;
  final VoidCallback onEditGoal;
  final VoidCallback onOpenDeckPicker;
  final VoidCallback onLaunchSprint;
  final VoidCallback onLeaveRoom;
  final bool canBroadcastVoice;
  final Future<void> Function() onVoicePodTapped;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<LiveRoomCubit>();

    return Drawer(
      backgroundColor: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: colors.surfaceBorder.withAlpha(isDark ? 80 : 50),
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary.withAlpha(isDark ? 50 : 25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          state.room.subject,
                          style: typography.caption.bold.copyWith(
                            color: colors.primary,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.room.title,
                    style: typography.subhead.bold.copyWith(
                      color: colors.textPrimary,
                      fontSize: 16,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const LivePulseBadge(),
                      const SizedBox(width: 8),
                      Text(
                        '${state.ephemeralParticipants.length} active in pod',
                        style: typography.caption.regular.copyWith(
                          color: colors.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: ListView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  // Mode Switcher Section
                  _buildSectionHeader('WORKSPACE MODE', Icons.layers_rounded),
                  const SizedBox(height: 8),
                  _buildModeTile(
                    title: 'Study Deck',
                    subtitle: state.activeDeckTitle ?? 'Active Recall & Flashcards',
                    icon: Icons.style_rounded,
                    isSelected: state.activeViewMode == RoomViewMode.deckStudy,
                    onTap: () {
                      cubit.switchViewMode(RoomViewMode.deckStudy);
                      Navigator.of(context).pop();
                    },
                  ),
                  const SizedBox(height: 6),
                  _buildModeTile(
                    title: 'Focus Cockpit',
                    subtitle: 'Presence & Body-Doubling',
                    icon: Icons.group_rounded,
                    isSelected: state.activeViewMode == RoomViewMode.stage,
                    onTap: () {
                      cubit.switchViewMode(RoomViewMode.stage);
                      Navigator.of(context).pop();
                    },
                  ),
                  const SizedBox(height: 6),
                  _buildModeTile(
                    title: 'Shared Whiteboard',
                    subtitle: 'Collaborative live drawing',
                    icon: Icons.draw_rounded,
                    isSelected: state.activeViewMode == RoomViewMode.whiteboard,
                    onTap: () {
                      cubit.switchViewMode(RoomViewMode.whiteboard);
                      Navigator.of(context).pop();
                    },
                  ),

                  const SizedBox(height: 18),

                  // Study Deck Quick Picker
                  _buildSectionHeader('STUDY DECK', Icons.auto_stories_rounded),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.surfaceTertiary,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: colors.surfaceBorder.withAlpha(isDark ? 60 : 40),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.activeDeckTitle ?? 'No deck chosen',
                          style: typography.body.bold.copyWith(
                            color: colors.textPrimary,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${state.cardsReviewedInSprint} cards reviewed in this session',
                          style: typography.caption.regular.copyWith(
                            color: colors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ShrinkableButton(
                          onTap: () {
                            Navigator.of(context).pop();
                            onOpenDeckPicker();
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: colors.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                state.activeDeckId != null
                                    ? 'Switch Deck'
                                    : 'Select Deck',
                                style: typography.caption.bold.copyWith(
                                  color: colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Micro-Goal Section
                  _buildSectionHeader('MICRO-GOAL', Icons.flag_rounded),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.surfaceTertiary,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: colors.surfaceBorder.withAlpha(isDark ? 60 : 40),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.activeGoal ?? 'No micro-goal set yet',
                          style: typography.body.bold.copyWith(
                            color: state.activeGoal != null
                                ? colors.textPrimary
                                : colors.textSecondary,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ShrinkableButton(
                          onTap: () {
                            Navigator.of(context).pop();
                            onEditGoal();
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: colors.primary.withAlpha(isDark ? 50 : 25),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: colors.primary.withAlpha(
                                  isDark ? 90 : 50,
                                ),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                state.activeGoal != null
                                    ? 'Edit Goal'
                                    : 'Set Goal',
                                style: typography.caption.bold.copyWith(
                                  color: colors.primary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Ambient Audio & Binaural Soundscapes
                  _buildSectionHeader(
                    'AMBIENT SOUNDSCAPE',
                    Icons.headphones_rounded,
                  ),
                  const SizedBox(height: 8),
                  DrawerAmbientAudioSection(
                    state: state,
                    colors: colors,
                    typography: typography,
                    isDark: isDark,
                  ),

                  const SizedBox(height: 18),

                  // Voice Pod & Audio Presence
                  _buildSectionHeader(
                    'VOICE POD',
                    Icons.mic_rounded,
                    isPro: !canBroadcastVoice,
                  ),
                  const SizedBox(height: 8),
                  DrawerVoicePodSection(
                    state: state,
                    colors: colors,
                    typography: typography,
                    isDark: isDark,
                    onVoicePodTapped: onVoicePodTapped,
                  ),

                  const SizedBox(height: 18),

                  // Co-Op Focus Sprint
                  _buildSectionHeader('CO-OP STUDY SPRINT', Icons.bolt_rounded),
                  const SizedBox(height: 8),
                  ShrinkableButton(
                    onTap: () {
                      Navigator.of(context).pop();
                      onLaunchSprint();
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colors.warning.withAlpha(isDark ? 50 : 30),
                            colors.primary.withAlpha(isDark ? 40 : 20),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: colors.warning.withAlpha(isDark ? 90 : 60),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.flash_on_rounded,
                            color: colors.warning,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Launch Co-Op Sprint',
                                  style: typography.caption.bold.copyWith(
                                    color: colors.textPrimary,
                                    fontSize: 12.5,
                                  ),
                                ),
                                Text(
                                  '3-minute synchronized rapid review battle',
                                  style: typography.caption.regular.copyWith(
                                    color: colors.textSecondary,
                                    fontSize: 10.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: colors.textSecondary,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Leave Room Button
                  ShrinkableButton(
                    onTap: () {
                      Navigator.of(context).pop();
                      onLeaveRoom();
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: colors.error.withAlpha(isDark ? 35 : 20),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: colors.error.withAlpha(isDark ? 80 : 45),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.logout_rounded,
                            size: 17,
                            color: colors.error,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Leave Room',
                            style: typography.caption.bold.copyWith(
                              color: colors.error,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, {bool isPro = false}) {
    return Row(
      children: [
        Icon(icon, size: 13, color: colors.primary),
        const SizedBox(width: 5),
        Text(
          title,
          style: typography.caption.bold.copyWith(
            color: colors.primary,
            fontSize: 10,
            letterSpacing: 0.8,
          ),
        ),
        if (isPro) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colors.primary, colors.primary.withAlpha(200)],
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'PRO',
              style: typography.caption.bold.copyWith(
                color: Colors.white,
                fontSize: 8.5,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildModeTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ShrinkableButton(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.primary.withAlpha(isDark ? 50 : 25)
              : colors.surfaceTertiary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? colors.primary
                : colors.surfaceBorder.withAlpha(isDark ? 60 : 40),
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? colors.primary : colors.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: typography.caption.bold.copyWith(
                      color: isSelected ? colors.primary : colors.textPrimary,
                      fontSize: 12.5,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: typography.caption.regular.copyWith(
                      color: colors.textSecondary,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, size: 16, color: colors.primary),
          ],
        ),
      ),
    );
  }
}
