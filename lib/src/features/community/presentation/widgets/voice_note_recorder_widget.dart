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
    final durationSeconds = useState<int>(0);
    final transcriptText = useState<String>('');
    final recordingTimer = useRef<Timer?>(null);
    final isProcessing = useState<bool>(false);

    final recordingService = useMemoized(
      locator.get<AudioRecordingService>,
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

      if (recordedPath == null || !File(recordedPath).existsSync()) {
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

      // Transcription is intentionally omitted client-side.
      // A Supabase Edge Function (transcribe-voice-note) handles Groq Whisper
      // transcription server-side after the VN is uploaded, so transcripts are
      // only visible to viewers — never to the person who recorded the note.
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
      } on Object catch (_) {}

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
              ? _PulsingMicButton(
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

/// Continuously pulsing mic circle used as the "tap to stop" affordance
/// during an active recording session.
class _PulsingMicButton extends StatefulWidget {
  const _PulsingMicButton({
    required this.compact,
    required this.isDark,
    required this.errorColor,
  });

  final bool compact;
  final bool isDark;
  final Color errorColor;

  @override
  State<_PulsingMicButton> createState() => _PulsingMicButtonState();
}

class _PulsingMicButtonState extends State<_PulsingMicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _rippleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    unawaited(_controller.repeat());

    _scaleAnim = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 1, curve: Curves.easeInOut),
      ),
    );
    _rippleAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const size = 36.0;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final ripple = _rippleAnim.value;
        final scale = _scaleAnim.value;
        return SizedBox(
          width: size + 12,
          height: size + 12,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer ripple ring
              Opacity(
                opacity: ((1 - ripple) * 0.9).clamp(0.0, 1.0),
                child: Container(
                  width: size + ripple * 14,
                  height: size + ripple * 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.errorColor
                          .withAlpha(((1 - ripple) * 140).round()),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              // Core pulsing mic circle
              Transform.scale(
                scale: scale,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.errorColor
                        .withAlpha(widget.isDark ? 60 : 40),
                    border: Border.all(
                      color: widget.errorColor.withAlpha(200),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.errorColor.withAlpha(100),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.mic_rounded,
                    size: widget.compact ? 18 : 20,
                    color: widget.errorColor,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}



/// Real-life grade Voice Recording Banner displayed when recording is active.
/// Shows only the REC indicator, live timer, and waveform — the mic button
/// in the parent toolbar acts as the single stop control.
class VoiceRecordingBannerWidget extends HookWidget {
  const VoiceRecordingBannerWidget({
    required this.durationSeconds,
    this.isLocked = false,
    this.transcriptText = '',
    this.amplitudeStream,
    // Legacy cancel/done params kept for callers that still pass them;
    // they are no longer rendered inside the banner itself.
    this.onCancel,
    this.onDone,
    super.key,
  });

  final bool isLocked;
  final int durationSeconds;
  final VoidCallback? onCancel;
  final VoidCallback? onDone;
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

              // Animated Waveform Visualizer — takes remaining space
              Expanded(
                child: AudioWaveformVisualizer(
                  amplitudeStream: amplitudeStream,
                ),
              ),
              if (onCancel != null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    unawaited(HapticFeedback.lightImpact());
                    onCancel?.call();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.error.withAlpha(isDark ? 50 : 25),
                    ),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      size: 16,
                      color: colors.error,
                    ),
                  ),
                ),
              ],
              if (onDone != null) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    unawaited(HapticFeedback.mediumImpact());
                    onDone?.call();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.primary.withAlpha(isDark ? 70 : 40),
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: colors.primary,
                    ),
                  ),
                ),
              ],
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
