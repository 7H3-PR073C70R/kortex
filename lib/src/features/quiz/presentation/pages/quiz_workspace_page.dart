import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_event.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_hub_bloc.dart';
import 'package:kortex/src/features/community/presentation/widgets/create_post_bottom_sheet.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_session_cubit.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_session_state.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/explanation_accordion.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/latex_rich_viewer.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/mcq_option_card.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/millionaire_audience_poll_dialog.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/millionaire_ladder_drawer.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/millionaire_lifeline_bar.dart';
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

  @override
  Widget build(BuildContext context) {
    final view = _QuizWorkspaceView(
      deckId: deckId,
      deckTitle: deckTitle ?? subject,
      courseId: courseId,
      courseCode: courseCode,
    );
    try {
      final existing = context.read<QuizSessionCubit>();
      if (existing.state.status == QuizSessionStatus.inProgress &&
          existing.state.questions.isNotEmpty) {
        return view;
      }
    } on Object catch (_) {
      // No ancestor QuizSessionCubit found, proceed to create one.
    }

    return BlocProvider<QuizSessionCubit>(
      create: (_) {
        final cubit = locator<QuizSessionCubit>();
        if (initialQuestions != null && initialQuestions!.isNotEmpty) {
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
  });

  final String deckId;
  final String? deckTitle;
  final String? courseId;
  final String? courseCode;

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
          (previous.audienceDistribution == null && current.audienceDistribution != null),
      listener: (context, state) {
        if (state.audienceDistribution != null && state.currentQuestion != null) {
          MillionaireAudiencePollDialog.show(
            context,
            distribution: state.audienceDistribution!,
            options: state.currentQuestion!.options,
          );
        }
        if (state.status == QuizSessionStatus.completed &&
            state.result != null) {
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
            backgroundColor: colors.transparent,
            body: const Center(
              child: AppLogoLoader(),
            ),
          );
        }

        if (state.status == QuizSessionStatus.error) {
          return Scaffold(
            backgroundColor: colors.transparent,
            appBar: AppBar(
              backgroundColor: colors.transparent,
              elevation: 0,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: colors.error,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      state.errorMessage ?? l10n.quizFailedToLoad,
                      textAlign: TextAlign.center,
                      style: typography.body.regular.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        unawaited(
                          context.read<QuizSessionCubit>().startQuizFromDeck(
                            deckId: deckId,
                            deckTitle: deckTitle,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: colors.white,
                      ),
                      child: Text(
                        l10n.retryAction,
                        style: typography.body.bold.copyWith(color: colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final current = state.currentQuestion;
        if (current == null) {
          return Scaffold(
            backgroundColor:
                isDark ? colors.backgroundPrimary : colors.surfacePrimary,
            appBar: AppBar(
              backgroundColor: colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.close_rounded, color: colors.textSecondary),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Text(
                state.quizTitle,
                style:
                    typography.title3.bold.copyWith(color: colors.textPrimary),
              ),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.quiz_outlined,
                      color: colors.textSecondary,
                      size: 56,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Quiz Questions Available',
                      style: typography.title2.bold.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'There are no flashcards or questions available to generate a quiz for this session.',
                      textAlign: TextAlign.center,
                      style: typography.body.regular.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: colors.white,
                      ),
                      child: Text(
                        l10n.cancelAction,
                        style:
                            typography.body.bold.copyWith(color: colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final progress = state.totalQuestions == 0
            ? 0.0
            : (state.currentIndex + 1) / state.totalQuestions;

        return Scaffold(
          backgroundColor: colors.transparent,
          appBar: AppBar(
            backgroundColor: colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.close_rounded, color: colors.textSecondary),
              onPressed: () => _confirmExit(context, state),
            ),
            title: Text(
              state.quizTitle,
              style: typography.title3.bold.copyWith(
                color: colors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              // Flag toggle action
              IconButton(
                icon: Icon(
                  state.isCurrentQuestionFlagged
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: state.isCurrentQuestionFlagged
                      ? colors.warning
                      : colors.textSecondary,
                ),
                tooltip: 'Flag Question for Review',
                onPressed: () =>
                    context.read<QuizSessionCubit>().toggleFlagCurrentQuestion(),
              ),
              // Question Navigation Palette
              IconButton(
                icon: Icon(Icons.grid_view_rounded, color: colors.textSecondary),
                tooltip: 'Question Palette',
                onPressed: () => _showQuestionPalette(
                  context,
                  context.read<QuizSessionCubit>(),
                  state,
                ),
              ),
              // Live Session Timer Badge (with time running low warning)
              Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: state.isTimeRunningLow
                      ? colors.error.withValues(alpha: 0.15)
                      : colors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: state.isTimeRunningLow
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
                      color: state.isTimeRunningLow
                          ? colors.error
                          : colors.success,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      state.formattedTimer,
                      style: typography.caption.bold.copyWith(
                        color: state.isTimeRunningLow
                            ? colors.error
                            : colors.success,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              // Progress Bar
              LinearProgressIndicator(
                value: progress,
                backgroundColor: colors.surfaceBorder,
                valueColor: AlwaysStoppedAnimation<Color>(
                  colors.primary,
                ),
              ),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                  children: [
                    // Assessment Mode Selector Pill
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () {
                            unawaited(HapticFeedback.lightImpact());
                            final newMode = state.assessmentMode ==
                                    AssessmentMode.discoveryMode
                                ? AssessmentMode.examSimulationMode
                                : AssessmentMode.discoveryMode;
                            context
                                .read<QuizSessionCubit>()
                                .setAssessmentMode(newMode);
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: state.assessmentMode ==
                                      AssessmentMode.discoveryMode
                                  ? colors.primary.withAlpha(isDark ? 50 : 25)
                                  : colors.warning.withAlpha(isDark ? 50 : 25),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: state.assessmentMode ==
                                        AssessmentMode.discoveryMode
                                    ? colors.primary.withAlpha(90)
                                    : colors.warning.withAlpha(90),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  state.assessmentMode ==
                                          AssessmentMode.discoveryMode
                                      ? Icons.lightbulb_outline_rounded
                                      : Icons.timer_outlined,
                                  size: 13,
                                  color: state.assessmentMode ==
                                          AssessmentMode.discoveryMode
                                      ? colors.primary
                                      : colors.warning,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  state.assessmentMode ==
                                          AssessmentMode.discoveryMode
                                      ? 'Discovery Mode (Hints Available)'
                                      : 'Exam Simulation (Strict)',
                                  style: typography.caption.bold.copyWith(
                                    color: state.assessmentMode ==
                                            AssessmentMode.discoveryMode
                                        ? colors.primary
                                        : colors.warning,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Question Counter & Sub-Topic with Flag indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
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
                            if (state.isCurrentQuestionFlagged) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.warning.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.bookmark_rounded,
                                      size: 12,
                                      color: colors.warning,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      'Flagged',
                                      style: typography.caption.bold.copyWith(
                                        color: colors.warning,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(
                              alpha: 0.15,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            current.subTopic,
                            style: typography.caption.bold.copyWith(
                              color: colors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Millionaire Mode Lifeline Bar
                    if (state.assessmentMode == AssessmentMode.millionaireMode) ...[
                      MillionaireLifelineBar(
                        state: state,
                        onUseFiftyFifty: () {
                          context.read<QuizSessionCubit>().useLifeline(LifelineType.fiftyFifty);
                        },
                        onUseAiClue: () {
                          context.read<QuizSessionCubit>().useLifeline(LifelineType.aiClue);
                        },
                        onUseAskAudience: () {
                          context.read<QuizSessionCubit>().useLifeline(LifelineType.askAudience);
                        },
                        onUseSkipSwap: () {
                          context.read<QuizSessionCubit>().useLifeline(LifelineType.skipSwap);
                        },
                        onOpenLadder: () {
                          MillionaireLadderDrawer.show(context, state);
                        },
                        onWalkAway: () {
                          unawaited(context.read<QuizSessionCubit>().walkAwayAndBank());
                        },
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Active AI Clue (Millionaire Mode)
                    if (state.assessmentMode == AssessmentMode.millionaireMode &&
                        state.activeClueText != null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.2 : 0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.auto_awesome_rounded,
                              color: Color(0xFF6366F1),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'AI Tutor Clue',
                                    style: typography.caption.bold.copyWith(
                                      color: const Color(0xFF6366F1),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    state.activeClueText!,
                                    style: typography.footnote.regular.copyWith(
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Second Chance Shield Notice
                    if (state.assessmentMode == AssessmentMode.millionaireMode &&
                        state.isSecondChanceActive) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFF10B981).withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.shield_rounded,
                              color: Color(0xFF10B981),
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Second Chance Shield Active!',
                                    style: typography.caption.bold.copyWith(
                                      color: const Color(0xFF10B981),
                                    ),
                                  ),
                                  Text(
                                    'Review and try another option without losing your banked progress.',
                                    style: typography.footnote.regular.copyWith(
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            ShrinkableButton(
                              onTap: () {
                                context.read<QuizSessionCubit>().useSecondChance();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Try Again',
                                  style: typography.caption.bold.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Soft-Fail Banked Checkpoint Notice (Millionaire Mode)
                    if (state.assessmentMode == AssessmentMode.millionaireMode &&
                        state.isSoftFailed) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.verified_user_rounded,
                              color: Color(0xFFF59E0B),
                              size: 24,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Safe Checkpoint Secured! 🛡️',
                                    style: typography.caption.bold.copyWith(
                                      color: const Color(0xFFF59E0B),
                                    ),
                                  ),
                                  Text(
                                    'Your progress is safely locked at Tier ${state.bankedTier} (+${state.bankedTierPrizeXp} XP). No score reset to zero!',
                                    style: typography.footnote.regular.copyWith(
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            ShrinkableButton(
                              onTap: () {
                                unawaited(context.read<QuizSessionCubit>().submitQuiz());
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Collect XP',
                                  style: typography.caption.bold.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Prompt Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colors.surfacePrimary.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: colors.primary.withValues(
                            alpha: 0.2,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LatexRichViewer(
                            text: current.prompt,
                            style: typography.title3.bold.copyWith(
                              color: colors.textPrimary,
                              height: 1.4,
                            ),
                          ),
                          if (current.imageUrl != null && current.imageUrl!.trim().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            AppMultimodalImage(
                              imageUrl: current.imageUrl!,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ],
                          if (current.latexFormula != null &&
                              current.latexFormula!.trim().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            LatexFormulaBlock(
                              formula: current.latexFormula!,
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Socratic Hint Feature (Discovery Mode only)
                    if (state.assessmentMode == AssessmentMode.discoveryMode &&
                        !current.isAnswered) ...[
                      const SizedBox(height: 12),
                      if (!state.isHintRevealed)
                        Center(
                          child: ShrinkableButton(
                            onTap: () {
                              unawaited(HapticFeedback.lightImpact());
                              context.read<QuizSessionCubit>().revealHint();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: colors.primary.withAlpha(isDark ? 40 : 20),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: colors.primary.withAlpha(60),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.lightbulb_outline_rounded,
                                    size: 16,
                                    color: colors.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Need a Socratic Hint? (Discovery Mode)',
                                    style: typography.caption.bold.copyWith(
                                      color: colors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: colors.warning.withAlpha(isDark ? 30 : 20),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: colors.warning.withAlpha(60),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.psychology_rounded,
                                color: colors.warning,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Socratic Clue',
                                      style: typography.caption.bold.copyWith(
                                        color: colors.warning,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Focus on the relationship between ${current.subTopic.isNotEmpty ? current.subTopic : "the core concepts"} and eliminate options with extreme claims.',
                                      style: typography.footnote.regular.copyWith(
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),
                    ],

                    const SizedBox(height: 16),

                    // Options List
                    ...current.options.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final opt = entry.value;

                      // 50:50 Lifeline Masking
                      if (state.assessmentMode == AssessmentMode.millionaireMode &&
                          state.isOptionEliminated(idx)) {
                        return const SizedBox.shrink();
                      }

                      final isSelected = current.userSelectedAnswer == opt;
                      final isCorrectOption =
                          opt.trim().toLowerCase() ==
                          current.correctAnswer.trim().toLowerCase();

                      return McqOptionCard(
                        optionText: opt,
                        index: idx,
                        isSelected: isSelected,
                        isAnswered: current.isAnswered,
                        isCorrect: isCorrectOption,
                        onTap: () {
                          context.read<QuizSessionCubit>().selectOption(opt);
                        },
                      );
                    }),

                    // Solution Accordion (Appears after answering)
                    if (current.isAnswered) ...[
                      ExplanationAccordion(
                        explanation: current.explanation,
                        latexFormula: current.latexFormula,
                      ),
                      const SizedBox(height: 8),
                      ShrinkableButton(
                        onTap: () {
                          unawaited(HapticFeedback.lightImpact());
                          final topicTag = current.subTopic.trim().isNotEmpty
                              ? current.subTopic.trim()
                              : (effectiveCourseCode ?? 'Quiz Solution');
                          final firstLine = current.prompt.split('\n').first.trim();
                          final shortPrompt = firstLine.length > 55 ? '${firstLine.substring(0, 52)}...' : firstLine;

                          final contentBuf = StringBuffer(current.prompt);
                          if (current.options.isNotEmpty) {
                            contentBuf.writeln('\n\n**Options:**');
                            for (final opt in current.options) {
                              contentBuf.writeln('• $opt');
                            }
                          }
                          contentBuf.writeln('\n**Correct Answer:** ${current.correctAnswer}');
                          if (current.explanation.isNotEmpty) {
                            contentBuf.writeln('\n**Explanation:**\n${current.explanation}');
                          }
                          contentBuf.writeln('\n💡 Seeking additional insights or alternative solution steps from the cohort.');

                          unawaited(
                            CreatePostBottomSheet.show(
                              context,
                              lockedTrack: effectiveCourseCode ?? deckTitle,
                              initialTitle: '[$topicTag] Question: $shortPrompt',
                              initialContent: contentBuf.toString().trim(),
                              initialLatex: current.latexFormula,
                              initialSyllabusTag: topicTag,
                              initialIsQuestion: true,
                              contextBadge: 'CBT Solution • $topicTag',
                              onSubmit: ({
                                required title,
                                required content,
                                required track,
                                latexContent,
                                isQuestion = true,
                                syllabusTag = 'Quiz Solution',
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
                                  context.showSnackBar(
                                    message:
                                        'Question bounty posted to class cohort! 🎯',
                                  );
                                }
                              },
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.help_outline_rounded,
                                size: 13,
                                color: colors.warning,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Confused by this solution? Ask Class Cohort',
                                style: typography.caption.bold.copyWith(
                                  color: colors.warning,
                                  fontSize: 11,
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
            ],
          ),
          bottomNavigationBar: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            decoration: BoxDecoration(
              color: colors.surfacePrimary,
              border: Border(
                top: BorderSide(
                  color: colors.surfaceBorder.withAlpha(isDark ? 60 : 120),
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  // Previous Question (Disabled in Millionaire mode as ascent is forward-only)
                  if (state.assessmentMode != AssessmentMode.millionaireMode) ...[
                    IconButton.outlined(
                      onPressed: state.canGoPrevious
                          ? () => context.read<QuizSessionCubit>().previousQuestion()
                          : null,
                      icon: const Icon(Icons.arrow_back_rounded),
                      tooltip: 'Previous Question',
                    ),
                    const SizedBox(width: 8),
                  ],
                  // Question Palette / Ladder Drawer in Millionaire mode
                  IconButton.outlined(
                    onPressed: state.assessmentMode == AssessmentMode.millionaireMode
                        ? () => MillionaireLadderDrawer.show(context, state)
                        : () => _showQuestionPalette(
                              context,
                              context.read<QuizSessionCubit>(),
                              state,
                            ),
                    icon: Icon(
                      state.assessmentMode == AssessmentMode.millionaireMode
                          ? Icons.military_tech_rounded
                          : Icons.grid_view_rounded,
                      color: state.assessmentMode == AssessmentMode.millionaireMode
                          ? const Color(0xFFF59E0B)
                          : null,
                    ),
                    tooltip: state.assessmentMode == AssessmentMode.millionaireMode
                        ? 'Millionaire Ascent Ladder'
                        : 'Question Palette',
                  ),
                  const SizedBox(width: 12),
                  // Next / Submit primary action
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          if (state.assessmentMode == AssessmentMode.millionaireMode &&
                              state.isSoftFailed) {
                            unawaited(context.read<QuizSessionCubit>().submitQuiz());
                          } else if (state.isLastQuestion) {
                            _confirmSubmit(context, state);
                          } else {
                            context.read<QuizSessionCubit>().nextQuestion();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: (state.assessmentMode == AssessmentMode.millionaireMode && state.isSoftFailed)
                              ? const Color(0xFFF59E0B)
                              : (state.isLastQuestion ? colors.success : colors.primary),
                          foregroundColor: colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          (state.assessmentMode == AssessmentMode.millionaireMode && state.isSoftFailed)
                              ? 'Bank & View Results'
                              : (state.isLastQuestion
                                  ? l10n.submitQuizButton
                                  : l10n.nextQuestionButton),
                          style: typography.callout.bold.copyWith(color: colors.white),
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
          title: const Text('Exit CBT Exam?'),
          content: Text(
            'You have answered ${state.answeredCount} of ${state.totalQuestions} questions.\n\n'
            'Exiting now will discard your ongoing CBT simulator progress.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Resume'),
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
              child: const Text('Exit Exam'),
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
          title: const Text('Submit CBT Mock Exam?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Are you sure you want to finalize and grade your test answers?',
              ),
              const SizedBox(height: 14),
              Text('• Answered: ${state.answeredCount} / ${state.totalQuestions}'),
              Text('• Unanswered: ${state.unansweredCount}'),
              if (state.flaggedCount > 0)
                Text('• Flagged for review: ${state.flaggedCount}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Review Questions'),
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
              child: const Text('Submit Now'),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuestionPalette(
    BuildContext context,
    QuizSessionCubit cubit,
    QuizSessionState state,
  ) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor:
            isDark ? colors.backgroundPrimary : colors.surfacePrimary,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (sheetCtx) {
        return SafeArea(
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
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Question Navigation Palette',
                      style: typography.title3.bold.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: colors.textSecondary),
                      onPressed: () => Navigator.of(sheetCtx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _legendIndicator(
                      label: 'Answered (${state.answeredCount})',
                      color: colors.primary,
                      colors: colors,
                      typography: typography,
                    ),
                    _legendIndicator(
                      label: 'Flagged (${state.flaggedCount})',
                      color: colors.warning,
                      colors: colors,
                      typography: typography,
                    ),
                    _legendIndicator(
                      label: 'Pending (${state.unansweredCount})',
                      color: colors.surfaceBorder,
                      colors: colors,
                      typography: typography,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(sheetCtx).height * 0.45,
                  ),
                  child: GridView.builder(
                    shrinkWrap: true,
                    itemCount: state.totalQuestions,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.15,
                    ),
                    itemBuilder: (gridCtx, index) {
                      final q = state.questions[index];
                      final isCurrent = index == state.currentIndex;
                      final isAnswered = q.isAnswered;
                      final isFlagged = state.isQuestionFlagged(q.id);

                      Color bgColor;
                      Color textColor;
                      Border? border;

                      if (isCurrent) {
                        bgColor = colors.primary.withValues(alpha: 0.2);
                        textColor = colors.primary;
                        border = Border.all(color: colors.primary, width: 2);
                      } else if (isFlagged) {
                        bgColor = colors.warning.withValues(alpha: 0.15);
                        textColor = colors.warning;
                        border = Border.all(
                          color: colors.warning.withValues(alpha: 0.5),
                        );
                      } else if (isAnswered) {
                        bgColor = colors.primary;
                        textColor = colors.white;
                      } else {
                        bgColor = colors.surfaceSecondary;
                        textColor = colors.textPrimary;
                        border = Border.all(color: colors.surfaceBorder);
                      }

                      return InkWell(
                        onTap: () {
                          Navigator.of(sheetCtx).pop();
                          cubit.jumpToQuestion(index);
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(10),
                            border: border,
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Text(
                                '${index + 1}',
                                style: typography.callout.bold.copyWith(
                                  color: textColor,
                                ),
                              ),
                              if (isFlagged)
                                Positioned(
                                  top: 3,
                                  right: 3,
                                  child: Icon(
                                    Icons.bookmark_rounded,
                                    size: 11,
                                    color: isCurrent ? colors.warning : textColor,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(sheetCtx).pop();
                      _confirmSubmit(context, state);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Submit Mock Exam (${state.answeredCount}/${state.totalQuestions} Answered)',
                      style: typography.callout.bold.copyWith(color: colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ));
  }

  Widget _legendIndicator({
    required String label,
    required Color color,
    required AppThemeColorsExtension colors,
    required TypographyThemeExtension typography,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: typography.caption.regular.copyWith(
            color: colors.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
