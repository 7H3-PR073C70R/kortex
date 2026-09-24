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
    if (exam.assessmentType == AssessmentType.quiz &&
        exam.scopedDeckIds.isNotEmpty) {
      unawaited(
        context.router.push(
          StudySessionRoute(deckId: exam.scopedDeckIds.first),
        ),
      );
      return;
    }

    unawaited(
      context.router.push(
        MockExamLobbyRoute(
          examId: exam.id,
          examName: exam.examName,
        ),
      ),
    );
  }

  String _getActionLabel(BuildContext context, AssessmentType type) {
    final l10n = context.l10n;
    return switch (type) {
      AssessmentType.quiz => l10n.actionPracticeScopedDecks,
      AssessmentType.classTest => l10n.actionStartTestReview,
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
                                  l10n.addExamTitle,
                                  style: typography.callout.semiBold.copyWith(
                                    color: neural.slate200,
                                    fontSize: 14,
                                  ),
                                ),
                                if (targetExam != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    l10n.examTargetInDays(
                                      targetExam.examName,
                                      targetExam.daysRemaining,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: typography.caption.regular.copyWith(
                                      color: neural.slate400,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
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

        final bannerLabel =
            '${exam.assessmentType.displayName} Countdown: ${l10n.daysUntilExam(days, exam.examName)}. '
            '${l10n.recommendedDailyPace(pace)}';

        return Semantics(
          container: true,
          button: false,
          label: bannerLabel,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Multi-Milestone Horizontal Pill Strip (if more than 1 assessment exists)
              if (allExams.length > 1) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ...allExams.map((e) {
                          final isSelected = e.id == exam.id;
                          final eUrgency = _calculator.getUrgencyLevel(
                            e.daysRemaining,
                            type: e.assessmentType,
                          );
                          final eColor = switch (eUrgency) {
                            ExamUrgencyLevel.normal => neural.emerald400,
                            ExamUrgencyLevel.warning => neural.amber400,
                            ExamUrgencyLevel.critical => neural.pink400,
                          };

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
                                        '${e.daysRemaining}d',
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
                                  : neural.hairline,
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
                    // Badge Header Row
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
                                  size: 13,
                                  color: badgeColor,
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    '${exam.assessmentType.displayName.toUpperCase()} • ${exam.subjectTrack} Track',
                                    style: typography.caption.bold.copyWith(
                                      fontSize: 10.5,
                                      color: badgeColor,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
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

                    Text(
                      l10n.daysUntilExam(days, exam.examName),
                      style: typography.title3.bold.copyWith(
                        color: neural.slate100,
                        fontSize: 15.5,
                      ),
                    ),
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
                                _getActionLabel(context, exam.assessmentType),
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
