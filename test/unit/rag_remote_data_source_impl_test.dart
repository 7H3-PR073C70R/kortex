import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/syllabot/data/client/vector_search_client.dart';
import 'package:kortex/src/features/syllabot/data/data_sources/rag_remote_data_source_impl.dart';
import 'package:mocktail/mocktail.dart';

class MockVectorSearchClient extends Mock implements VectorSearchClient {}

void main() {
  group('RagRemoteDataSourceImpl Test Suite', () {
    late MockVectorSearchClient mockClient;
    late RagRemoteDataSourceImpl dataSource;

    setUp(() {
      mockClient = MockVectorSearchClient();
      dataSource = RagRemoteDataSourceImpl(mockClient);
    });

    test('generateDocumentEmbeddings with small chunk count (<= 25) sends single batch', () async {
      final chunks = List.generate(
        15,
        (i) => {'content': 'Chunk $i content', 'chunk_index': i},
      );

      when(
        () => mockClient.generateEmbeddings(
          documentId: 'doc_small',
          chunks: chunks,
          metadata: {'filename': 'notes.pdf'},
        ),
      ).thenAnswer((_) async => {'success': true, 'chunks_created': 15});

      final result = await dataSource.generateDocumentEmbeddings(
        documentId: 'doc_small',
        rawText: 'Some raw text',
        chunks: chunks,
        metadata: {'filename': 'notes.pdf'},
      );

      expect(result, equals(15));
      verify(
        () => mockClient.generateEmbeddings(
          documentId: 'doc_small',
          chunks: chunks,
          metadata: {'filename': 'notes.pdf'},
        ),
      ).called(1);
    });

    test('generateDocumentEmbeddings with large textbook chunks (> 25) batches into groups of 25', () async {
      final chunks = List.generate(
        60,
        (i) => {'content': 'Textbook Chapter Chunk $i', 'chunk_index': i},
      );

      // Batches expected: 0..25 (25 items), 25..50 (25 items), 50..60 (10 items)
      when(
        () => mockClient.generateEmbeddings(
          documentId: 'doc_textbook',
          chunks: any(named: 'chunks'),
          metadata: any(named: 'metadata'),
        ),
      ).thenAnswer((invocation) {
        final batch =
            invocation.namedArguments[#chunks] as List<Map<String, dynamic>>;
        return Future.value({'success': true, 'chunks_created': batch.length});
      });

      final result = await dataSource.generateDocumentEmbeddings(
        documentId: 'doc_textbook',
        rawText: 'Full 500-page textbook text...',
        chunks: chunks,
        metadata: {'filename': 'physics_textbook.pdf'},
      );

      expect(result, equals(60));

      // Verify exactly 3 batches were sent across the wire
      verify(
        () => mockClient.generateEmbeddings(
          documentId: 'doc_textbook',
          chunks: any(named: 'chunks'),
          metadata: {'filename': 'physics_textbook.pdf'},
        ),
      ).called(3);
    });

    test('generateDocumentEmbeddings with rawText only passes rawText and null chunks', () async {
      when(
        () => mockClient.generateEmbeddings(
          documentId: 'doc_raw_only',
          rawText: 'Raw chapter text',
        ),
      ).thenAnswer((_) async => {'success': true, 'chunks_created': 1});

      final result = await dataSource.generateDocumentEmbeddings(
        documentId: 'doc_raw_only',
        rawText: 'Raw chapter text',
      );

      expect(result, equals(1));
      verify(
        () => mockClient.generateEmbeddings(
          documentId: 'doc_raw_only',
          rawText: 'Raw chapter text',
        ),
      ).called(1);
    });

    test('queryDocumentContext returns parsed DocumentChunkModel list', () async {
      when(
        () => mockClient.matchDocumentChunks(
          query: 'mitochondria',
          matchThreshold: 0.7,
          matchCount: 3,
          documentId: 'doc_bio',
        ),
      ).thenAnswer(
        (_) async => [
          {
            'id': 'chk_1',
            'content': 'Mitochondria is the powerhouse of the cell',
            'similarity': 0.92,
            'metadata': {'page': 42},
          },
        ],
      );

      final models = await dataSource.queryDocumentContext(
        query: 'mitochondria',
        matchThreshold: 0.7,
        matchCount: 3,
        documentId: 'doc_bio',
      );

      expect(models.length, equals(1));
      expect(models.first.id, equals('chk_1'));
      expect(models.first.content, contains('powerhouse'));
      expect(models.first.similarityScore, equals(0.92));
    });
  });
}
