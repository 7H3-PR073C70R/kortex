import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';

part 'study_session_state.freezed.dart';

enum StudySessionStatus { initial, loading, studying, finished, error }

@freezed
abstract class StudySessionState with _$StudySessionState {
  const factory StudySessionState({
    @Default(StudySessionStatus.initial) StudySessionStatus status,
    @Default('') String deckId,
    @Default([]) List<FlashcardEntity> cards,
    @Default(0) int currentIndex,
    @Default(false) bool isFlipped,
    @Default(0) int correctCount,
    @Default(0) int againCount,
    @Default(0) int hardCount,
    @Default(0) int goodCount,
    @Default(0) int easyCount,
    @Default(0) int elapsedSeconds,
    String? errorMessage,
  }) = _StudySessionState;

  const StudySessionState._();

  FlashcardEntity? get currentCard {
    if (cards.isEmpty || currentIndex >= cards.length) return null;
    return cards[currentIndex];
  }

  int get totalCards => cards.length;
  bool get isLastCard => currentIndex >= cards.length - 1;

  double get progressFactor =>
      totalCards == 0 ? 0.0 : ((currentIndex + 1) / totalCards).clamp(0.0, 1.0);

  double get retentionScore {
    final totalReviewed = againCount + hardCount + goodCount + easyCount;
    if (totalReviewed == 0) return 1;
    final weighted = (hardCount * 0.7) + (goodCount * 1.0) + (easyCount * 1.0);
    return (weighted / totalReviewed).clamp(0.0, 1.0);
  }

  String get formattedElapsedTime {
    final minutes = (elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
