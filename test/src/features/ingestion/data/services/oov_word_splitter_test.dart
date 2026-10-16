import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/ingestion/data/services/local_pdf_parser_service.dart';
import 'package:kortex/src/features/ingestion/data/services/oov_word_splitter.dart';
import 'package:kortex/src/features/ingestion/domain/entities/extraction_report.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Task 1.4: Out-Of-Vocabulary (OOV) Glued Run Safety Net Tests', () {
    group('Programming Identifier & Safeguard Detection', () {
      test('correctly identifies camelCase and PascalCase identifiers', () {
        expect(OovWordSplitter.isProgrammingIdentifier('computeModeFontSize'), isTrue);
        expect(OovWordSplitter.isProgrammingIdentifier('textEditingController'), isTrue);
        expect(OovWordSplitter.isProgrammingIdentifier('StatefulWidget'), isTrue);
        expect(OovWordSplitter.isProgrammingIdentifier('PdfLineLayout'), isTrue);
        expect(OovWordSplitter.isProgrammingIdentifier('ExtractionReport'), isTrue);
      });

      test('correctly identifies snake_case and SCREAMING_SNAKE identifiers', () {
        expect(OovWordSplitter.isProgrammingIdentifier('local_pdf_parser_service'), isTrue);
        expect(OovWordSplitter.isProgrammingIdentifier('dynamic_fragment_merging'), isTrue);
        expect(OovWordSplitter.isProgrammingIdentifier('MAX_BUFFER_SIZE'), isTrue);
        expect(OovWordSplitter.isProgrammingIdentifier('kortex_flashcard_deck'), isTrue);
      });

      test('correctly identifies alphanumeric tokens, URLs, and paths', () {
        expect(OovWordSplitter.isProgrammingIdentifier('SHA256HashAlgorithm'), isTrue);
        expect(OovWordSplitter.isProgrammingIdentifier('0x7FFFFFFF'), isTrue);
        expect(OovWordSplitter.isProgrammingIdentifier('https://flutter.dev/docs'), isTrue);
        expect(OovWordSplitter.isProgrammingIdentifier('/usr/local/bin/dart'), isTrue);
        expect(OovWordSplitter.isProgrammingIdentifier('support@kortex.app'), isTrue);
        expect(OovWordSplitter.isProgrammingIdentifier('JSON'), isTrue);
        expect(OovWordSplitter.isProgrammingIdentifier('HTTP'), isTrue);
      });

      test('does not classify plain lower or single-capital prose as identifiers', () {
        expect(OovWordSplitter.isProgrammingIdentifier('distinctsections'), isFalse);
        expect(OovWordSplitter.isProgrammingIdentifier('Distinctsections'), isFalse);
        expect(OovWordSplitter.isProgrammingIdentifier('softwareapplication'), isFalse);
        expect(OovWordSplitter.isProgrammingIdentifier('Softwareapplication'), isFalse);
        expect(OovWordSplitter.isProgrammingIdentifier('flutterengineering'), isFalse);
      });
    });

    group('OOV Candidate Validation', () {
      test('identifies true OOV candidate tokens >= 14 chars', () {
        expect(OovWordSplitter.isCandidateForOovSplitting('distinctsections'), isTrue);
        expect(OovWordSplitter.isCandidateForOovSplitting('Distinctsections'), isTrue);
        expect(OovWordSplitter.isCandidateForOovSplitting('softwareapplication'), isTrue);
        expect(OovWordSplitter.isCandidateForOovSplitting('flutterengineering'), isTrue);
      });

      test('safeguards legitimate long words present in StandardLexicon', () {
        expect(OovWordSplitter.isCandidateForOovSplitting('internationalization'), isFalse);
        expect(OovWordSplitter.isCandidateForOovSplitting('synchronization'), isFalse);
        expect(OovWordSplitter.isCandidateForOovSplitting('implementation'), isFalse);
        expect(OovWordSplitter.isCandidateForOovSplitting('infrastructure'), isFalse);
        expect(OovWordSplitter.isCandidateForOovSplitting('differentiation'), isFalse);
        expect(OovWordSplitter.isCandidateForOovSplitting('characterization'), isFalse);
        expect(OovWordSplitter.isCandidateForOovSplitting('telecommunication'), isFalse);
        expect(OovWordSplitter.isCandidateForOovSplitting('electromagnetism'), isFalse);
      });
    });

    group('DP Viterbi Word Segmentation (splitGluedWord)', () {
      test('splits glued two-word runs into distinct words', () {
        expect(
          OovWordSplitter.splitGluedWord('distinctsections'),
          equals('distinct sections'),
        );

        expect(
          OovWordSplitter.splitGluedWord('softwareapplication'),
          equals('software application'),
        );

        expect(
          OovWordSplitter.splitGluedWord('flutterengineering'),
          equals('flutter engineering'),
        );
      });

      test('preserves initial sentence capitalization', () {
        expect(
          OovWordSplitter.splitGluedWord('Distinctsections'),
          equals('Distinct sections'),
        );

        expect(
          OovWordSplitter.splitGluedWord('Softwareapplication'),
          equals('Software application'),
        );
      });

      test('splits multi-word glued runs with short functional words', () {
        expect(
          OovWordSplitter.splitGluedWord('softwareapplicationintodistinctsections'),
          equals('software application into distinct sections'),
        );
      });

      test('leaves unsplittable scientific/domain terms untouched', () {
        expect(
          OovWordSplitter.splitGluedWord('deoxyribonucleic'),
          equals('deoxyribonucleic'),
        );

        expect(
          OovWordSplitter.splitGluedWord('phosphatidylcholine'),
          equals('phosphatidylcholine'),
        );
      });
    });

    group('repairGluedRunsInText & ExtractionReport Auditing', () {
      test('repairs glued runs in prose and records splits in ExtractionReport', () {
        final report = ExtractionReport(filename: 'test.pdf');
        const input = 'We divide the softwareapplication into distinctsections.';

        final output = OovWordSplitter.repairGluedRunsInText(
          input,
          report: report,
          page: 3,
        );

        expect(output, equals('We divide the software application into distinct sections.'));
        expect(report.totalGluedWordSplits, equals(2));

        final split1 = report.gluedWordSplits[0];
        expect(split1.fusedToken, equals('softwareapplication'));
        expect(split1.splitResult, equals('software application'));
        expect(split1.page, equals(3));

        final split2 = report.gluedWordSplits[1];
        expect(split2.fusedToken, equals('distinctsections'));
        expect(split2.splitResult, equals('distinct sections'));
        expect(split2.page, equals(3));
      });

      test('preserves code blocks and math blocks byte-for-byte without splitting', () {
        const input = r'''
The architecture creates distinctsections in the code.

```dart
final softwareapplication = 42;
```

Here is a math formula:
$$
\text{distinctsections} = \sum_{i=1}^n x_i
$$
''';

        final output = OovWordSplitter.repairGluedRunsInText(input);

        // Prose line is repaired
        expect(output, contains('The architecture creates distinct sections in the code.'));

        // Code block is untouched
        expect(output, contains('final softwareapplication = 42;'));

        // Math block is untouched
        expect(output, contains(r'\text{distinctsections}'));
      });
    });

    group('LocalPdfParserService Integration Gate', () {
      test('LocalPdfParserService.repairGluedWordRuns repairs runs and reports audit logs', () {
        final report = ExtractionReport(filename: 'flutterengineering-book.pdf');
        const text = 'Modular flutterengineering yields distinctsections of logic.';

        final repaired = LocalPdfParserService.repairGluedWordRuns(
          text,
          report: report,
          page: 1,
        );

        expect(repaired, equals('Modular flutter engineering yields distinct sections of logic.'));
        expect(report.totalGluedWordSplits, equals(2));
      });

      test('acceptance gate: flutterengineering-book.pdf extracts clean separated words', () {
        final file = File('test/fixtures/ingestion/flutterengineering-book.pdf');
        if (!file.existsSync()) return;

        final bytes = file.readAsBytesSync();
        final report = ExtractionReport(filename: 'flutterengineering-book.pdf');
        const service = LocalPdfParserService();
        final text = service.extractTextFromPdfBytes(
          bytes,
          filename: 'flutterengineering-book.pdf',
          report: report,
        );

        expect(text, isNotEmpty);
        expect(text, isNot(contains('distinctsections')));
        expect(text, isNot(contains('softwareapplicationintodistinctsections')));
      });
    });
  });
}
