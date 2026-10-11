import 'dart:async';
import 'dart:math' as math;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/services/user_activity_service.dart';
import 'package:kortex/src/core/utils/app_logger.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_event.dart';
import 'package:kortex/src/features/dashboard/domain/entities/dashboard_feed_entity.dart';
import 'package:kortex/src/features/dashboard/domain/logic/ebbinghaus_decay_calculator.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_state.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/adaptive_retention_chart.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/analytics_cognitive_insights_card.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/analytics_heatmap_card.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/analytics_kpi_grid.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/analytics_neural_repair_sheet.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/analytics_shimmer_skeleton.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/analytics_subject_mastery_card.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/analytics_timeframe_filter_helper.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/analytics_weekly_velocity_chart.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/streak_shield_indicator.dart';
import 'package:kortex/src/features/monetization/domain/services/subscription_guard.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_app_bar.dart';
import 'package:kortex/src/shared/widgets/app_breadcrumbs.dart';
import 'package:kortex/src/shared/widgets/app_liquid_glass_tab_bar.dart';

@RoutePage()
class AnalyticsDetailPage extends HookWidget {
  const AnalyticsDetailPage({
    super.key,
    this.dashboardBloc,
    this.activityService,
    this.authBloc,
    this.subscriptionGuard,
  });

  final DashboardBloc? dashboardBloc;
  final UserActivityService? activityService;
  final AuthBloc? authBloc;
  final SubscriptionGuard? subscriptionGuard;

  @override
  Widget build(BuildContext context) {
    final effectiveBloc = dashboardBloc ??
        (locator.isRegistered<DashboardBloc>()
            ? locator<DashboardBloc>()
            : null);
    final effectiveActivityService = activityService ??
        (locator.isRegistered<UserActivityService>()
            ? locator<UserActivityService>()
            : null);
    final effectiveAuthBloc = authBloc ??
        (locator.isRegistered<AuthBloc>()
            ? locator<AuthBloc>()
            : null);
    final effectiveSubscriptionGuard = subscriptionGuard ??
        (locator.isRegistered<SubscriptionGuard>()
            ? locator<SubscriptionGuard>()
            : null);

    useEffect(() {
      effectiveBloc?.add(const DashboardStarted());
      final subscription =
          effectiveActivityService?.analyticsSummaryStream.listen((_) {
        effectiveBloc?.add(const DashboardRefreshed());
      });
      return () {
        unawaited(subscription?.cancel());
      };
    }, [effectiveBloc, effectiveActivityService]);

    final view = AnalyticsDetailView(
      activityService: effectiveActivityService,
      authBloc: effectiveAuthBloc,
      subscriptionGuard: effectiveSubscriptionGuard,
    );

    if (effectiveBloc != null) {
      return BlocProvider<DashboardBloc>.value(
        value: effectiveBloc,
        child: view,
      );
    }

    return view;
  }
}

class AnalyticsDetailView extends HookWidget {
  const AnalyticsDetailView({
    super.key,
    this.activityService,
    this.authBloc,
    this.subscriptionGuard,
  });

  final UserActivityService? activityService;
  final AuthBloc? authBloc;
  final SubscriptionGuard? subscriptionGuard;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final selectedFilterIndex = useState<int>(0);
    const filterOptions = ['Last 7 Days', 'Last 30 Days', 'All Time'];

    final freezeCountState = useState<int>(
      activityService?.getStreakFreezes() ?? 1,
    );
    final userXpState = useState<int>(
      activityService?.getXpPoints() ?? 0,
    );

