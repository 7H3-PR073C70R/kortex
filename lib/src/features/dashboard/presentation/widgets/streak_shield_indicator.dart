import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/l10n/l10n.dart';

class StreakShieldIndicator extends StatelessWidget {
  const StreakShieldIndicator({
    required this.streakDays,
    required this.hasStreakFreeze,
    required this.userXp,
    this.onPurchaseFreeze,
    super.key,
  });

  final int streakDays;
  final bool hasStreakFreeze;
  final int userXp;
  final VoidCallback? onPurchaseFreeze;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;

    final freezeLabel = hasStreakFreeze
        ? l10n.streakFreezeAvailable
        : l10n.streakFreezeActiveDesc;

    final topGradientColor = hasStreakFreeze
        ? colors.info.withValues(alpha: 0.15)
        : colors.warning.withValues(alpha: 0.15);

    return Semantics(
      container: true,
      label: 'Daily Streak: $streakDays days. $freezeLabel',
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              topGradientColor,
              theme.colorScheme.surface.withValues(alpha: 0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: hasStreakFreeze
                ? colors.info.withValues(alpha: 0.4)
                : colors.warning.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Flame & Streak Count
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.warning.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.local_fire_department_rounded,
                    color: colors.warning,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '$streakDays Days Streak',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                          ),
                          if (hasStreakFreeze) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colors.info.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: colors.info.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                              child: Text(
                                'SHIELD ACTIVE',
                                style: typography.caption.bold.copyWith(
                                  fontSize: 10,
                                  color: colors.info,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasStreakFreeze
                            ? l10n.streakFreezeActiveDesc
                            : 'Study daily to build momentum and earn XP!',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!hasStreakFreeze && onPurchaseFreeze != null) ...[
              const SizedBox(height: 14),
              Divider(height: 1, color: colors.surfaceBorder),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: Icon(
                    Icons.shield_rounded,
                    color: colors.info,
                    size: 18,
                  ),
                  label: Text(
                    l10n.buyStreakFreezeButton,
                    style: typography.body.bold.copyWith(
                      color: colors.info,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: colors.info.withValues(alpha: 0.5),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: onPurchaseFreeze,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
