import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kortex/src/core/constants/app_spacing.dart';
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/profile/presentation/widgets/syllabot_settings/syllabot_studio_voice_pack_card.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/text_to_speech_handler.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Sub-widget configuring persona gender, speech rate, pitch tuning,
/// Kokoro studio voices, and voice preview synthesis.
class VoiceDialogueAudioTuningSection extends StatelessWidget {
  const VoiceDialogueAudioTuningSection({
    required this.voiceGender,
    required this.speechRate,
    required this.speechPitch,
    required this.selectedVoiceName,
    required this.ttsHandler,
    required this.isPlayingPreview,
    this.localStorageService,
    super.key,
  });

  final ValueNotifier<VoiceGender> voiceGender;
  final ValueNotifier<double> speechRate;
  final ValueNotifier<double> speechPitch;
  final ValueNotifier<String?> selectedVoiceName;
  final TextToSpeechHandler ttsHandler;
  final ValueNotifier<bool> isPlayingPreview;
  final LocalStorageService? localStorageService;

  static const List<Map<String, dynamic>> _studioVoices = [
    {
      'id': 'Default',
      'label': 'Default',
      'tag': 'Studio Female',
      'gender': VoiceGender.female,
    },
    {
      'id': 'Bella',
      'label': 'Bella',
      'tag': 'Warm Female',
      'gender': VoiceGender.female,
    },
    {
      'id': 'Nicole',
      'label': 'Nicole',
      'tag': 'Crisp Tutor',
      'gender': VoiceGender.female,
    },
    {
      'id': 'Sarah',
      'label': 'Sarah',
      'tag': 'Articulate UK',
      'gender': VoiceGender.female,
    },
    {
      'id': 'Adam',
      'label': 'Adam',
      'tag': 'Mentor Male',
      'gender': VoiceGender.male,
    },
    {
      'id': 'Michael',
      'label': 'Michael',
      'tag': 'Academic Male',
      'gender': VoiceGender.male,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 24),

        // Persona Gender Selector
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
            AppSpacing.horizontalSpaceMedium,
            Expanded(
              child: SegmentedButton<VoiceGender>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: VoiceGender.female,
                    label: Text(
                      'Female',
                      style: typography.caption.bold.copyWith(
                        fontSize: 11,
                      ),
                    ),
                  ),
                  ButtonSegment(
                    value: VoiceGender.male,
                    label: Text(
                      'Male',
                      style: typography.caption.bold.copyWith(
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
                selected: {voiceGender.value},
                onSelectionChanged: (set) {
                  AppFeedback.selection();
                  final g = set.first;
                  voiceGender.value = g;
                  selectedVoiceName.value = null;
                  if (localStorageService != null) {
                    unawaited(
                      localStorageService!.savePreference(
                        key: PrefKeys.syllabotVoiceGender,
                        data: g.name,
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
        const Divider(height: 24),

        // Speech Speed Selector
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
            AppSpacing.horizontalSpaceMedium,
            Expanded(
              child: SegmentedButton<double>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: 0.8,
                    label: Text(
                      '0.8x',
                      style: typography.caption.bold.copyWith(
                        fontSize: 11,
                      ),
                    ),
                  ),
                  ButtonSegment(
                    value: 1,
                    label: Text(
                      '1.0x',
                      style: typography.caption.bold.copyWith(
                        fontSize: 11,
                      ),
                    ),
                  ),
                  ButtonSegment(
                    value: 1.2,
                    label: Text(
                      '1.2x',
                      style: typography.caption.bold.copyWith(
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
                selected: {speechRate.value},
                onSelectionChanged: (set) {
                  AppFeedback.selection();
                  final r = set.first;
                  speechRate.value = r;
                  if (localStorageService != null) {
                    unawaited(
                      localStorageService!.savePreference(
                        key: PrefKeys.syllabotSpeechRate,
                        data: r.toString(),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
        const Divider(height: 24),

        // Pitch Tuning Selector
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Pitch Tuning',
              style: typography.body.medium.copyWith(
                color: colors.textPrimary,
                fontSize: 13.5,
              ),
            ),
            AppSpacing.horizontalSpaceMedium,
            Expanded(
              child: SegmentedButton<double>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: 0.9,
                    label: Text(
                      'Warm (0.9x)',
                      style: typography.caption.bold.copyWith(
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                  ButtonSegment(
                    value: 1,
                    label: Text(
                      'Natural',
                      style: typography.caption.bold.copyWith(
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                  ButtonSegment(
                    value: 1.1,
                    label: Text(
                      'Crisp (1.1x)',
                      style: typography.caption.bold.copyWith(
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                ],
                selected: {speechPitch.value},
                onSelectionChanged: (set) {
                  AppFeedback.selection();
                  final p = set.first;
                  speechPitch.value = p;
                  if (localStorageService != null) {
                    unawaited(
                      localStorageService!.savePreference(
                        key: PrefKeys.syllabotVoicePitch,
                        data: p.toString(),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
        const Divider(height: 24),

        // Kokoro Studio Voices Grid
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'HIGH-QUALITY NEURAL VOICE',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: typography.caption.bold.copyWith(
                      color: colors.textSecondary.withAlpha(140),
                      fontSize: 10,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withAlpha(25),
                    borderRadius: AppRadius.radiusBadge,
                  ),
                  child: Text(
                    '24 kHz Studio Model',
                    style: typography.caption.bold.copyWith(
                      color: colors.primary,
                      fontSize: 9.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Offline-capable high-quality neural voice with automatic cloud acceleration when online.',
              style: typography.caption.regular.copyWith(
                color: colors.textSecondary,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _studioVoices.map((voice) {
                final voiceId = voice['id']! as String;
                final label = voice['label']! as String;
                final tag = voice['tag']! as String;
                final vGender = voice['gender']! as VoiceGender;
                final isSelected = selectedVoiceName.value == voiceId ||
                    (selectedVoiceName.value == null && voiceId == 'Bella');

                return ShrinkableButton(
                  onTap: () async {
                    AppFeedback.selection();
                    selectedVoiceName.value = voiceId;
                    voiceGender.value = vGender;
                    await ttsHandler.setKokoroVoice(voiceId);
                  },
                  child: AnimatedContainer(
                    duration: AppMotion.snappy,
                    width: 105,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colors.primary.withAlpha(isDark ? 50 : 25)
                          : colors.surfaceSecondary,
                      borderRadius: AppRadius.radiusCard,
                      border: Border.all(
                        color: isSelected
                            ? colors.primary
                            : colors.surfaceBorder.withAlpha(70),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: typography.body.bold.copyWith(
                                  color: isSelected
                                      ? colors.primary
                                      : colors.textPrimary,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                            if (isSelected) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.check_circle_rounded,
                                size: 14,
                                color: colors.primary,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tag,
                          style: typography.caption.regular.copyWith(
                            color: colors.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // Tiered pipeline & Kokoro download status card
            SyllabotStudioVoicePackCard(ttsHandler: ttsHandler),
          ],
        ),
        const SizedBox(height: 16),

        // Interactive "Test Selected Voice Mode" Banner Card
        ShrinkableButton(
          onTap: () async {
            AppFeedback.light();
            if (isPlayingPreview.value) {
              await ttsHandler.stop();
            } else {
              await ttsHandler.setSpeechRate(speechRate.value);
              await ttsHandler.setVoicePitch(speechPitch.value);
              await ttsHandler.setVoiceGender(voiceGender.value);
              await ttsHandler.setVoiceName(selectedVoiceName.value);
              await ttsHandler.speak(
                'Hello scholar! This is your custom neural voice mode preview for Syllabot AI.',
              );
            }
          },
          child: AnimatedContainer(
            duration: AppMotion.snappy,
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: isPlayingPreview.value
                  ? colors.error.withAlpha(30)
                  : colors.primary.withAlpha(isDark ? 40 : 20),
              borderRadius: AppRadius.radiusCard,
              border: Border.all(
                color: isPlayingPreview.value
                    ? colors.error
                    : colors.primary.withAlpha(90),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isPlayingPreview.value
                        ? colors.error
                        : colors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPlayingPreview.value
                        ? Icons.stop_rounded
                        : Icons.play_arrow_rounded,
                    color: colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPlayingPreview.value
                            ? 'Speaking Sample...'
                            : 'Test Selected Voice Mode',
                        style: typography.body.bold.copyWith(
                          color: isPlayingPreview.value
                              ? colors.error
                              : colors.primary,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Click to preview human voice audio synthesis',
                        style: typography.caption.regular.copyWith(
                          color: colors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
