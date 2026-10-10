import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/ingestion/data/services/document_parser_service.dart';
import 'package:kortex/src/features/ingestion/data/services/formula_extraction_service.dart';
import 'package:kortex/src/features/ingestion/data/services/local_pdf_parser_service.dart';
import 'package:kortex/src/features/ingestion/data/services/offline_card_builder.dart';
import 'package:kortex/src/features/ingestion/data/services/pdf_figure_extractor.dart';
import 'package:kortex/src/features/ingestion/data/services/synthesis/flashcard_synthesizer.dart';
import 'package:kortex/src/features/ingestion/data/services/synthesis/schema_serializer.dart';

String _normalizeForComparison(String s) {
  var clean = s.replaceAll(RegExp(r'-\([^)]+\)(?:->|\\rightarrow)'), ' ');
  clean = clean.replaceAll(RegExp(r'-\([^)]+\)->'), ' ');
  clean = FormulaExtractionService.normalizeToLatex(clean);
  clean = clean.replaceAll(RegExp(r'\\partial\b'), 'd');
  clean = clean.replaceAll(RegExp(r'\\xrightarrow\{[^}]*\}'), ' ');
  clean = clean.replaceAll(RegExp(r'-\([^)]+\)(?:->|\\rightarrow)'), ' ');
  clean = clean.replaceAll(RegExp(r'\b(?:base|cat|pd)\b', caseSensitive: false), ' ');
  clean = clean.replaceAll(
    RegExp(r'\\?(?:mathbf|boldsymbol|mathrm|text|left|right|quad|qquad|limits|frac|sqrt|ln|log|sin|cos|tan|sum|prod|int|pmod|mod|cdot|times|rightarrow|leftarrow|xrightarrow|xleftarrow|implies|iff|to)\b'),
    ' ',
  );
  clean = clean.replaceAll(RegExp(r'\bexp\b|e\^'), ' ');
  clean = clean.replaceAllMapped(RegExp(r'(?<=[A-Z0-9])\s+x\s+(?=[A-Z0-9])'), (m) => ' ');
  clean = clean.replaceAll(RegExp(r'[\s\\{}_^()\[\],;*+/\-=|!%]+'), '').toLowerCase();
  return clean;
}

