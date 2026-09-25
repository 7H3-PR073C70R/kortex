import 'dart:async';
import 'dart:io';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/text_to_speech_handler.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Subpage for Syllabot AI settings, consolidated Socratic reasoning preferences,
/// and voice dialogue controls.
@RoutePage()
class SyllabotAiSettingsPage extends HookWidget {
  const SyllabotAiSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final storage = locator.isRegistered<LocalStorageService>()
        ? locator<LocalStorageService>()
        : null;

    final initialMode = () {
      final raw = storage?.getPreference(key: PrefKeys.syllabotSocraticMode);
      if (raw != null) {
        return SocraticMode.values.firstWhere(
          (m) => m.name == raw,
          orElse: () => SocraticMode.stepByStep,
        );
      }
      return SocraticMode.stepByStep;
    }();

    final initialGender = () {
      final raw = storage?.getPreference(key: PrefKeys.syllabotVoiceGender);
      if (raw != null) {
        return VoiceGender.values.firstWhere(
          (g) => g.name == raw,
          orElse: () => VoiceGender.female,
        );
      }
      return VoiceGender.female;
    }();

    final initialRate = () {
      final raw = storage?.getPreference(key: PrefKeys.syllabotSpeechRate);
      if (raw != null) {
        final parsed = double.tryParse(raw);
        if (parsed != null && parsed > 0) return parsed;
      }
      return 1.0;
    }();

    final socraticMode = useState<SocraticMode>(initialMode);
    final voiceGender = useState<VoiceGender>(initialGender);
    final speechRate = useState<double>(initialRate);

