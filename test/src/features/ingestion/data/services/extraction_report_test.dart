import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/ingestion/data/services/document_parser_service.dart';
import 'package:kortex/src/features/ingestion/data/services/local_ingestion_service.dart';
import 'package:kortex/src/features/ingestion/data/services/local_pdf_parser_service.dart';
import 'package:kortex/src/features/ingestion/data/services/offline_card_builder.dart';
import 'package:kortex/src/features/ingestion/domain/entities/extraction_report.dart';

void main() {
  const fixturesDir = 'test/fixtures/ingestion';

  group('Step 3: ExtractionReport and typed exceptions', () {
    test('Unsupported file extension throws UnsupportedFileTypeException', () {
      const parser = DocumentParserService();
      final report = ExtractionReport(filename: 'test.xyz', fileType: 'xyz');

      expect(
        () => parser.extractTextFromBytes(
          Uint8List.fromList([1, 2, 3]),
          fileType: 'xyz',
          filename: 'test.xyz',
          report: report,
        ),
        throwsA(isA<UnsupportedFileTypeException>()),
      );

      final ingestionService = LocalIngestionService();
      expect(
        () => ingestionService.ingestBytes(
          bytes: Uint8List.fromList([1, 2, 3]),
          extension: 'exe',
        ),
        throwsA(isA<UnsupportedFileTypeException>()),
      );
    });

    test('Encrypted PDF fixture throws EncryptedPdfException', () async {
      const encryptedPdfPath = '$fixturesDir/encrypted_security_policy.pdf';
      final file = File(encryptedPdfPath);
      expect(file.existsSync(), isTrue, reason: 'Fixture must exist');

      final bytes = await file.readAsBytes();
      const pdfParser = LocalPdfParserService();
      final report = ExtractionReport(
        filename: 'encrypted_security_policy.pdf',
        fileType: 'pdf',
      );

      expect(
        () => pdfParser.extractTextFromPdfBytes(
          bytes,
          filename: 'encrypted_security_policy.pdf',
          report: report,
        ),
        throwsA(isA<EncryptedPdfException>()),
      );

      expect(report.isEncrypted, isTrue);

      // Verify through LocalIngestionService
      final ingestionService = LocalIngestionService();
      expect(
        () => ingestionService.ingestFile(file),
        throwsA(isA<EncryptedPdfException>()),
      );
    });

    test('Corrupt PDF fixture throws CorruptDocumentException', () async {
      const corruptPdfPath = '$fixturesDir/corrupt_malformed_syntax.pdf';
      final file = File(corruptPdfPath);
      expect(file.existsSync(), isTrue, reason: 'Fixture must exist');

      final bytes = await file.readAsBytes();
      const pdfParser = LocalPdfParserService();
      final report = ExtractionReport(
        filename: 'corrupt_malformed_syntax.pdf',
        fileType: 'pdf',
      );

      expect(
        () => pdfParser.extractTextFromPdfBytes(
          bytes,
          filename: 'corrupt_malformed_syntax.pdf',
          report: report,
        ),
        throwsA(isA<CorruptDocumentException>()),
      );

      expect(report.isCorrupt, isTrue);

      // Verify through LocalIngestionService
      final ingestionService = LocalIngestionService();
      expect(
        () => ingestionService.ingestFile(file),
        throwsA(isA<CorruptDocumentException>()),
      );
    });

    test('Zero text stream scanned PDF throws ScannedDocumentException', () {
      // Minimal valid single-page PDF with empty contents (no BT...ET or text)
      const emptyPdfString = '''

%PDF-1.4
1 0 obj
<< /Type /Catalog /Pages 2 0 R >>
endobj
2 0 obj
<< /Type /Pages /Kids [3 0 R] /Count 1 >>
endobj
3 0 obj
<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] >>
endobj
xref
0 4
0000000000 65535 f 
0000000009 00000 n 
0000000058 00000 n 
0000000115 00000 n 
trailer
<< /Size 4 /Root 1 0 R >>
startxref
195
%%EOF
''';

      final bytes = Uint8List.fromList(emptyPdfString.codeUnits);
      const pdfParser = LocalPdfParserService();
      final report = ExtractionReport(filename: 'scanned_empty.pdf', fileType: 'pdf');

      expect(
        () => pdfParser.extractTextFromPdfBytes(
          bytes,
          filename: 'scanned_empty.pdf',
          report: report,
        ),
        throwsA(isA<ScannedDocumentException>()),
      );

      expect(report.isScanned, isTrue);
    });

    test('ExtractionReport audits dropped marginalia, noise lines, and front matter', () {
      final report = ExtractionReport(
        filename: 'sample_audit_document.txt',
        fileType: 'txt',
      );

      const sampleDocWithNoise = '''

Table of Contents
1. Introduction to Quantum States . . . . . . 1
2. Superposition Principle . . . . . . . . . 5
3. Entanglement and Bell States . . . . . . 12

Page 1 of 42
Chapter 1: Quantum States
A quantum bit or qubit is the basic unit of quantum information in quantum computing.
Unlike classical bits which are strictly 0 or 1, a qubit can exist in a superposition of both states simultaneously.

Page 2 of 42
The state space of a single qubit is mathematically represented as a two-dimensional complex Hilbert space.
''';

      const cardBuilder = OfflineCardBuilder();
      final cards = cardBuilder.buildCards(sampleDocWithNoise, report: report);

      expect(cards, isNotEmpty);
      expect(report.totalDroppedElements, greaterThan(0));

      final droppedRules = report.droppedElements.map((e) => e.rule).toSet();
      expect(
        droppedRules.contains('table_of_contents_run') ||
            droppedRules.contains('page_noise'),
        isTrue,
        reason: 'Report should record dropped TOC or page number noise',
      );

      // Verify report serialization
      final json = report.toJson();
      expect(json['filename'], equals('sample_audit_document.txt'));
      expect(json['dropped_elements'], isA<List<dynamic>>());
      expect((json['dropped_elements'] as List<dynamic>).isNotEmpty, isTrue);
    });
  });
}
