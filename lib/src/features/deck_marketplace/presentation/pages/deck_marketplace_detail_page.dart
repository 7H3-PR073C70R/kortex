import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/utils/app_logger.dart';
import 'package:kortex/src/features/deck_marketplace/domain/entities/shared_deck_entity.dart';
import 'package:kortex/src/features/deck_marketplace/presentation/widgets/detail/deck_marketplace_detail_coordinator.dart';
import 'package:kortex/src/features/deck_marketplace/presentation/widgets/detail/deck_marketplace_detail_layouts.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_app_bar.dart';
import 'package:kortex/src/shared/widgets/app_breadcrumbs.dart';
import 'package:kortex/src/shared/widgets/app_logo_loader.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

// Grid breakpoint — mirrors the one used in study_hub_page.dart.
const double _kDetailGridBreakpoint = 600;

@RoutePage()
class DeckMarketplaceDetailPage extends HookWidget {
  const DeckMarketplaceDetailPage({
    required this.deck,
    this.onClosePanel,
    this.coordinator,
    super.key,
  });

  final SharedDeckEntity deck;
  final VoidCallback? onClosePanel;
  final DeckMarketplaceDetailCoordinator? coordinator;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final effectiveCoordinator =
        coordinator ?? DeckMarketplaceDetailCoordinator();

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = screenWidth >= _kDetailGridBreakpoint;

    final isCloning = useState<bool>(false);
    final currentRating = useState<double>(deck.rating);
    final userRating = useState<int?>(null);
    final isDeleting = useState<bool>(false);

    final isOwner = effectiveCoordinator.isOwner(deck);
    final decksState = context.watch<DecksBloc?>()?.state;
    final userDecks =
        effectiveCoordinator.getUserDecks(decksState?.allDecks);
    final isAlreadyCloned = effectiveCoordinator.isAlreadyCloned(
      deck,
      userDecks: userDecks,
    );

    Future<void> handleRate(int rating) async {
      if (isOwner) return;
      if (!isAlreadyCloned) {
        context.showSnackBar(
          message: 'Please clone this deck to your library before rating it.',
        );
        return;
      }
      userRating.value = rating;
      try {
        final res = await effectiveCoordinator.rateDeck(
          sharedDeckId: deck.id,
          rating: rating.toDouble(),
        );
        if (!context.mounted || res == null) return;
        res.fold(
          (failure) {
            context.showSnackBar(
              message: failure.message ?? 'Failed to submit rating.',
              type: SnackBarType.error,
            );
          },
          (newRating) {
            currentRating.value = newRating;
            context.showSnackBar(
              message: 'Thank you! Rating submitted ($rating ★).',
            );
          },
        );
      } on Object catch (e, st) {
        AppLogger.recordNonFatal(e, st);
      }
    }

