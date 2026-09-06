import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/ingestion/domain/entities/ocr_extraction_entity.dart';
import 'package:kortex/src/features/ingestion/domain/services/recursive_text_splitter.dart';

void main() {
  group('RecursiveTextSplitter Test Suite', () {
    const splitter = RecursiveTextSplitter(
      chunkSize: 50,
      chunkOverlap: 10,
    );

    test('returns empty list when input text is empty or blank', () {
      expect(splitter.splitText(text: ''), isEmpty);
      expect(splitter.splitText(text: '   \n\n  '), isEmpty);
    });

    test('short text under chunk limit produces single chunk', () {
      const text = 'Thermodynamics is the branch of physics that deals with heat and work.';
      final chunks = splitter.splitText(text: text, pageNumber: 1);

      expect(chunks.length, equals(1));
      expect(chunks.first.content, equals(text));
      expect(chunks.first.pageNumber, equals(1));
      expect(chunks.first.paragraphNumber, equals(1));
      expect(chunks.first.chunkIndex, equals(0));
    });

    test('long multi-paragraph text is recursively split with overlap', () {
      final paragraphs = List.generate(
        15,
        (i) => 'Paragraph ${i + 1}: Kortexify combines offline local storage, zero latency FSRS memory algorithms, and multimodal STEM OCR to provide students with an integrated active-recall study experience.',
      );
      final fullText = paragraphs.join('\n\n');

      final chunks = splitter.splitText(text: fullText, pageNumber: 2);

      expect(chunks.length, greaterThan(1));
      for (final chunk in chunks) {
        expect(chunk.pageNumber, equals(2));
        expect(chunk.content.isNotEmpty, isTrue);
      }

      // Check chunk sequencing
      for (var i = 0; i < chunks.length; i++) {
        expect(chunks[i].chunkIndex, equals(i));
      }
    });

    test('splitSnippets extracts page numbers and assigns paragraph numbers', () {
      const snippets = [
        OcrExtractionEntity(
          id: 'snip_1',
          documentId: 'doc_1',
          rawText: 'Section 1 on Page 1: Introduction to Linear Algebra and Vector Spaces.\n\nMatrices are rectangular arrays of numbers.',
          topic: 'Page 1: Matrices',
        ),
        OcrExtractionEntity(
          id: 'snip_2',
          documentId: 'doc_1',
          rawText: 'Section 2 on Page 2: Eigenvalues and Eigenvectors in quantum mechanics and differential systems.',
          topic: 'Page 2: Eigenvalues',
        ),
      ];

      final chunks = splitter.splitSnippets(snippets);

      expect(chunks.isNotEmpty, isTrue);
      expect(chunks.first.pageNumber, equals(1));
      expect(chunks.last.pageNumber, equals(2));
      expect(chunks.first.metadata['topic'], contains('Matrices'));
    });

    test('chunk serialization includes chunk_index, page_number, and paragraph_number', () {
      const chunk = TextChunk(
        content: 'Newton second law: F = ma.',
        chunkIndex: 3,
        pageNumber: 42,
        paragraphNumber: 2,
        metadata: {'courseCode': 'PHY101'},
      );

      final json = chunk.toJson();
      expect(json['content'], equals('Newton second law: F = ma.'));
      expect(json['chunk_index'], equals(3));
      expect(json['page_number'], equals(42));
      expect(json['paragraph_number'], equals(2));
      expect((json['metadata'] as Map)['courseCode'], equals('PHY101'));
    });
  });
}
