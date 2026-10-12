import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_event.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_state.dart';
import 'package:kortex/src/shared/widgets/app_logo_loader.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Deck selection view in InRoomDeckStudyWorkspace allowing scholars
/// to choose an active deck to study in the live study pod.
class WorkspaceDeckPickerView extends StatelessWidget {
  const WorkspaceDeckPickerView({
    required this.onDeckSelected,
    this.decksBloc,
    super.key,
  });

  final ValueChanged<DeckEntity> onDeckSelected;
  final DecksBloc? decksBloc;

  @override
  Widget build(BuildContext context) {
    final resolvedDecksBloc =
        decksBloc ??
        (locator.isRegistered<DecksBloc>() ? locator<DecksBloc>() : null);

    if (resolvedDecksBloc == null) {
      return _buildContent(
        context,
        allDecks: const [],
        isLoading: false,
        onRefresh: null,
      );
    }

    return BlocBuilder<DecksBloc, DecksState>(
      bloc: resolvedDecksBloc,
      builder: (context, decksState) {
        final isLoading = decksState.status == DecksStatus.loading;
        final allDecks = List<DeckEntity>.from(decksState.allDecks)
          ..sort((a, b) {
            final aDue = a.dueCards > 0;
            final bDue = b.dueCards > 0;
            if (aDue && !bDue) return -1;
            if (!aDue && bDue) return 1;
            if (aDue && bDue) {
              final countCmp = b.dueCards.compareTo(a.dueCards);
              if (countCmp != 0) return countCmp;
            }
            return a.title.toLowerCase().compareTo(b.title.toLowerCase());
          });

        return _buildContent(
          context,
          allDecks: allDecks,
          isLoading: isLoading,
          onRefresh: () {
            resolvedDecksBloc.add(const DecksRefreshed());
          },
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context, {
    required List<DeckEntity> allDecks,
    required bool isLoading,
    required VoidCallback? onRefresh,
  }) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.primary.withAlpha(isDark ? 40 : 25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.auto_stories_rounded,
                  size: 20,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose a Deck to Study',
                      style: typography.subhead.bold.copyWith(
                        color: colors.textPrimary,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      'Study alongside your study group with active memory recall',
                      style: typography.caption.regular.copyWith(
                        color: colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (onRefresh != null)
                IconButton(
                  tooltip: 'Refresh decks',
                  icon: Icon(
                    Icons.refresh_rounded,
                    size: 20,
                    color: colors.primary,
                  ),
                  onPressed: () {
                    unawaited(HapticFeedback.lightImpact());
                    onRefresh();
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: isLoading && allDecks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const AppLogoLoader(size: 40),
                        const SizedBox(height: 16),
                        Text(
                          'Fetching study decks...',
                          style: typography.body.medium.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : allDecks.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colors.primary.withAlpha(isDark ? 30 : 15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.auto_stories_outlined,
                              size: 36,
                              color: colors.primary,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'No decks available yet',
                            style: typography.subhead.bold.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Create or import a deck to start, or tap below to fetch your latest decks from the cloud.',
                            style: typography.caption.regular.copyWith(
                              color: colors.textSecondary,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 18),
                          ShrinkableButton(
                            onTap: () {
                              unawaited(HapticFeedback.mediumImpact());
                              onRefresh?.call();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: colors.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.refresh_rounded,
                                    size: 16,
                                    color: colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Fetch Decks',
                                    style: typography.caption.bold.copyWith(
                                      color: colors.white,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () async {
                      onRefresh?.call();
                      await Future<void>.delayed(
                        const Duration(milliseconds: 500),
                      );
                    },
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: ClampingScrollPhysics(),
                      ),
                      itemCount: allDecks.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final deck = allDecks[index];
                        final isDue = deck.dueCards > 0;

                        return ShrinkableButton(
                          onTap: () {
                            unawaited(HapticFeedback.mediumImpact());
                            onDeckSelected(deck);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colors.surfacePrimary,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDue
                                    ? colors.recallHard.withAlpha(
                                        isDark ? 100 : 70,
                                      )
                                    : colors.surfaceBorder.withAlpha(
                                        isDark ? 50 : 30,
                                      ),
                                width: isDue ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: colors.primary.withAlpha(
                                      isDark ? 40 : 20,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.style_rounded,
                                      size: 22,
                                      color: colors.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        deck.title,
                                        style: typography.body.bold.copyWith(
                                          color: colors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${deck.totalCards} cards • ${deck.subject}',
                                        style: typography.caption.regular
                                            .copyWith(
                                              color: colors.textSecondary,
                                              fontSize: 11.5,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isDue)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colors.recallHard.withAlpha(
                                        isDark ? 40 : 25,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${deck.dueCards} Due',
                                      style: typography.caption.bold.copyWith(
                                        color: colors.recallHard,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: colors.textSecondary,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
