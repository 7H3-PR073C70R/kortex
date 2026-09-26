import 'dart:async';
import 'dart:ui';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_event.dart';
import 'package:kortex/src/features/ingestion/data/models/generated_deck_preview_model.dart';
import 'package:kortex/src/features/ingestion/domain/entities/ocr_extraction_entity.dart';
import 'package:kortex/src/features/ingestion/domain/entities/processing_status.dart';
import 'package:kortex/src/features/ingestion/presentation/bloc/ingestion_bloc.dart';
import 'package:kortex/src/features/ingestion/presentation/bloc/ingestion_event.dart';
import 'package:kortex/src/features/ingestion/presentation/bloc/ingestion_state.dart';
import 'package:kortex/src/features/ingestion/presentation/widgets/generated_card_preview_tile.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_back_button.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

@RoutePage()
class GeneratedCardsReviewPage extends StatelessWidget {
  const GeneratedCardsReviewPage({
    required this.documentId,
    required this.deckTitle,
    required this.subject,
    required this.initialCards,
    required this.rawSnippets,
    this.courseId,
    this.courseCode,
    super.key,
  });

  final String documentId;
  final String deckTitle;
  final String subject;
  final List<GeneratedCardPreviewItem> initialCards;
  final List<OcrExtractionEntity> rawSnippets;
  final String? courseId;
  final String? courseCode;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<IngestionBloc>.value(
      value: locator<IngestionBloc>(),
      child: _GeneratedCardsReviewView(
        documentId: documentId,
        deckTitle: deckTitle,
        subject: subject,
        initialCards: initialCards,
        rawSnippets: rawSnippets,
        courseId: courseId,
        courseCode: courseCode,
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
    this.courseId,
    this.courseCode,
  });

  final String documentId;
  final String deckTitle;
  final String subject;
  final List<GeneratedCardPreviewItem> initialCards;
  final List<OcrExtractionEntity> rawSnippets;
  final String? courseId;
  final String? courseCode;

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
      final updatedSnippets = cards.value.map((c) {
        return OcrExtractionEntity(
          id: 'card_${c.front.hashCode}',
          documentId: documentId,
          rawText: c.back,
          latexContent: c.backLatex,
          imageUrl: c.imageUrl,
          topic: c.front,
        );
      }).toList();

      context.read<IngestionBloc>().add(
        GenerateFlashcardsFromSnippetsEvent(
          documentId: documentId,
          deckTitle: titleController.text.trim(),
          subject: subjectController.text.trim(),
          snippets: updatedSnippets,
          courseId: courseId,
          courseCode: courseCode,
        ),
      );
    }

    return Scaffold(
      backgroundColor: colors.transparent,
      extendBody: true,
      body: BlocConsumer<IngestionBloc, IngestionState>(
        listener: (context, state) {
          if (state.status == ProcessingStatus.completed &&
              state.generatedDeck != null) {
            if (locator.isRegistered<DecksBloc>()) {
              locator<DecksBloc>().add(const DecksRefreshed());
            }
            if (locator.isRegistered<DashboardBloc>()) {
              locator<DashboardBloc>().add(const DashboardRefreshed());
            }
    
            final generatedDeckId = state.generatedDeck!.id;
    
            unawaited(
              context.router.replaceAll([
                const MainRoute(),
                StudySessionRoute(deckId: generatedDeckId),
              ]),
            );
    
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final navContext =
                  locator<AppRouter>().navigatorKey.currentContext;
              if (navContext != null && navContext.mounted) {
                navContext.showSnackBar(
                  message: l10n.deckCreatedSuccessTap,
                  type: SnackBarType.success,
                  duration: const Duration(seconds: 5),
                  onTap: () {
                    unawaited(
                      locator<AppRouter>().navigate(
                        const MainRoute(children: [DecksRoute()]),
                      ),
                    );
                  },
                );
              }
            });
          }
        },
        builder: (context, state) {
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: colors.transparent,
                elevation: 0,
                pinned: true,
                leading: const AppBackButton(),
                flexibleSpace: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(color: colors.backgroundPrimary.withValues(alpha: 0.7)),
                  ),
                ),
                title: Text(
                  l10n.reviewCardsTitle,
                  style: typography.title3.bold.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Deck Metadata Inputs Card
                          Padding(
                            padding: const EdgeInsets.only(left: 6, bottom: 8),
                            child: Text(
                              'DECK METADATA',
                              style: typography.caption.bold.copyWith(
                                color: colors.textSecondary.withAlpha(170),
                                fontSize: 11,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic),
                          
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? colors.surfaceSecondary
                                  : colors.surfacePrimary,
                              borderRadius: AppRadius.radiusDialog,
                              border: Border.all(
                                color: colors.primary.withAlpha(isDark ? 30 : 15),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: colors.black.withAlpha(isDark ? 30 : 10),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
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
                                  label: l10n.subjectOrCourseLabel,
                                ),
                              ],
                            ),
                          ).animate().fadeIn(duration: 400.ms, delay: 50.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic),
                          
                          const SizedBox(height: 32),
    
                          Padding(
                            padding: const EdgeInsets.only(left: 6, bottom: 12),
                            child: Text(
                              l10n.previewAndEditCardsTitle(cards.value.length).toUpperCase(),
                              style: typography.caption.bold.copyWith(
                                color: colors.textSecondary.withAlpha(170),
                                fontSize: 11,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic),
    
                          // Cards List
                          ...List.generate(cards.value.length, (index) {
                            final card = cards.value[index];
                            return GeneratedCardPreviewTile(
                              index: index,
                              card: card,
                              onChanged: (updated) {
                                final updatedList =
                                    List<GeneratedCardPreviewItem>.from(
                                      cards.value,
                                    );
                                updatedList[index] = updated;
                                cards.value = updatedList;
                              },
                            ).animate().fadeIn(
                              duration: 400.ms,
                              delay: (150 + (index * 50)).ms,
                            ).slideY(
                              begin: 0.1, 
                              end: 0, 
                              curve: Curves.easeOutCubic
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            color: colors.backgroundPrimary.withValues(alpha: 0.85),
            border: Border(
              top: BorderSide(
                color: colors.primary.withAlpha(isDark ? 30 : 15),
              ),
            ),
          ),
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Center(
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
                          borderRadius: AppRadius.radiusCard,
                          boxShadow: [
                            BoxShadow(
                              color: colors.primary.withAlpha(isDark ? 60 : 40),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.play_arrow_rounded,
                              color: colors.white,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              l10n.confirmAndStudyAction,
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
        ),
      ).animate().fadeIn(duration: 500.ms, delay: 300.ms).slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic),
    );
  }
}
