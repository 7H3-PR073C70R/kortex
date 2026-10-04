import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/core/utils/uuid_utils.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
import 'package:kortex/src/features/decks/data/data_sources/decks_remote_data_source.dart';
import 'package:kortex/src/features/decks/data/models/deck_model.dart';
import 'package:kortex/src/features/decks/data/models/flashcard_model.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';
import 'package:kortex/src/features/decks/domain/repositories/decks_repository.dart';
import 'package:kortex/src/features/syllabot/domain/entities/execution_engine_type.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';
import 'package:kortex/src/features/syllabot/domain/use_cases/stream_syllabot_response_use_case.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';

/// Bottom sheet that lets the student pick which deck a forum solution should
/// be saved to, preview the card, and optionally navigate to create a new deck.
class ForumSaveFlashcardSheet extends HookWidget {
  const ForumSaveFlashcardSheet({
    required this.post,
    required this.reply,
    super.key,
  });

  final ForumPostEntity post;
  final ForumReplyEntity reply;

  static Future<DeckEntity?> show(
    BuildContext context, {
    required ForumPostEntity post,
    required ForumReplyEntity reply,
  }) {
    return showModalBottomSheet<DeckEntity?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.transparent,
      builder: (_) => ForumSaveFlashcardSheet(post: post, reply: reply),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

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
        if (!locator.isRegistered<DecksRepository>()) {
          isLoadingDecks.value = false;
          return;
        }
        final res = await locator<DecksRepository>().getUserDecks();
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
    }, []);

    Future<void> save() async {
      final target = selectedDeck.value;
      if (target == null) return;
      isSaving.value = true;
      AppFeedback.medium();
      try {
        final decksRepo = locator<DecksRepository>();
        final newCard = FlashcardEntity(
          id: UuidUtils.generate(),
          deckId: target.id,
          front: frontText,
          back: backText,
          frontLatex: post.latexContent,
          backLatex: reply.latexContent,
          sourceTopic: topicTag,
        );

        final existingRes = await decksRepo.getDeckCards(target.id);
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

        await decksRepo.updateDeckCards(target.id, [...existing, newCard]);

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

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 640,
          maxHeight: MediaQuery.sizeOf(context).height * 0.90,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.dialog),
            ),
            border: Border.all(
              color: colors.surfaceBorder.withValues(alpha: 0.5),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag handle
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
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? colors.surfacePrimary.withValues(alpha: 0.6)
                          : colors.surfaceSecondary.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      border: Border.all(
                        color: colors.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CardSide(
                          label: 'Front',
                          content: frontText,
                          icon: Icons.lightbulb_outline_rounded,
                          colors: colors,
                          typography: typography,
                        ),
                        Divider(
                          height: 20,
                          color: colors.surfaceBorder.withValues(alpha: 0.4),
                        ),
                        _CardSide(
                          label: 'Back',
                          content: backText,
                          icon: Icons.description_outlined,
                          colors: colors,
                          typography: typography,
                          maxLines: 4,
                        ),
                      ],
                    ),
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
                    _EmptyDecksHint(colors: colors, typography: typography)
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

class _CardSide extends StatelessWidget {
  const _CardSide({
    required this.label,
    required this.content,
    required this.icon,
    required this.colors,
    required this.typography,
    this.maxLines = 2,
  });

