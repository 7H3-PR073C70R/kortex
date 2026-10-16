import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/analytics_service.dart';
import 'package:kortex/src/core/services/user_activity_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/utils/app_logger.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/dashboard/domain/logic/cbt_readiness_calculator.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/cbt_readiness/cbt_readiness_breakdown_sheet.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/cbt_readiness/readiness_gauge_painter.dart';
import 'package:kortex/src/features/quiz/domain/repositories/past_questions_repository.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_sheet.dart';

export 'cbt_readiness/cbt_readiness_breakdown_sheet.dart';
export 'cbt_readiness/cbt_readiness_weekly_trends_chart.dart';
export 'cbt_readiness/day_one_diagnostic_banner.dart';
export 'cbt_readiness/readiness_breakdown_actions_section.dart';
export 'cbt_readiness/readiness_breakdown_course_card.dart';
export 'cbt_readiness/readiness_breakdown_projected_card.dart';
export 'cbt_readiness/readiness_gauge_painter.dart';

/// Interactive glassmorphic CBT Readiness Score progress gauge widget for the executive dashboard.
///
/// On first mount the arc sweeps from 0 → readiness score over
/// 900ms with an easeOutCubic curve, providing a satisfying reveal animation
/// that communicates "data loaded and computed". Metric bars stagger in after.
class CbtReadinessGaugeCard extends StatefulWidget {
  const CbtReadinessGaugeCard({
    required this.readinessResult,
    required this.examTitle,
    required this.daysRemaining,
    this.pastQuestionsRepository,
    this.userActivityService,
    this.analyticsService,
    super.key,
  });

  final CbtReadinessResult readinessResult;
  final String examTitle;
  final int daysRemaining;
  final PastQuestionsRepository? pastQuestionsRepository;
  final UserActivityService? userActivityService;
  final AnalyticsService? analyticsService;

  @override
  State<CbtReadinessGaugeCard> createState() => _CbtReadinessGaugeCardState();
}

