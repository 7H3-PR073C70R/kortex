import 'dart:async';
import 'dart:convert';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/domain/entities/user_profile_entity.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_event.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_state.dart';
import 'package:kortex/src/features/monetization/presentation/screens/paywall_screen.dart';
import 'package:kortex/src/features/profile/domain/use_cases/update_avatar_use_case.dart';
import 'package:kortex/src/features/profile/domain/use_cases/update_display_name_use_case.dart';
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
                      'Kortexify v1.2.0 • Neural Study AI',
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
        'scholar@kortexify.com';

    final streakDays = profile?.streakDays ?? 0;
    final level = profile?.level ?? 1;
    final retentionPct =
        ((profile?.retentionBenchmark ?? 0.85) * 100).toInt();

    final photoUrl = profile?.photoUrl;

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
                // Interactive Avatar with gradient glow and edit badge
                ShrinkableButton(
                  onTap: () => _showAvatarPickerDialog(
                    context,
                    colors,
                    typography,
                  ),
                  child: Stack(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colors.primary,
                              colors.syllabotAccent,
                            ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: colors.primary.withAlpha(isDark ? 80 : 40),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Center(
                          child: _buildAvatarContent(
                            photoUrl: photoUrl,
                            displayName: displayName,
                            typography: typography,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: colors.surfacePrimary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colors.surfaceBorder,
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            Icons.camera_alt_rounded,
                            size: 11,
                            color: colors.primary,
                          ),
                        ),
                      ),
                    ],
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

  Widget _buildAvatarContent({
    required String? photoUrl,
    required String displayName,
    required TypographyThemeExtension typography,
  }) {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      if (photoUrl.startsWith('emoji:')) {
        return Text(
          photoUrl.replaceFirst('emoji:', ''),
          style: const TextStyle(fontSize: 26),
        );
      } else if (photoUrl.startsWith('data:image')) {
        try {
          final base64String = photoUrl.contains(',')
              ? photoUrl.split(',').last
              : photoUrl;
          final bytes = base64Decode(base64String);
          return ClipOval(
            child: Image.memory(
              bytes,
              width: 54,
              height: 54,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Text(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : 'K',
                style: typography.title3.bold.copyWith(
                  color: Colors.white,
                  fontSize: 20,
                ),
              ),
            ),
          );
        } on Object catch (_) {}
      } else if (photoUrl.startsWith('http://') ||
          photoUrl.startsWith('https://')) {
        return ClipOval(
          child: Image.network(
            photoUrl,
            width: 54,
            height: 54,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Text(
              displayName.isNotEmpty ? displayName[0].toUpperCase() : 'K',
              style: typography.title3.bold.copyWith(
                color: Colors.white,
                fontSize: 20,
              ),
            ),
          ),
        );
      }
    }

    return Text(
      displayName.isNotEmpty ? displayName[0].toUpperCase() : 'K',
      style: typography.title3.bold.copyWith(
        color: Colors.white,
        fontSize: 20,
      ),
    );
  }

  void _showAvatarPickerDialog(
    BuildContext context,
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
  ) {
    AppFeedback.selection();
    final urlController = TextEditingController();

    final avatars = [
      {'emoji': '🎓', 'label': 'Scholar', 'id': 'emoji:🎓'},
      {'emoji': '📚', 'label': 'Academic', 'id': 'emoji:📚'},
      {'emoji': '💡', 'label': 'Innovator', 'id': 'emoji:💡'},
      {'emoji': '🎨', 'label': 'Creative', 'id': 'emoji:🎨'},
      {'emoji': '⚖️', 'label': 'Law', 'id': 'emoji:⚖️'},
      {'emoji': '🩺', 'label': 'Medical', 'id': 'emoji:🩺'},
      {'emoji': '💼', 'label': 'Business', 'id': 'emoji:💼'},
      {'emoji': '🔬', 'label': 'Science', 'id': 'emoji:🔬'},
      {'emoji': '🌍', 'label': 'Humanities', 'id': 'emoji:🌍'},
      {'emoji': '✍️', 'label': 'Author', 'id': 'emoji:✍️'},
    ];

    unawaited(
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (ctx) => Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 14,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          decoration: BoxDecoration(
            color: colors.surfacePrimary,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: colors.surfaceBorder.withAlpha(90),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.surfaceBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Customize Profile Avatar',
                    style: typography.title3.bold.copyWith(
                      color: colors.textPrimary,
                      fontSize: 17,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: colors.textSecondary,
                      size: 20,
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Upload a photo from your device or pick a scholar avatar',
                style: typography.caption.regular.copyWith(
                  color: colors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 18),

              // 1. Device Photo Picker Buttons (Gallery & Camera)
              Row(
                children: [
                  Expanded(
                    child: ShrinkableButton(
                      onTap: () async {
                        Navigator.of(ctx).pop();
                        await _pickAndUploadPhoto(context, ImageSource.gallery);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colors.primary,
                              colors.syllabotAccent,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: colors.primary.withAlpha(50),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.photo_library_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Choose Photo',
                              style: typography.caption.bold.copyWith(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ShrinkableButton(
                      onTap: () async {
                        Navigator.of(ctx).pop();
                        await _pickAndUploadPhoto(context, ImageSource.camera);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surfaceSecondary,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: colors.primary.withAlpha(80),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.camera_alt_rounded,
                              color: colors.primary,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Take Photo',
                              style: typography.caption.bold.copyWith(
                                color: colors.textPrimary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Divider(height: 1, color: colors.surfaceBorder.withAlpha(70)),
              const SizedBox(height: 14),

              Text(
                'Or Select an Avatar Icon',
                style: typography.body.bold.copyWith(
                  color: colors.textPrimary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),

              // Aesthetic Avatar Tokens Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.78,
                ),
                itemCount: avatars.length,
                itemBuilder: (context, index) {
                  final item = avatars[index];
                  return ShrinkableButton(
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      await _persistPhotoUrl(context, item['id']!);
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.surfaceSecondary,
                            border: Border.all(
                              color: colors.surfaceBorder.withAlpha(90),
                              width: 1.2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              item['emoji']!,
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          item['label']!,
                          style: typography.caption.medium.copyWith(
                            color: colors.textSecondary,
                            fontSize: 10.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
              Divider(height: 1, color: colors.surfaceBorder.withAlpha(70)),
              const SizedBox(height: 12),

              // Custom Photo URL Input
              Text(
                'Or Web Photo Link',
                style: typography.body.bold.copyWith(
                  color: colors.textPrimary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: urlController,
                      hintText: 'https://example.com/photo.jpg',
                    ),
                  ),
                  const SizedBox(width: 8),
                  ShrinkableButton(
                    onTap: () async {
                      final url = urlController.text.trim();
                      if (url.isNotEmpty) {
                        Navigator.of(ctx).pop();
                        await _persistPhotoUrl(context, url);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Apply',
                        style: typography.caption.bold.copyWith(
                          color: Colors.white,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndUploadPhoto(
    BuildContext context,
    ImageSource source,
  ) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 85,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';

      if (context.mounted) {
        await _persistPhotoUrl(context, base64String);
      }
    } on Object catch (e) {
      if (context.mounted) {
        context.showSnackBar(
          message: 'Could not select photo: $e',
          type: SnackBarType.error,
        );
      }
    }
  }

  Future<void> _persistPhotoUrl(BuildContext context, String photoUrl) async {
    AppFeedback.light();
    // 1. Immediately reflect the change in local AuthBloc state
    context.read<AuthBloc>().add(AuthAvatarUpdated(photoUrl));

    // 2. Persist to cloud repository
    final result = await locator<UpdateAvatarUseCase>()(photoUrl);
    result.fold(
      (failure) {
        if (context.mounted) {
          context.showSnackBar(
            message: 'Could not sync avatar: ${failure.message}',
            type: SnackBarType.error,
          );
        }
      },
      (_) {
        if (context.mounted) {
          context.read<AuthBloc>().add(const AuthProfileFetchRequested());
          context.showSnackBar(
            message: 'Avatar updated successfully!',
            type: SnackBarType.success,
          );
        }
      },
    );
  }

  void _showEditProfileDialog(BuildContext context, String currentName) {
    final controller = TextEditingController(text: currentName);
    AppFeedback.selection();
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
            // Immediate optimistic reflection
            context.read<AuthBloc>().add(AuthDisplayNameUpdated(newName));
            final result = await locator<UpdateDisplayNameUseCase>()(newName);
            result.fold(
              (failure) {
                if (context.mounted) {
                  context.showSnackBar(
                    message: 'Could not sync name: ${failure.message}',
                    type: SnackBarType.error,
                  );
                }
              },
              (_) {
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
              },
            );
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