  final String label;
  final String content;
  final IconData icon;
  final AppThemeColorsExtension colors;
  final TypographyThemeExtension typography;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: colors.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: typography.caption.bold.copyWith(
                  color: colors.textSecondary,
                  fontSize: 10,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                content,
                style: typography.body.regular.copyWith(
                  color: colors.textPrimary,
                  fontSize: 13,
                  height: 1.4,
                ),
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyDecksHint extends StatelessWidget {
  const _EmptyDecksHint({required this.colors, required this.typography});
  final AppThemeColorsExtension colors;
  final TypographyThemeExtension typography;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceBorder.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colors.surfaceBorder.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 32, color: colors.textSecondary),
          const SizedBox(height: 8),
          Text(
            'No study decks yet',
            style: typography.body.semiBold.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Create a deck first so you can save solutions from the forum.',
            style: typography.caption.regular.copyWith(
              color: colors.textSecondary,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AI Thread → Deck generation sheet
// ---------------------------------------------------------------------------

/// Sheet that streams Syllabot AI to extract 5-8 Q&A pairs from the full
/// forum thread and saves them as a private study deck.
class ForumGenerateDeckSheet extends HookWidget {
  const ForumGenerateDeckSheet({
    required this.post,
    required this.replies,
    super.key,
  });

  final ForumPostEntity post;
  final List<ForumReplyEntity> replies;

  static Future<void> show(
    BuildContext context, {
    required ForumPostEntity post,
    required List<ForumReplyEntity> replies,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.transparent,
      builder: (_) =>
          ForumGenerateDeckSheet(post: post, replies: replies),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final isGenerating = useState<bool>(false);
    final isSaving = useState<bool>(false);
    final streamedText = useState<String>('');
    final generatedCards =
        useState<List<({String front, String back})>>([]);
    final errorMessage = useState<String?>(null);

    final topicTag =
        post.syllabusTag.isNotEmpty ? post.syllabusTag : post.track;

    String buildPrompt() {
      final sb = StringBuffer()
        ..writeln(
          'You are a smart flashcard generator. Convert the following forum discussion into 5-8 concise study flashcards in strict JSON format.\n',
        )
        ..writeln('Discussion Title: ${post.title}')
        ..writeln('Subject / Topic: $topicTag')
        ..writeln('\nThread Content:')
        ..writeln('Q: ${post.content.trim()}');

      final topReplies = replies
          .where((r) => r.isVerifiedSolution || r.upvotes > 0)
          .take(5)
          .toList();
      final sourcedReplies =
          topReplies.isNotEmpty ? topReplies : replies.take(5).toList();
      for (final r in sourcedReplies) {
        sb.writeln('A (by @${r.authorName}): ${r.content.trim()}');
      }

      sb.writeln('''
\nReturn ONLY valid JSON, no markdown, no explanation:
[
  {"front": "Concise question or term", "back": "Clear, exam-ready answer"},
  ...
]''');
      return sb.toString();
    }

    Future<void> generate() async {
      if (isGenerating.value) return;
      isGenerating.value = true;
      streamedText.value = '';
      generatedCards.value = [];
      errorMessage.value = null;
      AppFeedback.medium();

      try {
        final streamUseCase =
            locator.isRegistered<StreamSyllabotResponseUseCase>()
                ? locator<StreamSyllabotResponseUseCase>()
                : null;

        if (streamUseCase == null) {
          errorMessage.value =
              'AI service is not available. Please try again later.';
          return;
        }

        final buffer = StringBuffer();
        await for (final chunk in streamUseCase.call(
          prompt: buildPrompt(),
          sessionId: 'forum_deck_${post.id}',
          socraticMode: SocraticMode.directAnswer,
          preferredEngine: ExecutionEngineType.cloudRemote,
        )) {
          buffer.write(chunk);
          streamedText.value = buffer.toString();
        }

        final raw = buffer.toString().trim();
        final jsonStart = raw.indexOf('[');
        final jsonEnd = raw.lastIndexOf(']');
        if (jsonStart != -1 && jsonEnd != -1 && jsonEnd > jsonStart) {
          final cards = _parseCardsJson(raw.substring(jsonStart, jsonEnd + 1));
          if (cards.isEmpty) {
            errorMessage.value = 'Could not parse AI response. Try again.';
          } else {
            generatedCards.value = cards;
          }
        } else {
          errorMessage.value = 'Unexpected AI response format. Try again.';
        }
      } on Object catch (e) {
        errorMessage.value = 'Generation failed: $e';
      } finally {
        isGenerating.value = false;
      }
    }

    Future<void> saveDeck() async {
      final cards = generatedCards.value;
      if (cards.isEmpty) return;
      isSaving.value = true;
      AppFeedback.medium();

      try {
        final deckId = UuidUtils.generate();
        final flashcards = cards
            .map(
              (c) => FlashcardModel(
                id: UuidUtils.generate(),
                deckId: deckId,
                front: c.front,
                back: c.back,
                sourceTopic: topicTag,
              ),
            )
            .toList();

        final titleRaw = post.title;
        final deckTitle =
            titleRaw.length > 40 ? '${titleRaw.substring(0, 40)}…' : titleRaw;

        final deck = DeckModel(
          id: deckId,
          title: deckTitle,
          subject: topicTag.isNotEmpty ? topicTag : 'General',
          category: 'Forum Synthesis',
          totalCards: flashcards.length,
          dueCards: flashcards.length,
          masteryRate: 0,
          description:
              'Auto-generated from the forum discussion: "$titleRaw"',
          cards: flashcards,
          lastStudied: DateTime.now(),
        );

        if (locator.isRegistered<DecksRemoteDataSource>()) {
          await locator<DecksRemoteDataSource>().saveGeneratedDeck(
            deck: deck,
            cards: flashcards,
          );
        }

        if (context.mounted) {
          context.showSnackBar(
            message:
                '${flashcards.length} flashcards saved to "$deckTitle" ✨',
            type: SnackBarType.success,
          );
          Navigator.of(context).pop();
        }
      } on Object catch (e) {
        if (context.mounted) {
          context.showSnackBar(
            message: 'Failed to save deck: $e',
            type: SnackBarType.error,
          );
        }
      } finally {
        isSaving.value = false;
      }
    }

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 640,
          maxHeight: MediaQuery.sizeOf(context).height * 0.90,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.dialog),
            ),
            border: Border.all(
              color: colors.surfaceBorder.withValues(alpha: 0.5),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag handle
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
                          Icons.auto_awesome_rounded,
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
                              'Generate Flashcard Deck',
                              style: typography.title3.bold.copyWith(
                                color: colors.textPrimary,
                                fontSize: 17,
                              ),
                            ),
                            Text(
                              'Syllabot will turn this thread into study cards.',
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
                  const SizedBox(height: 8),

                  // Thread summary pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? colors.surfacePrimary.withValues(alpha: 0.5)
                          : colors.surfaceSecondary.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(AppRadius.badge),
                      border: Border.all(
                        color: colors.surfaceBorder.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.forum_outlined,
                          size: 14,
                          color: colors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${post.title} · ${replies.length} replies',
                            style: typography.caption.regular.copyWith(
                              color: colors.textSecondary,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Content area: idle / generating / results
                  if (generatedCards.value.isEmpty && !isGenerating.value) ...[
                    AppButton(
                      text: 'Generate Flashcards with Syllabot',
                      prefixIcon:
                          const Icon(Icons.auto_awesome_rounded),
                      isEnabled: !isGenerating.value,
                      onPressed: generate,
                    ),
                    if (errorMessage.value != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        errorMessage.value!,
                        style: typography.caption.regular.copyWith(
                          color: colors.error,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ] else if (isGenerating.value) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? colors.surfacePrimary.withValues(alpha: 0.5)
                            : colors.surfaceSecondary.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        border: Border.all(
                          color: colors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colors.primary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Syllabot is generating flashcards…',
                                style: typography.caption.bold.copyWith(
                                  color: colors.textPrimary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          if (streamedText.value.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              streamedText.value.length > 300
                                  ? '${streamedText.value.substring(0, 300)}…'
                                  : streamedText.value,
                              style: typography.caption.regular.copyWith(
                                color: colors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ] else ...[
                    // Card preview list
                    Text(
                      '${generatedCards.value.length} flashcards generated',
                      style: typography.caption.bold.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: generatedCards.value.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final card = generatedCards.value[i];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? colors.surfacePrimary.withValues(alpha: 0.5)
                                : colors.surfaceSecondary
                                    .withValues(alpha: 0.7),
                            borderRadius:
                                BorderRadius.circular(AppRadius.card),
                            border: Border.all(
                              color:
                                  colors.surfaceBorder.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${i + 1}. ${card.front}',
                                style: typography.body.semiBold.copyWith(
                                  color: colors.textPrimary,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                card.back,
                                style: typography.caption.regular.copyWith(
                                  color: colors.textSecondary,
                                  fontSize: 12,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    AppButton(
                      text:
                          'Save Deck (${generatedCards.value.length} cards)',
                      isLoading: isSaving.value,
                      prefixIcon: const Icon(Icons.save_rounded),
                      onPressed: saveDeck,
                    ),
                    const SizedBox(height: 10),
                    AppButton(
                      text: 'Regenerate',
                      variant: AppButtonVariant.secondary,
                      prefixIcon: const Icon(Icons.refresh_rounded),
                      isEnabled: !isSaving.value,
                      onPressed: generate,
                    ),
                  ],

                  const SizedBox(height: 10),
                  AppButton(
                    text: 'Close',
                    variant: AppButtonVariant.ghost,
                    onPressed: () => Navigator.of(context).pop(),
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

/// Minimal JSON parser for AI card output — no extra deps needed.
/// Expects: [{"front":"...","back":"..."},...]
List<({String front, String back})> _parseCardsJson(String json) {
  final results = <({String front, String back})>[];
  final frontPattern = RegExp(r'"front"\s*:\s*"((?:[^"\\]|\\.)*)"');
  final backPattern = RegExp(r'"back"\s*:\s*"((?:[^"\\]|\\.)*)"');

  final fronts =
      frontPattern.allMatches(json).map((m) => m.group(1) ?? '').toList();
  final backs =
      backPattern.allMatches(json).map((m) => m.group(1) ?? '').toList();

  final count = fronts.length < backs.length ? fronts.length : backs.length;
  for (var i = 0; i < count; i++) {
    final f = fronts[i].trim().replaceAll(r'\n', '\n').replaceAll(r'\"', '"');
    final b = backs[i].trim().replaceAll(r'\n', '\n').replaceAll(r'\"', '"');
    if (f.isNotEmpty && b.isNotEmpty) {
      results.add((front: f, back: b));
    }
  }
  return results;
}
