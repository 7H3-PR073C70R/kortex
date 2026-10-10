// ignore_for_file: avoid_print, document_ignores

import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/ingestion/data/services/offline_card_builder.dart';

void main() {
  const builder = OfflineCardBuilder();

  final testSentences = [
    'Oracle America develops enterprise database software.',
    'The primary engineering challenge is to maintain zero-latency caching.',
    'The take-home project evaluates distributed systems architecture.',
    'The independent contractor must implement the client requirements.',
    'The university is located on Oxford Street in Cambridge.',
    'Lagos is the commercial financial center of West Africa.',
    'Professor Oyebode established the foundational jurisprudence curriculum.',
    'Nigeria is the most populous country on the African continent.',
    'The statutory registration fee is N850 per annual filing.',
    'The Supreme Court possesses exclusive constitutional jurisdiction.',
    'A competitive salary is offered for senior software engineering positions.',
    'The housing allowance is distributed at the end of each fiscal quarter.',
    'Strict confidentiality protects proprietary neural network model weights.',
    'The master services agreement defines service level guarantees.',
    'Financial regulation ensures transparency in algorithmic trading markets.',
  ];

  test('all 15 benchmark sentences produce cards', () {
    for (var i = 0; i < testSentences.length; i++) {
      final s = testSentences[i];
      final cards = builder.buildCards(s);
      print('Sentence ${i + 1}: "$s" -> ${cards.length} cards');
      for (final c in cards) {
        print('   [${c.type.name}] Q: ${c.front} | A: ${c.back}');
      }
      expect(cards, isNotEmpty, reason: 'Sentence ${i + 1} ("$s") must produce a card');
    }
  });
}
