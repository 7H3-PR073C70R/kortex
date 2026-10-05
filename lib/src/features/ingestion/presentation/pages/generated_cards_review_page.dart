import 'dart:async';

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
import 'package:kortex/src/shared/widgets/app_adaptive_app_bar.dart';
import 'package:kortex/src/shared/widgets/app_breadcrumbs.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';
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
    final isSubmitting = useState<bool>(false);

    void handleAddCard() {
      final newIndex = cards.value.length + 1;
      final updatedList = List<GeneratedCardPreviewItem>.from(cards.value)
        ..add(
          GeneratedCardPreviewItem(
            front: 'Concept $newIndex',
            back: '',
            topic: subjectController.text.trim().isNotEmpty
                ? subjectController.text.trim()
                : 'General',
          ),
        );
      cards.value = updatedList;
    }

    void handleConfirmAndStudy() {
      final currentStatus = context.read<IngestionBloc>().state.status;
      if (isSubmitting.value ||
          currentStatus == ProcessingStatus.generatingCards ||
          currentStatus == ProcessingStatus.syncingDb) {
        return;
      }
      isSubmitting.value = true;

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
          deckTitle: titleController.text.trim().isNotEmpty
              ? titleController.text.trim()
              : deckTitle,
          subject: subjectController.text.trim().isNotEmpty
              ? subjectController.text.trim()
              : subject,
          snippets: updatedSnippets,
          courseId: courseId,
          courseCode: courseCode,
        ),
      );
    }

    return Scaffold(
      backgroundColor: colors.backgroundPrimary,
      appBar: AppAdaptiveAppBar(
        backgroundColor: colors.backgroundPrimary,
        titleText: l10n.reviewCardsTitle,
        breadcrumbs: [
          AppBreadcrumbItem(
            label: 'Ingestion',
            onTap: () => context.router.maybePop(),
          ),
          AppBreadcrumbItem(label: l10n.reviewCardsTitle),
        ],
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: colors.primary.withAlpha(isDark ? 35 : 20),
              borderRadius: AppRadius.radiusBadge,
              border: Border.all(
                color: colors.primary.withAlpha(isDark ? 80 : 40),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.style_rounded,
                  size: 14,
                  color: colors.primary,
                ),
                const SizedBox(width: 5),
                Text(
                  '${cards.value.length}',
                  style: typography.caption.bold.copyWith(
                    color: colors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: BlocConsumer<IngestionBloc, IngestionState>(
        listener: (context, state) {
          if (state.status == ProcessingStatus.failed) {
            isSubmitting.value = false;
            if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
              context.showSnackBar(
                message: state.errorMessage!,
                type: SnackBarType.error,
              );
            }
          }
          if (state.status == ProcessingStatus.completed &&
              state.generatedDeck != null) {
            isSubmitting.value = false;
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
          return SafeArea(
            top: false,
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Overview Banner Card
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? colors.surfaceSecondary
                                    : colors.surfacePrimary,
                                borderRadius: AppRadius.radiusDialog,
                                border: Border.all(
                                  color: isDark
                                      ? colors.surfaceBorderHighlight
                                          .withAlpha(60)
                                      : colors.surfaceBorder.withAlpha(120),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.black.withAlpha(
                                      isDark ? 25 : 6,
                                    ),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          colors.primary,
                                          colors.primary.withAlpha(200),
                                        ],
                                      ),
                                      borderRadius: AppRadius.radiusCard,
                                    ),
                                    child: Icon(
                                      Icons.auto_awesome,
                                      color: colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Review & Finalize Flashcards',
                                          style: typography.body.bold.copyWith(
                                            color: colors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          'Review cards, edit prompts or explanations, and adjust deck information before starting.',
                                          style: typography.caption.regular
                                              .copyWith(
                                            color: colors.textSecondary,
                                            height: 1.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )
                                .animate()
                                .fadeIn(duration: 350.ms)
                                .slideY(
                                  begin: 0.08,
                                  end: 0,
                                  curve: Curves.easeOutCubic,
                                ),

                            const SizedBox(height: 20),

                            // Deck Metadata Header
                            Padding(
                              padding: const EdgeInsets.only(left: 4, bottom: 8),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.folder_outlined,
                                    size: 14,
                                    color: colors.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'DECK DETAILS',
                                    style: typography.caption.bold.copyWith(
                                      color:
                                          colors.textSecondary.withAlpha(180),
                                      fontSize: 11,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Deck Metadata Inputs Card
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? colors.surfaceSecondary
                                    : colors.surfacePrimary,
                                borderRadius: AppRadius.radiusDialog,
                                border: Border.all(
                                  color: isDark
                                      ? colors.surfaceBorderHighlight
                                          .withAlpha(60)
                                      : colors.surfaceBorder.withAlpha(120),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.black.withAlpha(
                                      isDark ? 25 : 6,
                                    ),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
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
                                  if (courseCode != null &&
                                      courseCode!.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colors.primary
                                            .withAlpha(isDark ? 30 : 15),
                                        borderRadius: AppRadius.radiusMicro,
                                        border: Border.all(
                                          color: colors.primary
                                              .withAlpha(isDark ? 60 : 30),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.school_outlined,
                                            size: 13,
                                            color: colors.primary,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Course: $courseCode',
                                            style: typography.caption.bold
                                                .copyWith(
                                              color: colors.primary,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            )
                                .animate()
                                .fadeIn(duration: 350.ms, delay: 50.ms)
                                .slideY(
                                  begin: 0.08,
                                  end: 0,
                                  curve: Curves.easeOutCubic,
                                ),

                            const SizedBox(height: 24),

                            // Cards List Header with Add Card action
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.style_outlined,
                                      size: 14,
                                      color: colors.textSecondary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      l10n
                                          .previewAndEditCardsTitle(
                                            cards.value.length,
                                          )
                                          .toUpperCase(),
                                      style: typography.caption.bold.copyWith(
                                        color:
                                            colors.textSecondary.withAlpha(180),
                                        fontSize: 11,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                                PlatformHoverBuilder(
                                  builder: (context, isHovered, child) {
                                    return AnimatedScale(
                                      scale: isHovered ? 1.04 : 1.0,
                                      duration: AppMotion.snappy,
                                      curve: AppMotion.easeOutCubic,
                                      child: child,
                                    );
                                  },
                                  child: ShrinkableButton(
                                    onTap: handleAddCard,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colors.primary
                                            .withAlpha(isDark ? 35 : 20),
                                        borderRadius: AppRadius.radiusBadge,
                                        border: Border.all(
                                          color: colors.primary
                                              .withAlpha(isDark ? 80 : 45),
                                        ),
                                      ),
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
                                            style: typography.caption.bold
                                                .copyWith(
                                              color: colors.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                                .animate()
                                .fadeIn(duration: 350.ms, delay: 100.ms)
                                .slideY(
                                  begin: 0.08,
                                  end: 0,
                                  curve: Curves.easeOutCubic,
                                ),
                          ],
                        ),
                      ),
                    ),

                    // Cards List or Empty State
                    if (cards.value.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.style_outlined,
                                  size: 48,
                                  color: colors.textSecondary.withAlpha(100),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No cards in this deck',
                                  style: typography.title3.bold.copyWith(
                                    color: colors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Tap "Add Card" above to add flashcards to your deck.',
                                  textAlign: TextAlign.center,
                                  style: typography.footnote.regular.copyWith(
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final card = cards.value[index];
                              return GeneratedCardPreviewTile(
                                key: ValueKey('preview_card_${card.front.hashCode}_$index'),
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
                                onDelete: () {
                                  final updatedList =
                                      List<GeneratedCardPreviewItem>.from(
                                    cards.value,
                                  )..removeAt(index);
                                  cards.value = updatedList;
                                },
                              );
                            },
                            childCount: cards.value.length,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark
              ? colors.surfaceSecondary.withAlpha(245)
              : colors.surfacePrimary.withAlpha(250),
          border: Border(
            top: BorderSide(
              color: isDark
                  ? colors.surfaceBorderHighlight.withAlpha(60)
                  : colors.surfaceBorder.withAlpha(120),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: colors.black.withAlpha(isDark ? 60 : 15),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: BlocBuilder<IngestionBloc, IngestionState>(
                  builder: (context, state) {
                    final isBusy = isSubmitting.value ||
                        state.status == ProcessingStatus.generatingCards ||
                        state.status == ProcessingStatus.syncingDb;

                    return AppButton(
                      text: isBusy
                          ? l10n.generatingCardsStatus
                          : l10n.confirmAndStudyAction,
                      isLoading: isBusy,
                      prefixIcon: isBusy
                          ? null
                          : const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                      onPressed: (isBusy || cards.value.isEmpty)
                          ? null
                          : handleConfirmAndStudy,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
