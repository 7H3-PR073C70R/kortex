import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:kortex/src/core/utils/uuid_utils.dart';
import 'package:kortex/src/features/ingestion/data/models/ocr_extraction_model.dart';
import 'package:kortex/src/features/ingestion/data/services/synthesis/flashcard_synthesizer.dart';
import 'package:kortex/src/features/ingestion/domain/entities/pedagogical_card_schema.dart';

export 'package:kortex/src/features/ingestion/domain/entities/pedagogical_card_schema.dart';

/// Layer 4: Schema Serializer & Validation Engine.
///
/// Enforces pedagogical quality checks:
/// 1. Answer leak prevention in question stem.
/// 2. Non-truncation of thoughts in card backs.
/// 3. Structural validation and formatting for database sync.
/// 4. Deterministic ID generation based on docId + blockId + cognitiveType.
/// 5. Multi-modal assets handling and source provenance embedding.
class SchemaSerializer {
  const SchemaSerializer({Clock? clock})
      : _clock = clock ?? const SystemUtcClock();

  final Clock _clock;

  static const String currentSchemaVersion = '1.0.0';

  static final _danglingTailRegex = RegExp(
    r'\b(?:and|or|to|of|in|for|with|that|which|by|as|you|the|a|an|is|are|be|into|from|relying|using|via|such|their|its)\s*$',
    caseSensitive: false,
  );

  static final _terminalPunctuationRegex = RegExp(
    r'(?:[\.\?!;:}\])"]|```|\$|\)|\|)\s*$',
  );

  /// Strict quality validation pipeline.
  bool _passesValidation(PedagogicalCandidateCard card) {
    final front = card.front.trim();
    final back = card.back.trim();

    // 1. Length & density checks
    if (front.length < 5) return false;
    if (back.length < 3) return false;
    if (back.length < 15 &&
        card.type != CognitiveQuestionType.code &&
        card.type != CognitiveQuestionType.math &&
        card.type != CognitiveQuestionType.yieldResult &&
        card.type != CognitiveQuestionType.location &&
        card.type != CognitiveQuestionType.definition) {
      return false;
    }

    // 2. Truncation check on card back (bypassed for code, math, and structured tables)
    if (card.type != CognitiveQuestionType.code &&
        card.type != CognitiveQuestionType.math &&
        card.type != CognitiveQuestionType.yieldResult &&
        _isTruncated(back)) {
      return false;
    }

    // 3. Answer leak check
    if (_isAnswerLeakedInStem(front, back)) return false;

    return true;
  }

  /// Checks if the card back represents an incomplete, truncated thought.
  bool _isTruncated(String back) {
    if (back.endsWith('-') || back.endsWith(',')) return true;
    if (_danglingTailRegex.hasMatch(back)) return true;
    if (!_terminalPunctuationRegex.hasMatch(back) && !back.contains('\n')) {
      return true;
    }
    return false;
  }

  /// Generates a deterministic UUID-formatted string based on document hash,
  /// block identifier, and pedagogical question type.
  static String generateDeterministicId({
    required String docId,
    required String blockId,
    required String cognitiveType,
  }) {
    final input = '$docId:$blockId:$cognitiveType';
    final digest = sha256.convert(utf8.encode(input)).toString();
    return '${digest.substring(0, 8)}-${digest.substring(8, 12)}-${digest.substring(12, 16)}-${digest.substring(16, 20)}-${digest.substring(20, 32)}';
  }

  /// Validates candidates and emits a structured [PedagogicalDeck].
  PedagogicalDeck serializeDeck({
    required String deckId,
    required String deckTitle,
    required String subject,
    required String category,
    required List<PedagogicalCandidateCard> candidateCards,
  }) {
    final now = _clock.now().toUtc();
    final validatedCards = <PedagogicalCard>[];
    final seenFronts = <String>{};

    for (final candidate in candidateCards) {
      if (!_passesValidation(candidate)) continue;

      // Deduplicate near-identical questions
      final normalizedFront = candidate.front
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (seenFronts.contains(normalizedFront)) continue;
      seenFronts.add(normalizedFront);

      final cognitiveType = _mapCognitiveType(candidate.type);

      // Generate deterministic ID if source has docId & blockId
      final cardId = (candidate.source?.docId != null &&
              candidate.source!.docId.isNotEmpty &&
              candidate.source?.blockId != null &&
              candidate.source!.blockId!.isNotEmpty)
          ? generateDeterministicId(
              docId: candidate.source!.docId,
              blockId: candidate.source!.blockId!,
              cognitiveType: cognitiveType,
            )
          : UuidUtils.generate();

      // Resolve source_topic from hierarchical section path rather than duplicating front text
      final sourceTopic = (candidate.source != null &&
              candidate.source!.sectionPath.isNotEmpty)
          ? candidate.source!.sectionPath.join(' > ')
          : (candidate.sourceTopic.isNotEmpty
              ? candidate.sourceTopic
              : deckTitle);

      // Assemble multi-modal assets
      final assets = List<CardAsset>.from(candidate.assets);
      if (assets.isEmpty) {
        if (candidate.backLatex != null || candidate.frontLatex != null) {
          assets.add(
            CardAsset(
              id: '${cardId}_math',
              type: CardAssetType.latexEquation,
              content: candidate.backLatex ?? candidate.frontLatex!,
            ),
          );
        }
        if (candidate.imageUrl != null) {
          assets.add(
            CardAsset(
              id: '${cardId}_img',
              type: CardAssetType.image,
              content: candidate.imageUrl!,
            ),
          );
        }
      }

      validatedCards.add(
        PedagogicalCard(
          id: cardId,
          deckId: deckId,
          front: candidate.front.trim(),
          back: candidate.back.trim(),
          sourceTopic: sourceTopic,
          cognitiveType: cognitiveType,
          source: candidate.source,
          assets: assets,
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
    final now = _clock.now().toUtc();
    final cards = <PedagogicalCard>[];

    for (final m in models) {
      final cardId = m.id.isNotEmpty ? m.id : UuidUtils.generate();
      final cognitiveType = _inferCognitiveType(m.topic);

      // Infer source metadata if topic contains breadcrumb hierarchy
      CardSource? source;
      if (m.topic.contains(' > ')) {
        source = CardSource(
          docId: m.documentId.isNotEmpty ? m.documentId : deckId,
          page: 1,
          sectionPath:
              m.topic.split(' > ').map((s) => s.trim()).toList(),
          blockId: m.id,
        );
      }

      // Multi-modal assets
      final assets = <CardAsset>[];
      if (m.latexContent != null && m.latexContent!.isNotEmpty) {
        assets.add(
          CardAsset(
            id: '${cardId}_math',
            type: CardAssetType.latexEquation,
            content: m.latexContent!,
          ),
        );
      }
      if (m.imageUrl != null && m.imageUrl!.isNotEmpty) {
        assets.add(
          CardAsset(
            id: '${cardId}_img',
            type: CardAssetType.image,
            content: m.imageUrl!,
          ),
        );
      }

      cards.add(
        PedagogicalCard(
          id: cardId,
          deckId: deckId,
          front: m.topic.trim(),
          back: m.rawText.trim(),
          sourceTopic: source != null
              ? source.sectionPath.join(' > ')
              : m.topic,
          cognitiveType: cognitiveType,
          source: source,
          assets: assets,
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
    if (q.contains('net yield') || q.contains('what does')) {
      return 'yield_result';
    }
    return 'definition';
  }
}
