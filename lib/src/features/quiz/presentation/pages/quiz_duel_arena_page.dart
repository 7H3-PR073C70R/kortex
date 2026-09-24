import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_duel_entity.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_duel_cubit.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_duel_state.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/latex_rich_viewer.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/mcq_option_card.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/quiz_shell.dart';
import 'package:kortex/src/shared/widgets/app_avatar.dart';
import 'package:kortex/src/shared/widgets/app_badge.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';

/// Full-screen competitive arena for 1v1 Real-Time Quiz Duels (QZ-13).
class QuizDuelArenaPage extends HookWidget {
  const QuizDuelArenaPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final reduceMotion = quizReduceMotion(context);

    final floatingEmotes = useState<List<String>>([]);

    void onSelectOption(int index) {
      AppFeedback.selection();
      unawaited(context.read<QuizDuelCubit>().submitAnswer(index));
    }

    void onSendEmote(String emote) {
      AppFeedback.light();
      unawaited(context.read<QuizDuelCubit>().sendEmote(emote));
      floatingEmotes.value = [...floatingEmotes.value, emote];
      Future.delayed(const Duration(milliseconds: 2200), () {
        if (floatingEmotes.value.isNotEmpty) {
          floatingEmotes.value = List.of(floatingEmotes.value)..removeAt(0);
        }
      });
    }

