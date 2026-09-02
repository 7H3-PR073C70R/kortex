import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/features/ingestion/domain/entities/processing_status.dart';
import 'package:kortex/src/features/ingestion/domain/entities/synthesis_mode.dart';
import 'package:kortex/src/features/ingestion/domain/use_cases/fetch_user_documents_use_case.dart';
import 'package:kortex/src/features/ingestion/domain/use_cases/generate_flashcards_from_doc_use_case.dart';
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
  })  : _upload = uploadUseCase,
        _processOcr = processOcrUseCase,
        _generateDeck = generateDeckUseCase,
        _fetchUserDocs = fetchUserDocsUseCase,
        super(const IngestionState()) {
    on<PickAndUploadFileEvent>(_onPickAndUploadFile);
    on<UploadProgressUpdatedEvent>(_onUploadProgressUpdated);
    on<SetSynthesisModeEvent>(_onSetSynthesisMode);
    on<TriggerOcrParsingEvent>(_onTriggerOcrParsing);
    on<UpdateSnippetContentEvent>(_onUpdateSnippetContent);
    on<GenerateFlashcardsFromSnippetsEvent>(_onGenerateFlashcards);
    on<FetchUserDocumentsEvent>(_onFetchUserDocuments);
    on<ResetIngestionStateEvent>(_onResetIngestionState);
  }

  final UploadStudyDocumentUseCase _upload;
  final ProcessStemOcrUseCase _processOcr;
  final GenerateFlashcardsFromDocUseCase _generateDeck;
  final FetchUserDocumentsUseCase _fetchUserDocs;

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
    emit(
      state.copyWith(
        status: ProcessingStatus.parsingOcr,
        stageMessage: isAi
            ? 'Synthesizing with AI Smart Synthesis...'
            : 'Reading document locally...',
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
            stageMessage: isAi
                ? 'AI synthesized ${snippets.length} conceptual cards'
                : 'Extracted ${snippets.length} study cards locally',
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

  void _onResetIngestionState(
    ResetIngestionStateEvent event,
    Emitter<IngestionState> emit,
  ) {
    emit(const IngestionState());
  }
}
