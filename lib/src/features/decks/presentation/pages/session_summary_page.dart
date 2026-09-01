import 'dart:async';
import 'dart:ui';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';

@RoutePage()
class SessionSummaryPage extends StatelessWidget {
  const SessionSummaryPage({
    required this.deckId,
    required this.cardsReviewed,
    required this.durationSeconds,
    required this.retentionScore,
    super.key,
  });

  final String deckId;
  final int cardsReviewed;
  final int durationSeconds;
  final double retentionScore;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final scorePercent = (retentionScore * 100).toInt();
    final minutes = (durationSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (durationSeconds % 60).toString().padLeft(2, '0');
    final durationFormatted = '$minutes:$seconds';

    return Scaffold(
      backgroundColor:
          isDark ? colors.backgroundPrimary : colors.surfacePrimary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // Celebration Glow Orb
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      colors.success,
                      colors.syllabotAccent,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.success.withAlpha(100),
                      blurRadius: 28,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),

              // Title & Subtitle
              Text(
                l10n.sessionSummaryTitle,
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
              const SizedBox(height: 28),

              // XP & Streak Announcement Pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colors.warning.withAlpha(isDark ? 45 : 20),
                  borderRadius: BorderRadius.circular(16),
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
                    Text(
                      l10n.sessionSummaryStreakBonus(50),
                      style: typography.caption.bold.copyWith(
                        color: colors.warning,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Stats Cards Row
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark
                          ? colors.surfaceSecondary.withAlpha(160)
                          : colors.surfacePrimary.withAlpha(220),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark
                            ? colors.surfaceBorderHighlight.withAlpha(70)
                            : colors.surfaceBorder.withAlpha(130),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StatItem(
                          label: l10n.sessionSummaryCardsReviewed,
                          value: '$cardsReviewed',
                          color: colors.primary,
                          colors: colors,
                        ),
                        Container(
                          width: 1,
                          height: 36,
                          color: colors.surfaceBorder,
                        ),
                        _StatItem(
                          label: l10n.sessionSummaryRetentionRate,
                          value: '$scorePercent%',
                          color: colors.success,
                          colors: colors,
                        ),
                        Container(
                          width: 1,
                          height: 36,
                          color: colors.surfaceBorder,
                        ),
                        _StatItem(
                          label: l10n.sessionSummaryTimeSpent,
                          value: durationFormatted,
                          color: colors.syllabotAccent,
                          colors: colors,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const Spacer(),

              // Return to Dashboard Action
              AppButton(
                text: l10n.sessionSummaryReturnDashboard,
                onPressed: () {
                  unawaited(context.router.replace(const MainRoute()));
                },
              ),
              const SizedBox(height: 12),

              // Review More Decks Action
              AppButton(
                text: l10n.sessionSummaryReviewAgain,
                variant: AppButtonVariant.outline,
                onPressed: () {
                  unawaited(context.router.maybePop());
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
    required this.colors,
  });

  final String label;
  final String value;
  final Color color;
  final AppThemeColorsExtension colors;

  @override
  Widget build(BuildContext context) {
    final typography = context.typography;

    return Column(
      children: [
        Text(
          value,
          style: typography.title3.bold.copyWith(
            color: color,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: typography.footnote.regular.copyWith(
            color: colors.textMuted,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
