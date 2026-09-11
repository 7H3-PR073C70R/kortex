import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/utils/use_case.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/domain/use_cases/delete_deck_use_case.dart';
import 'package:kortex/src/features/decks/domain/use_cases/get_user_decks_use_case.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_event.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_state.dart';

class DecksBloc extends Bloc<DecksEvent, DecksState> {
  DecksBloc({
    required GetUserDecksUseCase getUserDecksUseCase,
    DeleteDeckUseCase? deleteDeckUseCase,
  }) : _getUserDecksUseCase = getUserDecksUseCase,
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
    final updatedAll = state.allDecks
        .where((d) => d.id != event.deckId)
        .toList();
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

    if (locator.isRegistered<DashboardBloc>()) {
      locator<DashboardBloc>().add(DashboardDeckDeleted(event.deckId));
    }

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

    // Sort decks according to due date:
    // 1. Decks with dueCards > 0 come first.
    // 2. Among due decks, sort by highest due count descending.
    // 3. For upcoming non-due decks, sort by earliest nextDueDate ascending.
    // 4. Stable fallback: lastStudied or title.
    list.sort((a, b) {
      final aDue = a.dueCards > 0;
      final bDue = b.dueCards > 0;

      if (aDue && !bDue) return -1;
      if (!aDue && bDue) return 1;

      if (aDue && bDue) {
        final countCmp = b.dueCards.compareTo(a.dueCards);
        if (countCmp != 0) return countCmp;
      }

      final aEarliest = _findEarliestDueDate(a);
      final bEarliest = _findEarliestDueDate(b);

      if (aEarliest != null && bEarliest != null) {
        final dateCmp = aEarliest.compareTo(bEarliest);
        if (dateCmp != 0) return dateCmp;
      } else if (aEarliest != null) {
        return -1;
      } else if (bEarliest != null) {
        return 1;
      }

      if (a.lastStudied != null && b.lastStudied != null) {
        return b.lastStudied!.compareTo(a.lastStudied!);
      } else if (a.lastStudied != null) {
        return -1;
      } else if (b.lastStudied != null) {
        return 1;
      }

      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });

    return list;
  }

  DateTime? _findEarliestDueDate(DeckEntity deck) {
    DateTime? earliest;
    for (final card in deck.cards) {
      if (card.nextDueDate != null) {
        if (earliest == null || card.nextDueDate!.isBefore(earliest)) {
          earliest = card.nextDueDate;
        }
      }
    }
    return earliest;
  }
}
