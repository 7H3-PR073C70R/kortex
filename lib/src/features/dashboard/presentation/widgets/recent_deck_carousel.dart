import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/dashboard/domain/entities/study_deck_entity.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_state.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/fsrs_review_deck_card.dart';
import 'package:kortex/src/l10n/l10n.dart';

/// A horizontal carousel for reviewing recent and due study decks.
class RecentDeckCarousel extends StatelessWidget {
  const RecentDeckCarousel({
    required this.decks,
    this.title,
    super.key,
  });

  final List<StudyDeckEntity> decks;
  final String? title;

  @override
  Widget build(BuildContext context) {
    if (decks.isEmpty) return const SizedBox.shrink();

    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title!,
                  style: typography.title3.bold.copyWith(
                    color: colors.textPrimary,
                    fontSize: 15.5,
                  ),
                ),
                Text(
                  l10n.dashboardDecksCount(decks.length),
                  style: typography.caption.bold.copyWith(
                    color: colors.primary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          height: 205,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            itemCount: decks.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final deck = decks[index];
              return SizedBox(
                width: 300,
                child: FsrsReviewDeckCard(deck: deck)
                    .animate(delay: (index * 60).ms)
                    .fadeIn(duration: 350.ms, curve: Curves.easeOutCubic)
                    .slideX(begin: 0.05, end: 0, curve: Curves.easeOutQuint),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Scoped BlocBuilder wrapper for RecentDeckCarousel that only triggers
/// rebuilds when the collection of due study decks changes.
class ScopedRecentDeckCarousel extends StatelessWidget {
  const ScopedRecentDeckCarousel({
    this.title,
    this.skipFirst = false,
    super.key,
  });

  final String? title;
  final bool skipFirst;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardBloc, DashboardState>(
      buildWhen: (previous, current) {
        final prevFeed = previous.displayFeed;
        final currFeed = current.displayFeed;
        if (prevFeed == null || currFeed == null) {
          return previous != current;
        }
        return prevFeed.dueStudyDecks != currFeed.dueStudyDecks;
      },
      builder: (context, state) {
        final feed = state.displayFeed;
        if (feed == null) return const SizedBox.shrink();

        final rawDecks = feed.dueStudyDecks;
        final decks = skipFirst && rawDecks.length > 1
            ? rawDecks.skip(1).toList()
            : rawDecks;

        return RecentDeckCarousel(
          decks: decks,
          title: title,
        );
      },
    );
  }
}
