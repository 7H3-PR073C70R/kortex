import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/ingestion/data/services/document_parser_service.dart';
import 'package:kortex/src/features/ingestion/data/services/local_image_ocr_service.dart';
import 'package:kortex/src/features/ingestion/data/services/local_ingestion_service.dart';
import 'package:kortex/src/features/ingestion/data/services/local_pdf_parser_service.dart';
import 'package:kortex/src/features/ingestion/data/services/local_pptx_parser_service.dart';
import 'package:mocktail/mocktail.dart';

class MockLocalPdfParserService extends Mock implements LocalPdfParserService {}
class MockLocalPptxParserService extends Mock implements LocalPptxParserService {}
class MockLocalImageOcrService extends Mock implements LocalImageOcrService {}
class MockDocumentParserService extends Mock implements DocumentParserService {}

void main() {
  late LocalIngestionService ingestionService;
  late MockLocalPdfParserService mockPdfParser;
  late MockLocalPptxParserService mockPptxParser;
  late MockLocalImageOcrService mockImageOcr;
  late MockDocumentParserService mockDocumentParser;

  setUp(() {
    mockPdfParser = MockLocalPdfParserService();
    mockPptxParser = MockLocalPptxParserService();
    mockImageOcr = MockLocalImageOcrService();
    mockDocumentParser = MockDocumentParserService();

    ingestionService = LocalIngestionService(
      pdfParser: mockPdfParser,
      pptxParser: mockPptxParser,
      imageOcr: mockImageOcr,
      documentParser: mockDocumentParser,
    );
  });

  group('LocalIngestionService Multi-Format & Sizing Test Suite', () {
    test('enforces 50MB file size limit and throws FileSizeExceededException', () async {
      // 51MB byte array
      final oversizedBytes = Uint8List(51 * 1024 * 1024);

      expect(
        () => ingestionService.ingestBytes(
          bytes: oversizedBytes,
          extension: 'pdf',
        ),
        throwsA(isA<FileSizeExceededException>()),
      );
    });

    test('routes PDF documents to LocalPdfParserService and normalizes output', () async {
      final sampleBytes = Uint8List.fromList([1, 2, 3, 4]);
      when(() => mockPdfParser.extractText(sampleBytes))
          .thenAnswer((_) async => 'Title: Machine Learning Basics\r\n\r\n\r\nSupervised learning maps inputs to outputs.\nPage 1 of 10');

      final result = await ingestionService.ingestBytes(
        bytes: sampleBytes,
        extension: 'pdf',
      );

      expect(result, contains('Title: Machine Learning Basics'));
      expect(result, contains('Supervised learning maps inputs to outputs.'));
      expect(result, isNot(contains('Page 1 of 10')));
      verify(() => mockPdfParser.extractText(sampleBytes)).called(1);
    });

    test('routes PPTX documents to LocalPptxParserService and normalizes output', () async {
      final sampleBytes = Uint8List.fromList([5, 6, 7, 8]);
      when(() => mockPptxParser.extractText(sampleBytes))
          .thenAnswer((_) async => '## Slide 1: Neural Networks\n• Perceptrons form the building blocks.');

      final result = await ingestionService.ingestBytes(
        bytes: sampleBytes,
        extension: 'pptx',
      );

      expect(result, contains('## Slide 1: Neural Networks'));
      expect(result, contains('• Perceptrons form the building blocks.'));
      verify(() => mockPptxParser.extractText(sampleBytes)).called(1);
    });

    test('routes PNG / JPG image bytes to LocalImageOcrService', () async {
      final sampleBytes = Uint8List.fromList([9, 10, 11, 12]);
      when(() => mockImageOcr.extractTextFromBytes(sampleBytes, extension: 'png'))
          .thenAnswer((_) async => 'Theorem 1: Newton Third Law of Motion\nAction equals reaction.');

      final result = await ingestionService.ingestBytes(
        bytes: sampleBytes,
        extension: 'png',
      );

      expect(result, contains('Theorem 1: Newton Third Law of Motion'));
      expect(result, contains('Action equals reaction.'));
      verify(() => mockImageOcr.extractTextFromBytes(sampleBytes, extension: 'png')).called(1);
    });

    test('routes plain text and markdown bytes directly', () async {
      final textContent = '# Chapter 1\n\nDirect plain text reading.';
      final sampleBytes = Uint8List.fromList(utf8.encode(textContent));

      final result = await ingestionService.ingestBytes(
        bytes: sampleBytes,
        extension: 'md',
      );

      expect(result, contains('# Chapter 1'));
      expect(result, contains('Direct plain text reading.'));
    });

    test('throws UnsupportedFileTypeException on unknown file format', () async {
      final sampleBytes = Uint8List.fromList([1, 2, 3]);

      expect(
        () => ingestionService.ingestBytes(
          bytes: sampleBytes,
          extension: 'exe',
        ),
        throwsA(isA<UnsupportedFileTypeException>()),
      );
    });

    test('normalizeTextBuffer removes non-printable control characters and page numbers', () {
      final rawWithNoise = 'Heading \x00\x07Text\r\n\r\n\r\n\r\nParagraph 1\n------------------\nPage 4 of 12\n\n25\nEnding note.';
      final normalized = LocalIngestionService.normalizeTextBuffer(rawWithNoise);

      expect(normalized, isNot(contains('\x00')));
      expect(normalized, isNot(contains('\x07')));
      expect(normalized, isNot(contains('Page 4 of 12')));
      expect(normalized, isNot(contains('------------------')));
      expect(normalized, contains('Heading Text'));
      expect(normalized, contains('Paragraph 1'));
      expect(normalized, contains('Ending note.'));
    });
  });
}
