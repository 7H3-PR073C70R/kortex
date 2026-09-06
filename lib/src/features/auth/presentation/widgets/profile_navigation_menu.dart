import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/welcome_walkthrough_dialog.dart';
import 'package:kortex/src/shared/widgets/app_guided_tour_overlay.dart';
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
    final typography = context.typography;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfacePrimary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.surfaceBorder.withAlpha(50),
        ),
      ),
      child: Column(
        children: [
          // 1. Academic Track & Goal Calibration
          _buildNavTile(
            context: context,
            icon: Icons.school_rounded,
            iconColor: colors.primary,
            title: 'Academic Track & Goals',
            subtitle: '$targetTrack · $dailyTarget cards/day target',
            onTap: () {
              unawaited(
                context.router.push(const AcademicTrackSettingsRoute()),
              );
            },
            colors: colors,
            typography: typography,
            showDivider: true,
          ),

          // 2. Syllabot AI & Neural Engine
          _buildNavTile(
            context: context,
            icon: Icons.psychology_rounded,
            iconColor: colors.syllabotAccent,
            title: 'Syllabot AI & Neural Engine',
            subtitle: 'Socratic mode, voice persona & offline weights',
            onTap: () {
              unawaited(
                context.router.push(const SyllabotAiSettingsRoute()),
              );
            },
            colors: colors,
            typography: typography,
            showDivider: true,
          ),

          // 3. Account & Security
          _buildNavTile(
            context: context,
            icon: Icons.shield_outlined,
            iconColor: colors.primary,
            title: 'Account & Security',
            subtitle: 'Credentials, password, 2FA, data export & cache',
            onTap: () {
              unawaited(
                context.router.push(const SecuritySettingsRoute()),
              );
            },
            colors: colors,
            typography: typography,
            showDivider: true,
          ),

          // 4. Membership & Pro Tier
          _buildNavTile(
            context: context,
            icon: Icons.workspace_premium_rounded,
            iconColor: colors.warning,
            title: 'Membership & Pro Tier',
            subtitle: 'Unlimited Syllabot AI, cloud sync & OCR',
            onTap: () {
              unawaited(
                context.router.push(PaywallRoute()),
              );
            },
            colors: colors,
            typography: typography,
            showDivider: true,
          ),

          // 5. App & Sensory Preferences
          _buildNavTile(
            context: context,
            icon: Icons.tune_rounded,
            iconColor: colors.info,
            title: 'App & Sensory Preferences',
            subtitle: 'Dark mode, haptic feedback & notifications',
            onTap: () {
              unawaited(
                context.router.push(const AppPreferencesRoute()),
              );
            },
            colors: colors,
            typography: typography,
            showDivider: true,
          ),

          // 7. Interactive Feature Walkthrough
          _buildNavTile(
            context: context,
            icon: Icons.explore_rounded,
            iconColor: colors.syllabotAccent,
            title: 'Feature Walkthrough & Guide',
            subtitle: 'Replay the 4-step interactive onboarding tour',
            onTap: () {
              unawaited(
                showDialog<void>(
                  context: context,
                  builder: (_) => WelcomeWalkthroughDialog(
                    onEnterWorkspace: () {
                      if (context.mounted) {
                        unawaited(AppGuidedTourOverlay.start(context));
                      }
                    },
                  ),
                ),
              );
            },
            colors: colors,
            typography: typography,
            showDivider: true,
          ),

          // 8. About, Support & Community
          _buildNavTile(
            context: context,
            icon: Icons.info_outline_rounded,
            iconColor: colors.secondary,
            title: 'About, Support & Discord',
            subtitle: 'Help center, documentation & version info',
            onTap: () {
              unawaited(
                context.router.push(const AboutSupportRoute()),
              );
            },
            colors: colors,
            typography: typography,
            showDivider: false,
          ),
        ],
      ),
    );
  }

  Widget _buildNavTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required AppThemeColorsExtension colors,
    required TypographyThemeExtension typography,
    required bool showDivider,
  }) {
    return Column(
      children: [
        ShrinkableButton(
          onTap: () {
            AppFeedback.light();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: typography.body.bold.copyWith(
                          color: colors.textPrimary,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        style: typography.caption.regular.copyWith(
                          color: colors.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: colors.textSecondary.withAlpha(150),
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 64,
            endIndent: 16,
            color: colors.surfaceBorder.withAlpha(70),
          ),
      ],
    );
  }
}
