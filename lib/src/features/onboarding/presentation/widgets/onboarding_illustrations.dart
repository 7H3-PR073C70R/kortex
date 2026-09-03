import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/gen/assets.gen.dart';

/// Modular live SVG illustration builders with real-time ambient
/// laser scanlines, neural particle flow, and glowing physics overlays.
class OnboardingIllustrations {
  const OnboardingIllustrations._();

  /// Slide 1: Live Document Ingestion & Neural Synthesis.
  static Widget documentIngestion({
    BuildContext? context,
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
  }) {
    return _LiveIngestionScene(
      width: width,
      height: height,
      fit: fit,
    );
  }

  /// Slide 2: Live Optical STEM & LaTeX OCR with laser scanning sweep.
  static Widget stemOcr({
    BuildContext? context,
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
  }) {
    return _LiveOcrScene(
      width: width,
      height: height,
      fit: fit,
    );
  }

  /// Slide 3: Live Spaced Repetition (SM-2) memory retention tracker.
  static Widget spacedRepetition({
    BuildContext? context,
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
  }) {
    return _LiveRetentionScene(
      width: width,
      height: height,
      fit: fit,
    );
  }

  /// Slide 4: Live Socratic AI dialogue & Exam confidence calibration.
  static Widget socraticAi({
    BuildContext? context,
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
  }) {
    return _LiveSocraticScene(
      width: width,
      height: height,
      fit: fit,
    );
  }
}

