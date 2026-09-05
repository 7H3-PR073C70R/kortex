import 'package:equatable/equatable.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';

class DeckEntity extends Equatable {
  const DeckEntity({
    required this.id,
    required this.title,
    required this.subject,
    required this.totalCards,
    required this.dueCards,
    required this.masteryRate,
    required this.category,
    this.description,
    this.lastStudied,
    this.cards = const [],
    this.colorHex,
    this.iconName,
    this.courseId,
    this.courseCode,
  });

  final String id;
  final String title;
  final String subject;
  final int totalCards;
  final int dueCards;
  final double masteryRate;
  final String category;
  final String? description;
  final DateTime? lastStudied;
  final List<FlashcardEntity> cards;
  final String? colorHex;
  final String? iconName;
  final String? courseId;
  final String? courseCode;

  bool get hasDueCards => dueCards > 0;

  DeckEntity copyWith({
    String? id,
    String? title,
    String? subject,
    int? totalCards,
    int? dueCards,
    double? masteryRate,
    String? category,
    String? description,
    DateTime? lastStudied,
    List<FlashcardEntity>? cards,
    String? colorHex,
    String? iconName,
    String? courseId,
    String? courseCode,
  }) {
    return DeckEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      totalCards: totalCards ?? this.totalCards,
      dueCards: dueCards ?? this.dueCards,
      masteryRate: masteryRate ?? this.masteryRate,
      category: category ?? this.category,
      description: description ?? this.description,
      lastStudied: lastStudied ?? this.lastStudied,
      cards: cards ?? this.cards,
      colorHex: colorHex ?? this.colorHex,
      iconName: iconName ?? this.iconName,
      courseId: courseId ?? this.courseId,
      courseCode: courseCode ?? this.courseCode,
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    subject,
    totalCards,
    dueCards,
    masteryRate,
    category,
    description,
    lastStudied,
    cards,
    colorHex,
    iconName,
    courseId,
    courseCode,
  ];
}
