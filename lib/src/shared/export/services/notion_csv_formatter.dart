import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';

class NotionCsvFormatter {
  const NotionCsvFormatter();

  /// Converts a deck into Notion-compatible CSV formatted string in a background isolate.
  Future<String> generateNotionCsvAsync(DeckEntity deck) async {
    return compute(_isolateGenerateNotionCsv, deck);
  }

  static String _isolateGenerateNotionCsv(DeckEntity deck) {
    return const NotionCsvFormatter().generateNotionCsv(deck);
  }

  /// Converts a deck into Notion-compatible CSV formatted string.
  String generateNotionCsv(DeckEntity deck) {
    final buffer = StringBuffer()
      ..writeln('Name,Front,Back,Subject,Deck,Category');

    for (var i = 0; i < deck.cards.length; i++) {
      final card = deck.cards[i];
      final cardName = _escapeCsvField('${deck.title} - Card ${i + 1}');
      final front = _escapeCsvField(card.front);
      final back = _escapeCsvField(card.back);
      final subject = _escapeCsvField(deck.subject);
      final deckTitle = _escapeCsvField(deck.title);
      final category = _escapeCsvField(deck.category);

      buffer.writeln('$cardName,$front,$back,$subject,$deckTitle,$category');
    }

    return buffer.toString();
  }

  String _escapeCsvField(String field) {
    if (field.contains(',') ||
        field.contains('"') ||
        field.contains('\n') ||
        field.contains('\r')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  List<int> generateNotionCsvBytes(DeckEntity deck) {
    return utf8.encode(generateNotionCsv(deck));
  }
}
