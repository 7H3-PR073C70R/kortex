import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Interactive Cosmic Knowledge Orb collected during flight
class _KnowledgeOrb {
  _KnowledgeOrb({
    required this.symbol,
    required this.label,
    required this.xRatio,
    required this.y,
    required this.color,
  });

  final String symbol;
  final String label;
  final double xRatio; // 0.0 to 1.0 of screen width
  final Color color;
  double y; // pixels from top
  bool isCollected = false;
}

/// Dynamic particle emitted by rocket thrusters or explosions
class _FlightParticle {
  _FlightParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.radius,
    required this.color,
    required this.maxLife,
  }) : life = maxLife;

  double x;
  double y;
  double vx;
  double vy;
  double radius;
  Color color;
  double life;
  final double maxLife;

  bool get isDead => life <= 0;
}

/// Floating score / popup text
class _FloatingScore {
  _FloatingScore({
    required this.text,
    required this.x,
    required this.y,
    required this.color,
  });

  final String text;
  final double x;
  final Color color;
  double y;
  double opacity = 1;
}

/// Interactive Rocket Launch Animation Overlay
/// Gives users an exhilarating, gamified space flight experience with
/// physics steering, turbo boosts, collectible knowledge orbs, and warp jump.
class InteractiveRocketLaunchOverlay extends StatefulWidget {
  const InteractiveRocketLaunchOverlay({
    required this.onLaunchComplete,
    super.key,
  });

  final VoidCallback onLaunchComplete;

  @override
  State<InteractiveRocketLaunchOverlay> createState() =>
      _InteractiveRocketLaunchOverlayState();
}

