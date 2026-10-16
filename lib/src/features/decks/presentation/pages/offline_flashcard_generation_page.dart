import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/utils/uuid_utils.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';
import 'package:kortex/src/features/decks/domain/repositories/decks_repository.dart';
import 'package:kortex/src/features/decks/domain/services/study_engine_router.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_event.dart';
import 'package:kortex/src/features/decks/presentation/widgets/offline_generation/offline_generated_card_tile.dart';
import 'package:kortex/src/features/decks/presentation/widgets/offline_generation/offline_generation_header_cards.dart';
import 'package:kortex/src/features/decks/presentation/widgets/offline_generation/offline_save_deck_sheet.dart';
import 'package:kortex/src/features/decks/presentation/widgets/offline_generation/offline_topic_input_card.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

@RoutePage()
class OfflineFlashcardGenerationPage extends StatefulWidget {
  const OfflineFlashcardGenerationPage({
    super.key,
    this.initialTopic = 'Quantum Mechanics & Wave Functions',
    this.studyEngineRouter,
    this.decksRepository,
    this.decksBloc,
    this.dashboardBloc,
  });

  final String initialTopic;
  final StudyEngineRouter? studyEngineRouter;
  final DecksRepository? decksRepository;
  final DecksBloc? decksBloc;
  final DashboardBloc? dashboardBloc;

  @override
  State<OfflineFlashcardGenerationPage> createState() =>
      _OfflineFlashcardGenerationPageState();
}

