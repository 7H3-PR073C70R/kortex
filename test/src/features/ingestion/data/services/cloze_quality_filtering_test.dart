import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/ingestion/data/services/offline_card_builder.dart';
import 'package:kortex/src/features/ingestion/domain/entities/extraction_report.dart';
import 'package:kortex/src/features/ingestion/domain/entities/pedagogical_card_schema.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Task 2.3: Cloze Quality Filtering & Keyword Exclusions', () {
    const builder = OfflineCardBuilder();

    test('extractClozeExclusions extracts title tokens, camelCase components, and meta-words', () {
      final exclusions = OfflineCardBuilder.extractClozeExclusions(
        docContext: 'Kotlin Reference Guide',
      );

      expect(exclusions, contains('kotlin'));
      expect(exclusions, contains('reference'));
      expect(exclusions, contains('guide'));
      // Meta-structural vocabulary
      expect(exclusions, contains('chapter'));
      expect(exclusions, contains('section'));
      expect(exclusions, contains('figure'));
      expect(exclusions, contains('table'));
    });

    test('extractClozeExclusions splits camelCase and handles possessives', () {
      final exclusions = OfflineCardBuilder.extractClozeExclusions(
        docContext: 'FlutterEngineering Handbook',
      );

      expect(exclusions, contains('flutter'));
      expect(exclusions, contains('engineering'));
      expect(exclusions, contains('handbook'));
    });

    test('extractClozeExclusions identifies dominant corpus-wide terms with frequency >= 35%', () {
      final exclusions = OfflineCardBuilder.extractClozeExclusions(
        docContext: 'Cloud Systems Architecture',
        totalBlocks: 10,
        termFrequency: {
          'kubernetes': 8, // 8 / 10 = 80% >= 35% and >= 6
          'deployment': 2,
        },
      );

      expect(exclusions, contains('kubernetes'));
      expect(exclusions.contains('deployment'), isFalse);
    });

    test('prevents trivial cloze blanks of the document title (e.g. "Kotlin" in Kotlin manual)', () {
      const kotlinDoc = '''
# Kotlin Programming

Kotlin supports coroutines for asynchronous programming and structured concurrency.
Kotlin provides first-class null safety to eliminate NullPointerExceptions.
''';

      final cards = builder.buildCards(
        kotlinDoc,
        metadata: {'title': 'Kotlin Programming'},
      );

      final clozeCards = cards.where((c) => c.type == OfflineCardType.cloze).toList();
      expect(clozeCards, isNotEmpty);

      for (final card in clozeCards) {
        final answer = card.back.split('\n').first.trim().toLowerCase();
        expect(
          answer,
          isNot(equals('kotlin')),
          reason: 'Cloze card must not blank the document title "Kotlin": ${card.front}',
        );
      }
    });

    test('prevents trivial cloze blanks of the section heading', () {
      const sectionDoc = '''
# Advanced Algorithms

## Dynamic Programming
Dynamic programming solves complex problems by breaking them down into overlapping subproblems.
''';

      final cards = builder.buildCards(sectionDoc);
      final clozeCards = cards.where((c) => c.type == OfflineCardType.cloze).toList();

      for (final card in clozeCards) {
        final answer = card.back.split('\n').first.trim().toLowerCase();
        expect(
          answer,
          isNot(equals('dynamic')),
          reason: 'Cloze card must not blank words from the active heading: ${card.front}',
        );
        expect(
          answer,
          isNot(equals('programming')),
          reason: 'Cloze card must not blank words from the active heading: ${card.front}',
        );
      }
    });
  });

  group('Task 2.3: Duplicate Sentence & Answer Suppression', () {
    const builder = OfflineCardBuilder();

    test('deduplicates cards citing the identical source sentence', () {
      final report = ExtractionReport(filename: 'test.md');

      // Use card building through text with duplicated sentences:
      const docWithDuplicateSentence = '''
# Cell Biology

Cellular respiration is the biochemical process by which cells convert glucose and oxygen into usable ATP energy.

Cellular respiration is the biochemical process by which cells convert glucose and oxygen into usable ATP energy.
''';

      final cards = builder.buildCards(docWithDuplicateSentence, report: report);

      // Verify that no two cards share the exact same source sentence
      final seenSentences = <String>{};
      for (final card in cards) {
        final sentence = OfflineCardBuilder.extractSourceSentence(card);
        final norm = sentence.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
        expect(
          seenSentences.contains(norm),
          isFalse,
          reason: 'Identical source sentence must not produce duplicate cards: "$sentence"',
        );
        seenSentences.add(norm);
      }

      expect(report.totalDroppedElements, greaterThanOrEqualTo(1));
      expect(
        report.droppedElements.any((d) => d.rule == 'duplicate_source_sentence' || d.rule == 'duplicate_card_front' || d.rule == 'semantic_duplicate_card_front'),
        isTrue,
      );
    });

    test('deduplicates cards yielding identical answers within the same sub-deck', () {
      final report = ExtractionReport(filename: 'test.md');

      const docWithRedundantAnswers = '''
# Kotlin Functions

Top-level functions are declared using the fun keyword at package level.

Member functions in classes also require the fun keyword before the function identifier.

Local functions nested inside other functions also utilize the fun keyword.
''';

      final cards = builder.buildCards(
        docWithRedundantAnswers,
        metadata: {'title': 'Kotlin Functions'},
        report: report,
      );

      // Check cloze answers within the "Kotlin Functions" subdeck
      final subdeckAnswers = <String>[];
      for (final card in cards) {
        final ans = OfflineCardBuilder.extractCardAnswer(card).toLowerCase();
        subdeckAnswers.add(ans);
      }

      // Assert that 'fun' appears at most once in this subdeck
      final funCount = subdeckAnswers.where((a) => a == 'fun').length;
      expect(
        funCount,
        lessThanOrEqualTo(1),
        reason: 'Duplicate answers within the same sub-deck must be suppressed to eliminate answer clusters',
      );
    });

    test('allows identical answers across DIFFERENT sub-decks', () {
      const docWithMultiSectionSameTerm = '''
# Software Design

## Client Architecture
WebSockets enable real-time bidirectional communication between the user interface and gateway.

## Server Architecture
WebSockets enable the backend gateway to push events directly to active client sessions.
''';

      final cards = builder.buildCards(docWithMultiSectionSameTerm);

      // Each distinct section/subdeck should be allowed its own legitimate questions
      final subdecks = cards.map(OfflineCardBuilder.subDeckKey).toSet();
      expect(subdecks.length, greaterThanOrEqualTo(2));
    });

    test('subDeckKey cleanly normalizes headings and section paths', () {
      const card1 = OfflineCard(
        type: OfflineCardType.qa,
        front: 'Q1',
        back: 'A1',
        confidence: 0.9,
        heading: '## 3.4 Coroutines Basics',
        source: CardSource(
          docId: 'doc',
          page: 1,
          sectionPath: ['## 3.4 Coroutines Basics'],
        ),
      );

      const card2 = OfflineCard(
        type: OfflineCardType.qa,
        front: 'Q2',
        back: 'A2',
        confidence: 0.9,
        heading: 'Coroutines Basics',
        source: CardSource(
          docId: 'doc',
          page: 1,
          sectionPath: ['Coroutines Basics'],
        ),
      );

      expect(
        OfflineCardBuilder.subDeckKey(card1),
        equals(OfflineCardBuilder.subDeckKey(card2)),
      );
      expect(OfflineCardBuilder.subDeckKey(card1), equals('coroutines basics'));
    });
  });
}
