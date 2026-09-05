import 'package:equatable/equatable.dart';

/// Spaced Repetition Active Recall Deck entity adhering to SM-2 memory
/// retention metrics.
class StudyDeckEntity extends Equatable {
  const StudyDeckEntity({
    required this.id,
    required this.title,
    required this.subject,
    required this.totalCards,
    required this.dueCards,
    required this.retentionRate,
    required this.lastReviewed,
    required this.category,
    this.coverImageUrl,
    this.estimatedMinutes = 10,
    this.colorHex,
    this.courseId,
    this.courseCode,
  });

  final String id;
  final String title;
  final String subject;
  final int totalCards;
  final int dueCards;
  final double retentionRate; // 0.0 to 1.0 (e.g., 0.85 = 85%)
  final DateTime lastReviewed;
  final String category; // STEM, Humanities, Past Paper, Thesis, etc.
  final String? coverImageUrl;
  final int estimatedMinutes;
  final String? colorHex;
  final String? courseId;
  final String? courseCode;

  bool get isDueToday => dueCards > 0;
  double get progressFraction =>
      totalCards > 0 ? (totalCards - dueCards) / totalCards : 0.0;

  @override
  List<Object?> get props => [
    id,
    title,
    subject,
    totalCards,
    dueCards,
    retentionRate,
    lastReviewed,
    category,
    coverImageUrl,
    estimatedMinutes,
    colorHex,
    courseId,
    courseCode,
  ];
}
