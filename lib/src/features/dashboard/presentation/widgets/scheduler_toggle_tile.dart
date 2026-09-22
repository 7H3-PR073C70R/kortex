import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/decks/domain/logic/scheduler_factory.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

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
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    return Semantics(
      container: true,
      label: 'Spaced Repetition Scheduler: FSRS-6 Neural Engine Active',
      hint:
          'Kortex uses the FSRS-6 21-parameter adaptive neural spaced repetition algorithm',
      child: PlatformHoverBuilder(
        builder: (context, isHovered, child) {
          return ShrinkableButton(
            onTap: () {
              onChanged(currentAlgorithm);
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? colors.surfaceSecondary.withAlpha(160)
                    : colors.surfacePrimary.withAlpha(220),
                borderRadius: BorderRadius.circular(AppRadius.panel),
                border: Border.all(
                  color: colors.surfaceBorder.withAlpha(isDark ? 60 : 35),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.auto_graph_rounded,
                              color: colors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l10n.schedulerAlgorithmTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: typography.body.bold.copyWith(
                                  color: colors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // FSRS-6 Active Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary.withAlpha(isDark ? 50 : 25),
                          borderRadius: BorderRadius.circular(AppRadius.badge),
                          border: Border.all(
                            color: colors.primary.withAlpha(isDark ? 90 : 50),
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
                              style: typography.caption.bold.copyWith(
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
                  const SizedBox(height: 8),
                  Text(
                    l10n.fsrsModeDescription,
                    style: typography.footnote.regular.copyWith(
                      color: colors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
