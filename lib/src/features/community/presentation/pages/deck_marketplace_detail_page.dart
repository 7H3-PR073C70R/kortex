import 'dart:async';
import 'dart:convert';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/domain/entities/shared_deck_entity.dart';
import 'package:kortex/src/features/community/domain/use_cases/clone_shared_deck_use_case.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_event.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_logo_loader.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

@RoutePage()
class DeckMarketplaceDetailPage extends HookWidget {
  const DeckMarketplaceDetailPage({
    required this.deck,
    super.key,
  });

  final SharedDeckEntity deck;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final isCloning = useState<bool>(false);

    Future<void> handleClone() async {
      isCloning.value = true;
      try {
        final useCase = locator<CloneSharedDeckUseCase>();
        final res = await useCase(deck.id);
        isCloning.value = false;

        if (!context.mounted) return;
        final failureOrDeck = res;
        await failureOrDeck.fold(
          (failure) async {
            if (!context.mounted) return;
            context.showSnackBar(
              message: failure.message ?? l10n.marketplaceCloneFailed,
              type: SnackBarType.error,
            );
          },
          (clonedDeck) async {
            try {
              final storage = locator.isRegistered<LocalStorageService>()
                  ? locator<LocalStorageService>()
                  : null;
              if (storage != null) {
                final raw =
                    storage.getPreference(key: PrefKeys.persistedUserDecks);
                final existingList = raw != null && raw.isNotEmpty
                    ? (jsonDecode(raw) as List<dynamic>)
                    : <dynamic>[];

                final deckMap = <String, dynamic>{
                  'id': clonedDeck.id,
                  'title': clonedDeck.title,
                  'subject': clonedDeck.subject,
                  'total_cards': clonedDeck.totalCards,
                  'due_cards': clonedDeck.dueCards,
                  'mastery_rate': clonedDeck.masteryRate,
                  'category': clonedDeck.category,
                  'description': clonedDeck.description,
                  'created_at': DateTime.now().toIso8601String(),
                };

                existingList
                  ..removeWhere((d) => d is Map && d['id'] == clonedDeck.id)
                  ..insert(0, deckMap);

                await storage.savePreference(
                  key: PrefKeys.persistedUserDecks,
                  data: jsonEncode(existingList),
                );
              }
            } on Object catch (_) {}

            if (locator.isRegistered<DecksBloc>()) {
              locator<DecksBloc>().add(const DecksRefreshed());
            }
            if (locator.isRegistered<DashboardBloc>()) {
              locator<DashboardBloc>().add(const DashboardRefreshed());
            }

            if (!context.mounted) return;
            try {
              context.read<DecksBloc>().add(const DecksRefreshed());
            } on Object catch (_) {}
            try {
              context.read<DashboardBloc>().add(const DashboardRefreshed());
            } on Object catch (_) {}

            context.showSnackBar(
              message: l10n.marketplaceCloneSuccess,
            );
          },
        );
      } on Object catch (_) {
        isCloning.value = false;
        if (!context.mounted) return;
        context.showSnackBar(
          message: l10n.marketplaceCloneFailed,
          type: SnackBarType.error,
        );
      }
    }

