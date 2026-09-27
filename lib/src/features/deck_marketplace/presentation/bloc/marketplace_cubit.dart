import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:kortex/src/features/deck_marketplace/presentation/bloc/marketplace_state.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_event.dart';

class MarketplaceCubit extends Cubit<MarketplaceState> {
  MarketplaceCubit({
    required CommunityRepository repository,
  })  : _repository = repository,
        super(const MarketplaceState());

  final CommunityRepository _repository;

  Future<void> loadSharedDecks() async {
    emit(state.copyWith(status: MarketplaceStatus.loading));
    final res = await _repository.fetchSharedDecks();
    res.fold(
      (failure) => emit(state.copyWith(status: MarketplaceStatus.failure, errorMessage: failure.message)),
      (decks) => emit(state.copyWith(status: MarketplaceStatus.loaded, sharedDecks: decks)),
    );
  }

  Future<void> cloneDeck(String deckId) async {
    final res = await _repository.cloneSharedDeck(deckId);
    res.fold(
      (failure) => emit(state.copyWith(errorMessage: failure.message)),
      (clonedDeck) {
        emit(state.copyWith(lastClonedDeckId: clonedDeck.id));
        if (locator.isRegistered<DecksBloc>()) {
          locator<DecksBloc>().add(const DecksRefreshed());
        }
        if (locator.isRegistered<DashboardBloc>()) {
          locator<DashboardBloc>().add(const DashboardRefreshed());
        }
      },
    );
  }

  Future<void> publishDeck({
    required String title,
    required String subject,
    required String description,
    required String category,
    required String syllabusTag,
    required int totalCards,
    required List<Map<String, dynamic>> cardsJson,
  }) async {
    final res = await _repository.publishDeckToMarketplace(
      title: title,
      subject: subject,
      description: description,
      category: category,
      syllabusTag: syllabusTag,
      totalCards: totalCards,
      cardsJson: cardsJson,
    );
    res.fold(
      (failure) => emit(state.copyWith(errorMessage: failure.message)),
      (sharedDeck) {
        emit(state.copyWith(sharedDecks: [sharedDeck, ...state.sharedDecks]));
      },
    );
  }
}
