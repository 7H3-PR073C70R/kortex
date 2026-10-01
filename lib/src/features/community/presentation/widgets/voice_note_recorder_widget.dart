import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/audio_recording_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/speech_to_text_handler.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Controller to allow external widgets (such as pinned top recording banners)
/// to complete or cancel recording sessions synchronously with [VoiceNoteRecorderWidget].
class VoiceNoteRecorderController {
  Future<void> Function()? _finish;
  Future<void> Function()? _cancel;

  void attach({
    required Future<void> Function() onFinish,
    required Future<void> Function() onCancel,
  }) {
    _finish = onFinish;
    _cancel = onCancel;
  }

  void detach() {
    _finish = null;
    _cancel = null;
  }

  Future<void> finish() async => _finish?.call();
  Future<void> cancel() async => _cancel?.call();
}

/// Interactive Voice Note recorder widget supporting:
/// - Real microphone recording via [AudioRecordingService] into AAC/M4A audio files
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
    this.recorderController,
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
  final VoiceNoteRecorderController? recorderController;
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

    final recordingService = useMemoized(
      locator.get<AudioRecordingService>,
    );

    final sttHandler = useMemoized(
      () => SpeechToTextHandler(
        onResult: (words) {
          if (words.trim().isNotEmpty) {
            transcriptText.value = words;
            onTranscriptUpdate?.call(words);

            if (controller != null) {
              final base = initialText.value;
              final newContent = base.isEmpty ? words : '$base $words';
              controller!.text = newContent;
              controller!.selection =
                  TextSelection.collapsed(offset: newContent.length);
            }

            onRecordingStateChanged?.call(
              isRecording: isRecording.value,
              isLocked: isLocked.value,
              durationSeconds: durationSeconds.value,
              transcript: words,
            );
          }
        },
        onListeningChanged: (listening) {
          // Handled via AudioRecordingService lifecycle
        },
        onError: (err) {
          debugPrint('VoiceNoteRecorder: STT error: $err');
        },
      ),
    );

    useEffect(() {
      return () {
        recordingTimer.value?.cancel();
        sttHandler.dispose();
      };
    }, const []);

    Future<void> startRecordingSession() async {
      if (isRecording.value &&
          recordingTimer.value != null &&
          recordingTimer.value!.isActive) {
        return;
      }

      final hasPerm = await recordingService.hasPermission();
      if (!hasPerm) {
        if (context.mounted) {
          context.showSnackBar(
            message: 'Microphone permission is required to record voice notes',
            type: SnackBarType.error,
          );
        }
        return;
      }

      unawaited(HapticFeedback.mediumImpact());
      transcriptText.value = '';
      isLocked.value = false;
      dragOffset.value = 0;
      initialText.value = controller?.text ?? '';

      try {
        await recordingService.startRecording();
      } on Object catch (e) {
        debugPrint('VoiceNoteRecorder: Failed to start audio recording: $e');
        if (context.mounted) {
          context.showSnackBar(
            message: 'Failed to access microphone: $e',
            type: SnackBarType.error,
          );
        }
        return;
      }

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

      try {
        unawaited(sttHandler.startListening());
      } on Object catch (e) {
        debugPrint('VoiceNoteRecorder: STT start failed: $e');
      }
    }

    Future<void> finishRecordingSession() async {
      unawaited(HapticFeedback.lightImpact());
      recordingTimer.value?.cancel();
      final finalDuration = durationSeconds.value;
      final finalTranscript = transcriptText.value.trim();

      unawaited(sttHandler.stopListening());
      isRecording.value = false;
      isLocked.value = false;

      final recordedPath = await recordingService.stopRecording();

      onRecordingStateChanged?.call(
        isRecording: false,
        isLocked: false,
        durationSeconds: finalDuration,
        transcript: finalTranscript,
      );

      if (recordedPath != null && File(recordedPath).existsSync()) {
        onRecordingComplete(
          audioUrl: recordedPath,
          durationSeconds: finalDuration > 0 ? finalDuration : 1,
          transcript: finalTranscript,
        );
      } else {
        debugPrint('VoiceNoteRecorder: No audio captured or empty file');
        if (context.mounted) {
          context.showSnackBar(
            message: 'Voice note was too short or could not be recorded',
          );
        }
        onCancel();
      }
    }

    Future<void> cancelRecordingSession() async {
      unawaited(HapticFeedback.lightImpact());
      recordingTimer.value?.cancel();
      unawaited(sttHandler.cancel());
      await recordingService.cancelRecording();

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

    // Attach external controller if provided
    useEffect(() {
      recorderController?.attach(
        onFinish: finishRecordingSession,
        onCancel: cancelRecordingSession,
      );
      return () {
        recorderController?.detach();
      };
    }, [recorderController]);

    // Standalone top banner rendering if requested
    Widget? bannerWidget;
    if (showBanner && isRecording.value) {
      bannerWidget = Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: VoiceRecordingBannerWidget(
          isLocked: isLocked.value,
          durationSeconds: durationSeconds.value,
          transcriptText: transcriptText.value,
          amplitudeStream: recordingService.amplitudeStream,
          onCancel: cancelRecordingSession,
          onDone: finishRecordingSession,
        ),
      );
    }

    // Compact Mic Trigger Button
    final triggerButton = GestureDetector(
      onTap: () {
        if (isRecording.value) {
          unawaited(finishRecordingSession());
        } else {
          unawaited(startRecordingSession());
        }
      },
      onLongPressStart: (_) => unawaited(startRecordingSession()),
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
          unawaited(finishRecordingSession());
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
    this.amplitudeStream,
    super.key,
  });

  final bool isLocked;
  final int durationSeconds;
  final VoidCallback onCancel;
  final VoidCallback onDone;
  final String transcriptText;
  final Stream<double>? amplitudeStream;

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
              AudioWaveformVisualizer(
                amplitudeStream: amplitudeStream,
              ),
              const SizedBox(width: 8),

              // Lock Status Indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isLocked
                      ? colors.primary.withAlpha(isDark ? 50 : 30)
                      : colors.textSecondary.withAlpha(isDark ? 40 : 20),
                  borderRadius: AppRadius.radiusBadge,
                ),
                child: Text(
                  isLocked ? 'Locked 🔒' : 'Drag up to lock 🔒',
                  style: typography.caption.medium.copyWith(
                    color: isLocked ? colors.primary : colors.textSecondary,
                    fontSize: 10.5,
                  ),
                ),
              ),

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
          if (transcriptText.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              transcriptText.trim(),
              style: typography.caption.regular.copyWith(
                color: colors.textSecondary,
                fontSize: 11,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

/// Animated 4-bar waveform visualizer indicating active audio microphone input.
/// Reacts to real-time input amplitude when [amplitudeStream] is supplied.
class AudioWaveformVisualizer extends HookWidget {
  const AudioWaveformVisualizer({
    this.height = 14,
    this.color,
    this.amplitudeStream,
    super.key,
  });

  final double height;
  final Color? color;
  final Stream<double>? amplitudeStream;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final activeColor = color ?? colors.error;

    final controller = useAnimationController(
      duration: const Duration(milliseconds: 900),
    );

    final liveAmp = useStream(amplitudeStream, initialData: 0).data ?? 0;

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
            final baseFactor = 0.25 +
                0.75 * (phase < 0.5 ? phase * 2 : (1 - phase) * 2);
            // Blend idle subtle animation with live microphone volume
            final boost = (liveAmp * 1.5).clamp(0.0, 1.0);
            final combinedFactor = (baseFactor * (0.3 + 0.7 * boost)).clamp(0.15, 1.0);
            final barHeight = 4 + (height - 4) * combinedFactor;

            return Container(
              width: 3,
              height: barHeight,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: activeColor.withAlpha(
                  (180 + (phase * 75)).toInt().clamp(0, 255),
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}
