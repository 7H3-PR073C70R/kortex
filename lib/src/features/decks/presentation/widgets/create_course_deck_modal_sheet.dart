import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/decks/data/data_sources/decks_remote_data_source.dart';
import 'package:kortex/src/features/decks/data/models/deck_model.dart';
import 'package:kortex/src/features/decks/data/models/flashcard_model.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_event.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/latex_rich_viewer.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';

class CreateCourseDeckModalSheet extends HookWidget {
  const CreateCourseDeckModalSheet({
    required this.courseId,
    required this.courseCode,
    required this.courseTitle,
    super.key,
  });

  final String courseId;
  final String courseCode;
  final String courseTitle;

  static Future<void> show(
    BuildContext context, {
    required String courseId,
    required String courseCode,
    required String courseTitle,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CreateCourseDeckModalSheet(
        courseId: courseId,
        courseCode: courseCode,
        courseTitle: courseTitle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final titleController = useTextEditingController(
      text: '$courseCode Core Concepts',
    );
    final descController = useTextEditingController();
    final frontController = useTextEditingController();
    final backController = useTextEditingController();

    final addedCards = useState<List<Map<String, String>>>([]);
    final isSubmitting = useState<bool>(false);

    void addFlashcard() {
      final front = frontController.text.trim();
      final back = backController.text.trim();

      if (front.isEmpty || back.isEmpty) {
        context.showSnackBar(
          message: 'Please enter both question (front) and answer (back)',
        );
        return;
      }

      AppFeedback.light();
      addedCards.value = [
        ...addedCards.value,
        {'front': front, 'back': back},
      ];
      frontController.clear();
      backController.clear();
    }

    Future<void> saveDeck() async {
      final title = titleController.text.trim();
      if (title.isEmpty) {
        context.showSnackBar(
          message: 'Please provide a deck title',
        );
        return;
      }

      isSubmitting.value = true;
      AppFeedback.medium();

      try {
        final deckId = 'deck_${DateTime.now().millisecondsSinceEpoch}';

        final flashcards =
            addedCards.value.asMap().entries.map<FlashcardModel>((entry) {
          final idx = entry.key;
          final item = entry.value;
          return FlashcardModel(
            id: 'card_${deckId}_$idx',
            deckId: deckId,
            front: item['front']!,
            back: item['back']!,
            nextDueDate: DateTime.now(),
            sourceTopic: courseTitle,
          );
        }).toList();

        final deckModel = DeckModel(
          id: deckId,
          title: title,
          subject: courseTitle,
          totalCards: flashcards.length,
          dueCards: flashcards.length,
          masteryRate: 0,
          category: 'Course Review',
          description: descController.text.trim().isNotEmpty
              ? descController.text.trim()
              : 'Flashcards created for $courseCode',
          cards: flashcards,
          courseId: courseId,
          courseCode: courseCode,
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

        if (context.mounted) {
          Navigator.of(context).pop();
          context.showSnackBar(
            message: 'Deck created successfully with ${flashcards.length} card(s)!',
            type: SnackBarType.success,
          );
        }
      } on Object catch (err) {
        if (context.mounted) {
          context.showSnackBar(
            message: 'Failed to create deck: $err',
            type: SnackBarType.error,
          );
        }
      } finally {
        isSubmitting.value = false;
      }
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: BoxDecoration(
          color: colors.surfacePrimary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: isDark
                ? colors.surfaceBorderHighlight.withAlpha(70)
                : colors.surfaceBorder,
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.surfaceBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'New Study Deck',
                          style: typography.title2.bold.copyWith(
                            color: colors.textPrimary,
                            fontSize: 19,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$courseCode • $courseTitle',
                          style: typography.caption.regular.copyWith(
                            color: colors.primary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: colors.textSecondary,
                        size: 20,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Deck Title
                Text(
                  'Deck Title',
                  style: typography.footnote.bold.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: titleController,
                  style: typography.body.medium.copyWith(
                    color: colors.textPrimary,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. $courseCode Key Formulas',
                    filled: true,
                    fillColor: isDark
                        ? colors.surfaceSecondary.withAlpha(140)
                        : colors.surfaceSecondary.withAlpha(60),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colors.surfaceBorder),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Deck Description
                Text(
                  'Description (Optional)',
                  style: typography.footnote.bold.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: descController,
                  style: typography.body.medium.copyWith(
                    color: colors.textPrimary,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Brief summary of topics covered',
                    filled: true,
                    fillColor: isDark
                        ? colors.surfaceSecondary.withAlpha(140)
                        : colors.surfaceSecondary.withAlpha(60),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colors.surfaceBorder),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Add Flashcards Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Flashcards (${addedCards.value.length})',
                      style: typography.callout.bold.copyWith(
                        color: colors.textPrimary,
                        fontSize: 15,
                      ),
                    ),
                    if (addedCards.value.isNotEmpty)
                      Text(
                        r'LaTeX supported \(...\)',
                        style: typography.caption.regular.copyWith(
                          color: colors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                // Added Cards Preview List
                if (addedCards.value.isNotEmpty) ...[
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      itemCount: addedCards.value.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (ctx, index) {
                        final card = addedCards.value[index];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? colors.surfaceSecondary.withAlpha(150)
                                : colors.surfaceSecondary.withAlpha(80),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: colors.surfaceBorder.withAlpha(100),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: colors.primary.withAlpha(30),
                                  shape: BoxShape.circle,
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
                                    LatexRichViewer(
                                      text: card['front']!,
                                      style: typography.footnote.bold.copyWith(
                                        color: colors.textPrimary,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    LatexRichViewer(
                                      text: card['back']!,
                                      style: typography.caption.regular.copyWith(
                                        color: colors.textSecondary,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.remove_circle_outline_rounded,
                                  size: 18,
                                  color: colors.error.withAlpha(180),
                                ),
                                onPressed: () {
                                  addedCards.value = List<Map<String, String>>.from(
                                    addedCards.value,
                                  )..removeAt(index);
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // New Card Input Box
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? colors.surfaceSecondary.withAlpha(80)
                        : colors.surfaceSecondary.withAlpha(40),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colors.primary.withAlpha(isDark ? 60 : 35),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Front (Question / Concept)',
                        style: typography.caption.bold.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: frontController,
                        style: typography.body.medium.copyWith(
                          color: colors.textPrimary,
                          fontSize: 13.5,
                        ),
                        decoration: InputDecoration(
                          hintText: 'e.g. What is the formula for quadratic roots?',
                          isDense: true,
                          filled: true,
                          fillColor: colors.surfacePrimary,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: colors.surfaceBorder),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Back (Answer / Derivation)',
                        style: typography.caption.bold.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: backController,
                        style: typography.body.medium.copyWith(
                          color: colors.textPrimary,
                          fontSize: 13.5,
                        ),
                        decoration: InputDecoration(
                          hintText: r'e.g. \(x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}\)',
                          isDense: true,
                          filled: true,
                          fillColor: colors.surfacePrimary,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: colors.surfaceBorder),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: addFlashcard,
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Add Card to Deck'),
                          style: TextButton.styleFrom(
                            foregroundColor: colors.primary,
                            textStyle: typography.caption.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // Save Action Button
                AppButton(
                  text: 'Create Study Deck',
                  isLoading: isSubmitting.value,
                  onPressed: isSubmitting.value ? null : saveDeck,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
