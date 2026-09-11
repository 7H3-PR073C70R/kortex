import 'dart:async';
import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/utils/uuid_utils.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:kortex/src/features/decks/data/data_sources/decks_remote_data_source.dart';
import 'package:kortex/src/features/decks/data/models/deck_model.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_event.dart';
import 'package:kortex/src/features/ingestion/domain/entities/document_upload_entity.dart';
import 'package:kortex/src/features/ingestion/domain/entities/processing_status.dart';
import 'package:kortex/src/features/ingestion/domain/entities/synthesis_mode.dart';
import 'package:kortex/src/features/ingestion/domain/services/deep_document_dedup_service.dart';
import 'package:kortex/src/features/ingestion/domain/use_cases/fetch_lms_courses_use_case.dart';
import 'package:kortex/src/features/ingestion/domain/use_cases/fetch_user_documents_use_case.dart';
import 'package:kortex/src/features/ingestion/domain/use_cases/generate_flashcards_from_doc_use_case.dart';
import 'package:kortex/src/features/ingestion/domain/use_cases/import_lms_course_use_case.dart';
import 'package:kortex/src/features/ingestion/domain/use_cases/process_local_camera_ocr_use_case.dart';
import 'package:kortex/src/features/ingestion/domain/use_cases/process_stem_ocr_use_case.dart';
import 'package:kortex/src/features/ingestion/domain/use_cases/upload_study_document_use_case.dart';
import 'package:kortex/src/features/ingestion/presentation/bloc/ingestion_event.dart';
import 'package:kortex/src/features/ingestion/presentation/bloc/ingestion_state.dart';
import 'package:kortex/src/features/ingestion/presentation/controllers/onboarding_stream_controller.dart';

class IngestionBloc extends Bloc<IngestionEvent, IngestionState> {
  IngestionBloc({
    required UploadStudyDocumentUseCase uploadUseCase,
    required ProcessStemOcrUseCase processOcrUseCase,
    required GenerateFlashcardsFromDocUseCase generateDeckUseCase,
    required FetchUserDocumentsUseCase fetchUserDocsUseCase,
    DecksRemoteDataSource? decksRemoteDataSource,
    ProcessLocalCameraOcrUseCase? processCameraOcrUseCase,
    FetchLmsCoursesUseCase? fetchLmsCoursesUseCase,
    ImportLmsCourseUseCase? importLmsCourseUseCase,
    OnboardingStreamController? streamController,
    DeepDocumentDedupService? dedupService,
  }) : _upload = uploadUseCase,
       _processOcr = processOcrUseCase,
       _generateDeck = generateDeckUseCase,
       _fetchUserDocs = fetchUserDocsUseCase,
       _decksRemoteDataSource = decksRemoteDataSource,
       _processCameraOcr = processCameraOcrUseCase,
       _fetchLmsCourses = fetchLmsCoursesUseCase,
       _importLmsCourse = importLmsCourseUseCase,
       _streamController = streamController,
       _dedupService = dedupService ?? DeepDocumentDedupService(),
       super(const IngestionState()) {
    on<PickAndUploadFileEvent>(_onPickAndUploadFile);
    on<UploadProgressUpdatedEvent>(_onUploadProgressUpdated);
    on<SetSynthesisModeEvent>(_onSetSynthesisMode);
    on<TriggerOcrParsingEvent>(_onTriggerOcrParsing);
    on<AttachDocumentToCourseEvent>(_onAttachDocumentToCourse);
    on<UpdateSnippetContentEvent>(_onUpdateSnippetContent);
    on<GenerateFlashcardsFromSnippetsEvent>(_onGenerateFlashcards);
    on<FetchUserDocumentsEvent>(_onFetchUserDocuments);
    on<ResetIngestionStateEvent>(_onResetIngestionState);
    on<ProcessCameraImageEvent>(_onProcessCameraImage);
    on<FetchLmsCoursesEvent>(_onFetchLmsCourses);
    on<ImportLmsCourseEvent>(_onImportLmsCourse);
  }

  final UploadStudyDocumentUseCase _upload;
  final ProcessStemOcrUseCase _processOcr;
  final GenerateFlashcardsFromDocUseCase _generateDeck;
  final FetchUserDocumentsUseCase _fetchUserDocs;
  final DecksRemoteDataSource? _decksRemoteDataSource;
  final ProcessLocalCameraOcrUseCase? _processCameraOcr;
  final FetchLmsCoursesUseCase? _fetchLmsCourses;
  final ImportLmsCourseUseCase? _importLmsCourse;
  final OnboardingStreamController? _streamController;
  final DeepDocumentDedupService _dedupService;

