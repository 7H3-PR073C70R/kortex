import 'dart:async';
import 'dart:math' as math;
import 'package:auto_route/auto_route.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';
import 'package:kortex/src/shared/widgets/gratification_celebration_overlay.dart';

@RoutePage()
class SessionSummaryPage extends StatefulWidget {
  const SessionSummaryPage({
    required this.deckId,
    required this.cardsReviewed,
    required this.durationSeconds,
    required this.retentionScore,
    this.nextReviewInDays = 0,
    super.key,
  });

  final String deckId;
  final int cardsReviewed;
  final int durationSeconds;
  final double retentionScore;

  /// Days until the next scheduled review batch across the session's cards;
  /// 0 when unknown — the forward-looking line is then omitted.
  final int nextReviewInDays;

  @override
  State<SessionSummaryPage> createState() => _SessionSummaryPageState();
}

class _SessionSummaryPageState extends State<SessionSummaryPage> {
  final ConfettiController _confettiController = ConfettiController(
    duration: const Duration(seconds: 3),
  );
  bool _celebrationStarted = false;

  /// Celebrate every completed deck review session.
  bool get _shouldCelebrate => widget.cardsReviewed > 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_celebrationStarted) return;
    _celebrationStarted = true;
    final celebrate = _shouldCelebrate && !context.reduceMotion;
    if (celebrate) {
      _confettiController.play();
      unawaited(HapticFeedback.heavyImpact());

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final xp = widget.cardsReviewed * 10;
        final retention = (widget.retentionScore * 100).toInt();
        final emoji = widget.retentionScore >= 0.85 ? '🎴' : '🧠';
        final title = widget.retentionScore >= 0.85
            ? 'Deck Conquered!'
            : 'Study Session Complete!';
        final subtitle =
            'You reviewed ${widget.cardsReviewed} flashcards. Active recall consolidates memory tracks.';

        unawaited(
          GratificationCelebrationOverlay.show(
            context,
            title: title,
            subtitle: subtitle,
            primaryStatLabel: 'Cards',
            primaryStatValue: '${widget.cardsReviewed}',
            secondaryStatLabel: 'Retention',
            secondaryStatValue: '$retention%',
            tertiaryStatLabel: 'XP Earned',
            tertiaryStatValue: '+$xp',
            xpEarned: xp,
            motivationalBadge: '🧠 Memory Consolidation Active',
            buttonText: 'View Summary',
            emoji: emoji,
          ),
        );
      });
    } else {
      unawaited(HapticFeedback.lightImpact());
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;
    final reduceMotion = context.reduceMotion;

    final deckId = widget.deckId;
    final cardsReviewed = widget.cardsReviewed;
    final durationSeconds = widget.durationSeconds;
    final retentionScore = widget.retentionScore;

    final scorePercent = (retentionScore * 100).toInt();
    final minutes = (durationSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (durationSeconds % 60).toString().padLeft(2, '0');
    final durationFormatted = '$minutes:$seconds';

    final celebrate = _shouldCelebrate;

    return Scaffold(
      backgroundColor: isDark
          ? colors.backgroundPrimary
          : colors.surfacePrimary,
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          if (celebrate && !reduceMotion)
            Positioned(
              top: 0,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirection: math.pi / 2,
                maxBlastForce: 25,
                minBlastForce: 10,
                emissionFrequency: 0.05,
                numberOfParticles: 35,
                gravity: 0.15,
                colors: [
                  colors.primary,
                  colors.success,
                  colors.warning,
                  colors.secondary,
                  colors.deepBronze,
                  colors.quartzCyan,
                ],
              ),
            ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 24),

                      // Result Orb — enters from 0.9 scale, never from zero.
                      _OrbEntrance(
                        reduceMotion: reduceMotion,
                        child: Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: celebrate
                                  ? [colors.success, colors.syllabotAccent]
                                  : [
                                      colors.primary.withAlpha(
                                        isDark ? 170 : 140,
                                      ),
                                      colors.syllabotAccent.withAlpha(
                                        isDark ? 170 : 140,
                                      ),
                                    ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: colors.black.withAlpha(
                                  isDark ? 50 : 20,
                                ),
                                blurRadius: celebrate ? 28 : 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Icon(
                            celebrate
                                ? Icons.check_rounded
                                : Icons.task_alt_rounded,
                            color: colors.white,
                            size: 48,
                          ),
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

                      // XP Announcement Pill — base session XP is always
                      // awarded by UserActivityService (+50 per session).
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

                      // Stats Cards Row — values count up, staggered.
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
                              child: _StatItem(
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
                              child: _StatItem(
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
                              child: _StatItem(
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

                      // Forward-looking line: what the effort buys later.
                      if (widget.nextReviewInDays > 0) ...[
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 14,
                              color: colors.textMuted,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                l10n.sessionSummaryNextReview(
                                  widget.nextReviewInDays,
                                ),
                                textAlign: TextAlign.center,
                                style: typography.footnote.regular.copyWith(
                                  color: colors.textSecondary,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 40),

                      // Action Buttons
                      if (deckId.startsWith('sprint:')) ...[
                        AppButton(
                          text: '🚀 Next Focus Sprint',
                          onPressed: () {
                            unawaited(
                              context.router.replace(
                                StudySessionRoute(deckId: deckId),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        AppButton(
                          text: 'Done for Now',
                          variant: AppButtonVariant.outline,
                          onPressed: () {
                            unawaited(
                              context.router.replace(const MainRoute()),
                            );
                          },
                        ),
                      ] else ...[
                        // Return to Dashboard Action
                        AppButton(
                          text: l10n.sessionSummaryReturnDashboard,
                          onPressed: () {
                            unawaited(
                              context.router.replace(const MainRoute()),
                            );
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
                      ],
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Scale-in entrance for the orb; skipped entirely under reduced motion.
class _OrbEntrance extends StatelessWidget {
  const _OrbEntrance({
    required this.reduceMotion,
    required this.child,
  });

  final bool reduceMotion;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutQuint,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.scale(scale: 0.9 + 0.1 * t, child: child),
      ),
      child: child,
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.color,
    required this.colors,
    required this.reduceMotion,
    required this.staggerIndex,
    this.countTo,
    this.format,
    this.display,
  }) : assert(
         (countTo != null) == (format != null),
         'countTo and format must be provided together',
       ),
       assert(
         countTo != null || display != null,
         'provide either countTo or display',
       );

  final String label;
  final Color color;
  final AppThemeColorsExtension colors;
  final bool reduceMotion;
  final int staggerIndex;

  /// When set, the value animates 0 -> [countTo] through [format].
  final int? countTo;
  final String Function(int value)? format;

  /// Static value for stats that should not count up (e.g. mm:ss time).
  final String? display;

  static const _tabular = [FontFeature.tabularFigures()];

  @override
  Widget build(BuildContext context) {
    final typography = context.typography;
    final countTarget = countTo;

    final valueText = display ?? '$countTo';

    return _StaggeredFade(
      reduceMotion: reduceMotion,
      staggerIndex: staggerIndex,
      child: Column(
        children: [
          if (countTarget != null && !reduceMotion)
            TweenAnimationBuilder<int>(
              tween: IntTween(begin: 0, end: countTarget),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutQuint,
              builder: (context, value, _) => Text(
                format!(value),
                style: typography.title3.bold.copyWith(
                  color: color,
                  fontSize: 20,
                  fontFeatures: _tabular,
                ),
              ),
            )
          else
            Text(
              valueText,
              style: typography.title3.bold.copyWith(
                color: color,
                fontSize: 20,
                fontFeatures: _tabular,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: typography.footnote.regular.copyWith(
              color: colors.textMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// Soft fade-in offset per stat so the three numbers don't land at once.
class _StaggeredFade extends StatelessWidget {
  const _StaggeredFade({
    required this.reduceMotion,
    required this.staggerIndex,
    required this.child,
  });

  final bool reduceMotion;
  final int staggerIndex;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 250 + staggerIndex * 100),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(opacity: t, child: child),
      child: child,
    );
  }
}
