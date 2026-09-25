import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_event.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_hub_bloc.dart';
import 'package:kortex/src/features/community/presentation/widgets/create_post_bottom_sheet.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:kortex/src/features/decks/data/data_sources/decks_remote_data_source.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_event.dart';
import 'package:kortex/src/features/monetization/domain/services/subscription_guard.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_cubit.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_result_entity.dart';
import 'package:kortex/src/features/quiz/domain/logic/academic_grade_evaluator.dart';
import 'package:kortex/src/features/quiz/domain/logic/quiz_content_sanitizer.dart';
import 'package:kortex/src/features/quiz/domain/use_cases/convert_failed_quiz_to_deck_use_case.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_session_state.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/quiz_shell.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_back_button.dart';
import 'package:kortex/src/shared/widgets/gratification_celebration_overlay.dart';
import 'package:share_plus/share_plus.dart';

@RoutePage()
class QuizResultsPage extends StatefulWidget {
  const QuizResultsPage({
    required this.result,
    this.questions = const [],
    this.courseId,
    this.courseCode,
    this.assessmentMode = AssessmentMode.discoveryMode,
    this.currentTier = 1,
    this.bankedTier = 0,
    this.speedBonusXp = 0,
    this.isWalkedAway = false,
    this.showCelebrationDialog = true,
    super.key,
  });

  final QuizResultEntity result;
  final List<QuizQuestionEntity> questions;
  final String? courseId;
  final String? courseCode;
  final AssessmentMode assessmentMode;
  final int currentTier;
  final int bankedTier;
  final int speedBonusXp;
  final bool isWalkedAway;
  final bool showCelebrationDialog;

  @override
  State<QuizResultsPage> createState() => _QuizResultsPageState();
}

