import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Floating social authentication triggers for instant Google
/// and Apple sign-in with WCAG 2.1 AA compliant semantics and glassmorphism.
class SocialAuthBar extends StatelessWidget {
  const SocialAuthBar({
    required this.onGooglePressed,
    required this.onApplePressed,
    super.key,
    this.isLoading = false,
  });

  final VoidCallback onGooglePressed;
  final VoidCallback onApplePressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    return Row(
      children: [
        // Google Sign In
        Expanded(
          child: Semantics(
            button: true,
            label: l10n.authSocialGoogleSemantics,
            hint: 'Sign in quickly using your connected Google account',
            child: ShrinkableButton(
              onTap: isLoading
                  ? null
                  : () {
                      unawaited(HapticFeedback.lightImpact());
                      onGooglePressed();
                    },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: isDark
                          ? colors.surfaceSecondary.withAlpha(180)
                          : colors.surfacePrimary.withAlpha(200),
                      border: Border.all(
                        color: isDark
                            ? colors.surfaceBorderHighlight.withAlpha(90)
                            : colors.surfaceBorder.withAlpha(140),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(isDark ? 60 : 15),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.g_mobiledata_rounded,
                          size: 24,
                          color: Colors.blueAccent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Google',
                          style: typography.callout.bold.copyWith(
                            color: colors.textPrimary,
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Apple ID Sign In
        Expanded(
          child: Semantics(
            button: true,
            label: l10n.authSocialAppleSemantics,
            hint: 'Sign in quickly using your Apple ID',
            child: ShrinkableButton(
              onTap: isLoading
                  ? null
                  : () {
                      unawaited(HapticFeedback.lightImpact());
                      onApplePressed();
                    },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: isDark
                          ? colors.surfaceSecondary.withAlpha(180)
                          : colors.surfacePrimary.withAlpha(200),
                      border: Border.all(
                        color: isDark
                            ? colors.surfaceBorderHighlight.withAlpha(90)
                            : colors.surfaceBorder.withAlpha(140),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(isDark ? 60 : 15),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.apple,
                          size: 20,
                          color: colors.textPrimary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Apple',
                          style: typography.callout.bold.copyWith(
                            color: colors.textPrimary,
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
