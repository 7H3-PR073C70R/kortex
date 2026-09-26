import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/features/syllabot/presentation/pages/syllabot_chat_page.dart';
import 'package:kortex/src/shared/widgets/app_tour_keys.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';
import 'package:kortex/src/shared/widgets/syllabot_avatar.dart';

/// A global floating expandable & collapsible Syllabot AI overlay.
///
/// Features:
/// - Floats conveniently above the bottom navigation dock.
/// - Innovative Logo-Only Syllabot AI orb button with rotating multi-color AI ring.
/// - Expandable into full-screen Syllabot AI workspace on tap.
/// - Collapsible with a single tap to return to the unobtrusive floating logo.
/// - Retains ongoing conversation context across minimize/maximize cycles.
class FloatingSyllabotOverlay extends StatefulWidget {
  const FloatingSyllabotOverlay({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  State<FloatingSyllabotOverlay> createState() =>
      _FloatingSyllabotOverlayState();
}

class _FloatingSyllabotOverlayState extends State<FloatingSyllabotOverlay>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late final AnimationController _expandController;
  late final Animation<double> _expandAnimation;

  // Position tracking for floating button
  double? _customBottomOffset;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      vsync: this,
      duration: AppMotion.expressive,
      reverseDuration: AppMotion.standard,
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: AppMotion.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  void _expand() {
    unawaited(HapticFeedback.mediumImpact());
    setState(() {
      _isExpanded = true;
    });
    unawaited(_expandController.forward());
  }

  void _collapse() {
    unawaited(HapticFeedback.lightImpact());
    unawaited(
      _expandController.reverse().then((_) {
        if (mounted) {
          setState(() {
            _isExpanded = false;
          });
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    final defaultBottom = math.max(84, (bottomInset + 76).toInt()).toDouble();
    final bottomPosition = _customBottomOffset ?? defaultBottom;

    return Stack(
      children: [
        // 1. Underlying Application Pages
        widget.child,

        // 2. Collapsed Floating Syllabot AI Logo Orb (When not expanded)
        if (!_isExpanded || _expandAnimation.value < 1.0)
          Positioned(
            right: 20,
            bottom: bottomPosition,
            child: FadeTransition(
              opacity: Tween<double>(begin: 1, end: 0).animate(
                _expandAnimation,
              ),
              child: GestureDetector(
                onVerticalDragUpdate: (details) {
                  setState(() {
                    final size = MediaQuery.sizeOf(context);
                    final newBottom = (size.height - details.globalPosition.dy)
                        .clamp(defaultBottom, size.height - 140);
                    _customBottomOffset = newBottom;
                  });
                },
                child: Semantics(
                  button: true,
                  label: 'Ask Syllabot AI Assistant',
                  child: Material(
                    type: MaterialType.transparency,
                    child: PlatformHoverBuilder(
                      builder: (context, isHovered, child) {
                        return AnimatedScale(
                          scale: isHovered ? 1.08 : 1.0,
                          duration: AppMotion.snappy,
                          curve: AppMotion.easeOutCubic,
                          child: child,
                        );
                      },
                      child: ShrinkableButton(
                        key: AppTourKeys.syllabotFabKey = AppTourKeys.safeKey(
                          AppTourKeys.syllabotFabKey,
                          'tour_syllabot_fab',
                        ),
                        onTap: _expand,
                        child: const _SyllabotLogoOrb(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

        // 3. Full-Screen Expanded Syllabot Chat Sheet Overlay (Persists state)
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !_isExpanded,
            child: AnimatedBuilder(
              animation: _expandAnimation,
              builder: (context, child) {
                final isHidden = !_isExpanded && _expandAnimation.value == 0;
                return Offstage(
                  offstage: isHidden,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.15),
                      end: Offset.zero,
                    ).animate(_expandAnimation),
                    child: FadeTransition(
                      opacity: _expandAnimation,
                      child: child,
                    ),
                  ),
                );
              },
              child: Material(
                color: colors.backgroundPrimary,
                child: SyllabotChatPage(
                  onCollapse: _collapse,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Mind-Blowing & Weird Quantum Liquid Syllabot AI Floating Orb
class _SyllabotLogoOrb extends StatefulWidget {
  const _SyllabotLogoOrb();

  @override
  State<_SyllabotLogoOrb> createState() => _SyllabotLogoOrbState();
}

class _SyllabotLogoOrbState extends State<_SyllabotLogoOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    unawaited(_pulseController.repeat(reverse: true));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final neural = context.neural;
    final colors = context.colors;
    final isDark = context.isDarkMode;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final progress = _pulseController.value;
        final breathScale = 1.0 + (math.sin(progress * math.pi * 2) * 0.04);
        final glowOpacity = 0.35 + (math.sin(progress * math.pi * 2) * 0.25);

        return Transform.scale(
          scale: breathScale,
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? neural.obsidian950.withAlpha(240)
                  : colors.surfacePrimary.withAlpha(240),
              border: Border.all(
                color: isDark
                    ? colors.white.withAlpha(50)
                    : colors.black.withAlpha(25),
              ),
              boxShadow: [
                BoxShadow(
                  color: neural.fuchsia500.withAlpha((glowOpacity * 160).toInt()),
                  blurRadius: 22,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: neural.cyan.withAlpha((glowOpacity * 180).toInt()),
                  blurRadius: 18,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: ClipOval(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 1. Organic Weird Quantum Liquid Wave Halo
                    CustomPaint(
                      size: const Size(58, 58),
                      painter: _QuantumAuroraHaloPainter(
                        progress: progress,
                        cyan: neural.cyan,
                        fuchsia: neural.fuchsia500,
                        indigo: neural.indigo500,
                        amber: neural.amber400,
                      ),
                    ),

                    // 2. Central Syllabot Mascot Avatar Core
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? neural.obsidian950.withAlpha(220)
                            : colors.surfaceSecondary.withAlpha(230),
                        border: Border.all(
                          color: neural.cyan.withAlpha(120),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: neural.cyan.withAlpha(60),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: SyllabotAvatar(size: 34),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _QuantumAuroraHaloPainter extends CustomPainter {
  const _QuantumAuroraHaloPainter({
    required this.progress,
    required this.cyan,
    required this.fuchsia,
    required this.indigo,
    required this.amber,
  });

  final double progress;
  final Color cyan;
  final Color fuchsia;
  final Color indigo;
  final Color amber;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final angle = progress * math.pi * 2;

    // Organic liquid wave distortion painter
    final path = Path();
    const points = 16;
    for (var i = 0; i < points; i++) {
      final theta = (i * 2 * math.pi) / points;
      // Organic sine wave distortion for a weird liquid physics vibe
      final wave = math.sin(theta * 3 + angle * 2) * 2.2 +
          math.cos(theta * 2 - angle) * 1.4;
      final r = (radius * 0.90) + wave;

      final x = center.dx + r * math.cos(theta);
      final y = center.dy + r * math.sin(theta);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    final paint = Paint()
      ..shader = SweepGradient(
        transform: GradientRotation(angle),
        colors: [
          cyan.withAlpha(180),
          indigo.withAlpha(190),
          fuchsia.withAlpha(200),
          amber.withAlpha(160),
          cyan.withAlpha(180),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _QuantumAuroraHaloPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