    final activeMode = socraticMode.value;

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
          'Syllabot AI & Neural Engine',
          style: typography.title3.bold.copyWith(
            color: colors.textPrimary,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section 1: Socratic Reasoning Preference (Consolidated)
                  _buildSectionContainer(
                    title: 'SOCRATIC REASONING ENGINE',
                    subtitle: 'Select how Syllabot structures tutoring & explanations',
                    colors: colors,
                    typography: typography,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Active Mode Hero Display Card
                        AnimatedContainer(
                          duration: AppMotion.snappy,
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colors.primary.withAlpha(isDark ? 35 : 20),
                            borderRadius: AppRadius.radiusPanel,
                            border: Border.all(
                              color: colors.primary.withAlpha(isDark ? 110 : 80),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: colors.primary.withAlpha(40),
                                  borderRadius: AppRadius.radiusCard,
                                ),
                                child: Center(
                                  child: Text(
                                    _getModeIcon(activeMode),
                                    style: const TextStyle(fontSize: 22),
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
                                        Text(
                                          activeMode.label,
                                          style: typography.body.bold.copyWith(
                                            color: colors.primary,
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
                                            color: colors.primary,
                                            borderRadius: AppRadius.radiusMicro,
                                          ),
                                          child: Text(
                                            'ACTIVE',
                                            style: typography.caption.bold.copyWith(
                                              color: colors.white,
                                              fontSize: 9.5,
                                              letterSpacing: 0.8,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      activeMode.description,
                                      style: typography.caption.regular.copyWith(
                                        color: colors.textSecondary,
                                        fontSize: 12.5,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Mode Selector Chips Grid (2 Rows)
                        Text(
                          'CHOOSE STRATEGY',
                          style: typography.caption.bold.copyWith(
                            color: colors.textSecondary.withAlpha(140),
                            fontSize: 10,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: SocraticMode.values.map((mode) {
                            final isSelected = mode == activeMode;
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
                                  socraticMode.value = mode;
                                  if (storage != null) {
                                    unawaited(
                                      storage.savePreference(
                                        key: PrefKeys.syllabotSocraticMode,
                                        data: mode.name,
                                      ),
                                    );
                                  }
                                },
                                child: AnimatedContainer(
                                  duration: AppMotion.snappy,
                                  curve: Curves.easeOutCubic,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 9,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? colors.primary
                                        : colors.surfaceSecondary,
                                    borderRadius: AppRadius.radiusCard,
                                    border: Border.all(
                                      color: isSelected
                                          ? colors.primary
                                          : colors.surfaceBorder.withAlpha(80),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _getModeIcon(mode),
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        mode.label,
                                        style: typography.caption.bold.copyWith(
                                          color: isSelected
                                              ? colors.white
                                              : colors.textPrimary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Section 2: Voice Dialogue Persona
                  _buildSectionContainer(
                    title: 'VOICE DIALOGUE PERSONA',
                    subtitle: 'Audio characteristics for spoken interactions',
                    colors: colors,
                    typography: typography,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Persona Gender',
                              style: typography.body.medium.copyWith(
                                color: colors.textPrimary,
                                fontSize: 13.5,
                              ),
                            ),
                            SegmentedButton<VoiceGender>(
                              segments: [
                                ButtonSegment(
                                  value: VoiceGender.female,
                                  label: Text(
                                    'Female',
                                    style: typography.caption.bold.copyWith(fontSize: 11),
                                  ),
                                ),
                                ButtonSegment(
                                  value: VoiceGender.male,
                                  label: Text(
                                    'Male',
                                    style: typography.caption.bold.copyWith(fontSize: 11),
                                  ),
                                ),
                              ],
                              selected: {voiceGender.value},
                              onSelectionChanged: (set) {
                                AppFeedback.selection();
                                final g = set.first;
                                voiceGender.value = g;
                                if (storage != null) {
                                  unawaited(
                                    storage.savePreference(
                                      key: PrefKeys.syllabotVoiceGender,
                                      data: g.name,
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Speech Speed',
                              style: typography.body.medium.copyWith(
                                color: colors.textPrimary,
                                fontSize: 13.5,
                              ),
                            ),
                            SegmentedButton<double>(
                              segments: [
                                ButtonSegment(
                                  value: 0.8,
                                  label: Text(
                                    '0.8x',
                                    style: typography.caption.bold.copyWith(fontSize: 11),
                                  ),
                                ),
                                ButtonSegment(
                                  value: 1,
                                  label: Text(
                                    '1.0x',
                                    style: typography.caption.bold.copyWith(fontSize: 11),
                                  ),
                                ),
                                ButtonSegment(
                                  value: 1.2,
                                  label: Text(
                                    '1.2x',
                                    style: typography.caption.bold.copyWith(fontSize: 11),
                                  ),
                                ),
                              ],
                              selected: {speechRate.value},
                              onSelectionChanged: (set) {
                                AppFeedback.selection();
                                final r = set.first;
                                speechRate.value = r;
                                if (storage != null) {
                                  unawaited(
                                    storage.savePreference(
                                      key: PrefKeys.syllabotSpeechRate,
                                      data: r.toString(),
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!kIsWeb && Platform.isIOS) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary.withAlpha(18),
                        borderRadius: AppRadius.radiusPanel,
                        border: Border.all(
                          color: colors.primary.withAlpha(50),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.tips_and_updates_rounded,
                            size: 18,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'For the most natural voice quality, navigate to Settings → '
                              'Accessibility → Spoken Content → Voices → English '
                              'and download an Enhanced or Premium voice.',
                              style: typography.caption.regular.copyWith(
                                color: colors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),

                  // Apply Preferences Primary Action Button
                  PlatformHoverBuilder(
                    builder: (context, isHovered, child) {
                      return AnimatedScale(
                        scale: isHovered ? 1.01 : 1.0,
                        duration: AppMotion.snappy,
                        curve: Curves.easeOutCubic,
                        child: child,
                      );
                    },
                    child: ShrinkableButton(
                      onTap: () async {
                        AppFeedback.light();
                        if (storage != null) {
                          await storage.savePreference(
                            key: PrefKeys.syllabotSocraticMode,
                            data: socraticMode.value.name,
                          );
                          await storage.savePreference(
                            key: PrefKeys.syllabotVoiceGender,
                            data: voiceGender.value.name,
                          );
                          await storage.savePreference(
                            key: PrefKeys.syllabotSpeechRate,
                            data: speechRate.value.toString(),
                          );
                        }
                        if (context.mounted) {
                          context.showSnackBar(
                            message: 'Syllabot AI preferences updated successfully!',
                            type: SnackBarType.success,
                          );
                          Navigator.of(context).pop();
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: colors.primary,
                          borderRadius: AppRadius.radiusPanel,
                          boxShadow: [
                            BoxShadow(
                              color: colors.primary.withAlpha(50),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            'Save Neural Preferences',
                            style: typography.body.bold.copyWith(
                              color: colors.white,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
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

  String _getModeIcon(SocraticMode mode) {
    switch (mode) {
      case SocraticMode.stepByStep:
        return '🪜';
      case SocraticMode.directAnswer:
        return '🎯';
      case SocraticMode.examSim:
        return '📝';
      case SocraticMode.deepResearch:
        return '🔬';
      case SocraticMode.feynmanTeachBack:
        return '🧠';
    }
  }
}

