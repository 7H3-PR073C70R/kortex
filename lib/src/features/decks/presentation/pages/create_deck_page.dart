import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/services/file_picker_service.dart';
import 'package:kortex/src/core/utils/uuid_utils.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:kortex/src/features/decks/data/data_sources/decks_remote_data_source.dart';
import 'package:kortex/src/features/decks/data/models/deck_model.dart';
import 'package:kortex/src/features/decks/data/models/flashcard_model.dart';
import 'package:kortex/src/features/decks/domain/services/study_engine_router.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_event.dart';
import 'package:kortex/src/features/ingestion/data/services/local_ingestion_service.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';
import 'package:kortex/src/shared/widgets/app_liquid_glass_tab_bar.dart';
import 'package:kortex/src/shared/widgets/app_logo_loader.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class _DraftCard {
  const _DraftCard({required this.front, required this.back});
  final String front;
  final String back;
}

@RoutePage()
class CreateDeckPage extends HookWidget {
  const CreateDeckPage({
    this.courseId,
    this.courseCode,
    this.courseTitle,
    this.mappedSubject,
    super.key,
  });

  final String? courseId;
  final String? courseCode;
  final String? courseTitle;
  final String? mappedSubject;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final resolvedSubject =
        courseTitle ?? mappedSubject ?? courseCode ?? 'General Studies';
    final resolvedCourseCode = courseCode ?? 'GEN';

    final selectedTabIndex = useState<int>(0); // 0: Manual, 1: AI Prompt, 2: Document

    final titleController = useTextEditingController(
      text: courseCode != null && courseCode!.isNotEmpty
          ? '$courseCode Study Deck'
          : 'New Study Deck',
    );
    final descController = useTextEditingController();

    // Deck Cards List
    final deckCards = useState<List<_DraftCard>>([]);

    // Manual Card Entry
    final manualFrontController = useTextEditingController();
    final manualBackController = useTextEditingController();

    // AI Generation State
    final aiTopicController = useTextEditingController(
      text: courseTitle ?? resolvedCourseCode,
    );
    final aiCardCount = useState<int>(10);
    final isAiGenerating = useState<bool>(false);

    // Document Ingestion State
    final pickedDoc = useState<PickedDocument?>(null);
    final isDocIngesting = useState<bool>(false);
    final docStatus = useState<String>('');

    final isSaving = useState<bool>(false);

    // Add manual card to deck
    void addManualCard() {
      final front = manualFrontController.text.trim();
      final back = manualBackController.text.trim();

      if (front.isEmpty || back.isEmpty) {
        context.showSnackBar(
          message: 'Please provide both a Front concept and a Back answer/explanation.',
        );
        return;
      }

      AppFeedback.light();
      deckCards.value = [
        ...deckCards.value,
        _DraftCard(front: front, back: back),
      ];
      manualFrontController.clear();
      manualBackController.clear();
    }

    // AI Generation
    Future<void> generateCardsWithAi() async {
      final topic = aiTopicController.text.trim();
      if (topic.isEmpty) {
        context.showSnackBar(
          message: 'Please enter a topic or paste notes for AI generation.',
        );
        return;
      }

      isAiGenerating.value = true;
      AppFeedback.medium();

      try {
        final engine = locator.isRegistered<StudyEngineRouter>()
            ? locator<StudyEngineRouter>()
            : StudyEngineRouter();

        final result = await engine.generateStudyPack(
          topic: '$resolvedCourseCode: $topic',
          count: aiCardCount.value,
        );

        if (result.cards.isNotEmpty) {
          final newCards = result.cards
              .map((c) => _DraftCard(
                    front: c.front.replaceAll(RegExp(r'^On-Device:\s*', caseSensitive: false), ''),
                    back: c.back,
                  ))
              .toList();

          deckCards.value = [...deckCards.value, ...newCards];
          AppFeedback.heavy();

          if (context.mounted) {
            context.showSnackBar(
              message: 'Generated and added ${newCards.length} cards to your deck!',
              type: SnackBarType.success,
            );
          }
        } else {
          if (context.mounted) {
            context.showSnackBar(
              message: 'Could not generate flashcards. Please try adding manually.',
            );
          }
        }
      } on Object catch (e) {
        if (context.mounted) {
          context.showSnackBar(
            message: 'Generation notice: $e',
            type: SnackBarType.error,
          );
        }
      } finally {
        isAiGenerating.value = false;
      }
    }

