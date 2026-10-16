import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/deck_detail/deck_detail_states.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/deck_detail/flashcard_surface.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/deck_detail/fsrs_rating_button.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';
import 'package:kortex/src/features/decks/domain/use_cases/get_deck_cards_use_case.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/export/presentation/widgets/export_deck_modal_sheet.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_app_bar.dart';
import 'package:kortex/src/shared/widgets/app_breadcrumbs.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

DecksBloc _resolveDecksBloc(BuildContext context) =>
    context.read<DecksBloc?>() ??
    (locator.isRegistered<DecksBloc>() ? locator<DecksBloc>() : null) ??
    locator<DecksBloc>();

GetDeckCardsUseCase? _resolveGetDeckCardsUseCase(BuildContext context) =>
    context.read<GetDeckCardsUseCase?>() ??
    (locator.isRegistered<GetDeckCardsUseCase>()
        ? locator<GetDeckCardsUseCase>()
        : null);

@RoutePage()
class DeckDetailPage extends StatelessWidget {
  const DeckDetailPage({
    @PathParam('deckId') required this.deckId,
    this.onClose,
    this.decksBloc,
    this.getDeckCardsUseCase,
    super.key,
  });

  final String deckId;
  final VoidCallback? onClose;
  final DecksBloc? decksBloc;
  final GetDeckCardsUseCase? getDeckCardsUseCase;

  @override
  Widget build(BuildContext context) {
    final bloc = decksBloc ?? _resolveDecksBloc(context);
    return BlocProvider<DecksBloc>.value(
      value: bloc,
      child: _DeckDetailContent(
        deckId: deckId,
        onClose: onClose,
        getDeckCardsUseCase: getDeckCardsUseCase,
      ),
    );
  }
}

class _DeckDetailContent extends HookWidget {
  const _DeckDetailContent({
    required this.deckId,
    this.onClose,
    this.getDeckCardsUseCase,
  });

  final String deckId;
  final VoidCallback? onClose;
  final GetDeckCardsUseCase? getDeckCardsUseCase;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final currentCardIndex = useState<int>(0);

    final allDecks = context.watch<DecksBloc>().state.allDecks;
    DeckEntity? deck;
    for (final d in allDecks) {
      if (d.id == deckId) {
        deck = d;
        break;
      }
    }

    final loadedCards = useState<List<FlashcardEntity>>(deck?.cards ?? []);
    final isLoadingCards = useState<bool>(false);
    final errorMessage = useState<String?>(null);

    void fetchCards() {
      final useCase =
          getDeckCardsUseCase ?? _resolveGetDeckCardsUseCase(context);
      if (useCase != null) {
        isLoadingCards.value = true;
        errorMessage.value = null;
        unawaited(
          useCase(deckId).then((res) {
            res.fold(
              (failure) {
                errorMessage.value = failure.message;
              },
              (cards) {
                loadedCards.value = cards;
              },
            );
            isLoadingCards.value = false;
          }),
        );
      }
    }

    useEffect(() {
      if (deck != null && deck.cards.isNotEmpty) {
        loadedCards.value = deck.cards;
      } else {
        fetchCards();
      }
      return null;
    }, [deckId, deck?.cards]);

    final isFlipped = useState<bool>(false);

