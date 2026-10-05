import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/utils/use_case.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_state.dart';
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

    if (locator.isRegistered<DashboardBloc>()) {
      _dashboardSubscription =
          locator<DashboardBloc>().stream.listen((dashState) {
        final feed = dashState.feed;
        if (feed != null &&
            feed.dueStudyDecks.isNotEmpty &&
            state.allDecks.isNotEmpty) {
          final hasDiscrepancy = feed.dueStudyDecks.any((dashDeck) {
            final local =
                state.allDecks.where((d) => d.id == dashDeck.id).firstOrNull;
            return local != null && local.dueCards > dashDeck.dueCards;
          });
          if (hasDiscrepancy) {
            add(const DecksRefreshed());
          }
        }
      });
    }
  }

  final GetUserDecksUseCase _getUserDecksUseCase;
  final DeleteDeckUseCase? _deleteDeckUseCase;
  StreamSubscription<DashboardState>? _dashboardSubscription;

  @override
  Future<void> close() async {
    await _dashboardSubscription?.cancel();
    return super.close();
  }

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

    try {
      if (locator.isRegistered<LocalStorageService>()) {
        final storage = locator<LocalStorageService>();
        await storage.deletePreference(key: 'extracted_doc_${event.deckId}');
      }
    } on Object catch (_) {}

    if (_deleteDeckUseCase != null) {
      await _deleteDeckUseCase(event.deckId);
    }
  }

  List<DeckEntity> _reconcileWithDashboard(List<DeckEntity> decks) {
    if (!locator.isRegistered<DashboardBloc>()) return decks;
    final feed = locator<DashboardBloc>().state.feed;
    if (feed == null || feed.dueStudyDecks.isEmpty) return decks;

    final dashDueMap = {
      for (final d in feed.dueStudyDecks)
        d.id: d,
    };

    return decks.map((deck) {
      final dashDeck = dashDueMap[deck.id];
      if (dashDeck != null) {
        final isDashNewer = deck.lastStudied == null ||
            dashDeck.lastReviewed.isAfter(deck.lastStudied!);
        if (isDashNewer && dashDeck.dueCards > deck.dueCards) {
          return deck.copyWith(
            dueCards: dashDeck.dueCards,
            totalCards: dashDeck.totalCards > deck.totalCards
                ? dashDeck.totalCards
                : deck.totalCards,
            lastStudied: deck.lastStudied ?? dashDeck.lastReviewed,
          );
        }
      }
      return deck;
    }).toList();
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
        final reconciledDecks = _reconcileWithDashboard(decks);
        emit(
          state.copyWith(
            status: DecksStatus.loaded,
            allDecks: reconciledDecks,
            filteredDecks: _applyFilterAndSearch(
              reconciledDecks,
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
        final reconciledDecks = _reconcileWithDashboard(decks);
        emit(
          state.copyWith(
            status: DecksStatus.loaded,
            allDecks: reconciledDecks,
            filteredDecks: _applyFilterAndSearch(
              reconciledDecks,
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

    // Three-tier sort: Due → Undone → Done
    //
    // Tier 1 — Due:   dueCards > 0  (needs review right now)
    // Tier 2 — Undone: dueCards == 0 && masteryRate < 1.0  (in progress / new)
    // Tier 3 — Done:  dueCards == 0 && masteryRate >= 1.0  (fully mastered)
    //
    // Within Tier 1: sort by highest due count descending, then earliest due date.
    // Within Tier 2: sort by lowest masteryRate first (most work needed), then title.
    // Within Tier 3: sort by most recently studied descending, then title.
    int tier(DeckEntity d) {
      if (d.dueCards > 0) return 0; // Due
      if (d.masteryRate < 1.0) return 1; // Undone
      return 2; // Done
    }

    list.sort((a, b) {
      final aTier = tier(a);
      final bTier = tier(b);

      // Cross-tier: lower tier number wins
      if (aTier != bTier) return aTier.compareTo(bTier);

      // ── Within Tier 1 (Due) ──────────────────────────────────────────────
      if (aTier == 0) {
        final countCmp = b.dueCards.compareTo(a.dueCards);
        if (countCmp != 0) return countCmp;

        final aEarliest = _findEarliestDueDate(a);
        final bEarliest = _findEarliestDueDate(b);
        if (aEarliest != null && bEarliest != null) {
          final dateCmp = aEarliest.compareTo(bEarliest);
          if (dateCmp != 0) return dateCmp;
        }
      }

      // ── Within Tier 2 (Undone) ───────────────────────────────────────────
      if (aTier == 1) {
        // Show decks with least mastery first (most work to do)
        final masteryCmp = a.masteryRate.compareTo(b.masteryRate);
        if (masteryCmp != 0) return masteryCmp;
      }

      // ── Within Tier 3 (Done) ─────────────────────────────────────────────
      if (aTier == 2) {
        // Most recently studied at top of the done section
        if (a.lastStudied != null && b.lastStudied != null) {
          return b.lastStudied!.compareTo(a.lastStudied!);
        } else if (a.lastStudied != null) {
          return -1;
        } else if (b.lastStudied != null) {
          return 1;
        }
      }

      // Stable final fallback
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