    // Document Ingestion
    Future<void> ingestDocumentCards() async {
      final doc = pickedDoc.value;
      if (doc == null) {
        context.showSnackBar(
          message: 'Please select a lecture notes or study document first.',
        );
        return;
      }

      isDocIngesting.value = true;
      docStatus.value = 'Reading document text...';
      AppFeedback.medium();

      try {
        final ingestion = locator.isRegistered<LocalIngestionService>()
            ? locator<LocalIngestionService>()
            : LocalIngestionService();

        final extractedText = await ingestion.ingestBytes(
          bytes: doc.bytes,
          extension: doc.extension,
          filePath: doc.path,
        );

        if (extractedText.trim().isEmpty) {
          if (context.mounted) {
            context.showSnackBar(
              message: 'No readable text found in document. Please try a different file.',
            );
          }
          return;
        }

        docStatus.value = 'Synthesizing flashcards from document...';

        final engine = locator.isRegistered<StudyEngineRouter>()
            ? locator<StudyEngineRouter>()
            : StudyEngineRouter();

        final result = await engine.generateStudyPack(
          topic: '$resolvedCourseCode $resolvedSubject',
          count: 15,
          sourceText: extractedText,
        );

        if (result.cards.isNotEmpty) {
          final newCards = result.cards
              .map((c) => _DraftCard(
                    front: c.front.replaceAll(RegExp(r'^On-Device:\s*', caseSensitive: false), ''),
                    back: c.back,
                  ))
              .toList();

          deckCards.value = [...deckCards.value, ...newCards];
          AppFeedback.heavy();

          if (context.mounted) {
            context.showSnackBar(
              message: 'Synthesized ${newCards.length} cards from "${doc.name}"!',
              type: SnackBarType.success,
            );
          }
        } else {
          if (context.mounted) {
            context.showSnackBar(
              message: 'Could not extract flashcards from this document.',
            );
          }
        }
      } on Object catch (e) {
        if (context.mounted) {
          context.showSnackBar(
            message: 'Extraction error: $e',
            type: SnackBarType.error,
          );
        }
      } finally {
        isDocIngesting.value = false;
      }
    }

    // Save Deck to Repository
    Future<void> saveDeck() async {
      final title = titleController.text.trim();
      if (title.isEmpty) {
        context.showSnackBar(message: 'Please enter a title for your study deck.');
        return;
      }

      if (deckCards.value.isEmpty) {
        context.showSnackBar(
          message: 'Please add at least 1 flashcard to your deck before saving.',
        );
        return;
      }

      isSaving.value = true;
      AppFeedback.medium();

      try {
        final deckId = UuidUtils.generate();
        final flashcards = deckCards.value.map((draft) {
          return FlashcardModel(
            id: UuidUtils.generate(),
            deckId: deckId,
            front: draft.front,
            back: draft.back,
            sourceTopic: resolvedSubject,
            nextDueDate: DateTime.now(),
          );
        }).toList();

        final deckModel = DeckModel(
          id: deckId,
          title: title,
          subject: resolvedSubject,
          courseId: courseId,
          courseCode: resolvedCourseCode,
          totalCards: flashcards.length,
          dueCards: flashcards.length,
          masteryRate: 0,
          description: descController.text.trim().isNotEmpty
              ? descController.text.trim()
              : 'Study deck for $resolvedCourseCode ($resolvedSubject)',
          cards: flashcards,
          category: 'Course Study Deck',
        );

        if (locator.isRegistered<DecksRemoteDataSource>()) {
          await locator<DecksRemoteDataSource>().saveGeneratedDeck(
            deck: deckModel,
            cards: flashcards,
          );
        }

        if (locator.isRegistered<DecksBloc>()) {
          locator<DecksBloc>().add(const DecksRefreshed());
        }
        if (locator.isRegistered<DashboardBloc>()) {
          locator<DashboardBloc>().add(const DashboardRefreshed());
        }

        AppFeedback.heavy();

        if (context.mounted) {
          context.showSnackBar(
            message: 'Study Deck "$title" created with ${flashcards.length} card(s)!',
            type: SnackBarType.success,
          );
          Navigator.of(context).pop(true);
        }
      } on Object catch (e) {
        if (context.mounted) {
          context.showSnackBar(
            message: 'Failed to create study deck: $e',
            type: SnackBarType.error,
          );
        }
      } finally {
        isSaving.value = false;
      }
    }

