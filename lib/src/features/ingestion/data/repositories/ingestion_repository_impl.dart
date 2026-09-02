import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/extensions/repository_extension.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';
import 'package:kortex/src/features/ingestion/data/data_sources/ingestion_remote_data_source.dart';
import 'package:kortex/src/features/ingestion/domain/entities/document_upload_entity.dart';
import 'package:kortex/src/features/ingestion/domain/entities/ocr_extraction_entity.dart';
import 'package:kortex/src/features/ingestion/domain/repositories/ingestion_repository.dart';

class IngestionRepositoryImpl implements IngestionRepository {
  IngestionRepositoryImpl(this._remoteDataSource);

  final IngestionRemoteDataSource _remoteDataSource;

  @override
  Future<Either<Failure, DocumentUploadEntity>> uploadDocument({
    required String filename,
    required String fileType,
    required Uint8List fileBytes,
    void Function(double progress)? onProgress,
  }) {
    return Future<DocumentUploadEntity>.sync(() async {
      // 1. Compute SHA-256 content hash for smart storage deduplication
      final hash = sha256.convert(fileBytes).toString();

      // 2. System-wide Content-Addressable check & Reference Assignment
      final existing = await _remoteDataSource.findOrCreateDocumentReference(
        contentHash: hash,
        filename: filename,
        fileType: fileType,
        fileSizeBytes: fileBytes.lengthInBytes,
      );

      if (existing != null) {
        if (onProgress != null) onProgress(1);
        return existing.toEntity();
      }

      // 3. Brand-new content: upload to storage and register metadata
      final model = await _remoteDataSource.uploadDocument(
        filename: filename,
        fileType: fileType,
        fileBytes: fileBytes,
        contentHash: hash,
        onProgress: onProgress,
      );

      return model.toEntity();
    }).makeRequest();
  }

  @override
  Future<Either<Failure, List<OcrExtractionEntity>>> processStemOcr({
    required String documentId,
    required String storagePath,
    required String fileType,
  }) {
    return _remoteDataSource
        .processStemOcr(
          documentId: documentId,
          storagePath: storagePath,
          fileType: fileType,
        )
        .then((models) => models.map((m) => m.toEntity()).toList())
        .makeRequest();
  }

  @override
  Future<Either<Failure, List<DocumentUploadEntity>>> fetchUserDocuments() {
    return _remoteDataSource
        .fetchUserDocuments()
        .then((models) => models.map((m) => m.toEntity()).toList())
        .makeRequest();
  }

  @override
  Future<Either<Failure, DeckEntity>> generateFlashcardsFromDoc({
    required String documentId,
    required String deckTitle,
    required String subject,
    required List<OcrExtractionEntity> snippets,
  }) {
    return Future<DeckEntity>.sync(() {
      final cards = <FlashcardEntity>[];

      for (var i = 0; i < snippets.length; i++) {
        final snippet = snippets[i];
        cards.add(
          FlashcardEntity(
            id: 'ocr_card_${documentId}_$i',
            deckId: 'deck_$documentId',
            front: snippet.topic.isNotEmpty
                ? snippet.topic
                : 'Formula / Concept ${i + 1}',
            back: snippet.rawText,
            backLatex: snippet.latexContent,
            nextDueDate: DateTime.now().add(const Duration(days: 1)),
          ),
        );
      }

      final prefix = documentId.substring(
        0,
        documentId.length > 8 ? 8 : documentId.length,
      );
      return DeckEntity(
        id: 'deck_$prefix',
        title: deckTitle,
        subject: subject,
        totalCards: cards.length,
        dueCards: cards.length,
        masteryRate: 0,
        category: 'STEM Ingestion',
        description: 'Auto-synthesized from document $documentId',
        cards: cards,
      );
    }).makeRequest();
  }
}
