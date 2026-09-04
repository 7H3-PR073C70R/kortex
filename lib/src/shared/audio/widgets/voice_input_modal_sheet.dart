import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/audio/bloc/audio_workspace_cubit.dart';
import 'package:kortex/src/shared/audio/bloc/audio_workspace_state.dart';

class VoiceInputModalSheet extends StatefulWidget {
  const VoiceInputModalSheet({
    required this.onTranscribed,
    super.key,
  });

  final ValueChanged<String> onTranscribed;

  static Future<void> show(
    BuildContext context, {
    required ValueChanged<String> onTranscribed,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.transparent,
      builder: (ctx) => VoiceInputModalSheet(onTranscribed: onTranscribed),
    );
  }

  @override
  State<VoiceInputModalSheet> createState() => _VoiceInputModalSheetState();
}

class _VoiceInputModalSheetState extends State<VoiceInputModalSheet> {
  @override
  void initState() {
    super.initState();
    // Start listening on modal open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(context.read<AudioWorkspaceCubit>().startVoiceRecording());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;

    return BlocConsumer<AudioWorkspaceCubit, AudioWorkspaceState>(
      listener: (context, state) {
        if (state.recordingStatus == AudioRecordingStatus.transcribed &&
            state.transcribedText.isNotEmpty) {
          widget.onTranscribed(state.transcribedText);
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        }
      },
      builder: (context, state) {
        final soundLevel = state.liveSoundLevel;

        return Semantics(
          container: true,
          label: 'Voice-to-Text Input Modal Sheet: ${l10n.listeningVoiceInput}',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.95),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
              border: Border.all(
                color: colors.white.withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top drag handle
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.white.withAlpha(97),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),

                // Status Banner
                Text(
                  l10n.listeningVoiceInput,
                  textAlign: TextAlign.center,
                  style: typography.title3.bold.copyWith(
                    color: colors.white,
                  ),
                ),
                const SizedBox(height: 24),

                // Live Pulse Waveform Visualizer
                SizedBox(
                  height: 64,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      12,
                      (i) => _WaveBar(
                        index: i,
                        soundLevel: soundLevel,
                        accentColor: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Live Transcribed Text Box
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 60),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Text(
                    state.transcribedText.isEmpty
                        ? l10n.tapToSpeakHint
                        : state.transcribedText,
                    style: typography.body.regular.copyWith(
                      color: state.transcribedText.isEmpty
                          ? colors.white.withAlpha(97)
                          : colors.white,
                      fontStyle: state.transcribedText.isEmpty
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // Action Controls (Cancel & Finish)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Semantics(
                      button: true,
                      label: 'Cancel Voice Recording',
                      child: TextButton.icon(
                        onPressed: () {
                          unawaited(
                            context
                                .read<AudioWorkspaceCubit>()
                                .cancelVoiceRecording(),
                          );
                          Navigator.of(context).pop();
                        },
                        icon: Icon(
                          Icons.close_rounded,
                          color: colors.white.withAlpha(153),
                        ),
                        label: Text(
                          'Cancel',
                          style: typography.callout.regular.copyWith(
                            color: colors.white.withAlpha(153),
                          ),
                        ),
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: 'Submit Transcribed Speech',
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await context
                              .read<AudioWorkspaceCubit>()
                              .stopVoiceRecording();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.check_rounded),
                        label: Text(
                          'Done',
                          style: typography.callout.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WaveBar extends StatelessWidget {
  const _WaveBar({
    required this.index,
    required this.soundLevel,
    required this.accentColor,
  });

  final int index;
  final double soundLevel;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    // Stagger heights based on index and live amplitude
    final offset = (index % 3 + 1) * 0.3;
    final height = (soundLevel * 48.0 * offset).clamp(8.0, 56.0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 90),
      width: 5,
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: accentColor.withValues(
          alpha: (0.4 + (soundLevel * 0.6)).clamp(0.4, 1.0),
        ),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