    return Scaffold(
      backgroundColor: colors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: colors.backgroundPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: colors.textPrimary,
            size: 19,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          children: [
            Text(
              'Create Study Deck',
              style: typography.title3.bold.copyWith(
                color: colors.textPrimary,
                fontSize: 17,
              ),
            ),
            if (courseCode != null)
              Text(
                '$courseCode • $resolvedSubject',
                style: typography.footnote.regular.copyWith(
                  color: colors.textSecondary,
                  fontSize: 11.5,
                ),
              ),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Deck Info Card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isDark
                            ? colors.surfaceSecondary.withAlpha(120)
                            : colors.surfacePrimary,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDark
                              ? colors.surfaceBorderHighlight.withAlpha(50)
                              : colors.surfaceBorder.withAlpha(120),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.style_rounded, size: 18, color: colors.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Deck Details',
                                style: typography.callout.bold.copyWith(
                                  color: colors.textPrimary,
                                  fontSize: 14.5,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: colors.primary.withAlpha(isDark ? 40 : 20),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  resolvedCourseCode,
                                  style: typography.caption.bold.copyWith(
                                    color: colors.primary,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          AppTextField(
                            controller: titleController,
                            label: 'Deck Name',
                            hintText: 'e.g. $resolvedCourseCode Flashcards',
                          ),
                          const SizedBox(height: 12),
                          AppTextField(
                            controller: descController,
                            label: 'Description (Optional)',
                            hintText: 'e.g. Core concepts & formulas for quick recall',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Method Selector Tabs
                    AppLiquidGlassTabBar(
                      tabs: const [
                        'Manual Cards',
                        'AI Generator',
                        'Upload Notes',
                      ],
                      selectedIndex: selectedTabIndex.value,
                      onTabSelected: (index) {
                        AppFeedback.light();
                        selectedTabIndex.value = index;
                      },
                    ),
                    const SizedBox(height: 18),

                    // Tab 1: Manual Flashcard Entry
                    if (selectedTabIndex.value == 0) ...[
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: isDark
                              ? colors.surfaceSecondary.withAlpha(120)
                              : colors.surfacePrimary,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isDark
                                ? colors.surfaceBorderHighlight.withAlpha(50)
                                : colors.surfaceBorder.withAlpha(120),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add Card to Deck',
                              style: typography.callout.bold.copyWith(
                                color: colors.textPrimary,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 12),
                            AppTextField(
                              controller: manualFrontController,
                              label: 'Front (Question / Term / Concept)',
                              hintText: "e.g. State Le Chatelier's principle",
                              maxLines: 2,
                            ),
                            const SizedBox(height: 12),
                            AppTextField(
                              controller: manualBackController,
                              label: 'Back (Answer / Definition / Formula)',
                              hintText: 'e.g. When a system at equilibrium is subjected to change, it adjusts to counteract the change.',
                              maxLines: 3,
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: AppButton(
                                text: '+ Add Flashcard',
                                onPressed: addManualCard,
                                prefixIcon: const Icon(Icons.add_rounded, size: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ]
                    // Tab 2: AI Flashcard Generator
                    else if (selectedTabIndex.value == 1) ...[
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: isDark
                              ? colors.surfaceSecondary.withAlpha(120)
                              : colors.surfacePrimary,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isDark
                                ? colors.surfaceBorderHighlight.withAlpha(50)
                                : colors.surfaceBorder.withAlpha(120),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AI Flashcard Generator',
                              style: typography.callout.bold.copyWith(
                                color: colors.textPrimary,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Enter a topic or paste notes to automatically generate active recall flashcards.',
                              style: typography.footnote.regular.copyWith(
                                color: colors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 14),
                            AppTextField(
                              controller: aiTopicController,
                              label: 'Topic or Study Notes',
                              hintText: 'e.g. Organic chemistry reaction mechanisms and IUPAC naming',
                              maxLines: 3,
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Text(
                                  'Cards:',
                                  style: typography.caption.bold.copyWith(
                                    color: colors.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                ...[5, 10, 15, 20].map((count) {
                                  final isSelected = aiCardCount.value == count;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ShrinkableButton(
                                      onTap: () {
                                        AppFeedback.selection();
                                        aiCardCount.value = count;
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? colors.primary
                                              : (isDark ? colors.surfaceTertiary.withAlpha(80) : colors.surfaceSecondary),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '$count',
                                          style: typography.caption.bold.copyWith(
                                            color: isSelected ? colors.white : colors.textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: AppButton(
                                text: isAiGenerating.value ? 'Generating...' : '✨ Generate & Add Cards',
                                isLoading: isAiGenerating.value,
                                onPressed: isAiGenerating.value ? null : generateCardsWithAi,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ]
                    // Tab 3: Upload Study Document
                    else ...[
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: isDark
                              ? colors.surfaceSecondary.withAlpha(120)
                              : colors.surfacePrimary,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isDark
                                ? colors.surfaceBorderHighlight.withAlpha(50)
                                : colors.surfaceBorder.withAlpha(120),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Upload Lecture Notes / Slides',
                              style: typography.callout.bold.copyWith(
                                color: colors.textPrimary,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Extracts notes from PDF, PPTX, or TXT documents and synthesizes flashcards for this deck.',
                              style: typography.footnote.regular.copyWith(
                                color: colors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 14),
                            ShrinkableButton(
                              onTap: isDocIngesting.value
                                  ? null
                                  : () async {
                                      AppFeedback.light();
                                      final doc = await FilePickerService().pickStudyDocument(
                                        extensions: const ['pdf', 'png', 'jpg', 'jpeg', 'txt', 'pptx'],
                                      );
                                      if (doc != null) {
                                        pickedDoc.value = doc;
                                      }
                                    },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? colors.surfaceTertiary.withAlpha(60)
                                      : colors.surfaceSecondary.withAlpha(60),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: pickedDoc.value != null ? colors.primary : colors.surfaceBorder,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      pickedDoc.value != null
                                          ? Icons.check_circle_rounded
                                          : Icons.upload_file_rounded,
                                      size: 32,
                                      color: colors.primary,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      pickedDoc.value?.name ?? 'Select PDF, PPTX or Text Document',
                                      style: typography.caption.bold.copyWith(
                                        color: colors.textPrimary,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (isDocIngesting.value) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  AppLogoLoader(size: 14, color: colors.primary),
                                  const SizedBox(width: 8),
                                  Text(
                                    docStatus.value,
                                    style: typography.caption.regular.copyWith(
                                      color: colors.primary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: AppButton(
                                text: isDocIngesting.value ? 'Processing...' : 'Extract Flashcards',
                                isLoading: isDocIngesting.value,
                                onPressed: isDocIngesting.value || pickedDoc.value == null
                                    ? null
                                    : ingestDocumentCards,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Cards in this Deck Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Cards in Deck (${deckCards.value.length})',
                          style: typography.callout.bold.copyWith(
                            color: colors.textPrimary,
                            fontSize: 15,
                          ),
                        ),
                        if (deckCards.value.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              AppFeedback.light();
                              deckCards.value = [];
                            },
                            child: Text(
                              'Clear All',
                              style: typography.caption.bold.copyWith(
                                color: colors.error,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (deckCards.value.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? colors.surfaceSecondary.withAlpha(60)
                              : colors.surfacePrimary,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: colors.surfaceBorder.withAlpha(80),
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.style_outlined,
                              size: 28,
                              color: colors.textMuted,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'No flashcards in this deck yet',
                              style: typography.caption.bold.copyWith(
                                color: colors.textPrimary,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Add cards manually or generate them with AI above.',
                              style: typography.footnote.regular.copyWith(
                                color: colors.textSecondary,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: deckCards.value.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final card = deckCards.value[index];
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? colors.surfaceSecondary.withAlpha(100)
                                  : colors.surfacePrimary,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: colors.surfaceBorder.withAlpha(80),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: colors.primary.withAlpha(30),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: typography.caption.bold.copyWith(
                                        color: colors.primary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        card.front,
                                        style: typography.caption.bold.copyWith(
                                          color: colors.textPrimary,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        card.back,
                                        style: typography.footnote.regular.copyWith(
                                          color: colors.textSecondary,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.delete_outline_rounded,
                                    size: 18,
                                    color: colors.error.withAlpha(180),
                                  ),
                                  onPressed: () {
                                    AppFeedback.light();
                                    final list = List<_DraftCard>.from(deckCards.value)..removeAt(index);
                                    deckCards.value = list;
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),

            // Persistent Bottom Action Bar
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
                border: Border(top: BorderSide(color: colors.surfaceBorder)),
              ),
              child: AppButton(
                text: isSaving.value
                    ? 'Creating Deck...'
                    : 'Create Deck (${deckCards.value.length} Cards)',
                isLoading: isSaving.value,
                isEnabled: !isSaving.value && deckCards.value.isNotEmpty,
                onPressed: isSaving.value ? null : saveDeck,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
