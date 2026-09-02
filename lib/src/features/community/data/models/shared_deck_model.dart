import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';
import 'package:kortex/src/features/community/domain/entities/shared_deck_entity.dart';

class SharedDeckModel {
  const SharedDeckModel({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.title,
    required this.subject,
    this.description,
    this.category = 'General',
    required this.totalCards,
    this.downloadsCount = 0,
    this.rating = 4.8,
    this.cards = const [],
    this.originalDeckId,
  });

  final String id;
  final String ownerId;
  final String ownerName;
  final String title;
  final String subject;
  final String? description;
  final String category;
  final int totalCards;
  final int downloadsCount;
  final double rating;
  final List<Map<String, dynamic>> cards;
  final String? originalDeckId;

  factory SharedDeckModel.fromJson(Map<String, dynamic> json) {
    final rawCards = json['cards'] as List<dynamic>? ?? [];
    return SharedDeckModel(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String? ?? '',
      ownerName: json['owner_name'] as String? ?? 'Community Educator',
      title: json['title'] as String,
      subject: json['subject'] as String,
      description: json['description'] as String?,
      category: json['category'] as String? ?? 'General',
      totalCards: (json['total_cards'] as num?)?.toInt() ?? rawCards.length,
      downloadsCount: (json['downloads_count'] as num?)?.toInt() ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 4.8,
      cards: rawCards.cast<Map<String, dynamic>>(),
      originalDeckId: json['original_deck_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'owner_id': ownerId,
      'owner_name': ownerName,
      'title': title,
      'subject': subject,
      'description': description,
      'category': category,
      'total_cards': totalCards,
      'downloads_count': downloadsCount,
      'rating': rating,
      'cards': cards,
      'original_deck_id': originalDeckId,
    };
  }

  SharedDeckEntity toEntity() {
    final parsedCards = cards.map((c) {
      return FlashcardEntity(
        id: c['id'] as String? ?? 'card_${c.hashCode}',
        deckId: id,
        front: c['front'] as String? ?? '',
        back: c['back'] as String? ?? '',
        frontLatex: c['front_latex'] as String?,
        backLatex: c['back_latex'] as String?,
        nextDueDate: DateTime.now(),
      );
    }).toList();

    return SharedDeckEntity(
      id: id,
      ownerId: ownerId,
      ownerName: ownerName,
      title: title,
      subject: subject,
      description: description,
      category: category,
      totalCards: totalCards,
      downloadsCount: downloadsCount,
      rating: rating,
      cards: parsedCards,
      originalDeckId: originalDeckId,
    );
  }
}
