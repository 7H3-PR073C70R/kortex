import 'dart:typed_data';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/ingestion/domain/entities/document_upload_entity.dart';
import 'package:kortex/src/features/ingestion/domain/entities/ocr_extraction_entity.dart';

/// Contract defining study document ingestion, STEM OCR, and deck conversion.
abstract class IngestionRepository {
  /// Uploads file bytes with automatic SHA-256 deduplication.
  /// If identical content exists, reuses existing document without re-upload.
  Future<Either<Failure, DocumentUploadEntity>> uploadDocument({
    required String filename,
    required String fileType,
    required Uint8List fileBytes,
    void Function(double progress)? onProgress,
  });

  /// Triggers the STEM OCR pipeline to extract raw text & LaTeX formulas.
  Future<Either<Failure, List<OcrExtractionEntity>>> processStemOcr({
    required String documentId,
    required String storagePath,
    required String fileType,
  });

  /// Fetches all previously ingested documents for the authenticated user.
  Future<Either<Failure, List<DocumentUploadEntity>>> fetchUserDocuments();

  /// Converts approved OCR snippets into an active recall Spaced
  /// Repetition Deck.
  Future<Either<Failure, DeckEntity>> generateFlashcardsFromDoc({
    required String documentId,
    required String deckTitle,
    required String subject,
    required List<OcrExtractionEntity> snippets,
  });
}
