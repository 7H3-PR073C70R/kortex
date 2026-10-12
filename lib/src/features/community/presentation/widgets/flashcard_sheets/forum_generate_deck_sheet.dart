import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/utils/uuid_utils.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
import 'package:kortex/src/features/community/presentation/widgets/flashcard_sheets/forum_deck_ai_parser.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';
import 'package:kortex/src/features/decks/domain/repositories/decks_repository.dart';
import 'package:kortex/src/features/syllabot/domain/entities/execution_engine_type.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';
import 'package:kortex/src/features/syllabot/domain/use_cases/stream_syllabot_response_use_case.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_sheet.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';

/// Sheet that streams Syllabot AI to extract 5-8 Q&A pairs from the full
/// forum thread and saves them as a private study deck.
class ForumGenerateDeckSheet extends HookWidget {
  const ForumGenerateDeckSheet({
    required this.post,
    required this.replies,
    this.streamSyllabotResponseUseCase,
    this.decksRepository,
    super.key,
  });

  final ForumPostEntity post;
  final List<ForumReplyEntity> replies;
  final StreamSyllabotResponseUseCase? streamSyllabotResponseUseCase;
  final DecksRepository? decksRepository;

  static Future<void> show(
    BuildContext context, {
    required ForumPostEntity post,
    required List<ForumReplyEntity> replies,
    StreamSyllabotResponseUseCase? streamSyllabotResponseUseCase,
    DecksRepository? decksRepository,
  }) {
    return AppAdaptiveSheet.showModal<void>(
      context: context,
      maxWidth: 600,
      builder: (_) => ForumGenerateDeckSheet(
        post: post,
        replies: replies,
        streamSyllabotResponseUseCase: streamSyllabotResponseUseCase,
        decksRepository: decksRepository,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final effectiveStreamUseCase = useMemoized(
      () =>
          streamSyllabotResponseUseCase ??
          (locator.isRegistered<StreamSyllabotResponseUseCase>()
              ? locator<StreamSyllabotResponseUseCase>()
              : null),
      [streamSyllabotResponseUseCase],
    );

    final effectiveDecksRepo = useMemoized(
      () =>
          decksRepository ??
          (locator.isRegistered<DecksRepository>()
              ? locator<DecksRepository>()
              : null),
      [decksRepository],
    );

    final isGenerating = useState<bool>(false);
    final isSaving = useState<bool>(false);
    final streamedText = useState<String>('');
    final generatedCards =
        useState<List<({String front, String back})>>([]);
    final errorMessage = useState<String?>(null);

    final topicTag =
        post.syllabusTag.isNotEmpty ? post.syllabusTag : post.track;

    Future<void> generate() async {
      if (isGenerating.value) return;
      isGenerating.value = true;
      streamedText.value = '';
      generatedCards.value = [];
      errorMessage.value = null;
      AppFeedback.medium();

      try {
        if (effectiveStreamUseCase == null) {
          errorMessage.value =
              'AI service is not available. Please try again later.';
          return;
        }

        final prompt = ForumDeckAiParser.buildPrompt(
          post: post,
          replies: replies,
          topicTag: topicTag,
        );

        final buffer = StringBuffer();
        await for (final chunk in effectiveStreamUseCase.call(
          prompt: prompt,
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
          final cards =
              ForumDeckAiParser.parseCardsJson(raw.substring(jsonStart, jsonEnd + 1));
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
      if (cards.isEmpty || effectiveDecksRepo == null) return;
      isSaving.value = true;
      AppFeedback.medium();

      try {
        final deckId = UuidUtils.generate();
        final flashcards = cards
            .map(
              (c) => FlashcardEntity(
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

        final deck = DeckEntity(
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

        await effectiveDecksRepo.saveGeneratedDeck(
          deck: deck,
          cards: flashcards,
        );

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
                      prefixIcon: const Icon(Icons.auto_awesome_rounded),
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
                                : colors.surfaceSecondary.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            border: Border.all(
                              color: colors.surfaceBorder.withValues(alpha: 0.3),
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
