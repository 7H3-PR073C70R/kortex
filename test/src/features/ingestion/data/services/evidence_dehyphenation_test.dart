import 'dart:io';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/ingestion/data/services/dehyphenation_service.dart';
import 'package:kortex/src/features/ingestion/data/services/local_pdf_parser_service.dart';
import 'package:kortex/src/features/ingestion/data/services/standard_lexicon.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Task 1.3: Evidence-Driven Dehyphenation Unit Tests', () {
    group('StandardLexicon verification', () {
      test('identifies common English vocabulary and technical words', () {
        expect(StandardLexicon.contains('information'), isTrue);
        expect(StandardLexicon.contains('implementation'), isTrue);
        expect(StandardLexicon.contains('performance'), isTrue);
        expect(StandardLexicon.contains('distribution'), isTrue);
        expect(StandardLexicon.contains('algorithm'), isTrue);
        expect(StandardLexicon.contains('database'), isTrue);
        expect(StandardLexicon.contains('software'), isTrue);
        expect(StandardLexicon.contains('architecture'), isTrue);
        expect(StandardLexicon.contains('concurrency'), isTrue);
        expect(StandardLexicon.contains('synchronization'), isTrue);
      });

      test('identifies morphologically derived words with productive affixes', () {
        expect(StandardLexicon.contains('concurrently'), isTrue);
        expect(StandardLexicon.contains('optimization'), isTrue);
        expect(StandardLexicon.contains('distributed'), isTrue);
        expect(StandardLexicon.contains('optimizing'), isTrue);
        expect(StandardLexicon.contains('programming'), isTrue);
        expect(StandardLexicon.contains('photosynthesis'), isTrue);
        expect(StandardLexicon.contains('microorganism'), isTrue);
      });

      test('correctly rejects non-words and mangled compound runs', () {
        expect(StandardLexicon.contains('happensbefore'), isFalse);
        expect(StandardLexicon.contains('classbased'), isFalse);
        expect(StandardLexicon.contains('lockfree'), isFalse);
        expect(StandardLexicon.contains('waitfree'), isFalse);
        expect(StandardLexicon.contains('finegrained'), isFalse);
        expect(StandardLexicon.contains('userfriendly'), isFalse);
        expect(StandardLexicon.contains('timesensitive'), isFalse);
        expect(StandardLexicon.contains('readonly'), isFalse);
      });
    });

    group('DehyphenationService.evaluate', () {
      test('joins genuine split words without hyphen', () {
        expect(
          DehyphenationService.evaluate(
            precedingWord: 'infor',
            nextWord: 'mation',
          ),
          equals(DehyphenationAction.joinWithoutHyphen),
        );

        expect(
          DehyphenationService.evaluate(
            precedingWord: 'imple',
            nextWord: 'mentation',
          ),
          equals(DehyphenationAction.joinWithoutHyphen),
        );

        expect(
          DehyphenationService.evaluate(
            precedingWord: 'per',
            nextWord: 'formance',
          ),
          equals(DehyphenationAction.joinWithoutHyphen),
        );

        expect(
          DehyphenationService.evaluate(
            precedingWord: 'distri',
            nextWord: 'bution',
          ),
          equals(DehyphenationAction.joinWithoutHyphen),
        );

        expect(
          DehyphenationService.evaluate(
            precedingWord: 'algo',
            nextWord: 'rithm',
          ),
          equals(DehyphenationAction.joinWithoutHyphen),
        );
      });

      test('joins sentence-capitalized split words without hyphen', () {
        expect(
          DehyphenationService.evaluate(
            precedingWord: 'Infor',
            nextWord: 'mation',
          ),
          equals(DehyphenationAction.joinWithoutHyphen),
        );

        expect(
          DehyphenationService.evaluate(
            precedingWord: 'Distri',
            nextWord: 'bution',
          ),
          equals(DehyphenationAction.joinWithoutHyphen),
        );
      });

      test('preserves hyphenated compound terms (no static lists needed)', () {
        expect(
          DehyphenationService.evaluate(
            precedingWord: 'happens',
            nextWord: 'before',
          ),
          equals(DehyphenationAction.preserveHyphen),
        );

        expect(
          DehyphenationService.evaluate(
            precedingWord: 'class',
            nextWord: 'based',
          ),
          equals(DehyphenationAction.preserveHyphen),
        );

        expect(
          DehyphenationService.evaluate(
            precedingWord: 'lock',
            nextWord: 'free',
          ),
          equals(DehyphenationAction.preserveHyphen),
        );

        expect(
          DehyphenationService.evaluate(
            precedingWord: 'wait',
            nextWord: 'free',
          ),
          equals(DehyphenationAction.preserveHyphen),
        );

        expect(
          DehyphenationService.evaluate(
            precedingWord: 'fine',
            nextWord: 'grained',
          ),
          equals(DehyphenationAction.preserveHyphen),
        );

        expect(
          DehyphenationService.evaluate(
            precedingWord: 'user',
            nextWord: 'friendly',
          ),
          equals(DehyphenationAction.preserveHyphen),
        );

        expect(
          DehyphenationService.evaluate(
            precedingWord: 'thread',
            nextWord: 'safe',
          ),
          equals(DehyphenationAction.preserveHyphen),
        );

        expect(
          DehyphenationService.evaluate(
            precedingWord: 'read',
            nextWord: 'only',
          ),
          equals(DehyphenationAction.preserveHyphen),
        );
      });

      test('preserves numeric ranges', () {
        expect(
          DehyphenationService.evaluate(
            precedingWord: '20',
            nextWord: '40',
          ),
          equals(DehyphenationAction.preserveHyphen),
        );

        expect(
          DehyphenationService.evaluate(
            precedingWord: '1995',
            nextWord: '2026',
          ),
          equals(DehyphenationAction.preserveHyphen),
        );
      });

      test('preserves mixed-capitalization, acronym, and alphanumeric terms', () {
        expect(
          DehyphenationService.evaluate(
            precedingWord: 'Java',
            nextWord: 'enabled',
          ),
          equals(DehyphenationAction.preserveHyphen),
        );

        expect(
          DehyphenationService.evaluate(
            precedingWord: 'UTF',
            nextWord: '8',
          ),
          equals(DehyphenationAction.preserveHyphen),
        );

        expect(
          DehyphenationService.evaluate(
            precedingWord: 'x86',
            nextWord: '64',
          ),
          equals(DehyphenationAction.preserveHyphen),
        );

        expect(
          DehyphenationService.evaluate(
            precedingWord: 'OAuth',
            nextWord: 'based',
          ),
          equals(DehyphenationAction.preserveHyphen),
        );

        expect(
          DehyphenationService.evaluate(
            precedingWord: 'Node',
            nextWord: 'RED',
          ),
          equals(DehyphenationAction.preserveHyphen),
        );
      });

      test('leverages DocumentCorpus evidence when available', () {
        final corpus = DocumentCorpus.fromText('''
The happens-before relation is a strict partial order.
We investigate customized domain-specific microbenchmarks.
The author studied cryptography and security protocols.
''');

        // Intact compound in corpus -> preserve hyphen
        expect(
          DehyphenationService.evaluate(
            precedingWord: 'happens',
            nextWord: 'before',
            corpus: corpus,
          ),
          equals(DehyphenationAction.preserveHyphen),
        );

        expect(
          DehyphenationService.evaluate(
            precedingWord: 'domain',
            nextWord: 'specific',
            corpus: corpus,
          ),
          equals(DehyphenationAction.preserveHyphen),
        );

        // Unhyphenated word in corpus -> join without hyphen
        expect(
          DehyphenationService.evaluate(
            precedingWord: 'crypto',
            nextWord: 'graphy',
            corpus: corpus,
          ),
          equals(DehyphenationAction.joinWithoutHyphen),
        );
      });
    });

    group('LocalPdfParserService Layout Aware Lines Integration', () {
      test('correctly dehyphenates genuine word breaks while preserving compounds and ranges', () {
        final lines = [
          const PdfLineLayout(
            text: 'This system utilizes infor-',
            bounds: Rect.fromLTWH(50, 100, 200, 12),
            fontSize: 10,
          ),
          const PdfLineLayout(
            text: 'mation retrieval methods.',
            bounds: Rect.fromLTWH(50, 114, 200, 12),
            fontSize: 10,
          ),
          const PdfLineLayout(
            text: 'It operates for 20-',
            bounds: Rect.fromLTWH(50, 128, 200, 12),
            fontSize: 10,
          ),
          const PdfLineLayout(
            text: '40 hours continuously.',
            bounds: Rect.fromLTWH(50, 142, 200, 12),
            fontSize: 10,
          ),
          const PdfLineLayout(
            text: 'We apply a class-',
            bounds: Rect.fromLTWH(50, 156, 200, 12),
            fontSize: 10,
          ),
          const PdfLineLayout(
            text: 'based architectural design.',
            bounds: Rect.fromLTWH(50, 170, 200, 12),
            fontSize: 10,
          ),
          const PdfLineLayout(
            text: 'Actions adhere to the happens-',
            bounds: Rect.fromLTWH(50, 184, 200, 12),
            fontSize: 10,
          ),
          const PdfLineLayout(
            text: 'before consistency guarantee.',
            bounds: Rect.fromLTWH(50, 198, 200, 12),
            fontSize: 10,
          ),
        ];

        final output = LocalPdfParserService.layoutAwareLines(
          lines,
          pageHeight: 600,
          pageWidth: 400,
        );

        // 1. Genuine word break joined cleanly without hyphen
        expect(output, contains('information retrieval methods.'));
        expect(output, isNot(contains('infor-mation')));

        // 2. Numeric range preserved with hyphen
        expect(output, contains('20-40 hours continuously.'));

        // 3. Compounds preserved with hyphen (NEVER mangled)
        expect(output, contains('class-based architectural design.'));
        expect(output, isNot(contains('classbased')));

        expect(output, contains('happens-before consistency guarantee.'));
        expect(output, isNot(contains('happensbefore')));
      });
    });

    group('JLS8 Acceptance Gate: Compound Term Consistency', () {
      test('jls8.pdf consistently extracts happens-before and never mangles into happensbefore', () {
        final file = File('test/fixtures/ingestion/jls8.pdf');
        if (!file.existsSync()) return;

        final bytes = file.readAsBytesSync();
        const service = LocalPdfParserService();
        final text = service.extractTextFromPdfBytes(bytes, filename: 'jls8.pdf');

        // Check acceptance criteria:
        // Consistent handling of compound terms (no conflicting pairs like happens-before vs happensbefore)
        expect(text, contains('happens-before'));
        expect(
          text,
          isNot(contains('happensbefore')),
          reason: 'happens-before must never be mangled into happensbefore',
        );
      });
    });
  });
}
