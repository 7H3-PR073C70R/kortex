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

/// Innovative Logo-Only Syllabot AI Floating Orb with rotating multi-color AI petals
class _SyllabotLogoOrb extends StatefulWidget {
  const _SyllabotLogoOrb();

  @override
  State<_SyllabotLogoOrb> createState() => _SyllabotLogoOrbState();
}

class _SyllabotLogoOrbState extends State<_SyllabotLogoOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
    unawaited(_rotationController.repeat());
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final neural = context.neural;
    final colors = context.colors;
    final isDark = context.isDarkMode;

    return Container(
      key: AppTourKeys.syllabotFabKey,
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark
            ? neural.obsidian950.withAlpha(240)
            : colors.surfaceSecondary.withAlpha(240),
        border: Border.all(
          color: isDark
              ? colors.white.withAlpha(45)
              : colors.black.withAlpha(20),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: neural.fuchsia500.withAlpha(isDark ? 80 : 50),
            blurRadius: 18,
            spreadRadius: -2,
          ),
          BoxShadow(
            color: neural.cyan.withAlpha(isDark ? 65 : 40),
            blurRadius: 14,
            spreadRadius: -4,
          ),
        ],
      ),
      child: ClipOval(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Rotating multi-color radial AI petals
              RotationTransition(
                turns: _rotationController,
                child: CustomPaint(
                  size: const Size(50, 50),
                  painter: _AIPetalsPainter(
                    colors: [
                      neural.cyan,
                      neural.indigo500,
                      neural.fuchsia500,
                      neural.purple500,
                      neural.amber400,
                      neural.cyan300,
                      neural.cyan,
                    ],
                  ),
                ),
              ),
              // 2. Central AI core spark badge
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? neural.obsidian950.withAlpha(230)
                      : colors.surfaceSecondary.withAlpha(235),
                  border: Border.all(
                    color: neural.cyan.withAlpha(120),
                    width: 0.8,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 13,
                    color: neural.cyan300,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AIPetalsPainter extends CustomPainter {
  _AIPetalsPainter({required this.colors});

  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const count = 8;
    final radius = size.width * 0.33;
    final petalWidth = size.width * 0.12;
    final petalLength = size.width * 0.22;

    for (var i = 0; i < count; i++) {
      final angle = (i * 2 * math.pi) / count;
      final color = colors[i % colors.length];

      canvas
        ..save()
        ..translate(center.dx, center.dy)
        ..rotate(angle);

      final paint = Paint()
        ..color = color.withAlpha(220)
        ..style = PaintingStyle.fill;

      final path = Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              -petalWidth / 2,
              -radius - (petalLength / 2),
              petalWidth,
              petalLength,
            ),
            Radius.circular(petalWidth / 2),
          ),
        );

      canvas
        ..drawPath(path, paint)
        ..restore();
    }
  }

  @override
  bool shouldRepaint(covariant _AIPetalsPainter oldDelegate) => false;
}
