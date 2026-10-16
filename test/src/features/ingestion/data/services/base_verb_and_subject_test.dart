import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/ingestion/data/services/offline_card_builder.dart';

void main() {
  const builder = OfflineCardBuilder();

  group('Task 0.3: _toBaseVerb and _resolveSubject Tests', () {
    test('_toBaseVerb never mangles protected word endings', () {
      // Problem words flagged in user audit:
      expect(builder.toBaseVerbForTesting('this'), equals('this'));
      expect(builder.toBaseVerbForTesting('class'), equals('class'));
      expect(builder.toBaseVerbForTesting('process'), equals('process'));
      expect(builder.toBaseVerbForTesting('access'), equals('access'));
      expect(builder.toBaseVerbForTesting('malicious'), equals('malicious'));
      expect(builder.toBaseVerbForTesting('status'), equals('status'));

      // Additional protected words:
      expect(builder.toBaseVerbForTesting('analysis'), equals('analysis'));
      expect(builder.toBaseVerbForTesting('basis'), equals('basis'));
      expect(builder.toBaseVerbForTesting('focus'), equals('focus'));
      expect(builder.toBaseVerbForTesting('continuous'), equals('continuous'));
      expect(builder.toBaseVerbForTesting('pass'), equals('pass'));

      // Legitimate verb inflections properly converted to base form:
      expect(builder.toBaseVerbForTesting('processes'), equals('process'));
      expect(builder.toBaseVerbForTesting('accesses'), equals('access'));
      expect(builder.toBaseVerbForTesting('passes'), equals('pass'));
      expect(builder.toBaseVerbForTesting('catches'), equals('catch'));
      expect(builder.toBaseVerbForTesting('fixes'), equals('fix'));
      expect(builder.toBaseVerbForTesting('carries'), equals('carry'));
      expect(builder.toBaseVerbForTesting('applies'), equals('apply'));
      expect(builder.toBaseVerbForTesting('creates'), equals('create'));
      expect(builder.toBaseVerbForTesting('converts'), equals('convert'));
      expect(builder.toBaseVerbForTesting('contains'), equals('contain'));

      // Irregular verbs:
      expect(builder.toBaseVerbForTesting('has'), equals('have'));
      expect(builder.toBaseVerbForTesting('does'), equals('do'));
      expect(builder.toBaseVerbForTesting('goes'), equals('go'));
    });

    test('_resolveSubject rejects clause subjects, subordinators, and commas', () {
      // Subordinators and condition clauses (the 74/364 broken "How does" cards)
      expect(builder.resolveSubjectForTesting('If you need', null), isNull);
      expect(builder.resolveSubjectForTesting('When an error occurs', null), isNull);
      expect(builder.resolveSubjectForTesting('Because threads share memory', null), isNull);
      expect(builder.resolveSubjectForTesting('Although the process runs', null), isNull);
      expect(builder.resolveSubjectForTesting('Since components communicate', null), isNull);
      expect(builder.resolveSubjectForTesting('While processing data', null), isNull);
      expect(builder.resolveSubjectForTesting('Unless configured otherwise', null), isNull);

      // Prepositional phrases
      expect(builder.resolveSubjectForTesting('In Flutter', null), isNull);
      expect(builder.resolveSubjectForTesting('For each isolate', null), isNull);
      expect(builder.resolveSubjectForTesting('With standard settings', null), isNull);

      // Subjects containing commas
      expect(builder.resolveSubjectForTesting('In Flutter, the widget', null), isNull);
      expect(builder.resolveSubjectForTesting('Normally, garbage collection', null), isNull);

      // Subjects running past 6 words
      expect(
        builder.resolveSubjectForTesting('If you need access from one feature to another', null),
        isNull,
      );

      // Subjects containing clause verbs
      expect(builder.resolveSubjectForTesting('You need access', null), isNull);
      expect(builder.resolveSubjectForTesting('Developers should verify', null), isNull);
      expect(builder.resolveSubjectForTesting('Users must configure', null), isNull);

      // Valid pedagogical noun phrase subjects properly accepted
      expect(builder.resolveSubjectForTesting('Garbage Collector', null), equals('Garbage Collector'));
      expect(builder.resolveSubjectForTesting('The Garbage Collector', null), equals('Garbage Collector'));
      expect(builder.resolveSubjectForTesting('Flutter Framework', null), equals('Flutter Framework'));
      expect(builder.resolveSubjectForTesting('A compiler', null), equals('compiler'));
      expect(builder.resolveSubjectForTesting('State management architecture', null), equals('State management architecture'));
    });

    test('How does card generation does not emit mangled stems or clause subjects', () {
      const input = '''
# Architecture Overview

If you need access from one feature to another by using a shared module, you should import it.

When an error is detected by the supervisor via heartbeats, it restarts.

The Garbage Collector reclaims memory by traversing the object graph.

Flutter manages widgets by using an element tree.
''';

      final cards = builder.buildCards(input);
      
      // Ensure no mangled words in any card front
      final mangledWords = ['thi', 'clas', 'proces', 'acces', 'maliciou', 'statu'];
      for (final card in cards) {
        final lower = card.front.toLowerCase();
        for (final m in mangledWords) {
          final wordRegex = RegExp('\\b${RegExp.escape(m)}\\b');
          expect(
            wordRegex.hasMatch(lower),
            isFalse,
            reason: 'Card front should not contain mangled word "$m": "${card.front}"',
          );
        }

        // Ensure "How does" does not have clause subjects
        if (card.front.startsWith('How does ')) {
          final afterHowDoes = card.front.substring('How does '.length);
          final firstWord = afterHowDoes.split(RegExp(r'\s+')).first.toLowerCase();
          expect(
            ['if', 'when', 'because', 'although', 'since', 'while', 'unless', 'in', 'for', 'with'].contains(firstWord),
            isFalse,
            reason: 'How does stem should not start with clause marker: "${card.front}"',
          );
        }
      }

      // Valid cards should still be produced
      expect(cards.any((c) => c.front.contains('Garbage Collector')), isTrue);
      expect(cards.any((c) => c.front.contains('Flutter')), isTrue);
    });
  });
}
