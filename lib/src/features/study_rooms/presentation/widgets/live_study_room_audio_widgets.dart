import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/study_rooms/presentation/bloc/live_room_cubit.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_sheet.dart';
import 'package:kortex/src/shared/widgets/app_avatar.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Glowing avatar widget indicating audio activity or active speaker state.
class GlowAvatar extends StatefulWidget {
  const GlowAvatar({
    required this.name,
    required this.size,
    required this.isGlowing,
    required this.isDark,
    super.key,
    this.glowColor,
  });

  final String name;
  final double size;
  final bool isGlowing;
  final bool isDark;
  final Color? glowColor;

  @override
  State<GlowAvatar> createState() => _GlowAvatarState();
}

class _GlowAvatarState extends State<GlowAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
      // ignore: discarded_futures — TickerFuture from repeat() is intentionally not awaited per Flutter convention
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.85, end: 1.05).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cColors = context.colors;
    final effectiveGlowColor = widget.glowColor ?? cColors.primary;

    if (!widget.isGlowing) {
      return AppAvatar(
        customDimension: widget.size,
        name: widget.name,
        backgroundColor: effectiveGlowColor.withAlpha(50),
        foregroundColor: effectiveGlowColor,
      );
    }

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        return Container(
          width: widget.size + 16,
          height: widget.size + 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: effectiveGlowColor.withValues(
                alpha: _pulse.value.clamp(0.2, 1),
              ),
              width: 2,
            ),
          ),
          child: child,
        );
      },
      child: AppAvatar(
        customDimension: widget.size,
        name: widget.name,
        backgroundColor: effectiveGlowColor.withAlpha(60),
        foregroundColor: effectiveGlowColor,
        borderColor: effectiveGlowColor.withAlpha(150),
      ),
    );
  }
}

/// Equalizer audio bars animation showing active voice transmission.
class InRoomEqualizerVisualizer extends StatefulWidget {
  const InRoomEqualizerVisualizer({required this.color, super.key});

  final Color color;

  @override
  State<InRoomEqualizerVisualizer> createState() =>
      _InRoomEqualizerVisualizerState();
}

class _InRoomEqualizerVisualizerState extends State<InRoomEqualizerVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      // ignore: discarded_futures — TickerFuture from repeat() is intentionally not awaited per Flutter convention
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final val = _controller.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildBar(3 + val * 7),
            const SizedBox(width: 2),
            _buildBar(10 - val * 6),
            const SizedBox(width: 2),
            _buildBar(5 + val * 5),
          ],
        );
      },
    );
  }

  Widget _buildBar(double height) {
    return Container(
      width: 2.5,
      height: height.clamp(3, 11),
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

/// Ambient soundscapes control bar and volume adjustment modal sheet.
class AmbientSoundscapeBar extends StatelessWidget {
  const AmbientSoundscapeBar({
    required this.state,
    required this.isDark,
    super.key,
  });

  final LiveRoomState state;
  final bool isDark;

  static const soundtracks = [
    {'name': 'Lo-Fi Beats', 'emoji': '🎧'},
    {'name': 'Gentle Rain', 'emoji': '🌧️'},
    {'name': 'Binaural 40Hz', 'emoji': '🧠'},
    {'name': 'Library Silence', 'emoji': '📚'},
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    final currentSound = state.ambientSoundTrack;
    final isPlaying = state.isAmbientAudioPlaying;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isDark
              ? colors.surfaceSecondary.withAlpha(150)
              : colors.surfacePrimary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPlaying
                ? colors.syllabotAccent.withAlpha(isDark ? 80 : 50)
                : colors.primary.withAlpha(isDark ? 30 : 15),
          ),
        ),
        child: Row(
          children: [
            // Play / Pause toggle
            ShrinkableButton(
              onTap: () {
                unawaited(HapticFeedback.lightImpact());
                context.read<LiveRoomCubit>().toggleAmbientAudio();
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (isPlaying ? colors.syllabotAccent : colors.primary)
                      .withAlpha(isDark ? 50 : 30),
                ),
                child: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 16,
                  color: isPlaying ? colors.syllabotAccent : colors.primary,
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Soundscape Track Selector
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: soundtracks.map((track) {
                    final isSelected = currentSound == track['name'];
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ShrinkableButton(
                        onTap: () {
                          unawaited(HapticFeedback.lightImpact());
                          context.read<LiveRoomCubit>().setAmbientSoundTrack(
                            track['name']!,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isPlaying
                                      ? colors.syllabotAccent
                                      : colors.primary)
                                : colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? colors.transparent
                                  : colors.primary.withAlpha(isDark ? 30 : 20),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                track['emoji']!,
                                style: context.typography.body.regular.copyWith(
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                track['name']!,
                                style: typography.caption.bold.copyWith(
                                  fontSize: 10.5,
                                  color: isSelected
                                      ? colors.white
                                      : colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // Volume Button triggering interactive modal
            ShrinkableButton(
              onTap: () {
                unawaited(HapticFeedback.lightImpact());
                _showVolumeModal(context);
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (state.ambientAudioVolume > 0 && isPlaying)
                      ? colors.syllabotAccent.withAlpha(isDark ? 50 : 30)
                      : colors.primary.withAlpha(isDark ? 30 : 15),
                ),
                child: Icon(
                  state.ambientAudioVolume > 0.5
                      ? Icons.volume_up_rounded
                      : (state.ambientAudioVolume > 0
                            ? Icons.volume_down_rounded
                            : Icons.volume_mute_rounded),
                  size: 16,
                  color: isPlaying
                      ? colors.syllabotAccent
                      : colors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showVolumeModal(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final cubit = context.read<LiveRoomCubit>();

    unawaited(
      AppAdaptiveSheet.showModal<void>(
        context: context,
        builder: (ctx) {
          final isDesktop = AppAdaptiveSheet.isDesktopOrWeb(ctx);
          return BlocProvider.value(
            value: cubit,
            child: BlocBuilder<LiveRoomCubit, LiveRoomState>(
              builder: (context, roomState) {
                final volumePercent = (roomState.ambientAudioVolume * 100)
                    .round();
                return Align(
                  alignment: isDesktop ? Alignment.center : Alignment.bottomCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 540),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 20,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? colors.surfaceSecondary
                            : colors.surfacePrimary,
                        borderRadius: isDesktop
                            ? BorderRadius.circular(AppRadius.dialog)
                            : const BorderRadius.vertical(
                                top: Radius.circular(24),
                              ),
                        border: Border.all(
                          color: colors.primary.withAlpha(isDark ? 50 : 25),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Ambient Soundscape Volume',
                                style: typography.title3.bold.copyWith(
                                  color: colors.textPrimary,
                                ),
                              ),
                              Text(
                                '$volumePercent%',
                                style: typography.caption.bold.copyWith(
                                  color: colors.primary,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Slider(
                            value: roomState.ambientAudioVolume,
                            onChanged: cubit.setAmbientVolume,
                            activeColor: colors.syllabotAccent,
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.primary,
                              foregroundColor: colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('Done'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
