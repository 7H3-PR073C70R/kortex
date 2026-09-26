import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_event.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_hub_bloc.dart';
import 'package:kortex/src/features/community/presentation/widgets/create_post_bottom_sheet.dart';
import 'package:kortex/src/features/decks/domain/logic/fsrs_scheduler.dart';
import 'package:kortex/src/features/decks/presentation/bloc/study_session_cubit.dart';
import 'package:kortex/src/features/decks/presentation/bloc/study_session_state.dart';
import 'package:kortex/src/features/decks/presentation/pages/focus_workspace_page.dart';
import 'package:kortex/src/features/decks/presentation/widgets/feynman_active_recall_sheet.dart';
import 'package:kortex/src/features/decks/presentation/widgets/flashcard_gesture_canvas.dart';
import 'package:kortex/src/features/decks/presentation/widgets/fsrs_rating_action_bar.dart';
import 'package:kortex/src/features/decks/presentation/widgets/sprint_milestone_banner.dart';
import 'package:kortex/src/features/decks/presentation/widgets/study_progress_top_bar.dart';
import 'package:kortex/src/features/decks/presentation/widgets/thought_parking_lot_sheet.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_back_button.dart';
import 'package:kortex/src/shared/widgets/shimmer_placeholder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

@RoutePage()
class StudySessionPage extends HookWidget {
  const StudySessionPage({
    @PathParam('deckId') required this.deckId,
    super.key,
  });

