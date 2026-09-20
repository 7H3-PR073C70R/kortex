import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/ingestion/data/services/local_image_ocr_service.dart';
import 'package:kortex/src/features/ingestion/data/services/local_ingestion_service.dart';
import 'package:kortex/src/features/ingestion/data/services/local_pdf_parser_service.dart';
import 'package:kortex/src/features/ingestion/data/services/local_pptx_parser_service.dart';
import 'package:mocktail/mocktail.dart';

class MockLocalPdfParserService extends Mock implements LocalPdfParserService {}

class MockLocalPptxParserService extends Mock
    implements LocalPptxParserService {}

class MockLocalImageOcrService extends Mock implements LocalImageOcrService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LocalIngestionService ingestionService;
  late MockLocalPdfParserService mockPdfParser;
  late MockLocalPptxParserService mockPptxParser;
  late MockLocalImageOcrService mockImageOcr;
  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    mockPdfParser = MockLocalPdfParserService();
    mockPptxParser = MockLocalPptxParserService();
    mockImageOcr = MockLocalImageOcrService();

    ingestionService = LocalIngestionService(
      pdfParser: mockPdfParser,
      pptxParser: mockPptxParser,
      imageOcr: mockImageOcr,
    );
  });

  group('LocalIngestionService Multi-Format & Sizing Test Suite', () {
    test(
      'enforces 50MB file size limit and throws FileSizeExceededException',
      () async {
        // 51MB byte array
        final oversizedBytes = Uint8List(51 * 1024 * 1024);

        expect(
          () => ingestionService.ingestBytes(
            bytes: oversizedBytes,
            extension: 'pdf',
          ),
          throwsA(isA<FileSizeExceededException>()),
        );
      },
    );

    test(
      'routes PDF documents to LocalPdfParserService and normalizes output',
      () async {
        final sampleBytes = Uint8List.fromList([1, 2, 3, 4]);
        when(() => mockPdfParser.extractText(sampleBytes)).thenAnswer(
          (_) async =>
              'Title: Machine Learning Basics\r\n\r\n\r\nSupervised learning maps inputs to outputs.\nPage 1 of 10',
        );

        final result = await ingestionService.ingestBytes(
          bytes: sampleBytes,
          extension: 'pdf',
        );

        expect(result, contains('Title: Machine Learning Basics'));
        expect(result, contains('Supervised learning maps inputs to outputs.'));
        expect(result, isNot(contains('Page 1 of 10')));
        verify(() => mockPdfParser.extractText(sampleBytes)).called(1);
      },
    );

    test(
      'routes PPTX documents to LocalPptxParserService and normalizes output',
      () async {
        final sampleBytes = Uint8List.fromList([5, 6, 7, 8]);
        when(() => mockPptxParser.extractText(sampleBytes)).thenAnswer(
          (_) async =>
              '## Slide 1: Neural Networks\n• Perceptrons form the building blocks.',
        );

        final result = await ingestionService.ingestBytes(
          bytes: sampleBytes,
          extension: 'pptx',
        );

        expect(result, contains('## Slide 1: Neural Networks'));
        expect(result, contains('• Perceptrons form the building blocks.'));
        verify(() => mockPptxParser.extractText(sampleBytes)).called(1);
      },
    );

    test(
      'routes image types to LocalImageOcrService',
      () async {
        final sampleBytes = Uint8List.fromList([9, 10, 11, 12]);
        when(
          () => mockImageOcr.extractTextFromBytes(
            any(),
            extension: any(named: 'extension'),
          ),
        ).thenAnswer((_) async => '');

        for (final ext in ['png', 'jpg', 'jpeg', 'webp']) {
          final result = await ingestionService.ingestBytes(
            bytes: sampleBytes,
            extension: ext,
          );
          expect(
            result,
            isEmpty,
          );
        }
      },
    );

    test('routes plain text and markdown bytes directly', () async {
      const textContent = '# Chapter 1\n\nDirect plain text reading.';
      final sampleBytes = Uint8List.fromList(utf8.encode(textContent));

      final result = await ingestionService.ingestBytes(
        bytes: sampleBytes,
        extension: 'md',
      );

      expect(result, contains('# Chapter 1'));
      expect(result, contains('Direct plain text reading.'));
    });

    test(
      'returns empty string for unknown/unsupported file formats',
      () async {
        final sampleBytes = Uint8List.fromList([1, 2, 3]);

        final result = await ingestionService.ingestBytes(
          bytes: sampleBytes,
          extension: 'exe',
        );

        expect(result, isEmpty);
      },
    );

    test(
      'normalizeTextBuffer removes non-printable control characters and page numbers',
      () {
        const rawWithNoise =
            'Heading \x00\x07Text\r\n\r\n\r\n\r\nParagraph 1\n------------------\nPage 4 of 12\n\n25\nEnding note.';
        final normalized = LocalIngestionService.normalizeTextBuffer(
          rawWithNoise,
        );

        expect(normalized, isNot(contains('\x00')));
        expect(normalized, isNot(contains('\x07')));
        expect(normalized, isNot(contains('Page 4 of 12')));
        expect(normalized, isNot(contains('------------------')));
        expect(normalized, contains('Heading Text'));
        expect(normalized, contains('Paragraph 1'));
        expect(normalized, contains('Ending note.'));
      },
    );
  });
}
