import 'dart:async';
import 'dart:math' as math;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/dashboard/domain/logic/cbt_readiness_calculator.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/repositories/past_questions_repository.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_session_state.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Interactive glassmorphic CBT Readiness Score progress gauge widget for the executive dashboard.
///
/// On first mount the arc sweeps from 0 → readiness score over
/// 900ms with an easeOutCubic curve, providing a satisfying reveal animation
/// that communicates "data loaded and computed". Metric bars stagger in after.
class CbtReadinessGaugeCard extends StatefulWidget {
  const CbtReadinessGaugeCard({
    required this.readinessResult,
    required this.examTitle,
    required this.daysRemaining,
    super.key,
  });

  final CbtReadinessResult readinessResult;
  final String examTitle;
  final int daysRemaining;

  @override
  State<CbtReadinessGaugeCard> createState() => _CbtReadinessGaugeCardState();
}

class _CbtReadinessGaugeCardState extends State<CbtReadinessGaugeCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _arcController;
  late final Animation<double> _arcAnimation;

  @override
  void initState() {
    super.initState();
    _arcController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _arcAnimation = CurvedAnimation(
      parent: _arcController,
      curve: Curves.easeOutCubic,
    );
    // Delay slightly so the widget's outer container has faded in first.
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 80), () {
        if (mounted) unawaited(_arcController.forward());
      }),
    );
  }

  @override
  void didUpdateWidget(CbtReadinessGaugeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-animate when the score changes (e.g. after a data refresh).
    if (oldWidget.readinessResult.scorePercent !=
        widget.readinessResult.scorePercent) {
      _arcController.reset();
      unawaited(_arcController.forward());
    }
  }

  @override
  void dispose() {
    _arcController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final readinessResult = widget.readinessResult;
    final examTitle = widget.examTitle;

    return InkWell(
      onTap: () => _showDiagnosticSheet(context),
      borderRadius: BorderRadius.circular(AppRadius.panel),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark
              ? colors.surfaceSecondary.withAlpha(160)
              : colors.surfacePrimary.withAlpha(220),
          borderRadius: BorderRadius.circular(AppRadius.panel),
          border: Border.all(
            color: colors.surfaceBorder.withAlpha(isDark ? 60 : 35),
          ),
          boxShadow: [
            BoxShadow(
              color: colors.black.withAlpha(isDark ? 50 : 20),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CBT READINESS INDEX',
                        style: typography.caption.medium.copyWith(
                          color: colors.textSecondary,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        examTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: typography.title3.bold.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: readinessResult.statusColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(AppRadius.badge),
                    border: Border.all(
                      color: readinessResult.statusColor.withAlpha(100),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        readinessResult.statusLabel,
                        style: typography.caption.bold.copyWith(
                          color: readinessResult.statusColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: readinessResult.statusColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          readinessResult.projectedGrade,
                          style: typography.caption.bold.copyWith(
                            color: colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: AnimatedBuilder(
                    animation: _arcAnimation,
                    builder: (context, _) => CustomPaint(
                      painter: _ReadinessGaugePainter(
                        // Arc sweeps from 0 → target score.
                        scorePercent: (readinessResult.scorePercent *
                                _arcAnimation.value)
                            .round(),
                        color: readinessResult.statusColor,
                        trackColor:
                            colors.surfaceBorder.withAlpha(isDark ? 50 : 80),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${(readinessResult.scorePercent * _arcAnimation.value).round()}%',
                              style: typography.title1.bold.copyWith(
                                color: colors.textPrimary,
                                fontSize: 22,
                                height: 1,
                              ),
                            ),
                            Text(
                              'Score',
                              style: typography.caption.medium.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    children: [
                      _MetricBar(
                        label: 'Syllabus Coverage',
                        value: readinessResult.syllabusCoverage,
                        color: colors.primary,
                      ),
                      const SizedBox(height: 8),
                      _MetricBar(
                        label: 'Memory Retention',
                        value: readinessResult.fsrsRetentionRate,
                        color: const Color(0xFF10B981),
                      ),
                      const SizedBox(height: 8),
                      _MetricBar(
                        label: 'Mock Test Score',
                        value: readinessResult.mockScoreRatio,
                        color: const Color(0xFF6366F1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (readinessResult.remediationSuggestion.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: colors.primary.withAlpha(isDark ? 30 : 15),
                  borderRadius: BorderRadius.circular(AppRadius.badge),
                  border: Border.all(
                    color: colors.primary.withAlpha(isDark ? 80 : 40),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 16,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        readinessResult.remediationSuggestion,
                        style: typography.caption.medium.copyWith(
                          color: colors.textPrimary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: colors.textSecondary,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showDiagnosticSheet(BuildContext context) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (bottomSheetContext) {
          return DraggableScrollableSheet(
            initialChildSize: 0.82,
            maxChildSize: 0.94,
            minChildSize: 0.50,
            builder: (context, scrollController) {
              return _CbtReadinessBreakdownSheet(
                readinessResult: widget.readinessResult,
                examTitle: widget.examTitle,
                daysRemaining: widget.daysRemaining,
                scrollController: scrollController,
              );
            },
          );
        },
      ),
    );
  }
}

class _CbtReadinessBreakdownSheet extends StatefulWidget {
  const _CbtReadinessBreakdownSheet({
    required this.readinessResult,
    required this.examTitle,
    required this.daysRemaining,
    required this.scrollController,
  });

  final CbtReadinessResult readinessResult;
  final String examTitle;
  final int daysRemaining;
  final ScrollController scrollController;

  @override
  State<_CbtReadinessBreakdownSheet> createState() =>
      _CbtReadinessBreakdownSheetState();
}

class _CbtReadinessBreakdownSheetState
    extends State<_CbtReadinessBreakdownSheet> {
  final Set<String> _subjectsWithPastQuestions = {};

  @override
  void initState() {
    super.initState();
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

  String _cleanSlug(String input) {
    return input.trim().toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '_');
  }

  Future<void> _checkPastQuestionsAvailability() async {
    if (!locator.isRegistered<PastQuestionsRepository>()) return;

    try {
      final repo = locator<PastQuestionsRepository>();
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
    } on Object catch (_) {}
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

    return Container(
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: ListView(
              controller: widget.scrollController,
              children: [
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

                // Sheet Header: Responsive layout allowing multiline title without clipping badge
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
                  ],
                ),
                const SizedBox(height: 16),

                // Projected Score Card: Responsive stacked layout giving full width to score & grade
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        readiness.statusColor.withAlpha(isDark ? 50 : 25),
                        colors.primary.withAlpha(isDark ? 30 : 12),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(
                      color: readiness.statusColor.withAlpha(70),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'PROJECTED EXAM SCORE',
                            style: typography.caption.bold.copyWith(
                              color: colors.textSecondary,
                              fontSize: 10.5,
                              letterSpacing: 0.8,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? colors.surfacePrimary.withAlpha(180)
                                  : colors.surfaceSecondary,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.badge),
                              border: Border.all(
                                color: colors.surfaceBorder.withAlpha(40),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.speed_rounded,
                                  size: 13,
                                  color: readiness.speedReadinessRatio >= 0.8
                                      ? colors.success
                                      : colors.warning,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  readiness.speedDiagnosticLabel,
                                  style: typography.caption.bold.copyWith(
                                    color: readiness.speedReadinessRatio >= 0.8
                                        ? colors.success
                                        : colors.warning,
                                    fontSize: 10.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        readiness.projectedScoreRange,
                        style: typography.title3.bold.copyWith(
                          color: colors.textPrimary,
                          fontSize: 16,
                          height: 1.35,
                        ),
                      ),
                      if (readiness.totalCourseCount > 0) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.micro),
                                child: LinearProgressIndicator(
                                  value: readiness.calibratedCourseCount /
                                      math.max(1, readiness.totalCourseCount),
                                  minHeight: 4,
                                  backgroundColor:
                                      colors.surfaceBorder.withAlpha(60),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    readiness.isFullyCalibrated
                                        ? colors.success
                                        : colors.primary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${readiness.calibratedCourseCount}/${readiness.totalCourseCount} Calibrated',
                              style: typography.caption.medium.copyWith(
                                color: colors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
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

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colors.surfacePrimary
                            .withAlpha(isDark ? 80 : 220),
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        border: Border.all(
                          color: colors.surfaceBorder
                              .withAlpha(isDark ? 60 : 40),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top line: Subject name & Status/Grade pill
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      sub.subjectName,
                                      style: typography.body.bold.copyWith(
                                        color: colors.textPrimary,
                                        fontSize: 14.5,
                                      ),
                                    ),
                                    if (sub.courseCode.isNotEmpty &&
                                        sub.courseCode.toLowerCase() !=
                                            sub.subjectName.toLowerCase()) ...[
                                      const SizedBox(height: 1),
                                      Text(
                                        sub.courseCode,
                                        style: typography.caption.medium
                                            .copyWith(
                                              color: colors.textSecondary,
                                              fontSize: 11,
                                            ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: sub.isCalibrated
                                      ? (sub.statusColor ?? colors.primary)
                                          .withAlpha(20)
                                      : (hasPastQuestions
                                          ? colors.primary.withAlpha(20)
                                          : colors.warning.withAlpha(20)),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: sub.isCalibrated
                                        ? (sub.statusColor ?? colors.primary)
                                            .withAlpha(80)
                                        : (hasPastQuestions
                                            ? colors.primary.withAlpha(80)
                                            : colors.warning.withAlpha(80)),
                                  ),
                                ),
                                child: Text(
                                  sub.isCalibrated
                                      ? (sub.projectedGrade.isNotEmpty
                                          ? (sub.projectedGrade.endsWith('pts')
                                              ? '${sub.projectedScore} / ${sub.maxScore} pts'
                                              : '${sub.projectedScore}% · ${sub.projectedGrade}')
                                          : '${sub.projectedScore} / ${sub.maxScore}')
                                      : (hasPastQuestions
                                          ? 'Mock Ready'
                                          : 'Pending Diagnostic'),
                                  style: typography.caption.bold.copyWith(
                                    color: sub.isCalibrated
                                        ? (sub.statusColor ?? colors.primary)
                                        : (hasPastQuestions
                                            ? colors.primary
                                            : colors.warning),
                                    fontSize: 10.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Calibrated vs Uncalibrated State
                          if (sub.isCalibrated) ...[
                            Row(
                              children: [
                                Text(
                                  'Syllabus: ${(sub.coveragePercent * 100).round()}%',
                                  style: typography.caption.regular.copyWith(
                                    color: colors.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Accuracy: ${(sub.accuracyPercent * 100).round()}%',
                                  style: typography.caption.regular.copyWith(
                                    color: colors.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${sub.readinessPercent}% Readiness',
                                  style: typography.caption.bold.copyWith(
                                    color: sub.statusColor ?? colors.primary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.micro),
                              child: LinearProgressIndicator(
                                value: sub.readinessPercent / 100.0,
                                minHeight: 6,
                                backgroundColor:
                                    colors.surfaceBorder.withAlpha(50),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  sub.statusColor ?? colors.primary,
                                ),
                              ),
                            ),
                            if (hasPastQuestions) ...[
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: InkWell(
                                  onTap: () {
                                    Navigator.pop(context);
                                    unawaited(
                                      context.router.push(
                                        MockExamLobbyRoute(
                                          examId:
                                              'cbt_mock_${_cleanSlug(sub.subjectName)}',
                                          examName: sub.subjectName,
                                          subjectTrack: widget.examTitle,
                                          courseCode: sub.courseCode.isNotEmpty
                                              ? sub.courseCode
                                              : sub.subjectName,
                                        ),
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.refresh_rounded,
                                          size: 13,
                                          color: colors.primary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Retake Mock Exam',
                                          style: typography.caption.bold
                                              .copyWith(
                                                color: colors.primary,
                                                fontSize: 11,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ] else ...[
                            Text(
                              hasPastQuestions
                                  ? 'Official past questions available. Take a mock exam to calibrate your readiness index.'
                                  : 'No quiz or study activity recorded yet. Complete a 10-item diagnostic to unlock readiness.',
                              style: typography.caption.regular.copyWith(
                                color: colors.textSecondary,
                                fontSize: 11.5,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Action buttons: Mock Exam for courses with past questions, Diagnostic for courses without
                            if (hasPastQuestions) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: ShrinkableButton(
                                      onTap: () {
                                        Navigator.pop(context);
                                        unawaited(
                                          context.router.push(
                                            MockExamLobbyRoute(
                                              examId:
                                                  'cbt_mock_${_cleanSlug(sub.subjectName)}',
                                              examName: sub.subjectName,
                                              subjectTrack: widget.examTitle,
                                              courseCode:
                                                  sub.courseCode.isNotEmpty
                                                      ? sub.courseCode
                                                      : sub.subjectName,
                                            ),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: colors.primary,
                                          borderRadius: BorderRadius.circular(
                                            AppRadius.badge,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: colors.primary
                                                  .withAlpha(isDark ? 50 : 25),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.timer_outlined,
                                              size: 16,
                                              color: colors.white,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Start Mock Exam',
                                              style: typography.caption.bold
                                                  .copyWith(
                                                    color: colors.white,
                                                    fontSize: 12,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: Icon(
                                      Icons.menu_book_outlined,
                                      size: 18,
                                      color: colors.primary,
                                    ),
                                    tooltip: 'Browse Past Questions',
                                    style: IconButton.styleFrom(
                                      backgroundColor:
                                          colors.primary.withAlpha(20),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.badge,
                                        ),
                                      ),
                                      padding: const EdgeInsets.all(8),
                                      minimumSize: const Size(38, 38),
                                    ),
                                    onPressed: () {
                                      Navigator.pop(context);
                                      unawaited(
                                        context.router.push(
                                          CourseQuestionsRoute(
                                            courseTitle: sub.subjectName,
                                            courseCode:
                                                sub.courseCode.isNotEmpty
                                                    ? sub.courseCode
                                                    : null,
                                            examCategory: examCategory,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ] else ...[
                              ShrinkableButton(
                                onTap: () {
                                  Navigator.pop(context);
                                  unawaited(
                                    context.router.push(
                                      QuizWorkspaceRoute(
                                        deckId:
                                            'cbt_diagnostic_${_cleanSlug(sub.courseCode.isNotEmpty ? sub.courseCode : sub.subjectName)}',
                                        deckTitle:
                                            '${sub.subjectName} Diagnostic Quiz',
                                        subject: sub.subjectName,
                                        courseCode: sub.courseCode.isNotEmpty
                                            ? sub.courseCode
                                            : sub.subjectName,
                                        durationMinutes: 10,
                                        assessmentMode:
                                            AssessmentMode.examSimulationMode,
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  width: double.infinity,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: colors.primary
                                        .withAlpha(isDark ? 45 : 25),
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.badge,
                                    ),
                                    border: Border.all(
                                      color: colors.primary.withAlpha(120),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.bolt_rounded,
                                        size: 16,
                                        color: colors.primary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Take 10-Item Diagnostic Quiz',
                                        style: typography.caption.bold.copyWith(
                                          color: colors.primary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 14),
                ],

                // Primary Bottleneck Diagnostic
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.surfacePrimary
                        .withAlpha(isDark ? 60 : 200),
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(
                      color: colors.surfaceBorder.withAlpha(60),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: readiness.statusColor,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Primary Bottleneck Diagnostic',
                              style: typography.caption.bold.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        readiness.weakestAreaLabel.isNotEmpty
                            ? readiness.weakestAreaLabel
                            : 'Memory Retention Stability',
                        style: typography.body.bold.copyWith(
                          color: colors.textPrimary,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Actionable Remediation
                Text(
                  'RECOMMENDED ACTION',
                  style: typography.caption.bold.copyWith(
                    color: colors.textSecondary,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.primary.withAlpha(isDark ? 40 : 20),
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(color: colors.primary.withAlpha(80)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.bolt_rounded, color: colors.primary, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          readiness.remediationSuggestion,
                          style: typography.body.medium.copyWith(
                            color: colors.textPrimary,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Responsive Bottom Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          final rawWeakest = readiness.weakestAreaLabel;
                          final cleanSubject = rawWeakest.contains('(')
                              ? rawWeakest.split('(').first.trim()
                              : (rawWeakest.isNotEmpty
                                  ? rawWeakest.trim()
                                  : 'key concepts');
                          final prompt =
                              "Let's do an interactive study sprint for $cleanSubject to boost my ${widget.examTitle} exam readiness. Please quiz me on high-yield syllabus topics and explain core concepts step-by-step.";
                          unawaited(
                            context.router.push(
                              SyllabotChatRoute(initialPrompt: prompt),
                            ),
                          );
                        },
                        icon: Icon(
                          Icons.auto_awesome_rounded,
                          size: 16,
                          color: colors.primary,
                        ),
                        label: Text(
                          'AI Sprint',
                          style: typography.body.medium.copyWith(
                            color: colors.textPrimary,
                            fontSize: 13,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.card),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.card),
                          ),
                        ),
                        child: Text(
                          'Done',
                          style: typography.body.medium.copyWith(
                            color: colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricBar extends StatelessWidget {
  const _MetricBar({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final percent = (value.clamp(0.0, 1.0) * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: typography.caption.medium.copyWith(
                color: colors.textSecondary,
              ),
            ),
            Text(
              '$percent%',
              style: typography.caption.bold.copyWith(
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.micro),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: colors.surfaceBorder.withAlpha(60),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _ReadinessGaugePainter extends CustomPainter {
  _ReadinessGaugePainter({
    required this.scorePercent,
    required this.color,
    required this.trackColor,
  });

  final int scorePercent;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 12) / 2;
    const strokeWidth = 10.0;
    const startAngle = 0.75 * math.pi;
    const totalSweep = 1.5 * math.pi;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      totalSweep,
      false,
      trackPaint,
    );

    final sweepAngle = totalSweep * (scorePercent / 100.0);
    final valuePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    if (sweepAngle > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        valuePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ReadinessGaugePainter oldDelegate) {
    return oldDelegate.scorePercent != scorePercent ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor;
  }
}
