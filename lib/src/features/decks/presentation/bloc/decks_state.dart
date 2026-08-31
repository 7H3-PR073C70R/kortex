import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';

part 'decks_state.freezed.dart';

enum DecksStatus { initial, loading, loaded, error }

@freezed
abstract class DecksState with _$DecksState {
  const factory DecksState({
    @Default(DecksStatus.initial) DecksStatus status,
    @Default([]) List<DeckEntity> allDecks,
    @Default([]) List<DeckEntity> filteredDecks,
    @Default('all') String activeFilter,
    @Default('') String searchQuery,
    String? errorMessage,
  }) = _DecksState;

  const DecksState._();

  bool get isLoading => status == DecksStatus.loading;
  bool get isLoaded => status == DecksStatus.loaded;
  bool get isError => status == DecksStatus.error;

  int get totalDueCards =>
      allDecks.fold<int>(0, (sum, deck) => sum + deck.dueCards);
}
