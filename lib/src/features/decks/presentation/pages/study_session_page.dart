import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_hub_bloc.dart';
import 'package:kortex/src/features/decks/domain/logic/fsrs_scheduler.dart';
import 'package:kortex/src/features/decks/presentation/bloc/study_session_cubit.dart';
import 'package:kortex/src/features/decks/presentation/bloc/study_session_state.dart';
import 'package:kortex/src/features/decks/presentation/pages/focus_workspace_page.dart';
import 'package:kortex/src/features/decks/presentation/widgets/flashcard_gesture_canvas.dart';
import 'package:kortex/src/features/decks/presentation/widgets/sprint_milestone_banner.dart';
import 'package:kortex/src/features/decks/presentation/widgets/study_progress_top_bar.dart';
import 'package:kortex/src/features/decks/presentation/widgets/study_session/study_session_auxiliary_banners.dart';
import 'package:kortex/src/features/decks/presentation/widgets/study_session/study_session_error_view.dart';
import 'package:kortex/src/features/decks/presentation/widgets/study_session/study_session_keyboard_listener.dart';
import 'package:kortex/src/features/decks/presentation/widgets/study_session/study_session_rating_dock.dart';
import 'package:kortex/src/features/decks/presentation/widgets/study_session/study_session_shimmer_skeleton.dart';

@RoutePage()
class StudySessionPage extends HookWidget {
  const StudySessionPage({
    @PathParam('deckId') required this.deckId,
    this.cubitOverride,
    this.communityHubBlocOverride,
    super.key,
  });

  final String deckId;
  final StudySessionCubit? cubitOverride;
  final CommunityHubBloc? communityHubBlocOverride;

  @override
  Widget build(BuildContext context) {
    final isHyperdrive =
        deckId.startsWith('hyperdrive:') || deckId.startsWith('focus:');
    if (isHyperdrive) {
      final parts = deckId.split(':');
      final targetDeckId = parts.length > 1
          ? parts.sublist(1).join(':')
          : deckId;
      return FocusWorkspacePage(
        deckId: targetDeckId,
        deckTitle: 'Hyperdrive Focus',
      );
    }

    final isCram = deckId.startsWith('cram:');
    final isSprint = deckId.startsWith('sprint:');
    final String cleanDeckId;
    if (isCram) {
      final parts = deckId.split(':');
      cleanDeckId = parts.length > 2
          ? parts.sublist(2).join(':')
          : (parts.length > 1 ? parts[1] : deckId);
    } else if (isSprint) {
      cleanDeckId = deckId.split(':').last;
    } else {
      cleanDeckId = deckId;
    }

    return BlocProvider<StudySessionCubit>(
      create: (_) {
        final cubit = cubitOverride ?? locator<StudySessionCubit>();
        if (isCram) {
          final parts = deckId.split(':');
          final days = parts.length > 1 ? int.tryParse(parts[1]) : null;
          unawaited(
            cubit.startSession(
              cleanDeckId,
              daysUntilExam: days,
            ),
          );
        } else if (isSprint) {
          // Format: 'sprint:10:actualDeckId' or 'sprint:speed:3:actualDeckId'
          final parts = deckId.split(':');
          if (parts.length > 2 && parts[1] == 'speed') {
            final minutes = int.tryParse(parts[2]) ?? 3;
            final targetDeckId = parts.length > 3
                ? parts.sublist(3).join(':')
                : 'all';
            unawaited(
              cubit.startSession(
                targetDeckId,
                randomize: true,
                sprintSize: 30,
                targetDurationSeconds: minutes * 60,
              ),
            );
          } else {
            final size = int.tryParse(parts.length > 1 ? parts[1] : '10') ?? 10;
            final targetDeckId = parts.length > 2
                ? parts.sublist(2).join(':')
                : '';
            unawaited(
              cubit.startSession(
                targetDeckId,
                randomize: true,
                sprintSize: size,
              ),
            );
          }
        } else {
          unawaited(cubit.startSession(deckId));
        }
        return cubit;
      },
      child: _StudySessionView(
        deckId: cleanDeckId,
        communityHubBlocOverride: communityHubBlocOverride,
      ),
    );
  }
}

class _StudySessionView extends HookWidget {
  const _StudySessionView({
    required this.deckId,
    this.communityHubBlocOverride,
  });

  final String deckId;
  final CommunityHubBloc? communityHubBlocOverride;

