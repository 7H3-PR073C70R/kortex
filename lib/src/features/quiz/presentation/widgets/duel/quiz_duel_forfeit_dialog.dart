import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';

/// Confirmation dialog presented when a user attempts to leave an active quiz duel in progress.
class QuizDuelForfeitDialog {
  QuizDuelForfeitDialog._();

  /// Prompts the user to confirm forfeiting the ongoing duel.
  /// Returns `true` if the user confirms leaving and forfeiting.
  static Future<bool> show(BuildContext context) async {
    final colors = context.colors;
    final typography = context.typography;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.dialog),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: colors.warning, size: 24),
            const SizedBox(width: 8),
            Text('Leave Quiz Duel?', style: typography.title3.bold),
          ],
        ),
        content: Text(
          'Are you sure you want to forfeit? Leaving now will award victory to your rival and return you to the dashboard.',
          style: typography.body.regular.copyWith(
            color: colors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Stay in Duel',
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Leave & Forfeit'),
          ),
        ],
      ),
    );

    return result ?? false;
  }
}
