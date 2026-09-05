import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Visual style variants for [AppButton].
enum AppButtonVariant {
  primary,
  secondary,
  outline,
  ghost,
  destructive,
}

/// Sizing presets for [AppButton] adhering to 48x48dp minimum touch targets.
enum AppButtonSize {
  small(height: 38, fontSize: 13, iconSize: 16, horizontalPadding: 14),
  medium(height: 48, fontSize: 15, iconSize: 18, horizontalPadding: 20),
  large(height: 56, fontSize: 17, iconSize: 20, horizontalPadding: 24)
  ;

  const AppButtonSize({
    required this.height,
    required this.fontSize,
    required this.iconSize,
    required this.horizontalPadding,
  });

  final double height;
  final double fontSize;
  final double iconSize;
  final double horizontalPadding;
}

/// Universal WCAG 2.1 AA compliant button with tactile and voiceover feedback.
class AppButton extends StatefulWidget {
  const AppButton({
    required this.text,
    super.key,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.medium,
    this.isLoading = false,
    this.isEnabled = true,
    this.prefixIcon,
    this.suffixIcon,
    this.width,
    this.borderRadius,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
    this.textStyle,
    this.semanticLabel,
    this.semanticHint,
    this.focusNode,
    this.autofocus = false,
  });

  /// Factory constructor for a primary CTA button.
  const AppButton.primary({
    required String text,
    Key? key,
    VoidCallback? onPressed,
    AppButtonSize size = AppButtonSize.medium,
    bool isLoading = false,
    bool isEnabled = true,
    Widget? prefixIcon,
    Widget? suffixIcon,
    double? width,
    double? borderRadius,
    String? semanticLabel,
    String? semanticHint,
    FocusNode? focusNode,
    bool autofocus = false,
  }) : this(
         key: key,
         text: text,
         onPressed: onPressed,
         variant: AppButtonVariant.primary,
         size: size,
         isLoading: isLoading,
         isEnabled: isEnabled,
         prefixIcon: prefixIcon,
         suffixIcon: suffixIcon,
         width: width,
         borderRadius: borderRadius,
         semanticLabel: semanticLabel,
         semanticHint: semanticHint,
         focusNode: focusNode,
         autofocus: autofocus,
       );

  /// Factory constructor for a secondary surface button.
  const AppButton.secondary({
    required String text,
    Key? key,
    VoidCallback? onPressed,
    AppButtonSize size = AppButtonSize.medium,
    bool isLoading = false,
    bool isEnabled = true,
    Widget? prefixIcon,
    Widget? suffixIcon,
    double? width,
    double? borderRadius,
    String? semanticLabel,
    String? semanticHint,
    FocusNode? focusNode,
    bool autofocus = false,
  }) : this(
         key: key,
         text: text,
         onPressed: onPressed,
         variant: AppButtonVariant.secondary,
         size: size,
         isLoading: isLoading,
         isEnabled: isEnabled,
         prefixIcon: prefixIcon,
         suffixIcon: suffixIcon,
         width: width,
         borderRadius: borderRadius,
         semanticLabel: semanticLabel,
         semanticHint: semanticHint,
         focusNode: focusNode,
         autofocus: autofocus,
       );

  /// Factory constructor for an outline bordered button.
  const AppButton.outline({
    required String text,
    Key? key,
    VoidCallback? onPressed,
    AppButtonSize size = AppButtonSize.medium,
    bool isLoading = false,
    bool isEnabled = true,
    Widget? prefixIcon,
    Widget? suffixIcon,
    double? width,
    double? borderRadius,
    String? semanticLabel,
    String? semanticHint,
    FocusNode? focusNode,
    bool autofocus = false,
  }) : this(
         key: key,
         text: text,
         onPressed: onPressed,
         variant: AppButtonVariant.outline,
         size: size,
         isLoading: isLoading,
         isEnabled: isEnabled,
         prefixIcon: prefixIcon,
         suffixIcon: suffixIcon,
         width: width,
         borderRadius: borderRadius,
         semanticLabel: semanticLabel,
         semanticHint: semanticHint,
         focusNode: focusNode,
         autofocus: autofocus,
       );

  /// Factory constructor for a destructive warning button.
  const AppButton.destructive({
    required String text,
    Key? key,
    VoidCallback? onPressed,
    AppButtonSize size = AppButtonSize.medium,
    bool isLoading = false,
    bool isEnabled = true,
    Widget? prefixIcon,
    Widget? suffixIcon,
    double? width,
    double? borderRadius,
    String? semanticLabel,
    String? semanticHint,
    FocusNode? focusNode,
    bool autofocus = false,
  }) : this(
         key: key,
         text: text,
         onPressed: onPressed,
         variant: AppButtonVariant.destructive,
         size: size,
         isLoading: isLoading,
         isEnabled: isEnabled,
         prefixIcon: prefixIcon,
         suffixIcon: suffixIcon,
         width: width,
         borderRadius: borderRadius,
         semanticLabel: semanticLabel,
         semanticHint: semanticHint,
         focusNode: focusNode,
         autofocus: autofocus,
       );

