import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/services/notification_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/enums/theme_preset.dart';
import 'package:kortex/src/core/themes/theme_cubit.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/core/utils/use_case.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/profile/domain/entities/notification_preferences_entity.dart';
import 'package:kortex/src/features/profile/domain/use_cases/notification_preferences_use_cases.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Subpage for customizing appearance, sensory haptics, and study reminders.
@RoutePage()
class AppPreferencesPage extends HookWidget {
  const AppPreferencesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;
    final themeMode = context.watch<ThemeCubit>().state.themeMode;
    final activePreset = context.watch<ThemeCubit>().state.preset;

    LocalStorageService? localStorage;
    try {
      if (locator.isRegistered<LocalStorageService>()) {
        localStorage = locator<LocalStorageService>();
      }
    } on Object catch (_) {}

    final initialReminders =
        localStorage?.getPreference(key: 'study_reminders_enabled') != 'false';

    final haptics = useState<bool>(AppFeedback.isHapticsEnabled);
    final soundEffects = useState<bool>(AppFeedback.isSfxEnabled);

    final notificationPrefs = useState<NotificationPreferencesEntity>(
      NotificationPreferencesEntity(studyReminders: initialReminders),
    );

    useEffect(() {
      Future<void> fetchPreferences() async {
        try {
          if (locator.isRegistered<GetNotificationPreferencesUseCase>()) {
            final result = await locator<GetNotificationPreferencesUseCase>()(
              const NoParams(),
            );
            if (result.isRight) {
              notificationPrefs.value =
                  (result as Right<Failure, NotificationPreferencesEntity>)
                      .value;
            }
          }
        } on Object catch (_) {}
      }

      unawaited(fetchPreferences());
      return null;
    }, const []);

    void updateNotificationPref(NotificationPreferencesEntity newPrefs) {
      AppFeedback.selection();
      notificationPrefs.value = newPrefs;
      if (localStorage != null) {
        unawaited(
          localStorage.savePreference(
            key: 'study_reminders_enabled',
            data: newPrefs.studyReminders.toString(),
          ),
        );
      }
      if (!newPrefs.studyReminders &&
          locator.isRegistered<NotificationService>()) {
        unawaited(
          locator<NotificationService>().cancelAllNotifications(),
        );
      }
      if (locator.isRegistered<UpdateNotificationPreferencesUseCase>()) {
        unawaited(
          locator<UpdateNotificationPreferencesUseCase>()(newPrefs),
        );
      }
    }

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
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
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
                const SizedBox(height: 16),

