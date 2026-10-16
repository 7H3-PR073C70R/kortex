import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/audio_recording_service.dart';
import 'package:kortex/src/core/utils/app_logger.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/presentation/widgets/voice_note_recorder/pulsing_mic_button.dart';
import 'package:kortex/src/features/community/presentation/widgets/voice_note_recorder/voice_note_recorder_controller.dart';
import 'package:kortex/src/features/community/presentation/widgets/voice_note_recorder/voice_recording_banner_widget.dart';

// Re-export sub-widgets and controller for seamless backward compatibility
export 'voice_note_recorder/audio_waveform_visualizer.dart';
export 'voice_note_recorder/pulsing_mic_button.dart';
export 'voice_note_recorder/voice_note_recorder_controller.dart';
export 'voice_note_recorder/voice_recording_banner_widget.dart';

/// Interactive Voice Note recorder widget supporting:
/// - Real microphone recording via [AudioRecordingService] into AAC/M4A audio files
/// - Single-tap to record (tap again stops & completes recording)
/// - Explicit "Done" button to complete when banner is active
/// - Trash / Cancel button to discard
/// - Live duration timer & live Speech-to-Text transcript preview
class VoiceNoteRecorderWidget extends HookWidget {
  const VoiceNoteRecorderWidget({
    required this.onRecordingComplete,
    required this.onCancel,
    this.audioRecordingService,
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
  final AudioRecordingService? audioRecordingService;
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

  static String formatDuration(int seconds) =>
      VoiceRecordingBannerWidget.formatDuration(seconds);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;

    final isRecording = useState<bool>(false);
    final durationSeconds = useState<int>(0);
    final transcriptText = useState<String>('');
    final recordingTimer = useRef<Timer?>(null);
    final isProcessing = useState<bool>(false);

    final recordingService = useMemoized(
      () => audioRecordingService ?? locator.get<AudioRecordingService>(),
      [audioRecordingService],
    );

    useEffect(() {
      return () {
        recordingTimer.value?.cancel();
      };
    }, const []);

    Future<void> startRecordingSession() async {
      if (isProcessing.value || isRecording.value) return;

      // Unfocus keyboard so the recording banner is clearly visible
      FocusManager.instance.primaryFocus?.unfocus();

      // 1. Instantly flip UI to recording on the very first tap — zero delay
      isRecording.value = true;
      isProcessing.value = true;
      durationSeconds.value = 0;
      transcriptText.value = '';

      unawaited(HapticFeedback.mediumImpact());

      // Immediately notify parent widget so banner appears on the exact frame of the tap
      onRecordingStateChanged?.call(
        isRecording: true,
        isLocked: false,
        durationSeconds: 0,
        transcript: '',
      );

      // Start duration timer immediately
      recordingTimer.value?.cancel();
      recordingTimer.value = Timer.periodic(
        const Duration(seconds: 1),
        (timer) {
          durationSeconds.value = timer.tick;
          onRecordingStateChanged?.call(
            isRecording: true,
            isLocked: false,
            durationSeconds: timer.tick,
            transcript: '',
          );
        },
      );

      try {
        final hasPerm = await recordingService.hasPermission();
        if (!hasPerm) {
          recordingTimer.value?.cancel();
          isRecording.value = false;
          onRecordingStateChanged?.call(
            isRecording: false,
            isLocked: false,
            durationSeconds: 0,
            transcript: '',
          );
          if (context.mounted) {
            context.showSnackBar(
              message: 'Microphone permission is required to record voice notes',
              type: SnackBarType.error,
            );
          }
          isProcessing.value = false;
          return;
        }

        await recordingService.startRecording();
      } on Object catch (e) {
        debugPrint('VoiceNoteRecorder: Failed to start audio recording: $e');
        recordingTimer.value?.cancel();
        isRecording.value = false;
        onRecordingStateChanged?.call(
          isRecording: false,
          isLocked: false,
          durationSeconds: 0,
          transcript: '',
        );
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
      // If startRecording is still starting up, wait briefly for it to complete
      var attempts = 0;
      while (isProcessing.value && attempts < 15) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        attempts++;
      }
      isProcessing.value = true;

      unawaited(HapticFeedback.lightImpact());
      recordingTimer.value?.cancel();
      final finalDuration = durationSeconds.value;

      isRecording.value = false;
      onRecordingStateChanged?.call(
        isRecording: false,
        isLocked: false,
        durationSeconds: finalDuration,
        transcript: '',
      );

      final recordedPath = await recordingService.stopRecording();

      if (recordedPath == null || (!kIsWeb && !File(recordedPath).existsSync())) {
        debugPrint('VoiceNoteRecorder: No audio captured or empty file');
        if (context.mounted) {
          context.showSnackBar(
            message: 'Voice note was too short or could not be recorded',
          );
        }
        onCancel();
        isProcessing.value = false;
        return;
      }

      onRecordingComplete(
        audioUrl: recordedPath,
        durationSeconds: finalDuration > 0 ? finalDuration : 1,
        transcript: '',
      );

      isProcessing.value = false;
    }

    Future<void> cancelRecordingSession() async {
      recordingTimer.value?.cancel();
      isRecording.value = false;
      transcriptText.value = '';
      durationSeconds.value = 0;

      onRecordingStateChanged?.call(
        isRecording: false,
        isLocked: false,
        durationSeconds: 0,
        transcript: '',
      );

      try {
        await recordingService.cancelRecording();
      } on Object catch (e, st) {
        AppLogger.recordNonFatal(e, st);
      }

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

    // Single-tap mic button: tap once to instantly show banner and record;
    // tap again to finish recording.
    final triggerButton = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (isRecording.value) {
          unawaited(finishRecordingSession());
        } else {
          unawaited(startRecordingSession());
        }
      },
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: isRecording.value
              ? PulsingMicButton(
                  compact: compact,
                  isDark: isDark,
                  errorColor: colors.error,
                )
              : Icon(
                  Icons.mic_rounded,
                  size: compact ? 19 : 21,
                  color: colors.textSecondary,
                ),
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
