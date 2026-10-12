import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/text_to_speech_handler.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Sub-widget displaying the Syllabot Tutor Persona archetype cards.
class VoiceDialoguePersonaSection extends StatelessWidget {
  const VoiceDialoguePersonaSection({
    required this.tutorPersona,
    required this.ttsHandler,
    required this.isPlayingPreview,
    required this.speechRate,
    required this.voiceGender,
    this.localStorageService,
    super.key,
  });

  final ValueNotifier<String> tutorPersona;
  final TextToSpeechHandler ttsHandler;
  final ValueNotifier<bool> isPlayingPreview;
  final ValueNotifier<double> speechRate;
  final ValueNotifier<VoiceGender> voiceGender;
  final LocalStorageService? localStorageService;

  static const List<Map<String, String>> _archetypes = [
    {
      'title': 'Socratic Tutor',
      'icon': '🏛️',
      'desc': 'Scaffolded questions & deep conceptual breakdown.',
      'sample':
          'Hello! I am your Socratic AI Tutor. What concept would you like to explore today?',
    },
    {
      'title': 'Strict Exam Coach',
      'icon': '⏱️',
      'desc': 'High precision, timed drill pressure & direct feedback.',
      'sample':
          'Welcome scholar. Let us jump right into your exam drill questions and master key formulas.',
    },
    {
      'title': 'Friendly Peer',
      'icon': '🤝',
      'desc': 'Encouraging tone with relatable study analogies.',
      'sample':
          'Hey there! Ready to crush some study flashcards together? We got this!',
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
        Text(
          'TUTOR ARCHETYPE',
          style: typography.caption.bold.copyWith(
            color: colors.textSecondary.withAlpha(140),
            fontSize: 10,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        Column(
          children: _archetypes.map((p) {
            final title = p['title']!;
            final isSelected = tutorPersona.value == title;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: PlatformHoverBuilder(
                builder: (context, isHovered, child) {
                  return AnimatedScale(
                    scale: isHovered && !isSelected ? 1.01 : 1.0,
                    duration: AppMotion.snappy,
                    curve: Curves.easeOutCubic,
                    child: child,
                  );
                },
                child: ShrinkableButton(
                  onTap: () {
                    AppFeedback.selection();
                    tutorPersona.value = title;
                    if (localStorageService != null) {
                      unawaited(
                        localStorageService!.savePreference(
                          key: '__syllabot_tutor_persona',
                          data: title,
                        ),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colors.primary.withAlpha(isDark ? 40 : 20)
                          : colors.surfaceSecondary,
                      borderRadius: AppRadius.radiusCard,
                      border: Border.all(
                        color: isSelected
                            ? colors.primary
                            : colors.surfaceBorder.withAlpha(70),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          p['icon']!,
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: typography.body.bold.copyWith(
                                  color: isSelected
                                      ? colors.primary
                                      : colors.textPrimary,
                                  fontSize: 13.5,
                                ),
                              ),
                              Text(
                                p['desc']!,
                                style: typography.caption.regular.copyWith(
                                  color: colors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ShrinkableButton(
                          onTap: () async {
                            AppFeedback.light();
                            if (isPlayingPreview.value) {
                              await ttsHandler.stop();
                            } else {
                              await ttsHandler.setSpeechRate(
                                speechRate.value,
                              );
                              await ttsHandler.setVoiceGender(
                                voiceGender.value,
                              );
                              await ttsHandler.speak(
                                p['sample']!,
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: colors.primary.withAlpha(30),
                              borderRadius: AppRadius.radiusBadge,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isPlayingPreview.value
                                      ? Icons.stop_rounded
                                      : Icons.volume_up_rounded,
                                  size: 14,
                                  color: colors.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Sample',
                                  style: typography.caption.bold.copyWith(
                                    color: colors.primary,
                                    fontSize: 10.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
