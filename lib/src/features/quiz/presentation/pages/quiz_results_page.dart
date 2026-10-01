import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/link_sharing_service.dart';
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
import 'package:kortex/src/features/quiz/domain/services/assessment_orchestrator_service.dart';
import 'package:kortex/src/features/quiz/domain/use_cases/convert_failed_quiz_to_deck_use_case.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_session_state.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/quiz_shell.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_back_button.dart';
import 'package:kortex/src/shared/widgets/gratification_celebration_overlay.dart';

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

      // Process closed-loop telemetry, FSRS recalibration, & readiness index via AssessmentOrchestratorService
      if (locator.isRegistered<AssessmentOrchestratorService>()) {
        try {
          final orchestrator = locator<AssessmentOrchestratorService>();
          final activeTrack =
              context.read<AuthBloc?>()?.state.userProfile?.targetTrack;
          unawaited(
            orchestrator.processQuizCompletion(
              scorePercent: widget.result.scorePercent.toDouble(),
              totalQuestions: widget.result.totalQuestions,
              correctAnswers: widget.result.correctAnswers,
              questions: widget.questions,
              userAnswers: widget.questions.map((q) => q.isCorrect ? 1 : 0).toList(),
              courseCode: widget.courseCode,
              explicitTrack: activeTrack ?? widget.courseCode,
            ),
          );
        } on Object catch (_) {}
      }

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

              // 2.2 Academic Readiness Index Card
              if (locator.isRegistered<AssessmentOrchestratorService>())
                Builder(
                  builder: (context) {
                    final orchestrator = locator<AssessmentOrchestratorService>();
                    final readiness = orchestrator
                        .calculateReadinessIndex(
                          recentScorePercent:
                              widget.result.scorePercent.toDouble(),
                        )
                        .round();
                    final readinessColor = readiness >= 75
                        ? colors.success
                        : (readiness >= 55
                              ? colors.syllabotAccent
                              : colors.warning);

                    return Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: readinessColor.withAlpha(isDark ? 30 : 15),
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          border: Border.all(
                            color: readinessColor.withAlpha(isDark ? 80 : 50),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: readinessColor.withAlpha(
                                  isDark ? 50 : 25,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.speed_rounded,
                                color: readinessColor,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Academic Readiness Index',
                                    style: typography.caption.bold.copyWith(
                                      color: colors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$readiness% Final Exam Mastery',
                                    style: typography.callout.bold.copyWith(
                                      color: colors.textPrimary,
                                      fontSize: 15,
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
                                color: readinessColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                readiness >= 75
                                    ? 'Exam Ready'
                                    : (readiness >= 55
                                          ? 'Building Mastery'
                                          : 'Action Required'),
                                style: typography.caption.bold.copyWith(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
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

              // 2.8 Socratic AI Concept Remediation Banner
              if (mistakes > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colors.syllabotAccent.withAlpha(isDark ? 40 : 20),
                          colors.primary.withAlpha(isDark ? 30 : 15),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      border: Border.all(
                        color: colors.syllabotAccent.withAlpha(isDark ? 90 : 60),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.psychology_rounded,
                              color: colors.syllabotAccent,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Socratic AI Concept Remediation',
                              style: typography.callout.bold.copyWith(
                                color: colors.textPrimary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'You missed $mistakes question${mistakes > 1 ? 's' : ''}. '
                          'Syllabot has extracted key concept rules into an instant FSRS recovery deck.',
                          style: typography.footnote.regular.copyWith(
                            color: colors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 10),
                        InkWell(
                          onTap: () => unawaited(
                            _handlePracticeWeakFlashcards(context),
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.badge),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: colors.syllabotAccent,
                              borderRadius: BorderRadius.circular(
                                AppRadius.badge,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.auto_awesome_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Launch Socratic Recovery Deck',
                                  style: typography.caption.bold.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
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
    final deckId = result.id.isNotEmpty ? result.id : 'general-quiz';
    await locator<LinkSharingService>().shareQuizDuel(
      duelId: 'quiz-score-${result.id}',
      deckId: deckId,
      deckTitle: result.quizTitle,
    );
  }

  void _handleAskClassForHelp(BuildContext context) {
    unawaited(HapticFeedback.lightImpact());
    final allQuestions = widget.questions.isNotEmpty
        ? widget.questions
        : _missedQuestions;

    if (allQuestions.isEmpty) {
      context.showSnackBar(
        message: 'No quiz questions available to discuss.',
      );
      return;
    }

    if (allQuestions.length == 1) {
      _openCreatePostForQuestions(context, [allQuestions.first]);
      return;
    }

    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: context.isDarkMode
            ? context.colors.surfaceSecondary
            : context.colors.surfacePrimary,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (sheetCtx) {
          return _QuizForumQuestionSelectorSheet(
            questions: allQuestions,
            missedQuestions: _missedQuestions,
            onConfirm: (selected) {
              Navigator.of(sheetCtx).pop();
              _openCreatePostForQuestions(context, selected);
            },
          );
        },
      ),
    );
  }

  void _openCreatePostForQuestions(
    BuildContext context,
    List<QuizQuestionEntity> questions,
  ) {
    if (questions.isEmpty) return;

    final isSingle = questions.length == 1;
    final primaryQuestion = questions.first;
    final topicTag = primaryQuestion.subTopic.trim().isNotEmpty
        ? primaryQuestion.subTopic.trim()
        : (widget.courseCode ?? 'Quiz review');

    final contentBuf = StringBuffer();

    if (isSingle) {
      final q = primaryQuestion;
      contentBuf.writeln(q.prompt.replaceAll('**', ''));
      if (q.options.isNotEmpty) {
        contentBuf
          ..writeln()
          ..writeln('Options:');
        for (final opt in q.options) {
          contentBuf.writeln('• ${opt.replaceAll('**', '')}');
        }
      }
      contentBuf
        ..writeln()
        ..writeln(
          'Your Answer: ${q.userSelectedAnswer ?? 'Unanswered'}',
        )
        ..writeln('Correct Answer: ${q.correctAnswer}');
      if (q.explanation.isNotEmpty) {
        contentBuf
          ..writeln()
          ..writeln(
            'Explanation:\n${q.explanation.replaceAll('**', '')}',
          );
      }
      contentBuf
        ..writeln()
        ..writeln(
          'I missed this one during practice. Can someone break down how '
          'to approach it?',
        );
    } else {
      contentBuf.writeln(
        'I am reviewing my practice session and would appreciate help breaking down these questions:\n',
      );
      for (var i = 0; i < questions.length; i++) {
        final q = questions[i];
        contentBuf
          ..writeln('### Question ${i + 1}')
          ..writeln(q.prompt.replaceAll('**', ''));
        if (q.options.isNotEmpty) {
          contentBuf
            ..writeln()
            ..writeln('Options:');
          for (final opt in q.options) {
            contentBuf.writeln('• ${opt.replaceAll('**', '')}');
          }
        }
        contentBuf
          ..writeln()
          ..writeln('• Your Answer: ${q.userSelectedAnswer ?? 'Unanswered'}')
          ..writeln('• Correct Answer: ${q.correctAnswer}');
        if (q.explanation.isNotEmpty) {
          contentBuf.writeln(
            '• Explanation: ${q.explanation.replaceAll('**', '')}',
          );
        }
        if (i < questions.length - 1) {
          contentBuf.writeln('\n---\n');
        }
      }
      contentBuf.writeln(
        '\nCan someone explain the concepts and how to solve these?',
      );
    }

    final initialTitle = isSingle
        ? '[$topicTag] Question discussion'
        : '[$topicTag] Review: ${questions.length} Quiz Questions';

    final firstLatex = questions
        .firstWhere(
          (q) => q.latexFormula != null && q.latexFormula!.isNotEmpty,
          orElse: () => primaryQuestion,
        )
        .latexFormula;

    unawaited(
      CreatePostBottomSheet.show(
        context,
        lockedTrack: widget.courseCode,
        initialTitle: initialTitle,
        initialContent: contentBuf.toString().trim(),
        initialLatex: firstLatex,
        initialSyllabusTag: topicTag,
        initialIsQuestion: true,
        contextBadge: isSingle
            ? 'Practice question • $topicTag'
            : '${questions.length} Practice questions • $topicTag',
        onSubmit: ({
          required title,
          required content,
          required track,
          latexContent,
          isQuestion = true,
          syllabusTag = 'General',
          isAnonymous = true,
        }) {
          if (locator.isRegistered<CommunityHubBloc>()) {
            final effectiveTag = primaryQuestion.subTopic.trim().isNotEmpty
                ? primaryQuestion.subTopic.trim()
                : syllabusTag;
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

class _QuizForumQuestionSelectorSheet extends StatefulWidget {
  const _QuizForumQuestionSelectorSheet({
    required this.questions,
    required this.missedQuestions,
    required this.onConfirm,
  });

  final List<QuizQuestionEntity> questions;
  final List<QuizQuestionEntity> missedQuestions;
  final ValueChanged<List<QuizQuestionEntity>> onConfirm;

  @override
  State<_QuizForumQuestionSelectorSheet> createState() =>
      _QuizForumQuestionSelectorSheetState();
}

class _QuizForumQuestionSelectorSheetState
    extends State<_QuizForumQuestionSelectorSheet> {
  bool _isMultipleMode = false;
  late int _selectedSingleIndex;
  late Set<int> _selectedMultipleIndices;

  @override
  void initState() {
    super.initState();
    final firstMissedIdx = widget.missedQuestions.isNotEmpty
        ? widget.questions.indexOf(widget.missedQuestions.first)
        : 0;
    _selectedSingleIndex = firstMissedIdx >= 0 ? firstMissedIdx : 0;

    _selectedMultipleIndices = <int>{};
    if (widget.missedQuestions.isNotEmpty) {
      for (final mq in widget.missedQuestions) {
        final idx = widget.questions.indexOf(mq);
        if (idx >= 0) _selectedMultipleIndices.add(idx);
      }
    }
    if (_selectedMultipleIndices.isEmpty && widget.questions.isNotEmpty) {
      _selectedMultipleIndices.add(0);
    }
  }

  void _selectAllMissed() {
    setState(() {
      _selectedMultipleIndices.clear();
      for (final mq in widget.missedQuestions) {
        final idx = widget.questions.indexOf(mq);
        if (idx >= 0) _selectedMultipleIndices.add(idx);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedMultipleIndices =
          List.generate(widget.questions.length, (i) => i).toSet();
    });
  }

  void _clearAll() {
    setState(() {
      _selectedMultipleIndices.clear();
    });
  }

  void _submit() {
    if (_isMultipleMode) {
      if (_selectedMultipleIndices.isEmpty) return;
      final sortedIndices = _selectedMultipleIndices.toList()..sort();
      final selectedList =
          sortedIndices.map((i) => widget.questions[i]).toList();
      widget.onConfirm(selectedList);
    } else {
      if (_selectedSingleIndex < 0 ||
          _selectedSingleIndex >= widget.questions.length) {
        return;
      }
      widget.onConfirm([widget.questions[_selectedSingleIndex]]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final selectedCount =
        _isMultipleMode ? _selectedMultipleIndices.length : 1;

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: colors.textSecondary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ask Class for Help',
                        style: typography.headline.bold.copyWith(
                          color: colors.textPrimary,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Select question(s) to post to the study forum',
                        style: typography.caption.regular.copyWith(
                          color: colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close_rounded,
                    color: colors.textSecondary,
                    size: 20,
                  ),
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark
                    ? colors.surfaceTertiary.withValues(alpha: 0.5)
                    : colors.surfaceSecondary,
                borderRadius: AppRadius.radiusCard,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _ModeTab(
                      label: 'Single Question',
                      icon: Icons.filter_1_rounded,
                      isSelected: !_isMultipleMode,
                      onTap: () => setState(() => _isMultipleMode = false),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _ModeTab(
                      label: 'Multiple Questions',
                      icon: Icons.checklist_rounded,
                      isSelected: _isMultipleMode,
                      onTap: () => setState(() => _isMultipleMode = true),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_isMultipleMode) ...[
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (widget.missedQuestions.isNotEmpty)
                    ActionChip(
                      label: Text(
                        'Missed (${widget.missedQuestions.length})',
                        style: typography.caption.bold.copyWith(fontSize: 11),
                      ),
                      avatar: Icon(
                        Icons.highlight_off_rounded,
                        size: 14,
                        color: colors.error,
                      ),
                      backgroundColor: colors.error.withValues(alpha: 0.1),
                      side: BorderSide(
                        color: colors.error.withValues(alpha: 0.25),
                      ),
                      onPressed: _selectAllMissed,
                    ),
                  ActionChip(
                    label: Text(
                      'All (${widget.questions.length})',
                      style: typography.caption.bold.copyWith(fontSize: 11),
                    ),
                    backgroundColor: colors.primary.withValues(alpha: 0.1),
                    side: BorderSide(
                      color: colors.primary.withValues(alpha: 0.25),
                    ),
                    onPressed: _selectAll,
                  ),
                  ActionChip(
                    label: Text(
                      'Clear',
                      style: typography.caption.regular.copyWith(fontSize: 11),
                    ),
                    backgroundColor: Colors.transparent,
                    side: BorderSide(
                      color: colors.textSecondary.withValues(alpha: 0.2),
                    ),
                    onPressed: _clearAll,
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: widget.questions.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final q = widget.questions[index];
                  final isMissed = widget.missedQuestions.contains(q);
                  final isSelected = _isMultipleMode
                      ? _selectedMultipleIndices.contains(index)
                      : _selectedSingleIndex == index;

                  return InkWell(
                    onTap: () {
                      unawaited(HapticFeedback.selectionClick());
                      setState(() {
                        if (_isMultipleMode) {
                          if (isSelected) {
                            _selectedMultipleIndices.remove(index);
                          } else {
                            _selectedMultipleIndices.add(index);
                          }
                        } else {
                          _selectedSingleIndex = index;
                        }
                      });
                    },
                    borderRadius: AppRadius.radiusCard,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colors.primary
                                .withValues(alpha: isDark ? 0.18 : 0.08)
                            : (isDark
                                ? colors.surfaceTertiary.withValues(alpha: 0.3)
                                : colors.surfaceSecondary
                                    .withValues(alpha: 0.6)),
                        borderRadius: AppRadius.radiusCard,
                        border: Border.all(
                          color: isSelected
                              ? colors.primary
                              : colors.surfaceTertiary.withValues(alpha: 0.4),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isMultipleMode
                                ? (isSelected
                                    ? Icons.check_box_rounded
                                    : Icons.check_box_outline_blank_rounded)
                                : (isSelected
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_off_rounded),
                            color: isSelected
                                ? colors.primary
                                : colors.textSecondary.withValues(alpha: 0.6),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colors.primary
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Q${index + 1}',
                                        style: typography.caption.bold.copyWith(
                                          color: colors.primary,
                                          fontSize: 10.5,
                                        ),
                                      ),
                                    ),
                                    if (isMissed) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colors.error
                                              .withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Missed',
                                          style: typography.caption.bold.copyWith(
                                            color: colors.error,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                    ],
                                    if (q.subTopic.trim().isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          q.subTopic.trim(),
                                          style: typography.caption.regular
                                              .copyWith(
                                            color: colors.textSecondary,
                                            fontSize: 10.5,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  q.prompt.replaceAll('**', ''),
                                  style: typography.caption.bold.copyWith(
                                    color: colors.textPrimary,
                                    fontSize: 12,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: (_isMultipleMode && selectedCount == 0)
                    ? null
                    : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.radiusCard,
                  ),
                ),
                icon: const Icon(Icons.forum_rounded, size: 18),
                label: Text(
                  _isMultipleMode
                      ? 'Discuss $selectedCount Questions'
                      : 'Discuss Selected Question',
                  style: typography.subhead.bold.copyWith(
                    color: colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
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
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? colors.surfacePrimary : colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? colors.primary : colors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: typography.caption.bold.copyWith(
                color: isSelected ? colors.textPrimary : colors.textSecondary,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