                // 2. Accent Color Palette & Theme Presets (World-Class Redesign)
                _buildSectionContainer(
                  title: 'ACCENT PALETTE & COLOR ENGINE',
                  subtitle:
                      'Calibrate visual accent tones for maximum study focus',
                  colors: colors,
                  typography: typography,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Active Palette Hero Display Card
                      AnimatedContainer(
                        duration: AppMotion.snappy,
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: activePreset.defaultAccent.withAlpha(
                            isDark ? 35 : 20,
                          ),
                          borderRadius: AppRadius.radiusPanel,
                          border: Border.all(
                            color: activePreset.defaultAccent.withAlpha(
                              isDark ? 120 : 90,
                            ),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: activePreset.defaultAccent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: colors.white.withAlpha(160),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: activePreset.defaultAccent.withAlpha(
                                      90,
                                    ),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.palette_rounded,
                                color: colors.white,
                                size: 20,
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
                                        activePreset.displayName,
                                        style: typography.body.bold.copyWith(
                                          color: activePreset.defaultAccent,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: activePreset.defaultAccent,
                                          borderRadius: AppRadius.radiusMicro,
                                        ),
                                        child: Text(
                                          'ACTIVE',
                                          style: typography.caption.bold
                                              .copyWith(
                                                color: colors.white,
                                                fontSize: 9.5,
                                                letterSpacing: 0.8,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _getPresetDescription(activePreset),
                                    style: typography.caption.regular.copyWith(
                                      color: colors.textSecondary,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Palette Swatch Cards (2-Column Grid)
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              childAspectRatio: 2.8,
                            ),
                        itemCount: ThemePreset.values
                            .where(
                              (p) =>
                                  p.name != 'emeraldStem' &&
                                  p.name != 'royalAmethyst',
                            )
                            .length,
                        itemBuilder: (context, index) {
                          final presets = ThemePreset.values
                              .where(
                                (p) =>
                                    p.name != 'emeraldStem' &&
                                    p.name != 'royalAmethyst',
                              )
                              .toList();
                          final preset = presets[index];
                          final isSelected = activePreset == preset;
                          return PlatformHoverBuilder(
                            builder: (context, isHovered, child) {
                              return AnimatedScale(
                                scale: isHovered && !isSelected ? 1.02 : 1.0,
                                duration: AppMotion.snappy,
                                curve: Curves.easeOutCubic,
                                child: child,
                              );
                            },
                            child: ShrinkableButton(
                              onTap: () {
                                AppFeedback.selection();
                                unawaited(
                                  context.read<ThemeCubit>().setThemePreset(
                                    preset,
                                  ),
                                );
                              },
                              child: AnimatedContainer(
                                duration: AppMotion.snappy,
                                curve: Curves.easeOutCubic,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? preset.defaultAccent.withAlpha(
                                          isDark ? 35 : 20,
                                        )
                                      : colors.surfaceSecondary,
                                  borderRadius: AppRadius.radiusCard,
                                  border: Border.all(
                                    color: isSelected
                                        ? preset.defaultAccent
                                        : colors.surfaceBorder.withAlpha(80),
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: preset.defaultAccent,
                                        shape: BoxShape.circle,
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: preset.defaultAccent
                                                      .withAlpha(80),
                                                  blurRadius: 6,
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: isSelected
                                          ? Icon(
                                              Icons.check_rounded,
                                              color: colors.white,
                                              size: 14,
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        preset.displayName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: typography.caption.bold.copyWith(
                                          color: isSelected
                                              ? preset.defaultAccent
                                              : colors.textPrimary,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
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
                              soundEffects.value = val;
                              unawaited(
                                AppFeedback.setSfxEnabled(enabled: val),
                              );
                              if (val) AppFeedback.light();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 3. Granular Notification Control Matrix
                _buildSectionContainer(
                  title: l10n.preferencesNotificationsTitle,
                  subtitle: 'Customize push & local alert preferences',
                  colors: colors,
                  typography: typography,
                  child: Column(
                    children: [
                      // Toggle 1: Daily Study Reminders
                      _buildNotificationRow(
                        title: l10n.preferencesReminderTitle,
                        subtitle: l10n.preferencesReminderSubtitle,
                        value: notificationPrefs.value.studyReminders,
                        onChanged: (val) => updateNotificationPref(
                          notificationPrefs.value.copyWith(studyReminders: val),
                        ),
                        colors: colors,
                        typography: typography,
                      ),
                      const Divider(height: 18),

                      // Toggle 2: Streak Alerts & Freeze Notifications
                      _buildNotificationRow(
                        title: 'Streak Alerts & Freeze Warnings',
                        subtitle:
                            'Alerts before study streak resets at midnight',
                        value: notificationPrefs.value.streakAlerts,
                        onChanged: (val) => updateNotificationPref(
                          notificationPrefs.value.copyWith(streakAlerts: val),
                        ),
                        colors: colors,
                        typography: typography,
                      ),
                      const Divider(height: 18),

                      // Toggle 3: Timed Exam Pacing & Countdowns
                      _buildNotificationRow(
                        title: 'Exam Countdowns & Mock Pacing',
                        subtitle: 'Pacing reminders for upcoming target exams',
                        value: notificationPrefs.value.examAlerts,
                        onChanged: (val) => updateNotificationPref(
                          notificationPrefs.value.copyWith(examAlerts: val),
                        ),
                        colors: colors,
                        typography: typography,
                      ),
                      const Divider(height: 18),

                      // Toggle 4: Social & Community Forum Alerts
                      _buildNotificationRow(
                        title: 'Community Forum & Circle Alerts',
                        subtitle:
                            'Notifications when someone replies to your threads',
                        value: notificationPrefs.value.socialAlerts,
                        onChanged: (val) => updateNotificationPref(
                          notificationPrefs.value.copyWith(socialAlerts: val),
                        ),
                        colors: colors,
                        typography: typography,
                      ),
                      const Divider(height: 18),

                      // Toggle 5: Syllabot AI Ingestion & Synthesis
                      _buildNotificationRow(
                        title: 'Syllabot AI Document Ingestion',
                        subtitle:
                            'Alerts when document processing & OCR completes',
                        value: notificationPrefs.value.aiIngestionAlerts,
                        onChanged: (val) => updateNotificationPref(
                          notificationPrefs.value.copyWith(
                            aiIngestionAlerts: val,
                          ),
                        ),
                        colors: colors,
                        typography: typography,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required AppThemeColorsExtension colors,
    required TypographyThemeExtension typography,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: typography.body.medium.copyWith(
                  color: colors.textPrimary,
                  fontSize: 13.5,
                ),
              ),
              Text(
                subtitle,
                style: typography.caption.regular.copyWith(
                  color: colors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          activeTrackColor: colors.primary,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildSectionContainer({
    required String title,
    required String subtitle,
    required Widget child,
    required AppThemeColorsExtension colors,
    required TypographyThemeExtension typography,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: typography.caption.bold.copyWith(
                  color: colors.textSecondary.withAlpha(170),
                  fontSize: 11,
                  letterSpacing: 0.8,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: typography.caption.regular.copyWith(
                    color: colors.textSecondary.withAlpha(120),
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surfacePrimary,
            borderRadius: AppRadius.radiusDialog,
            border: Border.all(
              color: colors.surfaceBorder.withAlpha(80),
            ),
          ),
          child: child,
        ),
      ],
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
      child: PlatformHoverBuilder(
        builder: (context, isHovered, child) {
          return AnimatedContainer(
            duration: AppMotion.snappy,
            curve: Curves.easeOutCubic,
            transform: isHovered
                ? Matrix4.translationValues(0, -2, 0)
                : Matrix4.identity(),
            child: child,
          );
        },
        child: ShrinkableButton(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? colors.primary.withAlpha(28)
                  : colors.surfacePrimary,
              borderRadius: AppRadius.radiusCard,
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
      ),
    );
  }

  String _getPresetDescription(ThemePreset preset) {
    switch (preset) {
      case ThemePreset.cleanLight:
        return 'High-contrast minimal slate preset';
      case ThemePreset.slateDark:
        return 'Eye-strain engineering charcoal preset';
      case ThemePreset.midnightOled:
        return 'Pure OLED true black energy saver';
      case ThemePreset.alpineMoss:
        return 'Deep STEM Alpine Moss focus theme';
      case ThemePreset.warmOchre:
        return 'Academic Sandstone & Warm Ochre tone';
      case ThemePreset.deepBronze:
        return 'Editorial Amber & Deep Bronze accent';
      case ThemePreset.slateTerracotta:
        return 'Contrast Warmth & Slate Terracotta tint';
      case ThemePreset.quartzCyan:
        return 'Muted LaTeX Ink & Quartz Cyan accent';
      // ignore: deprecated_member_use_from_same_package -- Legacy theme alias.
      case ThemePreset.emeraldStem:
      // ignore: deprecated_member_use_from_same_package -- Legacy theme alias.
      case ThemePreset.royalAmethyst:
        return 'Custom Kortexify Scholar theme preset';
    }
  }
}