class _QuizResultsPageState extends State<QuizResultsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // If this quiz is associated with an active exam, update its empirical grade in CramPlannerCubit
      if (locator.isRegistered<CramPlannerCubit>()) {
        try {
          final planner = locator<CramPlannerCubit>();
          final exams = planner.state.activeExams;
          final matched = exams.where((e) {
            return (widget.courseCode != null &&
                    widget.courseCode!.isNotEmpty &&
                    (e.subjectTrack
                            .toLowerCase()
                            .contains(widget.courseCode!.toLowerCase()) ||
                        e.examName
                            .toLowerCase()
                            .contains(widget.courseCode!.toLowerCase()))) ||
                widget.result.quizTitle
                    .toLowerCase()
                    .contains(e.examName.toLowerCase()) ||
                e.examName
                    .toLowerCase()
                    .contains(widget.result.quizTitle.toLowerCase());
          }).firstOrNull;
          if (matched != null) {
            unawaited(
              planner.completeAssessment(
                examId: matched.id,
                scorePercent:
                    (widget.result.scorePercent / 100.0).clamp(0.0, 1.0),
              ),
            );
          }
        } on Object catch (_) {}
      }

      if (widget.showCelebrationDialog) {
        final isMillionaire =
            widget.assessmentMode == AssessmentMode.millionaireMode;
        final isMockExam =
            widget.assessmentMode == AssessmentMode.examSimulationMode;
        final score = widget.result.scorePercent;

        final String title;
        final String subtitle;
        final String emoji;
        final String? badge;

        if (isMillionaire) {
          emoji = '👑';
          title = widget.currentTier >= 12
              ? 'Top of the Ladder!'
              : 'Progress Banked!';
          subtitle =
              'You conquered ${widget.currentTier} tiers and banked ${(widget.currentTier * 100) + widget.speedBonusXp} XP!';
          badge = '👑 Millionaire Scholar';
        } else if (isMockExam) {
          emoji = score >= 80 ? '🎓' : (score >= 50 ? '🏛️' : '📝');
          title = score >= 90
              ? 'Exam Mastery Achieved!'
              : (score >= 70
                  ? 'Mock Exam Completed!'
                  : (score >= 50
                      ? 'Exam Simulation Done!'
                      : 'Mock Exam Finished!'));
          subtitle = score >= 70
              ? 'You completed the full exam simulation with $score% accuracy. Exam readiness locked in!'
              : 'Completed the full exam simulation. Reviewing your missed questions now will solidify your readiness.';
          badge = '🎓 Exam Simulation Milestone';
        } else {
          emoji = score >= 90 ? '🌟' : (score >= 70 ? '⚡' : '💪');
          title = score >= 90
              ? 'Flawless Knowledge!'
              : (score >= 70
                  ? 'Quiz Completed!'
                  : (score >= 50
                      ? 'Milestone Complete!'
                      : 'Practice Finished!'));
          subtitle = score >= 70
              ? 'You answered ${widget.result.correctAnswers}/${widget.result.totalQuestions} questions correctly! Synaptic recall sharpened.'
              : 'Consistency is what builds genius. Review your answers below to convert every mistake into mastery.';
          badge = '⚡ Active Practice Milestone';
        }

        final xp = isMillionaire
            ? (widget.currentTier * 100) + widget.speedBonusXp
            : (widget.result.correctAnswers * 15);

        final mistakes = _missedQuestions;

        unawaited(
          GratificationCelebrationOverlay.show(
            context,
            title: title,
            subtitle: subtitle,
            primaryStatLabel: 'Score',
            primaryStatValue: '$score%',
            secondaryStatLabel: 'Correct',
            secondaryStatValue:
                '${widget.result.correctAnswers}/${widget.result.totalQuestions}',
            tertiaryStatLabel: 'XP Earned',
            tertiaryStatValue: '+$xp',
            xpEarned: xp,
            motivationalBadge: badge,
            buttonText: 'See Full Breakdown',
            secondaryButtonText: mistakes.isNotEmpty
                ? 'Review Mistakes'
                : 'Practice Again',
            onSecondaryAction: () {
              if (mistakes.isNotEmpty) {
                _openMistakeReview(context, mistakes);
              } else {
                _handleTryAgain(context);
              }
            },
            emoji: emoji,
          ),
        );
      }
    });
  }

  bool _isBigWin(int score) {
    if (widget.assessmentMode == AssessmentMode.millionaireMode) {
      return widget.currentTier >= 12 || widget.isWalkedAway;
    }
    return score >= 90;
  }

  bool _isQuestionCorrect(QuizQuestionEntity q) {
    if (q.isCorrect) return true;
    if (q.userSelectedAnswer == null || q.userSelectedAnswer!.trim().isEmpty) {
      return false;
    }
    final cleanCorrect = QuizContentSanitizer.cleanOptionText(
      q.correctAnswer,
    ).trim().toLowerCase();
    final cleanSelected = QuizContentSanitizer.cleanOptionText(
      q.userSelectedAnswer!,
    ).trim().toLowerCase();
    return cleanCorrect == cleanSelected ||
        q.userSelectedAnswer!.trim().toLowerCase() ==
            q.correctAnswer.trim().toLowerCase();
  }

  List<QuizQuestionEntity> get _missedQuestions =>
      widget.questions.where((q) => !_isQuestionCorrect(q)).toList();

  int get _mistakeCount {
    if (widget.questions.isNotEmpty) return _missedQuestions.length;
    final missed = widget.result.totalQuestions - widget.result.correctAnswers;
    return missed < 0 ? 0 : missed;
  }

  int get _xpEarned => widget.assessmentMode == AssessmentMode.millionaireMode
      ? (widget.currentTier * 100) + widget.speedBonusXp
      : widget.result.correctAnswers * 15;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;
    final reduceMotion = quizReduceMotion(context);

    final isMillionaire =
        widget.assessmentMode == AssessmentMode.millionaireMode;
    final score = widget.result.scorePercent;
    final isPassed = isMillionaire || score >= kQuizPassScore;
    final bigWin = _isBigWin(score);
    final result = widget.result;
    final mistakes = _mistakeCount;

    return Scaffold(
      backgroundColor: isDark
          ? colors.backgroundPrimary
          : colors.surfacePrimary,
      appBar: AppBar(
        backgroundColor: colors.transparent,
        elevation: 0,
        leading: const AppBackButton(),
        title: Text(
          result.quizTitle,
          style: typography.title3.bold.copyWith(
            color: colors.textPrimary,
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              // Quiet recognition sits on the page itself. The modal
              // celebration is saved for the once-in-a-while moments.
              if (isPassed && !bigWin)
                QuizInlineBanner(
                  icon: Icons.emoji_events_rounded,
                  tone: QuizBannerTone.success,
                  title: isMillionaire
                      ? 'Tier ${widget.currentTier} banked'
                      : 'You passed this one',
                  message:
                      'Nice work. Everything that needs another pass is '
                      'listed below.',
                  reduceMotion: reduceMotion,
                ),

              // 1. Hero: the headline number, drawn in on arrival.
              QuizStaggeredFade(
                reduceMotion: reduceMotion,
                child: isMillionaire
                    ? _buildMillionaireHero(context)
                    : _buildScoreHero(context),
              ),

              const SizedBox(height: 18),

              // 2. The three numbers that matter, nothing more.
              Row(
                children: [
                  Expanded(
                    child: QuizStatChip(
                      label: 'XP earned',
                      value: '+$_xpEarned',
                      color: colors.primary,
                      reduceMotion: reduceMotion,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: QuizStatChip(
                      label: 'Time taken',
                      value: _formatDuration(result.durationSeconds),
                      color: colors.syllabotAccent,
                      reduceMotion: reduceMotion,
                      staggerIndex: 1,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: QuizStatChip(
                      label: 'Mistakes',
                      value: '$mistakes',
                      color: mistakes == 0 ? colors.success : colors.warning,
                      reduceMotion: reduceMotion,
                      staggerIndex: 2,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // 2.5. Seamless Quick Study Actions
              QuizStaggeredFade(
                index: 2,
                reduceMotion: reduceMotion,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? colors.surfaceSecondary
                        : colors.surfacePrimary,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(color: colors.surfaceBorder),
                    boxShadow: [
                      BoxShadow(
                        color: colors.black.withAlpha(isDark ? 20 : 4),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      if (widget.questions.isNotEmpty) ...[
                        Expanded(
                          child: _ResultQuickActionButton(
                            icon: Icons.replay_rounded,
                            label: 'Retake',
                            color: colors.primary,
                            onTap: () => _handleTryAgain(context),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: _ResultQuickActionButton(
                          icon: Icons.style_rounded,
                          label: 'Flashcards',
                          color: colors.syllabotAccent,
                          onTap: () => unawaited(
                            _handlePracticeWeakFlashcards(context),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ResultQuickActionButton(
                          icon: Icons.forum_rounded,
                          label: 'Ask Class',
                          color: colors.info,
                          onTap: () => _handleAskClassForHelp(context),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ResultQuickActionButton(
                          icon: Icons.share_rounded,
                          label: 'Share',
                          color: colors.textSecondary,
                          onTap: () => _handleShareResult(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // 3. Topic breakdown.
              Text(
                l10n.quizTopicWeakness,
                style: typography.title3.bold.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              if (result.weaknesses.isEmpty)
                QuizStaggeredFade(
                  index: 1,
                  reduceMotion: reduceMotion,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Every topic looks solid. Keep practising to hold it.',
                      style: typography.body.regular.copyWith(
                        color: colors.success,
                      ),
                    ),
                  ),
                )
              else
                ...result.weaknesses.asMap().entries.map((entry) {
                  final weakness = entry.value;
                  final acc = (weakness.accuracy * 100).toInt();
                  final isWeak = weakness.isWeak;
                  final badgeColor = isWeak ? colors.error : colors.success;

                  return QuizStaggeredFade(
                    index: 1 + (entry.key % 6),
                    distance: 10,
                    reduceMotion: reduceMotion,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? colors.surfaceSecondary
                            : colors.surfacePrimary,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        border: Border.all(
                          color: isWeak
                              ? colors.error.withValues(alpha: 0.3)
                              : colors.surfaceBorder,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colors.black.withAlpha(isDark ? 20 : 4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  weakness.subTopic,
                                  style: typography.body.bold.copyWith(
                                    color: colors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${weakness.correctCount} of '
                                  '${weakness.totalQuestions} correct',
                                  style: typography.caption.regular.copyWith(
                                    color: colors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(
                                AppRadius.badge,
                              ),
                              border: Border.all(
                                color: badgeColor.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              '$acc%',
                              style: typography.caption.bold.copyWith(
                                color: badgeColor,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),

              // 4. What to look at next, framed forward instead of punitive.
              if (mistakes > 0) ...[
                const SizedBox(height: 24),
                QuizStaggeredFade(
                  index: 2,
                  reduceMotion: reduceMotion,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.warning.withValues(
                        alpha: isDark ? 0.15 : 0.08,
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      border: Border.all(
                        color: colors.warning.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: colors.warning.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.psychology_alt_rounded,
                            color: colors.warning,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Where to focus next',
                                style: typography.subhead.bold.copyWith(
                                  color: colors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$mistakes ${mistakes == 1 ? 'question' : 'questions'} '
                                'need another pass. Reviewing them now is '
                                'when it sticks.',
                                style: typography.caption.regular.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildActionsBar(context),
    );
  }

  /// Standard hero: an animated arc drawing the score, then the number
  /// counting up to meet it. One moment, one number, no modal.
  Widget _buildScoreHero(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final reduceMotion = quizReduceMotion(context);
    final result = widget.result;
    final score = result.scorePercent;
    final isPassed = score >= kQuizPassScore;
    final gradeColor = isPassed ? colors.success : colors.warning;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            gradeColor.withValues(alpha: isDark ? 0.25 : 0.12),
            (isDark ? colors.surfaceSecondary : colors.surfacePrimary)
                .withValues(alpha: 0.95),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(AppRadius.panel),
        border: Border.all(color: gradeColor.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: colors.black.withAlpha(isDark ? 25 : 6),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            width: 168,
            height: 168,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 700),
              curve: AppMotion.easeOutCubic,
              builder: (context, t, _) => CustomPaint(
                painter: _ScoreArcPainter(
                  progress: t,
                  color: gradeColor,
                  trackColor: colors.surfaceBorder,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(score * t).round()}%',
                        style: typography.largeTitle.bold.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'score',
                        style: typography.caption.regular.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isPassed ? 'You scored $score%' : 'You scored $score% this time',
            style: typography.title3.bold.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            '${result.correctAnswers} of ${result.totalQuestions} '
            'questions correct',
            style: typography.body.regular.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          // Real-World Standard Grade Badge
          () {
            final activeTrack =
                context.watch<AuthBloc?>()?.state.userProfile?.targetTrack;
            final gradeResult = AcademicGradeEvaluator.evaluate(
              scorePercent: score.toDouble(),
              track: activeTrack ?? widget.courseCode,
            );

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: gradeResult.gradeColor.withAlpha(isDark ? 35 : 18),
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(
                  color: gradeResult.gradeColor.withAlpha(isDark ? 90 : 60),
                ),
              ),
              child: Column(
                children: [
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        size: 16,
                        color: gradeResult.gradeColor,
                      ),
                      Text(
                        'Real-World Grade: ${gradeResult.grade}',
                        style: typography.callout.bold.copyWith(
                          color: gradeResult.gradeColor,
                          fontSize: 14,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: gradeResult.gradeColor.withAlpha(
                            isDark ? 50 : 30,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          gradeResult.classification,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: typography.caption.bold.copyWith(
                            color: gradeResult.gradeColor,
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${gradeResult.standard} • ${gradeResult.remark}',
                    textAlign: TextAlign.center,
                    style: typography.footnote.regular.copyWith(
                      color: colors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            );
          }(),
        ],
      ),
    );
  }

  /// Millionaire hero: the climb result, with the banked prize stated plainly.
  Widget _buildMillionaireHero(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final isWalkedAway = widget.isWalkedAway;
    final currentTier = widget.currentTier;
    final speedBonusXp = widget.speedBonusXp;
    final reachedTop = currentTier >= 12;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            if (isDark) colors.surfaceSecondary else colors.surfacePrimary,
            if (isDark) colors.backgroundSecondary else colors.surfaceSecondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.panel),
        border: Border.all(
          color: isWalkedAway || reachedTop
              ? colors.warning.withValues(alpha: 0.6)
              : colors.success.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: reachedTop
                    ? [colors.warning, colors.warning.withAlpha(200)]
                    : isWalkedAway
                    ? [colors.success, colors.success.withAlpha(200)]
                    : [colors.syllabotAccent, colors.primary],
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              reachedTop
                  ? Icons.emoji_events_rounded
                  : isWalkedAway
                  ? Icons.savings_rounded
                  : Icons.military_tech_rounded,
              size: 36,
              color: colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            reachedTop
                ? 'You reached the top'
                : isWalkedAway
                ? 'You cashed out'
                : 'Tier $currentTier reached',
            textAlign: TextAlign.center,
            style: typography.title3.bold.copyWith(color: colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            reachedTop
                ? 'All 12 tiers, one after another. The whole ladder is yours.'
                : isWalkedAway
                ? 'Your Tier ${widget.bankedTier} prize is banked and stays '
                      'with you.'
                : 'You climbed to Tier $currentTier. Anything you banked '
                      'stays with you.',
            textAlign: TextAlign.center,
            style: typography.footnote.regular.copyWith(
              color: colors.white.withAlpha(200),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: colors.white.withValues(alpha: 0.15)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatColumn(
                  title: 'Tier',
                  value: '$currentTier / 12',
                  color: colors.warning,
                ),
                Container(
                  width: 1,
                  height: 28,
                  color: colors.white.withAlpha(50),
                ),
                _StatColumn(
                  title: 'Speed bonus',
                  value: '+$speedBonusXp XP',
                  color: colors.success,
                ),
                Container(
                  width: 1,
                  height: 28,
                  color: colors.white.withAlpha(50),
                ),
                _StatColumn(
                  title: 'Banked XP',
                  value: '${(currentTier * 100) + speedBonusXp}',
                  color: colors.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Seamless direct actions: Retake + Primary Review.
  Widget _buildActionsBar(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final mistakes = _missedQuestions;
    final hasMistakesToReview = mistakes.isNotEmpty;
    final canRestart = widget.questions.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: isDark ? colors.backgroundPrimary : colors.surfacePrimary,
        border: Border(top: BorderSide(color: colors.surfaceBorder)),
        boxShadow: [
          BoxShadow(
            color: colors.black.withAlpha(isDark ? 30 : 6),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Align(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Row(
              children: [
                if (canRestart) ...[
                  SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      icon: Icon(
                        Icons.replay_rounded,
                        size: 18,
                        color: colors.textPrimary,
                      ),
                      label: Text(
                        'Retake',
                        style: typography.callout.bold.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      onPressed: () => _handleTryAgain(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: colors.surfaceBorderHighlight),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.card),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      icon: Icon(
                        hasMistakesToReview
                            ? Icons.visibility_rounded
                            : Icons.check_circle_rounded,
                        size: 20,
                        color: colors.white,
                      ),
                      label: Text(
                        hasMistakesToReview
                            ? 'Review ${mistakes.length} ${mistakes.length == 1 ? 'Mistake' : 'Mistakes'}'
                            : (widget.questions.isNotEmpty
                                ? 'Review All Answers'
                                : 'Back to dashboard'),
                        style: typography.callout.bold.copyWith(
                          color: colors.white,
                        ),
                      ),
                      onPressed: () {
                        if (hasMistakesToReview) {
                          _openMistakeReview(context, mistakes);
                        } else if (widget.questions.isNotEmpty) {
                          _openMistakeReview(context, widget.questions);
                        } else {
                          context.router.popUntilRoot();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.card),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Sends the student back through the workspace, read-only, with every
  /// verdict already revealed. Review beats rereading a list of mistakes.
  void _openMistakeReview(
    BuildContext context,
    List<QuizQuestionEntity> mistakes,
  ) {
    unawaited(HapticFeedback.lightImpact());
    unawaited(
      context.router.push(
        QuizWorkspaceRoute(
          deckId: 'review-${widget.result.id}',
          deckTitle: 'Review: ${widget.result.quizTitle}',
          initialQuestions: mistakes,
          courseId: widget.courseId,
          courseCode: widget.courseCode,
          reviewMode: true,
        ),
      ),
    );
  }

  void _handleTryAgain(BuildContext context) {
    unawaited(HapticFeedback.lightImpact());
    final fresh = widget.questions
        .map(
          (q) => q.copyWith(
            isAnswered: false,
            isCorrect: false,
            clearUserSelectedAnswer: true,
          ),
        )
        .toList();
    unawaited(
      context.router.push(
        QuizWorkspaceRoute(
          deckId: 'retry-${widget.result.id}',
          deckTitle: widget.result.quizTitle,
          initialQuestions: fresh,
          courseId: widget.courseId,
          courseCode: widget.courseCode,
          assessmentMode: widget.assessmentMode,
        ),
      ),
    );
  }

  Future<void> _handleShareResult(BuildContext context) async {
    unawaited(HapticFeedback.lightImpact());
    final result = widget.result;
    final message =
        'I scored ${result.scorePercent}% on "${result.quizTitle}" in '
        'Kortex (${result.correctAnswers} of ${result.totalQuestions} '
        'correct).';
    try {
      final box = context.findRenderObject() as RenderBox?;
      final origin = box != null && box.hasSize
          ? box.localToGlobal(Offset.zero) & box.size
          : null;
      await SharePlus.instance.share(
        ShareParams(
          text: message,
          sharePositionOrigin: origin,
        ),
      );
    } on Object catch (_) {
      // Share failed — fall back to clipboard.
      await Clipboard.setData(ClipboardData(text: message));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.quizResultCopied),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _handleAskClassForHelp(BuildContext context) {
    unawaited(HapticFeedback.lightImpact());
    final incorrectQuestions = _missedQuestions;
    final questionToAsk = incorrectQuestions.isNotEmpty
        ? incorrectQuestions.first
        : widget.questions.firstOrNull;

    final topicTag = questionToAsk?.subTopic.trim().isNotEmpty == true
        ? questionToAsk!.subTopic.trim()
        : (widget.courseCode ?? 'Quiz review');

    final contentBuf = StringBuffer();
    if (questionToAsk != null) {
      contentBuf.writeln(questionToAsk.prompt.replaceAll('**', ''));
      if (questionToAsk.options.isNotEmpty) {
        contentBuf
          ..writeln()
          ..writeln('Options:');
        for (final opt in questionToAsk.options) {
          contentBuf.writeln('• ${opt.replaceAll('**', '')}');
        }
      }
      contentBuf
        ..writeln()
        ..writeln(
          'Your Answer: ${questionToAsk.userSelectedAnswer ?? 'Unanswered'}',
        )
        ..writeln('Correct Answer: ${questionToAsk.correctAnswer}');
      if (questionToAsk.explanation.isNotEmpty) {
        contentBuf
          ..writeln()
          ..writeln(
            'Explanation:\n${questionToAsk.explanation.replaceAll('**', '')}',
          );
      }
      contentBuf
        ..writeln()
        ..writeln(
          'I missed this one during practice. Can someone break down how '
          'to approach it?',
        );
    }

    unawaited(
      CreatePostBottomSheet.show(
        context,
        lockedTrack: widget.courseCode,
        initialTitle: '[$topicTag] Question discussion',
        initialContent: contentBuf.toString().trim(),
        initialLatex: questionToAsk?.latexFormula,
        initialSyllabusTag: topicTag,
        initialIsQuestion: true,
        contextBadge: 'Practice question • $topicTag',
        onSubmit:
            ({
              required title,
              required content,
              required track,
              latexContent,
              isQuestion = true,
              syllabusTag = 'General',
              isAnonymous = true,
            }) {
              if (locator.isRegistered<CommunityHubBloc>()) {
                final effectiveTag = questionToAsk?.subTopic ?? syllabusTag;
                locator<CommunityHubBloc>().add(
                  CreateForumPostEvent(
                    title: title,
                    content: content,
                    track: track,
                    latexContent: latexContent,
                    isQuestion: true,
                    syllabusTag: effectiveTag,
                    isAnonymous: isAnonymous,
                  ),
                );
              }
              context.showSnackBar(
                message: 'Posted to your class. Replies show up in the feed.',
                type: SnackBarType.success,
              );
            },
      ),
    );
  }

  Future<void> _handlePracticeWeakFlashcards(BuildContext context) async {
    unawaited(HapticFeedback.lightImpact());

    if (locator.isRegistered<SubscriptionGuard>()) {
      final isPro = await locator<SubscriptionGuard>().requirePro(
        context,
        featureName: 'Quiz Weakness Flashcards',
      );
      if (!isPro || !context.mounted) return;
    }

    // Prioritize questions that were answered incorrectly; fallback to all questions
    final incorrectQuestions = _missedQuestions;
    final questionsToUse = incorrectQuestions.isNotEmpty
        ? incorrectQuestions
        : widget.questions;

    if (questionsToUse.isEmpty && widget.result.weaknesses.isEmpty) {
      context.showSnackBar(
        message: 'There are no questions to turn into flashcards yet.',
      );
      return;
    }

    // Resolve course affiliation if not explicitly supplied
    var resolvedCourseId = widget.courseId?.trim();
    var resolvedCourseCode = widget.courseCode?.trim();

    if ((resolvedCourseId == null || resolvedCourseId.isEmpty) &&
        (resolvedCourseCode == null || resolvedCourseCode.isEmpty)) {
      if (locator.isRegistered<DecksBloc>()) {
        final allDecks = locator<DecksBloc>().state.allDecks;
        for (final d in allDecks) {
          if (d.courseCode != null &&
              d.courseCode!.isNotEmpty &&
              widget.result.quizTitle.toLowerCase().contains(
                d.courseCode!.toLowerCase(),
              )) {
            resolvedCourseId = d.courseId;
            resolvedCourseCode = d.courseCode;
            break;
          }
        }
      }
    }

    final convertUseCase =
        locator.isRegistered<ConvertFailedQuizToDeckUseCase>()
        ? locator<ConvertFailedQuizToDeckUseCase>()
        : ConvertFailedQuizToDeckUseCase(locator<DecksRemoteDataSource>());

    final conversionResult = await convertUseCase(
      result: widget.result,
      questions: widget.questions,
      courseId: resolvedCourseId,
      courseCode: resolvedCourseCode,
    );

    conversionResult.fold(
      (failure) {
        if (context.mounted) {
          context.showSnackBar(
            message: failure.message ?? 'The flashcards could not be created.',
            type: SnackBarType.error,
          );
        }
      },
      (deck) {
        // Refresh DecksBloc & DashboardBloc
        if (locator.isRegistered<DecksBloc>()) {
          locator<DecksBloc>().add(const DecksRefreshed());
        }
        if (locator.isRegistered<DashboardBloc>()) {
          locator<DashboardBloc>().add(const DashboardRefreshed());
        }

        if (context.mounted) {
          context.showSnackBar(
            message:
                'Your missed questions are now ${deck.totalCards} '
                'flashcards.',
            type: SnackBarType.success,
          );

          int? daysUntilExam;
          if (locator.isRegistered<CramPlannerCubit>()) {
            final exams = locator<CramPlannerCubit>().state.activeExams;
            final matched = exams.where((e) =>
                e.daysRemaining > 0 &&
                e.daysRemaining <= 14 &&
                (resolvedCourseCode != null &&
                    resolvedCourseCode.isNotEmpty &&
                    (e.subjectTrack.toLowerCase() ==
                            resolvedCourseCode.toLowerCase() ||
                        e.examName.toLowerCase().contains(
                            resolvedCourseCode.toLowerCase()))),
            ).firstOrNull ?? exams.where((e) => e.daysRemaining > 0 && e.daysRemaining <= 14).firstOrNull;
            if (matched != null) {
              daysUntilExam = matched.daysRemaining;
            }
          }

          final targetDeckId = (daysUntilExam != null && daysUntilExam > 0)
              ? 'cram:$daysUntilExam:${deck.id}'
              : deck.id;

          unawaited(
            context.router.replace(
              StudySessionRoute(deckId: targetDeckId),
            ),
          );
        }
      },
    );
  }

  static String _formatDuration(int seconds) {
    if (seconds <= 0) return '0s';
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    if (minutes == 0) return '${rest}s';
    if (rest == 0) return '${minutes}m';
    return '${minutes}m ${rest}s';
  }
}

/// The score ring behind the counting number.
class _ScoreArcPainter extends CustomPainter {
  const _ScoreArcPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  /// 0 → 1 sweep of the arc.
  final double progress;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    canvas.drawArc(rect, 0, 2 * 3.141592653589793, false, track);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(
      rect,
      -1.5707963267948966,
      2 * 3.141592653589793 * progress,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_ScoreArcPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.trackColor != trackColor;
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.title,
    required this.value,
    required this.color,
  });

  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: typography.caption.bold.copyWith(
            color: colors.white.withAlpha(180),
            fontSize: 10.5,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: typography.subhead.bold.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ResultQuickActionButton extends StatelessWidget {
  const _ResultQuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return InkWell(
      onTap: () {
        unawaited(HapticFeedback.lightImpact());
        onTap();
      },
      borderRadius: AppRadius.radiusCard,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.15 : 0.08),
          borderRadius: AppRadius.radiusCard,
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 6),
            Text(
              label,
              style: typography.caption.bold.copyWith(
                color: colors.textPrimary,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