  OnboardingStreamController? get streamController => _streamController;

  void _onSetSynthesisMode(
    SetSynthesisModeEvent event,
    Emitter<IngestionState> emit,
  ) {
    emit(state.copyWith(synthesisMode: event.mode));
  }

  Future<void> _onPickAndUploadFile(
    PickAndUploadFileEvent event,
    Emitter<IngestionState> emit,
  ) async {
    // 1. Deep document deduplication (page count check + random/representative page sampling)
    final incomingHash =
        DeepDocumentDedupService.computeSha256(event.fileBytes);
    final incomingFingerprint = _dedupService.extractFingerprint(
      bytes: event.fileBytes,
      fileType: event.fileType,
      contentHash: incomingHash,
    );

    DocumentUploadEntity? matchedDoc;
    for (final d in state.userDocuments) {
      if (_dedupService.isSameDocument(
        incomingBytes: event.fileBytes,
        incomingFileType: event.fileType,
        incomingContentHash: incomingHash,
        existingDoc: d,
      )) {
        matchedDoc = d;
        break;
      }
    }

    if (matchedDoc != null) {
      emit(
        state.copyWith(
          status: ProcessingStatus.generatingCards,
          currentDocument: matchedDoc,
          wasDeduplicated: true,
          stageMessage:
              'Document verified identical (${incomingFingerprint.pageCount} pages). Attaching study deck to ${event.courseCode ?? "course"}...',
        ),
      );

      await _assignExistingDeckToCourse(
        docFilename: matchedDoc.filename,
        courseId: event.courseId,
        courseCode: event.courseCode,
        courseTitle: event.courseTitle,
        documentId: matchedDoc.id,
        contentHash: matchedDoc.contentHash,
        emit: emit,
      );
      return;
    }

    emit(
      state.copyWith(
        status: ProcessingStatus.uploading,
        uploadProgress: 0.1,
      ),
    );

    final uploadResult = await _upload(
      filename: event.filename,
      fileType: event.fileType,
      fileBytes: event.fileBytes,
      onProgress: (progress) {
        add(UploadProgressUpdatedEvent(progress));
      },
    );

    await uploadResult.fold(
      (failure) async {
        emit(
          state.copyWith(
            status: ProcessingStatus.failed,
            errorMessage: failure.message,
          ),
        );
      },
      (doc) async {
        _dedupService.saveFingerprint(
          contentHash: doc.contentHash,
          fingerprint: incomingFingerprint,
          documentId: doc.id,
        );

        emit(
          state.copyWith(
            uploadProgress: 1,
            currentDocument: doc,
            wasDeduplicated: doc.isDeduplicated,
          ),
        );

        if (doc.isDeduplicated) {
          emit(
            state.copyWith(
              status: ProcessingStatus.generatingCards,
              stageMessage:
                  'Document already processed. Attaching study deck to ${event.courseCode ?? "course"}...',
            ),
          );

          await _assignExistingDeckToCourse(
            docFilename: doc.filename,
            courseId: event.courseId,
            courseCode: event.courseCode,
            courseTitle: event.courseTitle,
            documentId: doc.id,
            contentHash: doc.contentHash,
            emit: emit,
          );
          return;
        }

        // Immediately trigger STEM OCR parsing
        add(
          TriggerOcrParsingEvent(
            documentId: doc.id,
            storagePath: doc.storagePath,
            fileType: doc.fileType,
            courseId: event.courseId,
            courseCode: event.courseCode,
            courseTitle: event.courseTitle,
          ),
        );
      },
    );
  }

  void _onUploadProgressUpdated(
    UploadProgressUpdatedEvent event,
    Emitter<IngestionState> emit,
  ) {
    emit(state.copyWith(uploadProgress: event.progress));
  }

