import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/latex_rich_viewer.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class DeckMarketplaceInteractiveCardPreviewCarousel extends HookWidget {
  const DeckMarketplaceInteractiveCardPreviewCarousel({
    required this.cards,
    required this.totalCards,
    required this.subject,
    required this.isDark,
    super.key,
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
                        backgroundColor: colors.surfacePrimary.withAlpha(
                          isHovered ? 240 : 200,
                        ),
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
                        backgroundColor: colors.surfacePrimary.withAlpha(
                          isHovered ? 240 : 200,
                        ),
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
