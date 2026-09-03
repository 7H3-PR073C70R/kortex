import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/l10n/l10n.dart';

/// Visual style variants for [AppBadge].
enum AppBadgeVariant {
  primary,
  secondary,
  success,
  warning,
  error,
  outline,
  syllabot,
}

/// Compact status chip with descriptive screen-reader context.
class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    this.label,
    this.count,
    this.icon,
    this.variant = AppBadgeVariant.primary,
    this.dotOnly = false,
    this.dotSize = 8,
    this.maxCount = 99,
    this.padding,
    this.borderRadius,
    this.backgroundColor,
    this.textColor,
    this.semanticLabel,
  });

  /// Factory for a small status dot.
  const AppBadge.dot({
    Key? key,
    AppBadgeVariant variant = AppBadgeVariant.primary,
    double dotSize = 8,
    Color? color,
    String? semanticLabel,
  }) : this(
         key: key,
         variant: variant,
         dotOnly: true,
         dotSize: dotSize,
         backgroundColor: color,
         semanticLabel: semanticLabel,
       );

  /// Factory for a numeric counter badge.
  const AppBadge.count({
    required int count,
    Key? key,
    AppBadgeVariant variant = AppBadgeVariant.primary,
    int maxCount = 99,
    String? semanticLabel,
  }) : this(
         key: key,
         count: count,
         variant: variant,
         maxCount: maxCount,
         semanticLabel: semanticLabel,
       );

  final String? label;
  final int? count;
  final Widget? icon;
  final AppBadgeVariant variant;
  final bool dotOnly;
  final double dotSize;
  final int maxCount;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;
  final Color? backgroundColor;
  final Color? textColor;
  final String? semanticLabel;

  String _deriveSemanticLabel(BuildContext context) {
    if (semanticLabel != null) return semanticLabel!;
    final l10n = context.l10n;
    if (dotOnly) return l10n.statusIndicator(variant.name);
    if (count != null) {
      return count! > maxCount
          ? l10n.unreadItemsMoreThan(maxCount)
          : l10n.unreadItemsCount(count!);
    }
    return label != null ? l10n.badgeSuffix(label!) : '';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    final resolvedBg = backgroundColor ?? _resolveBackground(colors);
    final resolvedFg = textColor ?? _resolveForeground(colors);
    final resolvedBorder = _resolveBorder(colors);

    if (dotOnly) {
      return Semantics(
        container: true,
        label: _deriveSemanticLabel(context),
        child: Container(
          width: dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            color: resolvedFg,
            shape: BoxShape.circle,
          ),
        ),
      );
    }

    var displayText = label;
    if (count != null) {
      displayText = count! > maxCount ? '$maxCount+' : count.toString();
    }

    final badgeContent = Container(
      padding:
          padding ??
          EdgeInsets.symmetric(
            horizontal: count != null ? 7 : 9,
            vertical: 3,
          ),
      decoration: BoxDecoration(
        color: resolvedBg,
        borderRadius: BorderRadius.circular(borderRadius ?? 12),
        border: resolvedBorder != null
            ? Border.all(color: resolvedBorder)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            ExcludeSemantics(
              child: IconTheme(
                data: IconThemeData(
                  color: resolvedFg,
                  size: 13,
                ),
                child: icon!,
              ),
            ),
            if (displayText != null) const SizedBox(width: 4),
          ],
          if (displayText != null)
            ExcludeSemantics(
              child: Text(
                displayText,
                style: typography.caption.semiBold.copyWith(
                  fontSize: 11,
                  color: resolvedFg,
                  height: 1.1,
                ),
              ),
            ),
        ],
      ),
    );

    return Semantics(
      container: true,
      label: _deriveSemanticLabel(context),
      child: badgeContent,
    );
  }

  Color _resolveBackground(AppThemeColorsExtension colors) {
    switch (variant) {
      case AppBadgeVariant.primary:
        return colors.primary.withAlpha(35);
      case AppBadgeVariant.secondary:
        return colors.surfaceTertiary;
      case AppBadgeVariant.success:
        return colors.success.withAlpha(35);
      case AppBadgeVariant.warning:
        return colors.warning.withAlpha(35);
      case AppBadgeVariant.error:
        return colors.error.withAlpha(35);
      case AppBadgeVariant.outline:
        return Colors.transparent;
      case AppBadgeVariant.syllabot:
        return colors.syllabotAccent.withAlpha(35);
    }
  }

  Color _resolveForeground(AppThemeColorsExtension colors) {
    switch (variant) {
      case AppBadgeVariant.primary:
        return colors.primary;
      case AppBadgeVariant.secondary:
        return colors.textPrimary;
      case AppBadgeVariant.success:
        return colors.success;
      case AppBadgeVariant.warning:
        return colors.warning;
      case AppBadgeVariant.error:
        return colors.error;
      case AppBadgeVariant.outline:
        return colors.textSecondary;
      case AppBadgeVariant.syllabot:
        return colors.syllabotAccent;
    }
  }

  Color? _resolveBorder(AppThemeColorsExtension colors) {
    switch (variant) {
      case AppBadgeVariant.outline:
        return colors.surfaceBorder;
      case AppBadgeVariant.primary:
      case AppBadgeVariant.secondary:
      case AppBadgeVariant.success:
      case AppBadgeVariant.warning:
      case AppBadgeVariant.error:
      case AppBadgeVariant.syllabot:
        return null;
    }
  }
}
