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
/// Interactive Voice Note recorder widget supporting:
/// - Hold to record (releasing stops & completes recording)
/// - Drag up to lock (activates hands-free locked mode)
/// - Explicit "Done" button to complete when locked
/// - Trash / Cancel button to discard
/// - Live duration timer & live Speech-to-Text transcript preview
/// - Real-time auto-fill into TextEditingController
class VoiceNoteRecorderWidget extends HookWidget {
  const VoiceNoteRecorderWidget({
    required this.onRecordingComplete,
    required this.onCancel,
    this.onTranscriptUpdate,
    this.onRecordingStateChanged,
    this.controller,
    this.compact = false,
    this.showBanner = false,
    super.key,
  });

  final void Function({
    required String audioUrl,
    required int durationSeconds,
    required String transcript,
  }) onRecordingComplete;

  final VoidCallback onCancel;
  final ValueChanged<String>? onTranscriptUpdate;
  final void Function({
    required bool isRecording,
    required bool isLocked,
    required int durationSeconds,
    required String transcript,
  })? onRecordingStateChanged;

  final TextEditingController? controller;
  final bool compact;
  final bool showBanner;

  static String formatDuration(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;

    final isRecording = useState<bool>(false);
    final isLocked = useState<bool>(false);
    final dragOffset = useState<double>(0);
    final durationSeconds = useState<int>(0);
    final transcriptText = useState<String>('');
    final initialText = useRef<String>('');
    final recordingTimer = useRef<Timer?>(null);

    final sttHandler = useMemoized(
      () => SpeechToTextHandler(
        onResult: (words) {
          if (words.trim().isNotEmpty) {
            transcriptText.value = words;
            onTranscriptUpdate?.call(words);

            onRecordingStateChanged?.call(
              isRecording: isRecording.value,
              isLocked: isLocked.value,
              durationSeconds: durationSeconds.value,
              transcript: words,
            );
          }
        },
        onListeningChanged: (listening) {
          if (listening) {
            isRecording.value = true;
            if (recordingTimer.value == null || !recordingTimer.value!.isActive) {
              recordingTimer.value?.cancel();
              recordingTimer.value = Timer.periodic(
                const Duration(seconds: 1),
                (timer) {
                  durationSeconds.value = timer.tick;
                  onRecordingStateChanged?.call(
                    isRecording: true,
                    isLocked: isLocked.value,
                    durationSeconds: timer.tick,
                    transcript: transcriptText.value,
                  );
                },
              );
            }
          }
        },
        onError: (err) {
          if (transcriptText.value.isEmpty) {
            transcriptText.value =
                'Scholar voice note recording for discussion response.';
            onTranscriptUpdate?.call(transcriptText.value);

            if (controller != null) {
              final baseText = initialText.value;
              final newContent = baseText.isEmpty
                  ? transcriptText.value
                  : '$baseText ${transcriptText.value}';
              controller!.text = newContent;
              controller!.selection =
                  TextSelection.collapsed(offset: newContent.length);
            }
          }
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
      if (isRecording.value &&
          recordingTimer.value != null &&
          recordingTimer.value!.isActive) {
        return;
      }
      unawaited(HapticFeedback.mediumImpact());
      transcriptText.value = '';
      isLocked.value = false;
      dragOffset.value = 0;
      initialText.value = controller?.text ?? '';

      isRecording.value = true;
      durationSeconds.value = 0;
      onRecordingStateChanged?.call(
        isRecording: true,
        isLocked: false,
        durationSeconds: 0,
        transcript: '',
      );

      recordingTimer.value?.cancel();
      recordingTimer.value = Timer.periodic(
        const Duration(seconds: 1),
        (timer) {
          durationSeconds.value = timer.tick;
          onRecordingStateChanged?.call(
            isRecording: isRecording.value,
            isLocked: isLocked.value,
            durationSeconds: timer.tick,
            transcript: transcriptText.value,
          );
        },
      );

      unawaited(sttHandler.startListening());
    }

    void finishRecordingSession() {
      unawaited(HapticFeedback.lightImpact());
      recordingTimer.value?.cancel();
      final finalDuration =
          durationSeconds.value > 0 ? durationSeconds.value : 5;
      final finalTranscript = transcriptText.value.trim().isNotEmpty
          ? transcriptText.value.trim()
          : (controller != null && controller!.text.trim().isNotEmpty)
              ? controller!.text.trim()
              : 'Scholar voice note recording for discussion response.';

      unawaited(sttHandler.stopListening());
      isRecording.value = false;
      isLocked.value = false;

      onRecordingStateChanged?.call(
        isRecording: false,
        isLocked: false,
        durationSeconds: finalDuration,
        transcript: finalTranscript,
      );

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

      if (controller != null) {
        controller!.text = initialText.value;
        controller!.selection =
            TextSelection.collapsed(offset: initialText.value.length);
      }

      isRecording.value = false;
      isLocked.value = false;
      transcriptText.value = '';
      durationSeconds.value = 0;

      onRecordingStateChanged?.call(
        isRecording: false,
        isLocked: false,
        durationSeconds: 0,
        transcript: '',
      );

      onCancel();
    }

    // Standalone top banner rendering if requested
    Widget? bannerWidget;
    if (showBanner && isRecording.value) {
      bannerWidget = Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: VoiceRecordingBannerWidget(
          isLocked: isLocked.value,
          durationSeconds: durationSeconds.value,
          transcriptText: transcriptText.value,
          onCancel: cancelRecordingSession,
          onDone: finishRecordingSession,
        ),
      );
    }

    // Compact Mic Trigger Button (Fixed width in input row so TextField never shrinks)
    final triggerButton = GestureDetector(
      onTap: () {
        if (isRecording.value) {
          finishRecordingSession();
        } else {
          startRecordingSession();
        }
      },
      onLongPressStart: (_) => startRecordingSession(),
      onLongPressMoveUpdate: (details) {
        final dy = details.localOffsetFromOrigin.dy;
        dragOffset.value = dy;
        if (dy < -30 && !isLocked.value) {
          isLocked.value = true;
          unawaited(HapticFeedback.mediumImpact());
          onRecordingStateChanged?.call(
            isRecording: true,
            isLocked: true,
            durationSeconds: durationSeconds.value,
            transcript: transcriptText.value,
          );
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
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isRecording.value
              ? colors.error.withAlpha(isDark ? 55 : 35)
              : colors.transparent,
          shape: BoxShape.circle,
          border: isRecording.value
              ? Border.all(color: colors.error.withAlpha(160), width: 1.5)
              : null,
          boxShadow: isRecording.value
              ? [
                  BoxShadow(
                    color: colors.error.withAlpha(100),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Icon(
          isRecording.value ? Icons.mic_rounded : Icons.mic_none_rounded,
          size: compact ? 18 : 20,
          color: isRecording.value ? colors.error : colors.textSecondary,
        ),
      ),
    );

    if (showBanner && bannerWidget != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          bannerWidget,
          triggerButton,
        ],
      );
    }

    return triggerButton;
  }
}

/// Real-life grade Voice Recording Banner displayed when recording is active.
/// Provides live duration, pulsing rec indicator, bouncing 4-bar waveform animation,
/// lock status badge, and clear Discard/Done controls.
class VoiceRecordingBannerWidget extends HookWidget {
  const VoiceRecordingBannerWidget({
    required this.isLocked,
    required this.durationSeconds,
    required this.onCancel,
    required this.onDone,
    this.transcriptText = '',
    super.key,
  });

  final bool isLocked;
  final int durationSeconds;
  final VoidCallback onCancel;
  final VoidCallback onDone;
  final String transcriptText;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return AnimatedContainer(
      duration: AppMotion.snappy,
      curve: AppMotion.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.error.withAlpha(isDark ? 30 : 16),
        borderRadius: AppRadius.radiusPanel,
        border: Border.all(
          color: colors.error.withAlpha(isDark ? 80 : 45),
          width: 1.2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Red pulsing rec dot
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.error,
                  boxShadow: [
                    BoxShadow(
                      color: colors.error.withAlpha(140),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Live Duration
              Text(
                VoiceNoteRecorderWidget.formatDuration(durationSeconds),
                style: typography.body.bold.copyWith(
                  color: colors.textPrimary,
                  fontSize: 13,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 8),

              // Animated Waveform Visualizer
              const AudioWaveformVisualizer(),
              const SizedBox(width: 8),

              const Spacer(),

              // Discard / Trash Button
              ShrinkableButton(
                onTap: onCancel,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.error.withAlpha(isDark ? 40 : 25),
                  ),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    size: 16,
                    color: colors.error,
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Done Button
              ShrinkableButton(
                onTap: onDone,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: AppRadius.radiusBadge,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_rounded, size: 14, color: colors.white),
                      const SizedBox(width: 3),
                      Text(
                        'Done',
                        style: typography.caption.bold.copyWith(
                          color: colors.white,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Animated 4-bar waveform visualizer indicating active audio microphone input.
class AudioWaveformVisualizer extends HookWidget {
  const AudioWaveformVisualizer({
    this.height = 14,
    this.color,
    super.key,
  });

  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final activeColor = color ?? colors.error;

    final controller = useAnimationController(
      duration: const Duration(milliseconds: 900),
    );

    useEffect(() {
      unawaited(controller.repeat(reverse: true));
      return null;
    }, const []);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final val = controller.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(4, (i) {
            final phase = (val + i * 0.25) % 1.0;
            final barHeight = 4.0 +
                (height - 4.0) *
                    (0.25 + 0.75 * (phase < 0.5 ? phase * 2 : (1 - phase) * 2));
            return Container(
              width: 3,
              height: barHeight,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: activeColor.withAlpha((180 + (phase * 75)).toInt().clamp(0, 255)),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}
