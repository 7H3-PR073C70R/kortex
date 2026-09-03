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
    final l10n = context.l10n;

    final freezeLabel = hasStreakFreeze
        ? l10n.streakFreezeAvailable
        : l10n.streakFreezeActiveDesc;

    final topGradientColor = hasStreakFreeze
        ? Colors.cyanAccent.withValues(alpha: 0.15)
        : Colors.orangeAccent.withValues(alpha: 0.15);

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
                ? Colors.cyanAccent.withValues(alpha: 0.4)
                : Colors.orangeAccent.withValues(alpha: 0.3),
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
                    color: Colors.orangeAccent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.local_fire_department_rounded,
                    color: Colors.orangeAccent,
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
                              color: Colors.white,
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
                                color: Colors.cyanAccent.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.cyanAccent.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                              child: const Text(
                                'SHIELD ACTIVE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.cyanAccent,
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
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!hasStreakFreeze && onPurchaseFreeze != null) ...[
              const SizedBox(height: 14),
              const Divider(height: 1, color: Colors.white12),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(
                    Icons.shield_rounded,
                    color: Colors.cyanAccent,
                    size: 18,
                  ),
                  label: Text(
                    l10n.buyStreakFreezeButton,
                    style: const TextStyle(
                      color: Colors.cyanAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: Colors.cyanAccent.withValues(alpha: 0.5),
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
