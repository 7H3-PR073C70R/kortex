import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/community/domain/services/content_moderation_service.dart';

/// Modal dialog that presents moderation feedback in an informative, educational manner
/// so users understand community guidelines and can easily fix their posts or replies.
class ModerationFeedbackDialog extends StatelessWidget {
  const ModerationFeedbackDialog({
    required this.result,
    this.contentTarget = 'submission',
    super.key,
  });

  final ModerationResult result;
  final String contentTarget;

  static Future<void> show(
    BuildContext context, {
    required ModerationResult result,
    String contentTarget = 'submission',
  }) async {
    unawaited(HapticFeedback.mediumImpact());
    return showDialog<void>(
      context: context,
      builder: (ctx) => ModerationFeedbackDialog(
        result: result,
        contentTarget: contentTarget,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final (icon, headerTitle) = switch (result.category) {
      ModerationCategory.profanity => (
        Icons.record_voice_over_outlined,
        'Respectful Communication',
      ),
      ModerationCategory.commercialSpam ||
      ModerationCategory.educationalPurpose => (
        Icons.school_outlined,
        'Academic Purpose Required',
      ),
      ModerationCategory.personalContact => (
        Icons.privacy_tip_outlined,
        'Privacy Protection',
      ),
      ModerationCategory.maliciousScript => (
        Icons.security_rounded,
        'Security Policy',
      ),
      ModerationCategory.lowQualityOrGibberish ||
      ModerationCategory.lengthConstraint ||
      null => (
        Icons.help_outline_rounded,
        'Educational Guidelines',
      ),
    };

    return AlertDialog(
      backgroundColor: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.dialog),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.error.withAlpha(isDark ? 35 : 20),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: colors.error,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              headerTitle,
              style: typography.title3.bold.copyWith(
                color: colors.textPrimary,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.reason ??
                'Your $contentTarget could not be accepted because it does not meet our educational community standards.',
            style: typography.body.regular.copyWith(
              color: colors.textPrimary,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          if (result.suggestion != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.primary.withAlpha(isDark ? 20 : 10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: colors.primary.withAlpha(isDark ? 40 : 25),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 16,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      result.suggestion!,
                      style: typography.caption.medium.copyWith(
                        color: colors.textSecondary,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 10,
            ),
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Review & Edit'),
        ),
      ],
    );
  }
}
