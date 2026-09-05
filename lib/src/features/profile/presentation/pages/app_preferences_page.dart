import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/theme_cubit.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/profile/data/client/profile_api_client.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Subpage for customizing appearance, sensory haptics, and study reminders.
class AppPreferencesPage extends HookWidget {
  const AppPreferencesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final themeMode = context.watch<ThemeCubit>().state.themeMode;

    LocalStorageService? localStorage;
    try {
      if (locator.isRegistered<LocalStorageService>()) {
        localStorage = locator<LocalStorageService>();
      }
    } on Object catch (_) {}

    final initialReminders =
        localStorage?.getPreference(key: 'study_reminders_enabled') != 'false';

    final haptics = useState<bool>(AppFeedback.isHapticsEnabled);
    final notifications = useState<bool>(initialReminders);
    final soundEffects = useState<bool>(true);

    return Scaffold(
      backgroundColor: colors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: colors.backgroundPrimary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: colors.textPrimary,
            size: 18,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          l10n.preferencesTitle,
          style: typography.title3.bold.copyWith(
            color: colors.textPrimary,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Appearance Theme (3 options: System, Light, Dark)
              _buildSectionContainer(
                title: l10n.preferencesAppearanceTitle,
                subtitle: l10n.preferencesAppearanceSubtitle,
                colors: colors,
                typography: typography,
                child: Row(
                  children: [
                    Expanded(
                      child: _buildThemeCard(
                        context: context,
                        title: l10n.preferencesThemeSystem,
                        icon: Icons.brightness_auto_rounded,
                        isSelected: themeMode == ThemeMode.system,
                        onTap: () {
                          AppFeedback.selection();
                          unawaited(
                            context.read<ThemeCubit>().setThemeMode(
                              ThemeMode.system,
                            ),
                          );
                        },
                        colors: colors,
                        typography: typography,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildThemeCard(
                        context: context,
                        title: l10n.preferencesThemeLight,
                        icon: Icons.light_mode_rounded,
                        isSelected: themeMode == ThemeMode.light,
                        onTap: () {
                          AppFeedback.selection();
                          unawaited(
                            context.read<ThemeCubit>().setThemeMode(
                              ThemeMode.light,
                            ),
                          );
                        },
                        colors: colors,
                        typography: typography,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildThemeCard(
                        context: context,
                        title: l10n.preferencesThemeDark,
                        icon: Icons.dark_mode_rounded,
                        isSelected: themeMode == ThemeMode.dark,
                        onTap: () {
                          AppFeedback.selection();
                          unawaited(
                            context.read<ThemeCubit>().setThemeMode(
                              ThemeMode.dark,
                            ),
                          );
                        },
                        colors: colors,
                        typography: typography,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 2. Sensory & Audio Effects
              _buildSectionContainer(
                title: l10n.preferencesSensoryTitle,
                subtitle: l10n.preferencesSensorySubtitle,
                colors: colors,
                typography: typography,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.preferencesHapticsTitle,
                                style: typography.body.medium.copyWith(
                                  color: colors.textPrimary,
                                  fontSize: 13.5,
                                ),
                              ),
                              Text(
                                l10n.preferencesHapticsSubtitle,
                                style: typography.caption.regular.copyWith(
                                  color: colors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: haptics.value,
                          activeTrackColor: colors.primary,
                          onChanged: (val) {
                            haptics.value = val;
                            unawaited(
                              AppFeedback.setHapticsEnabled(enabled: val),
                            );
                            if (val) AppFeedback.light();
                          },
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.preferencesSfxTitle,
                                style: typography.body.medium.copyWith(
                                  color: colors.textPrimary,
                                  fontSize: 13.5,
                                ),
                              ),
                              Text(
                                l10n.preferencesSfxSubtitle,
                                style: typography.caption.regular.copyWith(
                                  color: colors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: soundEffects.value,
                          activeTrackColor: colors.primary,
                          onChanged: (val) {
                            AppFeedback.selection();
                            soundEffects.value = val;
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 3. Notifications & Study Reminders
              _buildSectionContainer(
                title: l10n.preferencesNotificationsTitle,
                subtitle: l10n.preferencesNotificationsSubtitle,
                colors: colors,
                typography: typography,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.preferencesReminderTitle,
                            style: typography.body.medium.copyWith(
                              color: colors.textPrimary,
                              fontSize: 13.5,
                            ),
                          ),
                          Text(
                            l10n.preferencesReminderSubtitle,
                            style: typography.caption.regular.copyWith(
                              color: colors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: notifications.value,
                      activeTrackColor: colors.primary,
                      onChanged: (val) {
                        AppFeedback.selection();
                        notifications.value = val;
                        if (localStorage != null) {
                          unawaited(
                            localStorage.savePreference(
                              key: 'study_reminders_enabled',
                              data: val.toString(),
                            ),
                          );
                        }
                        try {
                          if (locator.isRegistered<ProfileApiClient>()) {
                            final authState = context.read<AuthBloc>().state;
                            final userId =
                                authState.user?.id ?? authState.userProfile?.id;
                            if (authState.isAuthenticated && userId != null) {
                              unawaited(
                                locator<ProfileApiClient>()
                                    .updateNotificationPreferences(
                                  userId: userId,
                                  studyReminders: val,
                                  streakAlerts: val,
                                ),
                              );
                            }
                          }
                        } on Object catch (_) {}
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionContainer({
    required String title,
    required String subtitle,
    required Widget child,
    required AppThemeColorsExtension colors,
    required TypographyThemeExtension typography,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceSecondary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.surfaceBorder.withAlpha(80),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: typography.body.bold.copyWith(
              color: colors.textPrimary,
              fontSize: 14.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: typography.caption.regular.copyWith(
              color: colors.textSecondary,
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildThemeCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required AppThemeColorsExtension colors,
    required TypographyThemeExtension typography,
  }) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: title,
      child: ShrinkableButton(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? colors.primary.withAlpha(28)
                : colors.surfacePrimary,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? colors.primary
                  : colors.surfaceBorder.withAlpha(90),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? colors.primary : colors.textSecondary,
              ),
              const SizedBox(height: 6),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: typography.caption.bold.copyWith(
                  color: isSelected ? colors.primary : colors.textPrimary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
