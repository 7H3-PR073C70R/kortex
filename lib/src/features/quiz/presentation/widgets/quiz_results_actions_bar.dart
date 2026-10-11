import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';

/// Bottom action bar providing direct options to Retake and Review mistakes/all answers.
class QuizResultsActionsBar extends StatelessWidget {
  const QuizResultsActionsBar({
    required this.canRestart,
    required this.hasMistakesToReview,
    required this.mistakesCount,
    required this.questionsCount,
    required this.onRetake,
    required this.onReviewAction,
    super.key,
  });

  final bool canRestart;
  final bool hasMistakesToReview;
  final int mistakesCount;
  final int questionsCount;
  final VoidCallback onRetake;
  final VoidCallback onReviewAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: isDark ? colors.backgroundPrimary : colors.surfacePrimary,
        border: Border(top: BorderSide(color: colors.surfaceBorder)),
        boxShadow: [
          BoxShadow(
            color: colors.black.withAlpha(isDark ? 30 : 6),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Align(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Row(
              children: [
                if (canRestart) ...[
                  SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      icon: Icon(
                        Icons.replay_rounded,
                        size: 18,
                        color: colors.textPrimary,
                      ),
                      label: Text(
                        'Retake',
                        style: typography.callout.bold.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      onPressed: onRetake,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: colors.surfaceBorderHighlight),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.card),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      icon: Icon(
                        hasMistakesToReview
                            ? Icons.visibility_rounded
                            : Icons.check_circle_rounded,
                        size: 20,
                        color: colors.white,
                      ),
                      label: Text(
                        hasMistakesToReview
                            ? 'Review $mistakesCount ${mistakesCount == 1 ? 'Mistake' : 'Mistakes'}'
                            : (questionsCount > 0
                                ? 'Review All Answers'
                                : 'Back to dashboard'),
                        style: typography.callout.bold.copyWith(
                          color: colors.white,
                        ),
                      ),
                      onPressed: onReviewAction,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.card),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small quick action button for study workflows.
class QuizResultQuickActionButton extends StatelessWidget {
  const QuizResultQuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return InkWell(
      onTap: () {
        unawaited(HapticFeedback.lightImpact());
        onTap();
      },
      borderRadius: AppRadius.radiusCard,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.15 : 0.08),
          borderRadius: AppRadius.radiusCard,
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 6),
            Text(
              label,
              style: typography.caption.bold.copyWith(
                color: colors.textPrimary,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
