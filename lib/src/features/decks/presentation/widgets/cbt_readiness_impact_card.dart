import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/dashboard/domain/logic/cbt_readiness_calculator.dart';

/// Card surfacing the student's CBT Exam Readiness Index, syllabus breakdown,
/// and post-session readiness boost.
class CbtReadinessImpactCard extends StatelessWidget {
  const CbtReadinessImpactCard({
    required this.cardsReviewed,
    required this.retentionScore,
    this.examTitle = 'JAMB',
    this.syllabusCoverage = 0.88,
    this.mockScore = 0.85,
    this.topicName,
    super.key,
  });

  final int cardsReviewed;
  final double retentionScore;
  final String examTitle;
  final double syllabusCoverage;
  final double mockScore;
  final String? topicName;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    const calculator = CbtReadinessCalculator();
    final result = calculator.compute(
      syllabusCoverage: syllabusCoverage,
      fsrsRetentionRate: retentionScore,
      mockScoreRatio: mockScore,
      daysRemaining: 30,
    );

    final scoreGain = (cardsReviewed * 0.12 * retentionScore).clamp(0.4, 4.2);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfaceSecondary.withAlpha(180)
            : colors.surfacePrimary,
        borderRadius: BorderRadius.circular(AppRadius.panel),
        border: Border.all(
          color: isDark
              ? colors.surfaceBorderHighlight.withAlpha(80)
              : colors.surfaceBorder.withAlpha(140),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.black.withAlpha(isDark ? 50 : 15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: CBT Readiness Index title & ON TRACK pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CBT READINESS INDEX',
                      style: typography.caption.bold.copyWith(
                        color: colors.textMuted,
                        fontSize: 11,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      examTitle.toUpperCase(),
                      style: typography.title3.bold.copyWith(
                        color: colors.textPrimary,
                        fontSize: 20,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (topicName != null && topicName!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 11,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              topicName!.trim(),
                              style: typography.caption.medium.copyWith(
                                color: colors.primary,
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: result.statusColor.withAlpha(isDark ? 40 : 20),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: result.statusColor.withAlpha(120),
                  ),
                ),
                child: Text(
                  result.statusLabel,
                  style: typography.caption.bold.copyWith(
                    color: result.statusColor,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Main Content: Circular Arc Gauge (Left) + Breakdown Bars (Right)
          Row(
            children: [
              // Circular Arc Gauge
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(100, 100),
                      painter: _ArcGaugePainter(
                        percent: result.scorePercent / 100,
                        gaugeColor: result.statusColor,
                        trackColor: colors.surfaceBorder.withAlpha(100),
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${result.scorePercent}%',
                          style: typography.title2.bold.copyWith(
                            color: colors.textPrimary,
                            fontSize: 22,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Score',
                          style: typography.caption.medium.copyWith(
                            color: colors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),

              // Breakdown Progress Bars
              Expanded(
                child: Column(
                  children: [
                    _MetricBar(
                      label: 'Syllabus Coverage',
                      valuePercent: (result.syllabusCoverage * 100).round(),
                      barColor: const Color(0xFF6B8E7B),
                    ),
                    const SizedBox(height: 10),
                    _MetricBar(
                      label: 'FSRS Retention',
                      valuePercent: (result.fsrsRetentionRate * 100).round(),
                      barColor: const Color(0xFF10B981),
                    ),
                    const SizedBox(height: 10),
                    _MetricBar(
                      label: 'Mock Test Score',
                      valuePercent: (result.mockScoreRatio * 100).round(),
                      barColor: const Color(0xFF5B61D6),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Impact Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: result.statusColor.withAlpha(isDark ? 30 : 15),
              borderRadius: BorderRadius.circular(AppRadius.badge),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.trending_up_rounded,
                  size: 16,
                  color: result.statusColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '+${scoreGain.toStringAsFixed(1)}% CBT Readiness Boost from this session!',
                    style: typography.caption.bold.copyWith(
                      color: result.statusColor,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricBar extends StatelessWidget {
  const _MetricBar({
    required this.label,
    required this.valuePercent,
    required this.barColor,
  });

  final String label;
  final int valuePercent;
  final Color barColor;

  @override
  Widget build(BuildContext context) {
    final typography = context.typography;
    final colors = context.colors;
    final isDark = context.isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: typography.footnote.regular.copyWith(
                  color: colors.textSecondary,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$valuePercent%',
              style: typography.footnote.bold.copyWith(
                color: colors.textPrimary,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Container(
            height: 6,
            width: double.infinity,
            color: isDark
                ? colors.surfaceBorderHighlight.withAlpha(60)
                : colors.surfaceBorder.withAlpha(120),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (valuePercent / 100).clamp(0.04, 1.0),
              child: AnimatedContainer(
                duration: AppMotion.standard,
                curve: AppMotion.easeOutCubic,
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ArcGaugePainter extends CustomPainter {
  const _ArcGaugePainter({
    required this.percent,
    required this.gaugeColor,
    required this.trackColor,
  });

  final double percent;
  final Color gaugeColor;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 8;
    const strokeWidth = 10.0;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final gaugePaint = Paint()
      ..color = gaugeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Draw background 240-degree arc
    const startAngle = math.pi * 0.75;
    const sweepAngle = math.pi * 1.5;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      trackPaint,
    );

    // Draw active readiness arc
    final activeSweep = sweepAngle * percent.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      activeSweep,
      false,
      gaugePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ArcGaugePainter oldDelegate) {
    return oldDelegate.percent != percent ||
        oldDelegate.gaugeColor != gaugeColor ||
        oldDelegate.trackColor != trackColor;
  }
}
