import 'package:equatable/equatable.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';
import 'package:kortex/src/features/decks/domain/entities/focus_session_config.dart';
import 'package:kortex/src/features/decks/domain/entities/thought_entry.dart';

enum FocusSessionStatus {
  initial,
  loading,
  active,
  paused,
  completed,
  error,
}

class FocusSessionState extends Equatable {
  const FocusSessionState({
    this.status = FocusSessionStatus.initial,
    this.deckId = '',
    this.deckTitle = 'Focus Sprint',
    this.cards = const [],
    this.currentIndex = 0,
    this.isFlipped = false,
    this.elapsedSeconds = 0,
    this.remainingSeconds = 0,
    this.config = const FocusSessionConfig(),
    this.parkedThoughts = const [],
    this.streak = 0,
    this.againCount = 0,
    this.hardCount = 0,
    this.goodCount = 0,
    this.easyCount = 0,
    this.correctCount = 0,
    this.ttsSpeaking = false,
    this.errorMessage,
  });

  final FocusSessionStatus status;
  final String deckId;
  final String deckTitle;
  final List<FlashcardEntity> cards;
  final int currentIndex;
  final bool isFlipped;
  final int elapsedSeconds;
  final int remainingSeconds;
  final FocusSessionConfig config;
  final List<ThoughtEntry> parkedThoughts;
  final int streak;
  final int againCount;
  final int hardCount;
  final int goodCount;
  final int easyCount;
  final int correctCount;
  final bool ttsSpeaking;
  final String? errorMessage;

  FlashcardEntity? get currentCard {
    if (cards.isEmpty || currentIndex < 0 || currentIndex >= cards.length) {
      return null;
    }
    return cards[currentIndex];
  }

  bool get isLastCard => cards.isNotEmpty && currentIndex >= cards.length - 1;

  double get progress {
    if (config.type == FocusSessionType.timed) {
      final totalSec = config.targetDurationMinutes * 60;
      if (totalSec <= 0) return 1;
      final elapsed = totalSec - remainingSeconds;
      return (elapsed / totalSec).clamp(0.0, 1.0);
    } else {
      if (cards.isEmpty) return 0;
      return (currentIndex / cards.length).clamp(0.0, 1.0);
    }
  }

  String get timeRemainingFormatted {
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get timeElapsedFormatted {
    final minutes = elapsedSeconds ~/ 60;
    final seconds = elapsedSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  FocusSessionState copyWith({
    FocusSessionStatus? status,
    String? deckId,
    String? deckTitle,
    List<FlashcardEntity>? cards,
    int? currentIndex,
    bool? isFlipped,
    int? elapsedSeconds,
    int? remainingSeconds,
    FocusSessionConfig? config,
    List<ThoughtEntry>? parkedThoughts,
    int? streak,
    int? againCount,
    int? hardCount,
    int? goodCount,
    int? easyCount,
    int? correctCount,
    bool? ttsSpeaking,
    String? errorMessage,
  }) {
    return FocusSessionState(
      status: status ?? this.status,
      deckId: deckId ?? this.deckId,
      deckTitle: deckTitle ?? this.deckTitle,
      cards: cards ?? this.cards,
      currentIndex: currentIndex ?? this.currentIndex,
      isFlipped: isFlipped ?? this.isFlipped,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      config: config ?? this.config,
      parkedThoughts: parkedThoughts ?? this.parkedThoughts,
      streak: streak ?? this.streak,
      againCount: againCount ?? this.againCount,
      hardCount: hardCount ?? this.hardCount,
      goodCount: goodCount ?? this.goodCount,
      easyCount: easyCount ?? this.easyCount,
      correctCount: correctCount ?? this.correctCount,
      ttsSpeaking: ttsSpeaking ?? this.ttsSpeaking,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        deckId,
        deckTitle,
        cards,
        currentIndex,
        isFlipped,
        elapsedSeconds,
        remainingSeconds,
        config,
        parkedThoughts,
        streak,
        againCount,
        hardCount,
        goodCount,
        easyCount,
        correctCount,
        ttsSpeaking,
        errorMessage,
      ];
}
