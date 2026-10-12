import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_event.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_hub_bloc.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_state.dart';
import 'package:kortex/src/features/deck_marketplace/domain/entities/shared_deck_entity.dart';
import 'package:kortex/src/features/deck_marketplace/domain/services/deck_cloned_checker.dart';
import 'package:kortex/src/features/deck_marketplace/presentation/widgets/marketplace_deck_card.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/study_hub/study_hub_constants.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Tab displaying community shared decks with search, subject categories, and clone actions.
class StudyHubDeckMarketplaceTab extends HookWidget {
  const StudyHubDeckMarketplaceTab({
    required this.state,
    this.selectedDeckId,
    this.hasSelectedDeck = false,
    this.onDeckSelected,
    this.decksBloc,
    super.key,
  });

  final CommunityState state;
  final String? selectedDeckId;
  final bool hasSelectedDeck;
  final ValueChanged<SharedDeckEntity>? onDeckSelected;
  final DecksBloc? decksBloc;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= StudyHubConstants.desktopBreakpoint;
    final isGrid = !hasSelectedDeck &&
        (screenWidth >= StudyHubConstants.gridBreakpoint);
    final gridCrossAxisCount =
        isDesktop && !hasSelectedDeck ? 3 : (isGrid ? 2 : 1);
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 80;

    final selectedCategory = useState<String>('All');
    final searchQuery = useState<String>('');
    final searchController = useTextEditingController();

    final activeDecksBloc = decksBloc ?? context.watch<DecksBloc?>();
    final userDecks = activeDecksBloc?.state.allDecks ?? const <DeckEntity>[];

    const categories = [
      'All',
      'WAEC',
      'JAMB',
      'SAT',
      'STEM',
      'University',
    ];

    final filteredDecks = useMemoized(() {
      return state.sharedDecks.where((deck) {
        final matchesCat = selectedCategory.value == 'All' ||
            deck.category
                .toLowerCase()
                .contains(selectedCategory.value.toLowerCase()) ||
            deck.syllabusTag
                .toLowerCase()
                .contains(selectedCategory.value.toLowerCase());
        final query = searchQuery.value.trim().toLowerCase();
        final matchesSearch = query.isEmpty ||
            deck.title.toLowerCase().contains(query) ||
            deck.subject.toLowerCase().contains(query) ||
            (deck.description?.toLowerCase().contains(query) ?? false);
        return matchesCat && matchesSearch;
      }).toList();
    }, [state.sharedDecks, selectedCategory.value, searchQuery.value]);

