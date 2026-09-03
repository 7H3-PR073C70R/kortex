import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/syllabot/data/data_sources/rag_remote_data_source.dart';
import 'package:kortex/src/features/syllabot/data/models/document_chunk_model.dart';
import 'package:kortex/src/features/syllabot/data/repositories/rag_repository_impl.dart';
import 'package:kortex/src/features/syllabot/domain/entities/document_chunk_entity.dart';
import 'package:mocktail/mocktail.dart';

class MockRagRemoteDataSource extends Mock implements RagRemoteDataSource {}

void main() {
  group('RagRepositoryImpl Vector Pipeline Test Suite', () {
    late MockRagRemoteDataSource mockRemoteDataSource;
    late RagRepositoryImpl repository;

    const tChunkModels = [
      DocumentChunkModel(
        id: 'chk_101',
        documentId: 'doc_mit_calc',
        content: 'Calculus Fundamental Theorem Part 1 connects calculus ideas.',
        similarityScore: 0.95,
        documentTitle: 'Calculus Early Transcendentals',
        pageNumber: 210,
      ),
    ];

    setUp(() {
      mockRemoteDataSource = MockRagRemoteDataSource();
      repository = RagRepositoryImpl(mockRemoteDataSource);
    });

    test(
      'queryDocumentContext returns mapped entity list on success',
      () async {
        when(
          () => mockRemoteDataSource.queryDocumentContext(
            query: 'Fundamental Theorem of Calculus',
            matchThreshold: 0.70,
            matchCount: 3,
          ),
        ).thenAnswer((_) async => tChunkModels);

        final result = await repository.queryDocumentContext(
          query: 'Fundamental Theorem of Calculus',
        );

        expect(result.isRight, isTrue);
        final list =
            (result as Right<dynamic, List<DocumentChunkEntity>>).value;
        expect(list.length, equals(1));
        expect(list.first.id, equals('chk_101'));
        expect(list.first.similarityScore, equals(0.95));
      },
    );

    test('generateDocumentEmbeddings returns chunk count on success', () async {
      when(
        () => mockRemoteDataSource.generateDocumentEmbeddings(
          documentId: 'doc_mit_calc',
          rawText: 'Full textbook text...',
          metadata: any(named: 'metadata'),
        ),
      ).thenAnswer((_) async => 8);

      final result = await repository.generateDocumentEmbeddings(
        documentId: 'doc_mit_calc',
        rawText: 'Full textbook text...',
      );

      expect(result.isRight, isTrue);
      final count = (result as Right<dynamic, int>).value;
      expect(count, equals(8));
    });
  });
}
