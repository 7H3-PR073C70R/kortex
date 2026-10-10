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
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_event.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_hub_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:kortex/src/features/deck_marketplace/domain/entities/shared_deck_entity.dart';
import 'package:kortex/src/features/deck_marketplace/domain/services/deck_cloned_checker.dart';
import 'package:kortex/src/features/deck_marketplace/domain/use_cases/clone_shared_deck_use_case.dart';
import 'package:kortex/src/features/deck_marketplace/domain/use_cases/delete_shared_deck_use_case.dart';
import 'package:kortex/src/features/deck_marketplace/domain/use_cases/rate_shared_deck_use_case.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_event.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/latex_rich_viewer.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_app_bar.dart';
import 'package:kortex/src/shared/widgets/app_avatar.dart';
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
    super.key,
  });

  final SharedDeckEntity deck;
  final VoidCallback? onClosePanel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = screenWidth >= _kDetailGridBreakpoint;

    final isCloning = useState<bool>(false);
    final currentRating = useState<double>(deck.rating);
    final userRating = useState<int?>(null);
    final isDeleting = useState<bool>(false);

    final currentUserId = locator.isRegistered<UserStorageService>()
        ? locator<UserStorageService>().getUserId()
        : null;
    final isOwner = currentUserId != null && currentUserId == deck.ownerId;

    final decksState = context.watch<DecksBloc?>()?.state;
    final userDecks = decksState?.allDecks ??
        (locator.isRegistered<DecksBloc>()
            ? locator<DecksBloc>().state.allDecks
            : const <DeckEntity>[]);
    final isAlreadyCloned = isDeckAlreadyCloned(deck, userDecks: userDecks);

    Future<void> handleRate(int rating) async {
      if (isOwner) return;
      userRating.value = rating;
      try {
        final useCase = locator<RateSharedDeckUseCase>();
        final res = await useCase(
          sharedDeckId: deck.id,
          rating: rating.toDouble(),
        );
        if (!context.mounted) return;
        res.fold(
          (failure) {
            context.showSnackBar(
              message: failure.message ?? 'Failed to submit rating.',
              type: SnackBarType.error,
            );
          },
          (success) {
            if (locator.isRegistered<CommunityHubBloc>()) {
              locator<CommunityHubBloc>().add(
                RateSharedDeckEvent(
                  sharedDeckId: deck.id,
                  rating: rating.toDouble(),
                ),
              );
            }
            context.showSnackBar(
              message: 'Thank you! Rating submitted ($rating ★).',
            );
          },
        );
      } on Object catch (_) {}
    }

    Future<void> handleDelete() async {
      if (!isOwner) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusDialog),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: ctx.colors.error, size: 24),
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
        final useCase = locator<DeleteSharedDeckUseCase>();
        final res = await useCase(deck.id);
        isDeleting.value = false;

        if (!context.mounted) return;
        res.fold(
          (failure) {
            context.showSnackBar(
              message: failure.message ?? 'Failed to delete deck from marketplace.',
              type: SnackBarType.error,
            );
          },
          (success) {
            if (locator.isRegistered<CommunityHubBloc>()) {
              locator<CommunityHubBloc>().add(DeleteSharedDeckEvent(deck.id));
            }
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
        final useCase = locator<CloneSharedDeckUseCase>();
        final res = await useCase(deck.id);
        isCloning.value = false;

        if (!context.mounted) return;
        await res.fold(
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
                final raw = storage.getPreference(
                  key: PrefKeys.persistedUserDecks,
                );
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
              icon: Icon(Icons.delete_outline_rounded, size: 20, color: colors.error),
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
                ? _WideDetailLayout(
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
                : _CompactDetailLayout(
                    deck: deck,
                    isDark: isDark,
                    isOwner: isOwner,
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

// ── Compact layout (phones / portrait) ────────────────────────────────────────

class _CompactDetailLayout extends StatelessWidget {
  const _CompactDetailLayout({
    required this.deck,
    required this.isDark,
    required this.isOwner,
    required this.currentRating,
    required this.userRating,
    required this.onRate,
    required this.isDeleting,
    required this.onDelete,
  });

  final SharedDeckEntity deck;
  final bool isDark;
  final bool isOwner;
  final double currentRating;
  final int? userRating;
  final ValueChanged<int> onRate;
  final bool isDeleting;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DeckInfoPanel(deck: deck, isDark: isDark),
        const SizedBox(height: 16),
        _StatsRow(deck: deck, rating: currentRating),
        const SizedBox(height: 16),
        _DeckRatingSection(
          deck: deck,
          isOwner: isOwner,
          currentRating: currentRating,
          userRating: userRating,
          onRate: onRate,
        ),
        if (isOwner) ...[
          const SizedBox(height: 12),
          _OwnerDeleteButton(
            onDelete: onDelete,
            isDeleting: isDeleting,
          ),
        ],
        const SizedBox(height: 20),
        _CardPreviewSection(
          deck: deck,
          isDark: isDark,
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ── Wide layout (tablet / landscape / desktop) ────────────────────────────────

class _WideDetailLayout extends StatelessWidget {
  const _WideDetailLayout({
    required this.deck,
    required this.isDark,
    required this.isOwner,
    required this.currentRating,
    required this.userRating,
    required this.onRate,
    required this.isDeleting,
    required this.onDelete,
    required this.isCloning,
    required this.isAlreadyCloned,
    required this.onClone,
  });

  final SharedDeckEntity deck;
  final bool isDark;
  final bool isOwner;
  final double currentRating;
  final int? userRating;
  final ValueChanged<int> onRate;
  final bool isDeleting;
  final VoidCallback onDelete;
  final bool isCloning;
  final bool isAlreadyCloned;
  final VoidCallback onClone;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: deck info + stats + rating + primary CTA + owner actions
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DeckInfoPanel(deck: deck, isDark: isDark),
              const SizedBox(height: 16),
              _StatsRow(deck: deck, rating: currentRating),
              const SizedBox(height: 16),
              _DeckRatingSection(
                deck: deck,
                isOwner: isOwner,
                currentRating: currentRating,
                userRating: userRating,
                onRate: onRate,
              ),
              const SizedBox(height: 16),
              _InlineCloneButton(
                isCloning: isCloning,
                isAlreadyCloned: isAlreadyCloned,
                onClone: onClone,
              ),
              if (isOwner) ...[
                const SizedBox(height: 12),
                _OwnerDeleteButton(
                  onDelete: onDelete,
                  isDeleting: isDeleting,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 20),
        // Right: card preview panel + flashcards breakdown
        Expanded(
          flex: 5,
          child: _CardPreviewSection(deck: deck, isDark: isDark),
        ),
      ],
    );
  }
}

// ── Rating section ─────────────────────────────────────────────────────────────

class _DeckRatingSection extends StatelessWidget {
  const _DeckRatingSection({
    required this.deck,
    required this.isOwner,
    required this.currentRating,
    required this.userRating,
    required this.onRate,
  });

  final SharedDeckEntity deck;
  final bool isOwner;
  final double currentRating;
  final int? userRating;
  final ValueChanged<int> onRate;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    if (isOwner) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.primary.withAlpha(isDark ? 25 : 15),
          borderRadius: AppRadius.radiusCard,
          border: Border.all(
            color: colors.primary.withAlpha(isDark ? 40 : 25),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 20,
              color: colors.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Published by You',
                    style: typography.caption.bold.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Ratings are submitted by other community users. Distributors cannot rate their own decks.',
                    style: typography.caption.regular.copyWith(
                      color: colors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfaceSecondary.withAlpha(160)
            : colors.surfaceSecondary.withAlpha(120),
        borderRadius: AppRadius.radiusCard,
        border: Border.all(
          color: colors.primary.withAlpha(isDark ? 35 : 20),
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
                  Icon(
                    Icons.rate_review_outlined,
                    size: 16,
                    color: colors.warning,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    userRating != null ? 'Your Rating' : 'Rate this Deck',
                    style: typography.caption.bold.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
              Text(
                '${currentRating.toStringAsFixed(1)} ★ average',
                style: typography.caption.bold.copyWith(
                  color: colors.warning,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starValue = index + 1;
              final isFilled = (userRating != null && starValue <= userRating!) ||
                  (userRating == null && starValue <= currentRating.round());

              return IconButton(
                onPressed: () => onRate(starValue),
                iconSize: 28,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                constraints: const BoxConstraints(),
                icon: Icon(
                  isFilled ? Icons.star_rounded : Icons.star_border_rounded,
                  color: colors.warning,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ── Owner delete button ────────────────────────────────────────────────────────

class _OwnerDeleteButton extends StatelessWidget {
  const _OwnerDeleteButton({
    required this.onDelete,
    required this.isDeleting,
  });

  final VoidCallback onDelete;
  final bool isDeleting;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return PlatformHoverBuilder(
      builder: (context, isHovered, child) {
        return ShrinkableButton(
          onTap: isDeleting ? null : onDelete,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: colors.error.withAlpha(isHovered ? 35 : 20),
              borderRadius: AppRadius.radiusCard,
              border: Border.all(
                color: colors.error.withAlpha(isHovered ? 120 : 80),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isDeleting)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.error,
                    ),
                  )
                else ...[
                  Icon(
                    Icons.delete_outline_rounded,
                    size: 16,
                    color: colors.error,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Delete Deck from Marketplace',
                    style: typography.caption.bold.copyWith(
                      color: colors.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Deck info panel ───────────────────────────────────────────────────────────

// ── Deck info panel ───────────────────────────────────────────────────────────

class _DeckInfoPanel extends StatelessWidget {
  const _DeckInfoPanel({
    required this.deck,
    required this.isDark,
  });

  final SharedDeckEntity deck;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.primary.withAlpha(isDark ? 50 : 25),
            colors.syllabotAccent.withAlpha(isDark ? 40 : 18),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.radiusDialog,
        border: Border.all(
          color: colors.primary.withAlpha(isDark ? 60 : 35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge row — Wrap so it never overflows on small screens
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Category badge
              _Badge(
                label: deck.category.toUpperCase(),
                color: colors.primary,
                alpha: 40,
              ),
              // Verified vault badge
              _BadgeWithIcon(
                icon: Icons.verified_rounded,
                label: 'Verified Vault',
                color: colors.recallEasy,
                borderAlpha: 80,
                bgAlpha: 40,
              ),
              // Syllabus tag badge
              if (deck.syllabusTag.isNotEmpty &&
                  deck.syllabusTag != 'General')
                _EmojiTextBadge(
                  emoji: '📚',
                  label: deck.syllabusTag,
                  color: colors.syllabotAccent,
                  borderAlpha: 70,
                  bgAlpha: 35,
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            deck.title,
            style: typography.title2.bold.copyWith(
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),

          // Author row
          Row(
            children: [
              AppAvatar(
                customDimension: 22,
                name: deck.ownerName,
                backgroundColor: colors.primary.withAlpha(isDark ? 50 : 35),
                foregroundColor: colors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${deck.subject} • by ${deck.ownerName}',
                  style: typography.footnote.regular.copyWith(
                    color: colors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // XP incentive chip
          _EmojiTextBadge(
            emoji: '✨',
            label: 'Cloning awards +25 XP to ${deck.ownerName}',
            color: colors.syllabotAccent,
            bgAlpha: isDark ? 30 : 18,
          ),

          // Description
          if (deck.description != null && deck.description!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? colors.surfaceSecondary.withAlpha(120)
                    : colors.surfacePrimary.withAlpha(200),
                borderRadius: AppRadius.radiusCard,
                border: Border.all(
                  color: colors.primary.withAlpha(isDark ? 25 : 15),
                ),
              ),
              child: Text(
                deck.description!,
                style: typography.footnote.regular.copyWith(
                  color: colors.textSecondary,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Stats row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.deck,
    this.rating,
  });

  final SharedDeckEntity deck;
  final double? rating;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;
    final displayRating = rating ?? deck.rating;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfaceSecondary.withAlpha(160)
            : colors.surfaceSecondary.withAlpha(120),
        borderRadius: AppRadius.radiusCard,
        border: Border.all(
          color: colors.primary.withAlpha(isDark ? 30 : 18),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            icon: Icons.style_outlined,
            value: '${deck.totalCards}',
            label: 'Cards',
            color: colors.primary,
          ),
          _StatDivider(),
          _StatItem(
            icon: Icons.download_rounded,
            value: '${deck.downloadsCount}',
            label: 'Clones',
            color: colors.syllabotAccent,
          ),
          _StatDivider(),
          _StatItem(
            icon: Icons.star_rounded,
            value: displayRating.toStringAsFixed(1),
            label: 'Rating',
            color: colors.warning,
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final typography = context.typography;
    final colors = context.colors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: typography.subhead.bold.copyWith(color: colors.textPrimary),
        ),
        Text(
          label,
          style: typography.caption.regular.copyWith(
            color: colors.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: 1,
      height: 36,
      color: colors.surfaceBorder.withAlpha(context.isDarkMode ? 60 : 40),
    );
  }
}

// ── Inline clone button (wide layout) ─────────────────────────────────────────

class _InlineCloneButton extends StatelessWidget {
  const _InlineCloneButton({
    required this.isCloning,
    required this.isAlreadyCloned,
    required this.onClone,
  });

  final bool isCloning;
  final bool isAlreadyCloned;
  final VoidCallback onClone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    if (isAlreadyCloned) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: colors.recallEasy.withAlpha(isDark ? 40 : 25),
          borderRadius: AppRadius.radiusCard,
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
              size: 16,
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
      );
    }

    return PlatformHoverBuilder(
      builder: (context, isHovered, child) => AnimatedScale(
        scale: isHovered ? 1.01 : 1,
        duration: AppMotion.snappy,
        curve: AppMotion.easeOutCubic,
        child: ShrinkableButton(
          onTap: isCloning ? null : onClone,
          child: AnimatedContainer(
            duration: AppMotion.snappy,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isCloning
                    ? [
                        colors.primary.withAlpha(160),
                        colors.primary.withAlpha(130),
                      ]
                    : [
                        colors.primary,
                        colors.primary.withAlpha(220),
                      ],
              ),
              borderRadius: AppRadius.radiusCard,
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withAlpha(isHovered ? 80 : 40),
                  blurRadius: isHovered ? 16 : 8,
                  offset: Offset(0, isHovered ? 4 : 2),
                ),
              ],
            ),
            child: AnimatedSwitcher(
              duration: AppMotion.snappy,
              child: isCloning
                  ? AppLogoLoader(
                      key: const ValueKey('cloning_loader_inline'),
                      size: 18,
                      color: colors.white,
                      showMessage: false,
                    )
                  : Row(
                      key: const ValueKey('cloning_action_inline'),
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.copy_rounded,
                          color: colors.white,
                          size: 16,
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
    );
  }
}

// ── Card preview section ───────────────────────────────────────────────────────

class _CardPreviewSection extends StatelessWidget {
  const _CardPreviewSection({
    required this.deck,
    required this.isDark,
  });

  final SharedDeckEntity deck;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    final displayCards = deck.cards.isNotEmpty
        ? deck.cards.take(5).toList()
        : [
            FlashcardEntity(
              id: 'preview_1',
              deckId: 'preview',
              front: 'Key concept: Essential foundations in ${deck.subject}',
              back:
                  'Comprehensive revision breakdown with memory aids and formulas.',
            ),
            FlashcardEntity(
              id: 'preview_2',
              deckId: 'preview',
              front: 'High-yield exam application in ${deck.subject}',
              back: 'Step-by-step problem resolution for top test scores.',
            ),
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_stories_rounded,
                  size: 18,
                  color: colors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Card Preview',
                  style: typography.subhead.bold.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: colors.primary.withAlpha(isDark ? 40 : 20),
                borderRadius: AppRadius.radiusBadge,
              ),
              child: Text(
                '${deck.totalCards} cards total',
                style: typography.caption.bold.copyWith(
                  color: colors.primary,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Tap a card to flip between question and answer',
          style: typography.caption.regular.copyWith(
            color: colors.textSecondary,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 14),

        // The interactive carousel
        _InteractiveCardPreviewCarousel(
          cards: deck.cards,
          totalCards: deck.totalCards,
          subject: deck.subject,
          isDark: isDark,
        ),
        const SizedBox(height: 16),

        // Flashcards List Breakdown
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark
                ? colors.surfaceSecondary.withAlpha(140)
                : colors.surfacePrimary,
            borderRadius: AppRadius.radiusCard,
            border: Border.all(
              color: colors.primary.withAlpha(isDark ? 35 : 20),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.view_list_rounded,
                    size: 16,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Included Flashcards',
                    style: typography.caption.bold.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${deck.totalCards} items',
                    style: typography.caption.regular.copyWith(
                      color: colors.textSecondary,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: displayCards.length,
                separatorBuilder: (context, index) =>
                    Divider(height: 16, thickness: 0.5, color: colors.surfaceBorder.withAlpha(isDark ? 40 : 25)),
                itemBuilder: (context, index) {
                  final card = displayCards[index];
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary.withAlpha(isDark ? 35 : 20),
                          borderRadius: AppRadius.radiusMicro,
                        ),
                        child: Text(
                          '${index + 1}',
                          style: typography.caption.bold.copyWith(
                            fontSize: 10,
                            color: colors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LatexRichViewer(
                              text: card.front,
                              style: typography.caption.bold.copyWith(
                                color: colors.textPrimary,
                                fontSize: 12,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            LatexRichViewer(
                              text: card.back,
                              style: typography.caption.regular.copyWith(
                                color: colors.textSecondary,
                                fontSize: 11,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Interactive flashcard carousel ────────────────────────────────────────────

class _InteractiveCardPreviewCarousel extends HookWidget {
  const _InteractiveCardPreviewCarousel({
    required this.cards,
    required this.totalCards,
    required this.subject,
    required this.isDark,
  });

  final List<FlashcardEntity> cards;
  final int totalCards;
  final String subject;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    final displayCards = cards.isNotEmpty
        ? cards.take(5).toList()
        : [
            FlashcardEntity(
              id: 'preview_1',
              deckId: 'preview',
              front: 'Key concept: Essential foundations in $subject',
              back:
                  'Comprehensive revision breakdown with memory aids and formulas.',
            ),
            FlashcardEntity(
              id: 'preview_2',
              deckId: 'preview',
              front: 'High-yield exam application in $subject',
              back: 'Step-by-step problem resolution for top test scores.',
            ),
          ];

    final pageController = usePageController(viewportFraction: 0.94);
    final currentPage = useState<int>(0);
    final isFlipped = useState<bool>(false);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Fixed-height card carousel with overlay prev/next controls for desktop mouse navigation
        // and ClampingScrollPhysics to prevent browser back gesture overscroll.
        SizedBox(
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PageView.builder(
                controller: pageController,
                physics: const ClampingScrollPhysics(),
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
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: showingBack
                              ? colors.primary.withAlpha(isDark ? 50 : 28)
                              : (isDark
                                    ? colors.surfaceSecondary
                                    : colors.surfacePrimary),
                          borderRadius: AppRadius.radiusDialog,
                          border: Border.all(
                            color: showingBack
                                ? colors.primary
                                : colors.primary.withAlpha(isDark ? 55 : 30),
                            width: showingBack ? 1.5 : 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colors.black.withAlpha(isDark ? 40 : 15),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Card header row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: (showingBack
                                            ? colors.primary
                                            : colors.textSecondary)
                                        .withAlpha(30),
                                    borderRadius: AppRadius.radiusBadge,
                                  ),
                                  child: Text(
                                    showingBack
                                        ? 'ANSWER'
                                        : 'TAP TO FLIP',
                                    style: typography.caption.bold.copyWith(
                                      fontSize: 9.5,
                                      letterSpacing: 0.4,
                                      color: showingBack
                                          ? colors.primary
                                          : colors.textSecondary,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${index + 1} / ${displayCards.length}',
                                  style: typography.caption.regular.copyWith(
                                    fontSize: 10.5,
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),

                            // Card content with animated flip
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              transitionBuilder: (child, animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: ScaleTransition(
                                    scale: Tween<double>(begin: 0.97, end: 1)
                                        .animate(animation),
                                    child: child,
                                  ),
                                );
                              },
                              child: LatexRichViewer(
                                key: ValueKey(
                                  showingBack
                                      ? 'back_${card.id}'
                                      : 'front_${card.id}',
                                ),
                                text: showingBack ? card.back : card.front,
                                style: typography.footnote.bold.copyWith(
                                  color: colors.textPrimary,
                                  fontSize: 14,
                                  height: 1.45,
                                ),
                                maxLines: 6,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Spacer(),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Previous card chevron button
              if (currentPage.value > 0)
                Positioned(
                  left: 10,
                  child: PlatformHoverBuilder(
                    builder: (context, isHovered, child) => IconButton.filledTonal(
                      onPressed: () {
                        unawaited(HapticFeedback.selectionClick());
                        unawaited(
                          pageController.previousPage(
                            duration: AppMotion.snappy,
                            curve: AppMotion.easeOutCubic,
                          ),
                        );
                      },
                      style: IconButton.styleFrom(
                        backgroundColor: colors.surfacePrimary.withAlpha(isHovered ? 240 : 200),
                        foregroundColor: colors.textPrimary,
                        padding: const EdgeInsets.all(6),
                        minimumSize: const Size(32, 32),
                      ),
                      icon: const Icon(Icons.chevron_left_rounded, size: 20),
                      tooltip: 'Previous Card',
                    ),
                  ),
                ),

              // Next card chevron button
              if (currentPage.value < displayCards.length - 1)
                Positioned(
                  right: 10,
                  child: PlatformHoverBuilder(
                    builder: (context, isHovered, child) => IconButton.filledTonal(
                      onPressed: () {
                        unawaited(HapticFeedback.selectionClick());
                        unawaited(
                          pageController.nextPage(
                            duration: AppMotion.snappy,
                            curve: AppMotion.easeOutCubic,
                          ),
                        );
                      },
                      style: IconButton.styleFrom(
                        backgroundColor: colors.surfacePrimary.withAlpha(isHovered ? 240 : 200),
                        foregroundColor: colors.textPrimary,
                        padding: const EdgeInsets.all(6),
                        minimumSize: const Size(32, 32),
                      ),
                      icon: const Icon(Icons.chevron_right_rounded, size: 20),
                      tooltip: 'Next Card',
                    ),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Dots pagination indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(displayCards.length, (idx) {
            final isSelected = currentPage.value == idx;
            return GestureDetector(
              onTap: () {
                unawaited(HapticFeedback.selectionClick());
                unawaited(
                  pageController.animateToPage(
                    idx,
                    duration: AppMotion.snappy,
                    curve: AppMotion.easeOutCubic,
                  ),
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isSelected ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isSelected
                      ? colors.primary
                      : colors.primary.withAlpha(50),
                  borderRadius: AppRadius.radiusMicro,
                ),
              ),
            );
          }),
        ),

        // Hint: shows how many cards are hidden
        if (totalCards > displayCards.length) ...[
          const SizedBox(height: 12),
          Center(
            child: Text(
              '+${totalCards - displayCards.length} more cards after cloning',
              style: typography.caption.regular.copyWith(
                color: colors.textSecondary,
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Reusable badge widgets ─────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.color,
    this.alpha = 30,
  });

  final String label;
  final Color color;
  final int alpha;

  @override
  Widget build(BuildContext context) {
    final typography = context.typography;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(alpha),
        borderRadius: AppRadius.radiusBadge,
      ),
      child: Text(
        label,
        style: typography.caption.bold.copyWith(color: color, fontSize: 11),
      ),
    );
  }
}

class _BadgeWithIcon extends StatelessWidget {
  const _BadgeWithIcon({
    required this.icon,
    required this.label,
    required this.color,
    this.bgAlpha = 30,
    this.borderAlpha = 60,
  });

  final IconData icon;
  final String label;
  final Color color;
  final int bgAlpha;
  final int borderAlpha;

  @override
  Widget build(BuildContext context) {
    final typography = context.typography;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(bgAlpha),
        borderRadius: AppRadius.radiusBadge,
        border: Border.all(color: color.withAlpha(borderAlpha)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: typography.caption.bold.copyWith(
              color: color,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmojiTextBadge extends StatelessWidget {
  const _EmojiTextBadge({
    required this.emoji,
    required this.label,
    required this.color,
    this.bgAlpha = 25,
    this.borderAlpha = 50,
  });

  final String emoji;
  final String label;
  final Color color;
  final int bgAlpha;
  final int borderAlpha;

  @override
  Widget build(BuildContext context) {
    final typography = context.typography;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(bgAlpha),
        borderRadius: AppRadius.radiusBadge,
        border: Border.all(color: color.withAlpha(borderAlpha)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 5),
          Text(
            label,
            style: typography.caption.bold.copyWith(
              color: color,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}
