import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';

/// Wraps a looping [AnimationController] and rebuilds a [CustomPaint] each frame.
/// When the platform requests reduced motion, the loop settles on its completed (t = 1.0) composition.
class AnimatedScene extends StatefulWidget {
  const AnimatedScene({
    required this.durationMs,
    required this.painter,
    this.width,
    this.height,
    super.key,
  });

  final int durationMs;
  final CustomPainter Function(AppThemeColorsExtension colors, double t) painter;
  final double? width;
  final double? height;

  @override
  State<AnimatedScene> createState() => _AnimatedSceneState();
}

class _AnimatedSceneState extends State<AnimatedScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.durationMs),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    if (disableAnimations) {
      if (_controller.isAnimating) _controller.stop();
      _controller.value = 1.0;
    } else if (!_controller.isAnimating) {
      unawaited(_controller.repeat());
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final colors = context.colors;
            return CustomPaint(
              painter: widget.painter(colors, _controller.value),
            );
          },
        ),
      ),
    );
  }
}

/// Normalized sub-segment of the master timeline: 0 before [a], 1 after [b].
double seg(double t, double a, double b) =>
    ((t - a) / (b - a)).clamp(0.0, 1.0);

/// Ease-out cubic — fast departure, gentle settle.
double eo(double v) => 1 - math.pow(1 - v, 3).toDouble();

/// Returns rounded rectangle with given radius.
RRect rr(Rect rect, double radius) =>
    RRect.fromRectAndRadius(rect, Radius.circular(radius));

/// Paints a single line of text. Returns its size so callers can align.
Size drawLabel(
  Canvas canvas,
  String text, {
  required Offset at,
  required double size,
  required Color color,
  FontWeight weight = FontWeight.w600,
  double opacity = 1,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontSize: size,
        color: color.withAlpha((opacity * 255).round()),
        fontWeight: weight,
        height: 1,
      ),
    ),
    textDirection: TextDirection.ltr,
  )
    ..layout()
    ..paint(canvas, at);
  return painter.size;
}

/// Paints centered text on given anchor offset.
void drawLabelCentered(
  Canvas canvas,
  String text,
  Offset center, {
  required double size,
  required Color color,
  FontWeight weight = FontWeight.w600,
  double opacity = 1,
}) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontSize: size,
        color: color.withAlpha((opacity * 255).round()),
        fontWeight: weight,
        height: 1,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(
    canvas,
    Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
  );
}
