import 'package:equatable/equatable.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';

/// Represents a published community marketplace flashcard deck.
class SharedDeckEntity extends Equatable {
  const SharedDeckEntity({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.title,
    required this.subject,
    required this.totalCards,
    this.description,
    this.category = 'General',
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
  final List<FlashcardEntity> cards;
  final String? originalDeckId;

  SharedDeckEntity copyWith({
    String? id,
    String? ownerId,
    String? ownerName,
    String? title,
    String? subject,
    String? description,
    String? category,
    int? totalCards,
    int? downloadsCount,
    double? rating,
    List<FlashcardEntity>? cards,
    String? originalDeckId,
  }) {
    return SharedDeckEntity(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      ownerName: ownerName ?? this.ownerName,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      description: description ?? this.description,
      category: category ?? this.category,
      totalCards: totalCards ?? this.totalCards,
      downloadsCount: downloadsCount ?? this.downloadsCount,
      rating: rating ?? this.rating,
      cards: cards ?? this.cards,
      originalDeckId: originalDeckId ?? this.originalDeckId,
    );
  }

  @override
  List<Object?> get props => [
    id,
    ownerId,
    ownerName,
    title,
    subject,
    description,
    category,
    totalCards,
    downloadsCount,
    rating,
    cards,
    originalDeckId,
  ];
}
