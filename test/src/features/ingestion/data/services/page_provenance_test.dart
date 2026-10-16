import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/ingestion/data/services/document_parser_service.dart';
import 'package:kortex/src/features/ingestion/data/services/local_pdf_parser_service.dart';
import 'package:kortex/src/features/ingestion/data/services/markdown_ir_parser.dart';
import 'package:kortex/src/features/ingestion/data/services/offline_card_builder.dart';
import 'package:kortex/src/features/ingestion/domain/entities/document_ir.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Page Provenance Through IR (Task 2.1)', () {
    const pdfService = LocalPdfParserService();
    const docService = DocumentParserService();

    test('LocalPdfParserService extracts PageLayouts with 1-based pageIndex and delimiters', () {
      final file = File('test/fixtures/ingestion/Letter of Engagement - Oluwatobi Okanlawon.pdf');
      if (!file.existsSync()) return;

      final bytes = file.readAsBytesSync();
      final layouts = pdfService.extractPageLayoutsFromPdfBytes(
        bytes,
        filename: 'Letter of Engagement - Oluwatobi Okanlawon.pdf',
      );

      expect(layouts.isNotEmpty, isTrue);
      expect(layouts.first.pageIndex, equals(1));
      if (layouts.length > 1) {
        expect(layouts[1].pageIndex, equals(2));
      }

      final fullText = pdfService.extractTextFromPdfBytes(
        bytes,
        filename: 'Letter of Engagement - Oluwatobi Okanlawon.pdf',
      );

      expect(fullText.contains('<!-- page: 1 -->'), isTrue);
      if (layouts.length > 1) {
        expect(fullText.contains('<!-- page: 2 -->'), isTrue);
      }
    });

    test('MarkdownIrParser parses multi-page comments into distinct BlockProvenance pages', () {
      const markdown = '''
# Section One
<!-- page: 1 -->
Photosynthesis is defined as the biochemical process by which plants convert light energy into glucose.

<!-- page: 2 -->
# Section Two
Mitochondria are organelles that generate most of the chemical energy needed to power biochemical reactions.
''';

      final ir = const MarkdownIrParser().parse(
        markdown: markdown,
        documentId: 'doc_bio',
        filename: 'biology.md',
      );

      final page1Blocks = ir.blocks.where((b) => b.provenance.page == 1).toList();
      final page2Blocks = ir.blocks.where((b) => b.provenance.page == 2).toList();

      expect(page1Blocks.isNotEmpty, isTrue, reason: 'Must have blocks on page 1');
      expect(page2Blocks.isNotEmpty, isTrue, reason: 'Must have blocks on page 2');

      final def1 = page1Blocks.whereType<ParagraphBlock>().first;
      expect(def1.provenance.page, equals(1));
      expect(def1.text, contains('Photosynthesis'));

      final def2 = page2Blocks.whereType<ParagraphBlock>().first;
      expect(def2.provenance.page, equals(2));
      expect(def2.text, contains('Mitochondria'));
    });

    test('OfflineCardBuilder preserves multi-page provenance and p{page}_b{index}_{type} block IDs', () {
      const markdown = '''
<!-- page: 1 -->
# Cell Biology
Photosynthesis is defined as the biological process of turning light into energy.

<!-- page: 2 -->
# Cellular Respiration
Glycolysis yields a net yield of two ATP molecules and two pyruvate molecules per glucose.
''';

      const builder = OfflineCardBuilder();
      final cards = builder.buildCards(markdown);

      expect(cards.length, greaterThanOrEqualTo(2));

      final pages = cards.map((c) => c.source?.page).toSet();
      expect(pages.contains(1), isTrue, reason: 'Expected cards with source.page == 1');
      expect(pages.contains(2), isTrue, reason: 'Expected cards with source.page == 2');

      for (final card in cards) {
        expect(card.source, isNotNull);
        final src = card.source!;
        expect(src.page, greaterThanOrEqualTo(1));
        expect(
          src.blockId,
          matches(RegExp(r'^p\d+_b\d+_[a-z0-9_]+$')),
          reason: 'Block ID "${src.blockId}" must adhere to p{page}_b{index}_{type}',
        );
      }
    });

    test('OfflineCardBuilder.buildCardsFromIR preserves page provenance from DocumentIR', () {
      const ir = DocumentIR(
        docId: 'doc_physics',
        filename: 'physics.md',
        blocks: [
          HeadingBlock(
            text: 'Classical Mechanics',
            level: 1,
            provenance: BlockProvenance(
              docId: 'doc_physics',
              page: 1,
              readingOrder: 0,
              sectionPath: ['Classical Mechanics'],
            ),
          ),
          ParagraphBlock(
            text: 'Newtonian gravity is defined as the universal attractive force between any two masses.',
            sentences: ['Newtonian gravity is defined as the universal attractive force between any two masses.'],
            provenance: BlockProvenance(
              docId: 'doc_physics',
              page: 1,
              readingOrder: 1,
              sectionPath: ['Classical Mechanics'],
            ),
          ),
          HeadingBlock(
            text: 'Quantum Physics',
            level: 1,
            provenance: BlockProvenance(
              docId: 'doc_physics',
              page: 3,
              readingOrder: 2,
              sectionPath: ['Quantum Physics'],
            ),
          ),
          ParagraphBlock(
            text: 'Wave-particle duality states that matter exhibits both wave and particle characteristics.',
            sentences: ['Wave-particle duality states that matter exhibits both wave and particle characteristics.'],
            provenance: BlockProvenance(
              docId: 'doc_physics',
              page: 3,
              readingOrder: 3,
              sectionPath: ['Quantum Physics'],
            ),
          ),
        ],
      );

      const builder = OfflineCardBuilder();
      final cards = builder.buildCardsFromIR(ir);

      expect(cards.isNotEmpty, isTrue);

      final page1Cards = cards.where((c) => c.source?.page == 1).toList();
      final page3Cards = cards.where((c) => c.source?.page == 3).toList();

      expect(page1Cards.isNotEmpty, isTrue);
      expect(page3Cards.isNotEmpty, isTrue);
      expect(page3Cards.first.source!.blockId, startsWith('p3_'));
    });

    test('DocumentParserService.synthesizeDeckFromDocument preserves varied page provenance', () {
      const multiPageText = '''
<!-- page: 1 -->
# Software Engineering
Continuous integration is defined as the development practice where developers merge code into a shared repository.

<!-- page: 2 -->
# System Design
Horizontal scaling refers to adding more machines into your pool of resources rather than upgrading one machine.
''';

      final deck = docService.synthesizeDeckFromDocument(
        documentId: 'deck_provenance_test',
        fullText: multiPageText,
        filename: 'architecture.md',
      );

      expect(deck.cards.length, greaterThanOrEqualTo(2));

      final pages = deck.cards.map((c) => c.source?.page).toSet();
      expect(pages.length, greaterThanOrEqualTo(2), reason: 'Deck should contain varied page provenance');
      expect(pages.contains(1), isTrue);
      expect(pages.contains(2), isTrue);

      for (final card in deck.cards) {
        expect(card.source, isNotNull);
        expect(card.source!.docId, equals('deck_provenance_test'));
        expect(
          card.source!.blockId,
          matches(RegExp(r'^p\d+_b\d+_[a-z0-9_]+$')),
        );
      }
    });

    test('Single-page document defaults cleanly to page: 1 without artificial block ids', () {
      const singlePageText = '''
# Organic Chemistry
Enzymes are defined as biological catalysts that accelerate chemical reactions without being consumed.
''';

      final deck = docService.synthesizeDeckFromDocument(
        documentId: 'single_page_test',
        fullText: singlePageText,
        filename: 'chemistry.md',
      );

      expect(deck.cards.isNotEmpty, isTrue);
      for (final card in deck.cards) {
        expect(card.source?.page, equals(1));
        expect(card.source?.blockId, startsWith('p1_b'));
      }
    });
  });
}
