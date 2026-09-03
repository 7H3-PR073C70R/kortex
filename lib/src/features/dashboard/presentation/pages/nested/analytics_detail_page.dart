import 'dart:async';
import 'dart:ui';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:intl/intl.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/dashboard/domain/entities/analytics_summary_entity.dart';
import 'package:kortex/src/features/dashboard/domain/entities/dashboard_feed_entity.dart';
import 'package:kortex/src/features/dashboard/domain/logic/ebbinghaus_decay_calculator.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_state.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/adaptive_retention_chart.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_liquid_glass_tab_bar.dart';
import 'package:kortex/src/shared/widgets/shimmer_placeholder.dart';
import 'package:kortex/src/shared/widgets/syllabot_avatar.dart';

@RoutePage()
class AnalyticsDetailPage extends HookWidget {
  const AnalyticsDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DashboardBloc>.value(
      value: locator<DashboardBloc>(),
      child: const _AnalyticsDetailView(),
    );
  }
}

class _AnalyticsDetailView extends HookWidget {
  const _AnalyticsDetailView();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final selectedFilterIndex = useState<int>(0);
    const filterOptions = ['Last 7 Days', 'Last 30 Days', 'All Time'];

    return Scaffold(
      backgroundColor: isDark
          ? colors.backgroundPrimary
          : colors.surfacePrimary,
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
      body: BlocBuilder<DashboardBloc, DashboardState>(
        builder: (context, state) {
          if (state.isLoading && state.feed == null) {
            return const _AnalyticsShimmerSkeleton();
          }

          final feed = state.feed;
          final analytics = feed?.analyticsSummary ?? _buildEmptyAnalytics();
          final courses = feed?.curatedCourses ?? const <CuratedCourseEntity>[];

          final hasData =
              analytics.totalCardsMastered > 0 ||
              analytics.weeklyMinutesStudied > 0;

          var retentionPoints = const <DailyRetentionPoint>[];
          if (hasData) {
            const decayCalculator = EbbinghausDecayCalculator();
            retentionPoints = decayCalculator.calculateSevenDayProjection(
              cardStabilities: [4.5, 6.2, 5.0],
              empiricalRecallRates: [
                1.0,
                analytics.overallRetentionRate,
                analytics.overallRetentionRate * 0.95,
              ],
            );
          }

          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 60),
            children: [
              // 1. Reusable Liquid Glass Tab Bar
              AppLiquidGlassTabBar(
                tabs: filterOptions,
                selectedIndex: selectedFilterIndex.value,
                onTabSelected: (index) {
                  selectedFilterIndex.value = index;
                },
              ),
              const SizedBox(height: 18),

              // 2. Executive Performance Overview (4-Grid KPI Cards)
              _ExecutiveKpiGrid(analytics: analytics),
              const SizedBox(height: 20),

              // 3. Ebbinghaus Memory Decay & Retention Curve
              AdaptiveRetentionChart(points: retentionPoints),
              const SizedBox(height: 20),

              // 4. Weekly Study Volume & Velocity Bar Chart
              _WeeklyVelocityChart(
                analytics: analytics,
                colors: colors,
                isDark: isDark,
              ),
              const SizedBox(height: 20),

              // 5. Active 28-Day Consistency Matrix
              _DetailedHeatMapCard(
                analytics: analytics,
                colors: colors,
                isDark: isDark,
              ),
              const SizedBox(height: 20),

              // 6. Subject-by-Subject Syllabus Mastery Breakdown
              _SubjectMasteryCard(
                courses: courses,
                colors: colors,
                isDark: isDark,
              ),
              const SizedBox(height: 20),

              // 7. Syllabot Cognitive Diagnostics & Smart Recommendations
              _SyllabotCognitiveInsightsCard(
                insightText: feed?.syllabotDailyInsight,
                hasData: hasData,
                colors: colors,
                isDark: isDark,
              ),
            ],
          );
        },
      ),
    );
  }

  static AnalyticsSummaryEntity _buildEmptyAnalytics() {
    final now = DateTime.now();
    final heatMap = List.generate(28, (i) {
      final day = now.subtract(Duration(days: 27 - i));
      return HeatMapDayEntity(
        date: day,
        intensityLevel: 0,
        cardsReviewed: 0,
        minutesStudied: 0,
      );
    });

    return AnalyticsSummaryEntity(
      currentStreakDays: 0,
      longestStreakDays: 0,
      weeklyMinutesStudied: 0,
      overallRetentionRate: 0,
      totalCardsMastered: 0,
      heatMapData: heatMap,
      xpPoints: 0,
      academicRank: 'Neural Scholar I',
    );
  }
}

