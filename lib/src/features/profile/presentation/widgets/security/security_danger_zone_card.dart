import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Danger Zone card for permanently deleting an account and purging study data.
class SecurityDangerZoneCard extends StatelessWidget {
  const SecurityDangerZoneCard({
    required this.onDeleteAccount,
    super.key,
  });

  final VoidCallback onDeleteAccount;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.error.withAlpha(isDark ? 25 : 12),
        borderRadius: AppRadius.radiusDialog,
        border: Border.all(
          color: colors.error.withAlpha(isDark ? 90 : 60),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Danger Zone',
            style: typography.body.bold.copyWith(
              color: colors.error,
              fontSize: 14.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Permanently delete your account, synced flashcard '
            'decks, and Syllabot conversation history.',
            style: typography.caption.regular.copyWith(
              color: colors.textSecondary,
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 14),
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
              onTap: () => showDeleteAccountDialog(
                context: context,
                onConfirmDelete: onDeleteAccount,
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: colors.error,
                  borderRadius: AppRadius.radiusCard,
                ),
                child: Center(
                  child: Text(
                    'Delete Account & Purge Data',
                    style: typography.caption.bold.copyWith(
                      color: colors.white,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void showDeleteAccountDialog({
    required BuildContext context,
    required VoidCallback onConfirmDelete,
  }) {
    final colors = context.colors;
    final typography = context.typography;

    AppFeedback.heavy();
    unawaited(
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: colors.surfaceSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.radiusDialog,
          ),
          title: Text(
            'Delete Account Permanently?',
            style: typography.title3.bold.copyWith(
              color: colors.error,
            ),
          ),
          content: Text(
            'This action is irreversible. All your study streak data, '
            'flashcard decks, and AI notes will be completely purged from '
            'our servers.',
            style: typography.body.regular.copyWith(
              color: colors.textSecondary,
              fontSize: 13,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'Cancel',
                style: typography.body.regular.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                onConfirmDelete();
              },
              child: Text(
                'Delete Forever',
                style: typography.body.regular.copyWith(
                  color: colors.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
