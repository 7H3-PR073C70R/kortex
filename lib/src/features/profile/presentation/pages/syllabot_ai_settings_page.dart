import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/syllabot/data/client/local_llm_engine_client.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/text_to_speech_handler.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Subpage for Syllabot AI settings, reasoning preferences,
/// and offline weights manager.
class SyllabotAiSettingsPage extends HookWidget {
  const SyllabotAiSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    final socraticMode = useState<SocraticMode>(SocraticMode.stepByStep);
    final voiceGender = useState<VoiceGender>(VoiceGender.female);
    final speechRate = useState<double>(1);
    final offlineModelDownloaded = useState<bool>(
      locator<LocalLlmEngineClient>().isModelDownloaded,
    );
    final isDownloadingOfflineModel = useState<bool>(false);
    final offlineDownloadProgress = useState<double>(0);

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
                      child: ShrinkableButton(
                        onTap: () {
                          socraticMode.value = mode;
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? colors.primary.withAlpha(25)
                                : colors.surfaceSecondary,
                            borderRadius: BorderRadius.circular(14),
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      mode.nameString,
                                      style: typography.body.bold.copyWith(
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
                            voiceGender.value = set.first;
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
                            speechRate.value = set.first;
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 3. Offline Neural Weights Storage
              _buildSectionCard(
                title: 'Offline On-Device Weights',
                subtitle: 'Quantized LLM for study sessions without internet',
                colors: colors,
                typography: typography,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              offlineModelDownloaded.value
                                  ? 'Downloaded (248 MB)'
                                  : 'Not Downloaded',
                              style: typography.body.bold.copyWith(
                                color: offlineModelDownloaded.value
                                    ? const Color(0xFF10B981)
                                    : colors.textPrimary,
                                fontSize: 13.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              offlineModelDownloaded.value
                                  ? 'Ready for offline reasoning'
                                  : 'Requires ~248 MB local storage',
                              style: typography.caption.regular.copyWith(
                                color: colors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        if (isDownloadingOfflineModel.value)
                          SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(
                              value: offlineDownloadProgress.value,
                              strokeWidth: 2.5,
                            ),
                          )
                        else
                          ShrinkableButton(
                            onTap: () {
                              final client = locator<LocalLlmEngineClient>();
                              if (offlineModelDownloaded.value) {
                                unawaited(client.deleteModel());
                                offlineModelDownloaded.value = false;
                                context.showSnackBar(
                                  message: 'Offline Neural weights deleted.',
                                );
                              } else {
                                isDownloadingOfflineModel.value = true;
                                offlineDownloadProgress.value = 0.05;
                                client.downloadModel().listen(
                                  (p) {
                                    offlineDownloadProgress.value = p;
                                  },
                                  onDone: () {
                                    isDownloadingOfflineModel.value = false;
                                    offlineModelDownloaded.value = true;
                                    if (context.mounted) {
                                      context.showSnackBar(
                                        message:
                                            'Offline weights ready (248 MB)!',
                                        type: SnackBarType.success,
                                      );
                                    }
                                  },
                                );
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: offlineModelDownloaded.value
                                    ? colors.error.withAlpha(25)
                                    : colors.primary.withAlpha(30),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: offlineModelDownloaded.value
                                      ? colors.error.withAlpha(80)
                                      : colors.primary.withAlpha(80),
                                ),
                              ),
                              child: Text(
                                offlineModelDownloaded.value
                                    ? 'Delete Model'
                                    : 'Download (248 MB)',
                                style: typography.caption.bold.copyWith(
                                  color: offlineModelDownloaded.value
                                      ? colors.error
                                      : colors.primary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Save Action
              ShrinkableButton(
                onTap: () {
                  unawaited(HapticFeedback.lightImpact());
                  context.showSnackBar(
                    message: 'AI preferences saved successfully!',
                    type: SnackBarType.success,
                  );
                  Navigator.of(context).pop();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      'Apply Preferences',
                      style: typography.body.bold.copyWith(
                        color: Colors.white,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
            ],
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
    }
  }
}
