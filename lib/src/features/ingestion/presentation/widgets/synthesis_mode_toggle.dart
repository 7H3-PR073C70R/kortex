import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/ingestion/domain/entities/synthesis_mode.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Two-tier hybrid synthesis mode selector (Tier 1: Local vs Tier 2: AI Smart).
class SynthesisModeToggle extends StatelessWidget {
  const SynthesisModeToggle({
    required this.currentMode,
    required this.onModeSelected,
    super.key,
  });

  final SynthesisMode currentMode;
  final ValueChanged<SynthesisMode> onModeSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfaceSecondary.withAlpha(160)
            : colors.surfacePrimary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.primary.withAlpha(isDark ? 50 : 25),
        ),
      ),
      child: Row(
        children: [
          // Tier 1: Fast Local Extraction (Default & Free)
          Expanded(
            child: _ModeOptionCard(
              mode: SynthesisMode.fastLocal,
              title: l10n.fastLocalModeTitle,
              badge: l10n.fastLocalModeBadge,
              icon: Icons.flash_on_rounded,
              isSelected: currentMode.isFastLocal,
              onTap: () => onModeSelected(SynthesisMode.fastLocal),
            ),
          ),
          const SizedBox(width: 8),

          // Tier 2: AI Smart Synthesis (Pro / Deep Conceptual)
          Expanded(
            child: _ModeOptionCard(
              mode: SynthesisMode.aiSmart,
              title: l10n.aiSmartModeTitle,
              badge: l10n.aiSmartModeBadge,
              icon: Icons.auto_awesome_rounded,
              isSelected: currentMode.isAiSmart,
              onTap: () => onModeSelected(SynthesisMode.aiSmart),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeOptionCard extends StatelessWidget {
  const _ModeOptionCard({
    required this.mode,
    required this.title,
    required this.badge,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final SynthesisMode mode;
  final String title;
  final String badge;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return ShrinkableButton(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                    ? colors.primary.withAlpha(40)
                    : colors.primary.withAlpha(25))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? colors.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 17,
              color: isSelected ? colors.primary : colors.textSecondary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: typography.caption.bold.copyWith(
                  color: isSelected ? colors.primary : colors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? colors.primary
                    : colors.textSecondary.withAlpha(30),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                badge,
                style: typography.caption.bold.copyWith(
                  fontSize: 9,
                  color: isSelected ? Colors.white : colors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
