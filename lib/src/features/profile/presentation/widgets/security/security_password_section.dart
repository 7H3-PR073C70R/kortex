import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/features/profile/presentation/widgets/security/security_section_container.dart';
import 'package:kortex/src/shared/widgets/app_logo_loader.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Password change and authentication section.
class SecurityPasswordSection extends StatelessWidget {
  const SecurityPasswordSection({
    required this.currentPasswordController,
    required this.newPasswordController,
    required this.confirmPasswordController,
    required this.hasMinLength,
    required this.hasNumber,
    required this.hasSpecial,
    required this.isUpdatingPassword,
    required this.onUpdatePassword,
    required this.onSendResetEmail,
    super.key,
  });

  final TextEditingController currentPasswordController;
  final TextEditingController newPasswordController;
  final TextEditingController confirmPasswordController;
  final bool hasMinLength;
  final bool hasNumber;
  final bool hasSpecial;
  final bool isUpdatingPassword;
  final VoidCallback onUpdatePassword;
  final VoidCallback onSendResetEmail;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return SecuritySectionContainer(
      title: 'Password & Authentication',
      subtitle: 'Update your account password or request a reset link',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(
            controller: currentPasswordController,
            hintText: 'Current Password',
            isPassword: true,
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: newPasswordController,
            hintText: 'New Password (min. 8 characters)',
            isPassword: true,
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: confirmPasswordController,
            hintText: 'Confirm New Password',
            isPassword: true,
          ),
          const SizedBox(height: 12),

          // Password Strength Indicators
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildStrengthTag(
                label: '8+ Chars',
                isValid: hasMinLength,
                colors: colors,
                typography: typography,
              ),
              _buildStrengthTag(
                label: 'Number (0-9)',
                isValid: hasNumber,
                colors: colors,
                typography: typography,
              ),
              _buildStrengthTag(
                label: 'Special Symbol',
                isValid: hasSpecial,
                colors: colors,
                typography: typography,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: PlatformHoverBuilder(
                  builder: (context, isHovered, child) {
                    return AnimatedScale(
                      scale: isHovered ? 1.02 : 1.0,
                      duration: AppMotion.snappy,
                      curve: Curves.easeOutCubic,
                      child: child,
                    );
                  },
                  child: ShrinkableButton(
                    onTap: onUpdatePassword,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: AppRadius.radiusCard,
                      ),
                      child: Center(
                        child: isUpdatingPassword
                            ? AppLogoLoader(
                                size: 18,
                                color: colors.white,
                                showMessage: false,
                              )
                            : Text(
                                'Update Password',
                                style: typography.caption.bold.copyWith(
                                  color: colors.white,
                                  fontSize: 13,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
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
                  onTap: onSendResetEmail,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfacePrimary,
                      borderRadius: AppRadius.radiusCard,
                      border: Border.all(
                        color: colors.surfaceBorder.withAlpha(90),
                      ),
                    ),
                    child: Text(
                      'Send Reset Email',
                      style: typography.caption.bold.copyWith(
                        color: colors.textPrimary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStrengthTag({
    required String label,
    required bool isValid,
    required AppThemeColorsExtension colors,
    required TypographyThemeExtension typography,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isValid ? colors.success.withAlpha(25) : colors.surfacePrimary,
        borderRadius: AppRadius.radiusBadge,
        border: Border.all(
          color: isValid
              ? colors.success.withAlpha(90)
              : colors.surfaceBorder.withAlpha(80),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isValid
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 13,
            color: isValid
                ? colors.success
                : colors.textSecondary.withAlpha(120),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: typography.caption.bold.copyWith(
              color: isValid ? colors.success : colors.textSecondary,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}