/// Shimmer Skeleton Loader matching Analytics Page layout
class _AnalyticsShimmerSkeleton extends StatelessWidget {
  const _AnalyticsShimmerSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 60),
      children: const [
        // Tab bar shimmer
        ShimmerPlaceholder(height: 42, borderRadius: 21),
        SizedBox(height: 18),

        // 2x2 KPI Cards Shimmer
        Row(
          children: [
            Expanded(child: ShimmerPlaceholder(height: 120, borderRadius: 18)),
            SizedBox(width: 12),
            Expanded(child: ShimmerPlaceholder(height: 120, borderRadius: 18)),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: ShimmerPlaceholder(height: 120, borderRadius: 18)),
            SizedBox(width: 12),
            Expanded(child: ShimmerPlaceholder(height: 120, borderRadius: 18)),
          ],
        ),
        SizedBox(height: 20),

        // Chart Shimmer
        ShimmerPlaceholder(height: 260, borderRadius: 22),
        SizedBox(height: 20),

        // Velocity Chart Shimmer
        ShimmerPlaceholder(height: 180, borderRadius: 22),
        SizedBox(height: 20),

        // Heatmap Shimmer
        ShimmerPlaceholder(height: 200, borderRadius: 22),
      ],
    );
  }
}

/// 4-Card Executive KPI Matrix
class _ExecutiveKpiGrid extends StatelessWidget {
  const _ExecutiveKpiGrid({required this.analytics});

  final AnalyticsSummaryEntity analytics;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;

