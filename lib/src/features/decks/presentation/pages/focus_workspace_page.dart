import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';
import 'package:kortex/src/features/decks/domain/entities/focus_session_config.dart';
import 'package:kortex/src/features/decks/presentation/bloc/focus_session_cubit.dart';
import 'package:kortex/src/features/decks/presentation/bloc/focus_session_state.dart';
import 'package:kortex/src/features/decks/presentation/widgets/flashcard_gesture_canvas.dart';
import 'package:kortex/src/features/decks/presentation/widgets/fsrs_rating_action_bar.dart';
import 'package:kortex/src/features/decks/presentation/widgets/thought_parking_lot_sheet.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/text_to_speech_handler.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class FocusWorkspacePage extends StatefulWidget {
  const FocusWorkspacePage({
    required this.deckId,
    required this.deckTitle,
    this.preloadedCards,
    this.config = const FocusSessionConfig(),
    super.key,
  });

  final String deckId;
  final String deckTitle;
  final List<FlashcardEntity>? preloadedCards;
  final FocusSessionConfig config;

  @override
  State<FocusWorkspacePage> createState() => _FocusWorkspacePageState();
}

class _FocusWorkspacePageState extends State<FocusWorkspacePage> {
  late final TextToSpeechHandler _ttsHandler;
  late final FocusSessionCubit _cubit;

  @override
  void initState() {
    super.initState();
    _ttsHandler = TextToSpeechHandler();
    _cubit = FocusSessionCubit(
      ttsHandler: _ttsHandler,
    );
    unawaited(
      _cubit.startSession(
        deckId: widget.deckId,
        sessionTitle: widget.deckTitle,
        preloadedCards: widget.preloadedCards,
        config: widget.config,
      ),
    );
  }

  @override
  void dispose() {
    unawaited(_cubit.close());
    unawaited(_ttsHandler.stop());
    super.dispose();
  }

