import 'package:equatable/equatable.dart';

enum RecommendationType {
  pastPapers,
  flashcards,
  socraticAi,
}

class RecommendedContentItem extends Equatable {
  const RecommendedContentItem({
    required this.id,
    required this.type,
    required this.badge,
    required this.tagline,
    required this.description,
    required this.formulaChips,
  });

  final String id;
  final RecommendationType type;
  final String badge;
  final String tagline;
  final String description;
  final List<String> formulaChips;

  @override
  List<Object?> get props => [
        id,
        type,
        badge,
        tagline,
        description,
        formulaChips,
      ];
}
