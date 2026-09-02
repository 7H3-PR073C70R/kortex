import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/utils/use_case.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/domain/use_cases/delete_deck_use_case.dart';
import 'package:kortex/src/features/decks/domain/use_cases/get_user_decks_use_case.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_event.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_state.dart';

class DecksBloc extends Bloc<DecksEvent, DecksState> {
  DecksBloc({
    required GetUserDecksUseCase getUserDecksUseCase,
    DeleteDeckUseCase? deleteDeckUseCase,
  })  : _getUserDecksUseCase = getUserDecksUseCase,
        _deleteDeckUseCase = deleteDeckUseCase,
        super(const DecksState()) {
    on<DecksStarted>(_onDecksStarted);
    on<DecksRefreshed>(_onDecksRefreshed);
    on<DecksFilterChanged>(_onDecksFilterChanged);
    on<DecksSearchQueryChanged>(_onDecksSearchQueryChanged);
    on<DecksDeckDeleted>(_onDeckDeleted);
  }

  final GetUserDecksUseCase _getUserDecksUseCase;
  final DeleteDeckUseCase? _deleteDeckUseCase;

  Future<void> _onDeckDeleted(
    DecksDeckDeleted event,
    Emitter<DecksState> emit,
  ) async {
    final updatedAll = state.allDecks.where((d) => d.id != event.deckId).toList();
    emit(
      state.copyWith(
        allDecks: updatedAll,
        filteredDecks: _applyFilterAndSearch(
          updatedAll,
          state.activeFilter,
          state.searchQuery,
        ),
      ),
    );

    if (_deleteDeckUseCase != null) {
      await _deleteDeckUseCase(event.deckId);
    }
  }

  Future<void> _onDecksStarted(
    DecksStarted event,
    Emitter<DecksState> emit,
  ) async {
    emit(state.copyWith(status: DecksStatus.loading));
    final result = await _getUserDecksUseCase(const NoParams());

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: DecksStatus.error,
          errorMessage: failure.message,
        ),
      ),
      (decks) {
        emit(
          state.copyWith(
            status: DecksStatus.loaded,
            allDecks: decks,
            filteredDecks: _applyFilterAndSearch(
              decks,
              state.activeFilter,
              state.searchQuery,
            ),
          ),
        );
      },
    );
  }

  Future<void> _onDecksRefreshed(
    DecksRefreshed event,
    Emitter<DecksState> emit,
  ) async {
    final result = await _getUserDecksUseCase(const NoParams());

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: DecksStatus.error,
          errorMessage: failure.message,
        ),
      ),
      (decks) {
        emit(
          state.copyWith(
            status: DecksStatus.loaded,
            allDecks: decks,
            filteredDecks: _applyFilterAndSearch(
              decks,
              state.activeFilter,
              state.searchQuery,
            ),
          ),
        );
      },
    );
  }

  void _onDecksFilterChanged(
    DecksFilterChanged event,
    Emitter<DecksState> emit,
  ) {
    final updatedFiltered = _applyFilterAndSearch(
      state.allDecks,
      event.filter,
      state.searchQuery,
    );
    emit(
      state.copyWith(
        activeFilter: event.filter,
        filteredDecks: updatedFiltered,
      ),
    );
  }

  void _onDecksSearchQueryChanged(
    DecksSearchQueryChanged event,
    Emitter<DecksState> emit,
  ) {
    final updatedFiltered = _applyFilterAndSearch(
      state.allDecks,
      state.activeFilter,
      event.query,
    );
    emit(
      state.copyWith(
        searchQuery: event.query,
        filteredDecks: updatedFiltered,
      ),
    );
  }

  List<DeckEntity> _applyFilterAndSearch(
    List<DeckEntity> decks,
    String filter,
    String query,
  ) {
    var list = List<DeckEntity>.from(decks);

    // Apply Filter Tab
    if (filter == 'due') {
      list = list.where((d) => d.dueCards > 0).toList();
    } else if (filter == 'mastered') {
      list = list.where((d) => d.masteryRate >= 0.90).toList();
    }

    // Apply Search Query
    if (query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      list = list.where((d) {
        return d.title.toLowerCase().contains(q) ||
            d.subject.toLowerCase().contains(q) ||
            d.category.toLowerCase().contains(q);
      }).toList();
    }

    return list;
  }
}
