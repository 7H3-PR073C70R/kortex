import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/services/user_activity_service.dart';
import 'package:kortex/src/core/utils/app_logger.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/dashboard/domain/logic/cbt_readiness_calculator.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/planner/domain/entities/assessment_type.dart';
import 'package:kortex/src/features/planner/domain/entities/exam_event_entity.dart';
import 'package:kortex/src/features/planner/domain/logic/cram_workload_calculator.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_cubit.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_state.dart';
import 'package:kortex/src/features/planner/presentation/widgets/countdown/active_milestone_card.dart';
import 'package:kortex/src/features/planner/presentation/widgets/countdown/multi_milestone_pill_strip.dart';
import 'package:kortex/src/features/planner/presentation/widgets/countdown/untracked_milestone_card.dart';
import 'package:kortex/src/features/planner/presentation/widgets/manage_exam_modal_sheet.dart';
import 'package:kortex/src/l10n/l10n.dart';

export 'countdown/active_milestone_card.dart';
export 'countdown/cbt_readiness_breakdown_sheet.dart';
export 'countdown/multi_milestone_pill_strip.dart';
export 'countdown/untracked_milestone_card.dart';

/// Top-level coordinator widget for the live countdown banner and multi-milestone strip.
class ExamCountdownBanner extends StatelessWidget {
  const ExamCountdownBanner({
    this.registeredCourses,
    this.targetTrack,
    super.key,
  });

  final List<dynamic>? registeredCourses;
  final String? targetTrack;

  static const _calculator = CramWorkloadCalculator();

  void _onPrimaryActionPressed(BuildContext context, ExamEventEntity exam) {
    AppFeedback.selection();
    if (exam.isPast && !exam.isCompleted) {
      unawaited(ManageExamModalSheet.show(context));
      return;
    }
    if (exam.assessmentType == AssessmentType.quiz ||
        exam.assessmentType == AssessmentType.classTest) {
      if (exam.scopedDeckIds.isNotEmpty) {
        final deckTarget = exam.daysRemaining <= 14 && exam.daysRemaining > 0
            ? 'cram:${exam.daysRemaining}:${exam.scopedDeckIds.first}'
            : exam.scopedDeckIds.first;
        unawaited(
          context.router.push(
            StudySessionRoute(deckId: deckTarget),
          ),
        );
        return;
      } else {
        unawaited(
          context.router.push(
            QuizWorkspaceRoute(
              deckId: 'quick-quiz-${exam.id}',
              deckTitle: exam.examName,
              courseCode: exam.subjectTrack,
            ),
          ),
        );
        return;
      }
    }

    unawaited(
      context.router.push(
        MockExamLobbyRoute(
          examId: exam.id,
          examName: exam.examName,
          subjectTrack: exam.subjectTrack,
        ),
      ),
    );
  }

  String _getActionLabel(BuildContext context, ExamEventEntity exam) {
    final l10n = context.l10n;
    if (exam.isCompleted) {
      return 'Review Assessment';
    }
    if (exam.isPast) {
      return l10n.logGradeAndConclude;
    }
    return switch (exam.assessmentType) {
      AssessmentType.quiz => exam.scopedDeckIds.isNotEmpty
          ? l10n.actionPracticeScopedDecks
          : 'Take Quick Quiz',
      AssessmentType.classTest => exam.scopedDeckIds.isNotEmpty
          ? l10n.actionStartTestReview
          : 'Start Test Practice',
      AssessmentType.midterm ||
      AssessmentType.finalExam ||
      AssessmentType.mockExam ||
      AssessmentType.custom =>
        l10n.actionOpenMockLobby,
    };
  }

