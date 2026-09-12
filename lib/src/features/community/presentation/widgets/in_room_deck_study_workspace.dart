import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/presentation/bloc/live_room_cubit.dart';
import 'package:kortex/src/features/decks/data/data_sources/card_sync_queue.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';
import 'package:kortex/src/features/decks/domain/logic/fsrs_scheduler.dart';
import 'package:kortex/src/features/decks/domain/repositories/decks_repository.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/decks/presentation/widgets/latex_card_content_viewer.dart';
import 'package:kortex/src/shared/widgets/app_logo_loader.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// In-Room Active Recall Study Deck Workspace.
///
/// Enables students in a Live Focus Pod / Study Room to work directly on
/// flashcard decks with FSRS spaced repetition while remaining connected
/// to room audio, synchronized Pomodoro timer, and peer presence.
class InRoomDeckStudyWorkspace extends StatefulWidget {
  const InRoomDeckStudyWorkspace({
    required this.roomState,
    super.key,
  });

  final LiveRoomState roomState;

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

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutBack),
    );

    if (widget.roomState.activeDeckId != null) {
      unawaited(_loadDeckCards(widget.roomState.activeDeckId!));
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
      final repository = locator.isRegistered<DecksRepository>()
          ? locator<DecksRepository>()
          : null;
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
    if (_cards.isEmpty || _currentIndex >= _cards.length) return;

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
    final initialStability =
        currentCard.interval > 0 ? currentCard.interval.toDouble() : 0.0;
    final initialDifficulty =
        ((3.0 - currentCard.easeFactor) * 5.0).clamp(1.0, 10.0);

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

    // 3. Persist review log to sync queue
    if (locator.isRegistered<CardSyncQueue>()) {
      unawaited(locator<CardSyncQueue>().enqueueReview(reviewResult.log));
    }

    // 4. Update card state in-memory & locally
    final updatedCard = currentCard.copyWith(
      repetitions: reviewResult.card.reps,
      interval: reviewResult.card.scheduledDays,
      easeFactor: (3.0 - (reviewResult.card.difficulty / 5.0)).clamp(1.3, 2.5),
      lastReviewed: nowUtc,
      nextDueDate: reviewResult.card.due ??
          nowUtc.add(Duration(
              days: reviewResult.card.scheduledDays > 0
                  ? reviewResult.card.scheduledDays
                  : 1)),
    );

    final updatedCards = List<FlashcardEntity>.from(_cards);
    if (_currentIndex >= 0 && _currentIndex < updatedCards.length) {
      updatedCards[_currentIndex] = updatedCard;
    }
    _cards = updatedCards;

    if (locator.isRegistered<DecksRepository>()) {
      unawaited(locator<DecksRepository>().updateDeckCards(
        widget.roomState.activeDeckId ?? currentCard.deckId,
        updatedCards,
      ));
    }

    // 5. Log card completion to LiveRoomCubit & broadcast to room members
    context.read<LiveRoomCubit>().logCardReviewed(1, deckTitle);

    // 6. Advance to next card
    if (_isFlipped) {
      await _flipController.reverse();
    }
    setState(() {
      _isFlipped = false;
      _showAiHintPrompt = false;
      _activeAiHint = null;
      if (_currentIndex < _cards.length - 1) {
        _currentIndex++;
      } else {
        _currentIndex = _cards.length; // Complete state
      }
    });

    _resetInactivityTimer();
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
    final isDark = context.isDarkMode;

    if (widget.roomState.activeDeckId == null ||
        (_cards.isEmpty && !_isLoadingCards)) {
      return _buildDeckPicker(context, colors, typography, isDark);
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
      return _buildDeckCompletedView(context, colors, typography, isDark);
    }

    final currentCard = _cards[_currentIndex];

    return Column(
      children: [
        // Top Study HUD Bar: Deck title, card progress, and switch deck
        _buildTopStudyHud(context, colors, typography, isDark),
        const SizedBox(height: 8),

        // Main Flashcard Area with 3D Flip
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildInteractiveFlashcard(
              context,
              currentCard,
              colors,
              typography,
              isDark,
            ),
          ),
        ),

        // Ambient AI Syllabot Inactivity Hint Pill (if triggered)
        if (_showAiHintPrompt || _activeAiHint != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildAiHintBanner(context, colors, typography, isDark),
          ),
        ],

        const SizedBox(height: 10),

        // Bottom Recall Grading Action Bar (Again, Hard, Good, Easy)
        _buildFsrsRatingBar(context, colors, typography, isDark),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildTopStudyHud(
    BuildContext context,
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
    bool isDark,
  ) {
    final deckTitle =
        widget.roomState.activeDeckTitle ?? widget.roomState.room.subject;
    final totalCards = _cards.length;
    final progress = totalCards > 0 ? (_currentIndex + 1) / totalCards : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surfacePrimary.withAlpha(isDark ? 160 : 230),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.primary.withAlpha(isDark ? 50 : 25),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: colors.primary.withAlpha(isDark ? 50 : 25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.style_rounded, size: 16, color: colors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  deckTitle,
                  style: typography.body.bold.copyWith(
                    color: colors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 4,
                          backgroundColor: colors.surfaceTertiary,
                          valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_currentIndex + 1}/$totalCards',
                      style: typography.caption.bold.copyWith(
                        color: colors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ShrinkableButton(
            onTap: () {
              unawaited(HapticFeedback.lightImpact());
              context.read<LiveRoomCubit>().clearActiveDeck();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colors.surfaceTertiary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.swap_horiz_rounded,
                    size: 14,
                    color: colors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Decks',
                    style: typography.caption.bold.copyWith(
                      color: colors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveFlashcard(
    BuildContext context,
    FlashcardEntity card,
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
    bool isDark,
  ) {
    return GestureDetector(
      onTap: _toggleFlip,
      child: AnimatedBuilder(
        animation: _flipAnimation,
        builder: (context, child) {
          final angle = _flipAnimation.value * math.pi;
          final isUnder = angle > math.pi / 2;

          return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            alignment: Alignment.center,
            child: isUnder
                ? Transform(
                    transform: Matrix4.identity()..rotateY(math.pi),
                    alignment: Alignment.center,
                    child: _buildCardFace(
                      context,
                      title: 'ANSWER / EXPLANATION',
                      content: card.back,
                      isBack: true,
                      colors: colors,
                      typography: typography,
                      isDark: isDark,
                    ),
                  )
                : _buildCardFace(
                    context,
                    title: 'QUESTION / PROMPT',
                    content: card.front,
                    isBack: false,
                    colors: colors,
                    typography: typography,
                    isDark: isDark,
                  ),
          );
        },
      ),
    );
  }

  Widget _buildCardFace(
    BuildContext context, {
    required String title,
    required String content,
    required bool isBack,
    required AppThemeColorsExtension colors,
    required TypographyThemeExtension typography,
    required bool isDark,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfacePrimary,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isBack
              ? colors.primary.withAlpha(isDark ? 120 : 80)
              : colors.surfaceBorder.withAlpha(isDark ? 60 : 40),
          width: isBack ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.black.withAlpha(isDark ? 70 : 15),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isBack
                      ? colors.recallEasy.withAlpha(isDark ? 40 : 25)
                      : colors.primary.withAlpha(isDark ? 40 : 20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isBack ? Icons.check_circle_outline : Icons.help_outline,
                      size: 13,
                      color: isBack ? colors.recallEasy : colors.primary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      title,
                      style: typography.caption.bold.copyWith(
                        color: isBack ? colors.recallEasy : colors.primary,
                        fontSize: 10.5,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Icon(
                    Icons.touch_app_rounded,
                    size: 14,
                    color: colors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Tap to flip',
                    style: typography.caption.regular.copyWith(
                      color: colors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: LatexCardContentViewer(
                  text: content,
                  isBackFace: isBack,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiHintBanner(
    BuildContext context,
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
    bool isDark,
  ) {
    if (_activeAiHint != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.warning.withAlpha(isDark ? 35 : 20),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: colors.warning.withAlpha(isDark ? 90 : 50),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.smart_toy_rounded, size: 18, color: colors.warning),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _activeAiHint!,
                style: typography.caption.regular.copyWith(
                  color: colors.textPrimary,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.primary.withAlpha(isDark ? 30 : 15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colors.primary.withAlpha(isDark ? 70 : 35),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline_rounded,
              size: 16, color: colors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Stuck on this concept? Syllabot AI can help.',
              style: typography.caption.medium.copyWith(
                color: colors.textPrimary,
                fontSize: 11.5,
              ),
            ),
          ),
          ShrinkableButton(
            onTap: _isLoadingHint ? null : _generateSyllabotHint,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: _isLoadingHint
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Get Hint',
                      style: typography.caption.bold.copyWith(
                        color: Colors.white,
                        fontSize: 11,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFsrsRatingBar(
    BuildContext context,
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _FsrsGradeButton(
              label: 'Again',
              sublabel: '< 1m',
              grade: 1,
              color: colors.error,
              onTap: () => unawaited(_rateCard(1)),
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _FsrsGradeButton(
              label: 'Hard',
              sublabel: '10m',
              grade: 2,
              color: colors.recallHard,
              onTap: () => unawaited(_rateCard(2)),
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _FsrsGradeButton(
              label: 'Good',
              sublabel: '1d',
              grade: 3,
              color: colors.recallGood,
              onTap: () => unawaited(_rateCard(3)),
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _FsrsGradeButton(
              label: 'Easy',
              sublabel: '4d',
              grade: 4,
              color: colors.recallEasy,
              onTap: () => unawaited(_rateCard(4)),
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeckPicker(
    BuildContext context,
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
    bool isDark,
  ) {
    final decksBloc =
        locator.isRegistered<DecksBloc>() ? locator<DecksBloc>() : null;
    final allDecks = decksBloc?.state.allDecks ?? const <DeckEntity>[];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.primary.withAlpha(isDark ? 40 : 25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.auto_stories_rounded,
                  size: 20,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose a Deck to Study',
                      style: typography.subhead.bold.copyWith(
                        color: colors.textPrimary,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      'Study alongside your pod with active FSRS recall',
                      style: typography.caption.regular.copyWith(
                        color: colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: allDecks.isEmpty
                ? Center(
                    child: Text(
                      'No decks available yet. Create or import a deck to start!',
                      style: typography.body.regular.copyWith(
                        color: colors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    itemCount: allDecks.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final deck = allDecks[index];
                      final isDue = deck.dueCards > 0;

                      return ShrinkableButton(
                        onTap: () {
                          unawaited(HapticFeedback.mediumImpact());
                          context
                              .read<LiveRoomCubit>()
                              .selectActiveDeck(deck.id, deck.title);
                          unawaited(_loadDeckCards(deck.id));
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colors.surfacePrimary,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDue
                                  ? colors.recallHard
                                      .withAlpha(isDark ? 100 : 70)
                                  : colors.surfaceBorder
                                      .withAlpha(isDark ? 50 : 30),
                              width: isDue ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: colors.primary
                                      .withAlpha(isDark ? 40 : 20),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.style_rounded,
                                    size: 22,
                                    color: colors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      deck.title,
                                      style: typography.body.bold.copyWith(
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${deck.totalCards} cards • ${deck.subject}',
                                      style:
                                          typography.caption.regular.copyWith(
                                        color: colors.textSecondary,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isDue)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.recallHard
                                        .withAlpha(isDark ? 40 : 25),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${deck.dueCards} Due',
                                    style: typography.caption.bold.copyWith(
                                      color: colors.recallHard,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: colors.textSecondary,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeckCompletedView(
    BuildContext context,
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
    bool isDark,
  ) {
    final deckTitle =
        widget.roomState.activeDeckTitle ?? widget.roomState.room.subject;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.recallEasy.withAlpha(isDark ? 50 : 30),
              ),
              child: Icon(
                Icons.emoji_events_rounded,
                size: 54,
                color: colors.recallEasy,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Deck Round Complete! 🎉',
              style: typography.title2.bold.copyWith(
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You reviewed all ${_cards.length} cards in "$deckTitle" alongside your pod.',
              style: typography.body.medium.copyWith(
                color: colors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ShrinkableButton(
                  onTap: () {
                    unawaited(HapticFeedback.lightImpact());
                    setState(() {
                      _currentIndex = 0;
                      _isFlipped = false;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceTertiary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Review Again',
                      style: typography.body.bold.copyWith(
                        color: colors.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ShrinkableButton(
                  onTap: () {
                    unawaited(HapticFeedback.mediumImpact());
                    context.read<LiveRoomCubit>().clearActiveDeck();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Switch Deck',
                      style: typography.body.bold.copyWith(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FsrsGradeButton extends StatelessWidget {
  const _FsrsGradeButton({
    required this.label,
    required this.sublabel,
    required this.grade,
    required this.color,
    required this.onTap,
    required this.isDark,
  });

  final String label;
  final String sublabel;
  final int grade;
  final Color color;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final typography = context.typography;

    return ShrinkableButton(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withAlpha(isDark ? 40 : 25),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withAlpha(isDark ? 90 : 60),
            width: 1.2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: typography.caption.bold.copyWith(
                color: color,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sublabel,
              style: typography.caption.regular.copyWith(
                fontSize: 10,
                color: color.withAlpha(200),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
