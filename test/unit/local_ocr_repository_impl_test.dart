import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/ingestion/data/client/local_mlkit_ocr_client.dart';
import 'package:kortex/src/features/ingestion/data/data_sources/ingestion_remote_data_source.dart';
import 'package:kortex/src/features/ingestion/data/data_sources/ocr_local_data_source.dart';
import 'package:kortex/src/features/ingestion/data/models/ocr_extraction_model.dart';
import 'package:kortex/src/features/ingestion/data/repositories/local_ocr_repository_impl.dart';
import 'package:kortex/src/features/ingestion/domain/entities/ocr_extraction_entity.dart';
import 'package:mocktail/mocktail.dart';

class MockOcrLocalDataSource extends Mock implements OcrLocalDataSource {}

class MockIngestionRemoteDataSource extends Mock
    implements IngestionRemoteDataSource {}

void main() {
  group('LocalOcrRepositoryImpl Test Suite', () {
    late MockOcrLocalDataSource mockLocalDataSource;
    late MockIngestionRemoteDataSource mockRemoteDataSource;
    late LocalOcrRepositoryImpl repository;

    final tBytes = Uint8List.fromList([1, 2, 3, 4]);

    const tLocalEntities = [
      OcrExtractionEntity(
        id: 'ocr_local_doc1_0',
        documentId: 'doc1',
        rawText: 'E = mc^2',
        latexContent: 'E = mc^2',
        topic: 'Extracted STEM Content',
        confidenceScore: 0.96,
      ),
    ];

    const tCloudModels = [
      OcrExtractionModel(
        id: 'ocr_cloud_1',
        documentId: 'doc1',
        rawText: 'E = mc^2',
        latexContent: 'E = m c^2',
        topic: 'Relativistic Mechanics',
        confidenceScore: 0.99,
      ),
    ];

    setUp(() {
      mockLocalDataSource = MockOcrLocalDataSource();
      mockRemoteDataSource = MockIngestionRemoteDataSource();
      repository = LocalOcrRepositoryImpl(
        localDataSource: mockLocalDataSource,
        remoteDataSource: mockRemoteDataSource,
      );
    });

    test('processLiveCameraFrame returns detected blocks', () async {
      const tBlocks = [
        RecognizedTextBlock(
          text: 'PV = nRT',
          left: 20,
          top: 40,
          width: 120,
          height: 30,
        ),
      ];

      when(
        () => mockLocalDataSource.processFrame(
          tBytes,
          imagePath: any(named: 'imagePath'),
        ),
      ).thenAnswer((_) async => tBlocks);

      final result = await repository.processLiveCameraFrame(
        frameBytes: tBytes,
      );

      expect(result.isRight, isTrue);
      final blocks =
          (result as Right<dynamic, List<RecognizedTextBlock>>).value;
      expect(blocks.length, equals(1));
      expect(blocks.first.text, equals('PV = nRT'));
    });

    test('processCapturedImage performs on-device OCR and syncs cloud LaTeX',
        () async {
      when(
        () => mockLocalDataSource.extractFromImage(
          tBytes,
          documentId: 'doc1',
          imagePath: any(named: 'imagePath'),
        ),
      ).thenAnswer((_) async => tLocalEntities);

      when(
        () => mockLocalDataSource.queueForSync(
          documentId: 'doc1',
          rawText: any(named: 'rawText'),
          localPath: any(named: 'localPath'),
        ),
      ).thenAnswer((_) async {});

      when(
        () => mockRemoteDataSource.processStemOcr(
          documentId: 'doc1',
          storagePath: any(named: 'storagePath'),
          fileType: 'image/jpeg',
        ),
      ).thenAnswer((_) async => tCloudModels);

      when(
        () => mockLocalDataSource.markSyncComplete('doc1'),
      ).thenAnswer((_) async {});

      final result = await repository.processCapturedImage(
        imageBytes: tBytes,
        documentId: 'doc1',
      );

      expect(result.isRight, isTrue);
      final list = (result as Right<dynamic, List<OcrExtractionEntity>>).value;
      expect(list.length, equals(1));
      expect(list.first.latexContent, equals('E = m c^2'));
      verify(() => mockLocalDataSource.markSyncComplete('doc1')).called(1);
    });

    test('getPendingSyncCount returns queue count', () async {
      when(() => mockLocalDataSource.getPendingSyncItems()).thenAnswer(
        (_) async => [
          {'document_id': 'doc_1'},
          {'document_id': 'doc_2'},
        ],
      );

      final result = await repository.getPendingSyncCount();

      expect(result.isRight, isTrue);
      final count = (result as Right<dynamic, int>).value;
      expect(count, equals(2));
    });
  });
}
