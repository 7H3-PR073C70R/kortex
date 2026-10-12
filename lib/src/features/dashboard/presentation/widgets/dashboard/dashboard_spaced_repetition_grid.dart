import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/dashboard/domain/entities/study_deck_entity.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/fsrs_review_deck_card.dart';
import 'package:kortex/src/l10n/l10n.dart';

/// Responsive Grid for remaining queued decks on Desktop Workstation.
class DashboardDesktopSpacedRepetitionGrid extends StatelessWidget {
  const DashboardDesktopSpacedRepetitionGrid({
    required this.decks,
    super.key,
  });

  final List<StudyDeckEntity> decks;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.dashboardSpacedRepetitionQueue,
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
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 360,
            mainAxisExtent: 185,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          ),
          itemCount: decks.length,
          itemBuilder: (context, index) {
            return FsrsReviewDeckCard(deck: decks[index])
                .animate(delay: (index * 80).ms)
                .fadeIn(duration: 400.ms, curve: Curves.easeOutCubic)
                .slideY(begin: 0.05, end: 0, curve: Curves.easeOutQuint);
          },
        ),
      ],
    );
  }
}
