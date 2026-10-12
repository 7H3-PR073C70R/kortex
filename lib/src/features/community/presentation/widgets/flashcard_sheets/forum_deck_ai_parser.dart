import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';

/// Helper for constructing AI generation prompts and parsing JSON card output.
abstract final class ForumDeckAiParser {
  /// Builds the structured prompt to send to the Syllabot AI engine.
  static String buildPrompt({
    required ForumPostEntity post,
    required List<ForumReplyEntity> replies,
    required String topicTag,
  }) {
    final sb = StringBuffer()
      ..writeln(
        'You are a smart flashcard generator. Convert the following forum discussion into 5-8 concise study flashcards in strict JSON format.\n',
      )
      ..writeln('Discussion Title: ${post.title}')
      ..writeln('Subject / Topic: $topicTag')
      ..writeln('\nThread Content:')
      ..writeln('Q: ${post.content.trim()}');

    final topReplies = replies
        .where((r) => r.isVerifiedSolution || r.upvotes > 0)
        .take(5)
        .toList();
    final sourcedReplies =
        topReplies.isNotEmpty ? topReplies : replies.take(5).toList();
    for (final r in sourcedReplies) {
      sb.writeln('A (by @${r.authorName}): ${r.content.trim()}');
    }

    sb.writeln('''
\nReturn ONLY valid JSON, no markdown, no explanation:
[
  {"front": "Concise question or term", "back": "Clear, exam-ready answer"},
  ...
]''');
    return sb.toString();
  }

  /// Minimal JSON parser for AI card output — no extra deps needed.
  /// Expects: [{"front":"...","back":"..."},...]
  static List<({String front, String back})> parseCardsJson(String json) {
    final results = <({String front, String back})>[];
    final frontPattern = RegExp(r'"front"\s*:\s*"((?:[^"\\]|\\.)*)"');
    final backPattern = RegExp(r'"back"\s*:\s*"((?:[^"\\]|\\.)*)"');

    final fronts =
        frontPattern.allMatches(json).map((m) => m.group(1) ?? '').toList();
    final backs =
        backPattern.allMatches(json).map((m) => m.group(1) ?? '').toList();

    final count = fronts.length < backs.length ? fronts.length : backs.length;
    for (var i = 0; i < count; i++) {
      final f =
          fronts[i].trim().replaceAll(r'\n', '\n').replaceAll(r'\"', '"');
      final b =
          backs[i].trim().replaceAll(r'\n', '\n').replaceAll(r'\"', '"');
      if (f.isNotEmpty && b.isNotEmpty) {
        results.add((front: f, back: b));
      }
    }
    return results;
  }
}
