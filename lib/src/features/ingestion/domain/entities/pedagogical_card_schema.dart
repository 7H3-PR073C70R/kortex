import 'dart:convert';
import 'package:kortex/src/features/ingestion/data/models/ocr_extraction_model.dart';
import 'package:kortex/src/features/ingestion/domain/entities/document_ir.dart';

/// Clock abstraction for deterministic time generation across card synthesis.
abstract interface class Clock {
  DateTime now();
}

/// Standard system UTC clock.
class SystemUtcClock implements Clock {
  const SystemUtcClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}

/// Frozen deterministic clock for tests and golden assertions.
class FrozenClock implements Clock {
  const FrozenClock(this._fixedUtc);

  final DateTime _fixedUtc;

  @override
  DateTime now() => _fixedUtc;
}

/// Complete provenance context tracking where a pedagogical card originated.
class CardSource {
  const CardSource({
    required this.docId,
    required this.page,
    required this.sectionPath,
    this.bbox,
    this.blockId,
  });

  factory CardSource.fromJson(Map<String, dynamic> json) => CardSource(
    docId: json['doc_id'] as String? ?? '',
    page: json['page'] as int? ?? 1,
    sectionPath: List<String>.from(json['section_path'] as List? ?? []),
    bbox: json['bbox'] != null
        ? BoundingBox.fromJson(json['bbox'] as Map<String, dynamic>)
        : null,
    blockId: json['block_id'] as String?,
  );

  final String docId;
  final int page;
  final List<String> sectionPath;
  final BoundingBox? bbox;
  final String? blockId;

  Map<String, dynamic> toJson() => {
    'doc_id': docId,
    'page': page,
    'section_path': sectionPath,
    if (bbox != null) 'bbox': bbox!.toJson(),
    if (blockId != null) 'block_id': blockId,
  };

  @override
  String toString() =>
      'CardSource(doc: $docId, page: $page, path: ${sectionPath.join(" > ")})';
}

/// The multi-modal category of a card attachment.
enum CardAssetType {
  image,
  diagram,
  latexEquation,
  syntaxCode,
}

/// A multi-modal attachment bound to a card (cropped diagram, formula, or code snippet).
class CardAsset {
  const CardAsset({
    required this.id,
    required this.type,
    required this.content,
    this.label,
    this.mimeType,
    this.metadata = const {},
  });

  factory CardAsset.fromJson(Map<String, dynamic> json) => CardAsset(
    id: json['id'] as String,
    type: CardAssetType.values.firstWhere(
      (t) => t.name == json['type'],
      orElse: () => CardAssetType.image,
    ),
    content: json['content'] as String,
    label: json['label'] as String?,
    mimeType: json['mime_type'] as String?,
    metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
  );

  final String id;
  final CardAssetType type;
  final String content;
  final String? label;
  final String? mimeType;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'content': content,
    if (label != null) 'label': label,
    if (mimeType != null) 'mime_type': mimeType,
    if (metadata.isNotEmpty) 'metadata': metadata,
  };

  @override
  String toString() => 'CardAsset(${type.name}: $id)';
}

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
    this.source,
    this.assets = const [],
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

  factory PedagogicalCard.fromJson(Map<String, dynamic> json) {
    final fsrs = json['fsrs'] as Map<String, dynamic>? ?? {};
    final rawAssets = json['assets'] as List? ?? [];

    return PedagogicalCard(
      id: json['id'] as String,
      deckId: json['deck_id'] as String,
      front: json['front'] as String,
      back: json['back'] as String,
      sourceTopic: json['source_topic'] as String? ?? 'General',
      cognitiveType: json['cognitive_type'] as String? ?? 'definition',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String).toUtc()
          : DateTime.now().toUtc(),
      source: json['source'] != null
          ? CardSource.fromJson(json['source'] as Map<String, dynamic>)
          : null,
      assets: rawAssets
          .map((a) => CardAsset.fromJson(a as Map<String, dynamic>))
          .toList(),
      frontLatex: json['front_latex'] as String?,
      backLatex: json['back_latex'] as String?,
      imageUrl: json['image_url'] as String?,
      confidenceScore:
          (json['confidence_score'] as num?)?.toDouble() ?? 0.95,
      stability: (fsrs['stability'] as num?)?.toDouble() ?? 0.0,
      difficulty: (fsrs['difficulty'] as num?)?.toDouble() ?? 0.0,
      elapsedDays: fsrs['elapsed_days'] as int? ?? 0,
      scheduledDays: fsrs['scheduled_days'] as int? ?? 0,
      lapses: fsrs['lapses'] as int? ?? 0,
      fsrsState: fsrs['state'] as int? ?? 0,
    );
  }

  final String id;
  final String deckId;
  final String front;
  final String back;
  final String sourceTopic;
  final String cognitiveType;
  final DateTime createdAt;
  final CardSource? source;
  final List<CardAsset> assets;
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
      if (source != null) 'source': source!.toJson(),
      if (assets.isNotEmpty) 'assets': assets.map((a) => a.toJson()).toList(),
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

  @override
  String toString() => 'PedagogicalCard($id: "$front")';
}

/// A complete pedagogical deck adhering to PedagogicalDeckSchema.
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

  factory PedagogicalDeck.fromJson(Map<String, dynamic> json) {
    final rawCards = json['cards'] as List? ?? [];
    final cards = rawCards
        .map((c) => PedagogicalCard.fromJson(c as Map<String, dynamic>))
        .toList();

    return PedagogicalDeck(
      schemaVersion: json['schema_version'] as String? ?? '1.0.0',
      deckId: json['deck_id'] as String,
      deckTitle: json['deck_title'] as String,
      subject: json['subject'] as String,
      category: json['category'] as String,
      totalCards: json['total_cards'] as int? ?? cards.length,
      cards: cards,
      generatedAt: json['generated_at'] != null
          ? DateTime.parse(json['generated_at'] as String).toUtc()
          : DateTime.now().toUtc(),
    );
  }

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

  @override
  String toString() =>
      'PedagogicalDeck($deckTitle, $totalCards cards, v$schemaVersion)';
}
