import 'package:flutter/material.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';

/// Animated vertical checklist card displaying real-time password requirements
/// inside the chat bubble right below the password prompt message.
class AuthChatPasswordRequirementsCard extends StatelessWidget {
  const AuthChatPasswordRequirementsCard({
    required this.password,
    required this.colors,
    required this.typography,
    required this.isDark,
    super.key,
  });

  final String password;
  final AppThemeColorsExtension colors;
  final TypographyThemeExtension typography;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final hasMinLength = password.length >= 8;
    final hasNumber = RegExp('[0-9]').hasMatch(password);
    final hasUppercase = RegExp('[A-Z]').hasMatch(password);
    final hasSpecial = RegExp(
      r'[!@#$%^&*(),.?":{}|<>/_+\-=\[\]\\;`~]',
    ).hasMatch(password);

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfacePrimary.withAlpha(140)
            : colors.surfaceSecondary.withAlpha(180),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? colors.surfaceBorderHighlight.withAlpha(50)
              : colors.surfaceBorder.withAlpha(100),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AuthChatPasswordRequirementItem(
            isMet: hasMinLength,
            label: '8+ characters',
            colors: colors,
            typography: typography,
          ),
          const SizedBox(height: 6),
          AuthChatPasswordRequirementItem(
            isMet: hasNumber,
            label: 'Includes number (0-9)',
            colors: colors,
            typography: typography,
          ),
          const SizedBox(height: 6),
          AuthChatPasswordRequirementItem(
            isMet: hasUppercase,
            label: 'Uppercase letter (A-Z)',
            colors: colors,
            typography: typography,
          ),
          const SizedBox(height: 6),
          AuthChatPasswordRequirementItem(
            isMet: hasSpecial,
            label: 'Special character (!@#...)',
            colors: colors,
            typography: typography,
          ),
        ],
      ),
    );
  }
}

/// Individual requirement row item with a round check animating from an
/// empty circle to a filled circle and label transitioning to success color.
class AuthChatPasswordRequirementItem extends StatelessWidget {
  const AuthChatPasswordRequirementItem({
    required this.isMet,
    required this.label,
    required this.colors,
    required this.typography,
    super.key,
  });

  final bool isMet;
  final String label;
  final AppThemeColorsExtension colors;
  final TypographyThemeExtension typography;

  @override
  Widget build(BuildContext context) {
    final successColor = colors.success;
    final textColor = isMet ? successColor : colors.textMuted;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isMet ? successColor : colors.transparent,
              border: Border.all(
                color: isMet ? successColor : colors.surfaceBorderHighlight,
                width: 1.4,
              ),
            ),
            child: isMet
                ? Center(
                    child: Icon(
                      Icons.check,
                      size: 10,
                      color: colors.white,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 6),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            style: typography.caption.medium.copyWith(
              color: textColor,
              fontSize: 12,
              fontWeight: isMet ? FontWeight.w600 : null,
            ),
            child: Text(label),
          ),
        ],
      ),
    );
  }
}
