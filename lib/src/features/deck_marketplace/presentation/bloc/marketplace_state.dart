import 'package:equatable/equatable.dart';
import 'package:kortex/src/features/deck_marketplace/domain/entities/shared_deck_entity.dart';

enum MarketplaceStatus { initial, loading, loaded, failure }

class MarketplaceState extends Equatable {
  const MarketplaceState({
    this.status = MarketplaceStatus.initial,
    this.sharedDecks = const [],
    this.lastClonedDeckId,
    this.errorMessage,
  });

  final MarketplaceStatus status;
  final List<SharedDeckEntity> sharedDecks;
  final String? lastClonedDeckId;
  final String? errorMessage;

  MarketplaceState copyWith({
    MarketplaceStatus? status,
    List<SharedDeckEntity>? sharedDecks,
    String? lastClonedDeckId,
    String? errorMessage,
  }) {
    return MarketplaceState(
      status: status ?? this.status,
      sharedDecks: sharedDecks ?? this.sharedDecks,
      lastClonedDeckId: lastClonedDeckId,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, sharedDecks, lastClonedDeckId, errorMessage];
}