  Future<void> _onTriggerOcrParsing(
    TriggerOcrParsingEvent event,
    Emitter<IngestionState> emit,
  ) async {
    final isAi = state.synthesisMode.isAiSmart;
    final isDeduplicated = state.wasDeduplicated;

    emit(
      state.copyWith(
        status: ProcessingStatus.parsingOcr,
        stageMessage: isDeduplicated
            ? 'Loading cached study deck...'
            : (isAi
                ? 'Synthesizing with AI Smart Synthesis...'
                : 'Reading document locally...'),
      ),
    );

    final ocrResult = await _processOcr(
      documentId: event.documentId,
      storagePath: event.storagePath,
      fileType: event.fileType,
    );

    ocrResult.fold(
      (failure) {
        emit(
          state.copyWith(
            status: ProcessingStatus.failed,
            errorMessage: failure.message,
          ),
        );
      },
      (snippets) {
        emit(
          state.copyWith(
            status: ProcessingStatus.completed,
            stageMessage: isDeduplicated
                ? 'Pre-processed asset detected. Study deck synthesized!'
                : (isAi
                    ? 'AI synthesized ${snippets.length} conceptual cards'
                    : 'Extracted ${snippets.length} study cards locally'),
            snippets: snippets,
          ),
        );
      },
    );
  }

  Future<void> _onAttachDocumentToCourse(
    AttachDocumentToCourseEvent event,
    Emitter<IngestionState> emit,
  ) async {
    emit(
      state.copyWith(
        status: ProcessingStatus.generatingCards,
        currentDocument: event.doc,
        stageMessage:
            'Attaching "${event.doc.filename}" to ${event.courseCode ?? "course"}...',
      ),
    );

    await _assignExistingDeckToCourse(
      docFilename: event.doc.filename,
      courseId: event.courseId,
      courseCode: event.courseCode,
      courseTitle: event.courseTitle,
      documentId: event.doc.id,
      contentHash: event.doc.contentHash,
      emit: emit,
    );
  }

  Future<void> _assignExistingDeckToCourse({
    required String docFilename,
    required String? courseId,
    required String? courseCode,
    required String? courseTitle,
    required Emitter<IngestionState> emit,
    String? documentId,
    String? contentHash,
  }) async {
    final decksDataSource = _decksRemoteDataSource ??
        (locator.isRegistered<DecksRemoteDataSource>()
            ? locator<DecksRemoteDataSource>()
            : null);

    DeckModel? matchedDeck;
    if (decksDataSource != null) {
      final allDecks = await decksDataSource.getUserDecks();
      final baseName = docFilename
          .replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '')
          .toLowerCase()
          .trim();

      // Check LocalStorage cache first
      final storage = locator.isRegistered<LocalStorageService>()
          ? locator<LocalStorageService>()
          : null;
      String? cachedDeckId;
      if (storage != null) {
        if (contentHash != null) {
          final info = storage.getPreference(
            key: 'extracted_doc_$contentHash',
          );
          if (info != null) {
            try {
              final map = jsonDecode(info) as Map<String, dynamic>;
              cachedDeckId = map['deckId'] as String?;
            } on Object catch (_) {}
          }
        }
        if (cachedDeckId == null && documentId != null) {
          final info = storage.getPreference(
            key: 'extracted_doc_$documentId',
          );
          if (info != null) {
            try {
              final map = jsonDecode(info) as Map<String, dynamic>;
              cachedDeckId = map['deckId'] as String?;
            } on Object catch (_) {}
          }
        }
        if (cachedDeckId == null) {
          final info = storage.getPreference(
            key: 'extracted_doc_$baseName',
          );
          if (info != null) {
            try {
              final map = jsonDecode(info) as Map<String, dynamic>;
              cachedDeckId = map['deckId'] as String?;
            } on Object catch (_) {}
          }
        }
      }

      if (cachedDeckId != null) {
        matchedDeck = allDecks.where((d) => d.id == cachedDeckId).firstOrNull;
      }

      matchedDeck ??= allDecks.where((d) {
        final dTitle = d.title.toLowerCase().trim();
        return dTitle.contains(baseName) || baseName.contains(dTitle);
      }).firstOrNull;
    }

