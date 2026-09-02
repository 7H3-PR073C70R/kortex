import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/services/supabase_safe_helper.dart';
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
              // Pro Upgrade / Status Pill
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
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: profile?.isPro == true
                          ? [
                              const Color(0xFFF59E0B),
                              const Color(0xFFD97706),
                            ]
                          : [
                              colors.primary,
                              colors.syllabotAccent,
                            ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        profile?.isPro == true
                            ? Icons.verified_rounded
                            : Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        profile?.isPro == true ? 'Pro Active' : 'Go Pro',
                        style: typography.caption.bold.copyWith(
                          color: Colors.white,
                          fontSize: 12,
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
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Unified Scholar Hub Card (Identity + Quick Metrics)
                  _buildUnifiedScholarCard(
                    context,
                    state,
                    profile,
                    colors,
                    typography,
                    isDark,
                  ),
                  const SizedBox(height: 20),

                  // 2. Settings & Feature Management Menu
                  Text(
                    'Settings & Preferences',
                    style: typography.body.bold.copyWith(
                      color: colors.textPrimary,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildNavigationMenu(
                    context,
                    targetTrack,
                    dailyTarget,
                    colors,
                    typography,
                    isDark,
                  ),
                  const SizedBox(height: 24),

                  // 3. Sign Out Button
                  Center(
                    child: ShrinkableButton(
                      onTap: () => _confirmSignOut(context, colors, typography),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
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
                  const SizedBox(height: 14),

                  // 4. App Version Footer
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

  /// Unified card containing Scholar Avatar, Name, Email,
  /// and 3-stat performance row.
  Widget _buildUnifiedScholarCard(
    BuildContext context,
    AuthState state,
    UserProfileEntity? profile,
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
    bool isDark,
  ) {
    final displayName = profile?.displayName ??
        state.user?.displayName ??
        'Kortexify Scholar';
    final email = profile?.email ??
        state.user?.email ??
        SupabaseSafe.currentUser?.email ??
        'scholar@kortexify.com';

    final streakDays = profile?.streakDays ?? 0;
    final level = profile?.level ?? 1;
    final retentionPct =
        ((profile?.retentionBenchmark ?? 0.85) * 100).toInt();

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceSecondary,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colors.surfaceBorder.withAlpha(isDark ? 100 : 70),
        ),
      ),
      child: Column(
        children: [
          // Upper Identity Strip
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar with gradient glow
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colors.primary,
                        colors.syllabotAccent,
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      displayName.isNotEmpty
                          ? displayName[0].toUpperCase()
                          : 'K',
                      style: typography.title3.bold.copyWith(
                        color: Colors.white,
                        fontSize: 20,
                      ),
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
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: profile?.isPro == true
                                  ? const Color(0xFFF59E0B).withAlpha(35)
                                  : colors.primary.withAlpha(25),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              profile?.isPro == true ? 'PRO' : 'Free Tier',
                              style: typography.caption.bold.copyWith(
                                color: profile?.isPro == true
                                    ? const Color(0xFFF59E0B)
                                    : colors.primary,
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
                  onPressed: () => _showEditProfileDialog(
                    context,
                    displayName,
                  ),
                ),
              ],
            ),
          ),

          // Divider
          Divider(
            height: 1,
            color: colors.surfaceBorder.withAlpha(60),
          ),

          // Integrated 3-Stat Metric Strip
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Row(
              children: [
                Expanded(
                  child: _buildMetricCol(
                    label: 'Daily Streak',
                    value: '$streakDays Days 🔥',
                    colors: colors,
                    typography: typography,
                  ),
                ),
                Container(
                  height: 28,
                  width: 1,
                  color: colors.surfaceBorder.withAlpha(70),
                ),
                Expanded(
                  child: _buildMetricCol(
                    label: 'Scholar Rank',
                    value: 'Level $level 🎯',
                    colors: colors,
                    typography: typography,
                  ),
                ),
                Container(
                  height: 28,
                  width: 1,
                  color: colors.surfaceBorder.withAlpha(70),
                ),
                Expanded(
                  child: _buildMetricCol(
                    label: 'Retention',
                    value: '$retentionPct% 🧠',
                    colors: colors,
                    typography: typography,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCol({
    required String label,
    required String value,
    required AppThemeColorsExtension colors,
    required TypographyThemeExtension typography,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: typography.caption.bold.copyWith(
            color: colors.textPrimary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: typography.caption.regular.copyWith(
            color: colors.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  /// Categorized settings list
  Widget _buildNavigationMenu(
    BuildContext context,
    String targetTrack,
    int dailyTarget,
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
          // 1. Academic Track & Target
          _buildNavTile(
            context: context,
            icon: Icons.school_rounded,
            iconColor: Colors.blueAccent,
            title: 'Academic Track & Study Goals',
            subtitle: '$targetTrack • $dailyTarget cards/day target',
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

          // 2. Syllabot AI & Neural Engine
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

          // 3. Security & Access Control
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

          // 4. Membership & Pro Tier
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

          // 5. App & Sensory Preferences
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

          // 6. Account, Data & Export
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

          // 7. About, Support & Community
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
              final client = SupabaseSafe.client;
              if (client != null) {
                await client.auth.updateUser(
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
