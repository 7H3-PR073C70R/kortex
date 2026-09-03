import 'package:equatable/equatable.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/ingestion/domain/entities/document_upload_entity.dart';
import 'package:kortex/src/features/ingestion/domain/entities/ocr_extraction_entity.dart';
import 'package:kortex/src/features/ingestion/domain/entities/processing_status.dart';
import 'package:kortex/src/features/ingestion/domain/entities/synthesis_mode.dart';

class IngestionState extends Equatable {
  const IngestionState({
    this.status = ProcessingStatus.idle,
    this.uploadProgress = 0.0,
    this.synthesisMode = SynthesisMode.fastLocal,
    this.currentDocument,
    this.snippets = const [],
    this.userDocuments = const [],
    this.generatedDeck,
    this.errorMessage,
    this.stageMessage,
    this.wasDeduplicated = false,
  });

  final ProcessingStatus status;
  final double uploadProgress;
  final SynthesisMode synthesisMode;
  final DocumentUploadEntity? currentDocument;
  final List<OcrExtractionEntity> snippets;
  final List<DocumentUploadEntity> userDocuments;
  final DeckEntity? generatedDeck;
  final String? errorMessage;
  final String? stageMessage;
  final bool wasDeduplicated;

  bool get isUploading => status == ProcessingStatus.uploading;
  bool get isParsingOcr => status == ProcessingStatus.parsingOcr;
  bool get isGeneratingCards => status == ProcessingStatus.generatingCards;
  bool get isSyncingDb => status == ProcessingStatus.syncingDb;
  bool get isCompleted => status == ProcessingStatus.completed;
  bool get hasFailed => status == ProcessingStatus.failed;

  IngestionState copyWith({
    ProcessingStatus? status,
    double? uploadProgress,
    SynthesisMode? synthesisMode,
    DocumentUploadEntity? currentDocument,
    List<OcrExtractionEntity>? snippets,
    List<DocumentUploadEntity>? userDocuments,
    DeckEntity? generatedDeck,
    String? errorMessage,
    String? stageMessage,
    bool? wasDeduplicated,
  }) {
    return IngestionState(
      status: status ?? this.status,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      synthesisMode: synthesisMode ?? this.synthesisMode,
      currentDocument: currentDocument ?? this.currentDocument,
      snippets: snippets ?? this.snippets,
      userDocuments: userDocuments ?? this.userDocuments,
      generatedDeck: generatedDeck ?? this.generatedDeck,
      errorMessage: errorMessage ?? this.errorMessage,
      stageMessage: stageMessage ?? this.stageMessage,
      wasDeduplicated: wasDeduplicated ?? this.wasDeduplicated,
    );
  }

  @override
  List<Object?> get props => [
    status,
    uploadProgress,
    synthesisMode,
    currentDocument,
    snippets,
    userDocuments,
    generatedDeck,
    errorMessage,
    stageMessage,
    wasDeduplicated,
  ];
}
