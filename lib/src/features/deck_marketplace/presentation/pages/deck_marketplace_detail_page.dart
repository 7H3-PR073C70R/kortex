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
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:kortex/src/features/deck_marketplace/domain/entities/shared_deck_entity.dart';
import 'package:kortex/src/features/deck_marketplace/domain/use_cases/clone_shared_deck_use_case.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_event.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_avatar.dart';
import 'package:kortex/src/shared/widgets/app_back_button.dart';
import 'package:kortex/src/shared/widgets/app_logo_loader.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

// Grid breakpoint — mirrors the one used in study_hub_page.dart.
const double _kDetailGridBreakpoint = 600;

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

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = screenWidth >= _kDetailGridBreakpoint;

    final isCloning = useState<bool>(false);

    Future<void> handleClone() async {
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
          child: PlatformHoverBuilder(
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
      appBar: AppBar(
        backgroundColor: colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const AppBackButton(),
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
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star_rounded, size: 16, color: colors.warning),
                const SizedBox(width: 3),
                Text(
                  deck.rating.toStringAsFixed(1),
                  style: typography.caption.bold.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: bottomBar,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          // Wide layout: info panel (left) + card preview (right) side-by-side
          child: isWide
              ? _WideDetailLayout(
                  deck: deck,
                  isDark: isDark,
                )
              : _CompactDetailLayout(
                  deck: deck,
                  isDark: isDark,
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
  });

  final SharedDeckEntity deck;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _DeckInfoPanel(deck: deck, isDark: isDark),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
            child: _CardPreviewSection(
              deck: deck,
              isDark: isDark,
            ),
          ),
        ),
        // Stats row
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: _StatsRow(deck: deck),
          ),
        ),
        // Extra breathing room above the bottom bar
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }
}

// ── Wide layout (tablet / landscape / desktop) ────────────────────────────────

class _WideDetailLayout extends StatelessWidget {
  const _WideDetailLayout({
    required this.deck,
    required this.isDark,
  });

  final SharedDeckEntity deck;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: deck info + stats
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DeckInfoPanel(deck: deck, isDark: isDark),
                const SizedBox(height: 20),
                _StatsRow(deck: deck),
              ],
            ),
          ),
          const SizedBox(width: 20),
          // Right: card preview panel
          Expanded(
            flex: 4,
            child: _CardPreviewSection(deck: deck, isDark: isDark),
          ),
        ],
      ),
    );
  }
}

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
  const _StatsRow({required this.deck});

  final SharedDeckEntity deck;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;

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
            value: deck.rating.toStringAsFixed(1),
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
        // Fixed-height card carousel — avoids unbounded height issue inside
        // SingleChildScrollView / Column by using an explicit SizedBox.
        SizedBox(
          height: 200,
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
                          child: Text(
                            showingBack ? card.back : card.front,
                            key: ValueKey(
                              showingBack
                                  ? 'back_${card.id}'
                                  : 'front_${card.id}',
                            ),
                            style: typography.footnote.bold.copyWith(
                              color: colors.textPrimary,
                              fontSize: 14,
                              height: 1.45,
                            ),
                            maxLines: 4,
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
