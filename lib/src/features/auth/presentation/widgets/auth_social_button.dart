import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class AuthSocialButton extends StatelessWidget {
  const AuthSocialButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isLoading = false,
    this.semanticsHint,
    super.key,
  });

  final String label;
  final Widget icon;
  final VoidCallback onTap;
  final bool isLoading;
  final String? semanticsHint;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Semantics(
      label: label,
      hint: semanticsHint,
      button: true,
      enabled: !isLoading,
      child: ShrinkableButton(
        onTap: isLoading
            ? null
            : () {
                unawaited(HapticFeedback.lightImpact());
                onTap();
              },
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colors.primary.withAlpha(isDark ? 40 : 25),
            ),
            boxShadow: [
              BoxShadow(
                color: colors.black.withAlpha(isDark ? 40 : 10),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.primary,
                  ),
                )
              else ...[
                icon,
                const SizedBox(width: 12),
                Text(
                  label,
                  style: typography.body.bold.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
