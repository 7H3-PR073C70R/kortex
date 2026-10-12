import 'package:flutter/foundation.dart';

/// In-memory representation of an uncommitted flashcard during deck creation.
@immutable
class DraftCard {
  const DraftCard({required this.front, required this.back});

  final String front;
  final String back;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DraftCard &&
          runtimeType == other.runtimeType &&
          front == other.front &&
          back == other.back;

  @override
  int get hashCode => Object.hash(front, back);
}
