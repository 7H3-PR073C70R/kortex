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
  });

  final String front;
  final String back;
  final String? frontLatex;
  final String? backLatex;
  final String? imageUrl;
  final String topic;

  GeneratedCardPreviewItem copyWith({
    String? front,
    String? back,
    String? frontLatex,
    String? backLatex,
    String? imageUrl,
    String? topic,
  }) {
    return GeneratedCardPreviewItem(
      front: front ?? this.front,
      back: back ?? this.back,
      frontLatex: frontLatex ?? this.frontLatex,
      backLatex: backLatex ?? this.backLatex,
      imageUrl: imageUrl ?? this.imageUrl,
      topic: topic ?? this.topic,
    );
  }
}
