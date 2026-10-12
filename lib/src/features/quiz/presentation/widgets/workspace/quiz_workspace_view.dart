import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_session_cubit.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_session_state.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/millionaire_audience_poll_dialog.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/millionaire_ladder_drawer.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/millionaire_lifeline_bar.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/quiz_shell.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/workspace/quiz_workspace_action_bar.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/workspace/quiz_workspace_answer_matcher.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/workspace/quiz_workspace_contextual_banner.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/workspace/quiz_workspace_dialogs.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/workspace/quiz_workspace_options_list.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/workspace/quiz_workspace_prompt_card.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/workspace/quiz_workspace_question_header.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/workspace/quiz_workspace_timer_badge.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_logo_loader.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class QuizWorkspaceView extends HookWidget {
  const QuizWorkspaceView({
    required this.deckId,
    this.deckTitle,
    this.courseId,
    this.courseCode,
    this.reviewMode = false,
    this.decksBloc,
    super.key,
  });

  final String deckId;
  final String? deckTitle;
  final String? courseId;
  final String? courseCode;
  final bool reviewMode;
  final DecksBloc? decksBloc;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final focusNode = useFocusNode();
    useEffect(() {
      focusNode.requestFocus();
      return null;
    }, [focusNode]);

    var effectiveCourseId = courseId;
    var effectiveCourseCode = courseCode ??
        (deckTitle != null && deckTitle!.contains('(')
            ? deckTitle!.split('(').first.trim()
            : deckTitle);

    if (effectiveCourseId == null || effectiveCourseCode == null) {
      final activeDecksBloc = decksBloc ?? context.read<DecksBloc?>();
      if (activeDecksBloc != null) {
        final allDecks = activeDecksBloc.state.allDecks;
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

        return KeyboardListener(
          focusNode: focusNode,
          autofocus: true,
          onKeyEvent: (event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.escape) {
              if (reviewMode) {
                Navigator.of(context).pop();
              } else {
                QuizWorkspaceDialogs.confirmExit(context, state);
              }
            }
          },
          child: Scaffold(
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
                  QuizWorkspaceDialogs.confirmExit(context, state);
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
                if (isExam && !reviewMode)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: TextButton.icon(
                      onPressed: () =>
                          QuizWorkspaceDialogs.confirmSubmit(context, state),
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
                if (reviewMode || !isMillionaire)
                  IconButton(
                    icon: Icon(
                      Icons.grid_view_rounded,
                      color: colors.textPrimary,
                    ),
                    tooltip: 'Question Palette',
                    onPressed: () => QuizWorkspaceDialogs.showQuestionPalette(
                      context: context,
                      cubit: context.read<QuizSessionCubit>(),
                      state: state,
                      reviewMode: reviewMode,
                    ),
                  ),
                if (!reviewMode) const QuizTimerBadge(),
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
                          QuizWorkspaceQuestionHeader(
                            state: state,
                            question: current,
                            reviewMode: reviewMode,
                            reduceMotion: reduceMotion,
                          ),
                          const SizedBox(height: 14),
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
                          QuizWorkspaceContextualBanner(state: state),
                          QuizStaggeredFade(
                            index: 2,
                            reduceMotion: reduceMotion,
                            child: QuizPromptCard(question: current),
                          ),
                          if (isPractice &&
                              !current.isAnswered &&
                              !reviewMode) ...[
                            const SizedBox(height: 12),
                            if (!state.isHintRevealed)
                              Center(
                                child: GhostButton(
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
                                message: quizQuestionHintText(current),
                                reduceMotion: reduceMotion,
                              ),
                          ],
                          const SizedBox(height: 16),
                          QuizWorkspaceOptionsList(
                            question: current,
                            state: state,
                            reviewMode: reviewMode,
                            reduceMotion: reduceMotion,
                          ),
                          if (showVerdict)
                            QuizStaggeredFade(
                              reduceMotion: reduceMotion,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: QuizVerdictPanel(
                                  verdict: (current.isCorrect ||
                                          isSameAnswer(
                                            current.userSelectedAnswer ?? '',
                                            current.correctAnswer,
                                          ))
                                      ? QuizVerdict.correct
                                      : QuizVerdict.incorrect,
                                  question: current,
                                  hintText: quizQuestionHintText(current),
                                  askClassLabel: 'Ask the class about this',
                                  onAskClass: () =>
                                      QuizWorkspaceDialogs.askClassAbout(
                                    context,
                                    current,
                                    effectiveCourseCode,
                                    deckTitle,
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
            bottomNavigationBar: QuizActionBar(
              state: state,
              reduceMotion: reduceMotion,
              reviewMode: reviewMode,
              onOpenPalette: () => QuizWorkspaceDialogs.showQuestionPalette(
                context: context,
                cubit: context.read<QuizSessionCubit>(),
                state: state,
                reviewMode: reviewMode,
              ),
              onOpenLadder: () => MillionaireLadderDrawer.show(context, state),
              onReviewAndSubmit: () => QuizWorkspaceDialogs.showQuestionPalette(
                context: context,
                cubit: context.read<QuizSessionCubit>(),
                state: state,
                reviewMode: reviewMode,
              ),
              onExit: () => Navigator.of(context).pop(),
            ),
          ),
        );
      },
    );
  }
}
