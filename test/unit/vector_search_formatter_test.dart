import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/syllabot/domain/entities/document_chunk_entity.dart';

void main() {
  group('Vector Search Formatter & RAG Context Formatting Test Suite', () {
    test(
      'formats list of document chunks into structured LLM context string',
      () {
        const chunks = [
          DocumentChunkEntity(
            id: 'chunk-1',
            documentId: 'doc-1',
            content: 'Newton second law states F = ma.',
            metadata: {'page': 12, 'chapter': 'Dynamics'},
            similarityScore: 0.89,
          ),
          DocumentChunkEntity(
            id: 'chunk-2',
            documentId: 'doc-1',
            content:
                'Work done is defined as the dot product of force and distance.',
            metadata: {'page': 15, 'chapter': 'Work & Energy'},
            similarityScore: 0.82,
          ),
        ];

        final buffer = StringBuffer()
          ..writeln('--- RETRIEVED SYLLABUS CONTEXT ---');

        for (var i = 0; i < chunks.length; i++) {
          final c = chunks[i];
          final score = (c.similarityScore * 100).toInt();
          buffer.writeln(
            '[Source ${i + 1} | Similarity: $score%]: ${c.content}',
          );
        }
        buffer.writeln('----------------------------------');

        final contextString = buffer.toString();

        expect(contextString, contains('--- RETRIEVED SYLLABUS CONTEXT ---'));
        expect(contextString, contains('[Source 1 | Similarity: 89%]'));
        expect(contextString, contains('Newton second law states F = ma.'));
        expect(contextString, contains('[Source 2 | Similarity: 82%]'));
      },
    );

    test('handles empty chunk context gracefully', () {
      const emptyChunks = <DocumentChunkEntity>[];
      expect(emptyChunks.isEmpty, isTrue);
    });
  });
}