  final String deckId;

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
        final cubit = locator<StudySessionCubit>();
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
      ),
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
    final lastMilestoneIndex = useRef<int>(0);
    final isBionicEnabled = useState<bool>(false);
    // Non-blocking milestone check-in: holds the card count of the last
    // banner shown; null while no banner is on screen.
    final milestoneTick = useState<int?>(null);

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
                    nextReviewInDays: context
                        .read<StudySessionCubit>()
                        .nextReviewInDays,
                  ),
                ),
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
            if (state.status == StudySessionStatus.loading) {
              return _buildSessionShimmerSkeleton(colors, isDark);
            }

            if (state.status == StudySessionStatus.error) {
              final isNoCards =
                  state.errorMessage?.toLowerCase().contains('no cards') ==
                      true ||
                  state.errorMessage?.toLowerCase().contains('no flashcards') ==
                      true;
              return Column(
                children: [
                  // Top Navigation Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const AppBackButton(),
                        Text(
                          'Study Session',
                          style: typography.subhead.bold.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 44),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 32,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? colors.surfaceSecondary.withAlpha(140)
                                  : colors.surfacePrimary,
                              borderRadius: BorderRadius.circular(
                                AppRadius.dialog,
                              ),
                              border: Border.all(
                                color: colors.primary.withAlpha(
                                  isDark ? 60 : 30,
                                ),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: colors.black.withAlpha(
                                    isDark ? 40 : 15,
                                  ),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Glowing Icon Container
                                Container(
                                  width: 68,
                                  height: 68,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [
                                        colors.primary.withAlpha(
                                          isDark ? 70 : 35,
                                        ),
                                        colors.syllabotAccent.withAlpha(
                                          isDark ? 50 : 20,
                                        ),
                                      ],
                                    ),
                                    border: Border.all(
                                      color: colors.primary.withAlpha(
                                        isDark ? 100 : 50,
                                      ),
                                    ),
                                  ),
                                  child: Icon(
                                    isNoCards
                                        ? Icons.style_outlined
                                        : Icons.error_outline_rounded,
                                    size: 32,
                                    color: isNoCards
                                        ? colors.primary
                                        : colors.warning,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  isNoCards
                                      ? 'No Flashcards Yet'
                                      : 'Unable to Load Session',
                                  textAlign: TextAlign.center,
                                  style: typography.title3.bold.copyWith(
                                    color: colors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  isNoCards
                                      ? 'This deck does not have any flashcards yet. Generate cards with Syllabot AI or create them manually to start active recall.'
                                      : (state.errorMessage ??
                                            l10n.dashboardUnableToLoad),
                                  textAlign: TextAlign.center,
                                  style: typography.footnote.regular.copyWith(
                                    color: colors.textSecondary,
                                    height: 1.45,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                if (isNoCards) ...[
                                  ShrinkableButton(
                                    onTap: () {
                                      AppFeedback.light();
                                      unawaited(
                                        context.router.replace(
                                          DocumentIngestionRoute(),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 13,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            colors.primary,
                                            colors.syllabotAccent,
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.card,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: colors.black.withAlpha(
                                              isDark ? 40 : 20,
                                            ),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      alignment: Alignment.center,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.auto_awesome_rounded,
                                            color: colors.white,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Generate with AI',
                                            style: typography.subhead.bold
                                                .copyWith(
                                                  color: colors.white,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                                ShrinkableButton(
                                  onTap: () {
                                    AppFeedback.light();
                                    context.router.pop();
                                  },
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colors.surfaceSecondary.withAlpha(
                                        isDark ? 160 : 100,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.card,
                                      ),
                                      border: Border.all(
                                        color: colors.primary.withAlpha(
                                          isDark ? 40 : 20,
                                        ),
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'Return to Workspace',
                                      style: typography.footnote.bold.copyWith(
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            final currentCard = state.currentCard;
            if (currentCard == null) {
              return const SizedBox.shrink();
            }

            final cubit = context.read<StudySessionCubit>();

            return KeyboardListener(
              focusNode: focusNode,
              autofocus: true,
              onKeyEvent: (event) {
                if (event is KeyDownEvent) {
                  final key = event.logicalKey;
                  if (key == LogicalKeyboardKey.keyZ) {
                    if (cubit.canUndo) {
                      cubit.undoLastRating();
                      context.showSnackBar(message: 'Rating undone ↩️');
                    }
                  } else if (key == LogicalKeyboardKey.space ||
                      key == LogicalKeyboardKey.enter) {
                    cubit.toggleFlip();
                  } else if (state.isFlipped) {
                    if (key == LogicalKeyboardKey.digit1 ||
                        key == LogicalKeyboardKey.numpad1) {
                      unawaited(cubit.rateCard(0));
                    } else if (key == LogicalKeyboardKey.digit2 ||
                        key == LogicalKeyboardKey.numpad2) {
                      unawaited(cubit.rateCard(3));
                    } else if (key == LogicalKeyboardKey.digit3 ||
                        key == LogicalKeyboardKey.numpad3) {
                      unawaited(cubit.rateCard(4));
                    } else if (key == LogicalKeyboardKey.digit4 ||
                        key == LogicalKeyboardKey.numpad4) {
                      unawaited(cubit.rateCard(5));
                    }
                  }
                }
              },
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
                          onThoughtParkingLot: () {
                            unawaited(ThoughtParkingLotSheet.show(context));
                          },
                          elapsedTimeFormatted: cubit.isSpeedRun
                              ? cubit.formattedRemainingTime(
                                  state.elapsedSeconds,
                                )
                              : state.formattedElapsedTime,
                          onClose: () async {
                            await cubit.saveSessionCheckpoint();
                            if (context.mounted) {
                              unawaited(context.router.maybePop());
                            }
                          },
                        ),
                        // Contextual In-Session Cram Banner (Phase 1 Pillar 2)
                        if (context.read<StudySessionCubit>().daysUntilExam != null &&
                            context.read<StudySessionCubit>().daysUntilExam! > 0) ...[
                          _CramSessionBanner(
                            daysUntilExam: context.read<StudySessionCubit>().daysUntilExam!,
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
                              unawaited(
                                context.read<StudySessionCubit>().finishEarly(),
                              );
                            },
                            onDismiss: () => milestoneTick.value = null,
                          ),
                          const SizedBox(height: 10),
                        ],

                        // Study Buddy Pulse Indicator & Bionic Focus Accommodation
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: colors.primary.withAlpha(
                                  isDark ? 30 : 15,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.card,
                                ),
                                border: Border.all(
                                  color: colors.primary.withAlpha(40),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const _LiveDot(),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Studying with cohort',
                                    style: typography.caption.bold.copyWith(
                                      color: colors.primary,
                                      fontSize: 10.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Semantics(
                              button: true,
                              toggled: isBionicEnabled.value,
                              label: 'Bionic Focus',
                              child: ShrinkableButton(
                                onTap: () {
                                  AppFeedback.selection();
                                  isBionicEnabled.value =
                                      !isBionicEnabled.value;
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isBionicEnabled.value
                                        ? colors.primary.withAlpha(
                                            isDark ? 60 : 35,
                                          )
                                        : colors.surfaceSecondary.withAlpha(
                                            isDark ? 90 : 130,
                                          ),
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.card,
                                    ),
                                    border: Border.all(
                                      color: isBionicEnabled.value
                                          ? colors.primary
                                          : colors.surfaceBorder.withAlpha(60),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.auto_stories_rounded,
                                        size: 13,
                                        color: isBionicEnabled.value
                                            ? colors.primary
                                            : colors.textSecondary,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        'Bionic Focus',
                                        style: typography.caption.bold.copyWith(
                                          color: isBionicEnabled.value
                                              ? colors.primary
                                              : colors.textSecondary,
                                          fontSize: 10.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // 2. Main Flashcard Canvas with 3D Flip & 4-Way Physics
                        Expanded(
                          child: Center(
                            child: FlashcardGestureCanvas(
                              card: currentCard,
                              isFlipped: state.isFlipped,
                              enableBionicReading: isBionicEnabled.value,
                              onTapFlip: () {
                                context.read<StudySessionCubit>().toggleFlip();
                              },
                              onSwipeLeft: () {
                                unawaited(
                                  context.read<StudySessionCubit>().rateCard(
                                    FsrsRating.hard,
                                  ),
                                );
                              },
                              onSwipeRight: () {
                                unawaited(
                                  context.read<StudySessionCubit>().rateCard(
                                    FsrsRating.good,
                                  ),
                                );
                              },
                              onSwipeUp: () {
                                unawaited(
                                  context.read<StudySessionCubit>().rateCard(
                                    FsrsRating.easy,
                                  ),
                                );
                              },
                              onSwipeDown: () {
                                unawaited(
                                  context.read<StudySessionCubit>().rateCard(
                                    FsrsRating.again,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 3. FSRS-6 Rating Controls (Revealed when card is flipped)
                        AnimatedSize(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutQuint,
                          alignment: Alignment.topCenter,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            switchInCurve: Curves.easeOutQuint,
                            switchOutCurve: Curves.easeOut,
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween(
                                      begin: const Offset(0, 0.02),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                ),
                            child: !state.isFlipped
                                ? Container(
                                    key: const ValueKey('study-hint'),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 2,
                                    ),
                                    alignment: Alignment.center,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          l10n.studySessionSwipeHint,
                                          style: typography.footnote.regular
                                              .copyWith(
                                                color: colors.textMuted,
                                                fontSize: 11.5,
                                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        ShrinkableButton(
                                          onTap: () {
                                            unawaited(
                                              FeynmanActiveRecallSheet.show(
                                                context,
                                                card: currentCard,
                                                onRevealCard: () {
                                                  context
                                                      .read<StudySessionCubit>()
                                                      .toggleFlip();
                                                },
                                              ),
                                            );
                                          },
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  '💡 Pro-Tip: Explain aloud before flipping (Feynman Active Recall)',
                                                  style: typography.caption.regular
                                                      .copyWith(
                                                        color: colors.primary
                                                            .withAlpha(
                                                          isDark ? 210 : 170,
                                                        ),
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Icon(
                                                Icons.mic_rounded,
                                                size: 12,
                                                color: colors.primary,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : Column(
                                    key: const ValueKey('study-ratings'),
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      FsrsRatingActionBar(
                                        intervalPreviews: context
                                            .read<StudySessionCubit>()
                                            .ratingIntervalPreviews,
                                        onRateRating: (rating) {
                                          unawaited(
                                            context
                                                .read<StudySessionCubit>()
                                                .rateCard(
                                                  rating,
                                                ),
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 6),
                                      ShrinkableButton(
                                        onTap: () {
                                          unawaited(
                                            HapticFeedback.lightImpact(),
                                          );
                                          final firstLinePrompt = currentCard
                                              .front
                                              .split('\n')
                                              .first
                                              .trim();
                                          final topicName =
                                              currentCard.sourceTopic
                                                      ?.trim()
                                                      .isNotEmpty ==
                                                  true
                                              ? currentCard.sourceTopic!.trim()
                                              : 'Flashcard';

                                          unawaited(
                                            CreatePostBottomSheet.show(
                                              context,
                                              lockedTrack:
                                                  (currentCard
                                                          .sourceTopic
                                                          ?.isNotEmpty ??
                                                      false)
                                                  ? currentCard.sourceTopic
                                                  : null,
                                              initialTitle:
                                                  '[$topicName] Question on: $firstLinePrompt',
                                              initialContent:
                                                  '${currentCard.front}\n\n'
                                                  '💡 I am reviewing this flashcard and need help understanding the underlying concept. '
                                                  'Could someone in the cohort explain the step-by-step reasoning or formula derivation?',
                                              initialLatex:
                                                  currentCard.frontLatex ??
                                                  currentCard.backLatex,
                                              initialSyllabusTag: topicName,
                                              initialIsQuestion: true,
                                              contextBadge:
                                                  'Flashcard Bounty • $topicName',
                                              onSubmit:
                                                  ({
                                                    required title,
                                                    required content,
                                                    required track,
                                                    latexContent,
                                                    isQuestion = true,
                                                    syllabusTag = 'Flashcards',
                                                    isAnonymous = false,
                                                  }) {
                                                    if (locator
                                                        .isRegistered<
                                                          CommunityHubBloc
                                                        >()) {
                                                      locator<
                                                            CommunityHubBloc
                                                          >()
                                                          .add(
                                                            CreateForumPostEvent(
                                                              title: title,
                                                              content: content,
                                                              track: track,
                                                              latexContent:
                                                                  latexContent,
                                                              isQuestion: true,
                                                              syllabusTag:
                                                                  syllabusTag,
                                                              isAnonymous:
                                                                  isAnonymous,
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
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 4,
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.help_outline_rounded,
                                                size: 13,
                                                color: colors.warning,
                                              ),
                                              const SizedBox(width: 5),
                                              Text(
                                                'Stuck on this card? Post Bounty to Cohort',
                                                style: typography.caption.bold
                                                    .copyWith(
                                                      color: colors.warning,
                                                      fontSize: 11,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
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

/// Slow breathing dot for the "studying with cohort" presence pill —
/// a quiet liveness signal, frozen under reduced motion.
class _LiveDot extends StatefulWidget {
  const _LiveDot();

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      unawaited(_controller.repeat(reverse: true));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return FadeTransition(
      opacity: Tween<double>(begin: 0.55, end: 1).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.success,
        ),
      ),
    );
  }
}

class _CramSessionBanner extends StatelessWidget {
  const _CramSessionBanner({required this.daysUntilExam});

  final int daysUntilExam;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final isCrunch = daysUntilExam <= 1;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.warning.withValues(alpha: isDark ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: colors.warning.withValues(alpha: isDark ? 0.45 : 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: colors.warning.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.bolt_rounded,
              size: 15,
              color: colors.warning,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isCrunch
                      ? 'Imminent Assessment Crunch'
                      : 'Milestone Crunch: $daysUntilExam days remaining',
                  style: typography.caption.bold.copyWith(
                    color: colors.textPrimary,
                    fontSize: 12,
                  ),
                ),
                Text(
                  isCrunch
                      ? 'Intervals condensed to 24h for acute recall before your test.'
                      : 'FSRS-6 intervals clamped so cards stay fresh before exam day.',
                  style: typography.caption.regular.copyWith(
                    color: colors.textSecondary,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: colors.warning.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppRadius.badge),
              border: Border.all(
                color: colors.warning.withValues(alpha: 0.35),
              ),
            ),
            child: Text(
              'Clamped',
              style: typography.caption.bold.copyWith(
                color: colors.warning,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
