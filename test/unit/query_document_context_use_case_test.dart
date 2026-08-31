import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/syllabot/domain/entities/document_chunk_entity.dart';
import 'package:kortex/src/features/syllabot/domain/repositories/rag_repository.dart';
import 'package:kortex/src/features/syllabot/domain/use_cases/query_document_context_use_case.dart';
import 'package:mocktail/mocktail.dart';

class MockRagRepository extends Mock implements RagRepository {}

void main() {
  group('QueryDocumentContextUseCase RAG Vector Search Test Suite', () {
    late MockRagRepository mockRagRepository;
    late QueryDocumentContextUseCase useCase;

    const tChunks = [
      DocumentChunkEntity(
        id: 'chunk_1',
        documentId: 'doc_123',
        content: 'Thermodynamics Second Law: Entropy always increases.',
        similarityScore: 0.92,
        documentTitle: 'Physics University Vol 2',
        pageNumber: 142,
      ),
      DocumentChunkEntity(
        id: 'chunk_2',
        documentId: 'doc_123',
        content: 'Carnot heat engines operate at maximum efficiency.',
        similarityScore: 0.88,
        documentTitle: 'Physics University Vol 2',
        pageNumber: 145,
      ),
    ];

    setUp(() {
      mockRagRepository = MockRagRepository();
      useCase = QueryDocumentContextUseCase(mockRagRepository);
    });

    test('returns top relevant document chunks on successful vector match',
        () async {
      when(
        () => mockRagRepository.queryDocumentContext(
          query: 'Explain second law of thermodynamics and Carnot efficiency',
          matchThreshold: 0.65,
        ),
      ).thenAnswer((_) async => const Right(tChunks));

      final result = await useCase(
        query: 'Explain second law of thermodynamics and Carnot efficiency',
      );

      expect(result.isRight, isTrue);
      final chunks =
          (result as Right<dynamic, List<DocumentChunkEntity>>).value;
      expect(chunks.length, equals(2));
      expect(chunks.first.similarityScore, equals(0.92));
      expect(chunks.first.content, contains('Entropy always increases'));
    });

    test('propagates ServerFailure when vector RPC fails', () async {
      when(
        () => mockRagRepository.queryDocumentContext(
          query: any(named: 'query'),
          matchThreshold: any(named: 'matchThreshold'),
          matchCount: any(named: 'matchCount'),
          documentId: any(named: 'documentId'),
        ),
      ).thenAnswer(
        (_) async =>
            const Left(ServerFailure(message: 'Vector index unavailable')),
      );

      final result = await useCase(query: 'Organic reaction mechanisms');

      expect(result.isLeft, isTrue);
      final failure = (result as Left<Failure, dynamic>).value;
      expect(failure.message, equals('Vector index unavailable'));
    });
  });
}