    return Scaffold(
      backgroundColor: isDark
          ? colors.backgroundPrimary
          : colors.surfacePrimary,
      appBar: AppAdaptiveAppBar(
        breadcrumbs: [
          AppBreadcrumbItem(
            label: l10n.navTabDecks,
            onTap: () {
              if (context.router.canPop()) {
                context.router.pop();
              }
            },
          ),
          AppBreadcrumbItem(
            label: deck?.title ?? l10n.deckDetailTitle,
          ),
        ],
        title: Text(
          deck?.title ?? l10n.deckDetailTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: typography.title3.bold.copyWith(color: colors.textPrimary),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.ios_share_rounded, color: colors.textPrimary),
            tooltip: 'Export Deck',
            onPressed: () {
              final populatedDeck =
                  (deck ??
                          DeckEntity(
                            id: deckId,
                            title: 'Study Deck',
                            subject: 'Review',
                            totalCards: loadedCards.value.length,
                            dueCards: loadedCards.value.length,
                            masteryRate: 0,
                            category: 'General',
                            cards: loadedCards.value,
                          ))
                      .copyWith(cards: loadedCards.value);
              unawaited(
                ExportDeckModalSheet.show(context, deck: populatedDeck),
              );
            },
          ),
          Padding(
            padding: EdgeInsets.only(right: onClose != null ? 6 : 12),
            child: ShrinkableButton(
              onTap: () {
                unawaited(HapticFeedback.lightImpact());
                unawaited(
                  context.router.push(StudySessionRoute(deckId: deckId)),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(AppRadius.badge),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.play_arrow_rounded,
                      size: 16,
                      color: colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Study',
                      style: typography.caption.bold.copyWith(
                        color: colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (onClose != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: PlatformHoverBuilder(
                builder: (context, isHovered, child) {
                  return IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: isHovered ? colors.primary : colors.textPrimary,
                      size: 20,
                    ),
                    tooltip: 'Close Deck Details (Esc)',
                    onPressed: onClose,
                  );
                },
              ),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: isLoadingCards.value
                  ? const DeckDetailLoadingState()
                  : errorMessage.value != null
                  ? DeckDetailErrorState(
                      errorMessage: errorMessage.value!,
                      onRetry: fetchCards,
                    )
                  : loadedCards.value.isEmpty
                  ? DeckDetailEmptyState(onRefresh: fetchCards)
                  : Column(
                      children: [
                        // Progress Tracker
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l10n.deckDetailCardProgress(
                                currentCardIndex.value + 1,
                                loadedCards.value.length,
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
                                color: colors.primary.withAlpha(
                                  isDark ? 50 : 25,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.badge,
                                ),
                              ),
                              child: Text(
                                'ACTIVE REVIEW QUEUE',
                                style: typography.caption.bold.copyWith(
                                  color: colors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Flashcard Surface
                        Expanded(
                          child: FlashcardSurface(
                            isFlipped: isFlipped.value,
                            card: loadedCards.value[currentCardIndex.value],
                            onFlip: () {
                              isFlipped.value = !isFlipped.value;
                            },
                          ),
                        ),
                        const SizedBox(height: 20),

                        // FSRS-6 Rating Buttons (Hard / Good / Easy)
                        if (isFlipped.value) ...[
                          Center(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width >= 768
                                    ? 680
                                    : double.infinity,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: FsrsRatingButton(
                                      label: l10n.deckDetailHard,
                                      interval: '1d',
                                      color: colors.error,
                                      icon: Icons.bolt_rounded,
                                      onTap: () {
                                        if (currentCardIndex.value <
                                            loadedCards.value.length - 1) {
                                          currentCardIndex.value++;
                                          isFlipped.value = false;
                                        } else {
                                          unawaited(context.router.maybePop());
                                        }
                                      },
                                    ),
                                  ),
                                  SizedBox(
                                    width: MediaQuery.of(context).size.width >= 768
                                        ? 16
                                        : 10,
                                  ),
                                  Expanded(
                                    child: FsrsRatingButton(
                                      label: l10n.deckDetailGood,
                                      interval: '3d',
                                      color: colors.primary,
                                      icon: Icons.thumb_up_rounded,
                                      onTap: () {
                                        if (currentCardIndex.value <
                                            loadedCards.value.length - 1) {
                                          currentCardIndex.value++;
                                          isFlipped.value = false;
                                        } else {
                                          unawaited(context.router.maybePop());
                                        }
                                      },
                                    ),
                                  ),
                                  SizedBox(
                                    width: MediaQuery.of(context).size.width >= 768
                                        ? 16
                                        : 10,
                                  ),
                                  Expanded(
                                    child: FsrsRatingButton(
                                      label: l10n.deckDetailEasy,
                                      interval: '7d',
                                      color: colors.success,
                                      icon: Icons.rocket_launch_rounded,
                                      onTap: () {
                                        if (currentCardIndex.value <
                                            loadedCards.value.length - 1) {
                                          currentCardIndex.value++;
                                          isFlipped.value = false;
                                        } else {
                                          unawaited(context.router.maybePop());
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
