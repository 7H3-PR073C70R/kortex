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
    final isFsrs = currentAlgorithm == SpacedRepetitionAlgorithm.fsrs;

    return Semantics(
      container: true,
      label:
          'Spaced Repetition Scheduler Setting: '
          '${isFsrs ? "FSRS-4.5 Engine" : "SM-2 Algorithm"}',
      hint: 'Toggle between classical SM-2 and adaptive FSRS spaced repetition',
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
                // Toggle Button Mode
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      _AlgorithmOptionButton(
                        label: 'SM-2',
                        isSelected: !isFsrs,
                        onTap: () => onChanged(SpacedRepetitionAlgorithm.sm2),
                      ),
                      _AlgorithmOptionButton(
                        label: 'FSRS-4.5',
                        isSelected: isFsrs,
                        onTap: () => onChanged(SpacedRepetitionAlgorithm.fsrs),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              isFsrs ? l10n.fsrsModeDescription : l10n.sm2ModeDescription,
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

class _AlgorithmOptionButton extends StatelessWidget {
  const _AlgorithmOptionButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final colors = context.colors;

    return Semantics(
      button: true,
      selected: isSelected,
      label: 'Select $label Algorithm',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.primary : colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: isSelected
                ? context.typography.caption.bold.copyWith(
                    fontSize: 11,
                    color: colors.white,
                  )
                : context.typography.caption.medium.copyWith(
                    fontSize: 11,
                    color: colors.textSecondary,
                  ),
          ),
        ),
      ),
    );
  }
}