  Future<void> _handleClose(BuildContext context, StudySessionCubit cubit) async {
    await cubit.saveSessionCheckpoint();
    if (context.mounted) {
      if (context.router.canPop()) {
        context.router.pop();
      } else {
        unawaited(
          context.router.replaceAll([const MainRoute()]),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;

    final focusNode = useFocusNode();
    final lastMilestoneIndex = useRef<int>(0);
    final isBionicEnabled = useState<bool>(false);
    final milestoneTick = useState<int?>(null);
    final hasNavigatedToSummary = useRef<bool>(false);

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
            if (state.status == StudySessionStatus.finished &&
                !hasNavigatedToSummary.value) {
              hasNavigatedToSummary.value = true;
              final reviewedCount = state.totalReviewedCards;
              final nextDays = context
                  .read<StudySessionCubit>()
                  .nextReviewInDays;
              unawaited(
                context.router.push(
                  SessionSummaryRoute(
                    deckId: deckId,
                    cardsReviewed: reviewedCount > 0
                        ? reviewedCount
                        : state.cards.length,
                    durationSeconds: state.elapsedSeconds,
                    retentionScore: state.retentionScore,
                    nextReviewInDays: nextDays,
                  ),
                ).catchError((Object error, StackTrace stackTrace) {
                  if (context.mounted) {
                    hasNavigatedToSummary.value = false;
                  }
                  return null;
                }),
              );
            } else if (state.status == StudySessionStatus.studying &&
                state.currentIndex > 0 &&
                state.currentIndex % 10 == 0 &&
                state.currentIndex != lastMilestoneIndex.value &&
                !state.isLastCard) {
              lastMilestoneIndex.value = state.currentIndex;
              unawaited(HapticFeedback.mediumImpact());
              milestoneTick.value = state.currentIndex;
            }
          },
          builder: (context, state) {
            if (state.status == StudySessionStatus.finishing) {
              return Center(
                child: CircularProgressIndicator.adaptive(
                  valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                ),
              );
            }

            if (state.status == StudySessionStatus.loading) {
              return const StudySessionShimmerSkeleton();
            }

            if (state.status == StudySessionStatus.error) {
              return StudySessionErrorView(
                errorMessage: state.errorMessage,
              );
            }

            final currentCard = state.currentCard;
            if (currentCard == null) {
              return const SizedBox.shrink();
            }

            final cubit = context.read<StudySessionCubit>();

            return StudySessionKeyboardListener(
              focusNode: focusNode,
              canUndo: cubit.canUndo,
              isFlipped: state.isFlipped,
              onUndo: cubit.undoLastRating,
              onToggleFlip: cubit.toggleFlip,
              onSaveCheckpointAndExit: () => _handleClose(context, cubit),
              onRateCard: (val) => unawaited(cubit.rateCard(val)),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                    child: Column(
                      children: [
                        // 1. Top Progress & Session Timer Bar
                        StudyProgressTopBar(
                          currentIndex: state.currentIndex,
                          totalCards: state.totalCards,
                          canUndo: cubit.canUndo,
                          onUndo: () {
                            cubit.undoLastRating();
                            context.showSnackBar(message: 'Rating undone ↩️');
                          },
                          elapsedTimeFormatted: cubit.isSpeedRun
                              ? cubit.formattedRemainingTime(
                                  state.elapsedSeconds,
                                )
                              : state.formattedElapsedTime,
                          onClose: () => _handleClose(context, cubit),
                        ),

                        // Contextual In-Session Cram Banner (Phase 1 Pillar 2)
                        if (cubit.daysUntilExam != null &&
                            cubit.daysUntilExam! > 0) ...[
                          CramSessionBanner(
                            daysUntilExam: cubit.daysUntilExam!,
                          ),
                          const SizedBox(height: 10),
                        ],

                        // Milestone check-in — informative, never blocking.
                        if (milestoneTick.value != null) ...[
                          SprintMilestoneBanner(
                            key: ValueKey('milestone-${milestoneTick.value}'),
                            cardsCrushed: milestoneTick.value!,
                            onFinishSprint: () {
                              milestoneTick.value = null;
                              unawaited(cubit.finishEarly());
                            },
                            onDismiss: () => milestoneTick.value = null,
                          ),
                          const SizedBox(height: 10),
                        ],

                        // Study Cohort Pulse Indicator & Bionic Focus Accommodation
                        StudyCohortBionicBar(
                          isBionicEnabled: isBionicEnabled.value,
                          onToggleBionic: () {
                            isBionicEnabled.value = !isBionicEnabled.value;
                          },
                        ),
                        const SizedBox(height: 10),

                        // 2. Main Flashcard Canvas with 3D Flip & 4-Way Physics
                        Expanded(
                          child: Center(
                            child: FlashcardGestureCanvas(
                              card: currentCard,
                              isFlipped: state.isFlipped,
                              enableBionicReading: isBionicEnabled.value,
                              onTapFlip: cubit.toggleFlip,
                              onSwipeLeft: () {
                                unawaited(cubit.rateCard(FsrsRating.hard));
                              },
                              onSwipeRight: () {
                                unawaited(cubit.rateCard(FsrsRating.good));
                              },
                              onSwipeUp: () {
                                unawaited(cubit.rateCard(FsrsRating.easy));
                              },
                              onSwipeDown: () {
                                unawaited(cubit.rateCard(FsrsRating.again));
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 3. FSRS-6 Rating Controls & Community Bounty Dock
                        StudySessionRatingDock(
                          currentCard: currentCard,
                          isFlipped: state.isFlipped,
                          intervalPreviews: cubit.ratingIntervalPreviews,
                          onRateRating: (rating) {
                            unawaited(cubit.rateCard(rating));
                          },
                          onToggleFlip: cubit.toggleFlip,
                          communityHubBloc: communityHubBlocOverride,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