    Future<void> handleDelete() async {
      if (!isOwner) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusDialog),
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: ctx.colors.error,
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text('Delete from Marketplace?'),
            ],
          ),
          content: const Text(
            'Are you sure you want to remove this deck from the marketplace? '
            'Existing clones in users libraries will not be deleted, '
            'but new users will no longer be able to discover or clone it.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: ctx.colors.error,
                foregroundColor: ctx.colors.white,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete Deck'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      isDeleting.value = true;
      try {
        final res = await effectiveCoordinator.deleteDeck(deck.id);
        isDeleting.value = false;

        if (!context.mounted || res == null) return;
        res.fold(
          (failure) {
            context.showSnackBar(
              message:
                  failure.message ?? 'Failed to delete deck from marketplace.',
              type: SnackBarType.error,
            );
          },
          (success) {
            context.showSnackBar(
              message: 'Deck removed from marketplace.',
            );
            if (onClosePanel != null) {
              onClosePanel!();
            } else if (context.router.canPop()) {
              context.router.pop();
            }
          },
        );
      } on Object catch (_) {
        isDeleting.value = false;
      }
    }

    Future<void> handleClone() async {
      if (isAlreadyCloned) {
        context.showSnackBar(
          message: 'This deck is already in your deck list.',
        );
        return;
      }
      isCloning.value = true;
      try {
        final res = await effectiveCoordinator.cloneDeck(deck.id);
        isCloning.value = false;

        if (!context.mounted || res == null) return;
        res.fold(
          (failure) {
            if (!context.mounted) return;
            context.showSnackBar(
              message: failure.message ?? l10n.marketplaceCloneFailed,
              type: SnackBarType.error,
            );
          },
          (clonedDeck) {
            context.showSnackBar(message: l10n.marketplaceCloneSuccess);
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

    // ── Bottom CTA bar ────────────────────────────────────────────────────────
    final bottomBar = SafeArea(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: isAlreadyCloned
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: colors.recallEasy.withAlpha(isDark ? 40 : 25),
                    borderRadius: AppRadius.radiusPanel,
                    border: Border.all(
                      color: colors.recallEasy.withAlpha(isDark ? 100 : 70),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: colors.recallEasy,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Deck in Library',
                        style: typography.body.bold.copyWith(
                          color: colors.recallEasy,
                        ),
                      ),
                    ],
                  ),
                )
              : PlatformHoverBuilder(
                  builder: (context, isHovered, child) => AnimatedScale(
                    scale: isHovered ? 1.01 : 1,
                    duration: AppMotion.snappy,
                    curve: AppMotion.easeOutCubic,
                    child: ShrinkableButton(
                      onTap: isCloning.value ? null : handleClone,
                      child: AnimatedContainer(
                        duration: AppMotion.snappy,
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isCloning.value
                                ? [
                                    colors.primary.withAlpha(160),
                                    colors.primary.withAlpha(130),
                                  ]
                                : [
                                    colors.primary,
                                    colors.primary.withAlpha(220),
                                  ],
                          ),
                          borderRadius: AppRadius.radiusPanel,
                          boxShadow: [
                            BoxShadow(
                              color: colors.primary.withAlpha(
                                isHovered ? 80 : 40,
                              ),
                              blurRadius: isHovered ? 20 : 12,
                              offset: Offset(0, isHovered ? 6 : 3),
                            ),
                          ],
                        ),
                        child: AnimatedSwitcher(
                          duration: AppMotion.snappy,
                          child: isCloning.value
                              ? AppLogoLoader(
                                  key: const ValueKey('cloning_loader'),
                                  size: 20,
                                  color: colors.white,
                                  showMessage: false,
                                )
                              : Row(
                                  key: const ValueKey('cloning_action'),
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
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
        ),
      ),
    );

    return Scaffold(
      backgroundColor: isDark
          ? colors.backgroundPrimary
          : colors.surfacePrimary,
      appBar: AppAdaptiveAppBar(
        breadcrumbs: [
          AppBreadcrumbItem(
            label: 'Marketplace',
            onTap: () {
              if (context.router.canPop()) {
                context.router.pop();
              }
            },
          ),
          AppBreadcrumbItem(
            label: deck.title,
          ),
        ],
        title: Text(
          deck.title,
          style: typography.title3.bold.copyWith(
            color: colors.textPrimary,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // Rating pill in AppBar for quick at-a-glance info
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star_rounded, size: 16, color: colors.warning),
                const SizedBox(width: 3),
                Text(
                  currentRating.value.toStringAsFixed(1),
                  style: typography.caption.bold.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (isOwner) ...[
            IconButton(
              icon: Icon(
                Icons.delete_outline_rounded,
                size: 20,
                color: colors.error,
              ),
              tooltip: 'Delete Deck from Marketplace',
              onPressed: isDeleting.value ? null : handleDelete,
            ),
            const SizedBox(width: 4),
          ],
          if (onClosePanel != null) ...[
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              tooltip: 'Close Deck Detail (Esc)',
              onPressed: onClosePanel,
            ),
            const SizedBox(width: 4),
          ],
        ],
      ),
      bottomNavigationBar: isWide ? null : bottomBar,
      body: Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: isWide
                ? DeckMarketplaceWideDetailLayout(
                    deck: deck,
                    isDark: isDark,
                    isOwner: isOwner,
                    currentRating: currentRating.value,
                    userRating: userRating.value,
                    onRate: handleRate,
                    isDeleting: isDeleting.value,
                    onDelete: handleDelete,
                    isCloning: isCloning.value,
                    isAlreadyCloned: isAlreadyCloned,
                    onClone: handleClone,
                  )
                : DeckMarketplaceCompactDetailLayout(
                    deck: deck,
                    isDark: isDark,
                    isOwner: isOwner,
                    isAlreadyCloned: isAlreadyCloned,
                    currentRating: currentRating.value,
                    userRating: userRating.value,
                    onRate: handleRate,
                    isDeleting: isDeleting.value,
                    onDelete: handleDelete,
                  ),
          ),
        ),
      ),
    );
  }
}
