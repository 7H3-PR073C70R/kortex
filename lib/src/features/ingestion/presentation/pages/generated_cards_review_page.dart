import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_event.dart';
import 'package:kortex/src/features/ingestion/data/models/generated_deck_preview_model.dart';
import 'package:kortex/src/features/ingestion/domain/entities/ocr_extraction_entity.dart';
import 'package:kortex/src/features/ingestion/domain/entities/processing_status.dart';
import 'package:kortex/src/features/ingestion/presentation/bloc/ingestion_bloc.dart';
import 'package:kortex/src/features/ingestion/presentation/bloc/ingestion_event.dart';
import 'package:kortex/src/features/ingestion/presentation/bloc/ingestion_state.dart';
import 'package:kortex/src/features/ingestion/presentation/widgets/generated_card_preview_tile.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/widgets/aura_mesh_nebula.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

@RoutePage()
class GeneratedCardsReviewPage extends StatelessWidget {
  const GeneratedCardsReviewPage({
    required this.documentId,
    required this.deckTitle,
    required this.subject,
    required this.initialCards,
    required this.rawSnippets,
    super.key,
  });

  final String documentId;
  final String deckTitle;
  final String subject;
  final List<GeneratedCardPreviewItem> initialCards;
  final List<OcrExtractionEntity> rawSnippets;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<IngestionBloc>(
      create: (_) => locator<IngestionBloc>(),
      child: _GeneratedCardsReviewView(
        documentId: documentId,
        deckTitle: deckTitle,
        subject: subject,
        initialCards: initialCards,
        rawSnippets: rawSnippets,
      ),
    );
  }
}

class _GeneratedCardsReviewView extends HookWidget {
  const _GeneratedCardsReviewView({
    required this.documentId,
    required this.deckTitle,
    required this.subject,
    required this.initialCards,
    required this.rawSnippets,
  });

  final String documentId;
  final String deckTitle;
  final String subject;
  final List<GeneratedCardPreviewItem> initialCards;
  final List<OcrExtractionEntity> rawSnippets;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final cards = useState<List<GeneratedCardPreviewItem>>(
      List.from(initialCards),
    );
    final titleController = useTextEditingController(text: deckTitle);
    final subjectController = useTextEditingController(text: subject);

    void handleConfirmAndStudy() {
      // Map edited cards back to OcrExtractionEntity
      final updatedSnippets = cards.value.map((c) {
        return OcrExtractionEntity(
          id: 'card_${c.front.hashCode}',
          documentId: documentId,
          rawText: c.back,
          latexContent: c.backLatex,
          topic: c.front,
        );
      }).toList();

      context.read<IngestionBloc>().add(
            GenerateFlashcardsFromSnippetsEvent(
              documentId: documentId,
              deckTitle: titleController.text.trim(),
              subject: subjectController.text.trim(),
              snippets: updatedSnippets,
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
            l10n.reviewCardsTitle,
            style: typography.title3.bold.copyWith(
              color: colors.textPrimary,
            ),
          ),
        ),
        body: BlocConsumer<IngestionBloc, IngestionState>(
          listener: (context, state) {
            if (state.status == ProcessingStatus.completed &&
                state.generatedDeck != null) {
              // Refresh Decks list if bloc is registered
              if (locator.isRegistered<DecksBloc>()) {
                locator<DecksBloc>().add(const DecksRefreshed());
              }

              // Navigate directly into study session
              unawaited(
                context.router.replaceAll([
                  const MainRoute(),
                  StudySessionRoute(deckId: state.generatedDeck!.id),
                ]),
              );
            }
          },
          builder: (context, state) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Deck Metadata Inputs Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? colors.surfaceSecondary
                          : colors.surfacePrimary,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: colors.primary.withAlpha(isDark ? 60 : 30),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppTextField(
                          controller: titleController,
                          label: l10n.deckNameLabel,
                        ),
                        const SizedBox(height: 12),
                        AppTextField(
                          controller: subjectController,
                          label: 'Subject / Course',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'Preview & Edit Cards (${cards.value.length})',
                    style: typography.title3.bold.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Cards List
                  ...List.generate(cards.value.length, (index) {
                    final card = cards.value[index];
                    return GeneratedCardPreviewTile(
                      index: index,
                      card: card,
                      onChanged: (updated) {
                        final updatedList =
                            List<GeneratedCardPreviewItem>.from(cards.value);
                        updatedList[index] = updated;
                        cards.value = updatedList;
                      },
                    );
                  }),
                ],
              ),
            );
          },
        ),
        bottomSheet: Container(
          color: Colors.transparent,
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            MediaQuery.of(context).viewPadding.bottom + 12,
          ),
          child: ShrinkableButton(
            onTap: handleConfirmAndStudy,
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
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.confirmAndStudyAction,
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
