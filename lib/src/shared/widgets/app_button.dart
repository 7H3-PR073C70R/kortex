import 'dart:io';
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/num_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class AppButton extends StatelessWidget {
  const AppButton({
    required this.text,
    super.key,
    this.onPressed,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
    this.width,
    this.height = 40,
    this.radius = 25,
    this.textStyle,
    this.isBusy = false,
    this.enabled = true,
  });

  final String text;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? borderColor;
  final double? width;
  final double height;
  final double radius;
  final TextStyle? textStyle;
  final bool isBusy;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? context.colors.primary;
    return ShrinkableButton(
      onTap: enabled && !isBusy ? onPressed : null,
      child: Container(
        alignment: Alignment.center,
        width: width ?? double.infinity,
        height: height.height,
        decoration: BoxDecoration(
          border: borderColor == null
              ? null
              : Border.all(
                  color: borderColor!,
                ),
          color: enabled && onPressed != null
              ? bgColor
              : bgColor.withAlpha(
                  (255.0 * .8).round(),
                ),
          borderRadius: BorderRadius.circular(radius.radius),
        ),
        child: isBusy
            ? Platform.isAndroid
                ? CircularProgressIndicator(
                    color: textColor ?? context.colors.white,
                  )
                : Transform.scale(
                    scale: 2.radius,
                    child: CircularProgressIndicator.adaptive(
                      backgroundColor: textColor ?? Colors.white,
                    ),
                  )
            : Text(
                text,
                style: textStyle ??
                    context.textTheme.body.bold.copyWith(
                      fontSize: 14.fontSize,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
              ),
      ),
    );
  }
}
