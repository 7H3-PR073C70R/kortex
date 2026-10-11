import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/services/user_activity_service.dart';
import 'package:kortex/src/core/utils/app_logger.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/domain/entities/course_track_entity.dart';
import 'package:kortex/src/features/dashboard/domain/entities/dashboard_feed_entity.dart';
import 'package:kortex/src/features/dashboard/domain/logic/cbt_readiness_calculator.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_state.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/cbt_readiness_gauge_card.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_cubit.dart';

/// Dynamic CBT Readiness Score Gauge Card for the executive dashboard.
/// Resolves real days remaining from CramPlannerCubit or track defaults,
/// maps academic tracks to their proper archetypes and labels, and computes comprehensive readiness.
class DashboardCbtReadinessGaugeCard extends StatelessWidget {
  const DashboardCbtReadinessGaugeCard({
    required this.feed,
    this.targetTrack,
    super.key,
  });

  final DashboardFeedEntity feed;
  final String? targetTrack;

  @override
  Widget build(BuildContext context) {
    final plannerState = context.watch<CramPlannerCubit>().state;
    final selectedExam = plannerState.selectedExam;
    final upcomingExams = plannerState.upcomingUncompletedExams;

    // Resolve accurate days remaining dynamically from real planner state or track default
    final int effectiveDaysRemaining;
    if (selectedExam != null) {
      effectiveDaysRemaining = selectedExam.daysRemaining;
    } else if (upcomingExams.isNotEmpty) {
      effectiveDaysRemaining = upcomingExams
          .map((e) => e.daysRemaining)
          .reduce(math.min);
    } else {
      final defaultTrackMatch = CourseTrackEntity.defaultTracks
          .where(
            (t) =>
                t.id.toLowerCase() == (targetTrack ?? '').toLowerCase() ||
                (targetTrack != null &&
                    t.name.toLowerCase().contains(targetTrack!.toLowerCase())),
          )
          .firstOrNull;
      effectiveDaysRemaining = defaultTrackMatch?.examCountdownDays ?? 45;
    }

    // Resolve human-readable exam title
    final String effectiveExamTitle;
    if (selectedExam != null && selectedExam.examName.trim().isNotEmpty) {
      effectiveExamTitle = selectedExam.examName.trim();
    } else if (targetTrack != null && targetTrack!.trim().isNotEmpty) {
      final match = CourseTrackEntity.defaultTracks
          .where(
            (t) =>
                t.id.toLowerCase() == targetTrack!.toLowerCase() ||
                t.name.toLowerCase().contains(targetTrack!.toLowerCase()),
          )
          .firstOrNull;
      effectiveExamTitle = match != null ? match.name : targetTrack!.trim();
    } else {
      effectiveExamTitle = 'Standardized CBT Track';
    }

    final effectiveExamType =
        (selectedExam != null && selectedExam.subjectTrack.isNotEmpty)
            ? selectedExam.subjectTrack
            : (targetTrack ?? 'JAMB');

    // Real syllabus coverage average from curated courses if present
    final double realSyllabusCoverage;
    if (feed.curatedCourses.isNotEmpty) {
      final total = feed.curatedCourses.fold<double>(
        0,
        (sum, c) => sum + c.syllabusCoverage.clamp(0.0, 1.0),
      );
      realSyllabusCoverage = (total / feed.curatedCourses.length).clamp(
        0.0,
        1.0,
      );
    } else {
      realSyllabusCoverage = 0.0;
    }

    var subjectAccuracies = const <String, double>{};
    var subjectRetentions = const <String, double>{};
    var realMockScoreRatio = 0.0;

    try {
      if (locator.isRegistered<UserActivityService>()) {
        final activityService = locator<UserActivityService>();
        final metrics = activityService.getQuizPerformanceMetrics();
        subjectAccuracies = metrics.subjectAccuracies;
        subjectRetentions = metrics.subjectRetentions;
        if (metrics.totalQuizSessions > 0) {
          realMockScoreRatio = metrics.overallMockAccuracy;
        } else if (feed.analyticsSummary.overallRetentionRate > 0.0) {
          realMockScoreRatio = feed.analyticsSummary.overallRetentionRate;
        }
      }
    } on Object catch (e, st) { AppLogger.recordNonFatal(e, st); }

    final readinessResult = const CbtReadinessCalculator().compute(
      syllabusCoverage: realSyllabusCoverage,
      fsrsRetentionRate: feed.analyticsSummary.overallRetentionRate,
      mockScoreRatio: realMockScoreRatio,
      daysRemaining: effectiveDaysRemaining,
      registeredCourses: feed.curatedCourses,
      examType: effectiveExamType,
      subjectAccuracies: subjectAccuracies,
      subjectRetentions: subjectRetentions,
    );

    return CbtReadinessGaugeCard(
      readinessResult: readinessResult,
      examTitle: effectiveExamTitle,
      daysRemaining: effectiveDaysRemaining,
    );
  }
}

/// Scoped BlocBuilder wrapper for CBT Readiness Gauge that only rebuilds
/// when syllabus coverage or retention analytics meaningfully mutate.
class CbtReadinessGaugeSection extends StatelessWidget {
  const CbtReadinessGaugeSection({
    this.targetTrack,
    super.key,
  });

  final String? targetTrack;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardBloc, DashboardState>(
      buildWhen: (previous, current) {
        final prevFeed = previous.displayFeed;
        final currFeed = current.displayFeed;
        if (prevFeed == null || currFeed == null) {
          return previous != current;
        }
        return prevFeed.curatedCourses != currFeed.curatedCourses ||
            prevFeed.analyticsSummary.overallRetentionRate !=
                currFeed.analyticsSummary.overallRetentionRate;
      },
      builder: (context, state) {
        final feed = state.displayFeed;
        if (feed == null) return const SizedBox.shrink();

        return DashboardCbtReadinessGaugeCard(
          feed: feed,
          targetTrack: targetTrack,
        );
      },
    );
  }
}
