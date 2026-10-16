import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/l10n/l10n.dart';

/// Modal dialog shown when free-tier upload exceeds 50MB.
Future<void> show50MbUpgradeDialog(
  BuildContext context, {
  required String filename,
  required int sizeBytes,
}) async {
  final colors = context.colors;
  final typography = context.typography;
  final sizeMb = (sizeBytes / (1024 * 1024)).toStringAsFixed(1);

  await showDialog<void>(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      backgroundColor: context.isDarkMode
          ? colors.surfaceSecondary
          : colors.surfacePrimary,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.radiusDialog,
        side: BorderSide(color: colors.primary.withAlpha(60)),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.error.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.upload_file_rounded,
              color: colors.error,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '50MB Limit Exceeded',
              style: typography.title3.bold.copyWith(
                color: colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        'The selected file "$filename" is $sizeMb MB, which exceeds the 50MB free tier limit.\n\nUpgrade to Kortexify Pro to upload documents up to 200MB with unlimited AI flashcard synthesis.',
        style: typography.callout.regular.copyWith(
          color: colors.textSecondary,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogCtx).pop(),
          child: Text(
            'Dismiss',
            style: context.typography.body.regular.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: colors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.star_rounded, size: 18),
          label: Text(context.l10n.ingestionUpgradeTier),
          onPressed: () {
            Navigator.of(dialogCtx).pop();
            unawaited(
              context.router.push(PaywallRoute()),
            );
          },
        ),
      ],
    ),
  );
}

/// Modal dialog shown when daily free document upload limit (3 uploads/day) is reached.
Future<void> showDailyLimitDialog(BuildContext context) async {
  final colors = context.colors;
  final typography = context.typography;

  await showDialog<void>(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      backgroundColor: context.isDarkMode
          ? colors.surfaceSecondary
          : colors.surfacePrimary,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.radiusDialog,
        side: BorderSide(color: colors.primary.withAlpha(60)),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.warning.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.hourglass_top_rounded,
              color: colors.warning,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Daily Limit Reached',
              style: typography.title3.bold.copyWith(
                color: colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        'You have reached your free daily limit of 3 document uploads.\n\nUpgrade to Kortexify Pro for unlimited document uploads, 200MB file limit, and high-speed cloud AI card generation.',
        style: typography.callout.regular.copyWith(
          color: colors.textSecondary,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogCtx).pop(),
          child: Text(
            'Dismiss',
            style: context.typography.body.regular.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: colors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.star_rounded, size: 18),
          label: Text(context.l10n.ingestionUpgradeTier),
          onPressed: () {
            Navigator.of(dialogCtx).pop();
            unawaited(
              context.router.push(PaywallRoute()),
            );
          },
        ),
      ],
    ),
  );
}
