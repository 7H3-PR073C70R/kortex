import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_session_cubit.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_session_state.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/explanation_accordion.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/mcq_option_card.dart';
import 'package:kortex/src/l10n/l10n.dart';

@RoutePage()
class QuizWorkspacePage extends StatelessWidget {
  const QuizWorkspacePage({
    @PathParam('deckId') this.deckId = 'deck-default',
    @QueryParam('title') this.deckTitle,
    this.subject,
    this.durationMinutes,
    this.initialQuestions,
    super.key,
  });

  final String deckId;
  final String? deckTitle;
  final String? subject;
  final int? durationMinutes;
  final List<QuizQuestionEntity>? initialQuestions;

  @override
  Widget build(BuildContext context) {
    final view = _QuizWorkspaceView(
      deckId: deckId,
      deckTitle: deckTitle ?? subject,
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
          cubit.startQuizFromPastQuestions(
            title: deckTitle ?? subject ?? 'CBT Practice Test',
            questions: initialQuestions!,
            durationMinutes: durationMinutes,
          );
        } else {
          unawaited(
            cubit.startQuizFromDeck(
              deckId: deckId,
              deckTitle: deckTitle ?? subject ?? 'Practice Quiz',
            ),
          );
        }
        return cubit;
      },
      child: view,
    );
  }
}

class _QuizWorkspaceView extends StatelessWidget {
  const _QuizWorkspaceView({
    required this.deckId,
    this.deckTitle,
  });

  final String deckId;
  final String? deckTitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    return BlocConsumer<QuizSessionCubit, QuizSessionState>(
      listener: (context, state) {
        if (state.status == QuizSessionStatus.completed &&
            state.result != null) {
          unawaited(
            context.router.replace(
              QuizResultsRoute(
                result: state.result!,
                questions: state.questions,
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
              child: CircularProgressIndicator(),
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
            backgroundColor: colors.transparent,
            body: const SizedBox.shrink(),
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
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              state.quizTitle,
              style: typography.title3.bold.copyWith(
                color: colors.textPrimary,
              ),
            ),
            actions: [
              // Live Session Timer Badge
              Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.surfaceBorder),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 16,
                      color: colors.success,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      state.formattedTimer,
                      style: typography.caption.bold.copyWith(
                        color: colors.success,
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
                    // Question Counter & Sub-Topic
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                          Text(
                            current.prompt,
                            style: typography.title3.bold.copyWith(
                              color: colors.textPrimary,
                              height: 1.4,
                            ),
                          ),
                          if (current.imageUrl != null && current.imageUrl!.trim().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                current.imageUrl!,
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) => const SizedBox.shrink(),
                              ),
                            ),
                          ],
                          if (current.latexFormula != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: colors.black.withAlpha(97),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                current.latexFormula!,
                                style: typography.code.regular.copyWith(
                                  color: colors.success,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Options List
                    ...current.options.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final opt = entry.value;
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
                    if (current.isAnswered)
                      ExplanationAccordion(
                        explanation: current.explanation,
                        latexFormula: current.latexFormula,
                      ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: current.isAnswered
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          if (state.isLastQuestion) {
                            unawaited(
                              context.read<QuizSessionCubit>().submitQuiz(),
                            );
                          } else {
                            context.read<QuizSessionCubit>().nextQuestion();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.primary,
                          foregroundColor: colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          state.isLastQuestion
                              ? l10n.submitQuizButton
                              : l10n.nextQuestionButton,
                          style: typography.callout.bold.copyWith(color: colors.white),
                        ),
                      ),
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }
}
