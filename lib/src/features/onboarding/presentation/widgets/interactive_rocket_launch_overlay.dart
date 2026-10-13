import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/onboarding/presentation/widgets/rocket/cosmic_flight_painter.dart';
import 'package:kortex/src/features/onboarding/presentation/widgets/rocket/rocket_flight_models.dart';
import 'package:kortex/src/features/onboarding/presentation/widgets/rocket/rocket_launch_hud_bar.dart';
import 'package:kortex/src/features/onboarding/presentation/widgets/rocket/rocket_ship_painter.dart';

export 'rocket/cosmic_flight_painter.dart';
export 'rocket/rocket_flight_models.dart';
export 'rocket/rocket_launch_hud_bar.dart';
export 'rocket/rocket_ship_painter.dart';

/// Interactive Rocket Launch Animation Overlay.
///
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
  final List<FlightParticle> _particles = [];
  final List<KnowledgeOrb> _orbs = [];
  final List<FloatingScore> _scores = [];

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
      duration: const Duration(milliseconds: 600),
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

    // Schedule warp transition after 1.7 seconds for a punchy, snappy launch
    _warpTimer = Timer(
      const Duration(milliseconds: 1700),
      _triggerWarpSequence,
    );

    // Initial blast haptic
    unawaited(HapticFeedback.heavyImpact());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations ||
        MediaQuery.of(context).accessibleNavigation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_hasCompleted) {
          _hasCompleted = true;
          widget.onLaunchComplete();
        }
      });
      return;
    }

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
          KnowledgeOrb(
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
    if (!_isWarping) {
      _rocketX += dx * 0.22;
      _rocketY += dy * 0.22;

      // Target tilt based on horizontal velocity
      final targetTilt = (dx / 40.0).clamp(-0.45, 0.45);
      _tiltAngle += (targetTilt - _tiltAngle) * 0.25;
    } else {
      _rocketY -= 28.0;
      _tiltAngle *= 0.85;
    }

    // Fast speed progression for snappy launch
    if (!_isWarping) {
      _machSpeed = math.min(35, _machSpeed + 0.35);
    } else {
      _machSpeed += 2.5;
    }

    // Emit thruster exhaust particles
    final particleCount = _isWarping ? 6 : 4;
    for (var i = 0; i < particleCount; i++) {
      final spread = (_random.nextDouble() - 0.5) * 14;
      final speedFactor = _isWarping ? 20.0 : 12.0;
      final pColor = _random.nextBool()
          ? colors.warning
          : (_random.nextBool() ? colors.syllabotAccent : colors.primary);

      _particles.add(
        FlightParticle(
          x: _rocketX + spread,
          y: _rocketY + 38,
          vx: spread * 0.25,
          vy: speedFactor + (_random.nextDouble() * 8),
          radius: 3.0 + (_random.nextDouble() * 4),
          color: pColor,
          maxLife: 20,
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

    // Update knowledge orbs with faster drift
    final orbSpeed = 8.0 + (_machSpeed * 0.5);
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
              FlightParticle(
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
            FloatingScore(
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
        FlightParticle(
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
      FloatingScore(
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
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: colors.surfacePrimary,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) {
          if (_isWarping) return;
          setState(() {
            _targetRocketX = (_targetRocketX + details.delta.dx).clamp(
              40,
              size.width - 40,
            );
            _targetRocketY = (_targetRocketY + details.delta.dy).clamp(
              80,
              size.height - 80,
            );
          });
        },
        onTap: _onTapTurboBoost,
        child: Stack(
          children: [
            // 1. Dynamic Space / Hyperspace Canvas
            CustomPaint(
              size: Size(size.width, size.height),
              painter: CosmicFlightPainter(
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
                    color: orb.color.withAlpha(200),
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
                    painter: RocketShipPainter(
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
            RocketLaunchHudBar(
              machSpeed: _machSpeed,
              score: _score,
              isWarping: _isWarping,
              onSkip: _onSkip,
            ),
          ],
        ),
      ),
    );
  }
}
