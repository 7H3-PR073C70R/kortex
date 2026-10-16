import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/analytics_service.dart';
import 'package:kortex/src/core/services/user_activity_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/utils/app_logger.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/dashboard/domain/logic/cbt_readiness_calculator.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/cbt_readiness/cbt_readiness_weekly_trends_chart.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/cbt_readiness/readiness_breakdown_actions_section.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/cbt_readiness/readiness_breakdown_course_card.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/cbt_readiness/readiness_breakdown_projected_card.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/repositories/past_questions_repository.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_sheet.dart';

/// Bottom modal sheet providing in-depth CBT readiness diagnostic breakdowns.
class CbtReadinessBreakdownSheet extends StatefulWidget {
  const CbtReadinessBreakdownSheet({
    required this.readinessResult,
    required this.examTitle,
    required this.daysRemaining,
    required this.scrollController,
    this.pastQuestionsRepository,
    this.userActivityService,
    this.analyticsService,
    super.key,
  });

  final CbtReadinessResult readinessResult;
  final String examTitle;
  final int daysRemaining;
  final ScrollController scrollController;
  final PastQuestionsRepository? pastQuestionsRepository;
  final UserActivityService? userActivityService;
  final AnalyticsService? analyticsService;

  @override
  State<CbtReadinessBreakdownSheet> createState() =>
      _CbtReadinessBreakdownSheetState();
}