class _CbtReadinessGaugeCardState extends State<CbtReadinessGaugeCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _arcController;
  late final Animation<double> _arcAnimation;

  @override
  void initState() {
    super.initState();
    _arcController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _arcAnimation = CurvedAnimation(
      parent: _arcController,
      curve: Curves.easeOutCubic,
    );
    // Delay slightly so the widget's outer container has faded in first.
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 80), () {
        if (mounted) unawaited(_arcController.forward());
      }),
    );
    try {
      final analytics = widget.analyticsService ??
          (locator.isRegistered<AnalyticsService>()
              ? locator<AnalyticsService>()
              : null);
      if (analytics != null) {
        unawaited(
          analytics.logReadinessScoreViewed(
            readinessScore: widget.readinessResult.scorePercent.toDouble(),
            statusTier: widget.readinessResult.statusTier.name,
            confidenceIntervalLabel:
                widget.readinessResult.confidenceIntervalLabel,
            standardErrorMargin:
                widget.readinessResult.confidenceMargin.toDouble(),
            examTrack: widget.examTitle,
          ),
        );
      }
    } on Object catch (e, st) {
      AppLogger.recordNonFatal(e, st);
    }
  }

  @override
  void didUpdateWidget(CbtReadinessGaugeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-animate when the score changes (e.g. after a data refresh).
    if (oldWidget.readinessResult.scorePercent !=
        widget.readinessResult.scorePercent) {
      _arcController.reset();
      unawaited(_arcController.forward());
    }
  }

  @override
  void dispose() {
    _arcController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final readinessResult = widget.readinessResult;
    final examTitle = widget.examTitle;

    return InkWell(
      onTap: () => _showDiagnosticSheet(context),
      borderRadius: BorderRadius.circular(AppRadius.panel),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark
              ? colors.surfaceSecondary.withAlpha(160)
              : colors.surfacePrimary.withAlpha(220),
          borderRadius: BorderRadius.circular(AppRadius.panel),
          border: Border.all(
            color: colors.surfaceBorder.withAlpha(isDark ? 60 : 35),
          ),
          boxShadow: [
            BoxShadow(
              color: colors.black.withAlpha(isDark ? 50 : 20),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CBT READINESS INDEX',
                        style: typography.caption.medium.copyWith(
                          color: colors.textSecondary,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        examTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: typography.title3.bold.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: readinessResult.statusColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(AppRadius.badge),
                    border: Border.all(
                      color: readinessResult.statusColor.withAlpha(100),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        readinessResult.statusLabel,
                        style: typography.caption.bold.copyWith(
                          color: readinessResult.statusColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: readinessResult.statusColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          readinessResult.projectedGrade,
                          style: typography.caption.bold.copyWith(
                            color: colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: AnimatedBuilder(
                    animation: _arcAnimation,
                    builder: (context, _) => CustomPaint(
                      painter: ReadinessGaugePainter(
                        scorePercent: (readinessResult.scorePercent *
                                _arcAnimation.value)
                            .round(),
                        color: readinessResult.statusColor,
                        trackColor:
                            colors.surfaceBorder.withAlpha(isDark ? 50 : 80),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              readinessResult.isCalibrated
                                  ? '${(readinessResult.scorePercent * _arcAnimation.value).round()}%'
                                  : '--',
                              style: typography.title1.bold.copyWith(
                                color: colors.textPrimary,
                                fontSize: 22,
                                height: 1,
                              ),
                            ),
                            Text(
                              readinessResult.isCalibrated ? 'Score' : 'Pending',
                              style: typography.caption.medium.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    children: [
                      ReadinessMetricBar(
                        label: 'Syllabus Coverage',
                        value: readinessResult.syllabusCoverage,
                        color: colors.primary,
                      ),
                      const SizedBox(height: 8),
                      ReadinessMetricBar(
                        label: 'Memory Retention',
                        value: readinessResult.fsrsRetentionRate,
                        color: const Color(0xFF10B981),
                      ),
                      const SizedBox(height: 8),
                      ReadinessMetricBar(
                        label: 'Mock Test Score',
                        value: readinessResult.mockScoreRatio,
                        color: const Color(0xFF6366F1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (readinessResult.confidenceIntervalLabel.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: readinessResult.isSampleSufficient
                      ? colors.surfaceBorder.withAlpha(isDark ? 30 : 20)
                      : colors.warning.withAlpha(isDark ? 25 : 15),
                  borderRadius: BorderRadius.circular(AppRadius.badge),
                  border: Border.all(
                    color: readinessResult.isSampleSufficient
                        ? colors.surfaceBorder.withAlpha(isDark ? 60 : 45)
                        : colors.warning.withAlpha(isDark ? 70 : 45),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      readinessResult.isSampleSufficient
                          ? Icons.verified_outlined
                          : Icons.info_outline_rounded,
                      size: 14,
                      color: readinessResult.isSampleSufficient
                          ? colors.textSecondary
                          : colors.warning,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        readinessResult.confidenceIntervalLabel,
                        style: typography.caption.medium.copyWith(
                          color: readinessResult.isSampleSufficient
                              ? colors.textSecondary
                              : (isDark ? colors.warning : const Color(0xFFB45309)),
                          fontSize: 11,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (readinessResult.remediationSuggestion.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: colors.primary.withAlpha(isDark ? 30 : 15),
                  borderRadius: BorderRadius.circular(AppRadius.badge),
                  border: Border.all(
                    color: colors.primary.withAlpha(isDark ? 80 : 40),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 16,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        readinessResult.remediationSuggestion,
                        style: typography.caption.medium.copyWith(
                          color: colors.textPrimary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: colors.textSecondary,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showDiagnosticSheet(BuildContext context) {
    unawaited(
      AppAdaptiveSheet.showSideDrawer<void>(
        context: context,
        builder: (sheetContext) {
          final isDesktop = AppAdaptiveSheet.isDesktopOrWeb(sheetContext);
          if (isDesktop) {
            return Align(
              alignment: Alignment.centerRight,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: CbtReadinessBreakdownSheet(
                  readinessResult: widget.readinessResult,
                  examTitle: widget.examTitle,
                  daysRemaining: widget.daysRemaining,
                  scrollController: ScrollController(),
                  pastQuestionsRepository: widget.pastQuestionsRepository,
                  userActivityService: widget.userActivityService,
                  analyticsService: widget.analyticsService,
                ),
              ),
            );
          }
          return DraggableScrollableSheet(
            initialChildSize: 0.82,
            maxChildSize: 0.94,
            minChildSize: 0.50,
            builder: (context, scrollController) {
              return CbtReadinessBreakdownSheet(
                readinessResult: widget.readinessResult,
                examTitle: widget.examTitle,
                daysRemaining: widget.daysRemaining,
                scrollController: scrollController,
                pastQuestionsRepository: widget.pastQuestionsRepository,
                userActivityService: widget.userActivityService,
                analyticsService: widget.analyticsService,
              );
            },
          );
        },
      ),
    );
  }
}
