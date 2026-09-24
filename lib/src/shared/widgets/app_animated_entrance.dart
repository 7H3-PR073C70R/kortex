import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';

/// Fluid organic entrance animation widget that provides staggered glide,
/// gentle fade, and subtle scale-in for lists, cards, and sections.
///
/// Respects user accessibility preferences (`reduceMotion`).
class AppAnimatedEntrance extends StatefulWidget {
  const AppAnimatedEntrance({
    required this.child,
    super.key,
    this.staggerIndex = 0,
    this.duration = const Duration(milliseconds: 350),
    this.offset = const Offset(0, 16),
    this.scaleBegin = 0.98,
    this.curve = AppMotion.easeOutCubic,
    this.delay,
  });

  /// The widget to animate.
  final Widget child;

  /// Stagger sequence index (0, 1, 2...). Computes an organic entry cascade.
  final int staggerIndex;

  /// Duration of the entry animation.
  final Duration duration;

  /// Starting translation offset. Defaults to (0, 16) for a gentle upward glide.
  final Offset offset;

  /// Starting scale. Defaults to 0.98 for subtle depth settle.
  final double scaleBegin;

  /// Deceleration curve. Defaults to [AppMotion.easeOutCubic].
  final Curve curve;

  /// Explicit custom delay override if specified.
  final Duration? delay;

  @override
  State<AppAnimatedEntrance> createState() => _AppAnimatedEntranceState();
}

class _AppAnimatedEntranceState extends State<AppAnimatedEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _scaleAnimation;
  Timer? _delayTimer;

  Duration get _effectiveDelay {
    if (widget.delay != null) return widget.delay!;
    // Cap stagger delay at 280ms so deep lists never lag
    final ms = math.min(widget.staggerIndex * 35, 280);
    return Duration(milliseconds: ms);
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    final curved = CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(curved);
    _slideAnimation = Tween<Offset>(
      begin: widget.offset,
      end: Offset.zero,
    ).animate(curved);
    _scaleAnimation = Tween<double>(
      begin: widget.scaleBegin,
      end: 1,
    ).animate(curved);

    final delay = _effectiveDelay;
    if (delay == Duration.zero) {
      unawaited(_controller.forward());
    } else {
      _delayTimer = Timer(delay, () {
        if (mounted) {
          unawaited(_controller.forward());
        }
      });
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (context.reduceMotion) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: _slideAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Organic pulsating beacon widget used for live status indicators
/// (e.g. live study rooms, active focus sessions, hot discussions).
class AppPulsingBeacon extends StatefulWidget {
  const AppPulsingBeacon({
    required this.color,
    super.key,
    this.size = 8,
    this.pulseSpread = 6,
    this.duration = const Duration(milliseconds: 1600),
  });

  final Color color;
  final double size;
  final double pulseSpread;
  final Duration duration;

  @override
  State<AppPulsingBeacon> createState() => _AppPulsingBeaconState();
}

class _AppPulsingBeaconState extends State<AppPulsingBeacon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
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
    if (context.reduceMotion) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final progress = _controller.value;
        final spread = progress * widget.pulseSpread;
        final alpha = (1.0 - progress) * 0.4;

        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: widget.size + (spread * 2),
              height: widget.size + (spread * 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withValues(alpha: alpha),
              ),
            ),
            Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color,
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.6),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Smooth integer counter that rolls up to its target with easing and haptics.
class AppAnimatedCounter extends StatelessWidget {
  const AppAnimatedCounter({
    required this.targetValue,
    required this.style,
    super.key,
    this.duration = const Duration(milliseconds: 900),
    this.prefix = '',
    this.suffix = '',
  });

  final int targetValue;
  final TextStyle style;
  final Duration duration;
  final String prefix;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    if (context.reduceMotion) {
      return Text('$prefix$targetValue$suffix', style: style);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: targetValue.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Text(
          '$prefix${value.toInt()}$suffix',
          style: style,
        );
      },
    );
  }
}
