import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_duel_entity.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_duel_cubit.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_duel_state.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/duel/quiz_duel_cancelled_view.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/duel/quiz_duel_celebration_coordinator.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/duel/quiz_duel_countdown_view.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/duel/quiz_duel_forfeit_dialog.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/duel/quiz_duel_matching_view.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/duel/quiz_duel_round_content.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/duel/quiz_duel_scoreboard_view.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/duel/quiz_duel_split_scoreboard_header.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/quiz_shell.dart';

/// Full-screen competitive arena for 1v1 Real-Time Quiz Duels (QZ-13).
class QuizDuelArenaPage extends HookWidget {
  const QuizDuelArenaPage({
    super.key,
    this.quizDuelCubit,
  });

  final QuizDuelCubit? quizDuelCubit;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final reduceMotion = quizReduceMotion(context);

    final floatingEmotes = useState<List<String>>([]);
    final hasCelebrated = useState(false);
    final lastEmoteTs = useState<int?>(null);
    final activePostMatchTab = useState<int>(0);
    final lastEmoteSentMs = useState<int>(0);
    final previousStatus = useRef<QuizDuelStatus?>(null);
    final previousSeconds = useRef<int?>(null);
    final previousRivalSelected = useRef<bool>(false);

    final cubit = quizDuelCubit ?? context.read<QuizDuelCubit>();

    void onSelectOption(int index) {
      AppFeedback.selection();
      unawaited(cubit.submitAnswer(index));
    }

