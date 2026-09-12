import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_duel_entity.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_duel_cubit.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_duel_state.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/latex_rich_viewer.dart';
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
        final myPlayer = state.myParticipant ?? const QuizDuelParticipant(userId: '', displayName: 'You', avatarUrl: '⚡');
        final opponent = state.opponentParticipant ?? const QuizDuelParticipant(userId: '', displayName: 'Rival', avatarUrl: '🧠');
        final currentQuestion = match?.currentQuestion;

        if (state.status == QuizDuelStatus.countdown) {
          return Scaffold(
            backgroundColor: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
            body: SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'MATCH FOUND!',
                      style: typography.largeTitle.bold.copyWith(
                        color: colors.primary,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // VS Avatar Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Column(
                          children: [
                            AppAvatar(name: myPlayer.displayName, customDimension: 68),
                            const SizedBox(height: 8),
                            Text(myPlayer.displayName, style: typography.body.bold),
                            Text('Rating: ${myPlayer.eloRating}', style: typography.caption.regular.copyWith(color: colors.textSecondary)),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colors.error.withValues(alpha: 0.15),
                              border: Border.all(color: colors.error, width: 2),
                            ),
                            child: Text(
                              'VS',
                              style: typography.title2.bold.copyWith(color: colors.error),
                            ),
                          ),
                        ),
                        Column(
                          children: [
                            AppAvatar(name: opponent.displayName, customDimension: 68),
                            const SizedBox(height: 8),
                            Text(opponent.displayName, style: typography.body.bold),
                            Text('Rating: ${opponent.eloRating}', style: typography.caption.regular.copyWith(color: colors.textSecondary)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 48),
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Duel Starting in 3...',
                      style: typography.title3.bold.copyWith(color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (state.status == QuizDuelStatus.finished) {
          final isWinner = state.isWinner;
          final isDraw = state.isDraw;

          return Scaffold(
            backgroundColor: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isDraw
                          ? '🤝 DRAW MATCH!'
                          : isWinner
                              ? '🏆 VICTORY!'
                              : '💥 DEFEAT',
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
                          ? 'Outstanding speed and accuracy! +35 XP earned.'
                          : 'Great effort! Practice more to climb the leaderboard.',
                      textAlign: TextAlign.center,
                      style: typography.body.regular.copyWith(color: colors.textSecondary),
                    ),
                    const SizedBox(height: 36),

                    // Final Scoreboard Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colors.surfacePrimary,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: colors.surfaceBorder.withValues(alpha: 0.6)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              AppAvatar(name: myPlayer.displayName, customDimension: 52),
                              const SizedBox(height: 6),
                              Text(myPlayer.displayName, style: typography.body.bold),
                              const SizedBox(height: 4),
                              Text(
                                '${myPlayer.score} pts',
                                style: typography.title2.bold.copyWith(color: colors.primary),
                              ),
                              if (isWinner)
                                const AppBadge(label: 'Winner', variant: AppBadgeVariant.success),
                            ],
                          ),
                          Text('—', style: typography.title1.bold),
                          Column(
                            children: [
                              AppAvatar(name: opponent.displayName, customDimension: 52),
                              const SizedBox(height: 6),
                              Text(opponent.displayName, style: typography.body.bold),
                              const SizedBox(height: 4),
                              Text(
                                '${opponent.score} pts',
                                style: typography.title2.bold.copyWith(color: colors.secondary),
                              ),
                              if (!isWinner && !isDraw)
                                const AppBadge(label: 'Winner', variant: AppBadgeVariant.success),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),

                    AppButton(
                      text: 'Rematch ⚡',
                      onPressed: () async {
                        await context.read<QuizDuelCubit>().startMatchmaking(
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
                      text: 'Exit Arena',
                      variant: AppButtonVariant.secondary,
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Active Duel Round & Summary View
        final progress = (state.remainingSeconds / 15.0).clamp(0.0, 1.0);
        final timerColor = state.remainingSeconds <= 3
            ? colors.error
            : state.remainingSeconds <= 6
                ? colors.warning
                : colors.primary;

        return Scaffold(
          backgroundColor: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Split Scoreboard Header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: colors.surfacePrimary,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colors.surfaceBorder.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          children: [
                            // My info
                            Expanded(
                              child: Row(
                                children: [
                                  AppAvatar(name: myPlayer.displayName, customDimension: 36),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          myPlayer.displayName,
                                          style: typography.caption.bold,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          '${myPlayer.score} pts',
                                          style: typography.body.bold.copyWith(color: colors.primary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (myPlayer.comboStreak > 1)
                                    Text('🔥x${myPlayer.comboStreak}', style: typography.caption.bold),
                                ],
                              ),
                            ),
                            // VS Center Badge
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                'VS',
                                style: typography.caption.bold.copyWith(color: colors.textSecondary),
                              ),
                            ),
                            // Opponent info
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (opponent.comboStreak > 1)
                                    Text('🔥x${opponent.comboStreak}', style: typography.caption.bold),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          opponent.displayName,
                                          style: typography.caption.bold,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          '${opponent.score} pts',
                                          style: typography.body.bold.copyWith(color: colors.secondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  AppAvatar(name: opponent.displayName, customDimension: 36),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Countdown Timer Progress Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: colors.surfaceSecondary,
                          valueColor: AlwaysStoppedAnimation<Color>(timerColor),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Question Card
                      if (currentQuestion != null) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colors.surfacePrimary,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: colors.surfaceBorder.withValues(alpha: 0.4)),
                          ),
                          child: LatexRichViewer(
                            text: currentQuestion.prompt,
                            style: typography.body.regular.copyWith(
                              fontSize: 16,
                              height: 1.4,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // MCQ Options
                        Expanded(
                          child: ListView.separated(
                            itemCount: currentQuestion.options.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final option = currentQuestion.options[index];
                              final isSelected = state.selectedOptionIndex == index;
                              final isRoundSummary = state.status == QuizDuelStatus.roundSummary;
                              final isCorrect = option == currentQuestion.correctAnswer;

                              Color? cardColor = colors.surfacePrimary;
                              var borderColor = colors.surfaceBorder.withValues(alpha: 0.5);

                              if (isRoundSummary) {
                                if (isCorrect) {
                                  cardColor = colors.success.withValues(alpha: 0.18);
                                  borderColor = colors.success;
                                } else if (isSelected) {
                                  cardColor = colors.error.withValues(alpha: 0.18);
                                  borderColor = colors.error;
                                }
                              } else if (isSelected) {
                                cardColor = colors.primary.withValues(alpha: 0.15);
                                borderColor = colors.primary;
                              }

                              return Material(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(14),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: (state.isMyAnswerLocked || isRoundSummary)
                                      ? null
                                      : () => onSelectOption(index),
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 28,
                                          height: 28,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isSelected ? colors.primary : colors.surfaceSecondary,
                                          ),
                                          child: Center(
                                            child: Text(
                                              String.fromCharCode(65 + index),
                                              style: TextStyle(
                                                color: isSelected ? Colors.white : colors.textPrimary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: LatexRichViewer(
                                            text: option,
                                            style: typography.body.regular.copyWith(
                                              color: colors.textPrimary,
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
                        ),
                      ],

                      // Bottom Emote Bar
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: ['🔥', '⚡', '🤯', '👏', '🎯'].map((emote) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () => onSendEmote(emote),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: colors.surfaceSecondary,
                                  ),
                                  child: Text(emote, style: const TextStyle(fontSize: 20)),
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
                          child: Text(emote, style: const TextStyle(fontSize: 36)),
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