  void _showExitDialog(BuildContext context) {
    _cubit.pauseSession();
    final colors = context.colors;
    final typography = context.typography;

    unawaited(
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: colors.surfacePrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Pause Focus Sprint?',
            style: typography.title3.bold.copyWith(color: colors.textPrimary),
          ),
          content: Text(
            'You can take a quick breath, finish your session early, or jump right back in.',
            style: typography.body.regular.copyWith(color: colors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _cubit.resumeSession();
              },
              child: Text(
                'Resume',
                style: typography.body.medium.copyWith(color: colors.primary),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _cubit.completeEarly();
              },
              child: Text(
                'Finish Early',
                style: typography.body.medium.copyWith(color: colors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
              },
              child: Text(
                'Exit Without Saving',
                style: typography.body.medium.copyWith(color: Colors.redAccent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: Scaffold(
        body: SafeArea(
          child: BlocConsumer<FocusSessionCubit, FocusSessionState>(
            listener: (context, state) {
              if (state.status == FocusSessionStatus.error &&
                  state.errorMessage != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.errorMessage!),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            builder: (context, state) {
              if (state.status == FocusSessionStatus.loading) {
                return const Center(child: CircularProgressIndicator.adaptive());
              }

              if (state.status == FocusSessionStatus.completed) {
                return _FocusCompletionView(
                  state: state,
                  onRepeat: () {
                    unawaited(
                      _cubit.startSession(
                        deckId: widget.deckId,
                        sessionTitle: widget.deckTitle,
                        preloadedCards: widget.preloadedCards,
                        config: widget.config,
                      ),
                    );
                  },
                  onDone: () => Navigator.of(context).pop(),
                );
              }

              final currentCard = state.currentCard;
              if (currentCard == null) {
                return Center(
                  child: Text(
                    state.errorMessage ?? 'No cards available.',
                    style: context.typography.body.medium.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  // Zen Distraction-Free Header
                  _FocusZenHeader(
                    state: state,
                    onClose: () => _showExitDialog(context),
                    onToggleTts: () => _cubit.toggleTts(),
                    onOpenParkingLot: () => unawaited(ThoughtParkingLotSheet.show(context)),
                  ),

                  // Dopamine Streak Indicator
                  if (state.streak >= 2) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 2),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🔥 ', style: TextStyle(fontSize: 13)),
                            Text(
                              '${state.streak} in a row! Momentum building',
                              style: context.typography.caption.bold.copyWith(
                                color: const Color(0xFFD97706),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Flashcard Gesture Canvas
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: FlashcardGestureCanvas(
                        card: currentCard,
                        isFlipped: state.isFlipped,
                        onTapFlip: () => _cubit.toggleFlip(),
                        onSwipeLeft: () => unawaited(_cubit.rateCard(1)),
                        onSwipeRight: () => unawaited(_cubit.rateCard(3)),
                        onSwipeUp: () => unawaited(_cubit.rateCard(4)),
                        onSwipeDown: () => unawaited(_cubit.rateCard(2)),
                      ),
                    ),
                  ),

                  // FSRS Rating Bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: FsrsRatingActionBar(
                      onRateRating: (rating) => unawaited(_cubit.rateCard(rating)),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FocusZenHeader extends StatelessWidget {
  const _FocusZenHeader({
    required this.state,
    required this.onClose,
    required this.onToggleTts,
    required this.onOpenParkingLot,
  });

  final FocusSessionState state;
  final VoidCallback onClose;
  final VoidCallback onToggleTts;
  final VoidCallback onOpenParkingLot;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isTimed = state.config.type == FocusSessionType.timed;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.close_rounded, color: colors.textSecondary),
                onPressed: onClose,
                tooltip: 'Pause / Exit',
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  children: [
                    if (!state.config.hideCardCounter) ...[
                      Text(
                        isTimed
                            ? state.timeRemainingFormatted
                            : '${state.currentIndex + 1} of ${state.cards.length}',
                        style: typography.caption.bold.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    // Smooth visual Time-Timer progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: state.progress,
                        minHeight: 6,
                        backgroundColor: colors.surfaceSecondary,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // TTS Button
              IconButton(
                icon: Icon(
                  state.ttsSpeaking
                      ? Icons.volume_up_rounded
                      : Icons.volume_mute_rounded,
                  color: state.ttsSpeaking ? colors.primary : colors.textSecondary,
                ),
                onPressed: onToggleTts,
                tooltip: 'Read Aloud',
              ),

              // Thought Parking Lot Button with badge
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.psychology_rounded,
                      color: state.parkedThoughts.isNotEmpty
                          ? colors.primary
                          : colors.textSecondary,
                    ),
                    onPressed: onOpenParkingLot,
                    tooltip: 'Thought Parking Lot',
                  ),
                  if (state.parkedThoughts.isNotEmpty)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFF8B5CF6),
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '${state.parkedThoughts.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FocusCompletionView extends StatelessWidget {
  const _FocusCompletionView({
    required this.state,
    required this.onRepeat,
    required this.onDone,
  });

  final FocusSessionState state;
  final VoidCallback onRepeat;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final total = state.cards.length;
    final mastered = state.goodCount + state.easyCount;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          // Celebratory Icon
          Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.emoji_events_rounded,
                color: Colors.white,
                size: 56,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Title & Subtitle
          Text(
            'Hyperdrive Sprint Complete!',
            textAlign: TextAlign.center,
            style: typography.largeTitle.bold.copyWith(
              color: colors.textPrimary,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You conquered task paralysis with focused micro-momentum.',
            textAlign: TextAlign.center,
            style: typography.body.regular.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 32),

          // Stats Grid
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.surfaceSecondary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatColumn(
                  label: 'Cards Crushed',
                  value: '$total',
                  icon: Icons.layers_rounded,
                  color: colors.primary,
                ),
                _StatColumn(
                  label: 'Mastered',
                  value: '$mastered',
                  icon: Icons.check_circle_rounded,
                  color: const Color(0xFF10B981),
                ),
                _StatColumn(
                  label: 'Time Spent',
                  value: state.timeElapsedFormatted,
                  icon: Icons.timer_outlined,
                  color: const Color(0xFFF59E0B),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Parked Thoughts Review (if any)
          if (state.parkedThoughts.isNotEmpty) ...[
            Text(
              'Thoughts Parked During Session',
              style: typography.headline.bold.copyWith(
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your working memory dumped these thoughts so you could focus:',
              style: typography.footnote.regular.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surfaceSecondary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: state.parkedThoughts.map((thought) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lightbulb_outline_rounded,
                          color: colors.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            thought.content,
                            style: typography.body.regular.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 28),
          ],

          // Repeat Sprint Button
          ShrinkableButton(
            onTap: () {
              AppFeedback.selection();
              onRepeat();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Repeat Another Sprint',
                    style: typography.body.medium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Done Button
          ShrinkableButton(
            onTap: () {
              AppFeedback.selection();
              onDone();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: colors.surfaceSecondary,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colors.surfaceBorder.withValues(alpha: 0.6),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                'Return to Decks',
                style: typography.body.medium.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final typography = context.typography;
    final colors = context.colors;

    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: typography.title3.bold.copyWith(
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: typography.footnote.regular.copyWith(
            color: colors.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
