import 'dart:async';
import 'dart:io';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
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

/// Subpage for Syllabot AI settings, reasoning preferences,
/// and offline weights manager.
@RoutePage()
class SyllabotAiSettingsPage extends HookWidget {
  const SyllabotAiSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

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
                  // 1. Socratic Reasoning Mode
                  _buildSectionCard(
                    title: 'Socratic Reasoning Preference',
                    subtitle: 'Controls how Syllabot structures explanations',
                    colors: colors,
                    typography: typography,
                    child: Column(
                      children: SocraticMode.values.map((mode) {
                        final isSelected = mode == socraticMode.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: PlatformHoverBuilder(
                            builder: (context, isHovered, child) {
                              return AnimatedContainer(
                                duration: AppMotion.snappy,
                                curve: Curves.easeOutCubic,
                                transform: isHovered
                                    ? Matrix4.translationValues(4, 0, 0)
                                    : Matrix4.identity(),
                                child: child,
                              );
                            },
                            child: ShrinkableButton(
                              onTap: () {
                                socraticMode.value = mode;
                                unawaited(
                                  storage?.savePreference(
                                    key: PrefKeys.syllabotSocraticMode,
                                    data: mode.name,
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? colors.primary.withAlpha(25)
                                      : colors.surfaceSecondary,
                                  borderRadius: AppRadius.radiusCard,
                                  border: Border.all(
                                    color: isSelected
                                        ? colors.primary
                                        : colors.surfaceBorder.withAlpha(80),
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      _getModeIcon(mode),
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            mode.nameString,
                                            style: typography.body.bold
                                                .copyWith(
                                                  color: isSelected
                                                      ? colors.primary
                                                      : colors.textPrimary,
                                                  fontSize: 13.5,
                                                ),
                                          ),
                                          Text(
                                            _getModeSubtitle(mode),
                                            style: typography.caption.regular
                                                .copyWith(
                                                  color: colors.textSecondary,
                                                  fontSize: 11.5,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      Icon(
                                        Icons.check_circle_rounded,
                                        color: colors.primary,
                                        size: 18,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 2. Voice Dialogue Persona & Speech Speed
                  _buildSectionCard(
                    title: 'Voice Dialogue Persona',
                    subtitle: 'Audio characteristics for spoken conversations',
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
                              segments: const [
                                ButtonSegment(
                                  value: VoiceGender.female,
                                  label: Text(
                                    'Female',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ),
                                ButtonSegment(
                                  value: VoiceGender.male,
                                  label: Text(
                                    'Male',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ),
                              ],
                              selected: {voiceGender.value},
                              onSelectionChanged: (set) {
                                final g = set.first;
                                voiceGender.value = g;
                                unawaited(
                                  storage?.savePreference(
                                    key: PrefKeys.syllabotVoiceGender,
                                    data: g.name,
                                  ),
                                );
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
                              segments: const [
                                ButtonSegment(
                                  value: 0.8,
                                  label: Text(
                                    '0.8x',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ),
                                ButtonSegment(
                                  value: 1,
                                  label: Text(
                                    '1.0x',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ),
                                ButtonSegment(
                                  value: 1.2,
                                  label: Text(
                                    '1.2x',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ),
                              ],
                              selected: {speechRate.value},
                              onSelectionChanged: (set) {
                                final r = set.first;
                                speechRate.value = r;
                                unawaited(
                                  storage?.savePreference(
                                    key: PrefKeys.syllabotSpeechRate,
                                    data: r.toString(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!kIsWeb && Platform.isIOS) ...[
                    const SizedBox(height: 10),
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
                              'For the most natural voice, go to Settings → '
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
                  const SizedBox(height: 24),

                  // Save Action
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
                        unawaited(HapticFeedback.lightImpact());
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
                            message: 'AI preferences saved successfully!',
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
                        ),
                        child: Center(
                          child: Text(
                            'Apply Preferences',
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

  Widget _buildSectionCard({
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
        borderRadius: AppRadius.radiusDialog,
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

  String _getModeSubtitle(SocraticMode mode) {
    switch (mode) {
      case SocraticMode.stepByStep:
        return 'Guided probing questions to build first-principles intuition';
      case SocraticMode.directAnswer:
        return 'Concise, high-yield academic answers with key takeaways';
      case SocraticMode.examSim:
        return 'Strict examiner rubric grading with mark breakdown';
      case SocraticMode.deepResearch:
        return 'Rigorous derivations, proofs, and multi-source context';
      case SocraticMode.feynmanTeachBack:
        return 'Explain simply to Syllabot; AI identifies gaps, jargon, and tests mastery';
    }
  }
}
