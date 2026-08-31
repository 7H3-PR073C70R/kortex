import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_event.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_state.dart';
import 'package:kortex/src/features/decks/presentation/widgets/deck_list_tile_card.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';
import 'package:kortex/src/shared/widgets/syllabot_avatar.dart';

@RoutePage()
class DecksPage extends HookWidget {
  const DecksPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DecksBloc>(
      create: (_) => locator<DecksBloc>()..add(const DecksStarted()),
      child: const _DecksView(),
    );
  }
}

class _DecksView extends HookWidget {
  const _DecksView();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final searchController = useTextEditingController();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<DecksBloc, DecksState>(
          builder: (context, state) {
            if (state.isLoading && state.allDecks.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                final completer = Completer<void>();
                context.read<DecksBloc>().add(const DecksRefreshed());
                Timer(const Duration(milliseconds: 600), completer.complete);
                return completer.future;
              },
              color: colors.primary,
              child: ListView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                children: [
                  // 1. Header Title & Create Action
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.decksTitle,
                            style: typography.largeTitle.bold.copyWith(
                              color: colors.textPrimary,
                              fontSize: 24,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.decksSubtitle,
                            style: typography.footnote.regular.copyWith(
                              color: colors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      ShrinkableButton(
                        onTap: () {
                          unawaited(HapticFeedback.lightImpact());
                          unawaited(
                            context.router.push(
                              SyllabotChatRoute(
                                initialPrompt: 'Create a new study deck.',
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.primary,
                            boxShadow: [
                              BoxShadow(
                                color: colors.primary.withAlpha(80),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.add_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // 2. Search Field
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? colors.surfaceSecondary.withAlpha(160)
                          : colors.surfacePrimary.withAlpha(220),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? colors.surfaceBorderHighlight.withAlpha(70)
                            : colors.surfaceBorder.withAlpha(130),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: colors.textMuted,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: searchController,
                            onChanged: (query) {
                              context
                                  .read<DecksBloc>()
                                  .add(DecksSearchQueryChanged(query));
                            },
                            style: typography.callout.regular.copyWith(
                              color: colors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: l10n.decksSearchHint,
                              hintStyle: typography.footnote.regular.copyWith(
                                color: colors.textMuted,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        if (searchController.text.isNotEmpty)
                          IconButton(
                            icon: Icon(
                              Icons.clear_rounded,
                              size: 18,
                              color: colors.textMuted,
                            ),
                            onPressed: () {
                              searchController.clear();
                              context
                                  .read<DecksBloc>()
                                  .add(const DecksSearchQueryChanged(''));
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. Filter Chips (All / Due Today / Mastered)
                  Row(
                    children: [
                      _FilterChip(
                        label: l10n.decksFilterAll,
                        count: state.allDecks.length,
                        isSelected: state.activeFilter == 'all',
                        onTap: () {
                          context
                              .read<DecksBloc>()
                              .add(const DecksFilterChanged('all'));
                        },
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: l10n.decksFilterDue,
                        count: state.totalDueCards,
                        isDueBadge: true,
                        isSelected: state.activeFilter == 'due',
                        onTap: () {
                          context
                              .read<DecksBloc>()
                              .add(const DecksFilterChanged('due'));
                        },
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: l10n.decksFilterMastered,
                        isSelected: state.activeFilter == 'mastered',
                        onTap: () {
                          context
                              .read<DecksBloc>()
                              .add(const DecksFilterChanged('mastered'));
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 4. Decks List or Empty State
                  if (state.filteredDecks.isEmpty)
                    const _DecksEmptyState()
                  else
                    ...state.filteredDecks.map((deck) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: DeckListTileCard(deck: deck),
                      );
                    }),
                ],
              ),
            );
          },
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

    return ShrinkableButton(
      onTap: () {
        unawaited(HapticFeedback.lightImpact());
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.primary
              : (isDark
                  ? colors.surfaceSecondary.withAlpha(150)
                  : colors.surfacePrimary.withAlpha(200)),
          borderRadius: BorderRadius.circular(12),
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
                color: isSelected ? Colors.white : colors.textPrimary,
                fontSize: 12,
              ),
            ),
            if (count != null && count! > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isDueBadge
                      ? const Color(0xFFEF4444)
                      : (isSelected
                          ? Colors.white.withAlpha(40)
                          : colors.primary.withAlpha(30)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$count',
                  style: typography.footnote.bold.copyWith(
                    color: Colors.white,
                    fontSize: 10.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DecksEmptyState extends StatelessWidget {
  const _DecksEmptyState();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        children: [
          const SyllabotAvatar(size: 54),
          const SizedBox(height: 18),
          Text(
            l10n.decksEmptyStateTitle,
            style: typography.title3.bold.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.decksEmptyStateSubtitle,
            textAlign: TextAlign.center,
            style: typography.footnote.regular.copyWith(
              color: colors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 20),
          ShrinkableButton(
            onTap: () {
              unawaited(HapticFeedback.lightImpact());
              unawaited(
                context.router.push(
                  SyllabotChatRoute(
                    initialPrompt:
                        'Generate a new active recall flashcard deck.',
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                l10n.decksCreateDeckButton,
                style: typography.caption.bold.copyWith(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
