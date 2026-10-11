import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/features/study_rooms/presentation/bloc/live_room_cubit.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/live_study_room_audio_widgets.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Ambient soundscapes configuration section in the room drawer.
class DrawerAmbientAudioSection extends StatelessWidget {
  const DrawerAmbientAudioSection({
    required this.state,
    required this.colors,
    required this.typography,
    required this.isDark,
    super.key,
  });

  final LiveRoomState state;
  final AppThemeColorsExtension colors;
  final TypographyThemeExtension typography;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<LiveRoomCubit>();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceTertiary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colors.surfaceBorder.withAlpha(isDark ? 60 : 40),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                state.ambientSoundTrack,
                style: typography.caption.bold.copyWith(
                  color: colors.textPrimary,
                  fontSize: 12,
                ),
              ),
              ShrinkableButton(
                onTap: cubit.toggleAmbientAudio,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: state.isAmbientAudioPlaying
                        ? colors.syllabotAccent
                        : colors.primary.withAlpha(40),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    state.isAmbientAudioPlaying ? 'Playing' : 'Paused',
                    style: typography.caption.bold.copyWith(
                      color: colors.white,
                      fontSize: 10.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: AmbientSoundscapeBar.soundtracks.map((track) {
              final isSel = state.ambientSoundTrack == track['name'];
              return ShrinkableButton(
                onTap: () => cubit.setAmbientSoundTrack(track['name']!),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isSel
                        ? colors.syllabotAccent
                        : colors.surfacePrimary,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSel
                          ? colors.transparent
                          : colors.surfaceBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        track['emoji']!,
                        style: context.typography.body.regular.copyWith(fontSize: 11),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        track['name']!,
                        style: typography.caption.medium.copyWith(
                          fontSize: 10.5,
                          color: isSel
                              ? colors.white
                              : colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.volume_down_rounded,
                size: 14,
                color: colors.textSecondary,
              ),
              Expanded(
                child: Slider(
                  value: state.ambientAudioVolume,
                  onChanged: cubit.setAmbientVolume,
                  activeColor: colors.syllabotAccent,
                ),
              ),
              Icon(
                Icons.volume_up_rounded,
                size: 14,
                color: colors.textSecondary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Voice pod microphone controls and hand raising section in room drawer.
class DrawerVoicePodSection extends StatelessWidget {
  const DrawerVoicePodSection({
    required this.state,
    required this.colors,
    required this.typography,
    required this.isDark,
    required this.onVoicePodTapped,
    super.key,
  });

  final LiveRoomState state;
  final AppThemeColorsExtension colors;
  final TypographyThemeExtension typography;
  final bool isDark;
  final Future<void> Function() onVoicePodTapped;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<LiveRoomCubit>();

    return Row(
      children: [
        Expanded(
          child: ShrinkableButton(
            onTap: onVoicePodTapped,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: state.isVoicePodEnabled && !state.isMuted
                    ? colors.recallEasy.withAlpha(isDark ? 50 : 30)
                    : colors.surfaceTertiary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: state.isVoicePodEnabled && !state.isMuted
                      ? colors.recallEasy
                      : colors.surfaceBorder,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    !state.isVoicePodEnabled
                        ? Icons.mic_off_rounded
                        : (state.isMuted
                              ? Icons.mic_off_rounded
                              : Icons.mic_rounded),
                    size: 16,
                    color: state.isVoicePodEnabled && !state.isMuted
                        ? colors.recallEasy
                        : colors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    !state.isVoicePodEnabled
                        ? 'Join Voice'
                        : (state.isMuted ? 'Unmute' : 'Muted'),
                    style: typography.caption.bold.copyWith(
                      color: state.isVoicePodEnabled && !state.isMuted
                          ? colors.recallEasy
                          : colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ShrinkableButton(
            onTap: cubit.toggleHandRaise,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: state.isHandRaised
                    ? colors.warning.withAlpha(isDark ? 50 : 30)
                    : colors.surfaceTertiary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: state.isHandRaised
                      ? colors.warning
                      : colors.surfaceBorder,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.front_hand_rounded,
                    size: 16,
                    color: state.isHandRaised
                        ? colors.warning
                        : colors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    state.isHandRaised ? 'Hand Up' : 'Raise Hand',
                    style: typography.caption.bold.copyWith(
                      color: state.isHandRaised
                          ? colors.warning
                          : colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
