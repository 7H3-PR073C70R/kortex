import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/features/profile/presentation/widgets/security/security_section_container.dart';
import 'package:kortex/src/shared/widgets/app_dialog.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Account Credentials section showing display name and verified email.
class SecurityAccountCredentialsSection extends StatelessWidget {
  const SecurityAccountCredentialsSection({
    required this.displayName,
    required this.email,
    required this.onSaveDisplayName,
    super.key,
  });

  final String displayName;
  final String email;
  final Future<void> Function(String newName) onSaveDisplayName;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return SecuritySectionContainer(
      title: 'Account Credentials',
      subtitle: 'Your identity across devices and cloud sync',
      child: Column(
        children: [
          _buildAccountRow(
            label: 'Display Name',
            value: displayName,
            actionLabel: 'Edit',
            onAction: () => _showEditNameDialog(context, displayName),
            colors: colors,
            typography: typography,
          ),
          const Divider(height: 20),
          _buildAccountRow(
            label: 'Email Address',
            value: email,
            actionLabel: 'Verified',
            isVerified: true,
            colors: colors,
            typography: typography,
          ),
        ],
      ),
    );
  }

  void _showEditNameDialog(BuildContext context, String currentName) {
    final controller = TextEditingController(text: currentName);
    AppFeedback.selection();
    unawaited(
      AppDialog.show(
        context: context,
        title: 'Edit Display Name',
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: AppTextField(
            controller: controller,
            hintText: 'Enter your scholar alias',
          ),
        ),
        primaryActionText: 'Save',
        onPrimaryAction: () async {
          final newName = controller.text.trim();
          if (newName.isNotEmpty) {
            Navigator.of(context).pop();
            await onSaveDisplayName(newName);
          }
        },
      ),
    );
  }

  Widget _buildAccountRow({
    required String label,
    required String value,
    required String actionLabel,
    required AppThemeColorsExtension colors,
    required TypographyThemeExtension typography,
    VoidCallback? onAction,
    bool isVerified = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: typography.caption.regular.copyWith(
                color: colors.textSecondary,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              value,
              style: typography.body.bold.copyWith(
                color: colors.textPrimary,
                fontSize: 13.5,
              ),
            ),
          ],
        ),
        if (isVerified)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: colors.success.withAlpha(25),
              borderRadius: AppRadius.radiusBadge,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: colors.success,
                  size: 13,
                ),
                const SizedBox(width: 4),
                Text(
                  actionLabel,
                  style: typography.caption.bold.copyWith(
                    color: colors.success,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          )
        else
          ShrinkableButton(
            onTap: onAction ?? () {},
            child: Text(
              actionLabel,
              style: typography.caption.bold.copyWith(
                color: colors.primary,
                fontSize: 12.5,
              ),
            ),
          ),
      ],
    );
  }
}
