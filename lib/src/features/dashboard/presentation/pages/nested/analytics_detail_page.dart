import 'dart:ui';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/l10n/l10n.dart';

@RoutePage()
class AnalyticsDetailPage extends StatelessWidget {
  const AnalyticsDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colors.textPrimary),
          onPressed: () => context.router.pop(),
        ),
        title: Text(
          l10n.analyticsDetailTitle,
          style: typography.title3.bold.copyWith(color: colors.textPrimary),
        ),
        centerTitle: true,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          // Streak Showcase Banner
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [Color(0xFFEA580C), Color(0xFFF97316)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEA580C).withAlpha(80),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.analyticsStreakDays(14),
                    style: typography.title2.bold.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.analyticsStreakRecord,
                    style: typography.footnote.regular.copyWith(
                      color: Colors.white.withAlpha(220),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Retention Curve Breakdown
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: isDark
                      ? colors.surfaceSecondary.withAlpha(160)
                      : colors.surfacePrimary.withAlpha(210),
                  border: Border.all(
                    color: isDark
                        ? colors.surfaceBorderHighlight.withAlpha(70)
                        : colors.surfaceBorder.withAlpha(140),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.analyticsRetentionCurveTitle,
                      style: typography.caption.bold.copyWith(
                        color: colors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.analyticsMasteredCountSubtitle(240),
                      style: typography.footnote.regular.copyWith(
                        color: colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Progress indicators by subject
                    _SubjectRetentionBar(
                      subject: 'Engineering Mathematics',
                      retention: 0.92,
                      color: colors.primary,
                    ),
                    const SizedBox(height: 12),
                    _SubjectRetentionBar(
                      subject: 'Electromagnetism & Circuit Theory',
                      retention: 0.84,
                      color: colors.syllabotAccent,
                    ),
                    const SizedBox(height: 12),
                    const _SubjectRetentionBar(
                      subject: 'Thermodynamics & Fluid Mechanics',
                      retention: 0.78,
                      color: Color(0xFFF97316),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectRetentionBar extends StatelessWidget {
  const _SubjectRetentionBar({
    required this.subject,
    required this.retention,
    required this.color,
  });

  final String subject;
  final double retention;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final percent = (retention * 100).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              subject,
              style: typography.footnote.bold.copyWith(
                color: colors.textPrimary,
                fontSize: 12,
              ),
            ),
            Text(
              '$percent%',
              style: typography.footnote.bold.copyWith(
                color: color,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Container(
            height: 6,
            color: isDark
                ? colors.surfaceBorderHighlight.withAlpha(50)
                : colors.surfaceBorder.withAlpha(100),
            child: FractionallySizedBox(
              widthFactor: retention.clamp(0.05, 1.0),
              child: Container(color: color),
            ),
          ),
        ),
      ],
    );
  }
}
