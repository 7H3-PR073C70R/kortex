import 'package:flutter/foundation.dart';

/// Helper to normalize and resolve front and back content for flashcards.
///
/// Migrates legacy options blocks from the back face to the front face if
/// not already present, ensuring consistent layout across study sessions.
@immutable
abstract final class CardFaceContentResolver {
  /// Resolves the front and back strings of a flashcard.
  static (String, String) resolve(String front, String back) {
    // 1. If front already explicitly contains options, nothing to migrate
    final hasFrontOptions = RegExp(
      r'(?:\*\*Options:\*\*|Options:|\n\s*•\s*[A-Ea-e][\.\)])',
      caseSensitive: false,
    ).hasMatch(front);

    if (hasFrontOptions) {
      return (front, back);
    }

    // 2. Check if back contains legacy options block
    final legacyOptionsRegex = RegExp(
      r'(?:\*\*Options:\*\*|Options:)\s*\n([\s\S]*?)(?=\n+\s*(?:\*\*)?(?:Correct Answer|Ans|Answer|Explanation):|\Z)',
      caseSensitive: false,
    );

    final match = legacyOptionsRegex.firstMatch(back);
    if (match == null) {
      return (front, back);
    }

    final rawOptions = match.group(1) ?? '';
    final cleanOptionLines = <String>[];
    String? correctOptionText;

    for (final rawLine in rawOptions.split('\n')) {
      final trimmed = rawLine.trim();
      if (trimmed.isEmpty) continue;

      final isChecked = trimmed.contains('✅');
      final cleaned = trimmed
          .replaceAll('✅', '')
          .replaceAll('•', '')
          .replaceAll('*', '')
          .replaceAll('-', '')
          .trim();

      // Normalize duplicate prefixes like "A. A. Option Text" -> "A. Option Text"
      final optMatch = RegExp(
        r'^(?:([A-Ea-e])[\.\)]|\(([A-Ea-e])\))\s*(?:(?:([A-Ea-e])[\.\)]|\(([A-Ea-e])\))\s*)?(.*)',
      ).firstMatch(cleaned);

      if (optMatch != null) {
        final letter = (optMatch.group(1) ?? optMatch.group(2) ?? '')
            .toUpperCase();
        final content = optMatch.group(5)?.trim() ?? '';
        cleanOptionLines.add('• $letter. $content');
        if (isChecked && content.isNotEmpty) {
          correctOptionText = 'Option $letter — $content';
        }
      } else {
        cleanOptionLines.add('• $cleaned');
      }
    }

    final resolvedFront = cleanOptionLines.isNotEmpty
        ? '${front.trim()}\n\n**Options:**\n${cleanOptionLines.join('\n')}'
        : front;

    var resolvedBack =
        (back.substring(0, match.start) + back.substring(match.end)).trim();

    if (correctOptionText != null) {
      resolvedBack = resolvedBack.replaceAllMapped(
        RegExp(
          r'((?:\*\*)?Correct Answer:(?:\*\*)?\s*Option\s+[A-Ea-e])(?!\s*—)',
          caseSensitive: false,
        ),
        (m) => '${m.group(1)} — ${correctOptionText!.split(' — ').last}',
      );
    }

    return (resolvedFront, resolvedBack);
  }
}