class _OfflineFlashcardGenerationPageState
    extends State<OfflineFlashcardGenerationPage> {
  late final StudyEngineRouter _engineRouter;
  late final DecksRepository? _decksRepository;
  late final DecksBloc? _decksBloc;
  late final DashboardBloc? _dashboardBloc;
  late final TextEditingController _topicController;

  bool _isGenerating = false;
  bool _isSaving = false;
  final List<GeneratedFlashcard> _cards = [];

  @override
  void initState() {
    super.initState();
    _engineRouter = widget.studyEngineRouter ??
        (locator.isRegistered<StudyEngineRouter>()
            ? locator<StudyEngineRouter>()
            : StudyEngineRouter());
    _decksRepository = widget.decksRepository ??
        (locator.isRegistered<DecksRepository>()
            ? locator<DecksRepository>()
            : null);
    _decksBloc = widget.decksBloc ??
        (locator.isRegistered<DecksBloc>()
            ? locator<DecksBloc>()
            : null);
    _dashboardBloc = widget.dashboardBloc ??
        (locator.isRegistered<DashboardBloc>()
            ? locator<DashboardBloc>()
            : null);
    _topicController = TextEditingController(text: widget.initialTopic);
  }

  Future<void> _generateCards() async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) return;

    setState(() {
      _isGenerating = true;
      _cards.clear();
    });

    try {
      final result = await _engineRouter.generateStudyPack(
        topic: topic,
        forceOffline: true,
      );

      if (!mounted) return;

      if (result.isOfflineModelMissing) {
        context.showSnackBar(
          message:
              result.userMessage ?? StudyEngineRouter.offlineModelMissingPrompt,
        );
      } else {
        setState(() {
          _cards.addAll(result.cards);
        });
      }
    } on Object catch (e) {
      if (mounted) {
        context.showSnackBar(
          message: context.l10n.offlineGenNote('$e'),
          type: SnackBarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  void _showSaveDeckDialog() {
    final defaultTitle = _topicController.text.trim().isNotEmpty
        ? _topicController.text.trim()
        : 'Offline AI Study Deck';
    final defaultSubject = _extractSubject(defaultTitle);

    unawaited(
      showOfflineSaveDeckSheet(
        context: context,
        defaultTitle: defaultTitle,
        defaultSubject: defaultSubject,
        cardCount: _cards.length,
        onConfirm: _persistDeck,
      ),
    );
  }

  Future<void> _persistDeck({
    required String title,
    required String subject,
  }) async {
    setState(() {
      _isSaving = true;
    });

    try {
      final deckId = UuidUtils.generate();
      final flashcards = _cards.map((c) {
        final explanationText = c.explanation.trim().isNotEmpty
            ? '\n\n💡 Explanation:\n${c.explanation.trim()}'
            : '';
        return FlashcardEntity(
          id: UuidUtils.generate(),
          deckId: deckId,
          front: c.front,
          back: '${c.back}$explanationText',
          sourceTopic: subject,
          nextDueDate: DateTime.now(),
        );
      }).toList();

      final deckEntity = DeckEntity(
        id: deckId,
        title: title,
        subject: subject,
        totalCards: flashcards.length,
        dueCards: flashcards.length,
        masteryRate: 0,
        category: 'Offline AI Study Cards',
        description: 'Synthesized locally using on-device AI for $title.',
        cards: flashcards,
      );

      await _decksRepository?.saveGeneratedDeck(
        deck: deckEntity,
        cards: flashcards,
      );

      _decksBloc?.add(const DecksRefreshed());
      _dashboardBloc?.add(const DashboardRefreshed());

      AppFeedback.light();

      if (!mounted) return;
      context.showSnackBar(
        message: 'Deck "$title" saved to your Study Decks!',
        type: SnackBarType.success,
      );

      unawaited(
        showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: context.colors.surfacePrimary,
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.radiusDialog,
            ),
            title: Text(
              'Deck Saved!',
              style: context.typography.title3.bold.copyWith(
                color: context.colors.textPrimary,
              ),
            ),
            content: Text(
              'Your ${flashcards.length} flashcards have been added to your active recall queue.',
              style: context.typography.body.regular.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  context.router.pop();
                },
                child: Text(
                  'Back to Decks',
                  style: context.typography.body.bold.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.radiusCard,
                  ),
                ),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  unawaited(
                    context.router.replace(StudySessionRoute(deckId: deckId)),
                  );
                },
                child: Text(
                  'Study Now',
                  style: context.typography.body.bold.copyWith(
                    color: context.colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } on Object catch (e) {
      if (mounted) {
        context.showSnackBar(
          message: 'Failed to save deck: $e',
          type: SnackBarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _extractSubject(String topic) {
    final lower = topic.toLowerCase();
    if (lower.contains('quantum') ||
        lower.contains('physics') ||
        lower.contains('wave') ||
        lower.contains('mechanic')) {
      return 'Physics';
    }
    if (lower.contains('math') ||
        lower.contains('calculus') ||
        lower.contains('algebra') ||
        lower.contains('geometry')) {
      return 'Mathematics';
    }
    if (lower.contains('chem')) return 'Chemistry';
    if (lower.contains('bio')) return 'Biology';
    if (lower.contains('computer') ||
        lower.contains('algorithm') ||
        lower.contains('code')) {
      return 'Computer Science';
    }
    return 'General Studies';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Scaffold(
      backgroundColor: isDark
          ? colors.backgroundPrimary
          : colors.surfacePrimary,
      appBar: AppBar(
        backgroundColor: colors.transparent,
        elevation: 0,
        title: Text(
          'Offline AI Study Cards',
          style: typography.headline.bold.copyWith(
            color: colors.textPrimary,
            fontSize: 18.sp,
          ),
        ),
        actions: [
          if (_cards.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(right: 16.w),
              child: ShrinkableButton(
                onTap: _showSaveDeckDialog,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: AppRadius.radiusCard,
                    boxShadow: [
                      BoxShadow(
                        color: colors.black.withAlpha(isDark ? 50 : 20),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.bookmark_add_rounded,
                        color: colors.white,
                        size: 16.sp,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        'Save Deck',
                        style: typography.caption.bold.copyWith(
                          color: colors.white,
                          fontSize: 12.sp,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _cards.isNotEmpty
          ? Container(
              decoration: BoxDecoration(
                color: isDark
                    ? colors.surfaceSecondary.withAlpha(240)
                    : colors.surfacePrimary.withAlpha(245),
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
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 28.h),
                      child: AppButton(
                        text: 'Save ${_cards.length} Cards as Study Deck',
                        prefixIcon: Icon(
                          Icons.bookmark_add_rounded,
                          color: colors.white,
                          size: 18.sp,
                        ),
                        isLoading: _isSaving,
                        onPressed: _showSaveDeckDialog,
                      ),
                    ),
                  ),
                ),
              ),
            )
          : null,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const OfflineModelStatusCard(),
                  SizedBox(height: 20.h),
                  OfflineTopicInputCard(
                    controller: _topicController,
                    isGenerating: _isGenerating,
                    onGenerate: _generateCards,
                  ),
                  SizedBox(height: 24.h),
                  if (_isGenerating)
                    const OfflineGeneratingIndicator(),
                  if (_cards.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Generated Cards (${_cards.length})',
                          style: typography.headline.semiBold.copyWith(
                            color: colors.textPrimary,
                            fontSize: 16.sp,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _showSaveDeckDialog,
                          icon: Icon(
                            Icons.bookmark_add_rounded,
                            size: 16.sp,
                            color: colors.primary,
                          ),
                          label: Text(
                            'Save Deck',
                            style: typography.caption.bold.copyWith(
                              color: colors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _cards.length,
                      separatorBuilder: (_, _) => SizedBox(height: 12.h),
                      itemBuilder: (context, index) => OfflineGeneratedCardTile(
                        card: _cards[index],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