    void onSendEmote(String emote) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - lastEmoteSentMs.value < 900) return;
      lastEmoteSentMs.value = now;

      AppFeedback.light();
      unawaited(cubit.sendEmote(emote));
      floatingEmotes.value = [...floatingEmotes.value, emote];
      Future.delayed(const Duration(milliseconds: 2200), () {
        if (floatingEmotes.value.isNotEmpty) {
          floatingEmotes.value = List.of(floatingEmotes.value)..removeAt(0);
        }
      });
    }

    Future<void> copyCode(String code, {bool isSuccessSnackBar = false}) async {
      await Clipboard.setData(ClipboardData(text: code));
      AppFeedback.light();
      if (context.mounted) {
        context.showSnackBar(
          message: 'Room code $code copied!',
          type: isSuccessSnackBar ? SnackBarType.success : SnackBarType.info,
        );
      }
    }

    void handleMatchStatusTransitions(
      BuildContext context,
      QuizDuelState state,
    ) {
      // Countdown Audio / Haptic Tick
      if (state.status == QuizDuelStatus.countdown &&
          state.remainingSeconds != previousSeconds.value) {
        previousSeconds.value = state.remainingSeconds;
        AppFeedback.light();
      }

      // Duel Timer Urgent Tick (last 5 seconds)
      if (state.status == QuizDuelStatus.inRound &&
          state.remainingSeconds <= 5 &&
          state.remainingSeconds > 0 &&
          state.remainingSeconds != previousSeconds.value) {
        previousSeconds.value = state.remainingSeconds;
        AppFeedback.duelTimerTick();
      }

      // Rival Locked Answer Haptic Cue
      final rivalLocked =
          state.opponentParticipant?.selectedOptionIndex != null;
      if (state.status == QuizDuelStatus.inRound &&
          rivalLocked &&
          !previousRivalSelected.value) {
        AppFeedback.medium();
      }
      previousRivalSelected.value = rivalLocked;

      // Round Summary Verdict Feedback
      if (previousStatus.value == QuizDuelStatus.inRound &&
          state.status == QuizDuelStatus.roundSummary) {
        final myIdx = state.selectedOptionIndex ??
            state.myParticipant?.selectedOptionIndex;
        final q = state.match?.currentQuestion;
        if (myIdx != null &&
            q != null &&
            myIdx >= 0 &&
            myIdx < q.options.length) {
          final isCorrect = q.options[myIdx] == q.correctAnswer;
          if (isCorrect) {
            final streak = state.myParticipant?.comboStreak ?? 0;
            if (streak >= 3) {
              AppFeedback.comboStreak(streak);
            } else {
              AppFeedback.correct();
            }
          } else {
            AppFeedback.incorrect();
          }
        }
      }

      // Incoming Emote Handling
      if (state.match?.latestEmote != null &&
          state.match?.latestEmoteTimestamp != null &&
          state.match!.latestEmoteTimestamp != lastEmoteTs.value &&
          state.match?.latestEmoteSenderId != state.currentUserId) {
        lastEmoteTs.value = state.match!.latestEmoteTimestamp;
        final emote = state.match!.latestEmote!;
        floatingEmotes.value = [...floatingEmotes.value, emote];
        Future.delayed(const Duration(milliseconds: 2200), () {
          if (floatingEmotes.value.isNotEmpty) {
            floatingEmotes.value = List.of(floatingEmotes.value)..removeAt(0);
          }
        });
      }

      // Duel Finished Celebration Overlay
      if (state.status == QuizDuelStatus.finished &&
          previousStatus.value != null &&
          previousStatus.value != QuizDuelStatus.finished &&
          !hasCelebrated.value) {
        hasCelebrated.value = true;
        QuizDuelCelebrationCoordinator.showCelebration(
          context: context,
          state: state,
          cubit: cubit,
        );
      } else if (state.status != QuizDuelStatus.finished) {
        hasCelebrated.value = false;
      }

      previousStatus.value = state.status;
    }

    return BlocConsumer<QuizDuelCubit, QuizDuelState>(
      bloc: quizDuelCubit,
      listener: handleMatchStatusTransitions,
      builder: (context, state) {
        final match = state.match;
        final myPlayer = state.myParticipant ??
            const QuizDuelParticipant(
              userId: '',
              displayName: 'You',
              avatarUrl: '⚡',
            );
        final opponent = state.opponentParticipant ??
            const QuizDuelParticipant(
              userId: '',
              displayName: 'Rival',
              avatarUrl: '🧠',
            );
        final currentQuestion = match?.currentQuestion;

        if (state.status == QuizDuelStatus.matching) {
          return QuizDuelMatchingView(
            match: match,
            onPlayWithAi: () async {
              AppFeedback.selection();
              await cubit.matchWithAiImmediately();
            },
            onCancelSearch: () async {
              AppFeedback.light();
              await cubit.leaveMatch();
              if (context.mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
          );
        }

        if (state.status == QuizDuelStatus.cancelled) {
          return QuizDuelCancelledView(
            errorMessage: state.errorMessage,
            onFindAnother: () async {
              AppFeedback.selection();
              await cubit.startMatchmaking(
                subject: match?.subject ?? 'Physics',
                examBoard: match?.examBoard ?? 'WAEC',
                userId: state.currentUserId,
                displayName: myPlayer.displayName,
                avatarUrl: myPlayer.avatarUrl,
              );
            },
            onReturnToDashboard: () {
              AppFeedback.light();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          );
        }

        if (state.status == QuizDuelStatus.countdown) {
          return QuizDuelCountdownView(
            match: match,
            myPlayer: myPlayer,
            opponent: opponent,
            remainingSeconds: state.remainingSeconds,
            reduceMotion: reduceMotion,
            onCopyRoomCode: (code) => copyCode(code, isSuccessSnackBar: true),
          );
        }

        if (state.status == QuizDuelStatus.finished) {
          return QuizDuelScoreboardView(
            state: state,
            activeTab: activePostMatchTab.value,
            onTabSelected: (index) {
              AppFeedback.selection();
              activePostMatchTab.value = index;
            },
            onAcceptRematch: () {
              AppFeedback.selection();
              unawaited(cubit.acceptRematch());
            },
            onDeclineRematch: () async {
              AppFeedback.light();
              await cubit.declineRematch();
              if (context.mounted) {
                await cubit.leaveMatch();
                if (context.mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              }
            },
            onCancelRematchRequest: () {
              AppFeedback.light();
              unawaited(cubit.declineRematch());
            },
            onRequestRematch: () {
              AppFeedback.selection();
              unawaited(cubit.requestRematch());
            },
            onRematchWithAi: () {
              AppFeedback.selection();
              unawaited(cubit.rematchWithAiImmediately());
            },
            onFindNewRival: () async {
              AppFeedback.selection();
              await cubit.startMatchmaking(
                subject: match?.subject ?? 'Physics',
                examBoard: match?.examBoard ?? 'WAEC',
                userId: state.currentUserId,
                displayName: myPlayer.displayName,
                avatarUrl: myPlayer.avatarUrl,
              );
            },
            onShareDuel: () async {
              final code = match?.roomCode;
              final inviteSuffix = code != null && code.isNotEmpty
                  ? ' Challenge me back with room code: $code'
                  : ' Challenge me on Kortex!';
              final p1Score = match?.player1.score ?? 0;
              final shareText =
                  'I scored $p1Score pts in a 1v1 Quiz Duel on ${match?.subject ?? "Academic Trivia"}!$inviteSuffix';
              await Clipboard.setData(ClipboardData(text: shareText));
              AppFeedback.light();
              if (context.mounted) {
                context.showSnackBar(
                  message: 'Duel results & invite copied to clipboard!',
                  type: SnackBarType.success,
                );
              }
            },
            onReturnToDashboard: () async {
              AppFeedback.light();
              await cubit.leaveMatch();
              if (context.mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
          );
        }

        // Active Duel Round Arena
        final totalSeconds =
            (match?.durationPerQuestionSeconds ?? 60).toDouble();
        final progress =
            (state.remainingSeconds / totalSeconds).clamp(0.0, 1.0);
        final timerColor = state.remainingSeconds <= 5
            ? colors.error
            : state.remainingSeconds <= 8
                ? colors.warning
                : colors.primary;
        final rivalLocked = opponent.selectedOptionIndex != null;

        Future<bool> confirmLeave() async {
          if (cubit.state.status == QuizDuelStatus.finished ||
              cubit.state.status == QuizDuelStatus.cancelled) {
            return true;
          }
          return QuizDuelForfeitDialog.show(context);
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            final shouldLeave = await confirmLeave();
            if (shouldLeave && context.mounted) {
              await cubit.leaveMatch();
              if (context.mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            }
          },
          child: Scaffold(
            backgroundColor:
                isDark ? colors.surfaceSecondary : colors.surfacePrimary,
            appBar: AppBar(
              backgroundColor: colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () async {
                  AppFeedback.light();
                  final shouldLeave = await confirmLeave();
                  if (shouldLeave && context.mounted) {
                    await cubit.leaveMatch();
                    if (context.mounted) {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    }
                  }
                },
              ),
              title: Text(
                '${match?.subject ?? "Duel"} • Q${(match?.currentQuestionIndex ?? 0) + 1}/${match?.totalQuestions ?? 5}',
                style: typography.body.bold,
              ),
              centerTitle: true,
              actions: [
                if (match?.roomCode != null && match!.roomCode!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Center(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => copyCode(match.roomCode!),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surfacePrimary,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  colors.surfaceBorder.withValues(alpha: 0.6),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.vpn_key_rounded,
                                size: 12,
                                color: colors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                match.roomCode!,
                                style: typography.caption.bold.copyWith(
                                  letterSpacing: 1,
                                  color: colors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: QuizDuelSplitScoreboardHeader(
                    myPlayer: myPlayer,
                    opponent: opponent,
                    rivalLocked: rivalLocked,
                  ),
                ),
                Expanded(
                  child: QuizDuelRoundContent(
                    state: state,
                    currentQuestion: currentQuestion,
                    myPlayer: myPlayer,
                    opponent: opponent,
                    rivalLocked: rivalLocked,
                    progress: progress,
                    timerColor: timerColor,
                    reduceMotion: reduceMotion,
                    floatingEmotes: floatingEmotes.value,
                    onSelectOption: onSelectOption,
                    onSendEmote: onSendEmote,
                    onQuickAdvance: () {
                      unawaited(cubit.forceAdvanceToNextRound());
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