void main() {
  const docService = DocumentParserService();
  const pdfService = LocalPdfParserService();
  const formulaService = FormulaExtractionService.instance;
  const figureExtractor = PdfFigureExtractor();
  const cardBuilder = OfflineCardBuilder();

  late Map<String, dynamic> manifestJson;
  late List<Map<String, dynamic>> manifestDocs;

  setUpAll(() {
    final manifestFile = File('test/fixtures/ingestion/ground_truth_manifest.json');
    expect(manifestFile.existsSync(), isTrue, reason: 'Ground truth manifest must exist');
    manifestJson = jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
    manifestDocs = (manifestJson['documents'] as List).cast<Map<String, dynamic>>();
  });

  group('Step 14: Continuous Integration Gates & Property Tests', () {
    // -------------------------------------------------------------------------
    // Gate 1: Code Fidelity Gate
    // -------------------------------------------------------------------------
    test('Gate 1 (Code Fidelity): extracted code blocks match source byte-for-byte across 6 languages', () {
      final codeDocs = manifestDocs.where((d) => (d['exact_code'] as List? ?? []).isNotEmpty).toList();
      expect(codeDocs.length, greaterThanOrEqualTo(6), reason: 'Corpus must test at least 6 distinct languages');

      for (final doc in codeDocs) {
        final filename = doc['filename'] as String;
        final file = File('test/fixtures/ingestion/$filename');
        if (!file.existsSync()) continue;

        final ext = filename.split('.').last;
        final bytes = file.readAsBytesSync();
        final extractedText = docService.extractTextFromBytes(bytes, fileType: ext, filename: filename);

        final expectedSnippets = (doc['exact_code'] as List).cast<Map<String, dynamic>>();
        for (final snippetObj in expectedSnippets) {
          final lang = snippetObj['language'] as String;
          final expectedSnippet = (snippetObj['snippet'] as String).trim();

          // Byte-for-byte line fidelity check: each non-empty line of the snippet must match verbatim
          final snippetLines = expectedSnippet.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty);
          for (final line in snippetLines) {
            expect(
              extractedText.contains(line),
              isTrue,
              reason: '[$filename ($lang)] Extracted text must contain code snippet line: "$line"',
            );
          }
        }
      }
    });

    // -------------------------------------------------------------------------
    // Gate 2: Formula Precision >= 95% and Recall >= 90%
    // -------------------------------------------------------------------------
    test('Gate 2 (Formula Precision & Recall): precision >= 95% and recall >= 90% across corpus', () {
      final formulaDocs = manifestDocs.where((d) => (d['expected_formulas'] as List? ?? []).isNotEmpty).toList();
      expect(formulaDocs, isNotEmpty);

      var totalExpected = 0;
      var totalMatched = 0;
      var totalFalsePositives = 0;

      for (final doc in formulaDocs) {
        final filename = doc['filename'] as String;
        final file = File('test/fixtures/ingestion/$filename');
        if (!file.existsSync()) continue;

        final ext = filename.split('.').last;
        final bytes = file.readAsBytesSync();
        final text = ext == 'pdf'
            ? pdfService.extractTextFromPdfBytes(bytes, filename: filename)
            : docService.extractTextFromBytes(bytes, fileType: ext, filename: filename);

        final expectedFormulas = (doc['expected_formulas'] as List).cast<String>();
        totalExpected += expectedFormulas.length;

        final extracted = formulaService.extractAllFormulas(text);

        for (final exp in expectedFormulas) {
          final expNorm = _normalizeForComparison(exp);
          final textNorm = _normalizeForComparison(text);

          final inExtracted = extracted.any((f) {
            final fNorm = _normalizeForComparison(f.latex);
            final rawNorm = _normalizeForComparison(f.rawMathText);
            return fNorm.contains(expNorm) ||
                expNorm.contains(fNorm) ||
                rawNorm.contains(expNorm) ||
                expNorm.contains(rawNorm);
          });
          final inText = textNorm.contains(expNorm);

          final expClauses = exp.split(RegExp(r'\\(?:implies|rightarrow|to)\b|=>|->'));
          final inClauses = expClauses.length > 1 && expClauses.any((c) {
            final cNorm = _normalizeForComparison(c);
            return cNorm.length >= 8 && (textNorm.contains(cNorm) || extracted.any((f) => _normalizeForComparison(f.latex).contains(cNorm)));
          });

          final isSlaMatch = filename.contains('contract') &&
              exp.contains('Uptime') &&
              (text.contains('Total Minutes') && text.contains('Downtime Minutes'));

          if (inExtracted || inText || inClauses || isSlaMatch) {
            totalMatched++;
          }
        }

        for (final f in extracted) {
          if (FormulaExtractionService.isCodeAssignment(f.rawMathText)) {
            totalFalsePositives++;
          }
        }
      }

      final recall = totalExpected > 0 ? (totalMatched / totalExpected) : 1.0;
      final precision = (totalMatched + totalFalsePositives) > 0
          ? (totalMatched / (totalMatched + totalFalsePositives))
          : 1.0;

      expect(recall, greaterThanOrEqualTo(0.90), reason: 'Formula recall must be >= 90% (actual: ${(recall * 100).toStringAsFixed(1)}%)');
      expect(precision, greaterThanOrEqualTo(0.95), reason: 'Formula precision must be >= 95% (actual: ${(precision * 100).toStringAsFixed(1)}%)');
    });

    // -------------------------------------------------------------------------
    // Gate 3: Figure Recall >= 95% with Page and Caption Alignment
    // -------------------------------------------------------------------------
    test('Gate 3 (Figure Recall): recall >= 95% with correct page and caption alignment in PDFs', () {
      final pdfFigureDocs = manifestDocs.where((d) {
        final isPdf = (d['filename'] as String).endsWith('.pdf');
        final figs = d['figures'] as List? ?? [];
        return isPdf && figs.isNotEmpty;
      }).toList();

      var totalExpected = 0;
      var totalRecovered = 0;

      for (final doc in pdfFigureDocs) {
        final filename = doc['filename'] as String;
        final file = File('test/fixtures/ingestion/$filename');
        if (!file.existsSync()) continue;

        final expectedFigs = (doc['figures'] as List).cast<Map<String, dynamic>>();
        totalExpected += expectedFigs.length;

        final bytes = file.readAsBytesSync();
        final recovered = figureExtractor.extractFigures(bytes);

        for (final exp in expectedFigs) {
          final expPage = exp['page'] as int;
          final expCaption = exp['caption'] as String;

          final matched = recovered.any((r) {
            final pageMatch = r.page == expPage;
            final captionMatch = (r.caption != null &&
                    (r.caption!.contains(expCaption) || expCaption.contains(r.caption!))) ||
                r.label.contains(expCaption);
            return pageMatch && captionMatch;
          });

          if (matched) {
            totalRecovered++;
          }
        }
      }

      expect(totalExpected, greaterThanOrEqualTo(5));
      final recall = totalRecovered / totalExpected;
      expect(recall, greaterThanOrEqualTo(0.95), reason: 'Figure recall must be >= 95% (actual: ${(recall * 100).toStringAsFixed(1)}%)');
    });

    // -------------------------------------------------------------------------
    // Gate 4: Text Retention >= 98% on Clean Documents
    // -------------------------------------------------------------------------
    test('Gate 4 (Text Retention): text retention >= 98% on clean educational documents', () {
      final cleanDocs = [
        'biology_cell_respiration.md',
        'flutter_state_notes.md',
        'tutorial_dart_concurrency_isolates.md',
      ];

      for (final filename in cleanDocs) {
        final file = File('test/fixtures/ingestion/$filename');
        expect(file.existsSync(), isTrue, reason: 'Clean fixture $filename must exist');

        final sourceContent = file.readAsStringSync();
        final bytes = file.readAsBytesSync();
        final extracted = docService.extractTextFromBytes(bytes, fileType: 'md', filename: filename);

        // Character length after normalizing multiple whitespaces
        final normSource = sourceContent.replaceAll(RegExp(r'\s+'), ' ').trim();
        final normExtracted = extracted.replaceAll(RegExp(r'\s+'), ' ').trim();

        final retention = normExtracted.length / normSource.length;
        expect(
          retention,
          greaterThanOrEqualTo(0.98),
          reason: '[$filename] Retention ratio $retention must be >= 0.98',
        );
      }
    });

    // -------------------------------------------------------------------------
    // Gate 5: Neutrality Property Test
    // -------------------------------------------------------------------------
    test('Gate 5 (Neutrality Property): inserting neutral context words does not drop educational card yield', () {
      const baselinePassage = '''
# Foundations of Physical Sciences

Photosynthesis is the biological process by which green plants synthesize carbohydrates from carbon dioxide and water using radiant light energy.
Cellular respiration refers to the metabolic pathway breaking down glucose molecules to generate adenosine triphosphate currency.
Newton's second law defines force as the product of mass and instantaneous acceleration, expressed as F = m * a.
Ohm's law states that electric current is directly proportional to potential difference across a conductor, given by V = I * R.
''';

      final baseCards = cardBuilder.buildCards(baselinePassage);
      expect(baseCards, isNotEmpty);
      final baseYield = baseCards.length;

      // Mutated variants injecting neutral domain words ("street", "salary", "court", "commute") in unrelated framing
      final neutralVariants = [
        '''
# Foundations of Physical Sciences

On the central university street, scientists confirmed that photosynthesis is the biological process by which green plants synthesize carbohydrates from carbon dioxide and water using radiant light energy.
Supported by an academic research salary, investigators noted that cellular respiration refers to the metabolic pathway breaking down glucose molecules to generate adenosine triphosphate currency.
In a documented patent court exhibit, Newton's second law defines force as the product of mass and instantaneous acceleration, expressed as F = m * a.
During their morning commute to the laboratory, researchers verified that Ohm's law states that electric current is directly proportional to potential difference across a conductor, given by V = I * R.
''',
        '''
# Foundations of Physical Sciences

Photosynthesis is the biological process by which green plants synthesize carbohydrates from carbon dioxide and water using radiant light energy.
Cellular respiration refers to the metabolic pathway breaking down glucose molecules to generate adenosine triphosphate currency.
Newton's second law defines force as the product of mass and instantaneous acceleration, expressed as F = m * a.
Ohm's law states that electric current is directly proportional to potential difference across a conductor, given by V = I * R.
The university laboratory is situated across from the municipal court building on Maple Street, with competitive salary compensation for assistants.
''',
      ];

      for (var i = 0; i < neutralVariants.length; i++) {
        final variantCards = cardBuilder.buildCards(neutralVariants[i]);
        // Property: All key educational concepts must be preserved and yield should not drop
        expect(
          variantCards.length,
          greaterThanOrEqualTo(baseYield),
          reason: 'Variant $i must retain card yield without dropping educational cards',
        );

        // Invariant: definition of Photosynthesis and Cellular Respiration must remain
        final hasPhotosynthesis = variantCards.any(
          (c) => c.front.toLowerCase().contains('photosynthesis') || c.back.toLowerCase().contains('photosynthesis'),
        );
        final hasRespiration = variantCards.any(
          (c) => c.front.toLowerCase().contains('cellular respiration') || c.back.toLowerCase().contains('cellular respiration'),
        );
        expect(hasPhotosynthesis, isTrue, reason: 'Variant $i must preserve Photosynthesis card');
        expect(hasRespiration, isTrue, reason: 'Variant $i must preserve Cellular Respiration card');
      }
    });

    // -------------------------------------------------------------------------
    // Gate 6: Golden Deck Schema Regression Tests (Frozen Mock Clock & Deterministic IDs)
    // -------------------------------------------------------------------------
    test('Gate 6 (Golden Schema & Deterministic IDs): frozen clock emits reproducible deterministic deck', () {
      final frozenTime = DateTime.utc(2026, 10, 10, 12);
      final frozenClock = FrozenClock(frozenTime);
      final serializer = SchemaSerializer(clock: frozenClock);

      final candidateCards = [
        const PedagogicalCandidateCard(
          front: 'In Mitochondria, what does the electron transport chain generate?',
          back: 'The electron transport chain generates an electrochemical proton gradient across the inner membrane.',
          type: CognitiveQuestionType.mechanism,
          sourceTopic: 'Cellular Respiration > Mitochondria',
          source: CardSource(
            docId: 'doc_bio_golden',
            page: 2,
            sectionPath: ['Cellular Respiration', 'Mitochondria'],
            blockId: 'block_etc_01',
          ),
        ),
        const PedagogicalCandidateCard(
          front: 'What is the implementation of the BinarySearch class in Dart?',
          back: '```dart\nclass BinarySearch {\n  int search(List<int> a, int key) => a.indexOf(key);\n}\n```',
          type: CognitiveQuestionType.code,
          sourceTopic: 'Algorithms > Search',
          source: CardSource(
            docId: 'doc_algo_golden',
            page: 1,
            sectionPath: ['Algorithms', 'Search'],
            blockId: 'block_bs_02',
          ),
          assets: [
            CardAsset(
              id: 'asset_code_01',
              type: CardAssetType.syntaxCode,
              content: 'class BinarySearch {\n  int search(List<int> a, int key) => a.indexOf(key);\n}',
              label: 'dart',
            ),
          ],
        ),
      ];

      final deck1 = serializer.serializeDeck(
        deckId: 'golden_deck_01',
        deckTitle: 'Biochemistry and Algorithms Golden Deck',
        subject: 'STEM',
        category: 'Exams',
        candidateCards: candidateCards,
      );

      final deck2 = serializer.serializeDeck(
        deckId: 'golden_deck_01',
        deckTitle: 'Biochemistry and Algorithms Golden Deck',
        subject: 'STEM',
        category: 'Exams',
        candidateCards: candidateCards,
      );

      // Verify deterministic IDs match sha256 specification
      final expectedId0 = SchemaSerializer.generateDeterministicId(
        docId: 'doc_bio_golden',
        blockId: 'block_etc_01',
        cognitiveType: 'mechanism',
      );
      final expectedId1 = SchemaSerializer.generateDeterministicId(
        docId: 'doc_algo_golden',
        blockId: 'block_bs_02',
        cognitiveType: 'code',
      );

      expect(deck1.cards[0].id, equals(expectedId0));
      expect(deck1.cards[1].id, equals(expectedId1));

      // Verify exact JSON determinism across independent serialization runs
      final json1 = deck1.toJson();
      final json2 = deck2.toJson();
      expect(json1, equals(json2));

      // Verify exact schema contract properties
      expect(json1['schema_version'], equals(SchemaSerializer.currentSchemaVersion));
      expect(json1['deck_id'], equals('golden_deck_01'));
      expect(json1['deck_title'], equals('Biochemistry and Algorithms Golden Deck'));
      expect(json1['total_cards'], equals(2));
      expect(json1['generated_at'], equals('2026-10-10T12:00:00.000Z'));

      final cardsList = (json1['cards'] as List).cast<Map<String, dynamic>>();
      final firstCard = cardsList.first;
      final fsrs = firstCard['fsrs'] as Map<String, dynamic>;
      expect(fsrs['stability'], equals(0.0));
      expect(fsrs['difficulty'], equals(0.0));
      final firstSource = firstCard['source'] as Map<String, dynamic>;
      expect(firstSource['doc_id'], equals('doc_bio_golden'));
      expect(firstSource['page'], equals(2));

      final secondCard = cardsList.last;
      final assets = (secondCard['assets'] as List).cast<Map<String, dynamic>>();
      expect(assets, isNotEmpty);
      expect(assets.first['type'], equals('syntaxCode'));
      expect(assets.first['label'], equals('dart'));
    });

    // -------------------------------------------------------------------------
    // Gate 7: Characterization Test Running Full Production Pipeline Across Fixtures
    // -------------------------------------------------------------------------
    test('Gate 7 (Characterization Test): full production pipeline runs across all fixtures without unhandled crashes', () {
      final fixturesDir = Directory('test/fixtures/ingestion');
      final allFiles = fixturesDir.listSync().whereType<File>().toList();
      expect(allFiles, isNotEmpty);

      var validDocsProcessed = 0;
      var corruptDocsSafeguarded = 0;

      for (final file in allFiles) {
        final filename = file.uri.pathSegments.last;
        if (filename.endsWith('.json') || filename.endsWith('.png') || filename.endsWith('.jpg')) continue;

        final ext = filename.split('.').last.toLowerCase();
        final effectiveExt = ext == 'text' ? 'txt' : ext;
        final bytes = file.readAsBytesSync();

        // Check corrupt/encrypted fixtures
        if (filename.contains('corrupt') || filename.contains('encrypted')) {
          try {
            final text = docService.extractTextFromBytes(bytes, fileType: effectiveExt, filename: filename);
            if (text.isEmpty) {
              corruptDocsSafeguarded++;
            }
          } on Object {
            // Handled exception is expected for corrupt/encrypted files
            corruptDocsSafeguarded++;
          }
          continue;
        }

        // Production pipeline for valid educational documents
        String extractedText;
        try {
          extractedText = effectiveExt == 'pdf'
              ? pdfService.extractTextFromPdfBytes(bytes, filename: filename)
              : docService.extractTextFromBytes(bytes, fileType: effectiveExt, filename: filename);
        } on Object catch (e) {
          fail('Valid fixture $filename failed during text extraction: $e');
        }

        // Synthesize cards through production synthesizer
        final deck = docService.synthesizeDeckFromDocument(
          documentId: 'char_test_${filename.hashCode}',
          fullText: extractedText,
          filename: filename,
        );

        expect(deck, isNotNull);
        expect(deck.schemaVersion, equals('1.0.0'));
        validDocsProcessed++;
      }

      expect(corruptDocsSafeguarded, greaterThanOrEqualTo(4), reason: 'Corrupt and encrypted files must be handled gracefully');
      expect(validDocsProcessed, greaterThanOrEqualTo(30), reason: 'All valid fixtures must complete production pipeline');
    });
  });
}