  @override
  Widget build(BuildContext context) {
    final neural = context.neural;
    final l10n = context.l10n;

    return BlocBuilder<CramPlannerCubit, CramPlannerState>(
      builder: (context, state) {
        final exam = state.selectedExam;
        final allExams = state.activeExams;

        if (exam == null) {
          final upcoming =
              state.activeExams.where((e) => e.daysRemaining > 0).toList()
                ..sort((a, b) => a.daysRemaining.compareTo(b.daysRemaining));
          return UntrackedMilestoneCard(targetExam: upcoming.firstOrNull);
        }

        final days = exam.daysRemaining;
        final pace = state.dynamicDailyTarget;
        final urgency = _calculator.getUrgencyLevel(
          days,
          type: exam.assessmentType,
        );

        final badgeColor = switch (urgency) {
          ExamUrgencyLevel.normal => neural.emerald400,
          ExamUrgencyLevel.warning => neural.amber400,
          ExamUrgencyLevel.critical => neural.pink400,
        };

        final isTopPriority = exam.id == state.topPriorityExamId;

        final effectiveCourses = registeredCourses ??
            context.watch<DashboardBloc?>()?.state.displayFeed?.curatedCourses ??
            const <dynamic>[];

        final double effectiveCoverage;
        if (effectiveCourses.isNotEmpty) {
          final total = effectiveCourses.fold<double>(
            0,
            (sum, c) =>
                sum +
                RegisteredCourseInput.fromDynamic(c)
                    .syllabusCoverage
                    .clamp(0.0, 1.0),
          );
          effectiveCoverage = (total / effectiveCourses.length).clamp(0.0, 1.0);
        } else {
          effectiveCoverage = exam.completionProgress.clamp(0.0, 1.0);
        }

        var subjectAccuracies = const <String, double>{};
        var subjectRetentions = const <String, double>{};
        var subjectQuestionCounts = const <String, int>{};
        var totalQuestionsAnswered = 0;
        var effectiveRetention = 0.0;
        var effectiveMockRatio = 0.0;

        final dashboardFeed = context.watch<DashboardBloc?>()?.state.displayFeed;
        if (dashboardFeed != null) {
          effectiveRetention = dashboardFeed.analyticsSummary.overallRetentionRate;
        }

        try {
          if (locator.isRegistered<UserActivityService>()) {
            final activityService = locator<UserActivityService>();
            final metrics = activityService.getQuizPerformanceMetrics();
            subjectAccuracies = metrics.subjectAccuracies;
            subjectRetentions = metrics.subjectRetentions;
            subjectQuestionCounts = metrics.subjectQuestionCounts;
            totalQuestionsAnswered = metrics.totalQuestionsAnswered;
            if (metrics.totalQuizSessions > 0) {
              effectiveMockRatio = metrics.overallMockAccuracy;
            } else if (exam.achievedScorePercent != null && exam.achievedScorePercent! > 0) {
              effectiveMockRatio = exam.achievedScorePercent!.clamp(0.0, 1.0);
            }

            if (effectiveRetention == 0.0) {
              effectiveRetention = activityService.getOverallRetentionRate();
            }
          }
        } on Object catch (e, st) {
          AppLogger.recordNonFatal(e, st);
        }

        if (effectiveMockRatio == 0.0 && exam.achievedScorePercent != null && exam.achievedScorePercent! > 0) {
          effectiveMockRatio = exam.achievedScorePercent!.clamp(0.0, 1.0);
        }

        final effectiveExamType = exam.subjectTrack.isNotEmpty
            ? exam.subjectTrack
            : (targetTrack ?? exam.examName);

        final readinessResult = const CbtReadinessCalculator().compute(
          syllabusCoverage: effectiveCoverage,
          fsrsRetentionRate: effectiveRetention,
          mockScoreRatio: effectiveMockRatio,
          daysRemaining: days,
          registeredCourses: effectiveCourses,
          examType: effectiveExamType,
          subjectAccuracies: subjectAccuracies,
          subjectRetentions: subjectRetentions,
          subjectQuestionCounts: subjectQuestionCounts,
          totalQuestionsAnswered: totalQuestionsAnswered,
          explicitWeakestTopic: exam.examName,
        );

        final String countdownHeadline;
        if (exam.isCompleted) {
          countdownHeadline =
              '${exam.examName} • ${l10n.achievedScoreLabel(exam.achievedScorePercent != null ? (exam.achievedScorePercent! * 100).toStringAsFixed(0) : '100')}';
        } else if (exam.isPast) {
          countdownHeadline =
              '${exam.examName} • ${l10n.concludeAssessmentPrompt}';
        } else if (exam.isCriticalCrunch) {
          final totalH = exam.timeRemaining.inHours;
          final mins = exam.minutesRemaining;
          final timeStr = totalH > 0 ? '${totalH}h ${mins}m left' : '${mins}m left';
          countdownHeadline = '${exam.examName} • Starts in $timeStr';
        } else if (exam.isImminent) {
          countdownHeadline =
              '${exam.examName} • Tomorrow (${exam.timeRemaining.inHours}h left)';
        } else {
          countdownHeadline = l10n.daysUntilExam(days, exam.examName);
        }

        final bannerLabel =
            '${exam.assessmentType.displayName} Countdown: $countdownHeadline. '
            '${l10n.recommendedDailyPace(pace)}';

        return Semantics(
          container: true,
          button: false,
          label: bannerLabel,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MultiMilestonePillStrip(
                selectedExam: exam,
                allExams: allExams,
                totalCombinedDailyTarget: state.totalCombinedDailyTarget,
                estimatedDailyMinutes: state.estimatedDailyMinutes,
                topPriorityExamId: state.topPriorityExamId,
              ),
              ActiveMilestoneCard(
                exam: exam,
                pace: pace,
                badgeColor: badgeColor,
                isTopPriority: isTopPriority,
                readinessResult: readinessResult,
                countdownHeadline: countdownHeadline,
                actionLabel: _getActionLabel(context, exam),
                onPrimaryAction: () => _onPrimaryActionPressed(context, exam),
              ),
            ],
          ),
        );
      },
    );
  }
}