class _CbtReadinessBreakdownSheetState
    extends State<CbtReadinessBreakdownSheet> {
  final Set<String> _subjectsWithPastQuestions = {};
  PastQuestionsRepository? _resolvedRepo;

  @override
  void initState() {
    super.initState();
    _resolvedRepo = widget.pastQuestionsRepository ??
        (locator.isRegistered<PastQuestionsRepository>()
            ? locator<PastQuestionsRepository>()
            : null);
    try {
      final analytics = widget.analyticsService ??
          (locator.isRegistered<AnalyticsService>()
              ? locator<AnalyticsService>()
              : null);
      if (analytics != null) {
        unawaited(
          analytics.logReadinessScoreViewed(
            readinessScore: widget.readinessResult.scorePercent.toDouble(),
            statusTier: widget.readinessResult.statusTier.name,
            confidenceIntervalLabel:
                widget.readinessResult.confidenceIntervalLabel,
            standardErrorMargin:
                widget.readinessResult.confidenceMargin.toDouble(),
            examTrack: widget.examTitle,
          ),
        );
      }
    } on Object catch (e, st) {
      AppLogger.recordNonFatal(e, st);
    }
    unawaited(_checkPastQuestionsAvailability());
  }

  ExamCategory _resolveExamCategory(String examTitle, String examType) {
    final combined = '$examTitle $examType'.toUpperCase();
    if (combined.contains('WAEC') || combined.contains('WASSCE')) {
      return ExamCategory.waec;
    }
    if (combined.contains('JAMB') || combined.contains('UTME')) {
      return ExamCategory.jamb;
    }
    if (combined.contains('NECO')) return ExamCategory.neco;
    if (combined.contains('SAT')) return ExamCategory.sat;
    if (combined.contains('IELTS')) return ExamCategory.ielts;
    if (combined.contains('TOEFL')) return ExamCategory.toefl;
    if (combined.contains('MEDIC')) return ExamCategory.medicine;
    if (combined.contains('LAW')) return ExamCategory.law;
    if (combined.contains('ENGIN')) return ExamCategory.engineering;
    if (combined.contains('BUSIN') || combined.contains('COMMERC')) {
      return ExamCategory.business;
    }
    if (combined.contains('COMP') || combined.contains('CSC')) {
      return ExamCategory.computerScience;
    }
    return ExamCategory.waec;
  }

  Future<void> _checkPastQuestionsAvailability() async {
    final repo = _resolvedRepo;
    if (repo == null) return;

    try {
      final category = _resolveExamCategory(
        widget.examTitle,
        widget.readinessResult.targetExamType,
      );

      final availableRes = await repo.getAvailableSubjects(category);
      final availableList = availableRes.fold(
        (f) => <String>[],
        (list) => list.map((s) => s.trim().toLowerCase()).toList(),
      );

      final matched = <String>{};

      for (final sub in widget.readinessResult.subjectBreakdowns) {
        final nameLower = sub.subjectName.trim().toLowerCase();
        final codeLower = sub.courseCode.trim().toLowerCase();

        final foundInAvailable = availableList.any(
          (a) =>
              a == nameLower ||
              a == codeLower ||
              nameLower.contains(a) ||
              a.contains(nameLower) ||
              (codeLower.isNotEmpty &&
                  (codeLower.contains(a) || a.contains(codeLower))),
        );

        if (foundInAvailable) {
          matched.add(sub.subjectName);
        } else {
          final pqRes = await repo.getPastQuestions(
            examCategory: category,
            subject: sub.subjectName,
            courseCode: sub.courseCode.isNotEmpty ? sub.courseCode : null,
          );
          final hasQ = pqRes.fold((f) => false, (list) => list.isNotEmpty);
          if (hasQ) {
            matched.add(sub.subjectName);
          } else {
            final fallbackRes = await repo.getPastQuestions(
              searchQuery: sub.subjectName,
            );
            final hasFallbackQ =
                fallbackRes.fold((f) => false, (list) => list.isNotEmpty);
            if (hasFallbackQ) {
              matched.add(sub.subjectName);
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _subjectsWithPastQuestions.addAll(matched);
        });
      }
    } on Object catch (e, st) {
      AppLogger.recordNonFatal(e, st);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final readiness = widget.readinessResult;
    final examCategory = _resolveExamCategory(
      widget.examTitle,
      readiness.targetExamType,
    );
    final isDesktop = AppAdaptiveSheet.isDesktopOrWeb(context);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
        borderRadius: isDesktop
            ? const BorderRadius.horizontal(
                left: Radius.circular(AppRadius.sheet),
              )
            : const BorderRadius.vertical(
                top: Radius.circular(AppRadius.sheet),
              ),
        boxShadow: isDesktop
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 28,
                  offset: const Offset(-8, 0),
                ),
              ]
            : null,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: ListView(
              controller: widget.scrollController,
              children: [
                if (!isDesktop) ...[
                  // Drag handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.surfaceBorder.withAlpha(isDark ? 100 : 160),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Sheet Header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CBT Readiness Breakdown',
                            style: typography.title2.bold.copyWith(
                              color: colors.textPrimary,
                              fontSize: 19,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Diagnostic analysis for ${widget.examTitle} (${widget.daysRemaining <= 0 ? 'Exam Today' : '${widget.daysRemaining} days remaining'})',
                            style: typography.footnote.regular.copyWith(
                              color: colors.textSecondary,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: readiness.statusColor.withAlpha(25),
                        borderRadius: BorderRadius.circular(AppRadius.badge),
                        border: Border.all(
                          color: readiness.statusColor.withAlpha(90),
                        ),
                      ),
                      child: Text(
                        readiness.statusLabel,
                        style: typography.caption.bold.copyWith(
                          color: readiness.statusColor,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    if (isDesktop) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        tooltip: 'Close',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        color: colors.textSecondary,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),

                // Projected Exam Score Card
                ReadinessBreakdownProjectedCard(readiness: readiness),
                const SizedBox(height: 18),

                // Weekly CBT Readiness Trend Chart
                () {
                  final activityService = widget.userActivityService ??
                      (locator.isRegistered<UserActivityService>()
                          ? locator<UserActivityService>()
                          : null);
                  final sessions = activityService?.getRecordedSessions() ?? const [];
                  return CbtReadinessWeeklyTrendsChart(
                    currentReadinessScore: readiness.scorePercent.toDouble(),
                    sessions: sessions,
                    targetTrack: widget.examTitle,
                  );
                }(),
                const SizedBox(height: 18),

                // Registered Courses Breakdown Section Header
                if (readiness.subjectBreakdowns.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'REGISTERED COURSES BREAKDOWN',
                          style: typography.caption.bold.copyWith(
                            color: colors.textSecondary,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary.withAlpha(20),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          readiness.isFullyCalibrated
                              ? '${readiness.subjectBreakdowns.length} Enrolled'
                              : '${readiness.calibratedCourseCount}/${readiness.totalCourseCount} Calibrated',
                          style: typography.caption.bold.copyWith(
                            color: colors.primary,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Responsive per-course cards
                  ...readiness.subjectBreakdowns.map((sub) {
                    final hasPastQuestions =
                        _subjectsWithPastQuestions.contains(sub.subjectName);

                    return ReadinessBreakdownCourseCard(
                      sub: sub,
                      examCategory: examCategory,
                      examTitle: widget.examTitle,
                      hasPastQuestions: hasPastQuestions,
                    );
                  }),
                  const SizedBox(height: 6),
                ],

                // Bottleneck, Suggestions & Action Buttons
                ReadinessBreakdownActionsSection(
                  readiness: readiness,
                  examTitle: widget.examTitle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
