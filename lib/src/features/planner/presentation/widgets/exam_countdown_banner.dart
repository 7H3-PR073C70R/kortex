import 'dart:async';
import 'dart:ui';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/dashboard/domain/logic/cbt_readiness_calculator.dart';
import 'package:kortex/src/features/planner/domain/entities/assessment_type.dart';
import 'package:kortex/src/features/planner/domain/entities/exam_event_entity.dart';
import 'package:kortex/src/features/planner/domain/logic/cram_workload_calculator.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_cubit.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_state.dart';
import 'package:kortex/src/features/planner/presentation/widgets/add_exam_modal_sheet.dart';
import 'package:kortex/src/features/planner/presentation/widgets/manage_exam_modal_sheet.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';

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
        // Scope-aware fallback: Quick diagnostic check for this assessment
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
    final typography = context.typography;
    final l10n = context.l10n;

    return BlocBuilder<CramPlannerCubit, CramPlannerState>(
      builder: (context, state) {
        final exam = state.selectedExam;
        final allExams = state.activeExams;

        if (exam == null) {
          // Nearest upcoming exam drives the subtitle if one exists
          final upcoming =
              state.activeExams.where((e) => e.daysRemaining > 0).toList()
                ..sort((a, b) => a.daysRemaining.compareTo(b.daysRemaining));
          final targetExam = upcoming.firstOrNull;

          return Semantics(
            container: true,
            button: true,
            label: l10n.addExamTitle,
            child:
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
                            onTap: () {
                              unawaited(AddExamModalSheet.show(context));
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 16,
                                  sigmaY: 16,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: neural.glassPanel,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isHovered
                                          ? neural.emerald.withAlpha(102)
                                          : neural.hairline,
                                    ),
                                  ),
                                  child: child,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: neural.emerald.withAlpha(26),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: neural.emerald.withAlpha(51),
                              ),
                            ),
                            child: Icon(
                              Icons.access_alarm_rounded,
                              color: neural.emerald400,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Track Assessment Milestone',
                                  style: typography.callout.semiBold.copyWith(
                                    color: neural.slate200,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  targetExam != null
                                      ? l10n.examTargetInDays(
                                          targetExam.examName,
                                          targetExam.daysRemaining,
                                        )
                                      : 'Set countdown for upcoming tests, quizzes, or exams',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: typography.caption.regular.copyWith(
                                    color: neural.slate400,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: neural.obsidian800,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.chevron_right_rounded,
                              size: 16,
                              color: neural.slate400,
                            ),
                          ),
                        ],
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 400.ms, curve: Curves.easeOut)
                    .slideY(
                      begin: 0.1,
                      end: 0,
                      duration: 400.ms,
                      curve: Curves.easeOutQuint,
                    ),
          );
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
          syllabusCoverage: 0.78,
          fsrsRetentionRate: 0.86,
          mockScoreRatio: 0.80,
          daysRemaining: days,
        );

        // Headline calculation with sub-daily granularity
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
              // Consolidated Study Capacity Bar (Gap 2)
              if (allExams.length > 1 && state.totalCombinedDailyTarget > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: neural.obsidian800.withAlpha(150),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: neural.hairline),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.stacked_line_chart_rounded,
                          size: 13,
                          color: neural.emerald400,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            l10n.combinedTodayWorkload(
                              state.totalCombinedDailyTarget,
                              allExams
                                  .where((e) => !e.isCompleted && !e.isPast)
                                  .length,
                              state.estimatedDailyMinutes,
                            ),
                            style: typography.caption.medium.copyWith(
                              color: neural.slate300,
                              fontSize: 10.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Multi-Milestone Horizontal Pill Strip
              if (allExams.length > 1) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ...allExams.map((e) {
                          final isSelected = e.id == exam.id;
                          final isPillPriority =
                              e.id == state.topPriorityExamId;
                          final eUrgency = _calculator.getUrgencyLevel(
                            e.daysRemaining,
                            type: e.assessmentType,
                          );
                          final eColor = switch (eUrgency) {
                            ExamUrgencyLevel.normal => neural.emerald400,
                            ExamUrgencyLevel.warning => neural.amber400,
                            ExamUrgencyLevel.critical => neural.pink400,
                          };

                          final pillTimeStr =
                              e.isCompleted
                                  ? 'Done'
                                  : (e.timeRemaining.inHours < 24 && !e.isPast
                                      ? '${e.timeRemaining.inHours}h'
                                      : '${e.daysRemaining}d');

                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: InkWell(
                              onTap: () {
                                AppFeedback.selection();
                                context.read<CramPlannerCubit>().selectExam(
                                  e.id,
                                );
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: AnimatedContainer(
                                duration: AppMotion.snappy,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4.5,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? eColor.withAlpha(40)
                                      : neural.obsidian800.withAlpha(160),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected
                                        ? eColor.withAlpha(160)
                                        : neural.hairline,
                                    width: isSelected ? 1.4 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      e.assessmentType.icon,
                                      size: 12,
                                      color: isSelected
                                          ? eColor
                                          : neural.slate400,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      e.examName,
                                      style: typography.caption.bold.copyWith(
                                        color: isSelected
                                            ? neural.slate100
                                            : neural.slate400,
                                        fontSize: 11,
                                      ),
                                    ),
                                    if (isPillPriority) ...[
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.bolt_rounded,
                                        size: 11,
                                        color: neural.amber400,
                                      ),
                                    ],
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4.5,
                                        vertical: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: eColor.withAlpha(50),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        pillTimeStr,
                                        style: typography.caption.bold.copyWith(
                                          color: eColor,
                                          fontSize: 9.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                        // Quick Add pill
                        InkWell(
                          onTap: () => AddExamModalSheet.show(context),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4.5,
                            ),
                            decoration: BoxDecoration(
                              color: neural.obsidian800.withAlpha(140),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: neural.hairline),
                            ),
                            child: Icon(
                              Icons.add_rounded,
                              size: 13,
                              color: neural.slate400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Active Milestone Card
              PlatformHoverBuilder(
                builder: (context, isHovered, child) {
                  return AnimatedContainer(
                    duration: AppMotion.snappy,
                    curve: Curves.easeOutCubic,
                    transform: Matrix4.translationValues(
                      0,
                      isHovered ? -2 : 0,
                      0,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: neural.glassPanel,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isHovered
                                  ? badgeColor.withAlpha(120)
                                  : (exam.isCriticalCrunch
                                      ? badgeColor.withAlpha(100)
                                      : neural.hairline),
                              width: exam.isCriticalCrunch ? 1.4 : 1.0,
                            ),
                          ),
                          child: child,
                        ),
                      ),
                    ),
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge Header Row (Gap 3: Grade Weight & Priority)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Wrap(
                            spacing: 5,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                constraints: const BoxConstraints(maxWidth: 210),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3.5,
                                ),
                                decoration: BoxDecoration(
                                  color: neural.obsidian800,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: badgeColor.withAlpha(51),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      exam.assessmentType.icon,
                                      size: 12,
                                      color: badgeColor,
                                    ),
                                    const SizedBox(width: 4.5),
                                    Flexible(
                                      child: Text(
                                        '${exam.assessmentType.displayName.toUpperCase()} • ${exam.subjectTrack}${exam.subjectTrack.toLowerCase().contains('track') ? '' : ' Track'}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: typography.caption.bold.copyWith(
                                          fontSize: 10,
                                          color: badgeColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Grade Weight Badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3.5,
                                ),
                                decoration: BoxDecoration(
                                  color: neural.obsidian800,
                                  borderRadius: BorderRadius.circular(7),
                                  border: Border.all(
                                    color: neural.hairlineStrong,
                                  ),
                                ),
                                child: Text(
                                  l10n.gradeWeightBadge(
                                    (exam.effectiveWeightPercent > 1.0
                                            ? exam.effectiveWeightPercent
                                            : exam.effectiveWeightPercent * 100)
                                        .toInt()
                                        .toString(),
                                  ),
                                  style: typography.caption.medium.copyWith(
                                    fontSize: 9.5,
                                    color: neural.slate300,
                                  ),
                                ),
                              ),
                              // Dynamic CBT Readiness Index Badge
                              InkWell(
                                onTap: () {
                                  AppFeedback.selection();
                                  _showCbtReadinessBreakdownSheet(
                                    context,
                                    exam,
                                    readinessResult,
                                  );
                                },
                                borderRadius: BorderRadius.circular(7),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: readinessResult.statusColor.withAlpha(25),
                                    borderRadius: BorderRadius.circular(7),
                                    border: Border.all(
                                      color: readinessResult.statusColor.withAlpha(90),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.analytics_rounded,
                                        size: 11,
                                        color: readinessResult.statusColor,
                                      ),
                                      const SizedBox(width: 3.5),
                                      Text(
                                        'Readiness: ${readinessResult.scorePercent}%',
                                        style: typography.caption.bold.copyWith(
                                          fontSize: 9.5,
                                          color: readinessResult.statusColor,
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Icon(
                                        Icons.info_outline_rounded,
                                        size: 10,
                                        color: readinessResult.statusColor,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Top Priority Flag
                              if (isTopPriority)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: neural.amber400.withAlpha(30),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: neural.amber400.withAlpha(80),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.bolt_rounded,
                                        size: 11,
                                        color: neural.amber400,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        l10n.topPriorityBadge,
                                        style: typography.caption.bold.copyWith(
                                          fontSize: 9,
                                          color: neural.amber400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () {
                                unawaited(ManageExamModalSheet.show(context));
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3.5,
                                ),
                                decoration: BoxDecoration(
                                  color: neural.obsidian850.withAlpha(204),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: neural.hairlineStrong,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.tune_rounded,
                                      size: 12,
                                      color: neural.slate300,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Manage',
                                      style: typography.caption.medium.copyWith(
                                        color: neural.slate300,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(
                                Icons.add_rounded,
                                color: neural.slate400,
                                size: 20,
                              ),
                              tooltip: l10n.addExamTitle,
                              onPressed: () {
                                unawaited(AddExamModalSheet.show(context));
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Countdown Headline
                    Text(
                      countdownHeadline,
                      style: typography.title3.bold.copyWith(
                        color: neural.slate100,
                        fontSize: 15.5,
                      ),
                    ),

                    // Scoped Topics Tag Strip (Gap 5)
                    if (exam.scopedTopics.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(
                            Icons.topic_outlined,
                            size: 12,
                            color: neural.slate400,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              l10n.topicsCoveredLabel(
                                exam.scopedTopics.join(' • '),
                              ),
                              style: typography.caption.regular.copyWith(
                                color: neural.slate400,
                                fontSize: 10.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.auto_graph_rounded,
                          size: 16,
                          color: neural.emerald400,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            l10n.recommendedDailyPace(pace),
                            style: typography.footnote.semiBold.copyWith(
                              color: neural.emerald400,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Contextual Action Button (Primary CTA)
                    SizedBox(
                      width: double.infinity,
                      child: InkWell(
                        onTap: () => _onPrimaryActionPressed(context, exam),
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: AppMotion.snappy,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8.5,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                badgeColor.withAlpha(200),
                                badgeColor.withAlpha(140),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: badgeColor.withAlpha(50),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                exam.assessmentType == AssessmentType.quiz
                                    ? Icons.bolt_rounded
                                    : Icons.play_arrow_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _getActionLabel(context, exam),
                                style: typography.footnote.bold.copyWith(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

void _showCbtReadinessBreakdownSheet(
  BuildContext context,
  ExamEventEntity exam,
  CbtReadinessResult readiness,
) {
  final neural = context.neural;
  final typography = context.typography;

  unawaited(
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.dialog),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              decoration: BoxDecoration(
                color: neural.obsidian900.withAlpha(245),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.dialog),
                ),
                border: Border.all(
                  color: readiness.statusColor.withAlpha(90),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: neural.slate400.withAlpha(120),
                      borderRadius: BorderRadius.circular(AppRadius.micro),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Score Ring Header
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: readiness.statusColor.withAlpha(25),
                      border: Border.all(
                        color: readiness.statusColor,
                        width: 3,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${readiness.scorePercent}%',
                        style: typography.title2.bold.copyWith(
                          color: readiness.statusColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Text(
                    '${exam.examName} CBT Readiness',
                    style: typography.title3.bold.copyWith(
                      color: neural.slate100,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Status: ${readiness.statusLabel}',
                    textAlign: TextAlign.center,
                    style: typography.footnote.regular.copyWith(
                      color: readiness.statusColor,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Formula Weights Breakdown
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: neural.obsidian850,
                      borderRadius: BorderRadius.circular(AppRadius.panel),
                      border: Border.all(color: neural.hairlineStrong),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Readiness Index Model Weights',
                          style: typography.caption.bold.copyWith(
                            color: neural.amber300,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildWeightRow(
                          context,
                          icon: Icons.psychology_rounded,
                          label: 'FSRS Memory Retention Rate (50%)',
                          value: '86%',
                          color: neural.emerald400,
                        ),
                        const SizedBox(height: 8),
                        _buildWeightRow(
                          context,
                          icon: Icons.quiz_rounded,
                          label: 'CBT Mock Exam Average (25%)',
                          value: '80%',
                          color: neural.amber400,
                        ),
                        const SizedBox(height: 8),
                        _buildWeightRow(
                          context,
                          icon: Icons.timer_rounded,
                          label: 'Target Date Proximity (25%)',
                          value: '${exam.daysRemaining} days left',
                          color: neural.slate300,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: readiness.statusColor,
                        foregroundColor: neural.obsidian950,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.badge),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        unawaited(
                          context.router.push(
                            MockExamLobbyRoute(
                              examId: exam.id,
                              examName: exam.examName,
                              subjectTrack: exam.subjectTrack,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.play_arrow_rounded, size: 20),
                      label: Text(
                        'Launch CBT Diagnostic Mock',
                        style: typography.callout.bold.copyWith(
                          color: neural.obsidian950,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

Widget _buildWeightRow(
  BuildContext context, {
  required IconData icon,
  required String label,
  required String value,
  required Color color,
}) {
  final neural = context.neural;
  final typography = context.typography;

  return Row(
    children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          label,
          style: typography.caption.medium.copyWith(
            color: neural.slate200,
            fontSize: 12,
          ),
        ),
      ),
      Text(
        value,
        style: typography.caption.bold.copyWith(
          color: color,
          fontSize: 12,
        ),
      ),
    ],
  );
}
