import 'dart:async';
import 'dart:math' as math;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/dashboard/domain/logic/cbt_readiness_calculator.dart';

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
    super.key,
  });

  final CbtReadinessResult readinessResult;
  final String examTitle;
  final int daysRemaining;

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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
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
                      painter: _ReadinessGaugePainter(
                        // Arc sweeps from 0 → target score.
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
                              '${(readinessResult.scorePercent * _arcAnimation.value).round()}%',
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
            if (readinessResult.remediationSuggestion.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return DraggableScrollableSheet(
            initialChildSize: 0.78,
            maxChildSize: 0.92,
            minChildSize: 0.50,
            builder: (context, scrollController) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: BoxDecoration(
                  color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
                ),
                child: ListView(
                  controller: scrollController,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.textMuted.withAlpha(100),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'CBT Readiness Breakdown',
                          style: typography.title2.bold.copyWith(color: colors.textPrimary),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: widget.readinessResult.statusColor.withAlpha(30),
                            borderRadius: BorderRadius.circular(AppRadius.badge),
                          ),
                          child: Text(
                            widget.readinessResult.statusLabel,
                            style: typography.caption.bold.copyWith(color: widget.readinessResult.statusColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Diagnostic analysis for ${widget.examTitle} (${widget.daysRemaining} days remaining)',
                      style: typography.body.medium.copyWith(color: colors.textSecondary),
                    ),
                    const SizedBox(height: 18),

                    // Projected Score vs Target Goal Banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            widget.readinessResult.statusColor.withAlpha(isDark ? 50 : 30),
                            colors.primary.withAlpha(isDark ? 30 : 15),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        border: Border.all(color: widget.readinessResult.statusColor.withAlpha(80)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'PROJECTED EXAM SCORE',
                                  style: typography.caption.bold.copyWith(
                                    color: colors.textSecondary,
                                    fontSize: 10.5,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.readinessResult.projectedScoreRange,
                                  style: typography.title3.bold.copyWith(color: colors.textPrimary),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDark ? colors.surfacePrimary : colors.surfaceSecondary,
                              borderRadius: BorderRadius.circular(AppRadius.badge),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Pacing Rate',
                                  style: typography.caption.regular.copyWith(color: colors.textSecondary, fontSize: 10),
                                ),
                                Text(
                                  widget.readinessResult.speedDiagnosticLabel,
                                  style: typography.caption.bold.copyWith(
                                    color: widget.readinessResult.speedReadinessRatio >= 0.8 ? colors.success : colors.warning,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Subject Mastery Breakdown Header for Registered Courses
                    if (widget.readinessResult.subjectBreakdowns.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'REGISTERED COURSES BREAKDOWN',
                            style: typography.caption.bold.copyWith(
                              color: colors.textSecondary,
                              letterSpacing: 1.1,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: colors.primary.withAlpha(20),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${widget.readinessResult.subjectBreakdowns.length} Enrolled Courses',
                              style: typography.caption.bold.copyWith(color: colors.primary, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ...widget.readinessResult.subjectBreakdowns.map(
                        (sub) => Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: colors.surfacePrimary.withAlpha(isDark ? 80 : 200),
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            border: Border.all(color: colors.surfaceBorder.withAlpha(60)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      sub.subjectName,
                                      style: typography.body.bold.copyWith(color: colors.textPrimary),
                                    ),
                                  ),
                                  Text(
                                    sub.projectedGrade.isNotEmpty
                                        ? '${sub.projectedScore} / ${sub.maxScore} pts (${sub.projectedGrade})'
                                        : '${sub.projectedScore} / ${sub.maxScore} pts',
                                    style: typography.body.bold.copyWith(
                                      color: sub.statusColor ?? colors.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    'Syllabus: ${(sub.coveragePercent * 100).round()}%',
                                    style: typography.caption.regular.copyWith(
                                      color: colors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Accuracy: ${(sub.accuracyPercent * 100).round()}%',
                                    style: typography.caption.regular.copyWith(
                                      color: colors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(AppRadius.micro),
                                      child: LinearProgressIndicator(
                                        value: sub.readinessPercent / 100.0,
                                        minHeight: 6,
                                        backgroundColor: colors.surfaceBorder.withAlpha(60),
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          sub.statusColor ?? colors.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    '${sub.readinessPercent}%',
                                    style: typography.caption.bold.copyWith(color: colors.textSecondary),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Primary Bottleneck Diagnostic
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.surfacePrimary.withAlpha(isDark ? 60 : 200),
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        border: Border.all(color: colors.surfaceBorder.withAlpha(60)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: widget.readinessResult.statusColor, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Primary Bottleneck Diagnostic',
                                style: typography.caption.bold.copyWith(color: colors.textSecondary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.readinessResult.weakestAreaLabel.isNotEmpty
                                ? widget.readinessResult.weakestAreaLabel
                                : 'Memory Retention Stability',
                            style: typography.body.bold.copyWith(color: colors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Actionable Remediation
                    Text(
                      'RECOMMENDED ACTION',
                      style: typography.caption.bold.copyWith(
                        color: colors.textSecondary,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.primary.withAlpha(isDark ? 40 : 20),
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        border: Border.all(color: colors.primary.withAlpha(80)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.bolt_rounded, color: colors.primary, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.readinessResult.remediationSuggestion,
                              style: typography.body.medium.copyWith(color: colors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              final prompt =
                                  'Help me review ${widget.readinessResult.weakestAreaLabel.isNotEmpty ? widget.readinessResult.weakestAreaLabel : "key concepts"} to boost my $widget.examTitle readiness score.';
                              unawaited(
                                context.router.push(
                                  SyllabotChatRoute(initialPrompt: prompt),
                                ),
                              );
                            },
                            icon: Icon(
                              Icons.auto_awesome_rounded,
                              size: 18,
                              color: colors.primary,
                            ),
                            label: Text(
                              'AI Sprint',
                              style: typography.body.medium.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.card),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.pop(context),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.card),
                              ),
                            ),
                            child: const Text('Back'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
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
