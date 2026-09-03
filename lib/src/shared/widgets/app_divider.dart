import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';

/// Adaptive line divider with automatic semantics exclusions for VoiceOver.
class AppDivider extends StatelessWidget {
  const AppDivider({
    super.key,
    this.thickness = 1.0,
    this.indent = 0.0,
    this.endIndent = 0.0,
    this.color,
    this.label,
    this.margin,
  }) : isVertical = false;

  /// Vertical orientation constructor.
  const AppDivider.vertical({
    super.key,
    this.thickness = 1.0,
    this.indent = 0.0,
    this.endIndent = 0.0,
    this.color,
    this.margin,
  }) : isVertical = true,
       label = null;

  final double thickness;
  final double indent;
  final double endIndent;
  final Color? color;
  final String? label;
  final EdgeInsetsGeometry? margin;
  final bool isVertical;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final effectiveColor = color ?? colors.surfaceBorder;

    if (isVertical) {
      return ExcludeSemantics(
        child: Container(
          margin: margin,
          width: thickness,
          color: effectiveColor,
        ),
      );
    }

    if (label != null) {
      return Container(
        margin: margin ?? const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: ExcludeSemantics(
                child: Divider(
                  color: effectiveColor,
                  thickness: thickness,
                  indent: indent,
                  endIndent: 12,
                ),
              ),
            ),
            Semantics(
              header: true,
              label: label,
              child: Text(
                label!,
                style: typography.caption.medium.copyWith(
                  color: colors.textMuted,
                  fontSize: 12,
                ),
              ),
            ),
            Expanded(
              child: ExcludeSemantics(
                child: Divider(
                  color: effectiveColor,
                  thickness: thickness,
                  indent: 12,
                  endIndent: endIndent,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ExcludeSemantics(
      child: Container(
        margin: margin,
        child: Divider(
          color: effectiveColor,
          thickness: thickness,
          indent: indent,
          endIndent: endIndent,
          height: thickness,
        ),
      ),
    );
  }
}
