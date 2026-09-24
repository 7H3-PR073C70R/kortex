import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_event.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_state.dart';
import 'package:kortex/src/features/decks/presentation/widgets/deck_list_tile_card.dart';
import 'package:kortex/src/features/decks/presentation/widgets/focus_mode_setup_modal.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_empty_state.dart';
import 'package:kortex/src/shared/widgets/shimmer_placeholder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

@RoutePage()
class DecksPage extends HookWidget {
  const DecksPage({super.key});

  @override
  Widget build(BuildContext context) {
    final decksBloc = locator<DecksBloc>();

    useEffect(() {
      decksBloc.add(const DecksStarted());
      return null;
    }, const []);

    return BlocProvider<DecksBloc>.value(
      value: decksBloc,
      child: const _DecksView(),
    );
  }
}

class _DecksView extends HookWidget {
  const _DecksView();

  void _showDeckCreationSheet(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    unawaited(
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: isDark
            ? colors.surfaceSecondary
            : colors.surfacePrimary,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.dialog),
          ),
        ),
        builder: (bottomSheetContext) {
          return SafeArea(
            top: false,
            child: Align(
              alignment: Alignment.bottomCenter,
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: colors.surfaceBorder,
                            borderRadius: BorderRadius.circular(
                              AppRadius.micro,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        context.l10n.decksCreateSheetTitle,
                        style: typography.title3.bold.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.l10n.decksCreateSheetSubtitle,
                        style: typography.footnote.regular.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Option 0: Dedicated Study Deck Creation Page
                      _ActionOptionTile(
                        icon: Icons.layers_rounded,
                        iconColor: colors.primary,
                        title: 'Create Study Deck',
                        subtitle:
                            'Upload past questions or create flashcards manually',
                        onTap: () {
                          Navigator.pop(bottomSheetContext);
                          unawaited(
                            context.router.push(
                              CreateDeckRoute(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),

                      // Option 2: Upload Documents
                      _ActionOptionTile(
                        icon: Icons.document_scanner_rounded,
                        iconColor: colors.primary,
                        title: context.l10n.decksUploadDocTitle,
                        subtitle: context.l10n.decksUploadDocSubtitle,
                        onTap: () {
                          Navigator.pop(bottomSheetContext);
                          unawaited(
                            context.router.push(
                              DocumentIngestionRoute(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
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

    return Scaffold(
      backgroundColor: colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: BlocBuilder<DecksBloc, DecksState>(
              builder: (context, state) {
                if (state.isLoading && state.allDecks.isEmpty) {
                  return _buildDecksShimmerSkeleton(colors, isDark);
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    final completer = Completer<void>();
                    context.read<DecksBloc>().add(const DecksRefreshed());
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
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                    children: [
                      // 1. Header Title & Create Action
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.decksTitle,
                                  style: typography.largeTitle.bold.copyWith(
                                    color: colors.textPrimary,
                                    fontSize: 26,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  l10n.decksSubtitle,
                                  style: typography.footnote.regular.copyWith(
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
                              unawaited(HapticFeedback.lightImpact());
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

                      // 2. Today focus — the single obvious next action.
                      //    One decision at the front door beats four equal tiles.
                      if (state.allDecks.isNotEmpty) ...[
                        _TodayHeroCard(state: state),
                        const SizedBox(height: 14),

                        // 3. Sprint options demoted to a compact secondary row:
                        //    still one tap away, no longer competing with the queue.
                        Text(
                          l10n.decksSprintLabel,
                          style: typography.caption.bold.copyWith(
                            color: colors.textMuted,
                            fontSize: 11,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const ClampingScrollPhysics(),
                          child: Row(
                            children: [
                              _SprintChip(
                                icon: Icons.flash_on_rounded,
                                label: l10n.decksSprintQuick10,
                                tone: _SprintTone.primary,
                                onTap: () => _startSprint(context, state, '10'),
                              ),
                              const SizedBox(width: 8),
                              _SprintChip(
                                icon: Icons.track_changes_rounded,
                                label: l10n.decksSprintPower20,
                                tone: _SprintTone.neutral,
                                onTap: () => _startSprint(context, state, '20'),
                              ),
                              const SizedBox(width: 8),
                              _SprintChip(
                                icon: Icons.timer_outlined,
                                label: l10n.decksSprintSpeedRun,
                                tone: _SprintTone.warning,
                                onTap: () {
                                  AppFeedback.selection();
                                  unawaited(
                                    context.router.push(
                                      StudySessionRoute(
                                        deckId:
                                            'sprint:speed:3:${_sprintTargetDeckId(state)}',
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                              _SprintChip(
                                icon: Icons.bolt_rounded,
                                label: l10n.decksSprintHyperdrive,
                                tone: _SprintTone.gradient,
                                onTap: () {
                                  AppFeedback.selection();
                                  unawaited(
                                    FocusModeSetupModal.show(
                                      context,
                                      decks: state.allDecks,
                                      initialDeck: state.allDecks.firstWhere(
                                        (d) => d.dueCards > 0,
                                        orElse: () => state.allDecks.first,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                      ] else ...[
                        const SizedBox(height: 2),
                      ],

                      // 4. Search Field - Unified full-width text field
                      TextField(
                        controller: searchController,
                        style: typography.body.medium.copyWith(
                          color: colors.textPrimary,
                          fontSize: 14,
                        ),
                        cursorColor: colors.primary,
                        decoration: InputDecoration(
                          hintText: l10n.decksSearchHint,
                          hintStyle: typography.body.regular.copyWith(
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
                                  child:
                                      IconButton(
                                            icon: Icon(
                                              Icons.close_rounded,
                                              color: colors.textSecondary,
                                              size: 18,
                                            ),
                                            onPressed: () {
                                              searchController.clear();
                                              searchQueryEmpty.value = true;
                                              context.read<DecksBloc>().add(
                                                const DecksSearchQueryChanged(
                                                  '',
                                                ),
                                              );
                                            },
                                          )
                                          .animate(
                                            delay: 60.ms,
                                          )
                                          .fadeIn(
                                            duration: 140.ms,
                                          )
                                          .scale(
                                            begin: const Offset(0.5, 0.5),
                                            end: const Offset(1, 1),
                                            duration: 180.ms,
                                            curve: AppMotion.snappyCurve,
                                          ),
                                ),
                          filled: true,
                          fillColor: isDark
                              ? colors.surfaceSecondary.withAlpha(200)
                              : colors.surfacePrimary,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            borderSide: BorderSide(
                              color: isDark
                                  ? colors.surfaceBorderHighlight.withAlpha(90)
                                  : colors.surfaceBorder,
                              width: 1.2,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            borderSide: BorderSide(
                              color: isDark
                                  ? colors.surfaceBorderHighlight.withAlpha(90)
                                  : colors.surfaceBorder,
                              width: 1.2,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.card),
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

                      // 5. Filter Category Pills
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const ClampingScrollPhysics(),
                        child: Row(
                          children: [
                            _FilterChip(
                              label: l10n.decksFilterAll,
                              count: state.allDecks.length,
                              isSelected: state.activeFilter == 'all',
                              onTap: () {
                                context.read<DecksBloc>().add(
                                  const DecksFilterChanged('all'),
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: l10n.decksFilterDue,
                              count: state.allDecks
                                  .where((d) => d.dueCards > 0)
                                  .fold<int>(0, (sum, d) => sum + d.dueCards),
                              isDueBadge: true,
                              isSelected: state.activeFilter == 'due',
                              onTap: () {
                                context.read<DecksBloc>().add(
                                  const DecksFilterChanged('due'),
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: l10n.decksFilterMastered,
                              isSelected: state.activeFilter == 'mastered',
                              onTap: () {
                                context.read<DecksBloc>().add(
                                  const DecksFilterChanged('mastered'),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 6. Decks List / Empty State
                      if (state.filteredDecks.isEmpty)
                        if (state.activeFilter == 'due')
                          AppEmptyState(
                            isHappy: true,
                            title: 'All Caught Up! 🎉',
                            subtitle: state.allDecks.isEmpty
                                ? 'You have no due study decks for today. Create a new deck or import course materials to start practicing!'
                                : "Awesome job! You've crushed all your spaced repetition reviews scheduled for today. Keep up the streak!",
                            primaryActionLabel: state.allDecks.isEmpty
                                ? l10n.decksCreateDeckButton
                                : 'Review All Decks',
                            onPrimaryAction: () {
                              if (state.allDecks.isEmpty) {
                                _showDeckCreationSheet(context);
                              } else {
                                context.read<DecksBloc>().add(
                                  const DecksFilterChanged('all'),
                                );
                              }
                            },
                            secondaryActionLabel: state.allDecks.isEmpty
                                ? l10n.decksUploadDocTitle
                                : 'Practice with Syllabot AI',
                            onSecondaryAction: () {
                              if (state.allDecks.isEmpty) {
                                unawaited(
                                  context.router.push(DocumentIngestionRoute()),
                                );
                              } else {
                                unawaited(
                                  context.router.push(
                                    SyllabotChatRoute(
                                      initialPrompt:
                                          'Give me a 5-question Socratic review drill across my active subjects.',
                                      initialMode: SocraticMode.examSim,
                                    ),
                                  ),
                                );
                              }
                            },
                          )
                        else if (state.activeFilter == 'mastered')
                          AppEmptyState(
                            title: 'No Mastered Decks Yet 🎯',
                            subtitle:
                                'Keep reviewing your flashcards using FSRS-6 spaced repetition. As your retention reaches 90%+, mastered decks will appear here.',
                            primaryActionLabel: 'Review All Decks',
                            onPrimaryAction: () =>
                                context.read<DecksBloc>().add(
                                  const DecksFilterChanged('all'),
                                ),
                            secondaryActionLabel: l10n.decksCreateDeckButton,
                            onSecondaryAction: () =>
                                _showDeckCreationSheet(context),
                          )
                        else
                          AppEmptyState(
                            title: l10n.decksEmptyStateTitle,
                            subtitle: l10n.decksEmptyStateSubtitle,
                            primaryActionLabel: l10n.decksCreateDeckButton,
                            onPrimaryAction: () =>
                                _showDeckCreationSheet(context),
                            secondaryActionLabel: l10n.decksUploadDocTitle,
                            onSecondaryAction: () => unawaited(
                              context.router.push(DocumentIngestionRoute()),
                            ),
                          )
                      else
                        for (
                          var index = 0;
                          index < state.filteredDecks.length;
                          index++
                        )
                          _buildDeckTile(
                            context,
                            state.filteredDecks[index],
                            index,
                            reduceMotion,
                          ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Deck tiles enter with a short stagger (first 8 only) so the list feels
  /// assembled rather than popped. Keyed by deck id so filtering or search
  /// re-renders never replay the entrance for already-visible tiles.
  Widget _buildDeckTile(
    BuildContext context,
    DeckEntity deck,
    int index,
    bool reduceMotion,
  ) {
    Widget tile = Padding(
      key: ValueKey<String>(deck.id),
      padding: const EdgeInsets.only(bottom: 14),
      child: DeckListTileCard(deck: deck),
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

  /// Sprint pools come from the single due deck when there is exactly one,
  /// otherwise they run cross-deck over everything.
  String _sprintTargetDeckId(DecksState state) {
    final dueDecks = state.allDecks.where((d) => d.dueCards > 0).toList();
    if (dueDecks.length == 1) return dueDecks.first.id;
    return 'all';
  }

  void _startSprint(BuildContext context, DecksState state, String size) {
    AppFeedback.selection();
    unawaited(
      context.router.push(
        StudySessionRoute(
          deckId: 'sprint:$size:${_sprintTargetDeckId(state)}',
        ),
      ),
    );
  }

  Widget _buildDecksShimmerSkeleton(
    AppThemeColorsExtension colors,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header Shimmer
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerPlaceholder(width: 140, height: 26, borderRadius: 8),
                  SizedBox(height: 6),
                  ShimmerPlaceholder(width: 220, height: 14, borderRadius: 6),
                ],
              ),
              ShimmerPlaceholder(width: 40, height: 40, borderRadius: 20),
            ],
          ),
          const SizedBox(height: 20),

          // 2. Today Hero Shimmer
          const ShimmerPlaceholder(
            width: double.infinity,
            height: 132,
            borderRadius: 16,
          ),
          const SizedBox(height: 16),

          // 3. Search Bar Shimmer
          const ShimmerPlaceholder(
            width: double.infinity,
            height: 48,
            borderRadius: 16,
          ),
          const SizedBox(height: 16),

          // 4. Filter Category Pills Shimmer
          const Row(
            children: [
              ShimmerPlaceholder(width: 80, height: 32, borderRadius: 16),
              SizedBox(width: 8),
              ShimmerPlaceholder(width: 95, height: 32, borderRadius: 16),
              SizedBox(width: 8),
              ShimmerPlaceholder(width: 85, height: 32, borderRadius: 16),
            ],
          ),
          const SizedBox(height: 24),

          // 5. Deck Card List Skeletons
          Expanded(
            child: ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 3,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (_, _) => const ShimmerPlaceholder(
                width: double.infinity,
                height: 120,
                borderRadius: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The "what should I do right now?" answer, front and center.
/// Due > 0: one number, one button. Due == 0: calm confirmation, no dead end.
class _TodayHeroCard extends StatelessWidget {
  const _TodayHeroCard({required this.state});

  final DecksState state;

  static const int _secondsPerCard = 12;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;
    final reduceMotion = context.reduceMotion;

    final totalDue = state.totalDueCards;
    final hasDue = totalDue > 0;
    final dueMinutes = (totalDue * _secondsPerCard / 60).ceil().clamp(1, 999);

    final dueDecks = state.allDecks.where((d) => d.dueCards > 0).toList();
    final reviewDeckId = dueDecks.length == 1 ? dueDecks.first.id : 'all';

    final Widget hero = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [colors.surfaceSecondary, colors.surfaceTertiary]
              : [colors.surfacePrimary, colors.surfaceSecondary],
        ),
        borderRadius: BorderRadius.circular(AppRadius.panel),
        border: Border.all(
          color: hasDue
              ? colors.primary.withValues(alpha: 0.35)
              : colors.success.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.black.withValues(alpha: isDark ? 0.2 : 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (hasDue ? colors.primary : colors.success).withValues(
                    alpha: 0.18,
                  ),
                ),
                child: Icon(
                  hasDue
                      ? Icons.school_rounded
                      : Icons.check_circle_outline_rounded,
                  color: hasDue ? colors.primary : colors.success,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasDue
                          ? l10n.decksHeroWaitingTitle(totalDue)
                          : l10n.decksHeroAllCaughtUp,
                      style: typography.body.bold.copyWith(
                        color: colors.textPrimary,
                        fontSize: 16.5,
                        height: 1.25,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hasDue
                          ? l10n.decksHeroEstimate(dueMinutes)
                          : l10n.decksHeroAllCaughtUpSubtitle,
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
          const SizedBox(height: 14),
          if (hasDue)
            ShrinkableButton(
              onTap: () {
                AppFeedback.selection();
                unawaited(
                  context.router.push(
                    StudySessionRoute(deckId: reviewDeckId),
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colors.primary, colors.syllabotAccent],
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  boxShadow: [
                    BoxShadow(
                      color: colors.black.withAlpha(isDark ? 45 : 25),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Semantics(
                  button: true,
                  label: l10n.decksHeroReviewCta(totalDue),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.play_arrow_rounded,
                        color: colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        l10n.decksHeroReviewCta(totalDue),
                        style: typography.caption.bold.copyWith(
                          color: colors.white,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            ShrinkableButton(
              onTap: () {
                unawaited(HapticFeedback.lightImpact());
                context.read<DecksBloc>().add(
                  const DecksFilterChanged('all'),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: isDark
                      ? colors.white.withValues(alpha: 0.08)
                      : colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(
                    color: colors.surfaceBorder.withValues(alpha: 0.6),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  l10n.decksHeroBrowseDecks,
                  style: typography.caption.bold.copyWith(
                    color: colors.textPrimary,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (reduceMotion) return hero;

    return hero
        .animate()
        .fadeIn(duration: 250.ms, curve: Curves.easeOut)
        .scale(
          begin: const Offset(0.97, 0.97),
          end: const Offset(1, 1),
          duration: 250.ms,
          curve: Curves.easeOutQuint,
        )
        .slideY(
          begin: 0.04,
          end: 0,
          duration: 250.ms,
          curve: Curves.easeOutQuint,
        );
  }
}

enum _SprintTone { primary, neutral, warning, gradient }

/// Compact secondary action: same destinations as before, no longer shouting.
class _SprintChip extends StatelessWidget {
  const _SprintChip({
    required this.icon,
    required this.label,
    required this.tone,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final _SprintTone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final (Color fg, Color bg, Border? border) = switch (tone) {
      _SprintTone.primary => (
        colors.white,
        colors.primary,
        null,
      ),
      _SprintTone.neutral => (
        colors.textPrimary,
        isDark
            ? colors.white.withValues(alpha: 0.08)
            : colors.black.withValues(alpha: 0.05),
        Border.all(color: colors.surfaceBorder.withValues(alpha: 0.6)),
      ),
      _SprintTone.warning => (
        colors.warning,
        colors.warning.withValues(alpha: isDark ? 0.16 : 0.1),
        Border.all(color: colors.warning.withValues(alpha: 0.45)),
      ),
      _SprintTone.gradient => (
        colors.white,
        colors.transparent,
        null,
      ),
    };

    return Semantics(
      button: true,
      label: label,
      child: ShrinkableButton(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            gradient: tone == _SprintTone.gradient
                ? LinearGradient(
                    colors: [colors.deepBronze, colors.primary],
                  )
                : null,
            color: tone == _SprintTone.gradient ? null : bg,
            borderRadius: BorderRadius.circular(AppRadius.badge),
            border: border,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: tone == _SprintTone.gradient ? colors.white : fg,
                size: 15,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: typography.caption.bold.copyWith(
                  color: tone == _SprintTone.gradient ? colors.white : fg,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionOptionTile extends StatelessWidget {
  const _ActionOptionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return ShrinkableButton(
      onTap: () {
        unawaited(HapticFeedback.lightImpact());
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.panel),
          color: isDark
              ? colors.surfaceSecondary.withAlpha(150)
              : colors.surfacePrimary.withAlpha(200),
          border: Border.all(
            color: isDark
                ? colors.surfaceBorderHighlight.withAlpha(50)
                : colors.surfaceBorder.withAlpha(100),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.card),
                color: iconColor.withAlpha(isDark ? 40 : 25),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: typography.body.bold.copyWith(
                      color: colors.textPrimary,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: typography.footnote.regular.copyWith(
                      color: colors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: colors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.count,
    this.isDueBadge = false,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final int? count;
  final bool isDueBadge;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Semantics(
      selected: isSelected,
      button: true,
      label: label,
      child: ShrinkableButton(
        onTap: () {
          unawaited(HapticFeedback.lightImpact());
          onTap();
        },
        child: AnimatedContainer(
          duration: AppMotion.snappy,
          curve: AppMotion.snappyCurve,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected
                ? colors.primary
                : (isDark
                      ? colors.surfaceSecondary.withAlpha(150)
                      : colors.surfacePrimary.withAlpha(200)),
            borderRadius: BorderRadius.circular(AppRadius.badge),
            border: Border.all(
              color: isSelected
                  ? colors.primary
                  : (isDark
                        ? colors.surfaceBorderHighlight.withAlpha(70)
                        : colors.surfaceBorder.withAlpha(120)),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: typography.caption.bold.copyWith(
                  color: isSelected ? colors.white : colors.textPrimary,
                  fontSize: 12,
                ),
              ),
              if (count != null && count! > 0) ...[
                const SizedBox(width: 6),
                AnimatedSwitcher(
                  duration: AppMotion.snappy,
                  switchInCurve: AppMotion.snappyCurve,
                  switchOutCurve: AppMotion.exitCurve,
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: Container(
                    key: ValueKey('$count-$isDueBadge-$isSelected'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isDueBadge
                          ? colors.error
                          : (isSelected
                                ? colors.white.withAlpha(40)
                                : colors.primary.withAlpha(30)),
                      borderRadius: BorderRadius.circular(AppRadius.micro),
                    ),
                    child: Text(
                      '$count',
                      style: typography.footnote.bold.copyWith(
                        color: colors.white,
                        fontSize: 10.5,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
