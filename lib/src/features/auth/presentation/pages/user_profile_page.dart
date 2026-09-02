import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/features/auth/domain/entities/user_profile_entity.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_event.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_state.dart';
import 'package:kortex/src/features/monetization/presentation/screens/paywall_screen.dart';
import 'package:kortex/src/features/profile/presentation/pages/about_support_page.dart';
import 'package:kortex/src/features/profile/presentation/pages/academic_track_settings_page.dart';
import 'package:kortex/src/features/profile/presentation/pages/account_security_page.dart';
import 'package:kortex/src/features/profile/presentation/pages/app_preferences_page.dart';
import 'package:kortex/src/features/profile/presentation/pages/security_settings_page.dart';
import 'package:kortex/src/features/profile/presentation/pages/syllabot_ai_settings_page.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_dialog.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

@RoutePage()
class UserProfilePage extends HookWidget {
  const UserProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    useEffect(() {
      context.read<AuthBloc>().add(const AuthProfileFetchRequested());
      return null;
    }, const []);

    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (!state.isAuthenticated) {
          unawaited(context.router.root.replaceAll([const LoginRoute()]));
        }
      },
      builder: (context, state) {
        final profile = state.userProfile;
        final targetTrack = profile?.targetTrack ?? 'WAEC';
        final dailyTarget = profile?.dailyCardTarget ?? 20;

        return Scaffold(
          backgroundColor: colors.backgroundPrimary,
          appBar: AppBar(
            backgroundColor: colors.backgroundPrimary,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: Text(
              l10n.userProfileTitle,
              style: typography.title2.bold.copyWith(
                color: colors.textPrimary,
                fontSize: 20,
              ),
            ),
            actions: [
              // Pro Upgrade Badge Button
              ShrinkableButton(
                onTap: () {
                  AppFeedback.selection();
                  unawaited(
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const PaywallScreen(),
                      ),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 14),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colors.primary,
                        colors.syllabotAccent,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Pro',
                        style: typography.caption.bold.copyWith(
                          color: Colors.white,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Profile Header & Identity Card
                  _buildProfileCard(
                    context,
                    profile,
                    colors,
                    typography,
                    isDark,
                  ),
                  const SizedBox(height: 16),

                  // 2. Study Performance Quick Metrics Matrix
                  _buildMetricsGrid(profile, colors, typography, isDark),
                  const SizedBox(height: 18),

                  // 3. Active Target Track Highlight Capsule
                  _buildActiveTrackHighlight(
                    context,
                    targetTrack,
                    dailyTarget,
                    colors,
                    typography,
                    isDark,
                  ),
                  const SizedBox(height: 22),

                  // 4. Grouped Settings & Features Navigation
                  Text(
                    'Preferences & Management',
                    style: typography.body.bold.copyWith(
                      color: colors.textPrimary,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildNavigationMenu(context, colors, typography, isDark),
                  const SizedBox(height: 24),

                  // 5. Sign Out Action Button
                  Center(
                    child: ShrinkableButton(
                      onTap: () => _confirmSignOut(context, colors, typography),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: colors.error.withAlpha(isDark ? 30 : 15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: colors.error.withAlpha(isDark ? 80 : 50),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.logout_rounded,
                              color: colors.error,
                              size: 17,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              l10n.signOutButton,
                              style: typography.footnote.bold.copyWith(
                                color: colors.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 6. App Version & Build Footer
                  Center(
                    child: Text(
                      'Kortexify v1.2.0 • Build 1 • Advanced STEM AI',
                      style: typography.caption.regular.copyWith(
                        color: colors.textSecondary.withAlpha(120),
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileCard(
    BuildContext context,
    UserProfileEntity? profile,
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
    bool isDark,
  ) {
    final displayName = profile?.displayName ?? 'Kortexify Scholar';
    final email = profile?.email ?? 'scholar@kortexify.com';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceSecondary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.surfaceBorder.withAlpha(isDark ? 100 : 70),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: colors.primary.withAlpha(40),
            child: Text(
              displayName.isNotEmpty ? displayName[0].toUpperCase() : 'K',
              style: typography.title2.bold.copyWith(
                color: colors.primary,
                fontSize: 20,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        style: typography.body.bold.copyWith(
                          color: colors.textPrimary,
                          fontSize: 15.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary.withAlpha(30),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Tier 1',
                        style: typography.caption.bold.copyWith(
                          color: colors.primary,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: typography.caption.regular.copyWith(
                    color: colors.textSecondary,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.edit_outlined,
              color: colors.textSecondary,
              size: 20,
            ),
            tooltip: 'Edit Profile Name',
            onPressed: () => _showEditProfileDialog(context, displayName),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(
    UserProfileEntity? profile,
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
    bool isDark,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildMetricTile(
            title: 'Daily Streak',
            value: '${profile?.streakDays ?? 0} Days 🔥',
            accentColor: Colors.orangeAccent,
            colors: colors,
            typography: typography,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricTile(
            title: 'Scholar Rank',
            value: 'Level ${profile?.level ?? 1} 🎯',
            accentColor: colors.primary,
            colors: colors,
            typography: typography,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricTile(
            title: 'Retention',
            value:
                '${((profile?.retentionBenchmark ?? 0.85) * 100).toInt()}% 🧠',
            accentColor: const Color(0xFF10B981),
            colors: colors,
            typography: typography,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required Color accentColor,
    required AppThemeColorsExtension colors,
    required TypographyThemeExtension typography,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surfaceSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withAlpha(isDark ? 50 : 30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: typography.caption.medium.copyWith(
              color: colors.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: typography.body.bold.copyWith(
              color: accentColor,
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTrackHighlight(
    BuildContext context,
    String track,
    int dailyTarget,
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
    bool isDark,
  ) {
    return ShrinkableButton(
      onTap: () {
        AppFeedback.selection();
        unawaited(
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const AcademicTrackSettingsPage(),
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colors.primary.withAlpha(isDark ? 45 : 25),
              colors.surfaceSecondary,
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: colors.primary.withAlpha(isDark ? 90 : 60),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.primary.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.school_rounded,
                color: Colors.blueAccent,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Target: $track',
                        style: typography.body.bold.copyWith(
                          color: colors.textPrimary,
                          fontSize: 14.5,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary.withAlpha(25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$dailyTarget cards/day',
                          style: typography.caption.bold.copyWith(
                            color: colors.primary,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Custom syllabus, exam countdown & FSRS scheduling',
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
              color: colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationMenu(
    BuildContext context,
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceSecondary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.surfaceBorder.withAlpha(80),
        ),
      ),
      child: Column(
        children: [
          _buildNavTile(
            context: context,
            icon: Icons.track_changes_rounded,
            iconColor: Colors.blueAccent,
            title: 'Academic Track & Study Goals',
            subtitle: 'Calibrate target exams and daily review load',
            onTap: () {
              unawaited(
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AcademicTrackSettingsPage(),
                  ),
                ),
              );
            },
            colors: colors,
            typography: typography,
            showDivider: true,
          ),
          _buildNavTile(
            context: context,
            icon: Icons.psychology_rounded,
            iconColor: Colors.purpleAccent,
            title: 'Syllabot AI & Neural Engine',
            subtitle: 'Socratic mode, voice persona & offline weights',
            onTap: () {
              unawaited(
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SyllabotAiSettingsPage(),
                  ),
                ),
              );
            },
            colors: colors,
            typography: typography,
            showDivider: true,
          ),
          _buildNavTile(
            context: context,
            icon: Icons.lock_outline_rounded,
            iconColor: Colors.redAccent,
            title: 'Security & Access Control',
            subtitle: 'Password change, active sessions & biometric lock',
            onTap: () {
              unawaited(
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SecuritySettingsPage(),
                  ),
                ),
              );
            },
            colors: colors,
            typography: typography,
            showDivider: true,
          ),
          _buildNavTile(
            context: context,
            icon: Icons.workspace_premium_rounded,
            iconColor: Colors.amberAccent,
            title: 'Membership & Pro Tier',
            subtitle: 'Unlimited Syllabot AI, cloud sync & OCR',
            onTap: () {
              unawaited(
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PaywallScreen(),
                  ),
                ),
              );
            },
            colors: colors,
            typography: typography,
            showDivider: true,
          ),
          _buildNavTile(
            context: context,
            icon: Icons.tune_rounded,
            iconColor: Colors.tealAccent,
            title: 'App & Sensory Preferences',
            subtitle: 'Dark mode, haptic feedback & notifications',
            onTap: () {
              unawaited(
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AppPreferencesPage(),
                  ),
                ),
              );
            },
            colors: colors,
            typography: typography,
            showDivider: true,
          ),
          _buildNavTile(
            context: context,
            icon: Icons.shield_outlined,
            iconColor: Colors.greenAccent,
            title: 'Account, Data & Export',
            subtitle: 'Export decks to Anki/PDF, manage storage cache',
            onTap: () {
              unawaited(
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AccountSecurityPage(),
                  ),
                ),
              );
            },
            colors: colors,
            typography: typography,
            showDivider: true,
          ),
          _buildNavTile(
            context: context,
            icon: Icons.info_outline_rounded,
            iconColor: Colors.indigoAccent,
            title: 'About, Support & Discord',
            subtitle: 'Help center, documentation & version info',
            onTap: () {
              unawaited(
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AboutSupportPage(),
                  ),
                ),
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

  void _showEditProfileDialog(BuildContext context, String currentName) {
    final controller = TextEditingController(text: currentName);
    unawaited(
      AppDialog.show(
        context: context,
        title: 'Edit Scholar Profile',
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: AppTextField(
            controller: controller,
            hintText: 'Enter your name or alias',
          ),
        ),
        primaryActionText: 'Save',
        onPrimaryAction: () async {
          final newName = controller.text.trim();
          if (newName.isNotEmpty) {
            Navigator.of(context).pop();
            try {
              if (Supabase.instance.isInitialized) {
                await Supabase.instance.client.auth.updateUser(
                  UserAttributes(data: {'display_name': newName}),
                );
              }
              AppFeedback.light();
              if (context.mounted) {
                context.read<AuthBloc>().add(
                      const AuthProfileFetchRequested(),
                    );
                context.showSnackBar(
                  message: 'Profile updated: $newName',
                  type: SnackBarType.success,
                );
              }
            } on Object catch (e) {
              if (context.mounted) {
                context.showSnackBar(
                  message: 'Could not sync name: $e',
                  type: SnackBarType.error,
                );
              }
            }
          }
        },
      ),
    );
  }

  void _confirmSignOut(
    BuildContext context,
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
  ) {
    AppFeedback.selection();
    unawaited(
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: colors.surfaceSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Sign Out of Kortex?',
            style: typography.title3.bold.copyWith(
              color: colors.textPrimary,
            ),
          ),
          content: Text(
            'Are you sure you want to sign out? Your study progress is '
            'securely synced to cloud.',
            style: typography.body.regular.copyWith(
              color: colors.textSecondary,
              fontSize: 13,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: colors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () {
                AppFeedback.medium();
                Navigator.of(ctx).pop();
                context.read<AuthBloc>().add(const AuthSignOutRequested());
                unawaited(
                  context.router.root.replaceAll([const LoginRoute()]),
                );
              },
              child: Text(
                'Sign Out',
                style: TextStyle(
                  color: colors.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
