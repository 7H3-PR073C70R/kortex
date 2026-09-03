import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/decks/presentation/bloc/study_session_cubit.dart';
import 'package:kortex/src/features/decks/presentation/bloc/study_session_state.dart';
import 'package:kortex/src/features/decks/presentation/widgets/flashcard_gesture_canvas.dart';
import 'package:kortex/src/features/decks/presentation/widgets/sm2_rating_action_bar.dart';
import 'package:kortex/src/features/decks/presentation/widgets/study_progress_top_bar.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shimmer_placeholder.dart';
import 'package:kortex/src/shared/widgets/syllabot_avatar.dart';

@RoutePage()
class StudySessionPage extends HookWidget {
  const StudySessionPage({
    @PathParam('deckId') required this.deckId,
    super.key,
  });

  final String deckId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<StudySessionCubit>(
      create: (_) {
        final cubit = locator<StudySessionCubit>();
        unawaited(cubit.startSession(deckId));
        return cubit;
      },
      child: _StudySessionView(deckId: deckId),
    );
  }
}

class _StudySessionView extends HookWidget {
  const _StudySessionView({required this.deckId});

  final String deckId;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final focusNode = useFocusNode();

    useEffect(
      () {
        focusNode.requestFocus();
        return null;
      },
      [focusNode],
    );

    return Scaffold(
      backgroundColor: isDark
          ? colors.backgroundPrimary
          : colors.surfacePrimary,
      body: SafeArea(
        child: BlocConsumer<StudySessionCubit, StudySessionState>(
          listener: (context, state) {
            if (state.status == StudySessionStatus.finished) {
              unawaited(
                context.router.replace(
                  SessionSummaryRoute(
                    deckId: deckId,
                    cardsReviewed: state.cards.length,
                    durationSeconds: state.elapsedSeconds,
                    retentionScore: state.retentionScore,
                  ),
                ),
              );
            }
          },
          builder: (context, state) {
            if (state.status == StudySessionStatus.loading) {
              return _buildSessionShimmerSkeleton(colors, isDark);
            }

            if (state.status == StudySessionStatus.error) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SyllabotAvatar(size: 48, isError: true),
                      const SizedBox(height: 16),
                      Text(
                        state.errorMessage ?? l10n.dashboardUnableToLoad,
                        textAlign: TextAlign.center,
                        style: typography.callout.medium.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded),
                        onPressed: () => context.router.pop(),
                      ),
                    ],
                  ),
                ),
              );
            }

            final currentCard = state.currentCard;
            if (currentCard == null) {
              return const SizedBox.shrink();
            }

            return KeyboardListener(
              focusNode: focusNode,
              autofocus: true,
              onKeyEvent: (event) {
                if (event is KeyDownEvent) {
                  final key = event.logicalKey;
                  if (key == LogicalKeyboardKey.space) {
                    context.read<StudySessionCubit>().toggleFlip();
                  } else if (state.isFlipped) {
                    if (key == LogicalKeyboardKey.digit1 ||
                        key == LogicalKeyboardKey.numpad1) {
                      unawaited(
                        context.read<StudySessionCubit>().rateCard(0),
                      );
                    } else if (key == LogicalKeyboardKey.digit2 ||
                        key == LogicalKeyboardKey.numpad2) {
                      unawaited(
                        context.read<StudySessionCubit>().rateCard(3),
                      );
                    } else if (key == LogicalKeyboardKey.digit3 ||
                        key == LogicalKeyboardKey.numpad3) {
                      unawaited(
                        context.read<StudySessionCubit>().rateCard(4),
                      );
                    } else if (key == LogicalKeyboardKey.digit4 ||
                        key == LogicalKeyboardKey.numpad4) {
                      unawaited(
                        context.read<StudySessionCubit>().rateCard(5),
                      );
                    }
                  }
                }
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                child: Column(
                  children: [
                    // 1. Top Progress & Session Timer Bar
                    StudyProgressTopBar(
                      currentIndex: state.currentIndex,
                      totalCards: state.totalCards,
                      elapsedTimeFormatted: state.formattedElapsedTime,
                      onClose: () => unawaited(context.router.maybePop()),
                    ),
                    const SizedBox(height: 16),

                    // 2. Main Flashcard Canvas with 3D Flip & 4-Way Physics
                    Expanded(
                      child: Center(
                        child: FlashcardGestureCanvas(
                          card: currentCard,
                          isFlipped: state.isFlipped,
                          onTapFlip: () {
                            context.read<StudySessionCubit>().toggleFlip();
                          },
                          onSwipeLeft: () {
                            unawaited(
                              context.read<StudySessionCubit>().rateCard(3),
                            );
                          },
                          onSwipeRight: () {
                            unawaited(
                              context.read<StudySessionCubit>().rateCard(4),
                            );
                          },
                          onSwipeUp: () {
                            unawaited(
                              context.read<StudySessionCubit>().rateCard(5),
                            );
                          },
                          onSwipeDown: () {
                            unawaited(
                              context.read<StudySessionCubit>().rateCard(0),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 3. SM-2 Rating Controls (Revealed when card is flipped)
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 250),
                      crossFadeState: state.isFlipped
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      firstChild: Container(
                        height: 52,
                        alignment: Alignment.center,
                        child: Text(
                          l10n.studySessionSwipeHint,
                          style: typography.footnote.regular.copyWith(
                            color: colors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      secondChild: Sm2RatingActionBar(
                        onRate: (quality) {
                          unawaited(
                            context.read<StudySessionCubit>().rateCard(quality),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSessionShimmerSkeleton(
    AppThemeColorsExtension colors,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: Column(
        children: [
          // Progress Top Bar Skeleton
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ShimmerPlaceholder(height: 36, width: 36, borderRadius: 18),
              ShimmerPlaceholder(height: 16, width: 80, borderRadius: 8),
              ShimmerPlaceholder(height: 36, width: 36, borderRadius: 18),
            ],
          ),
          const SizedBox(height: 20),

          // Main Flashcard Skeleton
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark
                    ? colors.surfaceSecondary.withAlpha(160)
                    : colors.surfacePrimary.withAlpha(220),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: colors.surfaceBorder.withAlpha(100),
                ),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ShimmerPlaceholder(
                        height: 22,
                        width: 100,
                        borderRadius: 8,
                      ),
                      ShimmerPlaceholder(
                        height: 16,
                        width: 70,
                        borderRadius: 6,
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      ShimmerPlaceholder(
                        height: 22,
                        width: 260,
                        borderRadius: 8,
                      ),
                      SizedBox(height: 12),
                      ShimmerPlaceholder(
                        height: 18,
                        width: 200,
                        borderRadius: 8,
                      ),
                      SizedBox(height: 24),
                      ShimmerPlaceholder(
                        height: 60,
                        width: 240,
                        borderRadius: 14,
                      ),
                    ],
                  ),
                  ShimmerPlaceholder(
                    height: 14,
                    width: 180,
                    borderRadius: 6,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Bottom Bar Skeleton
          const ShimmerPlaceholder(
            height: 52,
            width: double.infinity,
            borderRadius: 16,
          ),
        ],
      ),
    );
  }
}
