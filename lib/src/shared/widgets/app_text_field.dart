import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/l10n/l10n.dart';

/// Production-ready accessible text input field matching WCAG 2.1 AA.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.initialValue,
    this.focusNode,
    this.label,
    this.hintText,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.isPassword = false,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.style,
    this.textAlign = TextAlign.start,
    this.autofocus = false,
    this.readOnly = false,
    this.enabled = true,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.onChanged,
    this.onTap,
    this.onEditingComplete,
    this.onFieldSubmitted,
    this.onSaved,
    this.validator,
    this.inputFormatters,
    this.autovalidateMode,
    this.contentPadding,
    this.borderRadius,
    this.fillColor,
    this.semanticLabel,
    this.semanticHint,
  });

  final TextEditingController? controller;
  final String? initialValue;
  final FocusNode? focusNode;
  final String? label;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool isPassword;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final TextStyle? style;
  final TextAlign textAlign;
  final bool autofocus;
  final bool readOnly;
  final bool enabled;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final GestureTapCallback? onTap;
  final VoidCallback? onEditingComplete;
  final ValueChanged<String>? onFieldSubmitted;
  final FormFieldSetter<String>? onSaved;
  final FormFieldValidator<String>? validator;
  final List<TextInputFormatter>? inputFormatters;
  final AutovalidateMode? autovalidateMode;
  final EdgeInsetsGeometry? contentPadding;
  final double? borderRadius;
  final Color? fillColor;
  final String? semanticLabel;
  final String? semanticHint;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscureText;
  late final FocusNode _internalFocusNode;
  bool _isFocused = false;

  FocusNode get _effectiveFocusNode => widget.focusNode ?? _internalFocusNode;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.isPassword;
    _internalFocusNode = FocusNode();
    _effectiveFocusNode.addListener(_handleFocusChange);
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

  void _toggleObscureText() {
    setState(() {
      _obscureText = !_obscureText;
    });
    final l10n = context.l10n;
    final message = _obscureText ? l10n.passwordHidden : l10n.passwordVisible;
    unawaited(
      // ignore: deprecated_member_use, backward-compatible a11y announcement
      SemanticsService.announce(
        message,
        TextDirection.ltr,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final effectiveRadius = widget.borderRadius ?? 12.0;

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(effectiveRadius),
      borderSide: BorderSide(color: colors.surfaceBorder),
    );

    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(effectiveRadius),
      borderSide: BorderSide(
        color: colors.primary,
        width: 1.5,
      ),
    );

    final errorBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(effectiveRadius),
      borderSide: BorderSide(
        color: colors.error,
      ),
    );

    final focusedErrorBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(effectiveRadius),
      borderSide: BorderSide(
        color: colors.error,
        width: 1.5,
      ),
    );

    Widget? effectiveSuffix;
    if (widget.isPassword) {
      final buttonLabel =
          _obscureText ? l10n.showPassword : l10n.hidePassword;
      effectiveSuffix = Semantics(
        button: true,
        label: buttonLabel,
        child: SizedBox(
          width: 48,
          height: 48,
          child: IconButton(
            icon: Icon(
              _obscureText
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: _isFocused ? colors.primary : colors.textMuted,
              size: 20,
            ),
            onPressed: _toggleObscureText,
            splashRadius: 20,
            tooltip: buttonLabel,
          ),
        ),
      );
    } else if (widget.suffixIcon != null) {
      effectiveSuffix = ExcludeSemantics(
        child: widget.suffixIcon,
      );
    }

    final field = TextFormField(
      controller: widget.controller,
      initialValue: widget.initialValue,
      focusNode: _effectiveFocusNode,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      textCapitalization: widget.textCapitalization,
      style: widget.style ??
          typography.body.regular.copyWith(
            color: colors.textPrimary,
            fontSize: 15,
          ),
      textAlign: widget.textAlign,
      autofocus: widget.autofocus,
      readOnly: widget.readOnly,
      enabled: widget.enabled,
      obscureText: _obscureText,
      maxLines: widget.isPassword ? 1 : widget.maxLines,
      minLines: widget.minLines,
      maxLength: widget.maxLength,
      onChanged: widget.onChanged,
      onTap: widget.onTap,
      onEditingComplete: widget.onEditingComplete,
      onFieldSubmitted: widget.onFieldSubmitted,
      onSaved: widget.onSaved,
      validator: widget.validator,
      inputFormatters: widget.inputFormatters,
      autovalidateMode: widget.autovalidateMode,
      cursorColor: colors.primary,
      decoration: InputDecoration(
        hintText: widget.hintText,
        helperText: widget.helperText,
        errorText: widget.errorText,
        filled: true,
        fillColor: widget.fillColor ??
            (widget.enabled
                ? colors.surfaceSecondary
                : colors.surfaceSecondary.withAlpha((255 * 0.5).round())),
        contentPadding: widget.contentPadding ??
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        prefixIcon: widget.prefixIcon != null
            ? ExcludeSemantics(
                child: IconTheme(
                  data: IconThemeData(
                    color: _isFocused ? colors.primary : colors.textMuted,
                    size: 20,
                  ),
                  child: widget.prefixIcon!,
                ),
              )
            : null,
        suffixIcon: effectiveSuffix,
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: focusedBorder,
        errorBorder: errorBorder,
        focusedErrorBorder: focusedErrorBorder,
        hintStyle: typography.callout.regular.copyWith(
          color: colors.textMuted,
        ),
        helperStyle: typography.caption.regular.copyWith(
          color: colors.textMuted,
        ),
        errorStyle: typography.caption.regular.copyWith(
          color: colors.error,
        ),
      ),
    );

    final semanticWrapper = Semantics(
      textField: true,
      label: widget.semanticLabel ?? widget.label ?? widget.hintText,
      hint: widget.semanticHint ?? widget.helperText,
      value: widget.controller?.text,
      obscured: _obscureText,
      enabled: widget.enabled,
      child: field,
    );

    if (widget.label != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Text(
              widget.label!,
              style: typography.subhead.medium.copyWith(
                color: colors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 6),
          semanticWrapper,
        ],
      );
    }

    return semanticWrapper;
  }
}
