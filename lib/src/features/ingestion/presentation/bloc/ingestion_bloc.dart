import 'dart:async';
import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/ingestion/domain/entities/document_upload_entity.dart';
import 'package:kortex/src/features/ingestion/domain/entities/processing_status.dart';
import 'package:kortex/src/features/ingestion/domain/entities/synthesis_mode.dart';
import 'package:kortex/src/features/ingestion/domain/use_cases/fetch_lms_courses_use_case.dart';
import 'package:kortex/src/features/ingestion/domain/use_cases/fetch_user_documents_use_case.dart';
import 'package:kortex/src/features/ingestion/domain/use_cases/generate_flashcards_from_doc_use_case.dart';
import 'package:kortex/src/features/ingestion/domain/use_cases/import_lms_course_use_case.dart';
import 'package:kortex/src/features/ingestion/domain/use_cases/process_local_camera_ocr_use_case.dart';
import 'package:kortex/src/features/ingestion/domain/use_cases/process_stem_ocr_use_case.dart';
import 'package:kortex/src/features/ingestion/domain/use_cases/upload_study_document_use_case.dart';
import 'package:kortex/src/features/ingestion/presentation/bloc/ingestion_event.dart';
import 'package:kortex/src/features/ingestion/presentation/bloc/ingestion_state.dart';

class IngestionBloc extends Bloc<IngestionEvent, IngestionState> {
  IngestionBloc({
    required UploadStudyDocumentUseCase uploadUseCase,
    required ProcessStemOcrUseCase processOcrUseCase,
    required GenerateFlashcardsFromDocUseCase generateDeckUseCase,
    required FetchUserDocumentsUseCase fetchUserDocsUseCase,
    ProcessLocalCameraOcrUseCase? processCameraOcrUseCase,
    FetchLmsCoursesUseCase? fetchLmsCoursesUseCase,
    ImportLmsCourseUseCase? importLmsCourseUseCase,
  }) : _upload = uploadUseCase,
       _processOcr = processOcrUseCase,
       _generateDeck = generateDeckUseCase,
       _fetchUserDocs = fetchUserDocsUseCase,
       _processCameraOcr = processCameraOcrUseCase,
       _fetchLmsCourses = fetchLmsCoursesUseCase,
       _importLmsCourse = importLmsCourseUseCase,
       super(const IngestionState()) {
    on<PickAndUploadFileEvent>(_onPickAndUploadFile);
    on<UploadProgressUpdatedEvent>(_onUploadProgressUpdated);
    on<SetSynthesisModeEvent>(_onSetSynthesisMode);
    on<TriggerOcrParsingEvent>(_onTriggerOcrParsing);
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
  final ProcessLocalCameraOcrUseCase? _processCameraOcr;
  final FetchLmsCoursesUseCase? _fetchLmsCourses;
  final ImportLmsCourseUseCase? _importLmsCourse;

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
        emit(
          state.copyWith(
            uploadProgress: 1,
            currentDocument: doc,
            wasDeduplicated: doc.isDeduplicated,
          ),
        );

        // Immediately trigger STEM OCR parsing
        add(
          TriggerOcrParsingEvent(
            documentId: doc.id,
            storagePath: doc.storagePath,
            fileType: doc.fileType,
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

    if (isDeduplicated) {
      // Multi-stage simulated synthesis animation (illusion of active generation)
      emit(
        state.copyWith(
          status: ProcessingStatus.parsingOcr,
          stageMessage: 'Analyzing document structure...',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 600));

      emit(
        state.copyWith(
          stageMessage: 'Extracting conceptual frameworks...',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 600));

      emit(
        state.copyWith(
          stageMessage: 'Compiling synthesized study deck...',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 500));
    } else {
      emit(
        state.copyWith(
          status: ProcessingStatus.parsingOcr,
          stageMessage: isAi
              ? 'Synthesizing with AI Smart Synthesis...'
              : 'Reading document locally...',
        ),
      );
    }

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
      (docs) => emit(state.copyWith(userDocuments: docs)),
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
}