    if (matchedDeck != null && courseId != null && decksDataSource != null) {
      final existingCards = await decksDataSource.getDeckCards(matchedDeck.id);
      final newDeckId = UuidUtils.generate();
      final now = DateTime.now();

      final newCards = existingCards.map((c) {
        return c.copyWith(
          id: UuidUtils.generate(),
          deckId: newDeckId,
          nextDueDate: now,
        );
      }).toList();

      final assignedDeck = matchedDeck.copyWith(
        id: newDeckId,
        courseId: courseId,
        courseCode: courseCode ?? matchedDeck.courseCode,
        subject: courseTitle ?? matchedDeck.subject,
        cards: newCards,
        totalCards: newCards.length,
        dueCards: newCards.length,
      );

      await decksDataSource.saveGeneratedDeck(
        deck: assignedDeck,
        cards: newCards,
      );

      // Save preference for future lookups
      try {
        final storage = locator.isRegistered<LocalStorageService>()
            ? locator<LocalStorageService>()
            : null;
        if (storage != null) {
          final info = jsonEncode({
            'deckId': assignedDeck.id,
            'deckTitle': assignedDeck.title,
            'documentId': documentId ?? '',
            'courseId': courseId,
            'courseCode': courseCode,
          });
          final baseName = docFilename
              .replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '')
              .toLowerCase()
              .trim();
          unawaited(
            storage.savePreference(key: 'extracted_doc_$baseName', data: info),
          );
          if (documentId != null) {
            unawaited(
              storage.savePreference(
                key: 'extracted_doc_$documentId',
                data: info,
              ),
            );
          }
          if (contentHash != null) {
            unawaited(
              storage.savePreference(
                key: 'extracted_doc_$contentHash',
                data: info,
              ),
            );
          }
        }
      } on Object catch (_) {}

      if (locator.isRegistered<DecksBloc>()) {
        locator<DecksBloc>().add(const DecksRefreshed());
      }
      if (locator.isRegistered<DashboardBloc>()) {
        locator<DashboardBloc>().add(const DashboardRefreshed());
      }

      final updatedAttached = Set<String>.from(state.attachedDocumentIds)
        ..add(assignedDeck.id);
      if (documentId != null) updatedAttached.add(documentId);
      if (courseCode != null) {
        updatedAttached.add('${assignedDeck.id}_$courseCode');
        if (documentId != null) updatedAttached.add('${documentId}_$courseCode');
      }
      updatedAttached.add('${assignedDeck.id}_$courseId');
      if (documentId != null) updatedAttached.add('${documentId}_$courseId');

