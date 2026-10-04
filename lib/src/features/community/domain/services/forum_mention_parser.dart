import 'package:equatable/equatable.dart';

/// Represents a parsed mention or hashtag tag in forum content.
enum ForumTokenKind { mention, hashtag, text }

class ForumToken extends Equatable {
  const ForumToken({
    required this.text,
    required this.kind,
    this.value,
  });

  final String text;
  final ForumTokenKind kind;
  final String? value;

  @override
  List<Object?> get props => [text, kind, value];
}

/// Helper service for extracting and tokenizing @mentions and #hashtags in forum discussions.
class ForumMentionParser {
  const ForumMentionParser._();

  static final RegExp _tokenRegex = RegExp(r'(@[a-zA-Z0-9_\-]+|#[a-zA-Z0-9_\-]+)');

  /// Extracts all distinct @username mentions from post text.
  static List<String> extractMentions(String text) {
    if (text.trim().isEmpty) return const [];
    final matches = RegExp(r'@[a-zA-Z0-9_\-]+').allMatches(text);
    return matches
        .map((m) => m.group(0)!.substring(1))
        .where((m) => m.isNotEmpty)
        .toSet()
        .toList();
  }

  /// Extracts all distinct #hashtag topics from post text.
  static List<String> extractHashtags(String text) {
    if (text.trim().isEmpty) return const [];
    final matches = RegExp(r'#[a-zA-Z0-9_\-]+').allMatches(text);
    return matches
        .map((m) => m.group(0)!.substring(1))
        .where((m) => m.isNotEmpty)
        .toSet()
        .toList();
  }

  /// Tokenizes plain text into a sequence of regular text, @mentions, and #hashtags.
  static List<ForumToken> parseTokens(String text) {
    if (text.isEmpty) return const [];

    final tokens = <ForumToken>[];
    var lastEnd = 0;

    for (final match in _tokenRegex.allMatches(text)) {
      if (match.start > lastEnd) {
        tokens.add(
          ForumToken(
            text: text.substring(lastEnd, match.start),
            kind: ForumTokenKind.text,
          ),
        );
      }

      final raw = match.group(0)!;
      if (raw.startsWith('@')) {
        tokens.add(
          ForumToken(
            text: raw,
            kind: ForumTokenKind.mention,
            value: raw.substring(1),
          ),
        );
      } else if (raw.startsWith('#')) {
        tokens.add(
          ForumToken(
            text: raw,
            kind: ForumTokenKind.hashtag,
            value: raw.substring(1),
          ),
        );
      }

      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      tokens.add(
        ForumToken(
          text: text.substring(lastEnd),
          kind: ForumTokenKind.text,
        ),
      );
    }

    return tokens;
  }
}
