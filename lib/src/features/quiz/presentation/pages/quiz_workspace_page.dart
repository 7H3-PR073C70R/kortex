import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_event.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_hub_bloc.dart';
import 'package:kortex/src/features/community/presentation/widgets/create_post_bottom_sheet.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/logic/quiz_content_sanitizer.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_session_cubit.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_session_state.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/latex_rich_viewer.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/mcq_option_card.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/millionaire_audience_poll_dialog.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/millionaire_ladder_drawer.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/millionaire_lifeline_bar.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/quiz_shell.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_logo_loader.dart';
import 'package:kortex/src/shared/widgets/app_multimodal_image.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

@RoutePage()
class QuizWorkspacePage extends StatelessWidget {
  const QuizWorkspacePage({
    @PathParam('deckId') this.deckId = 'deck-default',
    @QueryParam('title') this.deckTitle,
    this.subject,
    this.durationMinutes,
    this.initialQuestions,
    this.courseId,
    this.courseCode,
    this.assessmentMode = AssessmentMode.discoveryMode,
    this.reviewMode = false,
    super.key,
  });

  final String deckId;
  final String? deckTitle;
  final String? subject;
  final int? durationMinutes;
  final List<QuizQuestionEntity>? initialQuestions;
  final String? courseId;
  final String? courseCode;
  final AssessmentMode assessmentMode;

  /// Read-only walkthrough of already answered questions.
  /// Answers and verdicts stay exactly as they were during the session.
  final bool reviewMode;

  @override
  Widget build(BuildContext context) {
    final view = _QuizWorkspaceView(
      deckId: deckId,
      deckTitle: deckTitle ?? subject,
      courseId: courseId,
      courseCode: courseCode,
      reviewMode: reviewMode,
    );
    try {
      final existing = context.read<QuizSessionCubit>();
      if (!reviewMode &&
          existing.state.status == QuizSessionStatus.inProgress &&
          existing.state.questions.isNotEmpty) {
        return view;
      }
    } on Object catch (_) {
      // No ancestor QuizSessionCubit found, proceed to create one.
    }

    return BlocProvider<QuizSessionCubit>(
      create: (_) {
        final cubit = locator<QuizSessionCubit>();
        if (reviewMode) {
          cubit.startReview(
            title: deckTitle ?? 'Review your answers',
            questions: initialQuestions ?? const [],
          );
        } else if (initialQuestions != null && initialQuestions!.isNotEmpty) {
          if (assessmentMode == AssessmentMode.millionaireMode) {
            cubit.startMillionaireQuiz(
              title: deckTitle ?? subject ?? 'Millionaire Challenge',
              questions: initialQuestions!,
            );
          } else {
            cubit.startQuizFromPastQuestions(
              title: deckTitle ?? subject ?? 'CBT Practice Test',
              questions: initialQuestions!,
              durationMinutes: durationMinutes,
              assessmentMode: assessmentMode,
            );
          }
        } else if (assessmentMode == AssessmentMode.millionaireMode &&
            (deckId == 'arcade_global' || deckId.isEmpty)) {
          unawaited(cubit.startMillionaireArcade());
        } else {
          unawaited(
            cubit.startQuizFromDeck(
              deckId: deckId,
              deckTitle: deckTitle ?? subject ?? 'Practice Quiz',
              durationMinutes: durationMinutes,
              assessmentMode: assessmentMode,
            ),
          );
        }
        return cubit;
      },
      child: view,
    );
  }
}

class _QuizWorkspaceView extends HookWidget {
  const _QuizWorkspaceView({
    required this.deckId,
    this.deckTitle,
    this.courseId,
    this.courseCode,
    this.reviewMode = false,
  });

  final String deckId;
  final String? deckTitle;
  final String? courseId;
  final String? courseCode;
  final bool reviewMode;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    var effectiveCourseId = courseId;
    var effectiveCourseCode = courseCode;

    if (effectiveCourseId == null || effectiveCourseCode == null) {
      if (locator.isRegistered<DecksBloc>()) {
        final allDecks = locator<DecksBloc>().state.allDecks;
        final matchingDeck = allDecks.where((d) => d.id == deckId).firstOrNull;
        if (matchingDeck != null) {
          effectiveCourseId ??= matchingDeck.courseId;
          effectiveCourseCode ??= matchingDeck.courseCode;
        }
      }
    }

