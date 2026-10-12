import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/text_to_speech_handler.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Card displaying the tiered voice synthesis pipeline status and offline
/// Kokoro neural voice pack download progress.
class SyllabotStudioVoicePackCard extends StatelessWidget {
  const SyllabotStudioVoicePackCard({
    required this.ttsHandler,
    super.key,
  });

  final TextToSpeechHandler ttsHandler;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tiered Pipeline Status Card
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: colors.surfaceSecondary.withAlpha(120),
            borderRadius: AppRadius.radiusBadge,
            border: Border.all(
              color: colors.surfaceBorder.withAlpha(60),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 14,
                color: colors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tiered: Cloud Neural (Online) → On-Device Neural (Offline) → System Fallback',
                  style: typography.caption.medium.copyWith(
                    color: colors.textSecondary,
                    fontSize: 10.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Offline Neural Model Resumable Download Status Card
        ValueListenableBuilder<bool>(
          valueListenable: ttsHandler.isKokoroModelReadyNotifier,
          builder: (context, isReady, _) {
            return ValueListenableBuilder<double>(
              valueListenable: ttsHandler.kokoroDownloadProgressNotifier,
              builder: (context, progress, _) {
                return ValueListenableBuilder<String>(
                  valueListenable: ttsHandler.kokoroDownloadStatusNotifier,
                  builder: (context, statusText, _) {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isReady
                            ? colors.success.withAlpha(20)
                            : colors.surfaceSecondary,
                        borderRadius: AppRadius.radiusCard,
                        border: Border.all(
                          color: isReady
                              ? colors.success.withAlpha(80)
                              : colors.surfaceBorder.withAlpha(70),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isReady
                                    ? Icons.check_circle_rounded
                                    : Icons.downloading_rounded,
                                size: 16,
                                color: isReady
                                    ? colors.success
                                    : colors.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  isReady
                                      ? 'Offline Neural Voice Pack Ready'
                                      : 'Offline Voice Pack Status',
                                  style: typography.body.bold.copyWith(
                                    fontSize: 12,
                                    color: isReady
                                        ? colors.success
                                        : colors.textPrimary,
                                  ),
                                ),
                              ),
                              if (!isReady)
                                ShrinkableButton(
                                  onTap: () {
                                    AppFeedback.light();
                                    unawaited(
                                      ttsHandler.startKokoroModelDownload(),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colors.primary,
                                      borderRadius: AppRadius.radiusBadge,
                                    ),
                                    child: Text(
                                      'Download / Resume',
                                      style: typography.caption.bold.copyWith(
                                        color: colors.surface,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            statusText,
                            style: typography.caption.regular.copyWith(
                              color: colors.textSecondary,
                              fontSize: 10.5,
                            ),
                          ),
                          if (!isReady && progress > 0 && progress < 1.0) ...[
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: AppRadius.radiusBadge,
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 4,
                                backgroundColor:
                                    colors.surfaceBorder.withAlpha(50),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  colors.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }
}
