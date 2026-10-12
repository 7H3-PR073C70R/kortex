import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/shell/quiz_chrome_primitives.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Small pill used for topic and mode context labels.
class QuizTagPill extends StatelessWidget {
  const QuizTagPill({
    required this.label,
    required this.color,
    this.icon,
    this.maxWidth,
    super.key,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth ?? 220),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(isDark ? 44 : 22),
        borderRadius: BorderRadius.circular(AppRadius.badge),
        border: Border.all(color: color.withAlpha(70)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: typography.caption.bold.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact count readout used in the palette and results headers.
class QuizStatChip extends StatelessWidget {
  const QuizStatChip({
    required this.label,
    required this.value,
    required this.color,
    this.reduceMotion = false,
    this.staggerIndex = 0,
    super.key,
  });

  final String label;
  final String value;
  final Color color;
  final bool reduceMotion;
  final int staggerIndex;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return QuizStaggeredFade(
      reduceMotion: reduceMotion,
      index: staggerIndex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withAlpha(isDark ? 38 : 20),
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: color.withAlpha(70)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: typography.title3.bold.copyWith(color: color),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: typography.caption.regular.copyWith(
                color: colors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact pill used for selecting exam years or filter tags horizontally.
class QuizYearPill extends StatelessWidget {
  const QuizYearPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
    this.badge,
    this.reduceMotion = false,
    super.key,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;
  final String? badge;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return ShrinkableButton(
      onTap: onTap,
      child: AnimatedContainer(
        duration: reduceMotion ? Duration.zero : AppMotion.snappy,
        curve: AppMotion.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.primary
              : (isDark
                    ? colors.surfaceSecondary
                    : colors.surfaceSecondary.withAlpha(120)),
          borderRadius: BorderRadius.circular(AppRadius.panel),
          border: Border.all(
            color: isSelected
                ? colors.primary
                : colors.surfaceBorder.withAlpha(isDark ? 70 : 100),
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13,
                color: isSelected ? colors.white : colors.textSecondary,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: typography.caption.bold.copyWith(
                color: isSelected ? colors.white : colors.textPrimary,
                fontSize: 12,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colors.white.withAlpha(40)
                      : colors.primary.withAlpha(isDark ? 50 : 25),
                  borderRadius: BorderRadius.circular(AppRadius.micro),
                ),
                child: Text(
                  badge!,
                  style: typography.caption.bold.copyWith(
                    color: isSelected ? colors.white : colors.primary,
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Evenly-spaced, responsive question count selector pill.
class QuizCountOptionPill extends StatelessWidget {
  const QuizCountOptionPill({
    required this.count,
    required this.isSelected,
    required this.onTap,
    this.badge,
    this.reduceMotion = false,
    super.key,
  });

  final int count;
  final bool isSelected;
  final VoidCallback onTap;
  final String? badge;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return ShrinkableButton(
      onTap: onTap,
      child: AnimatedContainer(
        duration: reduceMotion ? Duration.zero : AppMotion.snappy,
        curve: AppMotion.easeOutCubic,
        height: 42,
        decoration: BoxDecoration(
          color: isSelected
              ? colors.primary
              : (isDark
                    ? colors.surfaceSecondary
                    : colors.surfaceSecondary.withAlpha(120)),
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: isSelected
                ? colors.primary
                : colors.surfaceBorder.withAlpha(isDark ? 70 : 100),
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$count',
                style: typography.caption.bold.copyWith(
                  color: isSelected ? colors.white : colors.textPrimary,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                ' Qs',
                style: typography.caption.regular.copyWith(
                  color: isSelected
                      ? colors.white.withAlpha(200)
                      : colors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