    return RefreshIndicator(
      onRefresh: () async {
        context.read<CommunityHubBloc>().add(const LoadCommunityHubEvent());
      },
      color: colors.primary,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: hasSelectedDeck
                ? 520
                : (isDesktop ? 1400 : 860),
          ),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Header & Search Filter Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.storefront_rounded,
                                size: 20,
                                color: colors.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Community Deck Marketplace',
                                style: typography.subhead.bold.copyWith(
                                  color: colors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${filteredDecks.length} Decks',
                            style: typography.caption.medium.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Search Input
                      Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: isDark
                              ? colors.surfaceSecondary
                              : colors.surfaceSecondary.withAlpha(140),
                          borderRadius: AppRadius.radiusSheet,
                          border: Border.all(
                            color: colors.primary.withAlpha(isDark ? 60 : 35),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.search_rounded,
                              size: 18,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: searchController,
                                style: typography.caption.bold.copyWith(
                                  color: colors.textPrimary,
                                  fontSize: 13,
                                ),
                                decoration: InputDecoration(
                                  hintText:
                                      'Search decks, subjects, syllabus tags...',
                                  hintStyle:
                                      typography.caption.regular.copyWith(
                                    color: colors.textSecondary.withAlpha(160),
                                  ),
                                  border: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  isDense: true,
                                  fillColor: Colors.transparent,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onChanged: (val) {
                                  searchQuery.value = val;
                                },
                              ),
                            ),
                            if (searchQuery.value.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  searchController.clear();
                                  searchQuery.value = '';
                                },
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: colors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Category Filter Pills
                      SizedBox(
                        height: 32,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: categories.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 6),
                          itemBuilder: (context, index) {
                            final cat = categories[index];
                            final isSelected = selectedCategory.value == cat;
                            return PlatformHoverBuilder(
                              builder: (context, isHovered, child) =>
                                  ShrinkableButton(
                                onTap: () {
                                  unawaited(HapticFeedback.lightImpact());
                                  selectedCategory.value = cat;
                                },
                                child: AnimatedContainer(
                                  duration: AppMotion.snappy,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? colors.primary
                                        : (isHovered
                                            ? colors.primary.withAlpha(
                                                isDark ? 50 : 30,
                                              )
                                            : (isDark
                                                ? colors.surfaceSecondary
                                                : colors.surfaceSecondary
                                                    .withAlpha(160))),
                                    borderRadius: AppRadius.radiusBadge,
                                    border: Border.all(
                                      color: isSelected
                                          ? colors.primary
                                          : colors.primary.withAlpha(
                                              isDark ? 40 : 20,
                                            ),
                                    ),
                                  ),
                                  child: Text(
                                    cat,
                                    style: typography.caption.bold.copyWith(
                                      color: isSelected
                                          ? colors.white
                                          : colors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (filteredDecks.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 48,
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.style_outlined,
                            size: 44,
                            color: colors.textSecondary.withAlpha(120),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            searchQuery.value.isNotEmpty
                                ? 'No decks found matching "${searchQuery.value}".'
                                : 'No community decks published yet.',
                            style: typography.caption.regular.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (gridCrossAxisCount > 1)
                // Multi-column grid layout for desktop / tablet when 3rd panel is hidden
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPadding),
                  sliver: SliverGrid(
                    gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: gridCrossAxisCount,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      mainAxisExtent: 228,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final deck = filteredDecks[index];
                        final isSelected = selectedDeckId == deck.id;
                        final isCloned = isDeckAlreadyCloned(
                          deck,
                          userDecks: userDecks,
                        );
                        return MarketplaceDeckCard(
                          deck: deck,
                          isSelected: isSelected,
                          isAlreadyCloned: isCloned,
                          onCloneTap: isCloned
                              ? null
                              : () {
                                  context.read<CommunityHubBloc>().add(
                                        CloneDeckEvent(deck.id),
                                      );
                                },
                          onTap: () {
                            if (onDeckSelected != null) {
                              onDeckSelected!(deck);
                            } else {
                              unawaited(
                                context.router.push(
                                  DeckMarketplaceDetailRoute(deck: deck),
                                ),
                              );
                            }
                          },
                        )
                            .animate(
                              delay: (index < 6 ? index * 45 : 0).ms,
                            )
                            .fadeIn(duration: 200.ms)
                            .slideY(
                              begin: 0.04,
                              end: 0,
                              curve: Curves.easeOutCubic,
                            );
                      },
                      childCount: filteredDecks.length,
                    ),
                  ),
                )
              else
                // Single-column list when 3rd panel is open or phone compact view
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPadding),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final deck = filteredDecks[index];
                        final isSelected = selectedDeckId == deck.id;
                        final isCloned = isDeckAlreadyCloned(
                          deck,
                          userDecks: userDecks,
                        );
                        return MarketplaceDeckCard(
                          deck: deck,
                          isSelected: isSelected,
                          isAlreadyCloned: isCloned,
                          margin: const EdgeInsets.only(bottom: 12),
                          onCloneTap: isCloned
                              ? null
                              : () {
                                  context.read<CommunityHubBloc>().add(
                                        CloneDeckEvent(deck.id),
                                      );
                                },
                          onTap: () {
                            if (onDeckSelected != null) {
                              onDeckSelected!(deck);
                            } else {
                              unawaited(
                                context.router.push(
                                  DeckMarketplaceDetailRoute(deck: deck),
                                ),
                              );
                            }
                          },
                        )
                            .animate(
                              delay: (index < 6 ? index * 45 : 0).ms,
                            )
                            .fadeIn(duration: 200.ms)
                            .slideY(
                              begin: 0.04,
                              end: 0,
                              curve: Curves.easeOutCubic,
                            );
                      },
                      childCount: filteredDecks.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
