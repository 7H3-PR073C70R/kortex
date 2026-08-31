import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/ingestion/data/data_sources/ingestion_remote_data_source.dart';
import 'package:kortex/src/features/ingestion/data/models/document_upload_model.dart';
import 'package:kortex/src/features/ingestion/data/repositories/ingestion_repository_impl.dart';
import 'package:kortex/src/features/ingestion/domain/entities/ocr_extraction_entity.dart';
import 'package:mocktail/mocktail.dart';

class MockIngestionRemoteDataSource extends Mock
    implements IngestionRemoteDataSource {}

void main() {
  late MockIngestionRemoteDataSource mockDataSource;
  late IngestionRepositoryImpl repository;

  final testBytes = Uint8List.fromList([10, 20, 30, 40]);
  final expectedHash = sha256.convert(testBytes).toString();

  final existingModel = DocumentUploadModel(
    id: 'doc_existing_123',
    userId: 'user_1',
    filename: 'existing_calc.pdf',
    fileType: 'pdf',
    fileSizeBytes: 4,
    storagePath: 'doc_existing_123.pdf',
    contentHash: expectedHash,
    processingStatus: 'completed',
    createdAt: DateTime(2026, 8, 30),
    isDeduplicated: true,
  );

  final newModel = DocumentUploadModel(
    id: 'doc_new_456',
    userId: 'user_1',
    filename: 'new_calc.pdf',
    fileType: 'pdf',
    fileSizeBytes: 4,
    storagePath: 'doc_new_456.pdf',
    contentHash: expectedHash,
    processingStatus: 'uploaded',
    createdAt: DateTime(2026, 8, 31),
  );

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    mockDataSource = MockIngestionRemoteDataSource();
    repository = IngestionRepositoryImpl(mockDataSource);
  });

  group('IngestionRepositoryImpl - Content-Addressable Deduplication', () {
    test(
        'assigns instance/reference without storage upload when hash matches existing content',
        () async {
      when(
        () => mockDataSource.findOrCreateDocumentReference(
          contentHash: expectedHash,
          filename: 'renamed_calc.pdf',
          fileType: 'pdf',
          fileSizeBytes: 4,
        ),
      ).thenAnswer((_) async => existingModel);

      final result = await repository.uploadDocument(
        filename: 'renamed_calc.pdf',
        fileType: 'pdf',
        fileBytes: testBytes,
      );

      expect(result.isRight, isTrue);
      result.fold(
        (l) => fail('Should not fail'),
        (doc) {
          expect(doc.id, 'doc_existing_123');
          expect(doc.isDeduplicated, isTrue);
          expect(doc.contentHash, expectedHash);
        },
      );

      // Verify uploadDocument on remote data source was NOT called
      verifyNever(
        () => mockDataSource.uploadDocument(
          filename: any(named: 'filename'),
          fileType: any(named: 'fileType'),
          fileBytes: any(named: 'fileBytes'),
          contentHash: any(named: 'contentHash'),
          onProgress: any(named: 'onProgress'),
        ),
      );
    });

    test('uploads to storage when content hash is novel in the system',
        () async {
      when(
        () => mockDataSource.findOrCreateDocumentReference(
          contentHash: expectedHash,
          filename: 'new_calc.pdf',
          fileType: 'pdf',
          fileSizeBytes: 4,
        ),
      ).thenAnswer((_) async => null);

      when(
        () => mockDataSource.uploadDocument(
          filename: 'new_calc.pdf',
          fileType: 'pdf',
          fileBytes: testBytes,
          contentHash: expectedHash,
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((_) async => newModel);

      final result = await repository.uploadDocument(
        filename: 'new_calc.pdf',
        fileType: 'pdf',
        fileBytes: testBytes,
      );

      expect(result.isRight, isTrue);
      result.fold(
        (l) => fail('Should not fail'),
        (doc) {
          expect(doc.id, 'doc_new_456');
          expect(doc.isDeduplicated, isFalse);
        },
      );

      verify(
        () => mockDataSource.uploadDocument(
          filename: 'new_calc.pdf',
          fileType: 'pdf',
          fileBytes: testBytes,
          contentHash: expectedHash,
          onProgress: any(named: 'onProgress'),
        ),
      ).called(1);
    });

    test('generates DeckEntity with LaTeX flashcards correctly', () async {
      const snippets = [
        OcrExtractionEntity(
          id: 'snip_1',
          documentId: 'doc_123',
          rawText: 'Integration by parts formula',
          latexContent: r'$$\int u \, dv = uv - \int v \, du$$',
          topic: 'Calculus II',
        ),
      ];

      final result = await repository.generateFlashcardsFromDoc(
        documentId: 'doc_12345678',
        deckTitle: 'Calculus Fundamentals',
        subject: 'Mathematics',
        snippets: snippets,
      );

      expect(result.isRight, isTrue);
      result.fold(
        (l) => fail('Should succeed'),
        (deck) {
          expect(deck.title, 'Calculus Fundamentals');
          expect(deck.cards.length, 1);
          expect(deck.cards.first.front, 'Calculus II');
          expect(deck.cards.first.back, 'Integration by parts formula');
          expect(
            deck.cards.first.backLatex,
            r'$$\int u \, dv = uv - \int v \, du$$',
          );
        },
      );
    });
  });
}
