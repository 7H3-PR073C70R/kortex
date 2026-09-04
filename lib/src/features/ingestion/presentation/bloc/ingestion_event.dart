import 'package:flutter/foundation.dart';
import 'package:kortex/src/features/ingestion/domain/entities/ocr_extraction_entity.dart';
import 'package:kortex/src/features/ingestion/domain/entities/synthesis_mode.dart';

@immutable
sealed class IngestionEvent {
  const IngestionEvent();
}

/// User selected or dropped a file.
final class PickAndUploadFileEvent extends IngestionEvent {
  const PickAndUploadFileEvent({
    required this.filename,
    required this.fileType,
    required this.fileBytes,
  });

  final String filename;
  final String fileType;
  final Uint8List fileBytes;
}

/// Progress callback fired during file upload.
final class UploadProgressUpdatedEvent extends IngestionEvent {
  const UploadProgressUpdatedEvent(this.progress);
  final double progress;
}

/// Trigger STEM OCR parsing for the uploaded document.
final class TriggerOcrParsingEvent extends IngestionEvent {
  const TriggerOcrParsingEvent({
    required this.documentId,
    required this.storagePath,
    required this.fileType,
  });

  final String documentId;
  final String storagePath;
  final String fileType;
}

/// User modified extracted snippet text or LaTeX in live editor.
final class UpdateSnippetContentEvent extends IngestionEvent {
  const UpdateSnippetContentEvent({
    required this.snippetId,
    required this.updatedRawText,
    this.updatedLatex,
    this.updatedTopic,
  });

  final String snippetId;
  final String updatedRawText;
  final String? updatedLatex;
  final String? updatedTopic;
}

/// Generate flashcards from the current list of OCR snippets.
final class GenerateFlashcardsFromSnippetsEvent extends IngestionEvent {
  const GenerateFlashcardsFromSnippetsEvent({
    required this.documentId,
    required this.deckTitle,
    required this.subject,
    required this.snippets,
  });

  final String documentId;
  final String deckTitle;
  final String subject;
  final List<OcrExtractionEntity> snippets;
}

/// Fetch list of previously uploaded documents.
final class FetchUserDocumentsEvent extends IngestionEvent {
  const FetchUserDocumentsEvent();
}

/// Toggle synthesis mode between Tier 1 (Fast Local) and Tier 2 (AI Smart).
final class SetSynthesisModeEvent extends IngestionEvent {
  const SetSynthesisModeEvent(this.mode);
  final SynthesisMode mode;
}

/// Reset ingestion pipeline to idle.
final class ResetIngestionStateEvent extends IngestionEvent {
  const ResetIngestionStateEvent();
}

/// Process captured camera image directly via on-device ML Kit OCR.
final class ProcessCameraImageEvent extends IngestionEvent {
  const ProcessCameraImageEvent({
    required this.filename,
    required this.imageBytes,
    this.imagePath,
    this.isOnline = true,
  });

  final String filename;
  final Uint8List imageBytes;
  final String? imagePath;
  final bool isOnline;
}

/// Fetch list of enrolled courses from Google Classroom or Canvas.
final class FetchLmsCoursesEvent extends IngestionEvent {
  const FetchLmsCoursesEvent({
    required this.platform,
    required this.authToken,
    this.canvasDomain,
  });

  final String platform;
  final String authToken;
  final String? canvasDomain;
}

/// Import course bundle (syllabus & assignments) into reviewable study snippets.
final class ImportLmsCourseEvent extends IngestionEvent {
  const ImportLmsCourseEvent({
    required this.platform,
    required this.courseId,
    required this.authToken,
    this.canvasDomain,
  });

  final String platform;
  final String courseId;
  final String authToken;
  final String? canvasDomain;
}