    return BlocConsumer<QuizSessionCubit, QuizSessionState>(
      listenWhen: (previous, current) =>
          previous.status != current.status ||
          (previous.audienceDistribution == null &&
              current.audienceDistribution != null),
      buildWhen: (previous, current) =>
          previous.status != current.status ||
          previous.currentIndex != current.currentIndex ||
          previous.currentQuestion != current.currentQuestion ||
          previous.totalQuestions != current.totalQuestions ||
          previous.assessmentMode != current.assessmentMode ||
          previous.pendingAnswer != current.pendingAnswer ||
          previous.isCurrentQuestionFlagged !=
              current.isCurrentQuestionFlagged ||
          previous.isHintRevealed != current.isHintRevealed ||
          previous.hintsUsedCount != current.hintsUsedCount ||
          previous.activeClueText != current.activeClueText ||
          previous.isSecondChanceActive != current.isSecondChanceActive ||
          previous.isSoftFailed != current.isSoftFailed ||
          previous.bankedTier != current.bankedTier ||
          previous.currentTier != current.currentTier ||
          previous.availableLifelines != current.availableLifelines ||
          previous.eliminatedOptionIndices != current.eliminatedOptionIndices ||
          previous.errorMessage != current.errorMessage,
      listener: (context, state) {
        if (state.audienceDistribution != null &&
            state.currentQuestion != null) {
          MillionaireAudiencePollDialog.show(
            context,
            distribution: state.audienceDistribution!,
            options: state.currentQuestion!.options,
          );
        }
        if (state.status == QuizSessionStatus.completed &&
            state.result != null &&
            !reviewMode) {
          unawaited(
            context.router.replace(
              QuizResultsRoute(
                result: state.result!,
                questions: state.questions,
                courseId: effectiveCourseId,
                courseCode: effectiveCourseCode,
                assessmentMode: state.assessmentMode,
                currentTier: state.currentTier,
                bankedTier: state.bankedTier,
                speedBonusXp: state.speedBonusXp,
                isWalkedAway: state.isWalkedAway,
              ),
            ),
          );
        }
      },
      builder: (context, state) {
        if (state.status == QuizSessionStatus.loading) {
          return Scaffold(
            backgroundColor: isDark
                ? colors.backgroundPrimary
                : colors.surfacePrimary,
            body: const Center(
              child: AppLogoLoader(),
            ),
          );
        }

        if (state.status == QuizSessionStatus.error) {
          return Scaffold(
            backgroundColor: isDark
                ? colors.backgroundPrimary
                : colors.surfacePrimary,
            appBar: AppBar(
              backgroundColor: colors.transparent,
              elevation: 0,
            ),
            body: QuizEmptyState(
              icon: Icons.cloud_off_rounded,
              headline: 'We could not load this quiz',
              message: state.errorMessage ?? l10n.quizFailedToLoad,
              actionLabel: l10n.retryAction,
              tone: QuizBannerTone.warning,
              onAction: () {
                unawaited(
                  context.read<QuizSessionCubit>().startQuizFromDeck(
                    deckId: deckId,
                    deckTitle: deckTitle,
                  ),
                );
              },
            ),
          );
        }

        final current = state.currentQuestion;
        if (current == null) {
          return Scaffold(
            backgroundColor: isDark
                ? colors.backgroundPrimary
                : colors.surfacePrimary,
            appBar: AppBar(
              backgroundColor: colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.close_rounded, color: colors.textPrimary),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Text(
                state.quizTitle,
                style: typography.title3.bold.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ),
            body: QuizEmptyState(
              icon: Icons.quiz_outlined,
              headline: 'Nothing to practice yet',
              message:
                  'This deck does not have enough cards to build a quiz '
                  'yet. Add a few cards and come back.',
              actionLabel: 'Back',
              onAction: () => Navigator.of(context).pop(),
            ),
          );
        }

        final isPractice = state.assessmentMode == AssessmentMode.discoveryMode;
        final isExam =
            state.assessmentMode == AssessmentMode.examSimulationMode;
        final isMillionaire =
            state.assessmentMode == AssessmentMode.millionaireMode;
        final reduceMotion = quizReduceMotion(context);
        final progress = state.totalQuestions == 0
            ? 0.0
            : (state.currentIndex + 1) / state.totalQuestions;
        final showVerdict = reviewMode || (current.isAnswered && !isExam);

        return Scaffold(
          backgroundColor: isDark
              ? colors.backgroundPrimary
              : colors.surfacePrimary,
          appBar: AppBar(
            backgroundColor: colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.close_rounded, color: colors.textPrimary),
              onPressed: () {
                if (reviewMode) {
                  Navigator.of(context).pop();
                  return;
                }
                _confirmExit(context, state);
              },
            ),
            title: Text(
              reviewMode ? 'Review: ${state.quizTitle}' : state.quizTitle,
              style: typography.title3.bold.copyWith(
                color: colors.textPrimary,
                fontSize: 16,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              // In Millionaire mode: Replace question jump with progress chip!
              if (isMillionaire)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ShrinkableButton(
                    onTap: () => MillionaireLadderDrawer.show(context, state),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colors.warning.withValues(
                          alpha: isDark ? 0.2 : 0.1,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.badge),
                        border: Border.all(
                          color: colors.warning.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.military_tech_rounded,
                            size: 16,
                            color: colors.warning,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Tier ${state.currentTier}/12',
                            style: typography.caption.bold.copyWith(
                              color: colors.warning,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              // In CBT / Mock Exam: Dedicated quick-action to review & finish anytime
              if (isExam && !reviewMode)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: TextButton.icon(
                    onPressed: () => _confirmSubmit(context, state),
                    icon: Icon(
                      Icons.assignment_turned_in_outlined,
                      size: 16,
                      color: colors.primary,
                    ),
                    label: Text(
                      'Finish (${state.answeredCount}/${state.totalQuestions})',
                      style: typography.caption.bold.copyWith(
                        color: colors.primary,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      backgroundColor: colors.primary.withAlpha(20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.badge),
                      ),
                    ),
                  ),
                ),
              // Question Navigation Palette: Accessible in review, practice and exam simulation
              if (reviewMode || !isMillionaire)
                IconButton(
                  icon: Icon(Icons.grid_view_rounded, color: colors.textPrimary),
                  tooltip: 'Question Palette',
                  onPressed: () => _showQuestionPalette(
                    context,
                    context.read<QuizSessionCubit>(),
                    state,
                  ),
                ),
              // Live Session Timer Badge (authentic CBT countdown)
              if (!reviewMode) const _QuizTimerBadge(),
            ],
          ),
          body: Column(
            children: [
              QuizProgressBar(
                value: progress,
                color: isMillionaire ? colors.warning : colors.primary,
                reduceMotion: reduceMotion,
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 820),
                    child: ListView(
                      key: ValueKey('quiz-question-${state.currentIndex}'),
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                      children: [
                        // Where you are, and what this question covers.
                        QuizStaggeredFade(
                          reduceMotion: reduceMotion,
                          child: Row(
                            children: [
                              Text(
                                l10n.quizQuestionProgress(
                                  state.currentIndex + 1,
                                  state.totalQuestions,
                                ),
                                style: typography.footnote.bold.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                              if (isExam && !reviewMode) ...[
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => context
                                      .read<QuizSessionCubit>()
                                      .toggleFlagCurrentQuestion(),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: state.isCurrentQuestionFlagged
                                          ? colors.warning.withValues(
                                              alpha: 0.15,
                                            )
                                          : colors.surfaceSecondary,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: state.isCurrentQuestionFlagged
                                            ? colors.warning
                                            : colors.surfaceBorder,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          state.isCurrentQuestionFlagged
                                              ? Icons.bookmark_rounded
                                              : Icons.bookmark_border_rounded,
                                          size: 13,
                                          color: state.isCurrentQuestionFlagged
                                              ? colors.warning
                                              : colors.textSecondary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          state.isCurrentQuestionFlagged
                                              ? 'Flagged'
                                              : 'Flag',
                                          style: typography.caption.bold.copyWith(
                                            color: state.isCurrentQuestionFlagged
                                                ? colors.warning
                                                : colors.textSecondary,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ] else if (state.isCurrentQuestionFlagged) ...[
                                const SizedBox(width: 8),
                                QuizTagPill(
                                  label: 'Flagged',
                                  color: colors.warning,
                                  icon: Icons.bookmark_rounded,
                                ),
                              ],
                              if (reviewMode) ...[
                                const SizedBox(width: 8),
                                if (current.isCorrect ||
                                    _isSameAnswer(
                                      current.userSelectedAnswer ?? '',
                                      current.correctAnswer,
                                    ))
                                  QuizTagPill(
                                    label: 'Correct',
                                    color: colors.success,
                                    icon: Icons.check_circle_rounded,
                                  )
                                else if (current.userSelectedAnswer != null &&
                                    current.userSelectedAnswer!.isNotEmpty)
                                  QuizTagPill(
                                    label: 'Incorrect',
                                    color: colors.error,
                                    icon: Icons.cancel_rounded,
                                  )
                                else
                                  QuizTagPill(
                                    label: 'Unattempted',
                                    color: colors.warning,
                                    icon: Icons.help_outline_rounded,
                                  ),
                              ],
                              const Spacer(),
                              QuizTagPill(
                                label: current.subTopic,
                                color: colors.primary,
                                maxWidth: 200,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        // The rules for this session, stated once in plain
                        // words instead of a toggle that can be tapped by
                        // mistake mid-quiz.
                        QuizStaggeredFade(
                          reduceMotion: reduceMotion,
                          index: 1,
                          child: Text(
                            reviewMode
                                ? 'Review mode. Answers are locked while you '
                                      'look back.'
                                : _sessionModeCaption(state),
                            style: typography.caption.regular.copyWith(
                              color: colors.textMuted,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Millionaire Mode Lifeline Bar
                        if (state.assessmentMode ==
                            AssessmentMode.millionaireMode) ...[
                          MillionaireLifelineBar(
                            state: state,
                            onUseFiftyFifty: () {
                              context.read<QuizSessionCubit>().useLifeline(
                                LifelineType.fiftyFifty,
                              );
                            },
                            onUseAiClue: () {
                              context.read<QuizSessionCubit>().useLifeline(
                                LifelineType.aiClue,
                              );
                            },
                            onUseAskAudience: () {
                              context.read<QuizSessionCubit>().useLifeline(
                                LifelineType.askAudience,
                              );
                            },
                            onUseSkipSwap: () {
                              context.read<QuizSessionCubit>().useLifeline(
                                LifelineType.skipSwap,
                              );
                            },
                            onOpenLadder: () {
                              MillionaireLadderDrawer.show(context, state);
                            },
                            onWalkAway: () {
                              unawaited(
                                context
                                    .read<QuizSessionCubit>()
                                    .walkAwayAndBank(),
                              );
                            },
                          ),
                          const SizedBox(height: 14),
                        ],

                        // One contextual banner slot: the most urgent message
                        // wins, so notices never stack over each other.
                        ?_contextualBanner(context, state),

                        // Prompt Card
                        QuizStaggeredFade(
                          index: 2,
                          reduceMotion: reduceMotion,
                          child: _QuizPromptCard(question: current),
                        ),

                        // A hint is offered before the answer, never after it,
                        // so it supports thinking instead of replacing it.
                        if (isPractice &&
                            !current.isAnswered &&
                            !reviewMode) ...[
                          const SizedBox(height: 12),
                          if (!state.isHintRevealed)
                            Center(
                              child: _GhostButton(
                                icon: Icons.lightbulb_outline_rounded,
                                label: 'Need a hint?',
                                color: colors.primary,
                                reduceMotion: reduceMotion,
                                onTap: () => context
                                    .read<QuizSessionCubit>()
                                    .revealHint(),
                              ),
                            )
                          else
                            QuizInlineBanner(
                              icon: Icons.psychology_rounded,
                              tone: QuizBannerTone.warning,
                              title: 'A nudge',
                              message: _hintText(current),
                              reduceMotion: reduceMotion,
                            ),
                        ],

                        const SizedBox(height: 16),

                        // Options List
                        ...current.options.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final opt = entry.value;

                          // 50:50 takes two wrong options out of play.
                          if (isMillionaire && state.isOptionEliminated(idx)) {
                            return const SizedBox.shrink();
                          }

                          return QuizStaggeredFade(
                            index: 3 + idx,
                            distance: 10,
                            reduceMotion: reduceMotion,
                            child: McqOptionCard(
                              optionText: opt,
                              index: idx,
                              reduceMotion: reduceMotion,
                              state: McqOptionCard.resolveState(
                                isSelected: reviewMode
                                    ? (current.userSelectedAnswer == opt ||
                                        _isSameAnswer(
                                          current.userSelectedAnswer ?? '',
                                          opt,
                                        ))
                                    : (isPractice
                                        ? (state.pendingAnswer == opt ||
                                            _isSameAnswer(
                                              state.pendingAnswer ?? '',
                                              opt,
                                            ))
                                        : (current.userSelectedAnswer == opt ||
                                            _isSameAnswer(
                                              current.userSelectedAnswer ?? '',
                                              opt,
                                            ))),
                                isAnswered: reviewMode || current.isAnswered,
                                isCorrect: _isSameAnswer(
                                  opt,
                                  current.correctAnswer,
                                ),
                              ),
                              onTap: () {
                                // Review is read-only: taps do nothing.
                                if (reviewMode) return;
                                context.read<QuizSessionCubit>().selectOption(
                                  opt,
                                );
                              },
                            ),
                          );
                        }),

                        // The verdict stays on the page. A miss explains
                        // itself and offers one quiet route to the class.
                        if (showVerdict)
                          QuizStaggeredFade(
                            reduceMotion: reduceMotion,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: QuizVerdictPanel(
                                verdict: (current.isCorrect ||
                                        _isSameAnswer(
                                          current.userSelectedAnswer ?? '',
                                          current.correctAnswer,
                                        ))
                                    ? QuizVerdict.correct
                                    : QuizVerdict.incorrect,
                                question: current,
                                hintText: _hintText(current),
                                askClassLabel: 'Ask the class about this',
                                onAskClass: () => _askClassAbout(
                                  context,
                                  current,
                                  effectiveCourseCode,
                                ),
                                reduceMotion: reduceMotion,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: _QuizActionBar(
            state: state,
            reduceMotion: reduceMotion,
            reviewMode: reviewMode,
            onOpenPalette: () => _showQuestionPalette(
              context,
              context.read<QuizSessionCubit>(),
              state,
            ),
            onOpenLadder: () => MillionaireLadderDrawer.show(context, state),
            onReviewAndSubmit: () => _showQuestionPalette(
              context,
              context.read<QuizSessionCubit>(),
              state,
            ),
            onExit: () => Navigator.of(context).pop(),
          ),
        );
      },
    );
  }

  /// Plain-language description of the session rules, shown once.
  String _sessionModeCaption(QuizSessionState state) {
    return switch (state.assessmentMode) {
      AssessmentMode.discoveryMode => 'Practice mode. Check answers as you go.',
      AssessmentMode.examSimulationMode =>
        'Exam mode. Timed, and marks show at the end.',
      AssessmentMode.millionaireMode =>
        'Climb mode. Milestones you reach stay banked.',
    };
  }

  /// One contextual banner slot: the most urgent message wins.
  Widget? _contextualBanner(BuildContext context, QuizSessionState state) {
    if (state.assessmentMode != AssessmentMode.millionaireMode) return null;
    final cubit = context.read<QuizSessionCubit>();

    if (state.isSoftFailed) {
      return QuizInlineBanner(
        icon: Icons.verified_user_rounded,
        tone: QuizBannerTone.warning,
        title: 'Tier ${state.bankedTier} is secured',
        message: '+${state.bankedTierPrizeXp} XP is banked and stays yours.',
        actionLabel: 'Collect XP',
        onAction: () => unawaited(cubit.submitQuiz()),
      );
    }
    if (state.isSecondChanceActive) {
      return QuizInlineBanner(
        icon: Icons.shield_outlined,
        tone: QuizBannerTone.success,
        title: 'Second chance open',
        message: 'Try another option. Your banked progress is not at risk.',
        actionLabel: 'Try again',
        onAction: cubit.useSecondChance,
      );
    }
    final clue = state.activeClueText;
    if (clue != null) {
      return QuizInlineBanner(
        icon: Icons.auto_awesome_rounded,
        tone: QuizBannerTone.tutor,
        title: 'Tutor clue',
        message: clue,
      );
    }
    return null;
  }

  /// The nudge offered before an answer, and repeated after a miss.
  String _hintText(QuizQuestionEntity question) {
    final topic = question.subTopic.trim().isNotEmpty
        ? question.subTopic.trim()
        : 'the core idea';
    return 'Start with $topic, then rule out the options that sound absolute.';
  }

  /// Opens the class discussion sheet pre-filled with this question.
  void _askClassAbout(
    BuildContext context,
    QuizQuestionEntity question,
    String? courseCode,
  ) {
    unawaited(HapticFeedback.lightImpact());
    final topicTag = question.subTopic.trim().isNotEmpty
        ? question.subTopic.trim()
        : (courseCode ?? 'Quiz question');

    final buffer = StringBuffer(question.prompt.replaceAll('**', ''));
    if (question.options.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln()
        ..writeln('Options:');
      for (final opt in question.options) {
        buffer.writeln('• ${opt.replaceAll('**', '')}');
      }
    }
    buffer
      ..writeln()
      ..writeln('Correct answer: ${question.correctAnswer}');
    if (question.explanation.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Explanation:')
        ..writeln(question.explanation.replaceAll('**', ''));
    }
    buffer
      ..writeln()
      ..writeln('Would like a second explanation or another method.');

    unawaited(
      CreatePostBottomSheet.show(
        context,
        lockedTrack: courseCode ?? deckTitle,
        initialTitle: '[$topicTag] Question discussion',
        initialContent: buffer.toString().trim(),
        initialLatex: question.latexFormula,
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
              syllabusTag = 'Quiz question',
              isAnonymous = false,
            }) {
              if (locator.isRegistered<CommunityHubBloc>()) {
                locator<CommunityHubBloc>().add(
                  CreateForumPostEvent(
                    title: title,
                    content: content,
                    track: track,
                    latexContent: latexContent,
                    isQuestion: true,
                    syllabusTag: syllabusTag,
                    isAnonymous: isAnonymous,
                  ),
                );
                context.showSnackBar(message: 'Posted to your class.');
              }
            },
      ),
    );
  }

  void _confirmExit(BuildContext context, QuizSessionState state) {
    if (state.status != QuizSessionStatus.inProgress &&
        state.status != QuizSessionStatus.questionAnswered) {
      Navigator.of(context).pop();
      return;
    }
    unawaited(
      showDialog<void>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: Text(context.l10n.quizLeaveDialogTitle),
          content: Text(
            'You have answered ${state.answeredCount} of ${state.totalQuestions}.\n\n'
            'If you come back to this deck later you can start again in a minute.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text(context.l10n.quizKeepGoing),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.error,
                foregroundColor: context.colors.white,
              ),
              child: Text(isExamSession(state) ? 'Leave exam' : 'Leave quiz'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmSubmit(BuildContext context, QuizSessionState state) {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: Text(context.l10n.quizFinishDialogTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.quizFinishDialogSub),
              const SizedBox(height: 14),
              Text(
                '• Answered: ${state.answeredCount} of ${state.totalQuestions}',
              ),
              Text('• Left blank: ${state.unansweredCount}'),
              if (state.flaggedCount > 0)
                Text('• Flagged to look at again: ${state.flaggedCount}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text(context.l10n.quizGoBack),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                unawaited(context.read<QuizSessionCubit>().submitQuiz());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.primary,
                foregroundColor: context.colors.white,
              ),
              child: Text(context.l10n.quizSeeResults),
            ),
          ],
        ),
      ),
    );
  }

  /// Question navigator: counts first, the grid next, one way out.
  void _showQuestionPalette(
    BuildContext context,
    QuizSessionCubit cubit,
    QuizSessionState state,
  ) {
    final colors = context.colors;

    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: context.isDarkMode
            ? colors.backgroundPrimary
            : colors.surfacePrimary,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.dialog),
          ),
        ),
        builder: (sheetCtx) => _QuestionPaletteSheet(
          state: state,
          onJump: (index) {
            Navigator.of(sheetCtx).pop();
            cubit.jumpToQuestion(index);
          },
          onSubmit: reviewMode
              ? null
              : () {
                  Navigator.of(sheetCtx).pop();
                  _confirmSubmit(context, state);
                },
        ),
      ),
    );
  }
}

/// True when the session behaves like a real paper: no marks until the end.
bool isExamSession(QuizSessionState state) =>
    state.assessmentMode == AssessmentMode.examSimulationMode;

/// Answer comparison that ignores decoration and case.
bool _isSameAnswer(String option, String correctAnswer) {
  final cleanCorrect = QuizContentSanitizer.cleanOptionText(
    correctAnswer,
  ).toLowerCase();
  final cleanOption = QuizContentSanitizer.cleanOptionText(
    option,
  ).toLowerCase();
  if (cleanCorrect.isEmpty) return false;
  return cleanCorrect == cleanOption ||
      option.trim().toLowerCase() == correctAnswer.trim().toLowerCase();
}

/// The question itself, with its figure and working, on one calm card.
class _QuizPromptCard extends StatelessWidget {
  const _QuizPromptCard({required this.question});

  final QuizQuestionEntity question;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
        borderRadius: AppRadius.radiusPanel,
        border: Border.all(color: colors.surfaceBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: colors.black.withAlpha(isDark ? 30 : 6),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LatexRichViewer(
            text: question.prompt,
            style: typography.title3.bold.copyWith(
              color: colors.textPrimary,
              height: 1.4,
            ),
          ),
          if (question.imageUrl != null &&
              question.imageUrl!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            AppMultimodalImage(
              imageUrl: question.imageUrl!,
              borderRadius: AppRadius.radiusCard,
            ),
          ],
          if (question.latexFormula != null &&
              question.latexFormula!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            LatexFormulaBlock(formula: question.latexFormula!),
          ],
        ],
      ),
    );
  }
}

/// Low-weight outlined button for optional offers such as hints.
class _GhostButton extends StatelessWidget {
  const _GhostButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    required this.reduceMotion,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return ShrinkableButton(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: color.withAlpha(isDark ? 40 : 20),
          borderRadius: AppRadius.radiusCard,
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: typography.caption.bold.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// Single primary action for the quiz, pinned where thumbs already are.
class _QuizActionBar extends StatelessWidget {
  const _QuizActionBar({
    required this.state,
    required this.reduceMotion,
    required this.reviewMode,
    required this.onOpenPalette,
    required this.onOpenLadder,
    required this.onReviewAndSubmit,
    required this.onExit,
  });

  final QuizSessionState state;
  final bool reduceMotion;
  final bool reviewMode;
  final VoidCallback onOpenPalette;
  final VoidCallback onOpenLadder;
  final VoidCallback onReviewAndSubmit;
  final VoidCallback onExit;

  /// Next step for the current mode: Check, Continue, Review or Bank.
  ({Color color, String label, VoidCallback? onPressed}) _resolveAction(
    AppThemeColorsExtension colors,
    QuizSessionCubit cubit,
  ) {
    final question = state.currentQuestion;
    final isAnswered = question?.isAnswered ?? false;

    if (reviewMode) {
      if (state.isLastQuestion) {
        return (
          color: colors.primary,
          label: 'Back to results',
          onPressed: onExit,
        );
      }
      return (
        color: colors.primary,
        label: 'Next question',
        onPressed: cubit.nextQuestion,
      );
    }

    if (state.assessmentMode == AssessmentMode.millionaireMode) {
      if (state.isSoftFailed) {
        return (
          color: colors.warning,
          label: 'Bank and see results',
          onPressed: () => unawaited(cubit.submitQuiz()),
        );
      }
      if (!isAnswered) {
        return (
          color: colors.primary,
          label: 'Pick an answer',
          onPressed: null,
        );
      }
      return state.isLastQuestion
          ? (
              color: colors.success,
              label: 'See results',
              onPressed: () => unawaited(cubit.submitQuiz()),
            )
          : (
              color: colors.primary,
              label: 'Next',
              onPressed: cubit.nextQuestion,
            );
    }

    if (isExamSession(state)) {
      if (state.isLastQuestion) {
        return (
          color: colors.success,
          label: state.unansweredCount == 0
              ? 'Review and finish'
              : 'Review (${state.unansweredCount} left blank)',
          onPressed: onReviewAndSubmit,
        );
      }
      return (
        color: colors.primary,
        label: 'Next question',
        onPressed: cubit.nextQuestion,
      );
    }

    if (isAnswered) {
      return state.isLastQuestion
          ? (
              color: colors.success,
              label: 'See results',
              onPressed: () => unawaited(cubit.submitQuiz()),
            )
          : (
              color: colors.primary,
              label: 'Continue',
              onPressed: cubit.nextQuestion,
            );
    }

    return (
      color: colors.primary,
      label: 'Check',
      onPressed: state.hasPendingAnswer ? cubit.checkAnswer : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final cubit = context.read<QuizSessionCubit>();
    final action = _resolveAction(colors, cubit);
    final isMillionaire =
        state.assessmentMode == AssessmentMode.millionaireMode;
    final canStepBack = !isMillionaire && state.canGoPrevious;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: colors.surfacePrimary,
        border: Border(top: BorderSide(color: colors.surfaceBorder)),
        boxShadow: [
          BoxShadow(
            color: colors.black.withAlpha(context.isDarkMode ? 30 : 6),
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
                if (!isMillionaire) ...[
                  IconButton.outlined(
                    onPressed: canStepBack ? cubit.previousQuestion : null,
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: canStepBack
                          ? colors.textPrimary
                          : colors.textMuted,
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: colors.surfaceBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.radiusCard,
                      ),
                    ),
                    tooltip: 'Previous question',
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    onPressed: onOpenPalette,
                    icon: Icon(
                      Icons.grid_view_rounded,
                      color: colors.textPrimary,
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: colors.surfaceBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.radiusCard,
                      ),
                    ),
                    tooltip: 'All questions',
                  ),
                  if (isExamSession(state)) ...[
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      onPressed: cubit.toggleFlagCurrentQuestion,
                      icon: Icon(
                        state.isCurrentQuestionFlagged
                            ? Icons.bookmark_added_rounded
                            : Icons.bookmark_border_rounded,
                        color: state.isCurrentQuestionFlagged
                            ? colors.warning
                            : colors.textSecondary,
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: state.isCurrentQuestionFlagged
                              ? colors.warning.withAlpha(120)
                              : colors.surfaceBorder,
                        ),
                        backgroundColor: state.isCurrentQuestionFlagged
                            ? colors.warning.withAlpha(20)
                            : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.radiusCard,
                        ),
                      ),
                      tooltip: state.isCurrentQuestionFlagged
                          ? 'Question flagged for review'
                          : 'Flag question for review',
                    ),
                  ],
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: AnimatedSwitcher(
                    duration: reduceMotion ? Duration.zero : AppMotion.standard,
                    switchInCurve: AppMotion.easeOutCubic,
                    switchOutCurve: AppMotion.exitCurve,
                    child: SizedBox(
                      key: ValueKey(action.label),
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: action.onPressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: action.color,
                          foregroundColor: colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.radiusCard,
                          ),
                        ),
                        child: Text(
                          action.label,
                          style: typography.callout.bold.copyWith(
                            color: colors.white,
                          ),
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
}

/// Bottom sheet listing every question and how far along it is.
class _QuestionPaletteSheet extends StatelessWidget {
  const _QuestionPaletteSheet({
    required this.state,
    required this.onJump,
    this.onSubmit,
  });

  final QuizSessionState state;
  final ValueChanged<int> onJump;

  /// Null in review mode: there is nothing left to submit.
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final reduceMotion = quizReduceMotion(context);
    final isExam = isExamSession(state);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.surfaceBorder,
                    borderRadius: AppRadius.radiusMicro,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'All questions',
                    style: typography.title3.bold.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: colors.textSecondary,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: QuizStatChip(
                      label: 'Answered',
                      value: '${state.answeredCount}',
                      color: colors.primary,
                      reduceMotion: reduceMotion,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: QuizStatChip(
                      label: 'Flagged',
                      value: '${state.flaggedCount}',
                      color: colors.warning,
                      reduceMotion: reduceMotion,
                      staggerIndex: 1,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: QuizStatChip(
                      label: 'Left blank',
                      value: '${state.unansweredCount}',
                      color: colors.textMuted,
                      reduceMotion: reduceMotion,
                      staggerIndex: 2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.4,
                ),
                child: GridView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(top: 4),
                  itemCount: state.totalQuestions,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 1.15,
                      ),
                  itemBuilder: (gridCtx, index) {
                    return QuizStaggeredFade(
                      distance: 8,
                      index: (index % 10) ~/ 2,
                      reduceMotion: reduceMotion,
                      child: _PaletteTile(
                        number: index + 1,
                        status: _tileStatus(state, index),
                        onTap: () => onJump(index),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              if (onSubmit != null)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: onSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.radiusCard,
                      ),
                    ),
                    child: Text(
                      isExam
                          ? 'Submit mock exam (${state.answeredCount} of '
                                '${state.totalQuestions} answered)'
                          : 'Finish practice quiz (${state.answeredCount} '
                                'of ${state.totalQuestions} answered)',
                      style: typography.callout.bold.copyWith(
                        color: colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  _PaletteTileStatus _tileStatus(QuizSessionState state, int index) {
    final question = state.questions[index];
    if (index == state.currentIndex) return _PaletteTileStatus.current;
    if (state.isQuestionFlagged(question.id)) {
      return _PaletteTileStatus.flagged;
    }
    return question.isAnswered
        ? _PaletteTileStatus.answered
        : _PaletteTileStatus.blank;
  }
}

enum _PaletteTileStatus { current, flagged, answered, blank }

class _PaletteTile extends StatelessWidget {
  const _PaletteTile({
    required this.number,
    required this.status,
    required this.onTap,
  });

  final int number;
  final _PaletteTileStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    final decoration = switch (status) {
      _PaletteTileStatus.current => BoxDecoration(
        color: colors.primary.withValues(alpha: 0.2),
        borderRadius: AppRadius.radiusBadge,
        border: Border.all(color: colors.primary, width: 2),
      ),
      _PaletteTileStatus.flagged => BoxDecoration(
        color: colors.warning.withValues(alpha: 0.15),
        borderRadius: AppRadius.radiusBadge,
        border: Border.all(color: colors.warning.withValues(alpha: 0.5)),
      ),
      _PaletteTileStatus.answered => BoxDecoration(
        color: colors.primary,
        borderRadius: AppRadius.radiusBadge,
      ),
      _PaletteTileStatus.blank => BoxDecoration(
        color: colors.surfaceSecondary,
        borderRadius: AppRadius.radiusBadge,
        border: Border.all(color: colors.surfaceBorder),
      ),
    };
    final textColor = switch (status) {
      _PaletteTileStatus.current => colors.primary,
      _PaletteTileStatus.flagged => colors.warning,
      _PaletteTileStatus.answered => colors.white,
      _PaletteTileStatus.blank => colors.textPrimary,
    };

    return Semantics(
      button: true,
      label: 'Question $number',
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.radiusBadge,
        child: AnimatedContainer(
          duration: AppMotion.snappy,
          curve: AppMotion.easeOutCubic,
          decoration: decoration,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                '$number',
                style: typography.callout.bold.copyWith(color: textColor),
              ),
              if (status == _PaletteTileStatus.flagged)
                Positioned(
                  top: 3,
                  right: 3,
                  child: Icon(
                    Icons.bookmark_rounded,
                    size: 11,
                    color: textColor,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuizTimerBadge extends StatelessWidget {
  const _QuizTimerBadge();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return BlocSelector<
      QuizSessionCubit,
      QuizSessionState,
      ({String timer, bool isLow})
    >(
      selector: (state) => (
        timer: state.formattedTimer,
        isLow: state.isTimeRunningLow,
      ),
      builder: (context, data) {
        return Container(
          margin: const EdgeInsets.only(right: 16),
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: data.isLow
                ? colors.error.withValues(alpha: isDark ? 0.2 : 0.1)
                : colors.surfaceSecondary,
            borderRadius: BorderRadius.circular(AppRadius.badge),
            border: Border.all(
              color: data.isLow
                  ? colors.error.withValues(alpha: 0.5)
                  : colors.surfaceBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.timer_outlined,
                size: 16,
                color: data.isLow ? colors.error : colors.success,
              ),
              const SizedBox(width: 5),
              Text(
                data.timer,
                style: typography.caption.bold.copyWith(
                  color: data.isLow ? colors.error : colors.success,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
