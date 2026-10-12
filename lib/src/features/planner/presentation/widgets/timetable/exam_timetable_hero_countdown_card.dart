import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/features/planner/domain/entities/exam_event_entity.dart';

/// Hero Active Countdown Display for the primary tracked assessment.
class ExamTimetableHeroCountdownCard extends StatelessWidget {
  const ExamTimetableHeroCountdownCard({
    required this.exam,
    super.key,
  });

  final ExamEventEntity exam;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final days = exam.timeRemaining.inDays;
    final hours = exam.hoursRemaining;
    final minutes = exam.minutesRemaining;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primary,
            colors.primary.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: AppRadius.radiusDialog,
        boxShadow: [
          BoxShadow(
            color: colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.white.withValues(alpha: 0.2),
                    borderRadius: AppRadius.radiusBadge,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(exam.assessmentType.icon, size: 13, color: colors.white),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          '${exam.assessmentType.displayName.toUpperCase()} • ${exam.subjectTrack.toUpperCase()}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: typography.caption.bold.copyWith(
                            color: colors.white,
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (exam.weightPercent != null)
                Text(
                  '${(exam.weightPercent! * 100).toInt()}% OF GRADE',
                  style: typography.caption.bold.copyWith(
                    color: colors.white.withValues(alpha: 0.85),
                    letterSpacing: 1,
                  ),
                )
              else
                Text(
                  'ACTIVE TIMETABLE',
                  style: typography.caption.bold.copyWith(
                    color: colors.white.withValues(alpha: 0.8),
                    letterSpacing: 1.1,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            exam.examName,
            style: typography.title2.bold.copyWith(color: colors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            DateFormat('EEEE, MMMM d, y • hh:mm a').format(exam.targetDate),
            style: typography.caption.regular.copyWith(
              color: colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 20),

          // Digits row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTimeDigit(context, days.toString(), 'DAYS', colors),
              Text(
                ':',
                style: typography.title1.bold.copyWith(
                  color: colors.white.withValues(alpha: 0.7),
                ),
              ),
              _buildTimeDigit(
                context,
                hours.toString().padLeft(2, '0'),
                'HOURS',
                colors,
              ),
              Text(
                ':',
                style: typography.title1.bold.copyWith(
                  color: colors.white.withValues(alpha: 0.7),
                ),
              ),
              _buildTimeDigit(
                context,
                minutes.toString().padLeft(2, '0'),
                'MINUTES',
                colors,
              ),
            ],
          ),
        ],
      ),
    ).animate()
      .fadeIn(duration: 400.ms, curve: Curves.easeOut)
      .scale(
        begin: const Offset(0.95, 0.95),
        end: const Offset(1, 1),
        duration: 400.ms,
        curve: Curves.easeOutQuint,
      );
  }

  Widget _buildTimeDigit(
    BuildContext context,
    String value,
    String label,
    AppThemeColorsExtension colors,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: colors.white.withValues(alpha: 0.2),
            borderRadius: AppRadius.radiusCard,
          ),
          child: Text(
            value,
            style: context.typography.body.regular.copyWith(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: colors.white,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: context.typography.body.regular.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: colors.white.withValues(alpha: 0.7),
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}
