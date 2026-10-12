import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';
import 'package:kortex/src/features/decks/domain/logic/fsrs_scheduler.dart';
import 'package:kortex/src/features/decks/domain/repositories/decks_repository.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_event.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_state.dart';
import 'package:kortex/src/features/study_rooms/presentation/bloc/live_room_cubit.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/workspace/workspace_ai_hint_banner.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/workspace/workspace_deck_completed_view.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/workspace/workspace_deck_picker_view.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/workspace/workspace_fsrs_rating_bar.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/workspace/workspace_interactive_flashcard.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/workspace/workspace_top_study_hud.dart';
import 'package:kortex/src/shared/widgets/app_logo_loader.dart';
import 'package:kortex/src/shared/widgets/gratification_celebration_overlay.dart';

/// In-Room Active Recall Study Deck Workspace.
///
/// Enables students in a Live Focus Pod / Study Room to work directly on
/// flashcard decks with FSRS spaced repetition while remaining connected
/// to room audio, synchronized Pomodoro timer, and peer presence.
class InRoomDeckStudyWorkspace extends StatefulWidget {
  const InRoomDeckStudyWorkspace({
    required this.roomState,
    this.decksRepository,
    this.decksBloc,
    this.dashboardBloc,
    super.key,
  });

  final LiveRoomState roomState;
  final DecksRepository? decksRepository;
  final DecksBloc? decksBloc;
  final DashboardBloc? dashboardBloc;

  @override
  State<InRoomDeckStudyWorkspace> createState() =>
      _InRoomDeckStudyWorkspaceState();
}

