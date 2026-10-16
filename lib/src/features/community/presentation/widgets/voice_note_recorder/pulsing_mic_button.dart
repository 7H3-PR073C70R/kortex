import 'dart:async';
import 'package:flutter/material.dart';

/// Continuously pulsing mic circle used as the "tap to stop" affordance
/// during an active recording session.
class PulsingMicButton extends StatefulWidget {
  const PulsingMicButton({
    required this.compact,
    required this.isDark,
    required this.errorColor,
    super.key,
  });

  final bool compact;
  final bool isDark;
  final Color errorColor;

  @override
  State<PulsingMicButton> createState() => _PulsingMicButtonState();
}

class _PulsingMicButtonState extends State<PulsingMicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _rippleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    unawaited(_controller.repeat());

    _scaleAnim = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 1, curve: Curves.easeInOut),
      ),
    );
    _rippleAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const size = 36.0;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final ripple = _rippleAnim.value;
        final scale = _scaleAnim.value;
        return SizedBox(
          width: size + 12,
          height: size + 12,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer ripple ring
              Opacity(
                opacity: ((1 - ripple) * 0.9).clamp(0.0, 1.0),
                child: Container(
                  width: size + ripple * 14,
                  height: size + ripple * 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.errorColor
                          .withAlpha(((1 - ripple) * 140).round()),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              // Core pulsing mic circle
              Transform.scale(
                scale: scale,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.errorColor
                        .withAlpha(widget.isDark ? 60 : 40),
                    border: Border.all(
                      color: widget.errorColor.withAlpha(200),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.errorColor.withAlpha(100),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.mic_rounded,
                    size: widget.compact ? 18 : 20,
                    color: widget.errorColor,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