// =========================================================================
// 1. LIVE INGESTION SCENE (Laser sweep + Synapse particle stream)
// =========================================================================
class _LiveIngestionScene extends StatefulWidget {
  const _LiveIngestionScene({
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  State<_LiveIngestionScene> createState() => _LiveIngestionSceneState();
}

class _LiveIngestionSceneState extends State<_LiveIngestionScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );
    unawaited(_controller.repeat());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return Stack(
      alignment: Alignment.center,
      children: [
        AppAssets.svgs.onboardingIngestion.svg(
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
        ),
        if (!disableAnimations)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  painter: _IngestionLivePainter(
                    progress: _controller.value,
                    primaryColor: colors.primary,
                    accentColor: colors.syllabotAccent,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _IngestionLivePainter extends CustomPainter {
  _IngestionLivePainter({
    required this.progress,
    required this.primaryColor,
    required this.accentColor,
  });

  final double progress;
  final Color primaryColor;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Laser scanning beam over left syllabus card
    final scanY = (h * 0.28) + (math.sin(progress * 2 * math.pi) * (h * 0.16));
    final scanPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          accentColor.withAlpha(200),
          Colors.white.withAlpha(240),
          accentColor.withAlpha(200),
          Colors.transparent,
        ],
        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
      ).createShader(Rect.fromLTWH(w * 0.08, scanY - 3, w * 0.32, 6))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.08, scanY - 1.5, w * 0.32, 3),
        const Radius.circular(2),
      ),
      scanPaint,
    );

    // 2. Glowing pulse aura around center cortex core
    final corePulse = math.sin(progress * 2 * math.pi) * 0.5 + 0.5;
    final coreGlowPaint = Paint()
      ..color = primaryColor.withAlpha((corePulse * 70).toInt().clamp(0, 255))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(
      Offset(w * 0.49, h * 0.49),
      16 + (corePulse * 6),
      coreGlowPaint,
    );

    // 3. Floating particle stream traveling from core to right flashcard
    final particle1T = (progress * 1.5) % 1.0;
    final p1X = (w * 0.55) + (particle1T * (w * 0.22));
    final p1Y = (h * 0.48) - (math.sin(particle1T * math.pi) * (h * 0.18));
    final particlePaint = Paint()
      ..color = Colors.cyanAccent.withAlpha(((1.0 - particle1T) * 220).toInt())
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(Offset(p1X, p1Y), 3.5, particlePaint);

    final particle2T = ((progress + 0.5) * 1.5) % 1.0;
    final p2X = (w * 0.55) + (particle2T * (w * 0.22));
    final p2Y = (h * 0.52) + (math.sin(particle2T * math.pi) * (h * 0.18));
    final particle2Paint = Paint()
      ..color = Colors.purpleAccent.withAlpha(
        ((1.0 - particle2T) * 220).toInt(),
      )
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(Offset(p2X, p2Y), 3.5, particle2Paint);
  }

  @override
  bool shouldRepaint(covariant _IngestionLivePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// =========================================================================
// 2. LIVE STEM OCR SCENE (Laser sweep + Reticle pulse)
// =========================================================================
class _LiveOcrScene extends StatefulWidget {
  const _LiveOcrScene({
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  State<_LiveOcrScene> createState() => _LiveOcrSceneState();
}

class _LiveOcrSceneState extends State<_LiveOcrScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
    unawaited(_controller.repeat());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return Stack(
      alignment: Alignment.center,
      children: [
        AppAssets.svgs.onboardingOcr.svg(
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
        ),
        if (!disableAnimations)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  painter: _OcrLivePainter(
                    progress: _controller.value,
                    primaryColor: colors.primary,
                    accentColor: colors.syllabotAccent,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _OcrLivePainter extends CustomPainter {
  _OcrLivePainter({
    required this.progress,
    required this.primaryColor,
    required this.accentColor,
  });

  final double progress;
  final Color primaryColor;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Full vertical scanner sweep
    final sweepY = (h * 0.18) + (progress * (h * 0.62));
    final beamHeight = h * 0.08;

    final beamPaint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              accentColor.withAlpha(90),
              Colors.white.withAlpha(220),
            ],
            stops: const [0.0, 0.7, 1.0],
          ).createShader(
            Rect.fromLTWH(w * 0.1, sweepY - beamHeight, w * 0.8, beamHeight),
          );

    canvas.drawRect(
      Rect.fromLTWH(w * 0.1, sweepY - beamHeight, w * 0.8, beamHeight),
      beamPaint,
    );

    final linePaint = Paint()
      ..color = Colors.cyanAccent
      ..strokeWidth = 2.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawLine(
      Offset(w * 0.1, sweepY),
      Offset(w * 0.9, sweepY),
      linePaint,
    );

    // Accuracy Radar Ping
    final pingPulse = math.sin(progress * 2 * math.pi) * 0.5 + 0.5;
    final radarPaint = Paint()
      ..color = Colors.greenAccent.withAlpha((pingPulse * 80).toInt())
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(
      Offset(w * 0.22, h * 0.75),
      8 + (pingPulse * 8),
      radarPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _OcrLivePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// =========================================================================
// 3. LIVE RETENTION SCENE (SM-2 Wave pulse & Milestone ripple)
// =========================================================================
class _LiveRetentionScene extends StatefulWidget {
  const _LiveRetentionScene({
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  State<_LiveRetentionScene> createState() => _LiveRetentionSceneState();
}

class _LiveRetentionSceneState extends State<_LiveRetentionScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    unawaited(_controller.repeat());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return Stack(
      alignment: Alignment.center,
      children: [
        AppAssets.svgs.onboardingRetention.svg(
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
        ),
        if (!disableAnimations)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  painter: _RetentionLivePainter(
                    progress: _controller.value,
                    primaryColor: colors.primary,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _RetentionLivePainter extends CustomPainter {
  _RetentionLivePainter({
    required this.progress,
    required this.primaryColor,
  });

  final double progress;
  final Color primaryColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Milestone 1 (Day 3) pulsing ripple
    final pulse1 = progress * 2 * math.pi;
    final r1 = 8.0 + (math.sin(pulse1) * 4.0);
    final ripple1Paint = Paint()
      ..color = Colors.greenAccent.withAlpha(
        (140 - (math.sin(pulse1) * 60)).toInt().clamp(0, 255),
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(Offset(w * 0.49, h * 0.38), r1, ripple1Paint);

    // Milestone 2 (Day 14) pulsing ripple
    final pulse2 = (progress + 0.5) * 2 * math.pi;
    final r2 = 8.0 + (math.sin(pulse2) * 4.0);
    final ripple2Paint = Paint()
      ..color = Colors.greenAccent.withAlpha(
        (140 - (math.sin(pulse2) * 60)).toInt().clamp(0, 255),
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(Offset(w * 0.84, h * 0.42), r2, ripple2Paint);

    // Retention curve energy spark traveling along trajectory
    final t = progress;
    final sparkX = (w * 0.49) + (t * (w * 0.35));
    final sparkY = (h * 0.38) + (math.sin(t * math.pi) * (h * 0.08));
    final sparkPaint = Paint()
      ..color = Colors.white
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(Offset(sparkX, sparkY), 3, sparkPaint);
  }

  @override
  bool shouldRepaint(covariant _RetentionLivePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// =========================================================================
// 4. LIVE SOCRATIC AI SCENE (Blinking dial aura + Dialogue spark)
// =========================================================================
class _LiveSocraticScene extends StatefulWidget {
  const _LiveSocraticScene({
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  State<_LiveSocraticScene> createState() => _LiveSocraticSceneState();
}

class _LiveSocraticSceneState extends State<_LiveSocraticScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    unawaited(_controller.repeat(reverse: true));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return Stack(
      alignment: Alignment.center,
      children: [
        AppAssets.svgs.onboardingSocratic.svg(
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
        ),
        if (!disableAnimations)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  painter: _SocraticLivePainter(
                    progress: _controller.value,
                    primaryColor: colors.primary,
                    accentColor: colors.syllabotAccent,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _SocraticLivePainter extends CustomPainter {
  _SocraticLivePainter({
    required this.progress,
    required this.primaryColor,
    required this.accentColor,
  });

  final double progress;
  final Color primaryColor;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // AI avatar glowing halo
    final haloGlow = (progress * 80).toInt().clamp(0, 255);
    final haloPaint = Paint()
      ..color = Colors.amberAccent.withAlpha(haloGlow)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(
      Offset(w * 0.12, h * 0.22),
      8 + (progress * 4),
      haloPaint,
    );

    // Mastery Dial live breathing arc glow
    final dialPulse = (progress * 100).toInt().clamp(0, 255);
    final dialPaint = Paint()
      ..color = accentColor.withAlpha(dialPulse)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(
      Offset(w * 0.76, h * 0.38),
      24 + (progress * 6),
      dialPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SocraticLivePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
