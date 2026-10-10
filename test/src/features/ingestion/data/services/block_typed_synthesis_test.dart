import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/ingestion/data/services/offline_card_builder.dart';
import 'package:kortex/src/features/ingestion/data/services/synthesis/flashcard_synthesizer.dart';
import 'package:kortex/src/features/ingestion/data/services/synthesis/schema_serializer.dart';
import 'package:kortex/src/features/ingestion/domain/entities/document_ir.dart';

void main() {
  const builder = OfflineCardBuilder();

  group('Step 12: Block-Typed Flashcard Synthesis & Quality Gates', () {
    test('Code cards infer language from fence info string and attach syntaxCode asset', () {
      const codeSample = '''
# State Management

```dart
class CounterNotifier extends ValueNotifier<int> {
  CounterNotifier() : super(0);
  void increment() => value++;
}
```
''';

      final cards = builder.buildCards(codeSample);
      final codeCards = cards.where((c) => c.type == OfflineCardType.code).toList();

      expect(codeCards, isNotEmpty);
      final card = codeCards.first;
      expect(card.front, contains('CounterNotifier'));
      expect(card.front, contains('Dart'));
      expect(card.back, contains('class CounterNotifier extends ValueNotifier<int>'));
      expect(card.assets, isNotEmpty);
      expect(card.assets.first.type, CardAssetType.syntaxCode);
      expect(card.assets.first.label, 'dart');
      expect(card.type.toCognitiveType(), CognitiveQuestionType.code);
    });

    test('Code cards infer language from source heuristics when fence is untagged', () {
      const pythonSample = '''
# Neural Networks

```
def train_epoch(model, dataloader, optimizer, criterion):
    model.train()
    total_loss = 0.0
    for inputs, targets in dataloader:
        optimizer.zero_grad()
        outputs = model(inputs)
        loss = criterion(outputs, targets)
        loss.backward()
        optimizer.step()
        total_loss += loss.item()
    return total_loss
```
''';

      final cards = builder.buildCards(pythonSample);
      final codeCards = cards.where((c) => c.type == OfflineCardType.code).toList();

      expect(codeCards, isNotEmpty);
      final card = codeCards.first;
      expect(card.front, contains('train_epoch'));
      expect(card.front, contains('Python'));
      expect(card.assets.first.type, CardAssetType.syntaxCode);
      expect(card.assets.first.label, 'python');
    });

    test('Formula cards synthesize lead-in concept and attach latexEquation asset', () {
      const mathSample = r'''
# Thermodynamics

$$ \Delta G = \Delta H - T \Delta S $$
''';

      final cards = builder.buildCards(mathSample);
      final mathCards = cards.where((c) => c.type == OfflineCardType.formula).toList();

      expect(mathCards, isNotEmpty);
      final card = mathCards.first;
      expect(card.front, contains('Thermodynamics'));
      expect(card.back, contains(r'\Delta G = \Delta H - T \Delta S'));
      expect(card.assets, isNotEmpty);
      expect(card.assets.first.type, CardAssetType.latexEquation);
      expect(card.type.toCognitiveType(), CognitiveQuestionType.math);
    });

    test('Figure cards synthesize contextual questions, attach image asset, and map to location', () {
      const ir = DocumentIR(
        docId: 'doc_fig_1',
        filename: 'architecture.pdf',
        blocks: [
          HeadingBlock(
            text: 'System Architecture',
            level: 1,
            provenance: BlockProvenance(
              docId: 'doc_fig_1',
              page: 1,
              readingOrder: 0,
              sectionPath: ['System Architecture'],
              bbox: BoundingBox(left: 0, top: 0, right: 100, bottom: 20),
            ),
          ),
          FigureBlock(
            page: 1,
            label: 'Figure 1.1',
            caption: 'Pipeline Event Loop',
            imageRef: 'assets/figures/fig_1_1.png',
            provenance: BlockProvenance(
              docId: 'doc_fig_1',
              page: 1,
              readingOrder: 1,
              sectionPath: ['System Architecture'],
              bbox: BoundingBox(left: 0, top: 20, right: 100, bottom: 100),
            ),
          ),
        ],
      );

      final cards = builder.buildCardsFromIR(ir);
      final figCards = cards.where((c) => c.type == OfflineCardType.figure).toList();

      expect(figCards, isNotEmpty);
      final card = figCards.first;
      expect(card.front, contains('Figure 1.1'));
      expect(card.front, contains('Pipeline Event Loop'));
      expect(card.back, 'Pipeline Event Loop');
      expect(card.assets, isNotEmpty);
      expect(card.assets.first.type, CardAssetType.image);
      expect(card.assets.first.content, 'assets/figures/fig_1_1.png');
      expect(card.type.toCognitiveType(), CognitiveQuestionType.location);
    });

    test('Table cards synthesize header-grounded relationship questions and map to yieldResult', () {
      const ir = DocumentIR(
        docId: 'doc_tbl_1',
        filename: 'sorting_algorithms.pdf',
        blocks: [
          HeadingBlock(
            text: 'Algorithm Complexities',
            level: 1,
            provenance: BlockProvenance(
              docId: 'doc_tbl_1',
              page: 1,
              readingOrder: 0,
              sectionPath: ['Algorithm Complexities'],
              bbox: BoundingBox(left: 0, top: 0, right: 100, bottom: 20),
            ),
          ),
          TableBlock(
            headers: ['Algorithm', 'Time Complexity', 'Space Complexity'],
            rows: [
              ['Quick Sort', 'O(n log n)', 'O(log n)'],
              ['Merge Sort', 'O(n log n)', 'O(n)'],
            ],
            caption: 'Sorting Table',
            provenance: BlockProvenance(
              docId: 'doc_tbl_1',
              page: 1,
              readingOrder: 1,
              sectionPath: ['Algorithm Complexities'],
              bbox: BoundingBox(left: 0, top: 20, right: 100, bottom: 100),
            ),
          ),
        ],
      );

      final cards = builder.buildCardsFromIR(ir);
      final tableCards = cards.where((c) => c.type == OfflineCardType.table).toList();

      expect(tableCards, isNotEmpty);
      final qSortCard = tableCards.firstWhere((c) => c.front.contains('Quick Sort'));
      expect(qSortCard.front, contains('Time Complexity'));
      expect(qSortCard.front, contains('Space Complexity'));
      expect(qSortCard.back, '| Quick Sort | O(n log n) | O(log n) |');
      expect(qSortCard.type.toCognitiveType(), CognitiveQuestionType.yieldResult);

      // Verify serialization allows table row back formatting
      final candidate = PedagogicalCandidateCard(
        front: qSortCard.front,
        back: qSortCard.back,
        type: qSortCard.type.toCognitiveType(),
        sourceTopic: 'Algorithm Complexities',
        source: qSortCard.source,
        assets: qSortCard.assets,
      );
      final deck = const SchemaSerializer().serializeDeck(
        deckId: 'deck_1',
        deckTitle: 'Sorting Algorithms',
        subject: 'Computer Science',
        category: 'Algorithms',
        candidateCards: [candidate],
      );
      expect(deck.cards, isNotEmpty);
      expect(deck.cards.first.back, '| Quick Sort | O(n log n) | O(log n) |');
    });

    test('Asset adjacency binds figures and equations to neighboring cards in same section', () {
      const ir = DocumentIR(
        docId: 'doc_adj_1',
        filename: 'kinematics.pdf',
        blocks: [
          HeadingBlock(
            text: 'Newtonian Motion',
            level: 1,
            provenance: BlockProvenance(
              docId: 'doc_adj_1',
              page: 1,
              readingOrder: 0,
              sectionPath: ['Newtonian Motion'],
              bbox: BoundingBox(left: 0, top: 0, right: 100, bottom: 20),
            ),
          ),
          MathBlock(
            latex: r'F = m \cdot a',
            isDisplay: true,
            rawMathText: r'F = m \cdot a',
            provenance: BlockProvenance(
              docId: 'doc_adj_1',
              page: 1,
              readingOrder: 1,
              sectionPath: ['Newtonian Motion'],
              bbox: BoundingBox(left: 0, top: 25, right: 100, bottom: 50),
            ),
          ),
          ParagraphBlock(
            text: 'Newtonian acceleration governs the rate of velocity change under an applied net external force.',
            sentences: [
              'Newtonian acceleration governs the rate of velocity change under an applied net external force.',
            ],
            provenance: BlockProvenance(
              docId: 'doc_adj_1',
              page: 1,
              readingOrder: 2,
              sectionPath: ['Newtonian Motion'],
              bbox: BoundingBox(left: 0, top: 55, right: 100, bottom: 80),
            ),
          ),
        ],
      );

      final cards = builder.buildCardsFromIR(ir);
      final proseCard = cards.firstWhere(
        (c) => c.type != OfflineCardType.formula && c.heading == 'Newtonian Motion',
      );

      expect(proseCard.assets, isNotEmpty);
      expect(proseCard.assets.first.type, CardAssetType.latexEquation);
      expect(proseCard.assets.first.content, contains(r'F = m \cdot a'));
    });

    test('Quality gates: filters out dangling pronouns and weak clause-initial transitions', () {
      const textWithDanglingPronouns = '''
# Cognitive Psychology

It is known that sensory input decays rapidly without attention.
They have demonstrated that rehearsal maintains short-term items.
This means that working memory has bounded capacity.
However, semantic networks organize knowledge hierarchically.
Therefore, retrieval cues facilitate rapid episodic memory recall.
Working memory capacity limits the simultaneous manipulation of cognitive items.
''';

      final cards = builder.buildCards(textWithDanglingPronouns);

      for (final card in cards) {
        final frontLower = card.front.toLowerCase();
        // None of the card stems or cloze contexts should begin with dangling pronouns
        expect(frontLower, isNot(startsWith('it is')));
        expect(frontLower, isNot(startsWith('they have')));
        expect(frontLower, isNot(startsWith('this means')));
        expect(frontLower, isNot(startsWith('however,')));
        expect(frontLower, isNot(startsWith('therefore,')));
      }
    });

    test('Quality gates: extractDeckTitle prioritizes metadata then primary first-page heading', () {
      // 1. From metadata
      final titleFromMeta = OfflineCardBuilder.extractDeckTitle(
        metadata: {'title': 'Distributed Consensus Protocols'},
        fullText: '# Some Other Heading\nContent here.',
      );
      expect(titleFromMeta, 'Distributed Consensus Protocols');

      // 2. From primary first-page heading in IR
      const ir = DocumentIR(
        docId: 'doc_title_1',
        filename: 'lecture_01.pdf',
        blocks: [
          HeadingBlock(
            text: 'Advanced Quantum Mechanics',
            level: 1,
            provenance: BlockProvenance(
              docId: 'doc_title_1',
              page: 1,
              readingOrder: 0,
              sectionPath: ['Advanced Quantum Mechanics'],
              bbox: BoundingBox(left: 0, top: 0, right: 100, bottom: 20),
            ),
          ),
        ],
      );
      final titleFromIR = OfflineCardBuilder.extractDeckTitle(ir: ir);
      expect(titleFromIR, 'Advanced Quantum Mechanics');

      // 3. Fallback to cleaned filename
      final titleFromFilename = OfflineCardBuilder.extractDeckTitle(
        filename: 'intro_machine-learning_v2.pdf',
      );
      expect(titleFromFilename, 'intro machine learning v2');
    });

    test('Quality gates: semantic deduplication suppresses high Jaccard token overlap (>0.85)', () {
      const duplicateSample = '''
# Biochemistry

Adenosine triphosphate serves as the primary molecular currency for energy transfer within living biological cells.
Adenosine triphosphate acts as the primary molecular currency for energy transfer within living biological cells.
Ribosomes synthesize proteins by translating messenger RNA sequences into amino acid polypeptide chains.
''';

      final cards = builder.buildCards(duplicateSample);
      // We should not have two almost identical cards for ATP
      final atpCards = cards.where((c) => c.front.contains('Adenosine triphosphate') || c.back.contains('currency')).toList();
      expect(atpCards.length, lessThanOrEqualTo(1));
    });

    test('Quality gates: multilingual sentence boundary and Unicode tokenization support', () {
      const multilingualDoc = '''
# Multilingual Foundations

La mitochondrie produit la majeure partie de l'adénosine triphosphate de la cellule eucaryote.
Die Zellatmung wandelt biochemische Energie aus Nährstoffen in Adenosintriphosphat um.
La photosynthèse transforme l'énergie lumineuse en molécules de glucides organiques stables.
''';

      final cards = builder.buildCards(multilingualDoc);
      expect(cards, isNotEmpty);
      for (final card in cards) {
        expect(card.front, isNotEmpty);
        expect(card.back, isNotEmpty);
      }
    });
  });
}