class _InRoomDeckStudyWorkspaceState extends State<InRoomDeckStudyWorkspace>
    with SingleTickerProviderStateMixin {
  List<FlashcardEntity> _cards = [];
  int _currentIndex = 0;
  bool _isFlipped = false;
  bool _isLoadingCards = false;
  bool _isRatingLocked = false;
  String? _loadedDeckId;

  // 3D Flip animation
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  // Syllabot AI Inactivity Detection
  Timer? _inactivityTimer;
  bool _showAiHintPrompt = false;
  String? _activeAiHint;
  bool _isLoadingHint = false;

  final FsrsScheduler _fsrsScheduler = FsrsScheduler();

  DecksRepository? get _decksRepository =>
      widget.decksRepository ??
      (locator.isRegistered<DecksRepository>()
          ? locator<DecksRepository>()
          : null);

  DecksBloc? get _decksBloc =>
      widget.decksBloc ??
      (locator.isRegistered<DecksBloc>() ? locator<DecksBloc>() : null);

  DashboardBloc? get _dashboardBloc =>
      widget.dashboardBloc ??
      (locator.isRegistered<DashboardBloc>()
          ? locator<DashboardBloc>()
          : null);

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutCubic),
    );

    if (widget.roomState.activeDeckId != null) {
      unawaited(_loadDeckCards(widget.roomState.activeDeckId!));
    }

    final bloc = _decksBloc;
    if (bloc != null) {
      if (bloc.state.allDecks.isEmpty ||
          bloc.state.status == DecksStatus.initial) {
        bloc.add(const DecksStarted());
      } else {
        bloc.add(const DecksRefreshed());
      }
    }
  }

  @override
  void didUpdateWidget(covariant InRoomDeckStudyWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.roomState.activeDeckId != oldWidget.roomState.activeDeckId &&
        widget.roomState.activeDeckId != null) {
      unawaited(_loadDeckCards(widget.roomState.activeDeckId!));
    }
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    _flipController.dispose();
    super.dispose();
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    if (_showAiHintPrompt) {
      setState(() {
        _showAiHintPrompt = false;
        _activeAiHint = null;
      });
    }

    // After 2.5 minutes of inactivity on a single card, trigger ambient Syllabot assistance
    _inactivityTimer = Timer(const Duration(seconds: 150), () {
      if (mounted && _cards.isNotEmpty && !_isFlipped) {
        setState(() {
          _showAiHintPrompt = true;
        });
      }
    });
  }

  Future<void> _loadDeckCards(String deckId) async {
    if (_loadedDeckId == deckId && _cards.isNotEmpty) return;

    setState(() {
      _isLoadingCards = true;
      _loadedDeckId = deckId;
      _currentIndex = 0;
      _isFlipped = false;
    });
    _flipController.reset();

    try {
      final repository = _decksRepository;
      if (repository != null) {
        final result = await repository.getDeckCards(deckId);
        result.fold(
          (failure) => setState(() => _cards = []),
          (cards) => setState(() {
            _cards = List<FlashcardEntity>.from(cards);
          }),
        );
      }
    } on Object catch (_) {
      setState(() => _cards = []);
    } finally {
      if (mounted) {
        setState(() => _isLoadingCards = false);
        _resetInactivityTimer();
      }
    }
  }

  void _toggleFlip() {
    unawaited(HapticFeedback.lightImpact());
    _resetInactivityTimer();
    if (_isFlipped) {
      unawaited(_flipController.reverse());
    } else {
      unawaited(_flipController.forward());
    }
    setState(() => _isFlipped = !_isFlipped);
  }

  Future<void> _rateCard(int grade) async {
    if (_cards.isEmpty || _currentIndex >= _cards.length || _isRatingLocked) {
      return;
    }

    setState(() {
      _isRatingLocked = true;
    });

    unawaited(HapticFeedback.mediumImpact());
    final currentCard = _cards[_currentIndex];
    final deckTitle =
        widget.roomState.activeDeckTitle ?? widget.roomState.room.subject;

    // 1. Resolve FsrsRating
    final FsrsRating fsrsRating;
    switch (grade) {
      case 1:
        fsrsRating = FsrsRating.again;
      case 2:
        fsrsRating = FsrsRating.hard;
      case 3:
        fsrsRating = FsrsRating.good;
      case 4:
      default:
        fsrsRating = FsrsRating.easy;
    }

    // 2. FSRS Review State Transition
    final nowUtc = DateTime.now().toUtc();
    final lastReviewUtc = currentCard.lastReviewed?.toUtc();
    final elapsedDays = lastReviewUtc == null
        ? 0
        : nowUtc.difference(lastReviewUtc).inDays.clamp(0, 36500);

    final isNewCard =
        currentCard.repetitions == 0 && currentCard.lastReviewed == null;
    final initialStability = currentCard.interval > 0
        ? currentCard.interval.toDouble()
        : 0.0;
    final initialDifficulty = ((3.0 - currentCard.easeFactor) * 5.0).clamp(
      1.0,
      10.0,
    );

    final fsrsCard = FsrsCard(
      cardId: currentCard.id,
      due: currentCard.nextDueDate?.toUtc(),
      stability: initialStability,
      difficulty: initialDifficulty,
      elapsedDays: elapsedDays,
      scheduledDays: currentCard.interval,
      reps: currentCard.repetitions,
      state: isNewCard ? FsrsCardState.newCard : FsrsCardState.review,
      lastReview: lastReviewUtc,
      lastReviewedEpoch: lastReviewUtc?.millisecondsSinceEpoch ?? 0,
    );

    final reviewResult = _fsrsScheduler.reviewCard(
      currentCard: fsrsCard,
      rating: fsrsRating,
      now: nowUtc,
    );

    // 3. Persist review log via domain repository
    final repository = _decksRepository;
    if (repository != null) {
      unawaited(repository.enqueueReviewLog(reviewResult.log));
    }

    // 4. Update card state in-memory & locally
    final updatedCard = currentCard.copyWith(
      repetitions: reviewResult.card.reps,
      interval: reviewResult.card.scheduledDays,
      easeFactor: (3.0 - (reviewResult.card.difficulty / 5.0)).clamp(1.3, 2.5),
      lastReviewed: nowUtc,
      nextDueDate:
          reviewResult.card.due ??
          nowUtc.add(
            Duration(
              days: reviewResult.card.scheduledDays > 0
                  ? reviewResult.card.scheduledDays
                  : 1,
            ),
          ),
    );

    final updatedCards = List<FlashcardEntity>.from(_cards);
    if (_currentIndex >= 0 && _currentIndex < updatedCards.length) {
      updatedCards[_currentIndex] = updatedCard;
    }
    _cards = updatedCards;

    // 5. Log card completion to LiveRoomCubit & broadcast to room members
    context.read<LiveRoomCubit>().logCardReviewed(1, deckTitle);

    // 6. Advance to next card
    if (_isFlipped) {
      await _flipController.reverse();
    }
    final isComplete = _currentIndex >= _cards.length - 1;
    setState(() {
      _isFlipped = false;
      _showAiHintPrompt = false;
      _activeAiHint = null;
      if (!isComplete) {
        _currentIndex++;
      } else {
        _currentIndex = _cards.length; // Complete state
      }
    });

    // 7. On deck completion, batch-persist deck card updates and refresh feeds
    if (isComplete && mounted) {
      if (repository != null) {
        unawaited(
          repository.updateDeckCards(
            widget.roomState.activeDeckId ?? currentCard.deckId,
            updatedCards,
          ),
        );
      }
      _decksBloc?.add(const DecksRefreshed());
      _dashboardBloc?.add(const DashboardRefreshed());
      unawaited(
        GratificationCelebrationOverlay.show(
          context,
          title: 'Deck Round Mastered! 🎉',
          subtitle:
              'You reviewed all ${_cards.length} cards in "$deckTitle" alongside your pod.',
          primaryStatLabel: 'Cards Reviewed',
          primaryStatValue: '${_cards.length}',
          secondaryStatLabel: 'Sprint Score',
          secondaryStatValue: '100%',
          xpEarned: _cards.length * 10,
        ),
      );
    }

    _resetInactivityTimer();

    // 8. Release rating lock after transition delay to prevent spamming
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (mounted) {
      setState(() {
        _isRatingLocked = false;
      });
    }
  }

  void _generateSyllabotHint() {
    if (_cards.isEmpty || _currentIndex >= _cards.length) return;
    unawaited(HapticFeedback.lightImpact());

    setState(() {
      _isLoadingHint = true;
    });

    final currentCard = _cards[_currentIndex];
    // Generate intelligent clue by extracting keywords / first thought-starter
    unawaited(
      Future.delayed(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        final answer = currentCard.back.trim();
        final words = answer.split(' ');
        final hintSnippet = words.take(math.min(6, words.length)).join(' ');
        setState(() {
          _isLoadingHint = false;
          _activeAiHint =
              '💡 Thought starter: Think about "$hintSnippet..." and how it connects to ${currentCard.front.split('?').first.trim()}.';
        });
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    if (widget.roomState.activeDeckId == null ||
        (_cards.isEmpty && !_isLoadingCards)) {
      return WorkspaceDeckPickerView(
        decksBloc: _decksBloc,
        onDeckSelected: (deck) {
          context.read<LiveRoomCubit>().selectActiveDeck(
            deck.id,
            deck.title,
          );
          unawaited(_loadDeckCards(deck.id));
        },
      );
    }

    if (_isLoadingCards) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AppLogoLoader(size: 44),
            const SizedBox(height: 16),
            Text(
              'Loading Deck Flashcards...',
              style: typography.body.medium.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (_currentIndex >= _cards.length) {
      final deckTitle =
          widget.roomState.activeDeckTitle ?? widget.roomState.room.subject;
      return WorkspaceDeckCompletedView(
        deckTitle: deckTitle,
        totalCards: _cards.length,
        onReviewAgainTap: () {
          unawaited(HapticFeedback.lightImpact());
          _decksBloc?.add(const DecksRefreshed());
          setState(() {
            _currentIndex = 0;
            _isFlipped = false;
          });
        },
        onSwitchDeckTap: () {
          unawaited(HapticFeedback.mediumImpact());
          _decksBloc?.add(const DecksRefreshed());
          context.read<LiveRoomCubit>().clearActiveDeck();
        },
      );
    }

    final currentCard = _cards[_currentIndex];
    final deckTitle =
        widget.roomState.activeDeckTitle ?? widget.roomState.room.subject;

    return Column(
      children: [
        // Top Study HUD Bar: Deck title, card progress, and switch deck
        WorkspaceTopStudyHud(
          deckTitle: deckTitle,
          currentIndex: _currentIndex,
          totalCards: _cards.length,
          onSwitchDeckTap: () {
            unawaited(HapticFeedback.lightImpact());
            context.read<LiveRoomCubit>().clearActiveDeck();
          },
        ),
        const SizedBox(height: 8),

        // Main Flashcard Area with 3D Flip
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: WorkspaceInteractiveFlashcard(
              card: currentCard,
              flipAnimation: _flipAnimation,
              onFlipTap: _toggleFlip,
            ),
          ),
        ),

        // Ambient AI Syllabot Inactivity Hint Pill (if triggered)
        if (_showAiHintPrompt || _activeAiHint != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: WorkspaceAiHintBanner(
              activeAiHint: _activeAiHint,
              isLoadingHint: _isLoadingHint,
              onGetHintTap: _generateSyllabotHint,
            ),
          ),
        ],

        const SizedBox(height: 10),

        // Bottom Recall Grading Action Bar (Again, Hard, Good, Easy)
        WorkspaceFsrsRatingBar(
          isRatingLocked: _isRatingLocked,
          onRateCard: (grade) => unawaited(_rateCard(grade)),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
