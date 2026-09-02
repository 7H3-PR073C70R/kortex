import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/ingestion/data/models/generated_deck_preview_model.dart';
import 'package:kortex/src/features/ingestion/domain/entities/ocr_extraction_entity.dart';
import 'package:kortex/src/features/ingestion/presentation/widgets/ocr_latex_live_editor.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/widgets/aura_mesh_nebula.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

@RoutePage()
class OcrPreviewPage extends HookWidget {
  const OcrPreviewPage({
    required this.documentId,
    required this.filename,
    required this.snippets,
    super.key,
  });

  final String documentId;
  final String filename;
  final List<OcrExtractionEntity> snippets;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final currentSnippets =
        useState<List<OcrExtractionEntity>>(List.from(snippets));

    void handleGenerateCards() {
      final previewCards = currentSnippets.value.map((s) {
        return GeneratedCardPreviewItem(
          front: s.topic.isNotEmpty ? s.topic : 'Core Concept',
          back: s.rawText,
          backLatex: s.latexContent,
          topic: s.topic,
        );
      }).toList();

      unawaited(
        context.router.push(
          GeneratedCardsReviewRoute(
            documentId: documentId,
            deckTitle: filename.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), ''),
            subject: 'Study Review',
            initialCards: previewCards,
            rawSnippets: currentSnippets.value,
          ),
        ),
      );
    }

    return AuraMeshNebula(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: colors.textPrimary,
              size: 20,
            ),
            onPressed: () => unawaited(Navigator.of(context).maybePop()),
          ),
          title: Text(
            l10n.ocrPreviewTitle,
            style: typography.title3.bold.copyWith(
              color: colors.textPrimary,
            ),
          ),
        ),
        body: Column(
          children: [
            // Extracted Snippets Count Banner
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colors.primary.withAlpha(isDark ? 40 : 25),
                borderRadius: BorderRadius.circular(14),
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
                      l10n.extractedSnippetsCount(currentSnippets.value.length),
                      style: typography.footnote.bold.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Live Editors List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: currentSnippets.value.length,
                itemBuilder: (context, index) {
                  final snippet = currentSnippets.value[index];
                  return OcrLatexLiveEditor(
                    snippet: snippet,
                    onChanged: (updated) {
                      final updatedList =
                          List<OcrExtractionEntity>.from(currentSnippets.value);
                      updatedList[index] = updated;
                      currentSnippets.value = updatedList;
                    },
                  );
                },
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: ShrinkableButton(
              onTap: handleGenerateCards,
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
                  boxShadow: [
                    BoxShadow(
                      color: colors.primary.withAlpha(isDark ? 90 : 50),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.style_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.generateCardsAction,
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
    );
  }
}
