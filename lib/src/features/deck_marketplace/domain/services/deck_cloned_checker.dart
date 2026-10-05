import 'dart:convert';
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/deck_marketplace/domain/entities/shared_deck_entity.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';

/// Utility to check whether a shared marketplace deck already exists in the user's personal deck library.
bool isDeckAlreadyCloned(
  SharedDeckEntity marketplaceDeck, {
  Iterable<DeckEntity>? userDecks,
}) {
  final targetTitle = marketplaceDeck.title.trim().toLowerCase();
  final targetSubject = marketplaceDeck.subject.trim().toLowerCase();
  final targetId = marketplaceDeck.id;
  final targetOriginalId = marketplaceDeck.originalDeckId;

  // 1. Check provided or active DecksBloc state decks
  final effectiveDecks = userDecks ??
      (locator.isRegistered<DecksBloc>()
          ? locator<DecksBloc>().state.allDecks
          : const <DeckEntity>[]);

  for (final userDeck in effectiveDecks) {
    if (userDeck.id == targetId) return true;
    if (userDeck.id == 'cloned_$targetId') return true;
    if (targetId == 'cloned_${userDeck.id}') return true;
    if (targetOriginalId != null && targetOriginalId == userDeck.id) return true;

    final userTitle = userDeck.title.trim().toLowerCase();
    final userSubject = userDeck.subject.trim().toLowerCase();
    if (userTitle == targetTitle &&
        (userSubject.isEmpty ||
            targetSubject.isEmpty ||
            userSubject == targetSubject)) {
      return true;
    }
  }

  // 2. Fallback check: check LocalStorageService persisted decks
  try {
    if (locator.isRegistered<LocalStorageService>()) {
      final storage = locator<LocalStorageService>();
      final raw = storage.getPreference(key: PrefKeys.persistedUserDecks);
      if (raw != null && raw.trim().isNotEmpty) {
        final list = jsonDecode(raw);
        if (list is List) {
          for (final item in list) {
            if (item is Map) {
              final id = item['id']?.toString();
              final title = item['title']?.toString().trim().toLowerCase();
              final subject = item['subject']?.toString().trim().toLowerCase();

              if (id == targetId ||
                  id == 'cloned_$targetId' ||
                  targetId == 'cloned_$id') {
                return true;
              }
              if (title != null &&
                  title == targetTitle &&
                  (subject == null ||
                      subject.isEmpty ||
                      targetSubject.isEmpty ||
                      subject == targetSubject)) {
                return true;
              }
            }
          }
        }
      }
    }
  } on Object catch (_) {}

  return false;
}
