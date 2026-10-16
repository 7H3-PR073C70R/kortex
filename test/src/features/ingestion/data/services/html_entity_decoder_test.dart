import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/ingestion/data/services/document_parser_service.dart';
import 'package:kortex/src/features/ingestion/data/services/html_entity_decoder.dart';
import 'package:kortex/src/features/ingestion/data/services/local_docx_parser_service.dart';
import 'package:kortex/src/features/ingestion/data/services/local_epub_parser_service.dart';
import 'package:kortex/src/features/ingestion/data/services/local_html_parser_service.dart';
import 'package:kortex/src/features/ingestion/data/services/offline_card_builder.dart';

void main() {
  const fixturesDir = 'test/fixtures/ingestion';

  group('HtmlEntityDecoder Unit Tests', () {
    test('decodes hexadecimal numeric character references', () {
      expect(HtmlEntityDecoder.decode('Traité d&#x27;Épistémologie'), equals("Traité d'Épistémologie"));
      expect(HtmlEntityDecoder.decode('Quoted &#X22;text&#X22;'), equals('Quoted "text"'));
      expect(HtmlEntityDecoder.decode('Curly &#x2019;quote&#x2019;'), equals('Curly ’quote’'));
      expect(HtmlEntityDecoder.decode('&#xC9;pist&#xE9;mologie'), equals('Épistémologie'));
    });

    test('decodes decimal numeric character references', () {
      expect(HtmlEntityDecoder.decode('It&#39;s a test'), equals("It's a test"));
      expect(HtmlEntityDecoder.decode('Non&#160;breaking&#160;space'), equals('Non breaking space'));
      expect(HtmlEntityDecoder.decode('Em&#8212;dash'), equals('Em—dash'));
      expect(HtmlEntityDecoder.decode('Copyright &#169; 2026'), equals('Copyright © 2026'));
    });

    test('decodes named HTML5 and XML entities', () {
      expect(HtmlEntityDecoder.decode('3.30 &times; 10^23'), equals('3.30 × 10^23'));
      expect(HtmlEntityDecoder.decode('Fast &amp; Furious &lt;tag&gt; &quot;quote&quot; &apos;single&apos;'),
          equals("Fast & Furious <tag> \"quote\" 'single'"));
      expect(HtmlEntityDecoder.decode('&plusmn; 5% &deg;C'), equals('± 5% °C'));
      expect(HtmlEntityDecoder.decode('&ndash; and &mdash; and &hellip;'), equals('– and — and …'));
      expect(HtmlEntityDecoder.decode('&Eacute;cole et &eacute;cole'), equals('École et école'));
      expect(HtmlEntityDecoder.decode('&nabla; &middot; E'), equals('∇ · E'));
    });

    test('handles fast path for strings without ampersand', () {
      const plain = 'Simple string with no entities whatsoever!';
      expect(identical(HtmlEntityDecoder.decode(plain), plain), isTrue);
    });

    test('preserves malformed or unmapped entities gracefully', () {
      expect(HtmlEntityDecoder.decode('&notanentity;'), equals('&notanentity;'));
      expect(HtmlEntityDecoder.decode('Just & by itself'), equals('Just & by itself'));
      expect(HtmlEntityDecoder.decode('Trailing &'), equals('Trailing &'));
      expect(HtmlEntityDecoder.decode('&#; and &#x;'), equals('&#; and &#x;'));
    });
  });

  group('Boundary-Level Integration Tests (Task 0.4)', () {
    test('LocalEpubParserService decodes OPF metadata title Traité d&#x27;Épistémologie', () {
      final file = File('$fixturesDir/doc_french_philosophy_epistemology.epub');
      expect(file.existsSync(), isTrue);

      final extracted = LocalEpubParserService.extractTextFromBytesSync(file.readAsBytesSync());

      // Heading 1 must be decoded, never containing &#x27;
      expect(extracted, contains("Traité d'Épistémologie"));
      expect(extracted, isNot(contains('&#x27;')));
      expect(extracted, isNot(contains('&amp;#x27;')));
    });

    test('LocalDocxParserService decodes table cells with 3.30 &times; 10^23', () {
      final file = File('$fixturesDir/doc_hindi_astrophysics_gravitation.docx');
      expect(file.existsSync(), isTrue);

      final extracted = LocalDocxParserService.extractTextFromBytesSync(file.readAsBytesSync());

      expect(extracted, contains('3.30 × 10^23'));
      expect(extracted, isNot(contains('&times;')));
    });

    test('LocalHtmlParserService decodes entities across headings, code, and body', () {
      const html = '''
<!DOCTYPE html>
<html>
<head><title>Test &amp; Demo</title></head>
<body>
  <h1>L&#x27;&Eacute;tude de la Philosophie</h1>
  <p>Distance: 3.30 &times; 10^23 m &plusmn; 5%</p>
  <p>Author&apos;s summary: It&#39;s completed &mdash; verified.</p>
</body>
</html>
''';

      final extracted = LocalHtmlParserService.extractTextFromString(html);

      expect(extracted, contains("L'Étude de la Philosophie"));
      expect(extracted, contains('3.30 × 10^23 m ± 5%'));
      expect(extracted, contains("Author's summary: It's completed — verified."));
      expect(extracted, isNot(contains('&#x27;')));
      expect(extracted, isNot(contains('&times;')));
      expect(extracted, isNot(contains('&Eacute;')));
    });

    test('OfflineCardBuilder eliminates entities from deck titles, topics, and cards', () {
      const rawText = '''
# Traité d&#x27;Épistémologie et des Sciences

L&#x27;&Eacute;pistémologie defines the branch of philosophy studying the nature and scope of knowledge.
The mass of Mercury is approximately 3.30 &times; 10^23 kg with a tolerance of &plusmn; 0.05.
''';

      const builder = OfflineCardBuilder();
      final deckTitle = OfflineCardBuilder.extractDeckTitle(fullText: rawText);
      expect(deckTitle, equals("Traité d'Épistémologie et des Sciences"));
      expect(deckTitle, isNot(contains('&#x27;')));

      final cards = builder.buildCards(rawText);
      expect(cards, isNotEmpty);

      final entityRegex = RegExp('&#[xX]?[0-9a-fA-F]+;|(&[a-zA-Z]+;)');

      for (final card in cards) {
        expect(
          entityRegex.hasMatch(card.front),
          isFalse,
          reason: 'Card front must not contain raw HTML/XML entity: "${card.front}"',
        );
        expect(
          entityRegex.hasMatch(card.back),
          isFalse,
          reason: 'Card back must not contain raw HTML/XML entity: "${card.back}"',
        );
        if (card.heading != null) {
          expect(
            entityRegex.hasMatch(card.heading!),
            isFalse,
            reason: 'Card heading must not contain raw HTML/XML entity: "${card.heading}"',
          );
        }
      }
    });

    test('DocumentParserService synthesis produces 0 entity leaks across French & Hindi fixtures', () {
      const docService = DocumentParserService();

      final fixtures = [
        'doc_french_philosophy_epistemology.epub',
        'doc_hindi_astrophysics_gravitation.docx',
      ];

      final entityRegex = RegExp('&#[xX]?[0-9a-fA-F]+;|(&[a-zA-Z]+;)');

      for (final fixtureName in fixtures) {
        final file = File('$fixturesDir/$fixtureName');
        expect(file.existsSync(), isTrue);

        final ext = fixtureName.split('.').last;
        final bytes = file.readAsBytesSync();
        final fullText = docService.extractTextFromBytes(bytes, fileType: ext, filename: fixtureName);

        final deck = docService.synthesizeDeckFromDocument(
          documentId: 'entity_test_${fixtureName.hashCode}',
          fullText: fullText,
          filename: fixtureName,
        );

        expect(
          entityRegex.hasMatch(deck.deckTitle),
          isFalse,
          reason: 'Deck title for $fixtureName leaked entity: "${deck.deckTitle}"',
        );

        for (final card in deck.cards) {
          expect(
            entityRegex.hasMatch(card.front),
            isFalse,
            reason: '[$fixtureName] Card front leaked entity: "${card.front}"',
          );
          expect(
            entityRegex.hasMatch(card.back),
            isFalse,
            reason: '[$fixtureName] Card back leaked entity: "${card.back}"',
          );
        }
      }
    });
  });
}
