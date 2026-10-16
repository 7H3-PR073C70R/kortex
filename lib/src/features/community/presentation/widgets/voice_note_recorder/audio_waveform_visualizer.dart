import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';

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
