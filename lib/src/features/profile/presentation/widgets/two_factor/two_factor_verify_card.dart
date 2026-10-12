import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/shared/widgets/app_logo_loader.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Step 3 card for entering the 6-digit code and triggering verification.
class TwoFactorVerifyCard extends StatelessWidget {
  const TwoFactorVerifyCard({
    required this.codeController,
    required this.isVerifying,
    required this.onVerify,
    super.key,
  });

  final TextEditingController codeController;
  final bool isVerifying;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colors.surfaceSecondary,
            borderRadius: AppRadius.radiusDialog,
            border: Border.all(
              color: colors.surfaceBorder.withAlpha(90),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '3',
                        style: typography.caption.bold.copyWith(
                          color: colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Enter 6-Digit Code from Authenticator',
                      style: typography.body.bold.copyWith(
                        color: colors.textPrimary,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: codeController,
                hintText: '123456',
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Verify & Enable Action Button
        PlatformHoverBuilder(
          builder: (context, isHovered, child) {
            return AnimatedScale(
              scale: isHovered ? 1.02 : 1.0,
              duration: AppMotion.snappy,
              curve: Curves.easeOutCubic,
              child: child,
            );
          },
          child: ShrinkableButton(
            onTap: isVerifying ? () {} : onVerify,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colors.primary,
                    colors.syllabotAccent,
                  ],
                ),
                borderRadius: AppRadius.radiusPanel,
                boxShadow: [
                  BoxShadow(
                    color: colors.black.withAlpha(
                      isDark ? 60 : 25,
                    ),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: isVerifying
                    ? AppLogoLoader(
                        size: 20,
                        color: colors.white,
                        showMessage: false,
                      )
                    : Text(
                        'Verify & Enable 2FA',
                        style: typography.body.bold.copyWith(
                          color: colors.white,
                          fontSize: 15,
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