  final String text;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool isLoading;
  final bool isEnabled;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final double? width;
  final double? borderRadius;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? borderColor;
  final TextStyle? textStyle;
  final String? semanticLabel;
  final String? semanticHint;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  late final FocusNode _internalFocusNode;
  bool _isFocused = false;

  FocusNode get _effectiveFocusNode => widget.focusNode ?? _internalFocusNode;

  @override
  void initState() {
    super.initState();
    _internalFocusNode = FocusNode();
    _effectiveFocusNode.addListener(_handleFocusChange);
    if (widget.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _announceLoading());
    }
  }

  @override
  void didUpdateWidget(covariant AppButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading && !oldWidget.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _announceLoading());
    }
  }

  @override
  void dispose() {
    _effectiveFocusNode.removeListener(_handleFocusChange);
    if (widget.focusNode == null) {
      _internalFocusNode.dispose();
    }
    super.dispose();
  }

  void _handleFocusChange() {
    if (mounted) {
      setState(() {
        _isFocused = _effectiveFocusNode.hasFocus;
      });
    }
  }

  Future<void> _announceLoading() async {
    if (!mounted) return;
    final message = context.l10n.loadingAnnouncement;
    // ignore: deprecated_member_use, backward-compatible a11y announcement
    await SemanticsService.announce(
      message,
      TextDirection.ltr,
    );
  }

  bool get _isClickable =>
      widget.isEnabled && !widget.isLoading && widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    final resolvedBg =
        widget.backgroundColor ?? _resolveBackgroundColor(colors);
    final resolvedFg = widget.textColor ?? _resolveForegroundColor(colors);
    final resolvedBorder = widget.borderColor ?? _resolveBorderColor(colors);
    final effectiveRadius = widget.borderRadius ?? 12.0;

    final effectiveTextStyle =
        widget.textStyle ??
        typography.subhead.semiBold.copyWith(
          fontSize: widget.size.fontSize,
          color: resolvedFg,
        );

    final content = AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: widget.isLoading
          ? SizedBox(
              key: const ValueKey('button_loading'),
              width: widget.size.iconSize,
              height: widget.size.iconSize,
              child: CircularProgressIndicator.adaptive(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(resolvedFg),
              ),
            )
          : Row(
              key: const ValueKey('button_content'),
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.prefixIcon != null) ...[
                  ExcludeSemantics(
                    child: IconTheme(
                      data: IconThemeData(
                        color: resolvedFg,
                        size: widget.size.iconSize,
                      ),
                      child: widget.prefixIcon!,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    widget.text,
                    style: effectiveTextStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
                if (widget.suffixIcon != null) ...[
                  const SizedBox(width: 8),
                  ExcludeSemantics(
                    child: IconTheme(
                      data: IconThemeData(
                        color: resolvedFg,
                        size: widget.size.iconSize,
                      ),
                      child: widget.suffixIcon!,
                    ),
                  ),
                ],
              ],
            ),
    );

    return Semantics(
      button: true,
      enabled: _isClickable,
      label: widget.semanticLabel ?? widget.text,
      hint: widget.semanticHint,
      focusable: true,
      focused: _isFocused,
      child: ShrinkableButton(
        focusNode: _effectiveFocusNode,
        autofocus: widget.autofocus,
        onTap: _isClickable ? widget.onPressed : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: widget.width,
          height: widget.size.height,
          constraints: const BoxConstraints(
            minWidth: 48,
            minHeight: 48,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: widget.size.horizontalPadding,
          ),
          decoration: BoxDecoration(
            color: _isClickable
                ? resolvedBg
                : resolvedBg.withAlpha((255 * 0.5).round()),
            borderRadius: BorderRadius.circular(effectiveRadius),
            border: Border.all(
              color: _isFocused
                  ? colors.primary
                  : (resolvedBorder ?? colors.transparent),
              width: _isFocused ? 2.0 : 1.0,
            ),
          ),
          alignment: Alignment.center,
          child: content,
        ),
      ),
    );
  }

  Color _resolveBackgroundColor(AppThemeColorsExtension colors) {
    switch (widget.variant) {
      case AppButtonVariant.primary:
        return colors.primary;
      case AppButtonVariant.secondary:
        return colors.surfaceSecondary;
      case AppButtonVariant.outline:
      case AppButtonVariant.ghost:
        return colors.transparent;
      case AppButtonVariant.destructive:
        return colors.error;
    }
  }

  Color _resolveForegroundColor(AppThemeColorsExtension colors) {
    switch (widget.variant) {
      case AppButtonVariant.primary:
      case AppButtonVariant.destructive:
        return colors.white;
      case AppButtonVariant.secondary:
        return colors.textPrimary;
      case AppButtonVariant.outline:
      case AppButtonVariant.ghost:
        return colors.primary;
    }
  }

  Color? _resolveBorderColor(AppThemeColorsExtension colors) {
    switch (widget.variant) {
      case AppButtonVariant.outline:
        return colors.surfaceBorder;
      case AppButtonVariant.primary:
      case AppButtonVariant.secondary:
      case AppButtonVariant.ghost:
      case AppButtonVariant.destructive:
        return null;
    }
  }
}
