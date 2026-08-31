import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/audio/bloc/audio_workspace_cubit.dart';
import 'package:kortex/src/shared/audio/bloc/audio_workspace_state.dart';

class TtsSpeechControlBar extends StatelessWidget {
  const TtsSpeechControlBar({
    required this.textToRead,
    super.key,
  });

  final String textToRead;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = context.l10n;

    return BlocBuilder<AudioWorkspaceCubit, AudioWorkspaceState>(
      builder: (context, state) {
        final isCurrentlySpeaking =
            state.isPlaying && state.currentlyReadingText == textToRead;

        return Semantics(
          container: true,
          label: 'Audio Narration Controls for text',
          child: Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isCurrentlySpeaking
                    ? theme.colorScheme.primary.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Play / Stop Button
                Semantics(
                  button: true,
                  label: isCurrentlySpeaking
                      ? l10n.stopAudioPlayback
                      : l10n.readAloudLabel,
                  child: InkWell(
                    onTap: () {
                      final cubit = context.read<AudioWorkspaceCubit>();
                      if (isCurrentlySpeaking) {
                        unawaited(cubit.stopPlayback());
                      } else {
                        unawaited(cubit.playText(textToRead));
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isCurrentlySpeaking
                                ? Icons.stop_circle_rounded
                                : Icons.volume_up_rounded,
                            size: 16,
                            color: isCurrentlySpeaking
                                ? Colors.redAccent
                                : theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isCurrentlySpeaking
                                ? 'Stop'
                                : l10n.readAloudLabel,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: isCurrentlySpeaking
                                  ? Colors.redAccent
                                  : Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),
                Container(
                  width: 1,
                  height: 14,
                  color: Colors.white24,
                ),
                const SizedBox(width: 8),

                // Speed Selector Menu
                _SpeedMenuButton(
                  currentSpeed: state.playbackSpeed,
                  onSpeedSelected: (speed) {
                    context
                        .read<AudioWorkspaceCubit>()
                        .setPlaybackSpeed(speed);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SpeedMenuButton extends StatelessWidget {
  const _SpeedMenuButton({
    required this.currentSpeed,
    required this.onSpeedSelected,
  });

  final double currentSpeed;
  final ValueChanged<double> onSpeedSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return PopupMenuButton<double>(
      onSelected: onSpeedSelected,
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.white12),
      ),
      child: Semantics(
        button: true,
        label: l10n.speechSpeedLabel(currentSpeed.toString()),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${currentSpeed}x',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                ),
              ),
              const Icon(
                Icons.arrow_drop_down_rounded,
                size: 16,
                color: Colors.white70,
              ),
            ],
          ),
        ),
      ),
      itemBuilder: (context) => [0.75, 1.0, 1.25, 1.5]
          .map(
            (s) => PopupMenuItem<double>(
              value: s,
              height: 36,
              child: Text(
                '${s}x',
                style: TextStyle(
                  color: s == currentSpeed ? Colors.cyanAccent : Colors.white,
                  fontWeight: s == currentSpeed
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
