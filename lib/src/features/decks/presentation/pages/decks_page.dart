import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/dashboard/presentation/pages/nested/deck_detail_page.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_event.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_state.dart';
import 'package:kortex/src/features/decks/presentation/widgets/deck_list_tile_card.dart';
import 'package:kortex/src/features/decks/presentation/widgets/decks/deck_creation_action_sheet.dart';
import 'package:kortex/src/features/decks/presentation/widgets/decks/deck_filter_chip.dart';
import 'package:kortex/src/features/decks/presentation/widgets/decks/decks_empty_state_view.dart';
import 'package:kortex/src/features/decks/presentation/widgets/decks/decks_shimmer_skeleton.dart';
import 'package:kortex/src/features/decks/presentation/widgets/decks/decks_today_hero_banner.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_tour_keys.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

export 'package:kortex/src/features/decks/presentation/widgets/decks/deck_creation_action_sheet.dart';
export 'package:kortex/src/features/decks/presentation/widgets/decks/deck_filter_chip.dart';
export 'package:kortex/src/features/decks/presentation/widgets/decks/decks_empty_state_view.dart';
export 'package:kortex/src/features/decks/presentation/widgets/decks/decks_shimmer_skeleton.dart';
export 'package:kortex/src/features/decks/presentation/widgets/decks/decks_today_hero_banner.dart';

@RoutePage()
class DecksPage extends HookWidget {
  const DecksPage({
    this.decksBloc,
    super.key,
  });

  final DecksBloc? decksBloc;

  @override
  Widget build(BuildContext context) {
    final effectiveDecksBloc = decksBloc ?? locator<DecksBloc>();

    useEffect(() {
      effectiveDecksBloc.add(const DecksStarted());
      return null;
    }, [effectiveDecksBloc]);

    return BlocProvider<DecksBloc>.value(
      value: effectiveDecksBloc,
      child: const _DecksView(),
    );
  }
}

class _DecksView extends HookWidget {
  const _DecksView();