    final overallRetention = (analytics.overallRetentionRate * 100).toInt();
    final hasRetention = overallRetention > 0;
    final hasCards = analytics.totalCardsMastered > 0;
    final hasStudyTime = analytics.weeklyMinutesStudied > 0;
    final hasStreak = analytics.currentStreakDays > 0;
    final weeklyHours = (analytics.weeklyMinutesStudied / 60).toStringAsFixed(
      1,
    );

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _KpiMetricCard(
                title: 'Retention Index',
                value: hasRetention ? '$overallRetention%' : '0%',
                subtitle: hasRetention
                    ? 'Active Recall Rate'
                    : 'No review data yet',
                badgeText: hasRetention ? 'Optimal' : 'Baseline',
                icon: Icons.psychology_rounded,
                accentColor: colors.success,
                colors: colors,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _KpiMetricCard(
                title: 'Cards Mastered',
                value: '${analytics.totalCardsMastered}',
                subtitle: hasCards
                    ? '${analytics.totalCardsMastered} Active SM-2'
                    : '0 Active Cards',
                badgeText: hasCards ? 'Active' : 'Empty',
                icon: Icons.style_rounded,
                accentColor: colors.primary,
                colors: colors,
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _KpiMetricCard(
                title: 'Study Velocity',
                value: '${analytics.weeklyMinutesStudied}m',
                subtitle: hasStudyTime
                    ? '$weeklyHours hrs this week'
                    : '0.0 hrs this week',
                badgeText: hasStudyTime ? 'On Track' : 'Idle',
                icon: Icons.timer_rounded,
                accentColor: colors.syllabotAccent,
                colors: colors,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _KpiMetricCard(
                title: 'Study Streak',
                value: '${analytics.currentStreakDays} Days 🔥',
                subtitle: hasStreak
                    ? 'Record: ${analytics.longestStreakDays} days'
                    : 'Start a streak today',
                badgeText: analytics.academicRank.isNotEmpty
                    ? analytics.academicRank.split(' ').last
                    : 'Rank I',
                icon: Icons.local_fire_department_rounded,
                accentColor: colors.warning,
                colors: colors,
                isDark: isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _KpiMetricCard extends StatelessWidget {
  const _KpiMetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.badgeText,
    required this.icon,
    required this.accentColor,
    required this.colors,
    required this.isDark,
  });

  final String title;
  final String value;
  final String subtitle;
  final String badgeText;
  final IconData icon;
  final Color accentColor;
  final AppThemeColorsExtension colors;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final typography = context.typography;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? colors.surfaceSecondary.withAlpha(160)
                : colors.surfacePrimary.withAlpha(220),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? colors.surfaceBorderHighlight.withAlpha(60)
                  : colors.surfaceBorder.withAlpha(130),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 30 : 8),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: accentColor.withAlpha(isDark ? 45 : 25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 15, color: accentColor),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2.5,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor.withAlpha(isDark ? 35 : 18),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: accentColor.withAlpha(isDark ? 70 : 35),
                        width: 0.6,
                      ),
                    ),
                    child: Text(
                      badgeText,
                      style: typography.footnote.bold.copyWith(
                        color: accentColor,
                        fontSize: 9.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: typography.footnote.medium.copyWith(
                  color: colors.textSecondary,
                  fontSize: 11.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: typography.title3.bold.copyWith(
                  color: colors.textPrimary,
                  fontSize: 19,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: typography.footnote.regular.copyWith(
                  color: colors.textSecondary.withAlpha(180),
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Weekly Velocity Daily Study Time Bar Chart
class _WeeklyVelocityChart extends StatelessWidget {
  const _WeeklyVelocityChart({
    required this.analytics,
    required this.colors,
    required this.isDark,
  });

  final AnalyticsSummaryEntity analytics;
  final AppThemeColorsExtension colors;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final typography = context.typography;
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const targetMinutes = 45;

    final recentDays = analytics.heatMapData.length >= 7
        ? analytics.heatMapData.sublist(analytics.heatMapData.length - 7)
        : analytics.heatMapData;

    final dayMinutesList = List.generate(7, (i) {
      if (i < recentDays.length) {
        return recentDays[i].minutesStudied;
      }
      return 0;
    });

    final totalWeekMins = dayMinutesList.fold<int>(
      0,
      (sum, mins) => sum + mins,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark
                ? colors.surfaceSecondary.withAlpha(160)
                : colors.surfacePrimary.withAlpha(220),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark
                  ? colors.surfaceBorderHighlight.withAlpha(70)
                  : colors.surfaceBorder.withAlpha(140),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.bar_chart_rounded,
                        size: 16,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Weekly Study Volume',
                        style: typography.title3.bold.copyWith(
                          color: colors.textPrimary,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    totalWeekMins > 0
                        ? 'Total: ${totalWeekMins}m'
                        : 'Goal: ${targetMinutes}m/day',
                    style: typography.caption.medium.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Bar Chart Columns
              SizedBox(
                height: 120,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(7, (i) {
                    final dayMins = dayMinutesList[i];
                    final isGoalMet = dayMins >= targetMinutes;
                    final heightFactor = (dayMins / 90.0).clamp(0.08, 1.0);

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${dayMins}m',
                          style: typography.footnote.bold.copyWith(
                            color: isGoalMet
                                ? colors.primary
                                : colors.textSecondary.withAlpha(160),
                            fontSize: 9.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 26,
                          height: dayMins > 0 ? (75 * heightFactor) : 6,
                          decoration: BoxDecoration(
                            gradient: dayMins > 0
                                ? LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: isGoalMet
                                        ? [
                                            colors.primary,
                                            colors.primary.withAlpha(150),
                                          ]
                                        : [
                                            colors.surfaceBorderHighlight
                                                .withAlpha(180),
                                            colors.surfaceBorder.withAlpha(100),
                                          ],
                                  )
                                : null,
                            color: dayMins == 0
                                ? (isDark
                                      ? colors.surfaceBorderHighlight.withAlpha(
                                          30,
                                        )
                                      : colors.surfaceBorder.withAlpha(60))
                                : null,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          weekdays[i],
                          style: typography.footnote.medium.copyWith(
                            color: colors.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Detailed 28-Day Consistency Matrix with Day Inspector
class _DetailedHeatMapCard extends StatefulWidget {
  const _DetailedHeatMapCard({
    required this.analytics,
    required this.colors,
    required this.isDark,
  });

  final AnalyticsSummaryEntity analytics;
  final AppThemeColorsExtension colors;
  final bool isDark;

  @override
  State<_DetailedHeatMapCard> createState() => _DetailedHeatMapCardState();
}

class _DetailedHeatMapCardState extends State<_DetailedHeatMapCard> {
  HeatMapDayEntity? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final typography = context.typography;
    final isDark = widget.isDark;
    const weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    final hasActivity = widget.analytics.heatMapData.any(
      (d) => d.cardsReviewed > 0 || d.minutesStudied > 0,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark
                ? colors.surfaceSecondary.withAlpha(160)
                : colors.surfacePrimary.withAlpha(220),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark
                  ? colors.surfaceBorderHighlight.withAlpha(70)
                  : colors.surfaceBorder.withAlpha(140),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_month_rounded,
                        size: 16,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Study Consistency Grid',
                        style: typography.title3.bold.copyWith(
                          color: colors.textPrimary,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    hasActivity ? 'Active Habit' : 'Past 28 Days',
                    style: typography.caption.bold.copyWith(
                      color: hasActivity
                          ? colors.success
                          : colors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Weekday Headers
              LayoutBuilder(
                builder: (context, constraints) {
                  final cellWidth = ((constraints.maxWidth - (6 * 6)) / 7)
                      .clamp(16.0, 42.0);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: weekdayLabels.map((day) {
                          return SizedBox(
                            width: cellWidth,
                            child: Text(
                              day,
                              textAlign: TextAlign.center,
                              style: typography.footnote.bold.copyWith(
                                color: colors.textSecondary.withAlpha(160),
                                fontSize: 9.5,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),

                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: widget.analytics.heatMapData.map((day) {
                          final isSelected = _selectedDay == day;
                          final color = _getIntensityColor(
                            day.intensityLevel,
                            colors,
                            isDark,
                          );

                          return InkWell(
                            onTap: () {
                              unawaited(HapticFeedback.selectionClick());
                              setState(() {
                                _selectedDay = isSelected ? null : day;
                              });
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: cellWidth,
                              height: cellWidth,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isSelected
                                      ? colors.textPrimary
                                      : (day.intensityLevel > 0
                                            ? colors.primary.withAlpha(
                                                isDark ? 90 : 50,
                                              )
                                            : Colors.transparent),
                                  width: isSelected ? 1.8 : 0.8,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: colors.primary.withAlpha(100),
                                          blurRadius: 6,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),

              // Selected Day Inspector Tooltip
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _selectedDay != null
                      ? colors.primary.withAlpha(isDark ? 35 : 15)
                      : (isDark
                            ? colors.surfacePrimary.withAlpha(80)
                            : colors.surfaceSecondary.withAlpha(90)),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _selectedDay != null
                        ? colors.primary.withAlpha(isDark ? 80 : 40)
                        : colors.surfaceBorder.withAlpha(isDark ? 40 : 80),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_selectedDay != null) ...[
                      Text(
                        DateFormat('EEEE, MMM d').format(_selectedDay!.date),
                        style: typography.footnote.bold.copyWith(
                          color: colors.textPrimary,
                          fontSize: 11.5,
                        ),
                      ),
                      Text(
                        '${_selectedDay!.cardsReviewed} cards reviewed • '
                        '${_selectedDay!.minutesStudied}m studied',
                        style: typography.footnote.medium.copyWith(
                          color: colors.primary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ] else ...[
                      Text(
                        hasActivity
                            ? 'Tap any day to inspect study performance'
                            : 'No study activity in past 28 days',
                        style: typography.footnote.regular.copyWith(
                          color: colors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Less',
                            style: typography.footnote.regular.copyWith(
                              color: colors.textSecondary.withAlpha(160),
                              fontSize: 9.5,
                            ),
                          ),
                          const SizedBox(width: 4),
                          ...List.generate(5, (lvl) {
                            return Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.symmetric(
                                horizontal: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: _getIntensityColor(
                                  lvl,
                                  colors,
                                  isDark,
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            );
                          }),
                          const SizedBox(width: 4),
                          Text(
                            'More',
                            style: typography.footnote.regular.copyWith(
                              color: colors.textSecondary.withAlpha(160),
                              fontSize: 9.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getIntensityColor(
    int level,
    AppThemeColorsExtension colors,
    bool isDark,
  ) {
    switch (level) {
      case 0:
        return isDark
            ? colors.surfaceBorderHighlight.withAlpha(30)
            : colors.surfaceBorder.withAlpha(60);
      case 1:
        return colors.primary.withAlpha(isDark ? 60 : 45);
      case 2:
        return colors.primary.withAlpha(isDark ? 120 : 90);
      case 3:
        return colors.primary.withAlpha(isDark ? 190 : 160);
      case 4:
      default:
        return colors.primary;
    }
  }
}

/// Subject & Syllabus Mastery Breakdown Card
class _SubjectMasteryCard extends StatelessWidget {
  const _SubjectMasteryCard({
    required this.courses,
    required this.colors,
    required this.isDark,
  });

  final List<CuratedCourseEntity> courses;
  final AppThemeColorsExtension colors;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final typography = context.typography;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark
                ? colors.surfaceSecondary.withAlpha(160)
                : colors.surfacePrimary.withAlpha(220),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark
                  ? colors.surfaceBorderHighlight.withAlpha(70)
                  : colors.surfaceBorder.withAlpha(140),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.school_rounded,
                        size: 16,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Course Mastery Matrix',
                        style: typography.title3.bold.copyWith(
                          color: colors.textPrimary,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${courses.length} Enrolled',
                    style: typography.caption.medium.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (courses.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Icon(
                        Icons.library_books_rounded,
                        size: 28,
                        color: colors.textSecondary.withAlpha(120),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No enrolled courses yet',
                        style: typography.footnote.bold.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Import a syllabus or course materials to '
                        'track mastery',
                        textAlign: TextAlign.center,
                        style: typography.caption.regular.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...courses.map((course) {
                  final percent = (course.syllabusCoverage * 100).toInt();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colors.primary.withAlpha(
                                        isDark ? 40 : 20,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      course.courseCode,
                                      style: typography.footnote.bold.copyWith(
                                        color: colors.primary,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      course.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: typography.footnote.bold.copyWith(
                                        color: colors.textPrimary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$percent%',
                              style: typography.footnote.bold.copyWith(
                                color: colors.primary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  height: 6,
                                  color: isDark
                                      ? colors.surfaceBorderHighlight.withAlpha(
                                          40,
                                        )
                                      : colors.surfaceBorder.withAlpha(80),
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: course.syllabusCoverage.clamp(
                                      0.05,
                                      1.0,
                                    ),
                                    child: Container(color: colors.primary),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${course.totalMaterials} materials',
                              style: typography.footnote.regular.copyWith(
                                color: colors.textSecondary,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}

/// Syllabot Cognitive Insights & Action Recommendations
class _SyllabotCognitiveInsightsCard extends StatelessWidget {
  const _SyllabotCognitiveInsightsCard({
    required this.insightText,
    required this.hasData,
    required this.colors,
    required this.isDark,
  });

  final String? insightText;
  final bool hasData;
  final AppThemeColorsExtension colors;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final typography = context.typography;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.primary.withAlpha(isDark ? 40 : 20),
                (isDark ? colors.surfaceSecondary : colors.surfacePrimary)
                    .withAlpha(isDark ? 160 : 220),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: colors.primary.withAlpha(isDark ? 80 : 50),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const SyllabotAvatar(size: 26),
                  const SizedBox(width: 8),
                  Text(
                    'Syllabot Cognitive Diagnostics',
                    style: typography.title3.bold.copyWith(
                      color: colors.textPrimary,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (insightText != null && insightText!.isNotEmpty) ...[
                _InsightRow(
                  icon: Icons.psychology_rounded,
                  iconColor: colors.primary,
                  title: 'Daily AI Synthesis',
                  description: insightText!,
                  colors: colors,
                ),
                const SizedBox(height: 12),
              ],
              if (hasData) ...[
                _InsightRow(
                  icon: Icons.lightbulb_outline_rounded,
                  iconColor: colors.warning,
                  title: 'Peak Recall Focus Window',
                  description:
                      'Active recall retention is highest during morning '
                      'study sessions. Review cards early for maximum '
                      'consolidation.',
                  colors: colors,
                ),
                const SizedBox(height: 12),
                _InsightRow(
                  icon: Icons.alarm_rounded,
                  iconColor: colors.success,
                  title: 'Memory Consolidation Tracking',
                  description:
                      'Daily spaced reviews prevent Ebbinghaus forgetting '
                      'decay and promote long-term neural retention.',
                  colors: colors,
                ),
              ] else ...[
                _InsightRow(
                  icon: Icons.tips_and_updates_rounded,
                  iconColor: colors.primary,
                  title: 'Getting Started with Spaced Repetition',
                  description:
                      'Create your first study deck or import lecture '
                      'materials. Syllabot will generate automated flashcards '
                      'and track your active recall retention score.',
                  colors: colors,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.colors,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final AppThemeColorsExtension colors;

  @override
  Widget build(BuildContext context) {
    final typography = context.typography;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: typography.footnote.bold.copyWith(
                  color: colors.textPrimary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: typography.caption.regular.copyWith(
                  color: colors.textSecondary,
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
