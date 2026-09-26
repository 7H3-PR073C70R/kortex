import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/dashboard/domain/logic/cbt_readiness_calculator.dart';

/// Interactive glassmorphic CBT Readiness Score progress gauge widget for the executive dashboard.
class CbtReadinessGaugeCard extends StatelessWidget {
  const CbtReadinessGaugeCard({
    required this.readinessResult,
    required this.examTitle,
    required this.daysRemaining,
    super.key,
  });

  final CbtReadinessResult readinessResult;
  final String examTitle;
  final int daysRemaining;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Container(
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: readinessResult.statusColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(AppRadius.badge),
                  border: Border.all(
                    color: readinessResult.statusColor.withAlpha(100),
                  ),
                ),
                child: Text(
                  readinessResult.statusLabel,
                  style: typography.caption.bold.copyWith(
                    color: readinessResult.statusColor,
                  ),
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
                child: CustomPaint(
                  painter: _ReadinessGaugePainter(
                    scorePercent: readinessResult.scorePercent,
                    color: readinessResult.statusColor,
                    trackColor: colors.surfaceBorder.withAlpha(isDark ? 50 : 80),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${readinessResult.scorePercent}%',
                          style: typography.title1.bold.copyWith(
                            color: colors.textPrimary,
                            fontSize: 22,
                            height: 1,
                          ),
                        ),
                        Text(
                          'Score',
                          style: typography.caption.medium.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: [
                    _MetricBar(
                      label: 'Syllabus Coverage',
                      value: readinessResult.syllabusCoverage,
                      color: colors.primary,
                    ),
                    const SizedBox(height: 8),
                    _MetricBar(
                      label: 'FSRS Retention',
                      value: readinessResult.fsrsRetentionRate,
                      color: const Color(0xFF10B981),
                    ),
                    const SizedBox(height: 8),
                    _MetricBar(
                      label: 'Mock Test Score',
                      value: readinessResult.mockScoreRatio,
                      color: const Color(0xFF6366F1),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricBar extends StatelessWidget {
  const _MetricBar({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final percent = (value.clamp(0.0, 1.0) * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: typography.caption.medium.copyWith(
                color: colors.textSecondary,
              ),
            ),
            Text(
              '$percent%',
              style: typography.caption.bold.copyWith(
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.micro),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: colors.surfaceBorder.withAlpha(60),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _ReadinessGaugePainter extends CustomPainter {
  _ReadinessGaugePainter({
    required this.scorePercent,
    required this.color,
    required this.trackColor,
  });

  final int scorePercent;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 12) / 2;
    const strokeWidth = 10.0;
    const startAngle = 0.75 * math.pi;
    const totalSweep = 1.5 * math.pi;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      totalSweep,
      false,
      trackPaint,
    );

    final sweepAngle = totalSweep * (scorePercent / 100.0);
    final valuePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    if (sweepAngle > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        valuePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ReadinessGaugePainter oldDelegate) {
    return oldDelegate.scorePercent != scorePercent ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor;
  }
}
