import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/speech_to_text_handler.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Interactive Voice Note recorder widget supporting:
/// - Hold to record (releasing stops & completes recording)
/// - Drag up to lock (activates hands-free locked mode)
/// - Explicit "Done" button to complete when locked
/// - Trash / Cancel button to discard
/// - Live duration timer & live Speech-to-Text transcript preview
class VoiceNoteRecorderWidget extends HookWidget {
  const VoiceNoteRecorderWidget({
    required this.onRecordingComplete,
    required this.onCancel,
    this.onTranscriptUpdate,
    this.compact = false,
    super.key,
  });

  final void Function({
    required String audioUrl,
    required int durationSeconds,
    required String transcript,
  }) onRecordingComplete;

  final VoidCallback onCancel;
  final ValueChanged<String>? onTranscriptUpdate;
  final bool compact;

  String _formatDuration(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final isRecording = useState<bool>(false);
    final isLocked = useState<bool>(false);
    final dragOffset = useState<double>(0);
    final durationSeconds = useState<int>(0);
    final transcriptText = useState<String>('');
    final recordingTimer = useRef<Timer?>(null);

    final sttHandler = useMemoized(
      () => SpeechToTextHandler(
        onResult: (words) {
          if (words.trim().isNotEmpty) {
            transcriptText.value = words;
            onTranscriptUpdate?.call(words);
          }
        },
        onListeningChanged: (listening) {
          if (listening && !isRecording.value) {
            isRecording.value = true;
            durationSeconds.value = 0;
            recordingTimer.value?.cancel();
            recordingTimer.value = Timer.periodic(
              const Duration(seconds: 1),
              (timer) {
                durationSeconds.value = timer.tick;
              },
            );
          }
        },
        onError: (err) {
          recordingTimer.value?.cancel();
          isRecording.value = false;
          isLocked.value = false;
        },
      ),
    );

    useEffect(() {
      return () {
        recordingTimer.value?.cancel();
        sttHandler.dispose();
      };
    }, const []);

    void startRecordingSession() {
      if (isRecording.value) return;
      unawaited(HapticFeedback.mediumImpact());
      transcriptText.value = '';
      isLocked.value = false;
      dragOffset.value = 0;
      unawaited(sttHandler.startListening());
    }

    void finishRecordingSession() {
      unawaited(HapticFeedback.lightImpact());
      recordingTimer.value?.cancel();
      final finalDuration = durationSeconds.value > 0 ? durationSeconds.value : 1;
      final finalTranscript = transcriptText.value.trim();

      unawaited(sttHandler.stopListening());
      isRecording.value = false;
      isLocked.value = false;

      onRecordingComplete(
        audioUrl: 'audio/voice_note.wav',
        durationSeconds: finalDuration,
        transcript: finalTranscript,
      );
    }

    void cancelRecordingSession() {
      unawaited(HapticFeedback.lightImpact());
      recordingTimer.value?.cancel();
      unawaited(sttHandler.cancel());
      isRecording.value = false;
      isLocked.value = false;
      transcriptText.value = '';
      durationSeconds.value = 0;
      onCancel();
    }

    // Hands-Free Locked Mode View
    if (isLocked.value || (isRecording.value && isLocked.value)) {
      return AnimatedContainer(
        duration: AppMotion.snappy,
        curve: AppMotion.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colors.primary.withAlpha(isDark ? 35 : 18),
          borderRadius: AppRadius.radiusPanel,
          border: Border.all(
            color: colors.primary.withAlpha(isDark ? 80 : 45),
            width: 1.2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: [Rec Dot + Timer] [Locked Badge] ... [Trash] [Done Button]
            Row(
              children: [
                // Red pulsing rec dot
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.error,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDuration(durationSeconds.value),
                  style: typography.body.bold.copyWith(
                    color: colors.textPrimary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: colors.primary.withAlpha(isDark ? 50 : 30),
                    borderRadius: AppRadius.radiusMicro,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_rounded, size: 11, color: colors.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Locked',
                        style: typography.caption.bold.copyWith(
                          color: colors.primary,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),

                // Cancel / Trash Button
                ShrinkableButton(
                  onTap: cancelRecordingSession,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.error.withAlpha(isDark ? 40 : 25),
                    ),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: colors.error,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Done Button
                ShrinkableButton(
                  onTap: finishRecordingSession,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: AppRadius.radiusBadge,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_rounded, size: 16, color: colors.white),
                        const SizedBox(width: 4),
                        Text(
                          'Done',
                          style: typography.caption.bold.copyWith(
                            color: colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Live Speech-to-Text Transcript Preview if available
            if (transcriptText.value.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? colors.surfacePrimary.withAlpha(160)
                      : colors.surfaceSecondary.withAlpha(140),
                  borderRadius: AppRadius.radiusBadge,
                  border: Border.all(
                    color: colors.surfaceBorder.withAlpha(isDark ? 40 : 25),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.subtitles_rounded,
                      size: 14,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        transcriptText.value,
                        style: typography.caption.regular.copyWith(
                          color: colors.textPrimary,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }

    // Default / Active Hold-to-Record Button View
    return GestureDetector(
      onLongPressStart: (_) => startRecordingSession(),
      onLongPressMoveUpdate: (details) {
        final dy = details.localOffsetFromOrigin.dy;
        dragOffset.value = dy;
        if (dy < -40 && !isLocked.value) {
          isLocked.value = true;
          unawaited(HapticFeedback.mediumImpact());
        }
      },
      onLongPressEnd: (_) {
        if (!isLocked.value && isRecording.value) {
          finishRecordingSession();
        }
      },
      child: AnimatedContainer(
        duration: AppMotion.snappy,
        curve: AppMotion.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isRecording.value
              ? colors.primary.withAlpha(isDark ? 45 : 25)
              : colors.transparent,
          borderRadius: AppRadius.radiusBadge,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isRecording.value ? Icons.mic_rounded : Icons.mic_none_rounded,
              size: compact ? 18 : 20,
              color: isRecording.value ? colors.primary : colors.textSecondary,
            ),
            if (isRecording.value) ...[
              const SizedBox(width: 6),
              Text(
                _formatDuration(durationSeconds.value),
                style: typography.caption.bold.copyWith(
                  color: colors.primary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Drag up to lock 🔒',
                style: typography.caption.regular.copyWith(
                  color: colors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
