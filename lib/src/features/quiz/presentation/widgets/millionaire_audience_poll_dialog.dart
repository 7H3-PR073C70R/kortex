import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/quiz_shell.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Modal dialog showing how the room would answer, for Millionaire Mode.
class MillionaireAudiencePollDialog extends StatelessWidget {
  const MillionaireAudiencePollDialog({
    required this.distribution,
    required this.options,
    required this.onClose,
    super.key,
  });

  final Map<String, int> distribution;
  final List<String> options;
  final VoidCallback onClose;

  static void show(
    BuildContext context, {
    required Map<String, int> distribution,
    required List<String> options,
  }) {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (dialogContext) => MillionaireAudiencePollDialog(
          distribution: distribution,
          options: options,
          onClose: () => Navigator.of(dialogContext).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final reduceMotion = quizReduceMotion(context);

    const optionLetters = ['A', 'B', 'C', 'D'];

    // Find the highest voted option
    var maxPercentage = -1;
    var maxLetter = '';
    for (final entry in distribution.entries) {
      if (entry.value > maxPercentage) {
        maxPercentage = entry.value;
        maxLetter = entry.key;
      }
    }

    return Dialog(
      backgroundColor: colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? colors.backgroundPrimary : colors.surfacePrimary,
          borderRadius: BorderRadius.circular(AppRadius.dialog),
          border: Border.all(
            color: colors.surfaceBorder,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.black.withAlpha(isDark ? 50 : 15),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [colors.primary, colors.primary.withAlpha(200)],
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    boxShadow: [
                      BoxShadow(
                        color: colors.black.withValues(
                          alpha: isDark ? 0.35 : 0.12,
                        ),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.groups_rounded,
                    color: colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'What the studio thinks',
                        style: typography.headline.bold.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        'How the room would answer',
                        style: typography.footnote.regular.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: Icon(
                    Icons.close_rounded,
                    color: colors.textMuted,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Distribution Bars
            ...List.generate(options.length, (i) {
              final letter = i < optionLetters.length
                  ? optionLetters[i]
                  : '${i + 1}';
              final pct = distribution[letter] ?? 0;
              final isMax = letter == maxLetter;
              final label = options[i];

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isMax
                                ? colors.success
                                : colors.surfaceSecondary,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            letter,
                            style: typography.caption.bold.copyWith(
                              color: isMax ? colors.white : colors.textPrimary,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: typography.footnote.medium.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$pct%',
                          style: typography.footnote.bold.copyWith(
                            color: isMax
                                ? colors.success
                                : colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.micro),
                      child: Stack(
                        children: [
                          Container(
                            height: 10,
                            width: double.infinity,
                            color: colors.surfaceSecondary,
                          ),
                          // Bars grow from zero, one after another, so the
                          // room "tallies" in front of the player.
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: reduceMotion
                                ? Duration.zero
                                : AppMotion.expressive +
                                      AppMotion.staggerDelay * i,
                            curve: AppMotion.easeOutCubic,
                            builder: (context, t, _) => FractionallySizedBox(
                              widthFactor: (pct / 100.0 * t).clamp(0.0, 1.0),
                              child: Container(
                                height: 10,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isMax
                                        ? [
                                            colors.success,
                                            colors.success.withAlpha(200),
                                          ]
                                        : [
                                            colors.primary,
                                            colors.primary.withAlpha(200),
                                          ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colors.warning.withValues(alpha: isDark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(AppRadius.badge),
                border: Border.all(
                  color: colors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.tips_and_updates_rounded,
                    color: colors.warning,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'The room is guessing too. Trust your own reasoning '
                      'first.',
                      style: typography.caption.regular.copyWith(
                        color: colors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Action Button
            ShrinkableButton(
              onTap: onClose,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: Text(
                  'Back to the question',
                  style: typography.headline.bold.copyWith(
                    color: colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