    return BlocConsumer<QuizDuelCubit, QuizDuelState>(
      listener: (context, state) {
        if (state.match?.latestEmote != null &&
            state.match?.latestEmoteSenderId != state.currentUserId) {
          final emote = state.match!.latestEmote!;
          floatingEmotes.value = [...floatingEmotes.value, emote];
          Future.delayed(const Duration(milliseconds: 2200), () {
            if (floatingEmotes.value.isNotEmpty) {
              floatingEmotes.value = List.of(floatingEmotes.value)..removeAt(0);
            }
          });
        }
      },
      builder: (context, state) {
        final match = state.match;
        final myPlayer =
            state.myParticipant ??
            const QuizDuelParticipant(
              userId: '',
              displayName: 'You',
              avatarUrl: '⚡',
            );
        final opponent =
            state.opponentParticipant ??
            const QuizDuelParticipant(
              userId: '',
              displayName: 'Rival',
              avatarUrl: '🧠',
            );
        final currentQuestion = match?.currentQuestion;

        if (state.status == QuizDuelStatus.countdown) {
          return Scaffold(
            backgroundColor: isDark
                ? colors.surfaceSecondary
                : colors.surfacePrimary,
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Arena Battle Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                colors.primary.withAlpha(isDark ? 60 : 35),
                                colors.secondary.withAlpha(isDark ? 60 : 35),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(
                              AppRadius.dialog,
                            ),
                            border: Border.all(
                              color: colors.primary.withAlpha(120),
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.bolt_rounded,
                                color: colors.warning,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'RIVAL FOUND • 1v1 DUEL',
                                style: typography.caption.bold.copyWith(
                                  color: colors.primary,
                                  letterSpacing: 1.2,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Match Details Subtitle
                        Text(
                          '${match?.subject ?? "Academic"} (${match?.examBoard ?? "Standard"}) • ${match?.totalQuestions ?? 10} Questions',
                          style: typography.body.medium.copyWith(
                            color: colors.textSecondary,
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(height: 36),

                        // VS Battle Ring Cards: they arrive together in one
                        // scale-in beat, the "found my rival" moment.
                        _MomentScale(
                          reduceMotion: reduceMotion,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 24,
                              horizontal: 16,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? colors.surfaceTertiary.withAlpha(180)
                                  : colors.surfaceSecondary.withAlpha(200),
                              borderRadius: BorderRadius.circular(
                                AppRadius.dialog,
                              ),
                              border: Border.all(
                                color: colors.primary.withAlpha(
                                  isDark ? 80 : 40,
                                ),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: colors.black.withAlpha(
                                    isDark ? 50 : 20,
                                  ),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                // Player 1 (You)
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: colors.primary,
                                          width: 2.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: colors.black.withAlpha(
                                              isDark ? 50 : 20,
                                            ),
                                            blurRadius: 10,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: AppAvatar(
                                        name: myPlayer.displayName,
                                        customDimension: 68,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      myPlayer.displayName,
                                      style: typography.body.bold.copyWith(
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colors.primary.withAlpha(35),
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.micro,
                                        ),
                                      ),
                                      child: Text(
                                        '${myPlayer.eloRating} ELO',
                                        style: typography.caption.bold.copyWith(
                                          color: colors.primary,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                // Glowing VS Emblem
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [
                                        colors.error,
                                        colors.warning,
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: colors.black.withAlpha(
                                          isDark ? 60 : 30,
                                        ),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    'VS',
                                    style: typography.title2.bold.copyWith(
                                      color: colors.white,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),

                                // Opponent (Rival)
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: colors.secondary,
                                          width: 2.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: colors.black.withAlpha(
                                              isDark ? 50 : 20,
                                            ),
                                            blurRadius: 10,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: AppAvatar(
                                        name: opponent.displayName,
                                        customDimension: 68,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      opponent.displayName,
                                      style: typography.body.bold.copyWith(
                                        fontSize: 15,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colors.secondary.withAlpha(35),
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.micro,
                                        ),
                                      ),
                                      child: Text(
                                        '${opponent.eloRating} ELO',
                                        style: typography.caption.bold.copyWith(
                                          color: colors.secondary,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),

                        // Countdown Indicator Pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primary.withAlpha(isDark ? 40 : 20),
                            borderRadius: BorderRadius.circular(
                              AppRadius.dialog,
                            ),
                            border: Border.all(
                              color: colors.primary.withAlpha(80),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    colors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Starting in 3 seconds...',
                                style: typography.body.bold.copyWith(
                                  color: colors.primary,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        if (state.status == QuizDuelStatus.finished) {
          final isWinner = state.isWinner;
          final isDraw = state.isDraw;

          return Scaffold(
            backgroundColor: isDark
                ? colors.surfaceSecondary
                : colors.surfacePrimary,
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 580),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isDraw
                              ? 'Even match'
                              : isWinner
                              ? 'You won this one'
                              : 'Rival took this one',
                          style: typography.largeTitle.bold.copyWith(
                            color: isDraw
                                ? colors.warning
                                : isWinner
                                ? colors.success
                                : colors.error,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isWinner
                              ? 'Fast and accurate. The bonus XP is on its way.'
                              : 'Close one. Every round makes the next one easier.',
                          textAlign: TextAlign.center,
                          style: typography.body.regular.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 36),

                        // Final Scoreboard Card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: colors.surfacePrimary,
                            borderRadius: BorderRadius.circular(
                              AppRadius.panel,
                            ),
                            border: Border.all(
                              color: colors.surfaceBorder.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                children: [
                                  AppAvatar(
                                    name: myPlayer.displayName,
                                    customDimension: 52,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    myPlayer.displayName,
                                    style: typography.body.bold,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${myPlayer.score} pts',
                                    style: typography.title2.bold.copyWith(
                                      color: colors.primary,
                                    ),
                                  ),
                                  if (isWinner)
                                    const AppBadge(
                                      label: 'Winner',
                                      variant: AppBadgeVariant.success,
                                    ),
                                ],
                              ),
                              Text('—', style: typography.title1.bold),
                              Column(
                                children: [
                                  AppAvatar(
                                    name: opponent.displayName,
                                    customDimension: 52,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    opponent.displayName,
                                    style: typography.body.bold,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${opponent.score} pts',
                                    style: typography.title2.bold.copyWith(
                                      color: colors.secondary,
                                    ),
                                  ),
                                  if (!isWinner && !isDraw)
                                    const AppBadge(
                                      label: 'Winner',
                                      variant: AppBadgeVariant.success,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),

                        AppButton(
                          text: 'Rematch',
                          onPressed: () async {
                            await context
                                .read<QuizDuelCubit>()
                                .startMatchmaking(
                                  subject: match?.subject ?? 'Physics',
                                  examBoard: match?.examBoard ?? 'WAEC',
                                  userId: state.currentUserId,
                                  displayName: myPlayer.displayName,
                                  avatarUrl: myPlayer.avatarUrl,
                                );
                          },
                        ),
                        const SizedBox(height: 12),
                        AppButton(
                          text: 'Leave arena',
                          variant: AppButtonVariant.secondary,
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        // Active Duel Round & Summary View
        final progress = (state.remainingSeconds / 15.0).clamp(0.0, 1.0);
        final timerColor = state.remainingSeconds <= 5
            ? colors.error
            : state.remainingSeconds <= 8
            ? colors.warning
            : colors.primary;
        final rivalLocked = opponent.selectedOptionIndex != null;

        return Scaffold(
          backgroundColor: isDark
              ? colors.surfaceSecondary
              : colors.surfacePrimary,
          appBar: AppBar(
            backgroundColor: colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () async {
                AppFeedback.light();
                await context.read<QuizDuelCubit>().leaveMatch();
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
            ),
            title: Text(
              '${match?.subject ?? "Duel"} • Q${(match?.currentQuestionIndex ?? 0) + 1}/${match?.totalQuestions ?? 5}',
              style: typography.body.bold,
            ),
            centerTitle: true,
          ),
          body: Stack(
            children: [
              SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 820),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Split Scoreboard Header
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: colors.surfacePrimary,
                              borderRadius: BorderRadius.circular(
                                AppRadius.panel,
                              ),
                              border: Border.all(
                                color: colors.surfaceBorder.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                // My info
                                Expanded(
                                  child: Row(
                                    children: [
                                      AppAvatar(
                                        name: myPlayer.displayName,
                                        customDimension: 36,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              myPlayer.displayName,
                                              style: typography.caption.bold,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              '${myPlayer.score} pts',
                                              style: typography.body.bold
                                                  .copyWith(
                                                    color: colors.primary,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (myPlayer.comboStreak > 1)
                                        Text(
                                          '🔥x${myPlayer.comboStreak}',
                                          style: typography.caption.bold,
                                        ),
                                    ],
                                  ),
                                ),
                                // VS Center Badge
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  child: Text(
                                    'VS',
                                    style: typography.caption.bold.copyWith(
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ),
                                // Opponent info
                                Expanded(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      if (opponent.comboStreak > 1)
                                        Text(
                                          '🔥x${opponent.comboStreak}',
                                          style: typography.caption.bold,
                                        ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              opponent.displayName,
                                              style: typography.caption.bold,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              '${opponent.score} pts',
                                              style: typography.body.bold
                                                  .copyWith(
                                                    color: colors.secondary,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      AppAvatar(
                                        name: opponent.displayName,
                                        customDimension: 36,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),

                          // A calm presence line: you can tell the rival is
                          // still in it without watching a number tick.
                          if (state.status == QuizDuelStatus.inRound)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: rivalLocked
                                        ? colors.success
                                        : colors.warning,
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  rivalLocked
                                      ? 'Rival has locked their answer'
                                      : 'Rival is thinking…',
                                  style: typography.caption.regular.copyWith(
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 10),

                          // Countdown Timer Progress Bar
                          QuizProgressBar(
                            value: progress,
                            color: timerColor,
                            height: 6,
                            reduceMotion: reduceMotion,
                          ),
                          const SizedBox(height: 16),

                          // Question Card
                          if (currentQuestion != null) ...[
                            QuizStaggeredFade(
                              distance: 10,
                              reduceMotion: reduceMotion,
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: colors.surfacePrimary,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.panel,
                                  ),
                                  border: Border.all(
                                    color: colors.surfaceBorder.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    LatexRichViewer(
                                      text: currentQuestion.prompt,
                                      style: typography.body.regular.copyWith(
                                        fontSize: 16,
                                        height: 1.4,
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                    if (currentQuestion.latexFormula != null &&
                                        currentQuestion
                                            .latexFormula!
                                            .trim()
                                            .isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      LatexFormulaBlock(
                                        formula: currentQuestion.latexFormula!,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // MCQ Options
                            Expanded(
                              child: ListView.separated(
                                itemCount: currentQuestion.options.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final option = currentQuestion.options[index];
                                  final isSelected =
                                      state.selectedOptionIndex == index;
                                  final isRoundSummary =
                                      state.status ==
                                      QuizDuelStatus.roundSummary;

                                  // Round summary reuses the shared verdict
                                  // states: the right answer pops green, your
                                  // wrong pick shakes red, the rest dim out.
                                  final optionState = isRoundSummary
                                      ? McqOptionCard.resolveState(
                                          isSelected: isSelected,
                                          isAnswered: true,
                                          isCorrect:
                                              option ==
                                              currentQuestion.correctAnswer,
                                        )
                                      : (isSelected
                                            ? McqOptionState.selected
                                            : McqOptionState.idle);

                                  return QuizStaggeredFade(
                                    key: ValueKey(
                                      'duel-opt-${match?.currentQuestionIndex}-$index',
                                    ),
                                    index: index,
                                    distance: 10,
                                    reduceMotion: reduceMotion,
                                    child: McqOptionCard(
                                      optionText: option,
                                      index: index,
                                      state: optionState,
                                      reduceMotion: reduceMotion,
                                      onTap: () {
                                        if (state.isMyAnswerLocked ||
                                            isRoundSummary) {
                                          return;
                                        }
                                        onSelectOption(index);
                                      },
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],

                          // Bottom Emote Bar
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: ['🔥', '⚡', '🤯', '👏', '🎯'].map((
                                emote,
                              ) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () => onSendEmote(emote),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: colors.surfaceSecondary,
                                      ),
                                      child: Text(
                                        emote,
                                        style: context.typography.body.regular.copyWith(fontSize: 20),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Floating Emote Layer
              ...floatingEmotes.value.map((emote) {
                return Positioned(
                  bottom: 120,
                  right: 32,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 1800),
                    builder: (context, value, child) {
                      return Transform.translate(
                        offset: Offset(0, -value * 120),
                        child: Opacity(
                          opacity: 1.0 - (value * 0.7),
                          child: Text(
                            emote,
                            style: context.typography.body.regular.copyWith(fontSize: 36),
                          ),
                        ),
                      );
                    },
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

/// One-shot scale-in used for the "rival found" moment, so both player cards
/// arrive together in a single beat instead of popping in instantly.
class _MomentScale extends StatelessWidget {
  const _MomentScale({required this.reduceMotion, required this.child});

  final bool reduceMotion;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.expressive,
      curve: AppMotion.easeOutCubic,
      builder: (context, t, _) => Opacity(
        opacity: t,
        child: Transform.scale(scale: 0.92 + 0.08 * t, child: child),
      ),
    );
  }
}
