import 'package:equatable/equatable.dart';

class ThoughtEntry extends Equatable {
  const ThoughtEntry({
    required this.id,
    required this.content,
    required this.createdAt,
    this.sessionId,
    this.deckId,
    this.isResolved = false,
  });

  factory ThoughtEntry.fromJson(Map<String, dynamic> json) {
    return ThoughtEntry(
      id: json['id'] as String,
      content: json['content'] as String,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      sessionId: json['sessionId'] as String?,
      deckId: json['deckId'] as String?,
      isResolved: json['isResolved'] as bool? ?? false,
    );
  }

  final String id;
  final String content;
  final DateTime createdAt;
  final String? sessionId;
  final String? deckId;
  final bool isResolved;

  ThoughtEntry copyWith({
    String? id,
    String? content,
    DateTime? createdAt,
    String? sessionId,
    String? deckId,
    bool? isResolved,
  }) {
    return ThoughtEntry(
      id: id ?? this.id,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      sessionId: sessionId ?? this.sessionId,
      deckId: deckId ?? this.deckId,
      isResolved: isResolved ?? this.isResolved,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'sessionId': sessionId,
      'deckId': deckId,
      'isResolved': isResolved,
    };
  }

  @override
  List<Object?> get props => [
        id,
        content,
        createdAt,
        sessionId,
        deckId,
        isResolved,
      ];
}
