import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/extensions/repository_extension.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/core/utils/uuid_utils.dart';
import 'package:kortex/src/features/decks/data/data_sources/decks_remote_data_source.dart';
import 'package:kortex/src/features/decks/data/models/deck_model.dart';
import 'package:kortex/src/features/decks/data/models/flashcard_model.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';
import 'package:kortex/src/features/ingestion/data/data_sources/ingestion_remote_data_source.dart';
import 'package:kortex/src/features/ingestion/domain/entities/document_upload_entity.dart';
import 'package:kortex/src/features/ingestion/domain/entities/ocr_extraction_entity.dart';
import 'package:kortex/src/features/ingestion/domain/entities/processing_status.dart';
import 'package:kortex/src/features/ingestion/domain/repositories/ingestion_repository.dart';

class IngestionRepositoryImpl implements IngestionRepository {
  IngestionRepositoryImpl(
    this._remoteDataSource, {
    DecksRemoteDataSource? decksRemoteDataSource,
  }) : _decksRemoteDataSource = decksRemoteDataSource;

  final IngestionRemoteDataSource _remoteDataSource;
  final DecksRemoteDataSource? _decksRemoteDataSource;

  @override
  Future<Either<Failure, DocumentUploadEntity>> uploadDocument({
    required String filename,
    required String fileType,
    required Uint8List fileBytes,
    String? courseId,
    String? courseCode,
    String? deckTitle,
    void Function(double progress)? onProgress,
  }) {
    return Future<DocumentUploadEntity>.sync(() async {
      // 1. Compute SHA-256 content hash for Content-Addressable Storage
      final hash = sha256.convert(fileBytes).toString();

      // 2. Multi-tenant Preflight Check with Transaction Advisory Locking
      try {
        final preflight = await _remoteDataSource
            .claimOrCreateDocumentPreflight(
              contentHash: hash,
              filename: filename,
              fileType: fileType,
              fileSizeBytes: fileBytes.lengthInBytes,
              courseId: courseId,
              courseCode: courseCode,
              deckTitle: deckTitle,
            );

        final status = preflight['status'] as String?;
        final userDocId = preflight['user_doc_id'] as String?;
        final storagePath = preflight['storage_path'] as String?;
        final deckId = preflight['deck_id'] as String?;

        if (userDocId != null) {
          _remoteDataSource.cacheDocumentBytes(
            userDocId,
            fileBytes,
            filename: filename,
          );

          // CASE 1: Instant match - Deck already completed by another user
          if (status == 'ready' && deckId != null) {
            onProgress?.call(1);
            return DocumentUploadEntity(
              id: userDocId,
              userId: '',
              filename: filename,
              fileType: fileType,
              fileSizeBytes: fileBytes.lengthInBytes,
              storagePath: storagePath ?? 'canonical/$hash.pdf',
              contentHash: hash,
              status: ProcessingStatus.completed,
              createdAt: DateTime.now(),
              isDeduplicated: true,
              deckId: deckId,
            );
          }

          // CASE 2: In-progress synthesis by concurrent user
          if (status == 'in_progress') {
            onProgress?.call(0.5);
            return DocumentUploadEntity(
              id: userDocId,
              userId: '',
              filename: filename,
              fileType: fileType,
              fileSizeBytes: fileBytes.lengthInBytes,
              storagePath: storagePath ?? 'canonical/$hash.pdf',
              contentHash: hash,
              status: ProcessingStatus.generatingCards,
              createdAt: DateTime.now(),
              isDeduplicated: true,
            );
          }

          // CASE 3: Novel upload or Reprocess required
          if (status == 'upload_required' || status == 'reprocess_required') {
            final model = await _remoteDataSource.uploadDocument(
              filename: filename,
              fileType: fileType,
              fileBytes: fileBytes,
              contentHash: hash,
              customStoragePath: storagePath,
              customDocId: userDocId,
              onProgress: onProgress,
            );

            return model.toEntity();
          }
        }
      } on Object catch (_) {
        // Fallback to legacy reference check if preflight throws
        final existing = await _remoteDataSource.findOrCreateDocumentReference(
          contentHash: hash,
          filename: filename,
          fileType: fileType,
          fileSizeBytes: fileBytes.lengthInBytes,
        );

        if (existing != null) {
          _remoteDataSource.cacheDocumentBytes(
            existing.id,
            fileBytes,
            filename: filename,
          );
          if (onProgress != null) onProgress(1);
          return existing.toEntity();
        }
      }

      // Default fallback: upload directly
      final model = await _remoteDataSource.uploadDocument(
        filename: filename,
        fileType: fileType,
        fileBytes: fileBytes,
        contentHash: hash,
        onProgress: onProgress,
      );

      _remoteDataSource.cacheDocumentBytes(
        model.id,
        fileBytes,
        filename: filename,
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
  Future<Either<Failure, void>> deleteDocument(String documentId) {
    return _remoteDataSource.deleteDocument(documentId).makeRequest();
  }

  @override
  Future<Either<Failure, DeckEntity>> generateFlashcardsFromDoc({
    required String documentId,
    required String deckTitle,
    required String subject,
    required List<OcrExtractionEntity> snippets,
    String? courseId,
    String? courseCode,
  }) {
    return Future<DeckEntity>.sync(() async {
      final deckId = UuidUtils.generate();
      final cards = <FlashcardEntity>[];

      for (var i = 0; i < snippets.length; i++) {
        final snippet = snippets[i];
        cards.add(
          FlashcardEntity(
            id: UuidUtils.generate(),
            deckId: deckId,
            front: snippet.topic.isNotEmpty
                ? snippet.topic
                : 'Concept ${i + 1}',
            back: snippet.rawText,
            backLatex: snippet.latexContent,
            imageUrl: snippet.imageUrl,
            sourceTopic: snippet.topic,
            nextDueDate: DateTime.now().add(const Duration(days: 1)),
          ),
        );
      }

      final deckEntity = DeckEntity(
        id: deckId,
        title: deckTitle,
        subject: subject,
        totalCards: cards.length,
        dueCards: cards.where((c) => c.isDueToday).length,
        masteryRate: 0,
        category: 'Document Ingestion',
        description: 'Auto-synthesized from document $documentId',
        cards: cards,
        courseId: courseId,
        courseCode: courseCode,
      );

      await _decksRemoteDataSource?.saveGeneratedDeck(
        deck: DeckModel.fromEntity(deckEntity),
        cards: cards.map(FlashcardModel.fromEntity).toList(),
      );

      return deckEntity;
    }).makeRequest();
  }
}
