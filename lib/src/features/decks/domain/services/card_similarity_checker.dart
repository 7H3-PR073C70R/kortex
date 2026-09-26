import 'dart:math' as math;
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';

/// Vector / n-gram similarity checker for instant flashcard duplication prevention (DC-15).
class CardSimilarityChecker {
  const CardSimilarityChecker();

  /// Calculates text similarity between 0.0 (completely distinct) and 1.0 (exact match).
  double calculateSimilarity(String text1, String text2) {
    final clean1 = text1.trim().toLowerCase();
    final clean2 = text2.trim().toLowerCase();

    if (clean1 == clean2) return 1;
    if (clean1.isEmpty || clean2.isEmpty) return 0;

    final tokens1 = _tokenize(clean1);
    final tokens2 = _tokenize(clean2);

    final intersection = tokens1.intersection(tokens2).length;
    final union = tokens1.union(tokens2).length;

    if (union == 0) return 0;
    final jaccard = intersection / union;

    final distance = _levenshteinDistance(clean1, clean2);
    final maxLength = math.max(clean1.length, clean2.length);
    final levenshteinSim = 1.0 - (distance / maxLength);

    return (0.6 * jaccard) + (0.4 * levenshteinSim);
  }

  /// Checks if a proposed card question is a potential duplicate of existing cards in the deck.
  FlashcardEntity? findDuplicate({
    required String question,
    required List<FlashcardEntity> existingCards,
    double threshold = 0.80,
  }) {
    for (final card in existingCards) {
      final sim = calculateSimilarity(question, card.front);
      if (sim >= threshold) {
        return card;
      }
    }
    return null;
  }

  Set<String> _tokenize(String text) {
    return RegExp(r'\w+')
        .allMatches(text)
        .map((m) => m.group(0)!)
        .where((t) => t.length >= 2)
        .toSet();
  }

  int _levenshteinDistance(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    final v0 = List<int>.filled(t.length + 1, 0);
    final v1 = List<int>.filled(t.length + 1, 0);

    for (var i = 0; i <= t.length; i++) {
      v0[i] = i;
    }

    for (var i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (var j = 0; j < t.length; j++) {
        final cost = (s[i] == t[j]) ? 0 : 1;
        v1[j + 1] = math.min(
          v1[j] + 1,
          math.min(v0[j + 1] + 1, v0[j] + cost),
        );
      }
      for (var j = 0; j <= t.length; j++) {
        v0[j] = v1[j];
      }
    }

    return v1[t.length];
  }
}
