import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';

/// Animated skeleton loading placeholder signaling loading to screen readers.
class ShimmerPlaceholder extends StatefulWidget {
  const ShimmerPlaceholder({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
    this.baseColor,
    this.highlightColor,
    this.semanticLabel = 'Loading content',
  });

  /// Rectangular skeleton placeholder.
  const ShimmerPlaceholder.rectangular({
    required double height,
    Key? key,
    double? width,
    double borderRadius = 8.0,
    Color? baseColor,
    Color? highlightColor,
    String semanticLabel = 'Loading content',
  }) : this(
          key: key,
          width: width,
          height: height,
          borderRadius: borderRadius,
          shape: BoxShape.rectangle,
          baseColor: baseColor,
          highlightColor: highlightColor,
          semanticLabel: semanticLabel,
        );

  /// Circular skeleton placeholder.
  const ShimmerPlaceholder.circular({
    required double radius,
    Key? key,
    Color? baseColor,
    Color? highlightColor,
    String semanticLabel = 'Loading profile avatar',
  }) : this(
          key: key,
          width: radius * 2,
          height: radius * 2,
          shape: BoxShape.circle,
          baseColor: baseColor,
          highlightColor: highlightColor,
          semanticLabel: semanticLabel,
        );

  final double? width;
  final double? height;
  final double? borderRadius;
  final BoxShape shape;
  final Color? baseColor;
  final Color? highlightColor;
  final String semanticLabel;

  @override
  State<ShimmerPlaceholder> createState() => _ShimmerPlaceholderState();
}

class _ShimmerPlaceholderState extends State<ShimmerPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
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

    final effectiveBase = widget.baseColor ?? colors.surfaceSecondary;
    final effectiveHighlight =
        widget.highlightColor ?? colors.surfaceTertiary;

    return Semantics(
      container: true,
      label: widget.semanticLabel,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              shape: widget.shape,
              borderRadius: widget.shape == BoxShape.rectangle
                  ? BorderRadius.circular(widget.borderRadius ?? 8.0)
                  : null,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: const [0.1, 0.5, 0.9],
                colors: [
                  effectiveBase,
                  effectiveHighlight,
                  effectiveBase,
                ],
                transform: _SlidingGradientTransform(
                  slidePercent: _controller.value,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform({required this.slidePercent});

  final double slidePercent;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(
      bounds.width * (slidePercent * 2 - 1),
      0,
      0,
    );
  }
}