      emit(
        state.copyWith(
          status: ProcessingStatus.completed,
          stageMessage:
              'Study deck attached to ${courseCode ?? "course"} successfully!',
          generatedDeck: assignedDeck.toEntity(),
          wasDeduplicated: true,
          attachedDocumentIds: updatedAttached,
        ),
      );
      return;
    }

    if (matchedDeck != null) {
      emit(
        state.copyWith(
          status: ProcessingStatus.completed,
          stageMessage: 'Pre-existing study deck loaded!',
          generatedDeck: matchedDeck.toEntity(),
          wasDeduplicated: true,
        ),
      );
      return;
    }

    // If no matched deck is yet created, extract OCR snippets and create the deck for the course
    emit(
      state.copyWith(
        status: ProcessingStatus.parsingOcr,
        stageMessage:
            'Processing document and generating study deck for ${courseCode ?? "course"}...',
      ),
    );

    final ocrResult = await _processOcr(
      documentId: documentId ?? 'doc_${DateTime.now().millisecondsSinceEpoch}',
      storagePath: '',
      fileType: 'pdf',
    );

    await ocrResult.fold(
      (failure) async {
        emit(
          state.copyWith(
            status: ProcessingStatus.failed,
            errorMessage: failure.message,
          ),
        );
      },
      (snippets) async {
        emit(
          state.copyWith(
            snippets: snippets,
            status: ProcessingStatus.generatingCards,
            stageMessage:
                'Generating flashcards for ${courseCode ?? "course"}...',
          ),
        );

        final cleanDeckTitle = docFilename.replaceAll(
          RegExp(r'\.[a-zA-Z0-9]+$'),
          '',
        );
        add(
          GenerateFlashcardsFromSnippetsEvent(
            documentId:
                documentId ?? 'doc_${DateTime.now().millisecondsSinceEpoch}',
            deckTitle: cleanDeckTitle,
            subject: courseTitle ?? courseCode ?? 'General',
            snippets: snippets,
            courseId: courseId,
            courseCode: courseCode,
          ),
        );
      },
    );
  }

  void _onUpdateSnippetContent(
    UpdateSnippetContentEvent event,
    Emitter<IngestionState> emit,
  ) {
    final updatedList = state.snippets.map((s) {
      if (s.id == event.snippetId) {
        return s.copyWith(
          rawText: event.updatedRawText,
          latexContent: event.updatedLatex,
          topic: event.updatedTopic,
        );
      }
      return s;
    }).toList();

    emit(state.copyWith(snippets: updatedList));
  }

  Future<void> _onGenerateFlashcards(
    GenerateFlashcardsFromSnippetsEvent event,
    Emitter<IngestionState> emit,
  ) async {
    emit(
      state.copyWith(
        status: ProcessingStatus.generatingCards,
        stageMessage: 'Structuring flashcards...',
      ),
    );

    emit(
      state.copyWith(
        status: ProcessingStatus.syncingDb,
        stageMessage: 'Syncing to Supabase...',
      ),
    );

    final deckResult = await _generateDeck(
      documentId: event.documentId,
      deckTitle: event.deckTitle,
      subject: event.subject,
      snippets: event.snippets,
      courseId: event.courseId,
      courseCode: event.courseCode,
    );

    deckResult.fold(
      (failure) {
        emit(
          state.copyWith(
            status: ProcessingStatus.failed,
            errorMessage: failure.message,
          ),
        );
      },
      (deck) {
        try {
          final storage = locator.isRegistered<LocalStorageService>()
              ? locator<LocalStorageService>()
              : null;
          if (storage != null) {
            final info = jsonEncode({
              'deckId': deck.id,
              'deckTitle': event.deckTitle,
              'documentId': event.documentId,
            });
            // Record by base title
            final baseName = event.deckTitle
                .replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '')
                .toLowerCase()
                .trim();
            unawaited(
              storage.savePreference(key: 'extracted_doc_$baseName', data: info),
            );

            // Record by documentId
            unawaited(
              storage.savePreference(
                key: 'extracted_doc_${event.documentId}',
                data: info,
              ),
            );

            // Record by currentDocument contentHash if available
            if (state.currentDocument?.contentHash != null) {
              unawaited(
                storage.savePreference(
                  key: 'extracted_doc_${state.currentDocument!.contentHash}',
                  data: info,
                ),
              );
            }
          }
        } on Object catch (_) {}

        // Refresh Decks & Dashboard in real-time
        if (locator.isRegistered<DecksBloc>()) {
          locator<DecksBloc>().add(const DecksRefreshed());
        }
        if (locator.isRegistered<DashboardBloc>()) {
          locator<DashboardBloc>().add(const DashboardRefreshed());
        }

        emit(
          state.copyWith(
            status: ProcessingStatus.completed,
            stageMessage: 'Deck & flashcards synced to Supabase',
            generatedDeck: deck,
          ),
        );
      },
    );
  }

  Future<void> _onFetchUserDocuments(
    FetchUserDocumentsEvent event,
    Emitter<IngestionState> emit,
  ) async {
    final result = await _fetchUserDocs();
    result.fold(
      (failure) => null,
      (docs) {
        final attached = <String>{};
        final storage = locator.isRegistered<LocalStorageService>()
            ? locator<LocalStorageService>()
            : null;
        if (storage != null) {
          for (final d in docs) {
            final baseName = d.filename
                .replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '')
                .toLowerCase()
                .trim();
            for (final key in [
              'extracted_doc_${d.contentHash}',
              'extracted_doc_${d.id}',
              'extracted_doc_$baseName',
            ]) {
              final raw = storage.getPreference(key: key);
              if (raw != null && raw.isNotEmpty) {
                try {
                  final map = jsonDecode(raw) as Map<String, dynamic>;
                  final cCode = map['courseCode'] as String?;
                  final cId = map['courseId'] as String?;
                  if (cCode != null && cCode.isNotEmpty) {
                    attached
                      ..add('${d.id}_$cCode')
                      ..add('${d.contentHash}_$cCode')
                      ..add('${baseName}_$cCode');
                  }
                  if (cId != null && cId.isNotEmpty) {
                    attached
                      ..add('${d.id}_$cId')
                      ..add('${d.contentHash}_$cId')
                      ..add('${baseName}_$cId');
                  }
                } on Object catch (_) {}
              }
            }
          }
        }
        emit(
          state.copyWith(
            userDocuments: docs,
            attachedDocumentIds: {...state.attachedDocumentIds, ...attached},
          ),
        );
      },
    );
  }

  Future<void> _onProcessCameraImage(
    ProcessCameraImageEvent event,
    Emitter<IngestionState> emit,
  ) async {
    final docId = 'cam_${DateTime.now().millisecondsSinceEpoch}';
    emit(
      state.copyWith(
        status: ProcessingStatus.parsingOcr,
        stageMessage: 'Scanning camera image with on-device ML Kit...',
        currentDocument: DocumentUploadEntity(
          id: docId,
          userId: 'local_user',
          filename: event.filename,
          fileType: 'jpg',
          fileSizeBytes: event.imageBytes.length,
          storagePath: event.imagePath ?? '',
          contentHash: 'cam_${event.imageBytes.length}_$docId',
          status: ProcessingStatus.parsingOcr,
          createdAt: DateTime.now(),
        ),
      ),
    );

    final useCase = _processCameraOcr ??
        (locator.isRegistered<ProcessLocalCameraOcrUseCase>()
            ? locator<ProcessLocalCameraOcrUseCase>()
            : null);

    if (useCase == null) {
      emit(
        state.copyWith(
          status: ProcessingStatus.failed,
          errorMessage: 'Camera OCR processing engine unavailable.',
        ),
      );
      return;
    }

    final result = await useCase(
      imageBytes: event.imageBytes,
      documentId: docId,
      imagePath: event.imagePath,
      isOnline: event.isOnline,
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: ProcessingStatus.failed,
          errorMessage: failure.message,
        ),
      ),
      (snippets) => emit(
        state.copyWith(
          status: ProcessingStatus.completed,
          stageMessage: 'Extracted ${snippets.length} cards from camera capture',
          snippets: snippets,
        ),
      ),
    );
  }

  Future<void> _onFetchLmsCourses(
    FetchLmsCoursesEvent event,
    Emitter<IngestionState> emit,
  ) async {
    final useCase = _fetchLmsCourses ??
        (locator.isRegistered<FetchLmsCoursesUseCase>()
            ? locator<FetchLmsCoursesUseCase>()
            : null);

    if (useCase == null) {
      emit(
        state.copyWith(
          status: ProcessingStatus.failed,
          errorMessage: 'LMS service unavailable.',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: ProcessingStatus.parsingOcr,
        stageMessage:
            'Fetching courses from ${event.platform == 'canvas' ? 'Canvas' : 'Google Classroom'}...',
      ),
    );

    final result = await useCase(
      platform: event.platform,
      authToken: event.authToken,
      canvasDomain: event.canvasDomain,
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: ProcessingStatus.failed,
          errorMessage: failure.message,
        ),
      ),
      (courses) => emit(
        state.copyWith(
          status: ProcessingStatus.idle,
          lmsCourses: courses,
          stageMessage: 'Loaded ${courses.length} courses',
        ),
      ),
    );
  }

  Future<void> _onImportLmsCourse(
    ImportLmsCourseEvent event,
    Emitter<IngestionState> emit,
  ) async {
    final useCase = _importLmsCourse ??
        (locator.isRegistered<ImportLmsCourseUseCase>()
            ? locator<ImportLmsCourseUseCase>()
            : null);

    if (useCase == null) {
      emit(
        state.copyWith(
          status: ProcessingStatus.failed,
          errorMessage: 'LMS import service unavailable.',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: ProcessingStatus.parsingOcr,
        stageMessage: 'Importing course materials & generating flashcards...',
      ),
    );

    final result = await useCase(
      platform: event.platform,
      courseId: event.courseId,
      authToken: event.authToken,
      canvasDomain: event.canvasDomain,
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: ProcessingStatus.failed,
          errorMessage: failure.message,
        ),
      ),
      (importResult) {
        final doc = DocumentUploadEntity(
          id: 'lms_${importResult.bundle.course.platform}_${importResult.bundle.course.id}',
          userId: 'local_user',
          filename: '${importResult.bundle.course.name} Course Pack',
          fileType: 'lms',
          fileSizeBytes: importResult.bundle.syllabusContent.length,
          storagePath: '',
          contentHash: 'lms_${importResult.bundle.course.id}',
          status: ProcessingStatus.completed,
          createdAt: DateTime.now(),
        );

        emit(
          state.copyWith(
            status: ProcessingStatus.completed,
            currentDocument: doc,
            selectedCourse: importResult.bundle.course,
            snippets: importResult.snippets,
            stageMessage:
                'Synthesized ${importResult.snippets.length} flashcards from course',
          ),
        );
      },
    );
  }

  void _onResetIngestionState(
    ResetIngestionStateEvent event,
    Emitter<IngestionState> emit,
  ) {
    emit(const IngestionState());
  }

  @override
  Future<void> close() async {
    await _streamController?.dispose();
    return super.close();
  }
}
