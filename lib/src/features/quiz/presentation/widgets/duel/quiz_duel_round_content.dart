import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_duel_entity.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_duel_state.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/latex_rich_viewer.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/mcq_option_card.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/quiz_shell.dart';

/// Interactive round arena containing rival status indicator, round verdict,
/// question card, MCQ options, and bottom emote launcher.
class QuizDuelRoundContent extends StatelessWidget {
  const QuizDuelRoundContent({
    required this.state,
    required this.currentQuestion,
    required this.myPlayer,
    required this.opponent,
    required this.rivalLocked,
    required this.progress,
    required this.timerColor,
    required this.reduceMotion,
    required this.floatingEmotes,
    required this.onSelectOption,
    required this.onSendEmote,
    required this.onQuickAdvance,
    super.key,
  });

  final QuizDuelState state;
  final QuizQuestionEntity? currentQuestion;
  final QuizDuelParticipant myPlayer;
  final QuizDuelParticipant opponent;
  final bool rivalLocked;
  final double progress;
  final Color timerColor;
  final bool reduceMotion;
  final List<String> floatingEmotes;
  final ValueChanged<int> onSelectOption;
  final ValueChanged<String> onSendEmote;
  final VoidCallback onQuickAdvance;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final match = state.match;

    return Stack(
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
                    const SizedBox(height: 10),

                    // Presence line: Rival lock status
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

                    // Round verdict strip if in round summary
                    if (state.status == QuizDuelStatus.roundSummary &&
                        currentQuestion != null) ...[
                      Builder(
                        builder: (context) {
                          final mySelection = state.selectedOptionIndex ??
                              myPlayer.selectedOptionIndex;
                          final userHasSelected =
                              mySelection != null && mySelection >= 0;
                          final isUserCorrect = userHasSelected &&
                              (currentQuestion!.options.length > mySelection &&
                                  currentQuestion!.options[mySelection] ==
                                      currentQuestion!.correctAnswer);

                          return GestureDetector(
                            onTap: onQuickAdvance,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isUserCorrect
                                    ? colors.success.withAlpha(isDark ? 50 : 25)
                                    : userHasSelected
                                        ? colors.error.withAlpha(isDark ? 50 : 25)
                                        : colors.warning.withAlpha(isDark ? 50 : 25),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.micro,
                                ),
                                border: Border.all(
                                  color: isUserCorrect
                                      ? colors.success.withAlpha(120)
                                      : userHasSelected
                                          ? colors.error.withAlpha(120)
                                          : colors.warning.withAlpha(120),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    isUserCorrect
                                        ? Icons.check_circle_rounded
                                        : userHasSelected
                                            ? Icons.cancel_rounded
                                            : Icons.access_time_filled_rounded,
                                    size: 16,
                                    color: isUserCorrect
                                        ? colors.success
                                        : userHasSelected
                                            ? colors.error
                                            : colors.warning,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isUserCorrect
                                        ? 'ROUND VERDICT • Correct Answer!'
                                        : userHasSelected
                                            ? 'ROUND VERDICT • Incorrect Answer'
                                            : 'ROUND VERDICT • Time Expired',
                                    style: typography.caption.bold.copyWith(
                                      color: isUserCorrect
                                          ? colors.success
                                          : userHasSelected
                                              ? colors.error
                                              : colors.warning,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 11,
                                    color: (isUserCorrect
                                            ? colors.success
                                            : userHasSelected
                                                ? colors.error
                                                : colors.warning)
                                        .withAlpha(150),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
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
                                text: currentQuestion!.prompt,
                                style: typography.body.regular.copyWith(
                                  fontSize: 16,
                                  height: 1.4,
                                  color: colors.textPrimary,
                                ),
                              ),
                              if (currentQuestion!.latexFormula != null &&
                                  currentQuestion!
                                      .latexFormula!
                                      .trim()
                                      .isNotEmpty) ...[
                                const SizedBox(height: 10),
                                LatexFormulaBlock(
                                  formula: currentQuestion!.latexFormula!,
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
                          itemCount: currentQuestion!.options.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final option = currentQuestion!.options[index];
                            final isSelected =
                                state.selectedOptionIndex == index;
                            final isRoundSummary =
                                state.status == QuizDuelStatus.roundSummary;
                            final isCorrectOption =
                                option == currentQuestion!.correctAnswer;

                            final optionState = isRoundSummary
                                ? McqOptionCard.resolveState(
                                    isSelected: isSelected,
                                    isAnswered: true,
                                    isCorrect: isCorrectOption,
                                  )
                                : (isSelected
                                    ? McqOptionState.selected
                                    : McqOptionState.idle);

                            final trailingLabel = isRoundSummary
                                ? (isSelected
                                    ? (isCorrectOption
                                        ? 'Your Answer'
                                        : 'Your Pick')
                                    : (isCorrectOption
                                        ? 'Correct Answer'
                                        : null))
                                : null;

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
                                trailingLabel: trailingLabel,
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
                                  style: typography.body.regular.copyWith(
                                    fontSize: 20,
                                  ),
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

        // Floating Animated Emotes Layer
        ...floatingEmotes.map((emote) {
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
                      style: typography.body.regular.copyWith(fontSize: 36),
                    ),
                  ),
                );
              },
            ),
          );
        }),
      ],
    );
  }
}
