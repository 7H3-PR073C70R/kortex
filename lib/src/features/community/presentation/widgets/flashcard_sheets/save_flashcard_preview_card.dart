import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';

/// Interactive card side preview item (Front or Back).
class SaveFlashcardCardSide extends StatelessWidget {
  const SaveFlashcardCardSide({
    required this.label,
    required this.content,
    required this.icon,
    required this.colors,
    required this.typography,
    this.maxLines = 2,
    super.key,
  });

  final String label;
  final String content;
  final IconData icon;
  final AppThemeColorsExtension colors;
  final TypographyThemeExtension typography;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: colors.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: typography.caption.bold.copyWith(
                  color: colors.textSecondary,
                  fontSize: 10,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                content,
                style: typography.body.regular.copyWith(
                  color: colors.textPrimary,
                  fontSize: 13,
                  height: 1.4,
                ),
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Container previewing both front and back sides of the prospective card.
class SaveFlashcardCardPreview extends StatelessWidget {
  const SaveFlashcardCardPreview({
    required this.frontText,
    required this.backText,
    super.key,
  });

  final String frontText;
  final String backText;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfacePrimary.withValues(alpha: 0.6)
            : colors.surfaceSecondary.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SaveFlashcardCardSide(
            label: 'Front',
            content: frontText,
            icon: Icons.lightbulb_outline_rounded,
            colors: colors,
            typography: typography,
          ),
          Divider(
            height: 20,
            color: colors.surfaceBorder.withValues(alpha: 0.4),
          ),
          SaveFlashcardCardSide(
            label: 'Back',
            content: backText,
            icon: Icons.description_outlined,
            colors: colors,
            typography: typography,
            maxLines: 4,
          ),
        ],
      ),
    );
  }
}

/// Empty state illustration when the student has not yet created any decks.
class EmptyDecksHint extends StatelessWidget {
  const EmptyDecksHint({
    required this.colors,
    required this.typography,
    super.key,
  });

  final AppThemeColorsExtension colors;
  final TypographyThemeExtension typography;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceBorder.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colors.surfaceBorder.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 32, color: colors.textSecondary),
          const SizedBox(height: 8),
          Text(
            'No study decks yet',
            style: typography.body.semiBold.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Create a deck first so you can save solutions from the forum.',
            style: typography.caption.regular.copyWith(
              color: colors.textSecondary,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
