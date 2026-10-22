import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/networking/api/app_api_endpoint.dart';
import 'package:kortex/src/features/syllabot/data/client/vector_search_client.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

void main() {
  group('VectorSearchClient Test Suite', () {
    late MockDio mockDio;
    late VectorSearchClient client;

    setUp(() {
      mockDio = MockDio();
      client = VectorSearchClient(mockDio);
    });

    test('generateEmbeddings omits rawText when chunks is provided and non-empty', () async {
      when(
        () => mockDio.post<dynamic>(
          '${AppApiEndpoint.baseUri}${AppApiEndpoint.generateEmbeddings}',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => Response<dynamic>(
          data: {'success': true, 'chunks_created': 2},
          statusCode: 200,
          requestOptions: RequestOptions(path: AppApiEndpoint.generateEmbeddings),
        ),
      );

      final chunks = [
        {'content': 'Chunk 1', 'chunk_index': 0},
        {'content': 'Chunk 2', 'chunk_index': 1},
      ];

      final res = await client.generateEmbeddings(
        documentId: 'doc_123',
        rawText: 'This giant raw text should NOT be sent over the wire',
        chunks: chunks,
        metadata: {'courseCode': 'PHYS101'},
      );

      expect(res['chunks_created'], equals(2));

      final captured = verify(
        () => mockDio.post<dynamic>(
          '${AppApiEndpoint.baseUri}${AppApiEndpoint.generateEmbeddings}',
          data: captureAny(named: 'data'),
        ),
      ).captured;

      expect(captured.length, equals(1));
      final payload = captured.first as Map<String, dynamic>;
      expect(payload['documentId'], equals('doc_123'));
      expect(payload['chunks'], equals(chunks));
      expect(payload.containsKey('rawText'), isFalse, reason: 'rawText must be omitted when chunks are present');
      expect(payload['metadata'], equals({'courseCode': 'PHYS101'}));
    });

    test('generateEmbeddings includes rawText when chunks is null or empty', () async {
      when(
        () => mockDio.post<dynamic>(
          '${AppApiEndpoint.baseUri}${AppApiEndpoint.generateEmbeddings}',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => Response<dynamic>(
          data: {'success': true, 'chunks_created': 1},
          statusCode: 200,
          requestOptions: RequestOptions(path: AppApiEndpoint.generateEmbeddings),
        ),
      );

      final res = await client.generateEmbeddings(
        documentId: 'doc_456',
        rawText: 'Solo chapter text',
      );

      expect(res['chunks_created'], equals(1));

      final captured = verify(
        () => mockDio.post<dynamic>(
          '${AppApiEndpoint.baseUri}${AppApiEndpoint.generateEmbeddings}',
          data: captureAny(named: 'data'),
        ),
      ).captured;

      final payload = captured.first as Map<String, dynamic>;
      expect(payload['documentId'], equals('doc_456'));
      expect(payload['rawText'], equals('Solo chapter text'));
      expect(payload.containsKey('chunks'), isFalse);
    });
  });
}