class _InteractiveRocketLaunchOverlayState
    extends State<InteractiveRocketLaunchOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _flightLoopController;
  late final AnimationController _warpController;

  final math.Random _random = math.Random();

  // Rocket physics state
  double _rocketX = 0;
  double _rocketY = 0;
  double _targetRocketX = 0;
  double _targetRocketY = 0;
  double _tiltAngle = 0;
  double _machSpeed = 1;
  int _score = 0;
  bool _isWarping = false;
  bool _hasCompleted = false;

  // Particle systems
  final List<_FlightParticle> _particles = [];
  final List<_KnowledgeOrb> _orbs = [];
  final List<_FloatingScore> _scores = [];

  // Starfield
  final List<Offset> _stars = [];

  Timer? _warpTimer;

  @override
  void initState() {
    super.initState();

    // 60fps physics & render loop
    _flightLoopController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    unawaited(_flightLoopController.repeat());

    _flightLoopController.addListener(_updatePhysics);

    _warpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Generate initial starfield
    for (var i = 0; i < 75; i++) {
      _stars.add(
        Offset(
          _random.nextDouble(),
          _random.nextDouble(),
        ),
      );
    }

    // Schedule warp transition after 4.2 seconds
    _warpTimer = Timer(const Duration(milliseconds: 4200), _triggerWarpSequence);

    // Initial blast haptic
    unawaited(HapticFeedback.heavyImpact());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final size = MediaQuery.sizeOf(context);
    if (_rocketX == 0 && _rocketY == 0) {
      // Start near the bottom-right (where the launch button was) and glide to center
      _rocketX = size.width * 0.75;
      _rocketY = size.height * 0.85;
      _targetRocketX = size.width * 0.5;
      _targetRocketY = size.height * 0.65;
    }

    // Populate initial knowledge orbs
    if (_orbs.isEmpty) {
      final colors = context.colors;
      final symbols = [
        ('E=mc²', 'RELATIVITY', colors.warning),
        ('∇×B', 'MAXWELL', colors.syllabotAccent),
        ('A⁺', 'EXAM READY', colors.success),
        ('∫ f(x)dx', 'CALCULUS', colors.primary),
        ('DNA', 'GENETICS', colors.info),
        ('O(log n)', 'ALGORITHMS', colors.warning),
        ('ħ', 'QUANTUM', colors.syllabotAccent),
      ];

      for (var i = 0; i < symbols.length; i++) {
        final item = symbols[i];
        _orbs.add(
          _KnowledgeOrb(
            symbol: item.$1,
            label: item.$2,
            xRatio: 0.15 + (_random.nextDouble() * 0.7),
            y: -120.0 * (i + 1),
            color: item.$3,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _warpTimer?.cancel();
    _flightLoopController.dispose();
    _warpController.dispose();
    super.dispose();
  }

  void _updatePhysics() {
    if (!mounted || _hasCompleted) return;

    final size = MediaQuery.sizeOf(context);
    final colors = context.colors;

    // Smooth spring interpolation toward target
    final dx = _targetRocketX - _rocketX;
    final dy = _targetRocketY - _rocketY;
    _rocketX += dx * 0.14;
    _rocketY += dy * 0.14;

    // Target tilt based on horizontal velocity
    final targetTilt = (dx / 40.0).clamp(-0.45, 0.45);
    _tiltAngle += (targetTilt - _tiltAngle) * 0.2;

    // Speed progression
    if (!_isWarping) {
      _machSpeed = math.min(32, _machSpeed + 0.08);
    } else {
      _machSpeed += 1.5;
    }

    // Emit thruster exhaust particles
    final particleCount = _isWarping ? 5 : 3;
    for (var i = 0; i < particleCount; i++) {
      final spread = (_random.nextDouble() - 0.5) * 14;
      final speedFactor = _isWarping ? 18.0 : 10.0;
      final pColor = _random.nextBool()
          ? colors.warning
          : (_random.nextBool() ? colors.syllabotAccent : colors.primary);

      _particles.add(
        _FlightParticle(
          x: _rocketX + spread,
          y: _rocketY + 38,
          vx: spread * 0.25,
          vy: speedFactor + (_random.nextDouble() * 8),
          radius: 3.0 + (_random.nextDouble() * 4),
          color: pColor,
          maxLife: 24,
        ),
      );
    }

    // Update & clean particles
    for (final p in _particles) {
      p
        ..x += p.vx
        ..y += p.vy
        ..life -= 1;
    }
    _particles.removeWhere((p) => p.isDead);

    // Update knowledge orbs
    final orbSpeed = 4.0 + (_machSpeed * 0.4);
    for (final orb in _orbs) {
      orb.y += orbSpeed;

      // Check collision with rocket
      if (!orb.isCollected) {
        final orbX = orb.xRatio * size.width;
        final dist = math.sqrt(
          math.pow(orbX - _rocketX, 2) + math.pow(orb.y - _rocketY, 2),
        );

        if (dist < 48) {
          orb.isCollected = true;
          _score += 150;
          unawaited(HapticFeedback.mediumImpact());

          // Spawn burst particles
          for (var j = 0; j < 16; j++) {
            final angle = _random.nextDouble() * 2 * math.pi;
            final spd = 2.0 + (_random.nextDouble() * 5);
            _particles.add(
              _FlightParticle(
                x: orbX,
                y: orb.y,
                vx: math.cos(angle) * spd,
                vy: math.sin(angle) * spd,
                radius: 4,
                color: orb.color,
                maxLife: 30,
              ),
            );
          }

          // Spawn floating score chip
          _scores.add(
            _FloatingScore(
              text: '+150 ${orb.label}!',
              x: orbX - 30,
              y: orb.y - 20,
              color: orb.color,
            ),
          );
        }
      }
    }

    // Reset orbs when scrolled past screen
    for (final orb in _orbs) {
      if (orb.y > size.height + 100) {
        orb
          ..y = -150 - (_random.nextDouble() * 300)
          ..isCollected = false;
      }
    }

    // Update floating score chips
    for (final s in _scores) {
      s
        ..y -= 2.0
        ..opacity = math.max(0, s.opacity - 0.035);
    }
    _scores.removeWhere((s) => s.opacity <= 0);

    setState(() {});
  }

  void _onTapTurboBoost() {
    if (_isWarping) return;
    unawaited(HapticFeedback.heavyImpact());

    setState(() {
      _machSpeed += 4.5;
      _score += 50;
    });

    final colors = context.colors;

    // Spawn massive afterburner radial shockwave particles
    for (var i = 0; i < 28; i++) {
      final angle = _random.nextDouble() * 2 * math.pi;
      final speed = 6.0 + (_random.nextDouble() * 9);
      _particles.add(
        _FlightParticle(
          x: _rocketX,
          y: _rocketY + 30,
          vx: math.cos(angle) * speed,
          vy: math.sin(angle) * speed + 5,
          radius: 5,
          color: i.isEven ? colors.syllabotAccent : colors.warning,
          maxLife: 35,
        ),
      );
    }

    _scores.add(
      _FloatingScore(
        text: 'TURBO BOOST! ⚡',
        x: _rocketX - 45,
        y: _rocketY - 50,
        color: colors.syllabotAccent,
      ),
    );
  }

  void _triggerWarpSequence() {
    if (_isWarping || _hasCompleted) return;
    _isWarping = true;
    unawaited(HapticFeedback.heavyImpact());

    unawaited(
      _warpController.forward().then((_) {
        if (!_hasCompleted && mounted) {
          _hasCompleted = true;
          widget.onLaunchComplete();
        }
      }),
    );
  }

  void _onSkip() {
    if (_hasCompleted) return;
    _hasCompleted = true;
    _warpTimer?.cancel();
    widget.onLaunchComplete();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: colors.surfacePrimary,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) {
          if (_isWarping) return;
          setState(() {
            _targetRocketX =
                (_targetRocketX + details.delta.dx).clamp(40, size.width - 40);
            _targetRocketY =
                (_targetRocketY + details.delta.dy).clamp(80, size.height - 80);
          });
        },
        onTap: _onTapTurboBoost,
        child: Stack(
          children: [
            // 1. Dynamic Space / Hyperspace Canvas
            CustomPaint(
              size: Size(size.width, size.height),
              painter: _CosmicFlightPainter(
                stars: _stars,
                particles: _particles,
                machSpeed: _machSpeed,
                isWarping: _isWarping,
                warpProgress: _warpController.value,
                primaryColor: colors.primary,
                accentColor: colors.syllabotAccent,
                warningColor: colors.warning,
                whiteColor: colors.white,
                surfaceColor: colors.surfacePrimary,
              ),
            ),

            // 2. Collectible Academic Knowledge Orbs
            ..._orbs.where((orb) => !orb.isCollected).map((orb) {
              return Positioned(
                left: (orb.xRatio * size.width) - 24,
                top: orb.y - 24,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        orb.color.withAlpha(220),
                        orb.color.withAlpha(80),
                        colors.transparent,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: orb.color.withAlpha(140),
                        blurRadius: 14,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    orb.symbol,
                    textAlign: TextAlign.center,
                    style: typography.caption.bold.copyWith(
                      color: colors.white,
                      fontSize: 11,
                    ),
                  ),
                ),
              );
            }),

            // 3. Floating Score & Multiplier Badges
            ..._scores.map((score) {
              return Positioned(
                left: score.x,
                top: score.y,
                child: Opacity(
                  opacity: score.opacity,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: score.color.withAlpha(50),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: score.color.withAlpha(180)),
                    ),
                    child: Text(
                      score.text,
                      style: typography.caption.bold.copyWith(
                        color: score.color,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              );
            }),

            // 4. Hero Vector Rocket Ship
            Positioned(
              left: _rocketX - 32,
              top: _rocketY - 48,
              child: Transform.rotate(
                angle: _tiltAngle,
                child: SizedBox(
                  width: 64,
                  height: 96,
                  child: CustomPaint(
                    painter: _RocketShipPainter(
                      primaryColor: colors.primary,
                      accentColor: colors.syllabotAccent,
                      whiteColor: colors.white,
                      warningColor: colors.warning,
                      isTurbo: _isWarping,
                    ),
                  ),
                ),
              ),
            ),

            // 5. Futuristic HUD & Telemetry Bar
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Mach Speed & Orbit Telemetry
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surfaceSecondary.withAlpha(200),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: colors.primary.withAlpha(90),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.speed_rounded,
                                size: 18,
                                color: colors.syllabotAccent,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _isWarping
                                    ? l10n.warpDriveEngaged
                                    : l10n.launchMachSpeed(
                                        _machSpeed.toStringAsFixed(1),
                                      ),
                                style: typography.caption.bold.copyWith(
                                  color: colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Score / Synapse Mastery Counter
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surfaceSecondary.withAlpha(200),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: colors.warning.withAlpha(90),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.bolt_rounded,
                                size: 18,
                                color: colors.warning,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$_score XP',
                                style: typography.caption.bold.copyWith(
                                  color: colors.warning,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Skip Button
                        ShrinkableButton(
                          onTap: _onSkip,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: colors.surfaceSecondary.withAlpha(150),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              'Skip',
                              style: typography.caption.medium.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Interactive Steering & Tap Hint
                    if (!_isWarping)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary.withAlpha(35),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: colors.primary.withAlpha(80),
                          ),
                        ),
                        child: Text(
                          l10n.launchSteerHint,
                          style: typography.caption.medium.copyWith(
                            color: colors.syllabotAccent,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // 6. Hyperspace Warp Whiteout / Iris Zoom
            if (_isWarping)
              AnimatedBuilder(
                animation: _warpController,
                builder: (context, child) {
                  return IgnorePointer(
                    child: Container(
                      color: colors.white.withAlpha(
                        (_warpController.value * 255).clamp(0, 255).toInt(),
                      ),
                      alignment: Alignment.center,
                      child: _warpController.value > 0.4
                          ? Text(
                              l10n.launchEnteringWorkspace,
                              style: typography.title2.bold.copyWith(
                                color: colors.primary,
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// Custom Canvas Painter for Starfield, Speed Streaks, and Thruster Particles
class _CosmicFlightPainter extends CustomPainter {
  _CosmicFlightPainter({
    required this.stars,
    required this.particles,
    required this.machSpeed,
    required this.isWarping,
    required this.warpProgress,
    required this.primaryColor,
    required this.accentColor,
    required this.warningColor,
    required this.whiteColor,
    required this.surfaceColor,
  });

  final List<Offset> stars;
  final List<_FlightParticle> particles;
  final double machSpeed;
  final bool isWarping;
  final double warpProgress;
  final Color primaryColor;
  final Color accentColor;
  final Color warningColor;
  final Color whiteColor;
  final Color surfaceColor;

  @override
  void paint(Canvas canvas, Size size) {
    // Deep cosmic background gradient
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          surfaceColor,
          surfaceColor.withAlpha(240),
          primaryColor.withAlpha(isWarping ? 80 : 35),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final starPaint = Paint()..color = whiteColor;
    final streakPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final streakLength = isWarping ? 80.0 + (warpProgress * 200) : machSpeed * 3.5;

    // Draw Starfield & Warp Streaks
    for (final star in stars) {
      final sx = star.dx * size.width;
      final sy = star.dy * size.height;

      if (streakLength > 6) {
        streakPaint
          ..strokeWidth = isWarping ? 2.5 : 1.5
          ..color = (isWarping ? accentColor : whiteColor).withAlpha(
            (140 + (warpProgress * 115)).toInt().clamp(0, 255),
          );
        canvas.drawLine(
          Offset(sx, sy),
          Offset(sx, sy + streakLength),
          streakPaint,
        );
      } else {
        canvas.drawCircle(Offset(sx, sy), 1.2, starPaint..color = whiteColor.withAlpha(160));
      }
    }

    // Draw Thruster Particles
    for (final p in particles) {
      final alpha = ((p.life / p.maxLife) * 255).toInt().clamp(0, 255);
      final pPaint = Paint()
        ..color = p.color.withAlpha(alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawCircle(Offset(p.x, p.y), p.radius, pPaint);
    }

    // Warp Shockwave Expanding Rings
    if (isWarping) {
      final center = Offset(size.width / 2, size.height / 2);
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0
        ..color = accentColor.withAlpha(((1 - warpProgress) * 220).toInt().clamp(0, 255))
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4);

      final radius = warpProgress * size.height * 0.9;
      canvas.drawCircle(center, radius, ringPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CosmicFlightPainter oldDelegate) => true;
}

/// Custom Vector Painter for Sleek Spaceship with Dynamic Thruster Plumes
class _RocketShipPainter extends CustomPainter {
  _RocketShipPainter({
    required this.primaryColor,
    required this.accentColor,
    required this.whiteColor,
    required this.warningColor,
    required this.isTurbo,
  });

  final Color primaryColor;
  final Color accentColor;
  final Color whiteColor;
  final Color warningColor;
  final bool isTurbo;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;

    // 1. Dynamic Flame Nozzle
    final flameHeight = isTurbo ? 42.0 : 28.0;
    final flamePath = Path()
      ..moveTo(cx - 8, size.height * 0.75)
      ..quadraticBezierTo(
        cx,
        size.height * 0.75 + flameHeight,
        cx + 8,
        size.height * 0.75,
      )
      ..close();

    final flamePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          warningColor,
          accentColor,
          accentColor.withAlpha(0),
        ],
      ).createShader(
        Rect.fromLTWH(cx - 12, size.height * 0.75, 24, flameHeight),
      )
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3);
    canvas.drawPath(flamePath, flamePaint);

    // 2. Aerodynamic Wings / Fins
    final wingPath = Path()
      // Left wing
      ..moveTo(cx - 10, size.height * 0.52)
      ..lineTo(cx - 28, size.height * 0.74)
      ..lineTo(cx - 10, size.height * 0.70)
      // Right wing
      ..moveTo(cx + 10, size.height * 0.52)
      ..lineTo(cx + 28, size.height * 0.74)
      ..lineTo(cx + 10, size.height * 0.70)
      ..close();

    final wingPaint = Paint()..color = accentColor;
    canvas.drawPath(wingPath, wingPaint);

    // 3. Rocket Fuselage Body
    final bodyPath = Path()
      ..moveTo(cx, size.height * 0.08) // Nose cone tip
      ..cubicTo(
        cx + 18,
        size.height * 0.30,
        cx + 16,
        size.height * 0.65,
        cx + 12,
        size.height * 0.74,
      )
      ..lineTo(cx - 12, size.height * 0.74)
      ..cubicTo(
        cx - 16,
        size.height * 0.65,
        cx - 18,
        size.height * 0.30,
        cx,
        size.height * 0.08,
      )
      ..close();

    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          whiteColor,
          whiteColor.withAlpha(230),
          primaryColor.withAlpha(120),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(bodyPath, bodyPaint);

    // 4. Cockpit Windshield Visor
    final visorPaint = Paint()..color = primaryColor;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, size.height * 0.35),
        width: 12,
        height: 18,
      ),
      visorPaint,
    );

    // Visor Glass Glare
    final glarePaint = Paint()..color = whiteColor.withAlpha(180);
    canvas.drawCircle(Offset(cx - 2, size.height * 0.32), 2.5, glarePaint);
  }

  @override
  bool shouldRepaint(covariant _RocketShipPainter oldDelegate) => true;
}
