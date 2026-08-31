import 'package:kortex/src/features/syllabot/domain/entities/conversation_session_entity.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';

class ConversationSessionModel {
  const ConversationSessionModel({
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
  final String socraticMode;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ConversationSessionModel.fromJson(Map<String, dynamic> json) {
    return ConversationSessionModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String? ?? 'New Study Session',
      socraticMode: json['socratic_mode'] as String? ?? 'stepByStep',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'socratic_mode': socraticMode,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  ConversationSessionEntity toEntity() {
    return ConversationSessionEntity(
      id: id,
      userId: userId,
      title: title,
      socraticMode: SocraticModeX.fromString(socraticMode),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static ConversationSessionModel fromEntity(ConversationSessionEntity entity) {
    return ConversationSessionModel(
      id: entity.id,
      userId: entity.userId,
      title: entity.title,
      socraticMode: entity.socraticMode.nameString,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }
}
