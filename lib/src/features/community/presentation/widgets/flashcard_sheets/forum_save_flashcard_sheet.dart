import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/utils/uuid_utils.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
import 'package:kortex/src/features/community/presentation/widgets/flashcard_sheets/save_flashcard_preview_card.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';
import 'package:kortex/src/features/decks/domain/repositories/decks_repository.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_sheet.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';

/// Bottom sheet that lets the student pick which deck a forum solution should
/// be saved to, preview the card, and optionally navigate to create a new deck.
class ForumSaveFlashcardSheet extends HookWidget {
  const ForumSaveFlashcardSheet({
    required this.post,
    required this.reply,
    this.decksRepository,
    super.key,
  });

  final ForumPostEntity post;
  final ForumReplyEntity reply;
  final DecksRepository? decksRepository;

  static Future<DeckEntity?> show(
    BuildContext context, {
    required ForumPostEntity post,
    required ForumReplyEntity reply,
    DecksRepository? decksRepository,
  }) {
    return AppAdaptiveSheet.showModal<DeckEntity?>(
      context: context,
      maxWidth: 600,
      builder: (_) => ForumSaveFlashcardSheet(
        post: post,
        reply: reply,
        decksRepository: decksRepository,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final effectiveDecksRepo = useMemoized(
      () =>
          decksRepository ??
          (locator.isRegistered<DecksRepository>()
              ? locator<DecksRepository>()
              : null),
      [decksRepository],
    );

    final frontText = post.title.trim();
    final authorCredit = reply.authorName.isNotEmpty
        ? '\n\n— Verified Solution by @${reply.authorName}'
        : '';
    final backText = '${reply.content.trim()}$authorCredit';
    final topicTag =
        post.syllabusTag.isNotEmpty ? post.syllabusTag : post.track;

    final isLoadingDecks = useState<bool>(true);
    final isSaving = useState<bool>(false);
    final decks = useState<List<DeckEntity>>([]);
    final selectedDeck = useState<DeckEntity?>(null);

    useEffect(() {
      Future<void> load() async {
        if (effectiveDecksRepo == null) {
          isLoadingDecks.value = false;
          return;
        }
        final res = await effectiveDecksRepo.getUserDecks();
        res.fold(
          (_) {},
          (all) {
            decks.value = all;
            final topicLower = topicTag.toLowerCase();
            DeckEntity? best;
            for (final d in all) {
              final tl = d.title.toLowerCase();
              final sl = d.subject.toLowerCase();
              if (tl.contains('forum') ||
                  tl.contains('verified') ||
                  tl.contains('saved') ||
                  sl.contains(topicLower) ||
                  tl.contains(topicLower)) {
                best = d;
                break;
              }
            }
            selectedDeck.value = best ?? (all.isNotEmpty ? all.first : null);
          },
        );
        isLoadingDecks.value = false;
      }

      unawaited(load());
      return null;
    }, [effectiveDecksRepo]);

    Future<void> save() async {
      final target = selectedDeck.value;
      if (target == null || effectiveDecksRepo == null) return;
      isSaving.value = true;
      AppFeedback.medium();
      try {
        final newCard = FlashcardEntity(
          id: UuidUtils.generate(),
          deckId: target.id,
          front: frontText,
          back: backText,
          frontLatex: post.latexContent,
          backLatex: reply.latexContent,
          sourceTopic: topicTag,
        );

        final existingRes = await effectiveDecksRepo.getDeckCards(target.id);
        final existing =
            existingRes.fold((_) => <FlashcardEntity>[], (c) => c);

        final isDuplicate = existing
            .any((c) => c.front == newCard.front && c.back == newCard.back);
        if (isDuplicate) {
          if (context.mounted) {
            context.showSnackBar(
              message: 'This solution is already in "${target.title}" 💡',
            );
            Navigator.of(context).pop<DeckEntity?>();
          }
          return;
        }

        await effectiveDecksRepo.updateDeckCards(target.id, [...existing, newCard]);

        if (context.mounted) {
          context.showSnackBar(
            message: 'Saved to "${target.title}" ✨',
            type: SnackBarType.success,
          );
          Navigator.of(context).pop<DeckEntity?>(target);
        }
      } on Object catch (e) {
        if (context.mounted) {
          context.showSnackBar(
            message: 'Failed to save flashcard: $e',
            type: SnackBarType.error,
          );
        }
      } finally {
        isSaving.value = false;
      }
    }

    final isDesktop = AppAdaptiveSheet.isDesktopOrWeb(context);

    return Align(
      alignment: isDesktop ? Alignment.center : Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.sizeOf(context).height * (isDesktop ? 0.82 : 0.90),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
            borderRadius: isDesktop
                ? BorderRadius.circular(AppRadius.dialog)
                : const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.dialog),
                  ),
            border: Border.all(
              color: colors.surfaceBorder.withValues(alpha: 0.5),
            ),
            boxShadow: isDesktop
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 28,
                      offset: const Offset(0, 14),
                    ),
                  ]
                : null,
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, isDesktop ? 24 : 12, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag handle
                  if (!isDesktop) ...[
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.surfaceBorder,
                          borderRadius: BorderRadius.circular(AppRadius.badge),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.badge),
                        ),
                        child: Icon(
                          Icons.style_rounded,
                          size: 20,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Save to Flashcard',
                              style: typography.title3.bold.copyWith(
                                color: colors.textPrimary,
                                fontSize: 17,
                              ),
                            ),
                            Text(
                              'Choose the deck to save this solution into.',
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
                  const SizedBox(height: 20),

                  // Card preview
                  SaveFlashcardCardPreview(
                    frontText: frontText,
                    backText: backText,
                  ),
                  const SizedBox(height: 20),

                  // Deck picker label
                  Text(
                    'Select Deck',
                    style: typography.caption.bold.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (isLoadingDecks.value)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: CircularProgressIndicator.adaptive(),
                      ),
                    )
                  else if (decks.value.isEmpty)
                    EmptyDecksHint(colors: colors, typography: typography)
                  else
                    Column(
                      children: [
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: decks.value.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final deck = decks.value[i];
                            final isSelected =
                                selectedDeck.value?.id == deck.id;
                            return GestureDetector(
                              onTap: () {
                                AppFeedback.selection();
                                selectedDeck.value = deck;
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? colors.primary.withValues(alpha: 0.1)
                                      : (isDark
                                          ? colors.surfacePrimary
                                              .withValues(alpha: 0.4)
                                          : colors.surfaceSecondary
                                              .withValues(alpha: 0.8)),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.card,
                                  ),
                                  border: Border.all(
                                    color: isSelected
                                        ? colors.primary
                                            .withValues(alpha: 0.5)
                                        : colors.surfaceBorder
                                            .withValues(alpha: 0.3),
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? colors.primary
                                                .withValues(alpha: 0.18)
                                            : colors.surfaceBorder
                                                .withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.badge,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.layers_rounded,
                                        size: 16,
                                        color: isSelected
                                            ? colors.primary
                                            : colors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            deck.title,
                                            style: typography.body.semiBold
                                                .copyWith(
                                              color: isSelected
                                                  ? colors.primary
                                                  : colors.textPrimary,
                                              fontSize: 13,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            '${deck.subject} · ${deck.totalCards} cards',
                                            style:
                                                typography.caption.regular
                                                    .copyWith(
                                              color: colors.textSecondary,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      Icon(
                                        Icons.check_circle_rounded,
                                        size: 18,
                                        color: colors.primary,
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        // Create new deck shortcut
                        GestureDetector(
                          onTap: () async {
                            AppFeedback.selection();
                            Navigator.of(context).pop<DeckEntity?>();
                            await context.router.push(
                              CreateDeckRoute(
                                mappedSubject: topicTag,
                                courseTitle: topicTag,
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              borderRadius:
                                   BorderRadius.circular(AppRadius.card),
                              border: Border.all(
                                color: colors.primary.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_rounded,
                                  size: 16,
                                  color: colors.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Create New Deck',
                                  style: typography.caption.bold.copyWith(
                                    color: colors.primary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 20),

                  // Save CTA
                  AppButton(
                    text: selectedDeck.value != null
                        ? 'Save to "${selectedDeck.value!.title}"'
                        : 'Save Flashcard',
                    isLoading: isSaving.value,
                    isEnabled: selectedDeck.value != null && !isSaving.value,
                    prefixIcon: const Icon(Icons.bookmark_add_rounded),
                    onPressed: save,
                  ),
                  const SizedBox(height: 10),
                  AppButton(
                    text: 'Cancel',
                    variant: AppButtonVariant.ghost,
                    onPressed: () => Navigator.of(context).pop<DeckEntity?>(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
