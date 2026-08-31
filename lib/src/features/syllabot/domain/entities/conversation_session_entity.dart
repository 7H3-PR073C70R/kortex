import 'package:equatable/equatable.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';

/// Domain entity representing a persistent conversation thread in Syllabot AI.
class ConversationSessionEntity extends Equatable {
  const ConversationSessionEntity({
    required this.id,
    required this.userId,
    required this.title,
    required this.socraticMode,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String title;
  final SocraticMode socraticMode;
  final DateTime createdAt;
  final DateTime updatedAt;

  ConversationSessionEntity copyWith({
    String? id,
    String? userId,
    String? title,
    SocraticMode? socraticMode,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ConversationSessionEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      socraticMode: socraticMode ?? this.socraticMode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        title,
        socraticMode,
        createdAt,
        updatedAt,
      ];
}
