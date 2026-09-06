import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/syllabot/domain/repositories/rag_repository.dart';
import 'package:kortex/src/features/syllabot/domain/use_cases/generate_document_embeddings_use_case.dart';
import 'package:mocktail/mocktail.dart';

class MockRagRepository extends Mock implements RagRepository {}

void main() {
  group('GenerateDocumentEmbeddingsUseCase Test Suite', () {
    late MockRagRepository mockRagRepository;
    late GenerateDocumentEmbeddingsUseCase useCase;

    setUp(() {
      mockRagRepository = MockRagRepository();
      useCase = GenerateDocumentEmbeddingsUseCase(mockRagRepository);
    });

    test('returns chunk count when repository successfully creates embeddings', () async {
      when(
        () => mockRagRepository.generateDocumentEmbeddings(
          documentId: 'doc_123',
          rawText: 'Photosynthesis converts light energy into chemical energy.',
          metadata: {'filename': 'biology_ch1.pdf'},
          chunks: any(named: 'chunks'),
        ),
      ).thenAnswer((_) async => const Right(12));

      final result = await useCase(
        documentId: 'doc_123',
        rawText: 'Photosynthesis converts light energy into chemical energy.',
        metadata: {'filename': 'biology_ch1.pdf'},
      );

      expect(result.isRight, isTrue);
      final count = (result as Right<Failure, int>).value;
      expect(count, equals(12));
      verify(
        () => mockRagRepository.generateDocumentEmbeddings(
          documentId: 'doc_123',
          rawText: 'Photosynthesis converts light energy into chemical energy.',
          metadata: {'filename': 'biology_ch1.pdf'},
          chunks: any(named: 'chunks'),
        ),
      ).called(1);
    });

    test('returns ServerFailure when repository fails', () async {
      when(
        () => mockRagRepository.generateDocumentEmbeddings(
          documentId: 'doc_456',
          rawText: 'Differential equations and boundary value problems.',
          metadata: any(named: 'metadata'),
          chunks: any(named: 'chunks'),
        ),
      ).thenAnswer(
        (_) async => const Left(ServerFailure(message: 'Edge function timeout')),
      );

      final result = await useCase(
        documentId: 'doc_456',
        rawText: 'Differential equations and boundary value problems.',
      );

      expect(result.isLeft, isTrue);
      final failure = (result as Left<Failure, int>).value;
      expect(failure.message, equals('Edge function timeout'));
    });
  });
}
