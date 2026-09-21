import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/planner/domain/entities/exam_event_entity.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';

class StudyCalibrationGraphWidget extends StatelessWidget {
  const StudyCalibrationGraphWidget({
    required this.exam,
    this.onStartStudySession,
    super.key,
  });

  final ExamEventEntity exam;
  final VoidCallback? onStartStudySession;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final progress = exam.completionProgress;
    final progressPercent = (progress * 100).toInt();
    final daysRemaining = exam.daysRemaining;

    // Determine status badge
    final String statusLabel;
    final Color statusColor;
    if (exam.isPast) {
      statusLabel = 'Completed';
      statusColor = colors.textSecondary;
    } else if (daysRemaining <= 3) {
      statusLabel = 'Sprint Pace';
      statusColor = colors.error;
    } else if (progress >= 0.7) {
      statusLabel = 'On Track';
      statusColor = colors.success;
    } else {
      statusLabel = 'Calibrated';
      statusColor = colors.primary;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  colors.surfaceSecondary,
                  colors.surfaceSecondary.withValues(alpha: 0.8),
                ]
              : [
                  colors.surfacePrimary,
                  colors.surfaceSecondary.withValues(alpha: 0.5),
                ],
        ),
        borderRadius: AppRadius.radiusDialog,
        border: Border.all(
          color: colors.primary.withValues(alpha: isDark ? 0.25 : 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Study Desk Calibration',
                      style: typography.callout.bold.copyWith(
                        color: colors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ideal trajectory vs. actual mastery',
                      style: typography.caption.regular.copyWith(
                        color: colors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: AppRadius.radiusBadge,
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      statusLabel,
                      style: typography.caption.bold.copyWith(
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Custom Trajectory Painter Canvas
          SizedBox(
            height: 120,
            child: CustomPaint(
              painter: _TrajectoryPainter(
                progress: progress,
                primaryColor: colors.primary,
                gridColor: colors.textSecondary.withValues(alpha: 0.15),
                indicatorDotColor: colors.white,
                isDark: isDark,
              ),
              child: const SizedBox.expand(),
            ),
          ),

          const SizedBox(height: 10),

          // Timeline Axis Labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Start',
                style: typography.caption.regular.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              Flexible(
                child: Text(
                  'Today ($progressPercent%)',
                  style: typography.caption.bold.copyWith(
                    color: colors.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Flexible(
                child: Text(
                  'Exam (${exam.formattedCountdown})',
                  style: typography.caption.regular.copyWith(
                    color: colors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 3 Metric Cards
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  context,
                  title: 'Daily Goal',
                  value: '${exam.dailyTarget}',
                  unit: 'cards/day',
                  icon: Icons.flag_rounded,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  context,
                  title: 'Mastered',
                  value: '${exam.masteredCardsCount}',
                  unit: '/ ${exam.totalCardsCount}',
                  icon: Icons.check_circle_rounded,
                  color: colors.success,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  context,
                  title: 'Remaining',
                  value: '${exam.remainingCards}',
                  unit: 'cards left',
                  icon: Icons.hourglass_bottom_rounded,
                  color: colors.warning,
                ),
              ),
            ],
          ),

          if (onStartStudySession != null && !exam.isPast) ...[
            const SizedBox(height: 16),
            PlatformHoverBuilder(
              builder: (context, isHovered, child) {
                return AnimatedContainer(
                  duration: AppMotion.snappy,
                  curve: Curves.easeOutCubic,
                  transform: Matrix4.translationValues(
                    0,
                    isHovered ? -1.5 : 0,
                    0,
                  ),
                  child: InkWell(
                    onTap: onStartStudySession,
                    borderRadius: AppRadius.radiusCard,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colors.primary,
                            colors.primary.withValues(
                              alpha: isHovered ? 0.95 : 0.85,
                            ),
                          ],
                        ),
                        borderRadius: AppRadius.radiusCard,
                        boxShadow: [
                          BoxShadow(
                            color: colors.black.withValues(
                              alpha: isDark
                                  ? (isHovered ? 0.45 : 0.3)
                                  : (isHovered ? 0.25 : 0.15),
                            ),
                            blurRadius: isHovered ? 16 : 12,
                            offset: Offset(0, isHovered ? 6 : 4),
                          ),
                        ],
                      ),
                      child: child,
                    ),
                  ),
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.play_circle_fill_rounded,
                    color: colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      "Review Today's ${exam.dailyTarget} Flashcards",
                      style: typography.callout.bold.copyWith(
                        color: colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricTile(
    BuildContext context, {
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
  }) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return PlatformHoverBuilder(
      builder: (context, isHovered, child) {
        return AnimatedContainer(
          duration: AppMotion.snappy,
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, isHovered ? -1.5 : 0, 0),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark
                ? (isHovered
                      ? colors.surfacePrimary.withValues(alpha: 0.85)
                      : colors.surfacePrimary.withValues(alpha: 0.6))
                : (isHovered
                      ? colors.surfaceSecondary
                      : colors.surfaceSecondary.withValues(alpha: 0.8)),
            borderRadius: AppRadius.radiusCard,
            border: Border.all(
              color: isHovered
                  ? color.withValues(alpha: 0.6)
                  : colors.surfaceBorder.withValues(alpha: 0.6),
            ),
            boxShadow: isHovered
                ? [
                    BoxShadow(
                      color: colors.black.withValues(
                        alpha: isDark ? 0.25 : 0.08,
                      ),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: child,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: typography.caption.regular.copyWith(
                    color: colors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: typography.title3.bold.copyWith(
              color: colors.textPrimary,
            ),
          ),
          Text(
            unit,
            style: typography.caption.regular.copyWith(
              color: colors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _TrajectoryPainter extends CustomPainter {
  _TrajectoryPainter({
    required this.progress,
    required this.primaryColor,
    required this.gridColor,
    required this.indicatorDotColor,
    required this.isDark,
  });

  final double progress;
  final Color primaryColor;
  final Color gridColor;
  final Color indicatorDotColor;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // Draw horizontal background guide lines
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    canvas
      ..drawLine(
        Offset(0, height * 0.25),
        Offset(width, height * 0.25),
        gridPaint,
      )
      ..drawLine(
        Offset(0, height * 0.75),
        Offset(width, height * 0.75),
        gridPaint,
      )
      ..drawLine(Offset(0, height), Offset(width, height), gridPaint);

    // 1. Draw Ideal Trajectory Path (straight or slight curve from bottom-left to top-right)
    final idealPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.35)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final idealPath = Path()
      ..moveTo(0, height)
      ..cubicTo(
        width * 0.35,
        height * 0.75,
        width * 0.65,
        height * 0.25,
        width,
        height * 0.1,
      );

    canvas.drawPath(idealPath, idealPaint);

    // 2. Draw Actual Progress Path up to current progress point
    final currentX = (width * 0.55).clamp(20.0, width - 20.0);
    final targetY = height - ((height * 0.9) * progress.clamp(0.05, 1.0));

    final actualPath = Path()
      ..moveTo(0, height)
      ..cubicTo(
        currentX * 0.4,
        height,
        currentX * 0.6,
        targetY,
        currentX,
        targetY,
      );

    // Fill gradient under actual path
    final fillPath = Path.from(actualPath)
      ..lineTo(currentX, height)
      ..lineTo(0, height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          primaryColor.withValues(alpha: 0.25),
          primaryColor.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, currentX, height));

    canvas.drawPath(fillPath, fillPaint);

    // Actual progress stroke
    final actualStrokePaint = Paint()
      ..color = primaryColor
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawPath(actualPath, actualStrokePaint);

    // Draw pulsating indicator dot at current progress point
    final haloPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(currentX, targetY), 10, haloPaint);

    final dotPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(currentX, targetY), 5, dotPaint);

    final innerDotPaint = Paint()
      ..color = indicatorDotColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(currentX, targetY), 2.5, innerDotPaint);
  }

  @override
  bool shouldRepaint(covariant _TrajectoryPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.indicatorDotColor != indicatorDotColor;
  }
}
