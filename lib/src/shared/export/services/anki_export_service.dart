import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';

class AnkiExportService {
  const AnkiExportService();

  /// Converts flashcards into standard Anki tab-delimited text format in a background isolate.
  Future<String> generateAnkiCsvAsync(DeckEntity deck) async {
    return compute(_isolateGenerateAnkiCsv, deck);
  }

  static String _isolateGenerateAnkiCsv(DeckEntity deck) {
    return const AnkiExportService().generateAnkiCsv(deck);
  }

  /// Converts flashcards into standard Anki tab-delimited text format with
  /// LaTeX tags.
  String generateAnkiCsv(DeckEntity deck) {
    final buffer = StringBuffer()
      ..writeln('#separator:tab')
      ..writeln('#html:true')
      ..writeln('#deck:${_escapeText(deck.title)}')
      ..writeln('#notetype:Basic (and reversed card)');

    for (final card in deck.cards) {
      final frontFormatted = _formatLatexForAnki(card.front);
      final backFormatted = _formatLatexForAnki(card.back);
      final subject = _escapeText(deck.subject);
      buffer.writeln('$frontFormatted\t$backFormatted\t$subject');
    }

    return buffer.toString();
  }

  /// Formats raw text LaTeX into Anki-compatible math tags.
  String _formatLatexForAnki(String text) {
    var formatted = text;

    // 1. Replace $$...$$ with placeholder to avoid collisions with single $
    const displayStartPlaceholder = '__ANKI_DISPLAY_MATH_START__';
    const displayEndPlaceholder = '__ANKI_DISPLAY_MATH_END__';

    formatted = formatted.replaceAllMapped(
      RegExp(r'\$\$(.*?)\$\$', dotAll: true),
      (match) =>
          '$displayStartPlaceholder${match.group(1)}$displayEndPlaceholder',
    );

    // 2. Replace single $...$ with inline math tags
    formatted = formatted.replaceAllMapped(
      RegExp(r'\$(.*?)\$'),
      (match) => '${r"[$]"}${match.group(1)}${r"[/$]"}',
    );

    // 3. Restore display math tags
    formatted = formatted
        .replaceAll(displayStartPlaceholder, r'[$$]')
        .replaceAll(displayEndPlaceholder, r'[/$$]');

    // Replace newlines with <br> for HTML rendering in Anki
    formatted = formatted.replaceAll('\n', '<br>');

    return formatted;
  }

  String _escapeText(String text) {
    return text.replaceAll('\t', ' ').replaceAll('\n', ' ');
  }

  List<int> generateAnkiExportBytes(DeckEntity deck) {
    return utf8.encode(generateAnkiCsv(deck));
  }
}
