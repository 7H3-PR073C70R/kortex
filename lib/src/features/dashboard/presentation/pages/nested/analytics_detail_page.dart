import 'dart:ui';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';

@RoutePage()
class AnalyticsDetailPage extends StatelessWidget {
  const AnalyticsDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF090D16)
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Semantics(
          button: true,
          label: 'Back to Dashboard',
          child: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: colors.textPrimary),
            onPressed: () => context.router.pop(),
          ),
        ),
        title: Text(
          'Neural Analytics & Retention',
          style: typography.title3.bold.copyWith(color: colors.textPrimary),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          physics: const BouncingScrollPhysics(),
          children: [
            // Streak Card
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark
                        ? colors.surfaceSecondary.withAlpha(190)
                        : colors.surfacePrimary.withAlpha(230),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: const Color(
                        0xFFF97316,
                      ).withAlpha(isDark ? 90 : 60),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFF97316).withAlpha(40),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.local_fire_department_rounded,
                          size: 28,
                          color: Color(0xFFF97316),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '14 Day Study Streak 🔥',
                              style: typography.title3.bold.copyWith(
                                color: colors.textPrimary,
                                fontSize: 17,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Your record is 28 days. Keep studying to '
                              'reach Neural Master rank!',
                              style: typography.footnote.regular.copyWith(
                                color: colors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'Memory Retention Curve (Ebbinghaus SM-2)',
              style: typography.title3.bold.copyWith(
                color: colors.textPrimary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),

            // Retention Breakdown List
            _SubjectRetentionRow(
              subject: 'Advanced Mathematics (MTH 301)',
              retention: 0.94,
              masteredCount: 142,
              colors: colors,
              isDark: isDark,
            ),
            const SizedBox(height: 10),
            _SubjectRetentionRow(
              subject: 'Electromagnetism (PHY 202)',
              retention: 0.88,
              masteredCount: 98,
              colors: colors,
              isDark: isDark,
            ),
            const SizedBox(height: 10),
            _SubjectRetentionRow(
              subject: 'Data Structures (CSC 310)',
              retention: 0.82,
              masteredCount: 165,
              colors: colors,
              isDark: isDark,
            ),
            const SizedBox(height: 10),
            _SubjectRetentionRow(
              subject: 'Organic Chemistry (CHM 201)',
              retention: 0.74,
              masteredCount: 81,
              colors: colors,
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectRetentionRow extends StatelessWidget {
  const _SubjectRetentionRow({
    required this.subject,
    required this.retention,
    required this.masteredCount,
    required this.colors,
    required this.isDark,
  });

  final String subject;
  final double retention;
  final int masteredCount;
  final AppThemeColorsExtension colors;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final typography = context.typography;
    final percent = (retention * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfaceSecondary.withAlpha(140)
            : colors.surfacePrimary.withAlpha(200),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? colors.surfaceBorderHighlight.withAlpha(60)
              : colors.surfaceBorder.withAlpha(120),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  subject,
                  style: typography.caption.bold.copyWith(
                    color: colors.textPrimary,
                    fontSize: 13.5,
                  ),
                ),
              ),
              Text(
                '$percent%',
                style: typography.caption.bold.copyWith(
                  color: percent >= 85
                      ? const Color(0xFF10B981)
                      : colors.primary,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: retention,
              backgroundColor: isDark
                  ? colors.surfaceBorderHighlight.withAlpha(50)
                  : colors.surfaceBorder.withAlpha(100),
              valueColor: AlwaysStoppedAnimation(
                percent >= 85 ? const Color(0xFF10B981) : colors.primary,
              ),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$masteredCount concept cards mastered in active recall',
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
