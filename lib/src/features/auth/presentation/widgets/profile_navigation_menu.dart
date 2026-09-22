import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/welcome_walkthrough_dialog.dart';
import 'package:kortex/src/shared/widgets/app_guided_tour_overlay.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class ProfileNavigationMenu extends StatelessWidget {
  const ProfileNavigationMenu({
    required this.targetTrack,
    required this.dailyTarget,
    super.key,
  });

  final String targetTrack;
  final int dailyTarget;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Learning & Progress ──────────────────────────────────────────
        const _SectionLabel(title: 'Learning & Progress'),
        _SettingsGroup(
          children: [
            _NavTile(
              icon: Icons.school_outlined,
              iconColor: colors.textSecondary,
              chipBg: const Color.fromRGBO(39, 39, 42, 0.8), // zinc-800/80
              chipBorder: const Color.fromRGBO(63, 63, 70, 0.5), // zinc-700/50
              hoverIconColor: const Color.fromRGBO(251, 191, 36, 1.0), // amber-400
              hoverChipBorder: const Color.fromRGBO(245, 158, 11, 0.4), // amber-500/40
              title: 'Academic Track & Goals',
              subtitle: '$targetTrack · $dailyTarget cards a day',
              onTap: () {
                AppFeedback.light();
                unawaited(
                  context.router.push(const AcademicTrackSettingsRoute()),
                );
              },
            ),
            _NavTile(
              icon: Icons.psychology_outlined,
              iconColor: const Color.fromRGBO(216, 180, 254, 1.0), // purple-300
              chipBg: const Color.fromRGBO(59, 7, 100, 0.3), // purple-950/30
              chipBorder: const Color.fromRGBO(107, 33, 168, 0.4), // purple-800/40
              hoverIconColor: const Color.fromRGBO(233, 213, 255, 1.0), // purple-200
              hoverChipBorder: const Color.fromRGBO(107, 33, 168, 0.4),
              title: 'Syllabot AI & Neural Engine',
              subtitle: 'Tutor style, voice and offline AI',
              onTap: () {
                AppFeedback.light();
                unawaited(
                  context.router.push(const SyllabotAiSettingsRoute()),
                );
              },
            ),
            _NavTile(
              icon: Icons.emoji_events_outlined,
              iconColor: const Color.fromRGBO(251, 191, 36, 1.0), // amber-400
              chipBg: const Color.fromRGBO(69, 26, 3, 0.3), // amber-950/30
              chipBorder: const Color.fromRGBO(153, 56, 0, 0.4), // amber-800/40
              hoverIconColor: const Color.fromRGBO(252, 211, 77, 1.0), // amber-300
              hoverChipBorder: const Color.fromRGBO(153, 56, 0, 0.4),
              title: 'Leaderboard & Leagues',
              subtitle: 'See where you stand with your cohort this week',
              onTap: () {
                AppFeedback.selection();
                unawaited(
                  context.router.push(const LeaderboardRoute()),
                );
              },
              showDividerBelow: false,
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ── Account & Security ───────────────────────────────────────────
        const _SectionLabel(title: 'Account & Security'),
        _SettingsGroup(
          children: [
            _NavTile(
              icon: Icons.lock_outline_rounded,
              iconColor: colors.textSecondary,
              chipBg: const Color.fromRGBO(39, 39, 42, 0.8), // zinc-800/80
              chipBorder: const Color.fromRGBO(63, 63, 70, 0.5), // zinc-700/50
              hoverIconColor: const Color.fromRGBO(34, 211, 238, 1.0), // cyan-400
              hoverChipBorder: const Color.fromRGBO(63, 63, 70, 0.5),
              title: 'Password & Two-Factor Sign-In',
              subtitle: 'Keep your study history safe',
              onTap: () {
                AppFeedback.light();
                unawaited(
                  context.router.push(SecuritySettingsRoute()),
                );
              },
            ),
            _NavTile(
              icon: Icons.workspace_premium_outlined,
              iconColor: const Color.fromRGBO(251, 191, 36, 1.0), // amber-400
              chipBg: const Color.fromRGBO(69, 26, 3, 0.3), // amber-950/30
              chipBorder: const Color.fromRGBO(153, 56, 0, 0.4), // amber-800/40
              hoverIconColor: const Color.fromRGBO(252, 211, 77, 1.0), // amber-300
              hoverChipBorder: const Color.fromRGBO(153, 56, 0, 0.4),
              title: 'Membership & Pro Tier',
              subtitle: 'Unlimited AI tutoring, sync and paper scans',
              badge: 'PRO',
              onTap: () {
                AppFeedback.light();
                unawaited(
                  context.router.push(PaywallRoute()),
                );
              },
              showDividerBelow: false,
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ── App & Support ────────────────────────────────────────────────
        const _SectionLabel(title: 'App & Support'),
        _SettingsGroup(
          children: [
            _NavTile(
              icon: Icons.tune_rounded,
              iconColor: colors.textSecondary,
              chipBg: const Color.fromRGBO(39, 39, 42, 0.8), // zinc-800/80
              chipBorder: const Color.fromRGBO(63, 63, 70, 0.5), // zinc-700/50
              hoverIconColor: const Color.fromRGBO(34, 211, 238, 1.0), // cyan-400
              hoverChipBorder: const Color.fromRGBO(63, 63, 70, 0.5),
              title: 'Appearance & Sounds',
              subtitle: 'Dark mode, haptics and notifications',
              onTap: () {
                AppFeedback.light();
                unawaited(
                  context.router.push(const AppPreferencesRoute()),
                );
              },
            ),
            _NavTile(
              icon: Icons.play_circle_outline_rounded,
              iconColor: colors.textSecondary,
              chipBg: const Color.fromRGBO(39, 39, 42, 0.8), // zinc-800/80
              chipBorder: const Color.fromRGBO(63, 63, 70, 0.5), // zinc-700/50
              hoverIconColor: const Color.fromRGBO(52, 211, 153, 1.0), // emerald-400
              hoverChipBorder: const Color.fromRGBO(63, 63, 70, 0.5),
              title: 'Feature Walkthrough',
              subtitle: 'Replay the quick tour of Kortexify',
              onTap: () {
                AppFeedback.light();
                unawaited(
                  showDialog<void>(
                    context: context,
                    builder: (_) => WelcomeWalkthroughDialog(
                      onEnterWorkspace: () {
                        if (context.mounted) {
                          unawaited(
                            AppGuidedTourOverlay.start(
                              context,
                              force: true,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                );
              },
            ),
            _NavTile(
              icon: Icons.info_outline_rounded,
              iconColor: colors.textSecondary,
              chipBg: const Color.fromRGBO(39, 39, 42, 0.8), // zinc-800/80
              chipBorder: const Color.fromRGBO(63, 63, 70, 0.5), // zinc-700/50
              hoverIconColor: const Color.fromRGBO(96, 165, 250, 1.0), // blue-400
              hoverChipBorder: const Color.fromRGBO(63, 63, 70, 0.5),
              title: 'About, Support & Discord',
              subtitle: 'Help center, privacy and community',
              onTap: () {
                AppFeedback.light();
                unawaited(
                  context.router.push(const AboutSupportRoute()),
                );
              },
              showDividerBelow: false,
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final typography = context.typography;

    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: typography.caption.bold.copyWith(
          color: const Color.fromRGBO(161, 161, 170, 1.0), // zinc-400
          fontSize: 11,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color.fromRGBO(18, 21, 28, 0.9), // cardBg/90
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color.fromRGBO(63, 63, 70, 0.8), // zinc-800/80
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.iconColor,
    required this.chipBg,
    required this.chipBorder,
    required this.hoverIconColor,
    required this.hoverChipBorder,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
    this.showDividerBelow = true,
  });

  final IconData icon;
  final Color iconColor;
  final Color chipBg;
  final Color chipBorder;
  final Color hoverIconColor;
  final Color hoverChipBorder;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;
  final bool showDividerBelow;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Column(
      children: [
        PlatformHoverBuilder(
          builder: (context, isHovered, child) {
            return InkWell(
              onTap: onTap,
              highlightColor: const Color.fromRGBO(63, 63, 70, 0.6), // zinc-800/60
              splashColor: Colors.transparent,
              child: AnimatedContainer(
                duration: AppMotion.snappy,
                curve: AppMotion.easeOutCubic,
                color: isHovered
                    ? const Color.fromRGBO(25, 29, 38, 0.4) // surfaceMuted/40
                    : Colors.transparent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    _IconChip(
                      icon: icon, 
                      iconColor: isHovered ? hoverIconColor : iconColor,
                      bgColor: chipBg,
                      borderColor: isHovered ? hoverChipBorder : chipBorder,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                title,
                                style: typography.body.bold.copyWith(
                                  color: isHovered
                                      ? Colors.white
                                      : const Color.fromRGBO(244, 244, 245, 1.0), // zinc-100
                                  fontSize: 14,
                                ),
                              ),
                              if (badge != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color.fromRGBO(251, 191, 36, 0.1), // amber-400/10
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: const Color.fromRGBO(245, 158, 11, 0.3), // amber-500/30
                                    ),
                                  ),
                                  child: Text(
                                    badge!,
                                    style: typography.caption.bold.copyWith(
                                      color: const Color.fromRGBO(252, 211, 77, 1.0), // amber-300
                                      fontSize: 9,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: typography.caption.regular.copyWith(
                              color: const Color.fromRGBO(161, 161, 170, 1.0), // zinc-400
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    AnimatedSlide(
                      offset: isHovered ? const Offset(0.1, 0) : Offset.zero,
                      duration: AppMotion.snappy,
                      curve: AppMotion.easeOutCubic,
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: isHovered
                            ? const Color.fromRGBO(212, 212, 216, 1.0) // zinc-300
                            : const Color.fromRGBO(113, 113, 122, 1.0), // zinc-500
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        if (showDividerBelow)
          Divider(
            height: 1,
            thickness: 1,
            color: const Color.fromRGBO(63, 63, 70, 0.6), // zinc-800/60
          ),
      ],
    );
  }
}

class _IconChip extends StatelessWidget {
  const _IconChip({
    required this.icon, 
    required this.iconColor,
    required this.bgColor,
    required this.borderColor,
  });

  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.snappy,
      curve: AppMotion.easeOutCubic,
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: Icon(icon, color: iconColor, size: 18),
    );
  }
}
