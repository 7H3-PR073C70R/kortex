import 'dart:convert';
import 'package:kortex/src/core/utils/uuid_utils.dart';
import 'package:kortex/src/features/ingestion/data/models/ocr_extraction_model.dart';
import 'package:kortex/src/features/ingestion/data/services/synthesis/flashcard_synthesizer.dart';

/// A validated pedagogical card adhering strictly to the database/sync schema.
class PedagogicalCard {
  const PedagogicalCard({
    required this.id,
    required this.deckId,
    required this.front,
    required this.back,
    required this.sourceTopic,
    required this.cognitiveType,
    required this.createdAt,
    this.frontLatex,
    this.backLatex,
    this.imageUrl,
    this.confidenceScore = 0.95,
    this.stability = 0.0,
    this.difficulty = 0.0,
    this.elapsedDays = 0,
    this.scheduledDays = 0,
    this.lapses = 0,
    this.fsrsState = 0,
  });

  final String id;
  final String deckId;
  final String front;
  final String back;
  final String sourceTopic;
  final String cognitiveType;
  final String? frontLatex;
  final String? backLatex;
  final String? imageUrl;
  final double confidenceScore;

  // Native FSRS-6 scheduling fields
  final double stability;
  final double difficulty;
  final int elapsedDays;
  final int scheduledDays;
  final int lapses;
  final int fsrsState;
  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deck_id': deckId,
      'front': front,
      'back': back,
      'front_latex': frontLatex,
      'back_latex': backLatex,
      'image_url': imageUrl,
      'source_topic': sourceTopic,
      'cognitive_type': cognitiveType,
      'confidence_score': confidenceScore,
      'fsrs': {
        'stability': stability,
        'difficulty': difficulty,
        'elapsed_days': elapsedDays,
        'scheduled_days': scheduledDays,
        'lapses': lapses,
        'state': fsrsState,
      },
      'created_at': createdAt.toIso8601String(),
    };
  }

  OcrExtractionModel toExtractionModel() {
    return OcrExtractionModel(
      id: id,
      documentId: deckId,
      topic: front,
      rawText: back,
      latexContent: backLatex ?? frontLatex,
      imageUrl: imageUrl,
      confidenceScore: confidenceScore,
    );
  }
}

/// A complete pedagogical deck adhering to the PedagogicalDeckSchema.
class PedagogicalDeck {
  const PedagogicalDeck({
    required this.schemaVersion,
    required this.deckId,
    required this.deckTitle,
    required this.subject,
    required this.category,
    required this.totalCards,
    required this.cards,
    required this.generatedAt,
  });

  final String schemaVersion;
  final String deckId;
  final String deckTitle;
  final String subject;
  final String category;
  final int totalCards;
  final List<PedagogicalCard> cards;
  final DateTime generatedAt;

  Map<String, dynamic> toJson() {
    return {
      'schema_version': schemaVersion,
      'deck_id': deckId,
      'deck_title': deckTitle,
      'subject': subject,
      'category': category,
      'total_cards': totalCards,
      'generated_at': generatedAt.toIso8601String(),
      'cards': cards.map((c) => c.toJson()).toList(),
    };
  }

  String toPrettyJson() {
    return const JsonEncoder.withIndent('  ').convert(toJson());
  }

  List<OcrExtractionModel> toExtractionModels() {
    return cards.map((c) => c.toExtractionModel()).toList();
  }
}

/// Layer 4: Schema Serializer & Validation Engine.
///
/// Enforces pedagogical quality checks:
/// 1. Answer leak prevention in question stem.
/// 2. Non-truncation of thoughts in card backs.
/// 3. Structural validation and formatting for database sync.
class SchemaSerializer {
  const SchemaSerializer();

  static const String currentSchemaVersion = '1.0.0';

  static final _danglingTailRegex = RegExp(
    r'\b(?:and|or|to|of|in|for|with|that|which|by|as|you|the|a|an|is|are|be|into|from|relying|using|via|such|their|its)\s*$',
    caseSensitive: false,
  );

  static final _terminalPunctuationRegex = RegExp(
    r'(?:[\.\?!;:]|```|\$|\))\s*$',
  );

  /// Validates candidates and emits a structured [PedagogicalDeck].
  PedagogicalDeck serializeDeck({
    required String deckId,
    required String deckTitle,
    required String subject,
    required String category,
    required List<PedagogicalCandidateCard> candidateCards,
  }) {
    final now = DateTime.now();
    final validatedCards = <PedagogicalCard>[];
    final seenFronts = <String>{};

    for (final candidate in candidateCards) {
      if (!_passesValidation(candidate)) continue;

      // Deduplicate near-identical questions
      final normalizedFront = candidate.front.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
      if (seenFronts.contains(normalizedFront)) continue;
      seenFronts.add(normalizedFront);

      validatedCards.add(
        PedagogicalCard(
          id: UuidUtils.generate(),
          deckId: deckId,
          front: candidate.front.trim(),
          back: candidate.back.trim(),
          sourceTopic: candidate.sourceTopic,
          cognitiveType: _mapCognitiveType(candidate.type),
          frontLatex: candidate.frontLatex,
          backLatex: candidate.backLatex,
          imageUrl: candidate.imageUrl,
          confidenceScore: candidate.confidenceScore,
          createdAt: now,
        ),
      );
    }

    return PedagogicalDeck(
      schemaVersion: currentSchemaVersion,
      deckId: deckId,
      deckTitle: deckTitle,
      subject: subject,
      category: category,
      totalCards: validatedCards.length,
      cards: validatedCards,
      generatedAt: now,
    );
  }

