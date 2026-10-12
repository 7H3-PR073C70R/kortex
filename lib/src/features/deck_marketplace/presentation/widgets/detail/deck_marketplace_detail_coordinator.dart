import 'dart:convert';

import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/core/utils/app_logger.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_event.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_hub_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:kortex/src/features/deck_marketplace/domain/entities/shared_deck_entity.dart';
import 'package:kortex/src/features/deck_marketplace/domain/services/deck_cloned_checker.dart';
import 'package:kortex/src/features/deck_marketplace/domain/use_cases/clone_shared_deck_use_case.dart';
import 'package:kortex/src/features/deck_marketplace/domain/use_cases/delete_shared_deck_use_case.dart';
import 'package:kortex/src/features/deck_marketplace/domain/use_cases/rate_shared_deck_use_case.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_event.dart';

class DeckMarketplaceDetailCoordinator {
  DeckMarketplaceDetailCoordinator({
    UserStorageService? userStorageService,
    LocalStorageService? localStorageService,
    RateSharedDeckUseCase? rateSharedDeckUseCase,
    DeleteSharedDeckUseCase? deleteSharedDeckUseCase,
    CloneSharedDeckUseCase? cloneSharedDeckUseCase,
    CommunityHubBloc? communityHubBloc,
    DecksBloc? decksBloc,
    DashboardBloc? dashboardBloc,
  })  : _userStorageService = userStorageService ??
            (locator.isRegistered<UserStorageService>()
                ? locator<UserStorageService>()
                : null),
        _localStorageService = localStorageService ??
            (locator.isRegistered<LocalStorageService>()
                ? locator<LocalStorageService>()
                : null),
        _rateSharedDeckUseCase = rateSharedDeckUseCase ??
            (locator.isRegistered<RateSharedDeckUseCase>()
                ? locator<RateSharedDeckUseCase>()
                : null),
        _deleteSharedDeckUseCase = deleteSharedDeckUseCase ??
            (locator.isRegistered<DeleteSharedDeckUseCase>()
                ? locator<DeleteSharedDeckUseCase>()
                : null),
        _cloneSharedDeckUseCase = cloneSharedDeckUseCase ??
            (locator.isRegistered<CloneSharedDeckUseCase>()
                ? locator<CloneSharedDeckUseCase>()
                : null),
        _communityHubBloc = communityHubBloc ??
            (locator.isRegistered<CommunityHubBloc>()
                ? locator<CommunityHubBloc>()
                : null),
        _decksBloc = decksBloc ??
            (locator.isRegistered<DecksBloc>()
                ? locator<DecksBloc>()
                : null),
        _dashboardBloc = dashboardBloc ??
            (locator.isRegistered<DashboardBloc>()
                ? locator<DashboardBloc>()
                : null);

  final UserStorageService? _userStorageService;
  final LocalStorageService? _localStorageService;
  final RateSharedDeckUseCase? _rateSharedDeckUseCase;
  final DeleteSharedDeckUseCase? _deleteSharedDeckUseCase;
  final CloneSharedDeckUseCase? _cloneSharedDeckUseCase;
  final CommunityHubBloc? _communityHubBloc;
  final DecksBloc? _decksBloc;
  final DashboardBloc? _dashboardBloc;

  String? get currentUserId => _userStorageService?.getUserId();

  bool isOwner(SharedDeckEntity deck) {
    final userId = currentUserId;
    return userId != null && userId == deck.ownerId;
  }

  List<DeckEntity> getUserDecks([List<DeckEntity>? fallback]) {
    return _decksBloc?.state.allDecks ?? fallback ?? const <DeckEntity>[];
  }

  bool isAlreadyCloned(SharedDeckEntity deck, {List<DeckEntity>? userDecks}) {
    final decks = userDecks ?? getUserDecks();
    return isDeckAlreadyCloned(deck, userDecks: decks);
  }

  Future<Either<Failure, double>?> rateDeck({
    required String sharedDeckId,
    required double rating,
  }) async {
    if (_rateSharedDeckUseCase == null) return null;
    final res = await _rateSharedDeckUseCase(
      sharedDeckId: sharedDeckId,
      rating: rating,
    );
    res.fold(
      (_) {},
      (newRating) {
        _communityHubBloc?.add(
          RateSharedDeckEvent(
            sharedDeckId: sharedDeckId,
            rating: newRating,
          ),
        );
      },
    );
    return res;
  }

  Future<Either<Failure, bool>?> deleteDeck(String sharedDeckId) async {
    if (_deleteSharedDeckUseCase == null) return null;
    final res = await _deleteSharedDeckUseCase(sharedDeckId);
    res.fold(
      (_) {},
      (_) {
        _communityHubBloc?.add(DeleteSharedDeckEvent(sharedDeckId));
      },
    );
    return res;
  }

  Future<Either<Failure, DeckEntity>?> cloneDeck(String sharedDeckId) async {
    if (_cloneSharedDeckUseCase == null) return null;
    final res = await _cloneSharedDeckUseCase(sharedDeckId);
    await res.fold(
      (_) async {},
      (clonedDeck) async {
        try {
          if (_localStorageService != null) {
            final raw = _localStorageService.getPreference(
              key: PrefKeys.persistedUserDecks,
            );
            final existingList = raw != null && raw.isNotEmpty
                ? (jsonDecode(raw) as List<dynamic>)
                : <dynamic>[];

            final deckMap = <String, dynamic>{
              'id': clonedDeck.id,
              'title': clonedDeck.title,
              'subject': clonedDeck.subject,
              'total_cards': clonedDeck.totalCards,
              'due_cards': clonedDeck.dueCards,
              'mastery_rate': clonedDeck.masteryRate,
              'category': clonedDeck.category,
              'description': clonedDeck.description,
              'created_at': DateTime.now().toIso8601String(),
            };

            existingList
              ..removeWhere((d) => d is Map && d['id'] == clonedDeck.id)
              ..insert(0, deckMap);

            await _localStorageService.savePreference(
              key: PrefKeys.persistedUserDecks,
              data: jsonEncode(existingList),
            );
          }
        } on Object catch (e, st) {
          AppLogger.recordNonFatal(e, st);
        }

        _decksBloc?.add(const DecksRefreshed());
        _dashboardBloc?.add(const DashboardRefreshed());
      },
    );
    return res;
  }
}
