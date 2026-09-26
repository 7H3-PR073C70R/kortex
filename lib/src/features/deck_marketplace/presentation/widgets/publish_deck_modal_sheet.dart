import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/deck_marketplace/domain/services/content_safety_moderation_service.dart';
import 'package:kortex/src/features/decks/data/data_sources/decks_remote_data_source.dart';
import 'package:kortex/src/features/decks/data/models/deck_model.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class PublishDeckModalSheet extends HookWidget {
  const PublishDeckModalSheet({
    required this.onSubmit,
    super.key,
  });

  final void Function({
    required String title,
    required String subject,
    required String description,
    required String category,
    String syllabusTag,
    int totalCards,
    List<Map<String, dynamic>> cardsJson,
  })
  onSubmit;

  static Future<void> show(
    BuildContext context, {
    required void Function({
      required String title,
      required String subject,
      required String description,
      required String category,
      String syllabusTag,
      int totalCards,
      List<Map<String, dynamic>> cardsJson,
    })
    onSubmit,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.transparent,
      builder: (ctx) => PublishDeckModalSheet(onSubmit: onSubmit),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final titleController = useTextEditingController();
    final subjectController = useTextEditingController();
    final syllabusTagController = useTextEditingController();
    final descriptionController = useTextEditingController();
    final selectedCategory = useState<String>('STEM');

    final userDecks = useState<List<DeckModel>>([]);
    final isLoadingDecks = useState<bool>(true);
    final selectedDeck = useState<DeckModel?>(null);
    final isSubmitting = useState<bool>(false);

    const categories = [
      'STEM',
      'JAMB',
      'WAEC',
      'SAT',
      'Medicine',
      'Engineering',
      'General',
    ];

    useEffect(() {
      var isMounted = true;
      Future<void> fetchDecks() async {
        try {
          if (locator.isRegistered<DecksRemoteDataSource>()) {
            final decks = await locator<DecksRemoteDataSource>().getUserDecks();
            if (isMounted) {
              userDecks.value = decks;
              isLoadingDecks.value = false;
            }
          } else {
            if (isMounted) isLoadingDecks.value = false;
          }
        } on Object catch (_) {
          if (isMounted) isLoadingDecks.value = false;
        }
      }

      unawaited(fetchDecks());
      return () {
        isMounted = false;
      };
    }, []);

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Container(
          padding: EdgeInsets.only(
            top: 24,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 28,
          ),
          decoration: BoxDecoration(
            color: colors.surfacePrimary,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.dialog),
            ),
            border: Border.all(
              color: colors.primary.withAlpha(isDark ? 60 : 30),
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Grabber handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.textSecondary.withAlpha(80),
                      borderRadius: AppRadius.radiusMicro,
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Sheet Title
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colors.primary.withAlpha(30),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.share_rounded,
                        color: colors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Share Deck to Marketplace',
                      style: typography.title2.bold.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Deck Picker Dropdown
                Text(
                  'Select Deck from Your Library',
                  style: typography.caption.bold.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? colors.surfaceSecondary
                        : colors.surfacePrimary,
                    borderRadius: AppRadius.radiusCard,
                    border: Border.all(
                      color: colors.primary.withAlpha(isDark ? 50 : 25),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<DeckModel?>(
                      value: selectedDeck.value,
                      isExpanded: true,
                      dropdownColor: isDark
                          ? colors.surfaceSecondary
                          : colors.surfacePrimary,
                      hint: Row(
                        children: [
                          Icon(
                            Icons.style_rounded,
                            size: 18,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isLoadingDecks.value
                                ? 'Loading your decks...'
                                : 'Choose a deck to share...',
                            style: typography.caption.regular.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      icon: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: colors.primary,
                      ),
                      items: [
                        DropdownMenuItem<DeckModel?>(
                          child: Text(
                            '-- Custom / Manual Entry --',
                            style: typography.caption.bold.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                        ...userDecks.value.map(
                          (deck) => DropdownMenuItem<DeckModel?>(
                            value: deck,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.style_outlined,
                                  size: 16,
                                  color: colors.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${deck.title} (${deck.totalCards} cards)',
                                    style: typography.caption.bold.copyWith(
                                      color: colors.textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      onChanged: (deck) {
                        selectedDeck.value = deck;
                        if (deck != null) {
                          titleController.text = deck.title;
                          subjectController.text = deck.subject;
                          descriptionController.text = deck.description ?? '';
                          syllabusTagController.text =
                              deck.courseCode ?? 'General';
                          if (categories.contains(deck.category)) {
                            selectedCategory.value = deck.category;
                          }
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Deck Title
                AppTextField(
                  controller: titleController,
                  hintText: 'Deck Title (e.g. Organic Chemistry Reactions)',
                ),
                const SizedBox(height: 12),

                // Subject
                AppTextField(
                  controller: subjectController,
                  hintText: 'Subject / Track (e.g. Chemistry, JAMB)',
                ),
                const SizedBox(height: 12),

                // Syllabus Topic Module
                AppTextField(
                  controller: syllabusTagController,
                  hintText: 'Syllabus Topic (e.g. Stereochemistry, Mechanics)',
                ),
                const SizedBox(height: 12),

                // Description
                AppTextField(
                  controller: descriptionController,
                  hintText: 'Brief description of concepts covered...',
                  maxLines: 3,
                ),
                const SizedBox(height: 16),

                // Category Selection
                Text(
                  'Category / Track',
                  style: typography.caption.bold.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: categories.map((cat) {
                    final isSelected = selectedCategory.value == cat;
                    return ChoiceChip(
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.radiusBadge,
                      ),
                      label: Text(cat),
                      selected: isSelected,
                      onSelected: (val) {
                        if (val) {
                          unawaited(HapticFeedback.lightImpact());
                          selectedCategory.value = cat;
                        }
                      },
                      selectedColor: colors.primary.withAlpha(40),
                      labelStyle: typography.caption.bold.copyWith(
                        color: isSelected
                            ? colors.primary
                            : colors.textSecondary,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 22),

                // Submit Button
                PlatformHoverBuilder(
                  builder: (context, isHovered, child) => AnimatedContainer(
                    duration: AppMotion.snappy,
                    curve: AppMotion.easeOutCubic,
                    decoration: BoxDecoration(
                      borderRadius: AppRadius.radiusCard,
                      boxShadow: [
                        BoxShadow(
                          color: colors.black.withAlpha(
                            isHovered ? (isDark ? 60 : 30) : (isDark ? 40 : 20),
                          ),
                          blurRadius: isHovered ? 16 : 12,
                          offset: Offset(0, isHovered ? 6 : 4),
                        ),
                      ],
                    ),
                    child: ShrinkableButton(
                      onTap: isSubmitting.value
                          ? () {}
                          : () async {
                              final title = titleController.text.trim();
                              final subject = subjectController.text.trim();
                              final desc = descriptionController.text.trim();
                              final tag = syllabusTagController.text.trim();
                              if (title.isEmpty || subject.isEmpty) return;

                              isSubmitting.value = true;
                              unawaited(HapticFeedback.mediumImpact());

                              var cardsJson = <Map<String, dynamic>>[];
                              var totalCards =
                                  selectedDeck.value?.totalCards ?? 10;

                              if (selectedDeck.value != null) {
                                try {
                                  var cards = selectedDeck.value!.cards;
                                  if (cards.isEmpty &&
                                      locator
                                          .isRegistered<
                                            DecksRemoteDataSource
                                          >()) {
                                    cards =
                                        await locator<DecksRemoteDataSource>()
                                            .getDeckCards(
                                              selectedDeck.value!.id,
                                            );
                                  }
                                  cardsJson = cards
                                      .map((c) => c.toJson())
                                      .toList();
                                  if (cards.isNotEmpty) {
                                    totalCards = cards.length;
                                  }
                                } on Object catch (_) {}
                              }

                              // Perform content safety moderation & personal note stripping
                              const moderationService = ContentSafetyModerationService();
                              final moderationResult = moderationService.moderateAndSanitize(
                                title: title,
                                description: desc.isNotEmpty ? desc : 'Community Deck',
                                cardsJson: cardsJson,
                              );

                              if (!moderationResult.isApproved) {
                                isSubmitting.value = false;
                                if (context.mounted) {
                                  context.showSnackBar(
                                    message: moderationResult.flaggedReason ??
                                        'Content safety check failed.',
                                    type: SnackBarType.error,
                                  );
                                }
                                return;
                              }

                              onSubmit(
                                title: moderationResult.sanitizedTitle,
                                subject: subject,
                                description: moderationResult.sanitizedDescription,
                                category: selectedCategory.value,
                                syllabusTag: tag.isNotEmpty ? tag : 'General',
                                totalCards: totalCards,
                                cardsJson: moderationResult.sanitizedCards,
                              );
                              if (context.mounted) {
                                if (moderationResult.personalNotesStrippedCount > 0) {
                                  context.showSnackBar(
                                    message:
                                        'Deck shared! ${moderationResult.personalNotesStrippedCount} private note(s) auto-stripped.',
                                  );
                                }
                                Navigator.of(context).pop();
                              }
                            },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colors.primary,
                              colors.primary.withAlpha(isHovered ? 245 : 220),
                            ],
                          ),
                          borderRadius: AppRadius.radiusCard,
                        ),
                        child: Center(
                          child: isSubmitting.value
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      colors.white,
                                    ),
                                  ),
                                )
                              : Text(
                                  l10n.shareDeckTitle,
                                  style: typography.body.bold.copyWith(
                                    color: colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
