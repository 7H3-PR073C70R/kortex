import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/decks/presentation/widgets/session_summary/session_summary_stat_widgets.dart';
import 'package:kortex/src/l10n/l10n.dart';

/// Header section for SessionSummaryPage displaying the celebration orb,
/// summary titles, streak bonus, and key performance metric cards.
class SessionSummaryHeaderSection extends StatelessWidget {
  const SessionSummaryHeaderSection({
    required this.cardsReviewed,
    required this.scorePercent,
    required this.durationFormatted,
    required this.celebrate,
    required this.isMastery,
    required this.summaryTitle,
    required this.reduceMotion,
    super.key,
  });

  final int cardsReviewed;
  final int scorePercent;
  final String durationFormatted;
  final bool celebrate;
  final bool isMastery;
  final String summaryTitle;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    return Column(
      children: [
        const SizedBox(height: 12),
        OrbEntrance(
          reduceMotion: reduceMotion,
          child: Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: celebrate
                    ? [colors.success, colors.syllabotAccent]
                    : [
                        colors.primary.withAlpha(isDark ? 170 : 140),
                        colors.syllabotAccent.withAlpha(isDark ? 170 : 140),
                      ],
              ),
              boxShadow: [
                BoxShadow(
                  color: (celebrate ? colors.success : colors.primary)
                      .withAlpha(isDark ? 70 : 35),
                  blurRadius: celebrate ? 28 : 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              celebrate
                  ? (isMastery
                      ? Icons.emoji_events_rounded
                      : Icons.check_rounded)
                  : Icons.task_alt_rounded,
              color: colors.white,
              size: 48,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          summaryTitle,
          textAlign: TextAlign.center,
          style: typography.title2.bold.copyWith(
            color: colors.textPrimary,
            fontSize: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.sessionSummarySubtitle,
          textAlign: TextAlign.center,
          style: typography.footnote.regular.copyWith(
            color: colors.textSecondary,
            fontSize: 13,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: colors.warning.withAlpha(isDark ? 45 : 20),
            borderRadius: BorderRadius.circular(AppRadius.badge),
            border: Border.all(
              color: colors.warning.withAlpha(120),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.local_fire_department_rounded,
                color: colors.warning,
                size: 18,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  l10n.sessionSummaryStreakBonus(50),
                  textAlign: TextAlign.center,
                  style: typography.caption.bold.copyWith(
                    color: colors.warning,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark
                ? colors.surfaceSecondary.withAlpha(160)
                : colors.surfacePrimary,
            borderRadius: BorderRadius.circular(AppRadius.dialog),
            border: Border.all(
              color: isDark
                  ? colors.surfaceBorderHighlight.withAlpha(70)
                  : colors.surfaceBorder.withAlpha(130),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: SessionStatItem(
                  label: l10n.sessionSummaryCardsReviewed,
                  countTo: cardsReviewed,
                  format: (value) => '$value',
                  color: colors.primary,
                  colors: colors,
                  reduceMotion: reduceMotion,
                  staggerIndex: 0,
                ),
              ),
              Container(
                width: 1,
                height: 36,
                color: colors.surfaceBorder,
              ),
              Expanded(
                child: SessionStatItem(
                  label: l10n.sessionSummaryRetentionRate,
                  countTo: scorePercent,
                  format: (value) => '$value%',
                  color: colors.success,
                  colors: colors,
                  reduceMotion: reduceMotion,
                  staggerIndex: 1,
                ),
              ),
              Container(
                width: 1,
                height: 36,
                color: colors.surfaceBorder,
              ),
              Expanded(
                child: SessionStatItem(
                  label: l10n.sessionSummaryTimeSpent,
                  display: durationFormatted,
                  color: colors.syllabotAccent,
                  colors: colors,
                  reduceMotion: reduceMotion,
                  staggerIndex: 2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
