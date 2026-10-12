import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/services/file_picker_service.dart';
import 'package:kortex/src/core/services/user_activity_service.dart';
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
import 'package:kortex/src/features/decks/presentation/widgets/create_deck/draft_card.dart';
import 'package:kortex/src/features/ingestion/data/services/local_ingestion_service.dart';

/// Coordinator decoupling AI card generation, file ingestion, and deck persistence
/// from the UI presentation layer.
class CreateDeckActionCoordinator {
  CreateDeckActionCoordinator({
    DecksRepository? decksRepository,
    UserActivityService? userActivityService,
    DecksBloc? decksBloc,
    DashboardBloc? dashboardBloc,
    StudyEngineRouter? studyEngineRouter,
    LocalIngestionService? ingestionService,
    FilePickerService? filePickerService,
  })  : _decksRepository = decksRepository ??
            (locator.isRegistered<DecksRepository>()
                ? locator<DecksRepository>()
                : null),
        _userActivityService = userActivityService ??
            (locator.isRegistered<UserActivityService>()
                ? locator<UserActivityService>()
                : null),
        _decksBloc = decksBloc ??
            (locator.isRegistered<DecksBloc>()
                ? locator<DecksBloc>()
                : null),
        _dashboardBloc = dashboardBloc ??
            (locator.isRegistered<DashboardBloc>()
                ? locator<DashboardBloc>()
                : null),
        _studyEngineRouter = studyEngineRouter ??
            (locator.isRegistered<StudyEngineRouter>()
                ? locator<StudyEngineRouter>()
                : StudyEngineRouter()),
        _ingestionService = ingestionService ??
            (locator.isRegistered<LocalIngestionService>()
                ? locator<LocalIngestionService>()
                : LocalIngestionService()),
        _filePickerService = filePickerService ?? FilePickerService();

  final DecksRepository? _decksRepository;
  final UserActivityService? _userActivityService;
  final DecksBloc? _decksBloc;
  final DashboardBloc? _dashboardBloc;
  final StudyEngineRouter _studyEngineRouter;
  final LocalIngestionService _ingestionService;
  final FilePickerService _filePickerService;

  FilePickerService get filePickerService => _filePickerService;

  /// Generates flashcards with AI from the specified topic and adds them to [deckCards].
  Future<void> generateCardsWithAi({
    required BuildContext context,
    required String topic,
    required String resolvedCourseCode,
    required int cardCount,
    required ValueNotifier<bool> isAiGenerating,
    required ValueNotifier<List<DraftCard>> deckCards,
  }) async {
    final trimmedTopic = topic.trim();
    if (trimmedTopic.isEmpty) {
      context.showSnackBar(
        message: 'Please enter a topic or paste notes for AI generation.',
      );
      return;
    }

    isAiGenerating.value = true;
    AppFeedback.medium();

    try {
      final result = await _studyEngineRouter.generateStudyPack(
        topic: '$resolvedCourseCode: $trimmedTopic',
        count: cardCount,
      );

      if (result.cards.isNotEmpty) {
        final newCards = result.cards
            .map(
              (c) => DraftCard(
                front: c.front.replaceAll(
                  RegExp(r'^On-Device:\s*', caseSensitive: false),
                  '',
                ),
                back: c.back,
              ),
            )
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

  /// Ingests text from a picked lecture note file and synthesizes flashcards.
  Future<void> ingestDocumentCards({
    required BuildContext context,
    required PickedDocument? doc,
    required String resolvedCourseCode,
    required String resolvedSubject,
    required ValueNotifier<bool> isDocIngesting,
    required ValueNotifier<String> docStatus,
    required ValueNotifier<List<DraftCard>> deckCards,
  }) async {
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
      final extractedText = await _ingestionService.ingestBytes(
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

      final result = await _studyEngineRouter.generateStudyPack(
        topic: '$resolvedCourseCode $resolvedSubject',
        count: 15,
        sourceText: extractedText,
      );

      if (result.cards.isNotEmpty) {
        final newCards = result.cards
            .map(
              (c) => DraftCard(
                front: c.front.replaceAll(
                  RegExp(r'^On-Device:\s*', caseSensitive: false),
                  '',
                ),
                back: c.back,
              ),
            )
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

  /// Saves the configured deck and flashcards into the repository and triggers refreshes.
  Future<void> saveDeck({
    required BuildContext context,
    required String title,
    required String description,
    required String? courseId,
    required String resolvedCourseCode,
    required String resolvedSubject,
    required List<DraftCard> cards,
    required ValueNotifier<bool> isSaving,
  }) async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      context.showSnackBar(
        message: 'Please enter a title for your study deck.',
      );
      return;
    }

    if (cards.isEmpty) {
      context.showSnackBar(
        message: 'Please add at least 1 flashcard to your deck before saving.',
      );
      return;
    }

    isSaving.value = true;
    AppFeedback.medium();

    try {
      final deckId = UuidUtils.generate();
      final flashcards = cards.map((draft) {
        return FlashcardEntity(
          id: UuidUtils.generate(),
          deckId: deckId,
          front: draft.front,
          back: draft.back,
          sourceTopic: resolvedSubject,
          nextDueDate: DateTime.now(),
        );
      }).toList();

      final deckEntity = DeckEntity(
        id: deckId,
        title: trimmedTitle,
        subject: resolvedSubject,
        courseId: courseId,
        courseCode: resolvedCourseCode,
        totalCards: flashcards.length,
        dueCards: flashcards.length,
        masteryRate: 0,
        description: description.trim().isNotEmpty
            ? description.trim()
            : 'Study deck for $resolvedCourseCode ($resolvedSubject)',
        cards: flashcards,
        category: 'Course Study Deck',
      );

      if (_decksRepository != null) {
        await _decksRepository.saveGeneratedDeck(
          deck: deckEntity,
          cards: flashcards,
        );
      }

      if (_userActivityService != null) {
        unawaited(
          _userActivityService.awardXp(
            XpActivityCategory.deckCreation,
            sourceId: deckId,
            metadata: {
              'title': trimmedTitle,
              'totalCards': flashcards.length,
            },
          ),
        );
      }

      _decksBloc?.add(const DecksRefreshed());
      _dashboardBloc?.add(const DashboardRefreshed());

      AppFeedback.heavy();

      if (context.mounted) {
        context.showSnackBar(
          message: 'Study Deck "$trimmedTitle" created with ${flashcards.length} card(s)!',
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
}
