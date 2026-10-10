import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/ingestion/data/services/document_parser_service.dart';
import 'package:kortex/src/features/ingestion/data/services/local_pdf_parser_service.dart';
import 'package:kortex/src/features/ingestion/domain/entities/ingestion_cancellation_token.dart';
import 'package:kortex/src/features/ingestion/domain/exceptions/ingestion_exceptions.dart';

void main() {
  group('Step 15: Ingestion Execution Budget & Cancellation Tests', () {
    const parser = DocumentParserService();

    test('enforces 50 MB execution budget constant', () {
      expect(DocumentParserService.maxFileSizeBytes, 50 * 1024 * 1024);
    });

    test('throws FileSizeExceededException when input exceeds 50 MB in extractTextFromBytes', () {
      final oversizedBytes = Uint8List(50 * 1024 * 1024 + 1);

      expect(
        () => parser.extractTextFromBytes(
          oversizedBytes,
          fileType: 'txt',
          filename: 'oversized.txt',
        ),
        throwsA(isA<FileSizeExceededException>()),
      );
    });

    test('throws FileSizeExceededException in LocalPdfParserService when PDF exceeds 50 MB', () {
      final oversizedBytes = Uint8List(50 * 1024 * 1024 + 1024);

      expect(
        () => const LocalPdfParserService().extractTextFromPdfBytes(
          oversizedBytes,
          filename: 'huge.pdf',
        ),
        throwsA(isA<FileSizeExceededException>()),
      );
    });

    test('IngestionCancellationToken tracks cancellation and notifies listeners', () {
      var notified = false;
      final token = IngestionCancellationToken()
        ..addListener(() {
          notified = true;
        });

      expect(token.isCancelled, isFalse);

      token.cancel();
      expect(token.isCancelled, isTrue);
      expect(notified, isTrue);

      expect(
        token.throwIfCancelled,
        throwsA(isA<IngestionCancelledException>()),
      );
    });

    test('extractTextFromBytes aborts immediately when cancellation token is cancelled', () {
      final token = IngestionCancellationToken()..cancel();

      expect(
        () => parser.extractTextFromBytes(
          Uint8List.fromList([1, 2, 3]),
          fileType: 'txt',
          filename: 'test.txt',
          cancellationToken: token,
        ),
        throwsA(isA<IngestionCancelledException>()),
      );
    });

    test('synthesizeDeckFromDocument aborts when cancellation token is cancelled', () {
      final token = IngestionCancellationToken()..cancel();

      expect(
        () => parser.synthesizeDeckFromDocument(
          documentId: 'doc_cancelled',
          fullText: 'Section 1: Test content that should be cancelled.',
          filename: 'test.txt',
          cancellationToken: token,
        ),
        throwsA(isA<IngestionCancelledException>()),
      );
    });

    test('LocalPdfParserService aborts when cancellation token is cancelled', () {
      final token = IngestionCancellationToken()..cancel();

      expect(
        () => const LocalPdfParserService().extractTextFromPdfBytes(
          Uint8List.fromList([37, 80, 68, 70]), // %PDF
          filename: 'sample.pdf',
          cancellationToken: token,
        ),
        throwsA(isA<IngestionCancelledException>()),
      );
    });
  });
}