    return Scaffold(
      backgroundColor: isDark
          ? colors.backgroundPrimary
          : colors.surfacePrimary,
      appBar: AppBar(
        backgroundColor: colors.transparent,
        elevation: 0,
        title: Text(
          deck.title,
          style: typography.title3.bold.copyWith(
            color: colors.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: colors.textPrimary,
          ),
          onPressed: () => unawaited(context.router.maybePop()),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: ShrinkableButton(
            onTap: isCloning.value ? null : handleClone,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colors.primary,
                    colors.primary.withAlpha(220),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: isCloning.value
                    ? AppLogoLoader(
                        size: 20,
                        color: colors.white,
                        showMessage: false,
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.copy_rounded,
                            color: colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.cloneDeckButton,
                            style: typography.body.bold.copyWith(
                              color: colors.white,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Deck Banner info
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colors.primary.withAlpha(isDark ? 50 : 25),
                      colors.syllabotAccent.withAlpha(isDark ? 40 : 20),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: colors.primary.withAlpha(isDark ? 60 : 35),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: colors.primary.withAlpha(40),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                deck.category.toUpperCase(),
                                style: typography.caption.bold.copyWith(
                                  color: colors.primary,
                                ),
                              ),
                            ),
                            if (deck.syllabusTag.isNotEmpty && deck.syllabusTag != 'General') ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.syllabotAccent.withAlpha(35),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: colors.syllabotAccent.withAlpha(70),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('📚', style: TextStyle(fontSize: 10)),
                                    const SizedBox(width: 4),
                                    Text(
                                      deck.syllabusTag,
                                      style: typography.caption.bold.copyWith(
                                        color: colors.syllabotAccent,
                                        fontSize: 10.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        Row(
                          children: [
                            Icon(
                              Icons.star_rounded,
                              size: 18,
                              color: colors.warning,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              deck.rating.toStringAsFixed(1),
                              style: typography.caption.bold.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      deck.title,
                      style: typography.title2.bold.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${deck.subject} • Created by ${deck.ownerName}',
                      style: typography.footnote.regular.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: colors.syllabotAccent.withAlpha(isDark ? 30 : 18),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: colors.syllabotAccent.withAlpha(50)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('✨', style: TextStyle(fontSize: 12)),
                          const SizedBox(width: 6),
                          Text(
                            'Cloning awards +25 XP to ${deck.ownerName}',
                            style: typography.caption.bold.copyWith(
                              color: colors.syllabotAccent,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (deck.description != null &&
                        deck.description!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        deck.description!,
                        style: typography.footnote.regular.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Cards Preview Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Interactive Card Preview (${deck.totalCards})',
                    style: typography.footnote.bold.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  Text(
                    '${deck.downloadsCount} clones',
                    style: typography.caption.medium.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Interactive Flashcard Preview Carousel (Tap-to-flip first 3-5 cards)
              _InteractiveCardPreviewCarousel(
                cards: deck.cards,
                totalCards: deck.totalCards,
                subject: deck.subject,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InteractiveCardPreviewCarousel extends HookWidget {
  const _InteractiveCardPreviewCarousel({
    required this.cards,
    required this.totalCards,
    required this.subject,
  });

  final List<FlashcardEntity> cards;
  final int totalCards;
  final String subject;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final displayCards = cards.isNotEmpty
        ? cards.take(5).toList()
        : [
            FlashcardEntity(
              id: 'preview_1',
              deckId: 'preview',
              front: 'Key concept: Essential foundations in $subject',
              back: 'Comprehensive revision breakdown with memory aids and formulas.',
            ),
            FlashcardEntity(
              id: 'preview_2',
              deckId: 'preview',
              front: 'High-yield exam application in $subject',
              back: 'Step-by-step problem resolution for top test scores.',
            ),
          ];

    final pageController = usePageController(viewportFraction: 0.92);
    final currentPage = useState<int>(0);
    final isFlipped = useState<bool>(false);

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PageView.builder(
            controller: pageController,
            itemCount: displayCards.length,
            onPageChanged: (idx) {
              currentPage.value = idx;
              isFlipped.value = false;
            },
            itemBuilder: (context, index) {
              final card = displayCards[index];
              final showingBack = isFlipped.value;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ShrinkableButton(
                  onTap: () {
                    unawaited(HapticFeedback.selectionClick());
                    isFlipped.value = !isFlipped.value;
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: showingBack
                          ? colors.primary.withAlpha(isDark ? 45 : 25)
                          : (isDark ? colors.surfaceSecondary : colors.surfacePrimary),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: showingBack
                            ? colors.primary
                            : colors.primary.withAlpha(isDark ? 50 : 25),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colors.black.withAlpha(isDark ? 40 : 20),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: (showingBack ? colors.primary : colors.textSecondary)
                                    .withAlpha(30),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                showingBack ? 'ANSWER (FLIPPED)' : 'QUESTION (TAP TO FLIP)',
                                style: typography.caption.bold.copyWith(
                                  fontSize: 9.5,
                                  color: showingBack ? colors.primary : colors.textSecondary,
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                Icon(
                                  Icons.touch_app_rounded,
                                  size: 13,
                                  color: colors.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Card ${index + 1} of ${displayCards.length}',
                                  style: typography.caption.regular.copyWith(
                                    fontSize: 10.5,
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          showingBack ? card.back : card.front,
                          style: typography.footnote.bold.copyWith(
                            color: colors.textPrimary,
                            fontSize: 14,
                            height: 1.4,
                          ),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        // Dots Indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(displayCards.length, (idx) {
            final isSelected = currentPage.value == idx;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: isSelected ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: isSelected ? colors.primary : colors.primary.withAlpha(50),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }
}
