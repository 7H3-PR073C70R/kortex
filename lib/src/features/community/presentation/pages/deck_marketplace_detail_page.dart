import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/domain/entities/shared_deck_entity.dart';
import 'package:kortex/src/features/community/domain/use_cases/clone_shared_deck_use_case.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

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

    final isCloning = useState<bool>(false);

    Future<void> handleClone() async {
      isCloning.value = true;
      try {
        final useCase = locator<CloneSharedDeckUseCase>();
        final res = await useCase(deck.id);
        isCloning.value = false;

        if (!context.mounted) return;
        res.fold(
          (failure) {
            context.showSnackBar(
              message: failure.message ?? l10n.marketplaceCloneFailed,
              type: SnackBarType.error,
            );
          },
          (clonedDeck) {
            context.showSnackBar(
              message: l10n.marketplaceCloneSuccess,
            );
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

    return Scaffold(
      backgroundColor: isDark
          ? colors.backgroundPrimary
          : colors.surfacePrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          deck.title,
          style: typography.title3.bold.copyWith(
            color: colors.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: colors.textPrimary,
          ),
          onPressed: () => unawaited(context.router.maybePop()),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: ShrinkableButton(
            onTap: isCloning.value ? null : handleClone,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colors.primary,
                    colors.primary.withAlpha(220),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: isCloning.value
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.copy_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.cloneDeckButton,
                            style: typography.body.bold.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Deck Banner info
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colors.primary.withAlpha(isDark ? 50 : 25),
                      colors.syllabotAccent.withAlpha(isDark ? 40 : 20),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: colors.primary.withAlpha(isDark ? 60 : 35),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primary.withAlpha(40),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            deck.category.toUpperCase(),
                            style: typography.caption.bold.copyWith(
                              color: colors.primary,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 18,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              deck.rating.toStringAsFixed(1),
                              style: typography.caption.bold.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      deck.title,
                      style: typography.title2.bold.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${deck.subject} • Created by ${deck.ownerName}',
                      style: typography.footnote.regular.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    if (deck.description != null &&
                        deck.description!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        deck.description!,
                        style: typography.footnote.regular.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Cards Preview Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Preview Cards (${deck.totalCards})',
                    style: typography.footnote.bold.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  Text(
                    '${deck.downloadsCount} downloads',
                    style: typography.caption.medium.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Cards List
              if (deck.cards.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Full deck containing ${deck.totalCards} cards '
                      'ready to clone.',
                      style: typography.footnote.medium.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                )
              else
                ...deck.cards.take(5).map((card) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? colors.surfaceSecondary
                          : colors.surfaceSecondary.withAlpha(100),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: colors.primary.withAlpha(30),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Q: ${card.front}',
                          style: typography.footnote.bold.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'A: ${card.back}',
                          style: typography.caption.regular.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}
