import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Modes for [KortexLogoAssemblyWidget].
enum LogoAssemblyMode {
  /// Assembles once with an elastic neural snap, then transitions to an ambient breathing loop.
  splash,

  /// Continuously tear apart and assemble in a fluid, hypnotic loading loop.
  looping,
}

/// An immersive, high-performance vector animation widget that deconstructs
/// (tears apart) and reconstructs (forms together) the Kortex neural logo.
class KortexLogoAssemblyWidget extends StatefulWidget {
  const KortexLogoAssemblyWidget({
    super.key,
    this.size = 180,
    this.mode = LogoAssemblyMode.splash,
    this.onAssemblyComplete,
    this.showGlow = true,
  });

  /// The size (width & height) of the logo bounding box.
  final double size;

  /// Assembly animation mode (splash screen vs continuous loading spinner).
  final LogoAssemblyMode mode;

  /// Optional callback invoked when initial assembly sequence completes.
  final VoidCallback? onAssemblyComplete;

  /// Whether to render an ambient radial glow backdrop around the logo.
  final bool showGlow;

  @override
  State<KortexLogoAssemblyWidget> createState() =>
      _KortexLogoAssemblyWidgetState();
}

class _KortexLogoAssemblyWidgetState extends State<KortexLogoAssemblyWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: widget.mode == LogoAssemblyMode.splash ? 2200 : 2800,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    if (disableAnimations) {
      _controller
        ..stop()
        ..value = 1.0;
      widget.onAssemblyComplete?.call();
    } else if (!_controller.isAnimating && _controller.value == 0.0) {
      if (widget.mode == LogoAssemblyMode.splash) {
        unawaited(
          _controller.forward().then((_) {
            widget.onAssemblyComplete?.call();
            if (mounted &&
                !(MediaQuery.maybeDisableAnimationsOf(context) ?? false)) {
              unawaited(
                _controller.repeat(
                  reverse: true,
                  period: const Duration(milliseconds: 3200),
                ),
              );
            }
          }),
        );
      } else {
        unawaited(_controller.repeat());
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return Semantics(
      label: 'Kortex Neural Engine Assembly Animation',
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final progress = disableAnimations ? 1.0 : _controller.value;

            return CustomPaint(
              size: Size(widget.size, widget.size),
              painter: KortexLogoAssemblyPainter(
                progress: progress,
                mode: widget.mode,
                showGlow: widget.showGlow,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// CustomPainter that renders each vector component of the Kortex logo
/// with precise dynamic offsets, stroke paths, radial grid guidelines, and particle nodes.
class KortexLogoAssemblyPainter extends CustomPainter {
  KortexLogoAssemblyPainter({
    required this.progress,
    required this.mode,
    this.showGlow = true,
  });

  final double progress;
  final LogoAssemblyMode mode;
  final bool showGlow;

  // Brand Palette Constants matching kortex_logo.svg
  static const Color colorSage = Color(0xFF788C7E);
  static const Color colorTeal = Color(0xFF5B8C93);
  static const Color colorDeepGreen = Color(0xFF4A6B5D);
  static const Color colorOchre = Color(0xFFD4A373);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 512.0;
    final center = Offset(size.width / 2, size.height / 2);

    canvas..save()
    ..translate(center.dx, center.dy);

    // Calculate phase progress values based on mode
    double gridProgress;
    double stemProgress;
    double armsProgress;
    double shieldProgress;
    double nodesProgress;
    double deconstructOffset; // Disassembly displacement
    double glowAlpha;
    double sweepPhase;

    if (mode == LogoAssemblyMode.splash) {
      // 0.0 to 1.0 initial assembly sequence
      gridProgress = (progress / 0.35).clamp(0.0, 1.0);
      stemProgress = ((progress - 0.20) / 0.35).clamp(0.0, 1.0);
      armsProgress = ((progress - 0.30) / 0.40).clamp(0.0, 1.0);
      shieldProgress = ((progress - 0.45) / 0.45).clamp(0.0, 1.0);
      nodesProgress = ((progress - 0.60) / 0.40).clamp(0.0, 1.0);
      deconstructOffset = (1.0 - progress).clamp(0.0, 1.0);
      glowAlpha = progress.clamp(0.0, 1.0);
      sweepPhase = progress * 2 * math.pi;
    } else {
      // Continuous looping: 0.0 -> 0.60 assembly/lock, 0.60 -> 0.85 pulse, 0.85 -> 1.0 tear apart
      final cycle = progress;
      if (cycle < 0.60) {
        final t = cycle / 0.60;
        gridProgress = (t / 0.5).clamp(0.0, 1.0);
        stemProgress = ((t - 0.1) / 0.5).clamp(0.0, 1.0);
        armsProgress = ((t - 0.2) / 0.5).clamp(0.0, 1.0);
        shieldProgress = ((t - 0.3) / 0.5).clamp(0.0, 1.0);
        nodesProgress = ((t - 0.4) / 0.5).clamp(0.0, 1.0);
        deconstructOffset = (1.0 - t * 1.5).clamp(0.0, 1.0);
      } else if (cycle < 0.85) {
        // Assembled & glowing pulse
        gridProgress = 1.0;
        stemProgress = 1.0;
        armsProgress = 1.0;
        shieldProgress = 1.0;
        nodesProgress = 1.0;
        deconstructOffset = 0.0;
      } else {
        // Disassembling / tearing apart before restart
        final t = (cycle - 0.85) / 0.15;
        gridProgress = 1.0 - t;
        stemProgress = 1.0 - t;
        armsProgress = 1.0 - t;
        shieldProgress = 1.0 - t;
        nodesProgress = 1.0 - t;
        deconstructOffset = t;
      }
      glowAlpha = 0.6 + 0.4 * math.sin(progress * 2 * math.pi);
      sweepPhase = progress * 4 * math.pi;
    }

    // Easings
    final easeOutBack = Curves.easeOutBack.transform(gridProgress.clamp(0.0, 1.0));
    final easeOutCubic = Curves.easeOutCubic.transform(stemProgress.clamp(0.0, 1.0));
    final elasticArms = Curves.easeOutBack.transform(armsProgress.clamp(0.0, 1.0));
    final shieldEase = Curves.easeInOutCubic.transform(shieldProgress.clamp(0.0, 1.0));
    final nodeSpring = Curves.elasticOut.transform(nodesProgress.clamp(0.0, 1.0));

    // Gradient definition for paths
    const brandGradient = LinearGradient(
      begin: Alignment(-0.67, -0.78),
      end: Alignment(0.67, 0.78),
      colors: [colorSage, colorTeal, colorDeepGreen, colorOchre],
      stops: [0.0, 0.35, 0.70, 1.0],
    );

    final shaderRect = Rect.fromCircle(center: Offset.zero, radius: 220 * scale);
    final brandShader = brandGradient.createShader(shaderRect);

    // -------------------------------------------------------------------------
    // 0. Ambient Radial Aura Glow (Backdrop)
    // -------------------------------------------------------------------------
    if (showGlow && glowAlpha > 0.01) {
      final glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            colorTeal.withValues(alpha: 0.35 * glowAlpha),
            colorDeepGreen.withValues(alpha: 0.15 * glowAlpha),
            Colors.transparent,
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: 240 * scale));
      canvas.drawCircle(Offset.zero, 200 * scale, glowPaint);
    }

    // -------------------------------------------------------------------------
    // 1. Crisp 1px Isometric Wireframe Guidelines
    // -------------------------------------------------------------------------
    if (gridProgress > 0.01) {
      final gridPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorSage.withValues(alpha: 0.18 * gridProgress),
            colorOchre.withValues(alpha: 0.18 * gridProgress),
          ],
        ).createShader(shaderRect)
        ..strokeWidth = 1.2 * scale
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      // Outer 6 vertices in relative coordinates (centered at 256, 256)
      // Original SVG coords:
      // V0: (256, 56) -> (0, -200)
      // V1: (429.2, 156) -> (173.2, -100)
      // V2: (429.2, 356) -> (173.2, 100)
      // V3: (256, 456) -> (0, 200)
      // V4: (82.8, 356) -> (-173.2, 100)
      // V5: (82.8, 156) -> (-173.2, -100)
      final vertices = [
        Offset(0, -200 * scale),
        Offset(173.2 * scale, -100 * scale),
        Offset(173.2 * scale, 100 * scale),
        Offset(0, 200 * scale),
        Offset(-173.2 * scale, 100 * scale),
        Offset(-173.2 * scale, -100 * scale),
      ];

      // Radial Axes from Center -> Vertices
      for (final v in vertices) {
        final currentEnd = Offset.lerp(Offset.zero, v, easeOutBack)!;
        canvas.drawLine(Offset.zero, currentEnd, gridPaint);
      }

      // Inner Hexagon Mesh (Radius = 100)
      if (gridProgress > 0.4) {
        final meshProgress = ((gridProgress - 0.4) / 0.6).clamp(0.0, 1.0);
        final meshPath = Path();
        final meshVerts = [
          Offset(0, -100 * scale),
          Offset(86.6 * scale, -50 * scale),
          Offset(86.6 * scale, 50 * scale),
          Offset(0, 100 * scale),
          Offset(-86.6 * scale, 50 * scale),
          Offset(-86.6 * scale, -50 * scale),
        ];

        meshPath.moveTo(meshVerts[0].dx, meshVerts[0].dy);
        for (var i = 1; i < meshVerts.length; i++) {
          meshPath.lineTo(meshVerts[i].dx, meshVerts[i].dy);
        }
        meshPath.close();

        final animatedMeshPaint = Paint()
          ..strokeWidth = 1.0 * scale
          ..style = PaintingStyle.stroke
          ..color = colorTeal.withValues(alpha: 0.22 * meshProgress);

        canvas.drawPath(meshPath, animatedMeshPaint);
      }

      // Cross-Isometric Guideline Chords
      if (gridProgress > 0.6) {
        final chordAlpha = ((gridProgress - 0.6) / 0.4).clamp(0.0, 1.0) * 0.15;
        final chordPaint = Paint()
          ..strokeWidth = 1.0 * scale
          ..style = PaintingStyle.stroke
          ..color = colorSage.withValues(alpha: chordAlpha);

        // Horizontal Chords
        canvas..drawLine(
          Offset(-173.2 * scale, -100 * scale),
          Offset(173.2 * scale, -100 * scale),
          chordPaint,
        )
        ..drawLine(
          Offset(-173.2 * scale, 100 * scale),
          Offset(173.2 * scale, 100 * scale),
          chordPaint,
        )
        // Vertical Chords
        ..drawLine(
          Offset(-86.6 * scale, -50 * scale),
          Offset(-86.6 * scale, 50 * scale),
          chordPaint,
        )
        ..drawLine(
          Offset(86.6 * scale, -50 * scale),
          Offset(86.6 * scale, 50 * scale),
          chordPaint,
        );
      }
    }

    // -------------------------------------------------------------------------
    // 2. Symmetrical Outer Hexagon Shield Frame
    // -------------------------------------------------------------------------
    if (shieldProgress > 0.01) {
      final vertices = [
        Offset(0, -200 * scale),
        Offset(173.2 * scale, -100 * scale),
        Offset(173.2 * scale, 100 * scale),
        Offset(0, 200 * scale),
        Offset(-173.2 * scale, 100 * scale),
        Offset(-173.2 * scale, -100 * scale),
      ];

      final shieldPath = Path()
      ..moveTo(vertices[0].dx, vertices[0].dy);
      for (var i = 1; i < vertices.length; i++) {
        // Apply torn apart / exploded offset during disassembly
        final angle = (i * 60 - 90) * math.pi / 180;
        final explodeVec = Offset(
          math.cos(angle) * 35 * scale * deconstructOffset,
          math.sin(angle) * 35 * scale * deconstructOffset,
        );
        final targetPt = vertices[i] + explodeVec;
        final lerpPt = Offset.lerp(vertices[i - 1], targetPt, shieldEase)!;
        shieldPath.lineTo(lerpPt.dx, lerpPt.dy);
      }
      if (shieldEase >= 0.99) {
        shieldPath.close();
      }

      final shieldPaint = Paint()
        ..shader = brandShader
        ..strokeWidth = 14 * scale
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      canvas.drawPath(shieldPath, shieldPaint);
    }

    // -------------------------------------------------------------------------
    // 3. Stylized Neural "K" Network Mark
    // -------------------------------------------------------------------------
    if (stemProgress > 0.01 || armsProgress > 0.01) {
      final kPaint = Paint()
        ..shader = brandShader
        ..strokeWidth = 16 * scale
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      // --- "K" Vertical Left Stem ---
      // Original SVG coords: (156, 140) to (156, 372)
      // Relative coords: (-100, -116) to (-100, +116)
      final stemStartTarget = Offset(-100 * scale, -116 * scale);
      final stemEndTarget = Offset(-100 * scale, 116 * scale);

      // Disassembly displacement: slides in from left (-180, 0)
      final stemOffset = Offset(-80 * scale * (1.0 - easeOutCubic), 0);
      final animatedStemStart = stemStartTarget + stemOffset;
      final animatedStemEnd = stemEndTarget + stemOffset;

      if (stemProgress > 0.01) {
        final currentStemEnd = Offset.lerp(
          animatedStemStart,
          animatedStemEnd,
          easeOutCubic,
        )!;
        canvas.drawLine(animatedStemStart, currentStemEnd, kPaint);
      }

      // --- "K" Horizontal Connector to Nucleus ---
      // Original SVG coords: (156, 256) to (256, 256)
      // Relative coords: (-100, 0) to (0, 0)
      final horizStart = Offset(-100 * scale, 0) + stemOffset;
      const horizEnd = Offset.zero;
      if (stemProgress > 0.3) {
        final horizProgress = ((stemProgress - 0.3) / 0.7).clamp(0.0, 1.0);
        final currentHorizEnd = Offset.lerp(
          horizStart,
          horizEnd,
          Curves.easeOut.transform(horizProgress),
        )!;
        canvas.drawLine(horizStart, currentHorizEnd, kPaint);
      }

      // --- "K" Upper Diagonal Arm ---
      // Original SVG coords: (256, 256) to (356, 140)
      // Relative coords: (0, 0) to (100, -116)
      final upperArmTarget = Offset(100 * scale, -116 * scale);
      final upperExplode = Offset(40 * scale * deconstructOffset, -40 * scale * deconstructOffset);
      if (armsProgress > 0.01) {
        final currentUpperEnd = Offset.lerp(
          Offset.zero,
          upperArmTarget + upperExplode,
          elasticArms,
        )!;
        canvas.drawLine(Offset.zero, currentUpperEnd, kPaint);
      }

      // --- "K" Lower Diagonal Arm ---
      // Original SVG coords: (256, 256) to (356, 372)
      // Relative coords: (0, 0) to (100, 116)
      final lowerArmTarget = Offset(100 * scale, 116 * scale);
      final lowerExplode = Offset(40 * scale * deconstructOffset, 40 * scale * deconstructOffset);
      if (armsProgress > 0.01) {
        final currentLowerEnd = Offset.lerp(
          Offset.zero,
          lowerArmTarget + lowerExplode,
          elasticArms,
        )!;
        canvas.drawLine(Offset.zero, currentLowerEnd, kPaint);
      }
    }

    // -------------------------------------------------------------------------
    // 4. Standardized Uniform Outer Hexagon Nodes
    // -------------------------------------------------------------------------
    if (nodesProgress > 0.01 || shieldProgress > 0.8) {
      final outerNodes = [
        (Offset(0, -200 * scale), colorSage),
        (Offset(173.2 * scale, -100 * scale), colorTeal),
        (Offset(173.2 * scale, 100 * scale), colorDeepGreen),
        (Offset(0, 200 * scale), colorOchre),
        (Offset(-173.2 * scale, 100 * scale), colorDeepGreen),
        (Offset(-173.2 * scale, -100 * scale), colorSage),
      ];

      for (var i = 0; i < outerNodes.length; i++) {
        final pt = outerNodes[i].$1;
        final color = outerNodes[i].$2;
        final nodeScale = (nodeSpring * (1.0 - deconstructOffset * 0.4)).clamp(0.0, 1.4);
        final r = 10 * scale * nodeScale;

        if (r > 0.1) {
          final nodePaint = Paint()
            ..color = color
            ..style = PaintingStyle.fill;
          canvas.drawCircle(pt, r, nodePaint);

          // Energy aura ring around nodes
          if (mode == LogoAssemblyMode.looping && nodeSpring >= 0.9) {
            final auraR = r + 4 * scale * (1.0 + math.sin(sweepPhase + i));
            final auraPaint = Paint()
              ..color = color.withValues(alpha: 0.35)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5 * scale;
            canvas.drawCircle(pt, auraR, auraPaint);
          }
        }
      }
    }

    // -------------------------------------------------------------------------
    // 5. Standardized Uniform "K" Terminal Nodes
    // -------------------------------------------------------------------------
    if (nodesProgress > 0.1) {
      final kNodes = [
        (Offset(-100 * scale, -116 * scale), colorSage),
        (Offset(-100 * scale, 116 * scale), colorDeepGreen),
        (Offset(100 * scale, -116 * scale), colorTeal),
        (Offset(100 * scale, 116 * scale), colorOchre),
      ];

      for (final n in kNodes) {
        final pt = n.$1;
        final color = n.$2;
        final r = 13 * scale * nodeSpring.clamp(0.0, 1.2);

        if (r > 0.1) {
          final nodePaint = Paint()
            ..color = color
            ..style = PaintingStyle.fill;
          canvas.drawCircle(pt, r, nodePaint);
        }
      }
    }

    // -------------------------------------------------------------------------
    // 6. Refined 2D Vector Central Core (Nucleus)
    // -------------------------------------------------------------------------
    final coreScale = (gridProgress * (1.0 + 0.08 * math.sin(sweepPhase))).clamp(0.0, 1.3);
    if (coreScale > 0.01) {
      // Outer ring (Radius 42, stroke 2)
      final coreOuterPaint = Paint()
        ..shader = brandShader
        ..strokeWidth = 2.0 * scale
        ..style = PaintingStyle.stroke
        ..color = colorSage.withValues(alpha: 0.35 * gridProgress);
      canvas.drawCircle(Offset.zero, 42 * scale * coreScale, coreOuterPaint);

      // Inner radial core circle (Radius 30)
      final coreRadialShader = const RadialGradient(
        colors: [colorSage, colorTeal, colorDeepGreen],
        stops: [0.0, 0.60, 1.0],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: 34 * scale * coreScale));

      final coreInnerPaint = Paint()
        ..shader = coreRadialShader
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset.zero, 30 * scale * coreScale, coreInnerPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant KortexLogoAssemblyPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.mode != mode ||
        oldDelegate.showGlow != showGlow;
  }
}
