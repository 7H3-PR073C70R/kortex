import 'dart:async';
import 'dart:ui';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';
import 'package:kortex/src/features/decks/domain/use_cases/get_deck_cards_use_case.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/export/presentation/widgets/export_deck_modal_sheet.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_app_bar.dart';
import 'package:kortex/src/shared/widgets/app_breadcrumbs.dart';
import 'package:kortex/src/shared/widgets/app_logo_loader.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

@RoutePage()
class DeckDetailPage extends StatelessWidget {
  const DeckDetailPage({
    @PathParam('deckId') required this.deckId,
    this.onClose,
    super.key,
  });

  final String deckId;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DecksBloc>.value(
      value: locator<DecksBloc>(),
      child: _DeckDetailContent(deckId: deckId, onClose: onClose),
    );
  }
}

class _DeckDetailContent extends HookWidget {
  const _DeckDetailContent({
    required this.deckId,
    this.onClose,
  });

  final String deckId;
  final VoidCallback? onClose;

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
      if (locator.isRegistered<GetDeckCardsUseCase>()) {
        isLoadingCards.value = true;
        errorMessage.value = null;
        unawaited(
          locator<GetDeckCardsUseCase>()(deckId).then((res) {
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

    final dynamicCards = loadedCards.value
        .map((c) => (front: c.front, back: c.back))
        .toList();

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
                  ? const Center(
                      child: AppLogoLoader(size: 56),
                    )
                  : errorMessage.value != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.cloud_off_rounded,
                            size: 56,
                            color: colors.textMuted.withAlpha(140),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Unable to Load Cards',
                            style: typography.callout.bold.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            errorMessage.value!,
                            textAlign: TextAlign.center,
                            style: typography.footnote.regular.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ShrinkableButton(
                            onTap: fetchCards,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: colors.primary,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.badge),
                              ),
                              child: Text(
                                'Retry',
                                style: typography.caption.bold.copyWith(
                                  color: colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : dynamicCards.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.style_outlined,
                            size: 56,
                            color: colors.textMuted.withAlpha(120),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No Flashcards Found',
                            style: typography.callout.bold.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'This deck does not have any active cards yet.',
                            textAlign: TextAlign.center,
                            style: typography.footnote.regular.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ShrinkableButton(
                            onTap: fetchCards,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: colors.surfaceSecondary,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.badge),
                                border: Border.all(
                                  color: colors.surfaceBorder,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.refresh_rounded,
                                    size: 14,
                                    color: colors.textPrimary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Refresh Cards',
                                    style: typography.caption.bold.copyWith(
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        // Progress Tracker
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l10n.deckDetailCardProgress(
                                currentCardIndex.value + 1,
                                dynamicCards.length,
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
                          child: Semantics(
                            button: true,
                            label: isFlipped.value
                                ? dynamicCards[currentCardIndex.value].back
                                : dynamicCards[currentCardIndex.value].front,
                            child: PlatformHoverBuilder(
                              builder: (context, isHovered, child) {
                                return InkWell(
                                  onTap: () {
                                    unawaited(HapticFeedback.lightImpact());
                                    isFlipped.value = !isFlipped.value;
                                  },
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.dialog,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.dialog,
                                    ),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(
                                        sigmaX: 16,
                                        sigmaY: 16,
                                      ),
                                      child: AnimatedContainer(
                                        duration: AppMotion.snappy,
                                        curve: AppMotion.easeOutCubic,
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(28),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? colors.surfaceSecondary
                                                    .withAlpha(200)
                                              : colors.surfacePrimary.withAlpha(
                                                  220,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            AppRadius.dialog,
                                          ),
                                          border: Border.all(
                                            color: isFlipped.value
                                                ? colors.success.withAlpha(
                                                    isDark ? 90 : 50,
                                                  )
                                                : isHovered
                                                ? colors.primary.withAlpha(
                                                    isDark ? 140 : 80,
                                                  )
                                                : colors.primary.withAlpha(
                                                    isDark ? 80 : 40,
                                                  ),
                                            width: 1.5,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: colors.black.withAlpha(
                                                isDark ? 50 : 20,
                                              ),
                                              blurRadius: 20,
                                              offset: const Offset(0, 8),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: isFlipped.value
                                                    ? colors.success.withAlpha(
                                                        isDark ? 50 : 25,
                                                      )
                                                    : colors.primary.withAlpha(
                                                        isDark ? 50 : 25,
                                                      ),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      AppRadius.micro,
                                                    ),
                                              ),
                                              child: Text(
                                                isFlipped.value
                                                    ? l10n.deckDetailAnswerFormula
                                                    : l10n.deckDetailQuestion,
                                                style: typography.caption.bold
                                                    .copyWith(
                                                      color: isFlipped.value
                                                          ? colors.success
                                                          : colors.primary,
                                                      fontSize: 11,
                                                      letterSpacing: 0.8,
                                                    ),
                                              ),
                                            ),
                                            const SizedBox(height: 24),
                                            Text(
                                              isFlipped.value
                                                  ? dynamicCards[currentCardIndex
                                                            .value]
                                                        .back
                                                  : dynamicCards[currentCardIndex
                                                            .value]
                                                        .front,
                                              textAlign: TextAlign.center,
                                              style: typography.title2.bold
                                                  .copyWith(
                                                    color: colors.textPrimary,
                                                    fontSize: 19,
                                                    height: 1.4,
                                                  ),
                                            ),
                                            const SizedBox(height: 24),
                                            Text(
                                              l10n.deckDetailTapToFlip,
                                              style: typography.footnote.regular
                                                  .copyWith(
                                                    color: colors.textMuted,
                                                    fontSize: 12,
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
                                    child: _FsrsRatingButton(
                                      label: l10n.deckDetailHard,
                                      interval: '1d',
                                      color: colors.error,
                                      icon: Icons.bolt_rounded,
                                      onTap: () {
                                        if (currentCardIndex.value <
                                            dynamicCards.length - 1) {
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
                                    child: _FsrsRatingButton(
                                      label: l10n.deckDetailGood,
                                      interval: '3d',
                                      color: colors.primary,
                                      icon: Icons.thumb_up_rounded,
                                      onTap: () {
                                        if (currentCardIndex.value <
                                            dynamicCards.length - 1) {
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
                                    child: _FsrsRatingButton(
                                      label: l10n.deckDetailEasy,
                                      interval: '7d',
                                      color: colors.success,
                                      icon: Icons.rocket_launch_rounded,
                                      onTap: () {
                                        if (currentCardIndex.value <
                                            dynamicCards.length - 1) {
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

class _FsrsRatingButton extends StatelessWidget {
  const _FsrsRatingButton({
    required this.label,
    required this.interval,
    required this.color,
    required this.onTap,
    this.icon,
  });

  final String label;
  final String interval;
  final Color color;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final isDesktop = MediaQuery.of(context).size.width >= 768;

    return Semantics(
      button: true,
      label: '$label, $interval',
      child: PlatformHoverBuilder(
        builder: (context, isHovered, child) {
          return ShrinkableButton(
            onTap: () {
              unawaited(HapticFeedback.lightImpact());
              onTap();
            },
            child: AnimatedContainer(
              duration: AppMotion.snappy,
              curve: AppMotion.easeOutCubic,
              padding: EdgeInsets.symmetric(
                vertical: isDesktop ? 14 : 10,
                horizontal: isDesktop ? 16 : 10,
              ),
              decoration: BoxDecoration(
                color: isHovered
                    ? color.withAlpha(isDark ? 65 : 45)
                    : color.withAlpha(isDark ? 38 : 24),
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(
                  color: isHovered
                      ? color.withAlpha(200)
                      : color.withAlpha(isDark ? 120 : 85),
                  width: isHovered ? 1.5 : 1.2,
                ),
                boxShadow: isHovered
                    ? [
                        BoxShadow(
                          color: color.withAlpha(isDark ? 70 : 35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : null,
              ),
              child: isDesktop
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, color: color, size: 20),
                          const SizedBox(width: 8),
                        ],
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: typography.body.bold.copyWith(
                                color: color,
                                fontSize: 14.5,
                              ),
                            ),
                            Text(
                              interval,
                              style: typography.caption.bold.copyWith(
                                color: color.withAlpha(210),
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, color: color, size: 18),
                          const SizedBox(height: 4),
                        ],
                        Text(
                          label,
                          style: typography.caption.bold.copyWith(
                            color: color,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: color.withAlpha(isDark ? 55 : 35),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            interval,
                            style: typography.caption.bold.copyWith(
                              color: isDark ? Colors.white : color,
                              fontSize: 10.5,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }
}
