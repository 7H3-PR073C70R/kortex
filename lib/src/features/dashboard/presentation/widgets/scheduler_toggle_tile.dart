import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/decks/domain/logic/scheduler_factory.dart';
import 'package:kortex/src/l10n/l10n.dart';

class SchedulerToggleTile extends StatelessWidget {
  const SchedulerToggleTile({
    required this.currentAlgorithm,
    required this.onChanged,
    super.key,
  });

  final SpacedRepetitionAlgorithm currentAlgorithm;
  final ValueChanged<SpacedRepetitionAlgorithm> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final colors = context.colors;
    final l10n = context.l10n;

    return Semantics(
      container: true,
      label: 'Spaced Repetition Scheduler: FSRS-6 Neural Engine Active',
      hint: 'Kortex uses the FSRS-6 21-parameter adaptive neural spaced repetition algorithm',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colors.surfaceBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.auto_graph_rounded,
                      color: theme.colorScheme.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      l10n.schedulerAlgorithmTitle,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
                // FSRS-6 Active Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withAlpha(context.isDarkMode ? 50 : 25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colors.primary.withAlpha(100),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.success,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'FSRS-6',
                        style: context.typography.caption.bold.copyWith(
                          fontSize: 11,
                          color: colors.primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Adaptive 21-parameter neural scheduling with personalized forgetting curve modeling for optimal retention.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
