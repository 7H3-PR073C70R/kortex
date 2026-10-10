import 'package:kortex/src/features/ingestion/domain/entities/pedagogical_card_schema.dart';

class GeneratedDeckPreviewModel {
  const GeneratedDeckPreviewModel({
    required this.deckTitle,
    required this.subject,
    required this.cards,
  });

  final String deckTitle;
  final String subject;
  final List<GeneratedCardPreviewItem> cards;
}

class GeneratedCardPreviewItem {
  const GeneratedCardPreviewItem({
    required this.front,
    required this.back,
    this.frontLatex,
    this.backLatex,
    this.imageUrl,
    this.topic = 'General',
    this.sourceCitation,
    this.confidenceScore = 0.95,
    this.source,
    this.cognitiveType = 'definition',
  });

  final String front;
  final String back;
  final String? frontLatex;
  final String? backLatex;
  final String? imageUrl;
  final String topic;
  final String? sourceCitation;
  final double confidenceScore;
  final CardSource? source;
  final String cognitiveType;

  /// Formatted citation string (e.g. `p. 14 · §8.3` or explicit citation).
  String get effectiveCitation {
    if (sourceCitation != null && sourceCitation!.trim().isNotEmpty) {
      return sourceCitation!.trim();
    }
    if (source != null) {
      final pageStr = 'p. ${source!.page}';
      if (source!.sectionPath.isNotEmpty) {
        final sec = source!.sectionPath.last.replaceFirst(RegExp(r'^(?:Section|Chapter|§)\s*', caseSensitive: false), '§');
        final formattedSec = sec.startsWith('§') ? sec : '§$sec';
        return '$pageStr · $formattedSec';
      }
      return pageStr;
    }
    return '';
  }

  /// Whether this card has low extraction confidence and requires user review.
  bool get needsReview => confidenceScore < 0.85;

  GeneratedCardPreviewItem copyWith({
    String? front,
    String? back,
    String? frontLatex,
    String? backLatex,
    String? imageUrl,
    String? topic,
    String? sourceCitation,
    double? confidenceScore,
    CardSource? source,
    String? cognitiveType,
  }) {
    return GeneratedCardPreviewItem(
      front: front ?? this.front,
      back: back ?? this.back,
      frontLatex: frontLatex ?? this.frontLatex,
      backLatex: backLatex ?? this.backLatex,
      imageUrl: imageUrl ?? this.imageUrl,
      topic: topic ?? this.topic,
      sourceCitation: sourceCitation ?? this.sourceCitation,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      source: source ?? this.source,
      cognitiveType: cognitiveType ?? this.cognitiveType,
    );
  }
}
