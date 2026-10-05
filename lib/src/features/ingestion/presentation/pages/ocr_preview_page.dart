import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/ingestion/data/models/generated_deck_preview_model.dart';
import 'package:kortex/src/features/ingestion/domain/entities/ocr_extraction_entity.dart';
import 'package:kortex/src/features/ingestion/presentation/widgets/ocr_latex_live_editor.dart';
import 'package:kortex/src/features/syllabot/domain/use_cases/generate_document_embeddings_use_case.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_app_bar.dart';
import 'package:kortex/src/shared/widgets/app_breadcrumbs.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

@RoutePage()
class OcrPreviewPage extends HookWidget {
  const OcrPreviewPage({
    required this.documentId,
    required this.filename,
    required this.snippets,
    this.courseId,
    this.courseCode,
    this.courseTitle,
    super.key,
  });

  final String documentId;
  final String filename;
  final List<OcrExtractionEntity> snippets;
  final String? courseId;
  final String? courseCode;
  final String? courseTitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final currentSnippets = useState<List<OcrExtractionEntity>>(
      List.from(snippets),
    );

    final availableImageUrls = useMemoized(() {
      final urls = <String>{};
      for (final s in currentSnippets.value) {
        if (s.imageUrl != null && s.imageUrl!.trim().isNotEmpty) {
          urls.add(s.imageUrl!.trim());
        }
      }
      return urls.toList();
    }, [currentSnippets.value]);

    void handleGenerateCards() {
      if (currentSnippets.value.isEmpty) return;

      final previewCards = currentSnippets.value.map((s) {
        return GeneratedCardPreviewItem(
          front: s.topic.isNotEmpty ? s.topic : 'Core Concept',
          back: s.rawText,
          backLatex: s.latexContent,
          imageUrl: s.imageUrl,
          topic: s.topic,
        );
      }).toList();

      final resolvedSubject =
          courseTitle ??
          (courseCode != null && courseCode!.isNotEmpty
              ? '$courseCode Review'
              : 'Study Review');

      // Trigger background RAG vector embeddings indexing with curated/edited text
      final combinedText = currentSnippets.value
          .map((s) => s.rawText)
          .where((t) => t.trim().isNotEmpty)
          .join('\n\n');
      if (combinedText.isNotEmpty &&
          locator.isRegistered<GenerateDocumentEmbeddingsUseCase>()) {
        unawaited(
          locator<GenerateDocumentEmbeddingsUseCase>()(
            documentId: documentId,
            rawText: combinedText,
            metadata: {
              'filename': filename,
              'courseCode': courseCode ?? 'GENERAL',
              'courseTitle': resolvedSubject,
              'extractedSnippetsCount': currentSnippets.value.length,
            },
          ),
        );
      }

      unawaited(
        context.router.push(
          GeneratedCardsReviewRoute(
            documentId: documentId,
            deckTitle: filename.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), ''),
            subject: resolvedSubject,
            initialCards: previewCards,
            rawSnippets: currentSnippets.value,
            courseId: courseId,
            courseCode: courseCode,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colors.backgroundPrimary,
      appBar: AppAdaptiveAppBar(
        backgroundColor: colors.backgroundPrimary,
        titleText: l10n.ocrPreviewTitle,
        breadcrumbs: [
          AppBreadcrumbItem(
            label: 'Ingestion',
            onTap: () => context.router.maybePop(),
          ),
          AppBreadcrumbItem(label: l10n.ocrPreviewTitle),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: [
                // Extracted Snippets Count Banner with Add Card Action
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withAlpha(isDark ? 40 : 25),
                    borderRadius: AppRadius.radiusCard,
                    border: Border.all(
                      color: colors.primary.withAlpha(isDark ? 80 : 50),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        color: colors.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.extractedSnippetsCount(
                            currentSnippets.value.length,
                          ),
                          style: typography.footnote.bold.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      PlatformHoverBuilder(
                        builder: (context, isHovered, child) {
                          return AnimatedContainer(
                            duration: AppMotion.snappy,
                            curve: AppMotion.easeOutCubic,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: isHovered
                                  ? colors.primary.withAlpha(isDark ? 50 : 35)
                                  : colors.primary.withAlpha(isDark ? 30 : 20),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.badge),
                              border: Border.all(
                                color: colors.primary.withAlpha(
                                  isDark ? 90 : 60,
                                ),
                              ),
                            ),
                            child: InkWell(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.badge),
                              onTap: () {
                                final updatedList =
                                    List<OcrExtractionEntity>.from(
                                  currentSnippets.value,
                                )..add(
                                    OcrExtractionEntity(
                                      id: 'card_${DateTime.now().millisecondsSinceEpoch}',
                                      documentId: documentId,
                                      rawText: '',
                                      topic:
                                          'Card ${currentSnippets.value.length + 1}',
                                    ),
                                  );
                                currentSnippets.value = updatedList;
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.add_rounded,
                                    size: 15,
                                    color: colors.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Add Card',
                                    style: typography.caption.bold.copyWith(
                                      color: colors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Live Editors List or Empty State
                Expanded(
                  child: currentSnippets.value.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.auto_stories_outlined,
                                  size: 56,
                                  color: colors.textSecondary.withAlpha(120),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No study cards yet',
                                  style: typography.title3.bold.copyWith(
                                    color: colors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Tap "Add Card" above to create study flashcards from your material.',
                                  textAlign: TextAlign.center,
                                  style: typography.footnote.regular.copyWith(
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: currentSnippets.value.length,
                          itemBuilder: (context, index) {
                            final snippet = currentSnippets.value[index];
                            return OcrLatexLiveEditor(
                              key: ValueKey(
                                snippet.id.isNotEmpty
                                    ? snippet.id
                                    : 'ocr_snippet_$index',
                              ),
                              snippet: snippet,
                              cardNumber: index + 1,
                              availableImageUrls: availableImageUrls,
                              onChanged: (updated) {
                                final updatedList =
                                    List<OcrExtractionEntity>.from(
                                  currentSnippets.value,
                                );
                                updatedList[index] = updated;
                                currentSnippets.value = updatedList;
                              },
                              onDelete: () {
                                final updatedList =
                                    List<OcrExtractionEntity>.from(
                                  currentSnippets.value,
                                )..removeAt(index);
                                currentSnippets.value = updatedList;
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: colors.backgroundPrimary.withValues(alpha: 0.95),
            border: Border(
              top: BorderSide(
                color: colors.primary.withAlpha(isDark ? 35 : 15),
              ),
            ),
          ),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: PlatformHoverBuilder(
                builder: (context, isHovered, child) {
                  return AnimatedScale(
                    scale: isHovered ? 1.02 : 1.0,
                    duration: AppMotion.snappy,
                    curve: AppMotion.easeOutCubic,
                    child: child,
                  );
                },
                child: ShrinkableButton(
                  onTap: currentSnippets.value.isEmpty
                      ? null
                      : handleGenerateCards,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: currentSnippets.value.isEmpty
                            ? [
                                colors.textSecondary.withAlpha(80),
                                colors.textSecondary.withAlpha(60),
                              ]
                            : [
                                colors.primary,
                                colors.primary.withAlpha(220),
                              ],
                      ),
                      borderRadius: AppRadius.radiusCard,
                      boxShadow: currentSnippets.value.isEmpty
                          ? null
                          : [
                              BoxShadow(
                                color: colors.black.withAlpha(isDark ? 50 : 20),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.style_rounded,
                          color: colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.generateCardsAction,
                          style: typography.body.bold.copyWith(
                            color: colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
