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
    final isStarting = useState<bool>(false);  // true only during the brief async startup gap
    final durationSeconds = useState<int>(0);
    final transcriptText = useState<String>('');
    final finalTranscriptText = useState<String>('');  // only updated on isFinal results
    final initialText = useRef<String>('');
    final recordingTimer = useRef<Timer?>(null);
    final isProcessing = useState<bool>(false);

    final recordingService = useMemoized(
      locator.get<AudioRecordingService>,
    );

    final sttHandler = useMemoized(
      () => SpeechToTextHandler(
        onResult: (words) {
          // Live intermediate preview only — do not save as authoritative transcript
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
              isLocked: false,
              durationSeconds: durationSeconds.value,
              transcript: words,
            );
          }
        },
        onResultWithFinal: (words, {required isFinal}) {
          // Accumulate final-only results as the authoritative transcript
          if (isFinal && words.trim().isNotEmpty) {
            final prev = finalTranscriptText.value.trim();
            finalTranscriptText.value =
                prev.isEmpty ? words.trim() : '$prev ${words.trim()}';
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
      unawaited(sttHandler.initialize());
      return () {
        recordingTimer.value?.cancel();
        sttHandler.dispose();
      };
    }, const []);

    Future<void> startRecordingSession() async {
      if (isProcessing.value || isRecording.value || isStarting.value) return;
      isProcessing.value = true;
      // Immediately show a "starting" state so the button reacts on first tap
      isStarting.value = true;

      try {
        final hasPerm = await recordingService.hasPermission();
        if (!hasPerm) {
          if (context.mounted) {
            context.showSnackBar(
              message: 'Microphone permission is required to record voice notes',
              type: SnackBarType.error,
            );
          }
          isStarting.value = false;
          isProcessing.value = false;
          return;
        }

        unawaited(HapticFeedback.mediumImpact());
        transcriptText.value = '';
        finalTranscriptText.value = '';
        initialText.value = controller?.text ?? '';

        await recordingService.startRecording();

        isStarting.value = false;
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
              isLocked: false,
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
      } on Object catch (e) {
        debugPrint('VoiceNoteRecorder: Failed to start audio recording: $e');
        isStarting.value = false;
        if (context.mounted) {
          context.showSnackBar(
            message: 'Failed to access microphone: $e',
            type: SnackBarType.error,
          );
        }
      } finally {
        isProcessing.value = false;
      }
    }

    Future<void> finishRecordingSession() async {
      if (isProcessing.value) return;
      isProcessing.value = true;

      unawaited(HapticFeedback.lightImpact());
      recordingTimer.value?.cancel();
      final finalDuration = durationSeconds.value;
      // Prefer accumulated final results; fall back to last live preview
      final finalTranscript = finalTranscriptText.value.trim().isNotEmpty
          ? finalTranscriptText.value.trim()
          : transcriptText.value.trim();

      unawaited(sttHandler.stopListening());
      isRecording.value = false;

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
      isProcessing.value = false;
    }

    Future<void> cancelRecordingSession() async {
      if (isProcessing.value) return;
      isProcessing.value = true;

      unawaited(HapticFeedback.lightImpact());
      recordingTimer.value?.cancel();
      unawaited(sttHandler.cancel());
      await recordingService.cancelRecording();

      if (controller != null) {
        controller!.text = initialText.value;
        controller!.selection =
            TextSelection.collapsed(offset: initialText.value.length);
      }

      isStarting.value = false;
      isRecording.value = false;
      transcriptText.value = '';
      finalTranscriptText.value = '';
      durationSeconds.value = 0;

      onRecordingStateChanged?.call(
        isRecording: false,
        isLocked: false,
        durationSeconds: 0,
        transcript: '',
      );

      onCancel();
      isProcessing.value = false;
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
          durationSeconds: durationSeconds.value,
          transcriptText: transcriptText.value,
          amplitudeStream: recordingService.amplitudeStream,
          onCancel: cancelRecordingSession,
          onDone: finishRecordingSession,
        ),
      );
    }

    // Single-Tap Mic Trigger Button (Instant Start / Finish)
    final isActive = isRecording.value || isStarting.value;
    final triggerButton = ShrinkableButton(
      onTap: () {
        if (isRecording.value) {
          unawaited(finishRecordingSession());
        } else if (!isStarting.value) {
          unawaited(startRecordingSession());
        }
      },
      child: AnimatedContainer(
        duration: AppMotion.snappy,
        curve: AppMotion.easeOutCubic,
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive
              ? colors.error.withAlpha(isDark ? 60 : 35)
              : colors.transparent,
          shape: BoxShape.circle,
          border: isActive
              ? Border.all(color: colors.error.withAlpha(180), width: 1.5)
              : null,
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: colors.error.withAlpha(120),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: isStarting.value
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(colors.error),
                ),
              )
            : Icon(
                isRecording.value ? Icons.stop_rounded : Icons.mic_rounded,
                size: compact ? 19 : 21,
                color:
                    isRecording.value ? colors.error : colors.textSecondary,
              ),
      ),
    );

    if (showBanner && bannerWidget != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          bannerWidget,
          Align(
            alignment: Alignment.centerLeft,
            child: triggerButton,
          ),
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
    required this.durationSeconds,
    required this.onCancel,
    required this.onDone,
    this.isLocked = false,
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

    final isTranscriptExpanded = useState<bool>(false);

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

              // Recording Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.error.withAlpha(isDark ? 55 : 30),
                  borderRadius: AppRadius.radiusBadge,
                ),
                child: Text(
                  'REC',
                  style: typography.caption.bold.copyWith(
                    color: colors.error,
                    fontSize: 10,
                    letterSpacing: 0.6,
                  ),
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
            ShrinkableButton(
              onTap: () {
                unawaited(HapticFeedback.lightImpact());
                isTranscriptExpanded.value = !isTranscriptExpanded.value;
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.subtitles_rounded,
                    size: 12,
                    color: colors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isTranscriptExpanded.value
                        ? 'Hide Live STT Preview 📝'
                        : 'Show Live STT Preview 📝',
                    style: typography.caption.bold.copyWith(
                      color: colors.textSecondary,
                      fontSize: 10.5,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    isTranscriptExpanded.value
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 14,
                    color: colors.textSecondary,
                  ),
                ],
              ),
            ),
            if (isTranscriptExpanded.value) ...[
              const SizedBox(height: 4),
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
