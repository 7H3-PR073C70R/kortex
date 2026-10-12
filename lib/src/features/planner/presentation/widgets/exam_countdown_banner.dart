import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/features/dashboard/domain/logic/cbt_readiness_calculator.dart';
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
  const ExamCountdownBanner({super.key});

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
        final readinessResult = const CbtReadinessCalculator().compute(
          syllabusCoverage: exam.completionProgress,
          fsrsRetentionRate: (exam.achievedScorePercent ?? 0.80).clamp(0.0, 1.0),
          mockScoreRatio: (exam.achievedScorePercent ?? 0.75).clamp(0.0, 1.0),
          daysRemaining: days,
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