  void _showDeckCreationSheet(BuildContext context) {
    unawaited(DeckCreationActionSheet.show(context));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;
    final reduceMotion = context.reduceMotion;

    final searchController = useTextEditingController();
    final searchQueryEmpty = useState(true);
    final selectedDesktopDeck = useState<DeckEntity?>(null);

    useEffect(() {
      context.read<DecksBloc>().add(const DecksRefreshed());
      try {
        final tabsRouter = AutoTabsRouter.of(context);
        void onTabChange() {
          if (tabsRouter.activeIndex == 1) {
            context.read<DecksBloc>().add(const DecksRefreshed());
          }
        }

        tabsRouter.addListener(onTabChange);
        return () => tabsRouter.removeListener(onTabChange);
      } on Object catch (_) {
        return null;
      }
    }, const []);

    return Focus(
      onKeyEvent: (node, event) {
        if (selectedDesktopDeck.value != null &&
            event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          selectedDesktopDeck.value = null;
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: colors.transparent,
        body: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 1024;
              final hasSelectedDeck =
                  isDesktop && selectedDesktopDeck.value != null;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AnimatedContainer(
                    duration: AppMotion.expressive,
                    curve: AppMotion.easeOutCubic,
                    width: hasSelectedDeck ? 520 : constraints.maxWidth,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: hasSelectedDeck ? 520 : 860,
                        ),
                        child: BlocBuilder<DecksBloc, DecksState>(
                          builder: (context, state) {
                            if (state.isLoading && state.allDecks.isEmpty) {
                              return const DecksShimmerSkeleton();
                            }

                            return RefreshIndicator(
                              onRefresh: () async {
                                final completer = Completer<void>();
                                context.read<DecksBloc>().add(
                                      const DecksRefreshed(),
                                    );
                                Timer(
                                  const Duration(milliseconds: 600),
                                  completer.complete,
                                );
                                return completer.future;
                              },
                              color: colors.primary,
                              child: ListView(
                                physics: const ClampingScrollPhysics(
                                  parent: AlwaysScrollableScrollPhysics(),
                                ),
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  16,
                                  20,
                                  140,
                                ),
                                children: [
                                  // 1. Header Title & Create Action
                                  Row(
                                    key: AppTourKeys.decksHeaderKey,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              l10n.decksTitle,
                                              style: typography.largeTitle.bold
                                                  .copyWith(
                                                color: colors.textPrimary,
                                                fontSize: 26,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              l10n.decksSubtitle,
                                              style: typography.footnote.regular
                                                  .copyWith(
                                                color: colors.textSecondary,
                                                fontSize: 13,
                                                height: 1.3,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      ShrinkableButton(
                                        onTap: () {
                                          unawaited(
                                            HapticFeedback.lightImpact(),
                                          );
                                          _showDeckCreationSheet(context);
                                        },
                                        child: Container(
                                          width: 42,
                                          height: 42,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: colors.primary,
                                            boxShadow: [
                                              BoxShadow(
                                                color: colors.black.withAlpha(
                                                  isDark ? 60 : 30,
                                                ),
                                                blurRadius: 10,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Icon(
                                            Icons.add_rounded,
                                            color: colors.white,
                                            size: 22,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  // 2. Today Review Hero Banner
                                  DecksTodayHeroBanner(
                                    allDecks: state.allDecks,
                                    onBrowseAll: () {
                                      context.read<DecksBloc>().add(
                                            const DecksFilterChanged('all'),
                                          );
                                    },
                                  ),
                                  if (state.allDecks.isNotEmpty)
                                    const SizedBox(height: 16),

                                  // 3. Search Field - Unified full-width text field
                                  if (state.allDecks.isNotEmpty) ...[
                                    TextField(
                                      controller: searchController,
                                      style: typography.body.medium.copyWith(
                                        color: colors.textPrimary,
                                        fontSize: 14,
                                      ),
                                      cursorColor: colors.primary,
                                      decoration: InputDecoration(
                                        hintText: l10n.decksSearchHint,
                                        hintStyle: typography.body.regular
                                            .copyWith(
                                          color: colors.textMuted,
                                          fontSize: 13.5,
                                        ),
                                        prefixIcon: Icon(
                                          Icons.search_rounded,
                                          color: colors.textSecondary,
                                          size: 20,
                                        ),
                                        suffixIcon: searchQueryEmpty.value
                                            ? null
                                            : Semantics(
                                                button: true,
                                                label: l10n.decksClearSearch,
                                                child: IconButton(
                                                  icon: Icon(
                                                    Icons.close_rounded,
                                                    color:
                                                        colors.textSecondary,
                                                    size: 18,
                                                  ),
                                                  onPressed: () {
                                                    searchController.clear();
                                                    searchQueryEmpty.value =
                                                        true;
                                                    context
                                                        .read<DecksBloc>()
                                                        .add(
                                                          const DecksSearchQueryChanged(
                                                            '',
                                                          ),
                                                        );
                                                  },
                                                )
                                                    .animate(delay: 60.ms)
                                                    .fadeIn(duration: 140.ms)
                                                    .scale(
                                                      begin: const Offset(
                                                        0.5,
                                                        0.5,
                                                      ),
                                                      end: const Offset(1, 1),
                                                      duration: 180.ms,
                                                      curve: AppMotion
                                                          .snappyCurve,
                                                    ),
                                              ),
                                        filled: true,
                                        fillColor: isDark
                                            ? colors.surfaceSecondary
                                                .withAlpha(200)
                                            : colors.surfacePrimary,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 12,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            AppRadius.card,
                                          ),
                                          borderSide: BorderSide(
                                            color: isDark
                                                ? colors
                                                    .surfaceBorderHighlight
                                                    .withAlpha(90)
                                                : colors.surfaceBorder,
                                            width: 1.2,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            AppRadius.card,
                                          ),
                                          borderSide: BorderSide(
                                            color: isDark
                                                ? colors
                                                    .surfaceBorderHighlight
                                                    .withAlpha(90)
                                                : colors.surfaceBorder,
                                            width: 1.2,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            AppRadius.card,
                                          ),
                                          borderSide: BorderSide(
                                            color: colors.primary,
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                      onChanged: (query) {
                                        searchQueryEmpty.value = query.isEmpty;
                                        context.read<DecksBloc>().add(
                                              DecksSearchQueryChanged(query),
                                            );
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                  ],

                                  // 4. Filter Category Pills
                                  SingleChildScrollView(
                                    key: AppTourKeys.decksFilterChipKey,
                                    scrollDirection: Axis.horizontal,
                                    physics: const ClampingScrollPhysics(),
                                    child: Row(
                                      children: [
                                        DeckFilterChip(
                                          label: l10n.decksFilterAll,
                                          count: state.allDecks.length,
                                          isSelected:
                                              state.activeFilter == 'all',
                                          onTap: () {
                                            context.read<DecksBloc>().add(
                                                  const DecksFilterChanged(
                                                    'all',
                                                  ),
                                                );
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                        DeckFilterChip(
                                          label: l10n.decksFilterDue,
                                          count: state.allDecks
                                              .where((d) => d.dueCards > 0)
                                              .fold<int>(
                                                0,
                                                (sum, d) => sum + d.dueCards,
                                              ),
                                          isDueBadge: true,
                                          isSelected:
                                              state.activeFilter == 'due',
                                          onTap: () {
                                            context.read<DecksBloc>().add(
                                                  const DecksFilterChanged(
                                                    'due',
                                                  ),
                                                );
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                        DeckFilterChip(
                                          label: l10n.decksFilterMastered,
                                          isSelected:
                                              state.activeFilter == 'mastered',
                                          onTap: () {
                                            context.read<DecksBloc>().add(
                                                  const DecksFilterChanged(
                                                    'mastered',
                                                  ),
                                                );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  // 5. Decks List / Empty State
                                  if (state.filteredDecks.isEmpty)
                                    DecksEmptyStateView(
                                      activeFilter: state.activeFilter,
                                      allDecks: state.allDecks,
                                      onCreateDeckTap: () =>
                                          _showDeckCreationSheet(context),
                                      onResetFilterToAll: () =>
                                          context.read<DecksBloc>().add(
                                                const DecksFilterChanged('all'),
                                              ),
                                    )
                                  else
                                    LayoutBuilder(
                                      builder: (context, gridConstraints) {
                                        final columnCount =
                                            switch (gridConstraints.maxWidth) {
                                          >= 1400 => 4,
                                          >= 900 => 3,
                                          >= 640 => 2,
                                          _ => 1,
                                        };
                                        if (columnCount > 1) {
                                          final itemWidth =
                                              (gridConstraints.maxWidth -
                                                      (14 *
                                                          (columnCount - 1))) /
                                                  columnCount;
                                          return Wrap(
                                            spacing: 14,
                                            runSpacing: 14,
                                            children: [
                                              for (var index = 0;
                                                  index <
                                                      state
                                                          .filteredDecks.length;
                                                  index++
                                              )
                                                SizedBox(
                                                  width: itemWidth,
                                                  child: _buildDeckTile(
                                                    context,
                                                    state.filteredDecks[index],
                                                    index,
                                                    reduceMotion,
                                                    isDesktop: isDesktop,
                                                    selectedDesktopDeck:
                                                        selectedDesktopDeck,
                                                  ),
                                                ),
                                            ],
                                          );
                                        }
                                        return Column(
                                          children: [
                                            for (var index = 0;
                                                index <
                                                    state.filteredDecks.length;
                                                index++
                                            )
                                              _buildDeckTile(
                                                context,
                                                state.filteredDecks[index],
                                                index,
                                                reduceMotion,
                                                isDesktop: isDesktop,
                                                selectedDesktopDeck:
                                                    selectedDesktopDeck,
                                              ),
                                          ],
                                        );
                                      },
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  if (hasSelectedDeck) ...[
                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: isDark
                          ? colors.surfaceBorderHighlight.withAlpha(50)
                          : colors.surfaceBorder,
                    ),
                    Expanded(
                      child: DeckDetailPage(
                        key: ValueKey(selectedDesktopDeck.value!.id),
                        deckId: selectedDesktopDeck.value!.id,
                        onClose: () {
                          selectedDesktopDeck.value = null;
                        },
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDeckTile(
    BuildContext context,
    DeckEntity deck,
    int index,
    bool reduceMotion, {
    bool isDesktop = false,
    ValueNotifier<DeckEntity?>? selectedDesktopDeck,
  }) {
    Widget tile = Padding(
      key: ValueKey<String>(deck.id),
      padding: const EdgeInsets.only(bottom: 14),
      child: DeckListTileCard(
        deck: deck,
        isSelected: selectedDesktopDeck?.value?.id == deck.id,
        onSelectDeck: isDesktop && selectedDesktopDeck != null
            ? (selectedDeck) {
                selectedDesktopDeck.value = selectedDeck;
              }
            : null,
      ),
    );

    if (!reduceMotion && index < 8) {
      tile = tile
          .animate(delay: (index * 80).ms)
          .fadeIn(duration: 200.ms, curve: Curves.easeOut)
          .slideY(
            begin: 0.04,
            end: 0,
            duration: 250.ms,
            curve: Curves.easeOutQuint,
          );
    }
    return tile;
  }
}
