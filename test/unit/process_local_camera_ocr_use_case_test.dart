import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/ingestion/domain/entities/ocr_extraction_entity.dart';
import 'package:kortex/src/features/ingestion/domain/repositories/local_ocr_repository.dart';
import 'package:kortex/src/features/ingestion/domain/use_cases/process_local_camera_ocr_use_case.dart';
import 'package:mocktail/mocktail.dart';

class MockLocalOcrRepository extends Mock implements LocalOcrRepository {}

void main() {
  group('ProcessLocalCameraOcrUseCase Test Suite', () {
    late MockLocalOcrRepository mockRepository;
    late ProcessLocalCameraOcrUseCase useCase;

    final tBytes = Uint8List.fromList([10, 20, 30, 40]);

    const tEntities = [
      OcrExtractionEntity(
        id: 'ocr_1',
        documentId: 'doc_math',
        rawText: r'\int x dx = \frac{x^2}{2} + C',
        latexContent: r'\int x dx = \frac{x^2}{2} + C',
        topic: 'Integration Calculus',
        confidenceScore: 0.98,
      ),
    ];

    setUp(() {
      mockRepository = MockLocalOcrRepository();
      useCase = ProcessLocalCameraOcrUseCase(mockRepository);
    });

    test(
      'invokes repository processCapturedImage and returns extractions',
      () async {
        when(
          () => mockRepository.processCapturedImage(
            imageBytes: tBytes,
            documentId: 'doc_math',
            imagePath: any(named: 'imagePath'),
          ),
        ).thenAnswer((_) async => const Right(tEntities));

        final result = await useCase(
          imageBytes: tBytes,
          documentId: 'doc_math',
        );

        expect(result.isRight, isTrue);
        final list =
            (result as Right<dynamic, List<OcrExtractionEntity>>).value;
        expect(list.length, equals(1));
        expect(list.first.topic, equals('Integration Calculus'));
        expect(list.first.confidenceScore, equals(0.98));
      },
    );
  });
}
