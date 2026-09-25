import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';

/// Renders the FSRS memory retrievability curve R(t) = (1 + F * t / S)^(-1)
/// and memory decay metrics for decks and individual cards.
class FsrsRetrievabilityVisualizer extends StatelessWidget {
  const FsrsRetrievabilityVisualizer({
    required this.stabilityDays,
    this.targetRetention = 0.90,
    this.elapsedDays = 0,
    this.subjectTitle = 'Overall Memory Track',
    super.key,
  });

  /// FSRS Memory Stability S (in days)
  final double stabilityDays;

  /// User requested retention (e.g. 0.90 for 90%)
  final double targetRetention;

  /// Elapsed days since last review
  final int elapsedDays;

  final String subjectTitle;

  /// Calculates retrievability R(t) at time t (in days) given stability S
  static double calculateRetrievability(double stability, int t) {
    if (stability <= 0) return 1.0;
    // Standard FSRS formula: R(t) = 0.9^(t / S)
    return math.pow(0.9, t / stability).toDouble().clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final neural = context.neural;

    final effectiveStability = stabilityDays > 0 ? stabilityDays : 7.0;
    final currentRetrievability = calculateRetrievability(
      effectiveStability,
      elapsedDays,
    );
    final currentPercentage = (currentRetrievability * 100).round();

    final statusColor = currentPercentage >= 85
        ? neural.emerald400
        : currentPercentage >= 70
        ? neural.amber400
        : colors.error;

    final statusBgColor = currentPercentage >= 85
        ? neural.emerald.withValues(alpha: 0.15)
        : currentPercentage >= 70
        ? neural.amber.withValues(alpha: 0.15)
        : colors.error.withValues(alpha: 0.15);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfacePrimary,
        borderRadius: BorderRadius.circular(AppRadius.panel),
        border: Border.all(color: colors.surfaceBorder),
        boxShadow: [
          BoxShadow(
            color: colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.badge),
                    ),
                    child: Icon(
                      Icons.show_chart_rounded,
                      color: colors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FSRS Memory Forgetting Curve',
                        style: typography.body.bold.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        subjectTitle,
                        style: typography.caption.regular.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.psychology_rounded,
                      size: 14,
                      color: statusColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$currentPercentage% Retrievability',
                      style: typography.caption.bold.copyWith(
                        color: statusColor,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Forgetting Curve Graph Canvas
          SizedBox(
            height: 140,
            width: double.infinity,
            child: CustomPaint(
              painter: _ForgettingCurvePainter(
                stability: effectiveStability,
                targetRetention: targetRetention,
                elapsedDays: elapsedDays,
                primaryColor: colors.primary,
                gridColor: colors.surfaceBorder,
                textColor: colors.textSecondary,
                amberColor: neural.amber400,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Key FSRS Stat Badges
          Row(
            children: [
              Expanded(
                child: _StatBadge(
                  label: 'Stability (S)',
                  value: '${stabilityDays.toStringAsFixed(1)} days',
                  icon: Icons.timer_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatBadge(
                  label: 'Target Retention',
                  value: '${(targetRetention * 100).toInt()}%',
                  icon: Icons.verified_user_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatBadge(
                  label: 'Elapsed Time',
                  value: '$elapsedDays days',
                  icon: Icons.history_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceSecondary,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colors.surfaceBorder.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: colors.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: typography.caption.regular.copyWith(
                    color: colors.textSecondary,
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: typography.caption.bold.copyWith(
              color: colors.textPrimary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ForgettingCurvePainter extends CustomPainter {
  _ForgettingCurvePainter({
    required this.stability,
    required this.targetRetention,
    required this.elapsedDays,
    required this.primaryColor,
    required this.gridColor,
    required this.textColor,
    required this.amberColor,
  });

  final double stability;
  final double targetRetention;
  final int elapsedDays;
  final Color primaryColor;
  final Color gridColor;
  final Color textColor;
  final Color amberColor;

  @override
  void paint(Canvas canvas, Size size) {
    const margin = EdgeInsets.only(left: 30, bottom: 20, top: 10, right: 10);
    final chartWidth = size.width - margin.left - margin.right;
    final chartHeight = size.height - margin.top - margin.bottom;

    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.6)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final targetPaint = Paint()
      ..color = amberColor.withValues(alpha: 0.7)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final curvePaint = Paint()
      ..color = primaryColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          primaryColor.withValues(alpha: 0.25),
          primaryColor.withValues(alpha: 0),
        ],
      ).createShader(
        Rect.fromLTWH(margin.left, margin.top, chartWidth, chartHeight),
      );

    // Draw Y-axis grid lines (100%, 75%, 50%, 0%)
    final yTicks = [1.0, 0.75, 0.50, 0.0];
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (final tick in yTicks) {
      final y = margin.top + chartHeight * (1 - tick);
      canvas.drawLine(
        Offset(margin.left, y),
        Offset(size.width - margin.right, y),
        gridPaint,
      );

      textPainter.text = TextSpan(
        text: '${(tick * 100).toInt()}%',
        style: TextStyle(color: textColor, fontSize: 9),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(margin.left - textPainter.width - 6, y - textPainter.height / 2),
      );
    }

    // Draw X-axis day labels (Day 0, 7, 14, 30, 60)
    final maxDays = math.max(60.0, stability * 2.5);
    final xTicks = [0, 7, 14, 30, 60];

    for (final tick in xTicks) {
      final x = margin.left + (tick / maxDays) * chartWidth;
      if (x <= size.width - margin.right) {
        textPainter.text = TextSpan(
          text: 'd$tick',
          style: TextStyle(color: textColor, fontSize: 9),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(x - textPainter.width / 2, size.height - margin.bottom + 4),
        );
      }
    }

    // Target Retention Dotted Line
    final targetY = margin.top + chartHeight * (1 - targetRetention);
    canvas.drawLine(
      Offset(margin.left, targetY),
      Offset(size.width - margin.right, targetY),
      targetPaint,
    );

    // Build Curve Path R(t) = 0.9^(t / S)
    final path = Path();
    final fillPath = Path();
    fillPath.moveTo(margin.left, margin.top);

    for (var px = 0.0; px <= chartWidth; px += 2) {
      final t = (px / chartWidth) * maxDays;
      final ret = FsrsRetrievabilityVisualizer.calculateRetrievability(stability, t.toInt());
      final x = margin.left + px;
      final y = margin.top + chartHeight * (1 - ret);

      if (px == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      fillPath.lineTo(x, y);
    }

    fillPath.lineTo(margin.left + chartWidth, margin.top + chartHeight);
    fillPath.lineTo(margin.left, margin.top + chartHeight);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, curvePaint);

    // Elapsed Day Marker Dot
    final elapsedX = margin.left + (elapsedDays / maxDays).clamp(0.0, 1.0) * chartWidth;
    final elapsedR = FsrsRetrievabilityVisualizer.calculateRetrievability(stability, elapsedDays);
    final elapsedY = margin.top + chartHeight * (1 - elapsedR);

    final dotPaint = Paint()..color = primaryColor;
    final dotOuterPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(elapsedX, elapsedY), 7, dotOuterPaint);
    canvas.drawCircle(Offset(elapsedX, elapsedY), 4, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _ForgettingCurvePainter oldDelegate) {
    return oldDelegate.stability != stability ||
        oldDelegate.targetRetention != targetRetention ||
        oldDelegate.elapsedDays != elapsedDays ||
        oldDelegate.primaryColor != primaryColor;
  }
}