    return Scaffold(
      backgroundColor: isDark
          ? colors.backgroundPrimary
          : colors.surfacePrimary,
      appBar: AppAdaptiveAppBar(
        breadcrumbs: [
          AppBreadcrumbItem(
            label: 'Dashboard',
            onTap: () {
              if (context.router.canPop()) {
                context.router.pop();
              }
            },
          ),
          AppBreadcrumbItem(
            label: l10n.analyticsDetailTitle,
          ),
        ],
        title: Text(
          l10n.analyticsDetailTitle,
          style: typography.title3.bold.copyWith(color: colors.textPrimary),
        ),
      ),
      body: BlocBuilder<DashboardBloc, DashboardState>(
        builder: (context, state) {
          if (state.isLoading && state.feed == null) {
            return const AnalyticsShimmerSkeleton();
          }

          final feed = state.feed;
          final rawAnalytics = AnalyticsTimeframeFilterHelper.resolveAnalytics(
            feed?.analyticsSummary,
            activityService: activityService,
          );
          final courses = feed?.curatedCourses ?? const <CuratedCourseEntity>[];

          final filterIndex = selectedFilterIndex.value;
          final analytics =
              AnalyticsTimeframeFilterHelper.filterAnalyticsByTimeframe(
            rawAnalytics,
            filterIndex,
          );

          final hasData =
              analytics.totalCardsMastered > 0 ||
              analytics.weeklyMinutesStudied > 0 ||
              analytics.overallRetentionRate > 0 ||
              analytics.currentStreakDays > 0;

          var retentionPoints = const <DailyRetentionPoint>[];
          if (hasData) {
            const decayCalculator = EbbinghausDecayCalculator();
            final effectiveRate = analytics.overallRetentionRate > 0
                ? analytics.overallRetentionRate
                : 0.85;

            final projectionDays = filterIndex == 0
                ? 7
                : (filterIndex == 1 ? 14 : 28);
            final empiricalStability = effectiveRate >= 0.99
                ? 14.0
                : (-1.0 / math.log(effectiveRate.clamp(0.01, 0.98))).clamp(
                    2.0,
                    30.0,
                  );

            retentionPoints = decayCalculator.calculateProjection(
              projectionDays: projectionDays,
              cardStabilities: [empiricalStability],
              empiricalRecallRates: [
                1.0,
                effectiveRate,
                (effectiveRate * 0.96).clamp(0.0, 1.0),
              ],
            );
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: ListView(
                physics: const ClampingScrollPhysics(),
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
                  AnalyticsKpiGrid(
                    analytics: analytics,
                    timeframeIndex: filterIndex,
                  ),
                  const SizedBox(height: 20),

                  // Streak Shield Protection Indicator
                  StreakShieldIndicator(
                    streakDays: analytics.currentStreakDays,
                    hasStreakFreeze: freezeCountState.value > 0,
                    userXp: math.max(analytics.xpPoints, userXpState.value),
                    onPurchaseFreeze: () async {
                      if (activityService == null) return;
                      final success = await activityService!
                          .purchaseStreakFreeze();
                      if (success) {
                        AppFeedback.celebration();
                        freezeCountState.value = activityService!
                            .getStreakFreezes();
                        userXpState.value = activityService!.getXpPoints();
                        if (context.mounted) {
                          context.showSnackBar(
                            message: l10n.streakFreezeSuccess,
                            type: SnackBarType.success,
                          );
                          try {
                            authBloc?.add(
                              const AuthStreakIncremented(),
                            );
                          } on Object catch (e, st) {
                            AppLogger.recordNonFatal(e, st);
                          }
                        }
                      } else {
                        AppFeedback.incorrect();
                        if (context.mounted) {
                          context.showSnackBar(
                            message:
                                'Insufficient XP. Complete study sessions to earn at least 200 XP!',
                          );
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 20),

                  // 3. Ebbinghaus Memory Decay & Retention Curve
                  AdaptiveRetentionChart(
                    points: retentionPoints,
                    onTriggerNeuralRepair: (day, retrievability) {
                      showAnalyticsNeuralRepairSheet(
                        context,
                        day,
                        retrievability,
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // 4. Weekly Study Volume & Velocity Bar Chart
                  AnalyticsWeeklyVelocityChart(
                    analytics: analytics,
                    timeframeIndex: filterIndex,
                    colors: colors,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 20),

                  // 5. Activity Heatmap & Consistency Grid
                  AnalyticsDetailedHeatMapCard(
                    analytics: analytics,
                    timeframeIndex: filterIndex,
                    colors: colors,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 20),

                  // 6. Course & Subject Mastery Breakdown
                  AnalyticsSubjectMasteryCard(
                    courses: courses,
                    colors: colors,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 20),

                  // 7. Syllabot Cognitive Diagnostics & Smart Recommendations
                  AnalyticsCognitiveInsightsCard(
                    insightText: feed?.syllabotDailyInsight,
                    hasData: hasData,
                    colors: colors,
                    isDark: isDark,
                    activityService: activityService,
                    subscriptionGuard: subscriptionGuard,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
