import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/voice_dialogue/dialogue_state.dart';

/// Siri / Gemini fluid multi-color acoustic sound ribbon visualizer.
class VoiceSoundRibbonWidget extends StatelessWidget {
  const VoiceSoundRibbonWidget({
    required this.stateColor,
    required this.state,
    required this.soundLevelNotifier,
    required this.animation,
    required this.height,
    super.key,
  });

  final Color stateColor;
  final DialogueState state;
  final ValueNotifier<double> soundLevelNotifier;
  final Animation<double> animation;
  final double height;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return ValueListenableBuilder<double>(
          valueListenable: soundLevelNotifier,
          builder: (context, soundLevel, _) {
            return CustomPaint(
              size: Size(double.infinity, height),
              painter: VoiceSoundRibbonPainter(
                stateColor: stateColor,
                state: state,
                soundLevel: soundLevel,
                animationValue: animation.value,
              ),
            );
          },
        );
      },
    );
  }
}

/// GPU-accelerated sinusoidal acoustic ribbon painter with Siri/Gemini harmonic layers.
class VoiceSoundRibbonPainter extends CustomPainter {
  VoiceSoundRibbonPainter({
    required this.stateColor,
    required this.state,
    required this.soundLevel,
    required this.animationValue,
  });

  final Color stateColor;
  final DialogueState state;
  final double soundLevel;
  final double animationValue;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final centerY = height / 2;

    // Amplitude scale based on dialogue state and decibels
    final isListening = state == DialogueState.listening;
    final isSpeaking = state == DialogueState.speaking;
    final isThinking = state == DialogueState.thinking;

    final baseAmp = isListening
        ? (8.0 + soundLevel * 36.0)
        : isSpeaking
        ? 24.0
        : isThinking
        ? 14.0
        : 6.0;

    // Siri / Gemini multi-harmonic wave definitions
    // Each wave has [freq, phase, amp, strokeWidth, colors, blur]
    final waveLayers = [
      // 1. Ambient Glow Underlayer (Wide soft blur)
      VoiceRibbonLayer(
        freq: 1,
        phase: animationValue * 2 * math.pi,
        amp: baseAmp * 1.1,
        strokeWidth: 6,
        colors: [
          stateColor.withValues(alpha: 0),
          const Color(0xFF00E5FF).withValues(alpha: 0.35),
          const Color(0xFF7C4DFF).withValues(alpha: 0.4),
          const Color(0xFFFF4081).withValues(alpha: 0.35),
          stateColor.withValues(alpha: 0),
        ],
        blur: 10,
      ),
      // 2. Cyan / Turquoise Wave (Crisp lead harmonic)
      VoiceRibbonLayer(
        freq: 1.4,
        phase: (animationValue * 2 * math.pi) + 0.8,
        amp: baseAmp * 0.95,
        strokeWidth: 3.2,
        colors: [
          stateColor.withValues(alpha: 0),
          const Color(0xFF00E5FF),
          const Color(0xFF18FFFF),
          const Color(0xFF00B0FF),
          stateColor.withValues(alpha: 0),
        ],
      ),
      // 3. Purple / Indigo Wave (Deep harmonic counterpoint)
      VoiceRibbonLayer(
        freq: 1.8,
        phase: (animationValue * 2 * math.pi) - 1.2,
        amp: baseAmp * 0.75,
        strokeWidth: 2.8,
        colors: [
          stateColor.withValues(alpha: 0),
          const Color(0xFF7C4DFF),
          const Color(0xFF651FFF),
          const Color(0xFFB388FF),
          stateColor.withValues(alpha: 0),
        ],
      ),
      // 4. Rose / Amber Wave (Warm harmonic shimmer)
      VoiceRibbonLayer(
        freq: 2.2,
        phase: (animationValue * 2 * math.pi) + 2.4,
        amp: baseAmp * 0.55,
        strokeWidth: 2.2,
        colors: [
          stateColor.withValues(alpha: 0),
          const Color(0xFFFF4081),
          const Color(0xFFFF80AB),
          const Color(0xFFFFAB40),
          stateColor.withValues(alpha: 0),
        ],
      ),
      // 5. White Hot Center Filament (Luminous core)
      VoiceRibbonLayer(
        freq: 1.2,
        phase: (animationValue * 2 * math.pi) + 0.4,
        amp: baseAmp * 0.85,
        strokeWidth: 1.6,
        colors: [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: 0.85),
          Colors.white,
          Colors.white.withValues(alpha: 0.85),
          Colors.white.withValues(alpha: 0),
        ],
      ),
    ];

    for (final layer in waveLayers) {
      final path = Path();
      const sampleStep = 4.0;
      var isFirst = true;

      for (var x = 0.0; x <= width; x += sampleStep) {
        final progress = (x / width).clamp(0, 1);
        // Hanning-style window tapering to zero smoothly at both ends
        final envelope = math.sin(progress * math.pi);
        final envelopePowered = math.pow(envelope, 1.3).toDouble();

        final waveOffset = math.sin(
          (progress * layer.freq * 2 * math.pi) + layer.phase,
        );
        final y = centerY + (waveOffset * layer.amp * envelopePowered);

        if (isFirst) {
          path.moveTo(x, y);
          isFirst = false;
        } else {
          path.lineTo(x, y);
        }
      }

      final shader = LinearGradient(
        colors: layer.colors,
        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
      ).createShader(Rect.fromLTWH(0, centerY - baseAmp, width, baseAmp * 2));

      final paint = Paint()
        ..shader = shader
        ..style = PaintingStyle.stroke
        ..strokeWidth = layer.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      if (layer.blur != null) {
        paint.maskFilter = MaskFilter.blur(BlurStyle.normal, layer.blur!);
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant VoiceSoundRibbonPainter oldDelegate) {
    return oldDelegate.soundLevel != soundLevel ||
        oldDelegate.state != state ||
        oldDelegate.stateColor != stateColor ||
        oldDelegate.animationValue != animationValue;
  }
}

class VoiceRibbonLayer {
  const VoiceRibbonLayer({
    required this.freq,
    required this.phase,
    required this.amp,
    required this.strokeWidth,
    required this.colors,
    this.blur,
  });

  final double freq;
  final double phase;
  final double amp;
  final double strokeWidth;
  final List<Color> colors;
  final double? blur;
}