  /// Converts a list of [OcrExtractionModel]s into a verified [PedagogicalDeck].
  PedagogicalDeck fromExtractionModels({
    required String deckId,
    required String deckTitle,
    required String subject,
    required String category,
    required List<OcrExtractionModel> models,
  }) {
    final now = DateTime.now();
    final cards = <PedagogicalCard>[];

    for (final m in models) {
      cards.add(
        PedagogicalCard(
          id: m.id.isNotEmpty ? m.id : UuidUtils.generate(),
          deckId: deckId,
          front: m.topic.trim(),
          back: m.rawText.trim(),
          sourceTopic: m.topic,
          cognitiveType: _inferCognitiveType(m.topic),
          createdAt: now,
          backLatex: m.latexContent,
          imageUrl: m.imageUrl,
          confidenceScore: m.confidenceScore,
        ),
      );
    }

    return PedagogicalDeck(
      schemaVersion: currentSchemaVersion,
      deckId: deckId,
      deckTitle: deckTitle,
      subject: subject,
      category: category,
      totalCards: cards.length,
      cards: cards,
      generatedAt: now,
    );
  }

  /// Strict quality validation pipeline.
  bool _passesValidation(PedagogicalCandidateCard card) {
    final front = card.front.trim();
    final back = card.back.trim();

    // 1. Length & density checks
    if (front.length < 10) return false;
    if (back.length < 15 && card.type != CognitiveQuestionType.code && card.type != CognitiveQuestionType.math) {
      return false;
    }

    // 2. Truncation check on card back
    if (_isTruncated(back)) return false;

    // 3. Answer leak check
    if (_isAnswerLeakedInStem(front, back)) return false;

    return true;
  }

  /// Checks if the card back represents an incomplete, truncated thought.
  bool _isTruncated(String back) {
    if (back.endsWith('-') || back.endsWith(',')) return true;
    if (_danglingTailRegex.hasMatch(back)) return true;
    if (!_terminalPunctuationRegex.hasMatch(back)) return true;
    return false;
  }

  /// Validates that the answer predicate is not leaked in the question stem.
  bool _isAnswerLeakedInStem(String front, String back) {
    final fLower = front.toLowerCase();
    final bLower = back.toLowerCase();

    // If question is asking "What does [Subject] [Verb]?", it should not contain the direct object
    if (fLower.startsWith('what does') || fLower.startsWith('what do')) {
      final questionWords = fLower
          .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
          .split(' ')
          .where((w) => w.length > 3)
          .toSet();

      final answerWords = bLower
          .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
          .split(' ')
          .where((w) => w.length > 3)
          .toSet();

      if (questionWords.isEmpty || answerWords.isEmpty) return false;
      final overlap = questionWords.intersection(answerWords);

      // If the question contains almost the entire answer, it is a leak
      if (overlap.length >= answerWords.length && answerWords.length <= 4) {
        return true;
      }
    }

    return false;
  }

  String _mapCognitiveType(CognitiveQuestionType type) {
    switch (type) {
      case CognitiveQuestionType.causality:
        return 'causality';
      case CognitiveQuestionType.mechanism:
        return 'mechanism';
      case CognitiveQuestionType.stateTransition:
        return 'state_transition';
      case CognitiveQuestionType.svo:
        return 'svo';
      case CognitiveQuestionType.definition:
        return 'definition';
      case CognitiveQuestionType.ebnf:
        return 'ebnf';
      case CognitiveQuestionType.code:
        return 'code';
      case CognitiveQuestionType.math:
        return 'math';
      case CognitiveQuestionType.location:
        return 'location';
      case CognitiveQuestionType.yieldResult:
        return 'yield_result';
    }
  }

  String _inferCognitiveType(String question) {
    final q = question.toLowerCase();
    if (q.startsWith('why')) return 'causality';
    if (q.startsWith('how')) return 'mechanism';
    if (q.contains('what happens when')) return 'state_transition';
    if (q.contains('syntax specification')) return 'ebnf';
    if (q.contains('code structure')) return 'code';
    if (q.contains('mathematical formulation')) return 'math';
    if (q.startsWith('where')) return 'location';
    if (q.contains('net yield') || q.contains('what does')) return 'yield_result';
    return 'definition';
  }
}
