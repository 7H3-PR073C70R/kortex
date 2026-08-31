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
    this.topic = 'General',
  });

  final String front;
  final String back;
  final String? frontLatex;
  final String? backLatex;
  final String topic;

  GeneratedCardPreviewItem copyWith({
    String? front,
    String? back,
    String? frontLatex,
    String? backLatex,
    String? topic,
  }) {
    return GeneratedCardPreviewItem(
      front: front ?? this.front,
      back: back ?? this.back,
      frontLatex: frontLatex ?? this.frontLatex,
      backLatex: backLatex ?? this.backLatex,
      topic: topic ?? this.topic,
    );
  }
}
