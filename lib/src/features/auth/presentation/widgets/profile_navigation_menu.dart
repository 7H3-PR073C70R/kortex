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
    final neural = context.neural;
    final isDark = context.isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Learning & Progress ──────────────────────────────────────────
        const _SectionLabel(title: 'Learning & Progress'),
        _SettingsGroup(
          children: [
            _NavTile(
              icon: Icons.school_outlined,
              iconColor: isDark ? colors.textSecondary : colors.primary,
              chipBg: isDark
                  ? colors.surfaceSecondary
                  : colors.primary.withValues(alpha: 0.08),
              chipBorder: isDark
                  ? colors.surfaceBorder
                  : colors.primary.withValues(alpha: 0.2),
              hoverIconColor: neural.amber400,
              hoverChipBorder: neural.amber400.withValues(alpha: 0.4),
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
              iconColor: neural.purple500,
              chipBg: neural.purple500.withValues(alpha: isDark ? 0.15 : 0.1),
              chipBorder: neural.purple500.withValues(alpha: isDark ? 0.4 : 0.25),
              hoverIconColor: neural.purple500.withValues(alpha: 0.8),
              hoverChipBorder: neural.purple500.withValues(alpha: 0.4),
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
              iconColor: isDark
                  ? neural.amber400
                  : const Color.fromRGBO(217, 119, 6, 1),
              chipBg: neural.amber.withValues(alpha: isDark ? 0.15 : 0.1),
              chipBorder: neural.amber.withValues(alpha: isDark ? 0.4 : 0.25),
              hoverIconColor: neural.amber300,
              hoverChipBorder: neural.amber.withValues(alpha: 0.4),
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
              iconColor: isDark
                  ? colors.textSecondary
                  : const Color.fromRGBO(14, 116, 144, 1),
              chipBg: isDark
                  ? colors.surfaceSecondary
                  : const Color.fromRGBO(6, 182, 212, 0.08),
              chipBorder: isDark
                  ? colors.surfaceBorder
                  : const Color.fromRGBO(6, 182, 212, 0.2),
              hoverIconColor: neural.cyan400,
              hoverChipBorder: neural.cyan400.withValues(alpha: 0.4),
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
              iconColor: isDark
                  ? neural.amber400
                  : const Color.fromRGBO(217, 119, 6, 1),
              chipBg: neural.amber.withValues(alpha: isDark ? 0.15 : 0.1),
              chipBorder: neural.amber.withValues(alpha: isDark ? 0.4 : 0.25),
              hoverIconColor: neural.amber300,
              hoverChipBorder: neural.amber.withValues(alpha: 0.4),
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
              iconColor: isDark ? colors.textSecondary : colors.textPrimary,
              chipBg: colors.surfaceSecondary,
              chipBorder: colors.surfaceBorder,
              hoverIconColor: neural.cyan400,
              hoverChipBorder: colors.surfaceBorder,
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
              iconColor: isDark
                  ? neural.emerald400
                  : const Color.fromRGBO(5, 150, 105, 1),
              chipBg: neural.emerald.withValues(alpha: isDark ? 0.15 : 0.1),
              chipBorder: neural.emerald.withValues(alpha: isDark ? 0.4 : 0.25),
              hoverIconColor: neural.emerald400,
              hoverChipBorder: neural.emerald400.withValues(alpha: 0.4),
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
              iconColor: isDark ? colors.textSecondary : colors.textPrimary,
              chipBg: colors.surfaceSecondary,
              chipBorder: colors.surfaceBorder,
              hoverIconColor: neural.cyan300,
              hoverChipBorder: colors.surfaceBorder,
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
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10, top: 4),
      child: Text(
        title.toUpperCase(),
        style: typography.caption.bold.copyWith(
          color: colors.textMuted,
          fontSize: 11.5,
          letterSpacing: 0.8,
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
    final colors = context.colors;
    final isDark = context.isDarkMode;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfacePrimary,
        borderRadius: AppRadius.radiusPanel,
        border: Border.all(
          color: colors.surfaceBorder,
        ),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: colors.black.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : [
                BoxShadow(
                  color: colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
                BoxShadow(
                  color: colors.black.withValues(alpha: 0.02),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
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
    final isDark = context.isDarkMode;

    return Column(
      children: [
        PlatformHoverBuilder(
          builder: (context, isHovered, child) {
            return InkWell(
              onTap: onTap,
              highlightColor: colors.surfaceTertiary,
              splashColor: context.colors.transparent,
              child: AnimatedContainer(
                duration: AppMotion.snappy,
                curve: AppMotion.easeOutCubic,
                color: isHovered
                    ? colors.surfaceSecondary
                    : context.colors.transparent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
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
                                  color: colors.textPrimary,
                                  fontSize: 14,
                                ),
                              ),
                              if (badge != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color.fromRGBO(245, 158, 11, 0.15)
                                        : const Color.fromRGBO(245, 158, 11, 0.12),
                                    borderRadius: AppRadius.radiusMicro,
                                    border: Border.all(
                                      color: isDark
                                          ? const Color.fromRGBO(245, 158, 11, 0.35)
                                          : const Color.fromRGBO(245, 158, 11, 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    badge!,
                                    style: typography.caption.bold.copyWith(
                                      color: isDark
                                          ? const Color.fromRGBO(252, 211, 77, 1)
                                          : const Color.fromRGBO(180, 83, 9, 1),
                                      fontSize: 9.5,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: typography.caption.regular.copyWith(
                              color: colors.textSecondary,
                              fontSize: 12.5,
                              height: 1.35,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedSlide(
                      offset: isHovered ? const Offset(0.08, 0) : Offset.zero,
                      duration: AppMotion.snappy,
                      curve: AppMotion.easeOutCubic,
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: isHovered
                            ? colors.textPrimary
                            : colors.textMuted,
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
            color: colors.surface.withValues(alpha: isDark ? 0.7 : 0.6),
            indent: 70,
            endIndent: 16,
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
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadius.radiusCard,
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: Icon(icon, color: iconColor, size: 20),
    );
  }
}
