import 'dart:math' as math;

/// Utility that formats natural text into Bionic Reading markdown for neurodivergent
/// learners (ADHD, dyslexia, executive reading fatigue).
///
/// Highlights the initial fixation point of words (e.g. "**Quan**tum **mech**anics"),
/// guiding saccadic eye movements and preventing cognitive overwhelm while strictly
/// preserving LaTeX formulas ($...$, $$...$$, \[...\], \(...\)) and code blocks.
class BionicTextFormatter {
  const BionicTextFormatter._();

  static final RegExp _formulaRegex = RegExp(
    r'(\\\([\s\S]*?\\\)|\$\$[\s\S]*?\$\$|\\\[[\s\S]*?\\\]|\$(?!\$)[\s\S]*?\$|`[^`]+`)',
    multiLine: true,
  );

  static final RegExp _wordRegex = RegExp('[a-zA-Z0-9]+');

  /// Transforms [text] into Bionic Reading markdown format by bolding initial letters of words.
  /// Preserves LaTeX equations, code spans, and existing bold markdown markers.
  static String format(String text, {double fixationRatio = 0.45}) {
    if (text.trim().isEmpty) return text;

    // Skip if the text already contains intentional markdown bolding
    if (text.contains('**') || text.contains('__')) {
      return text;
    }

    // Split text by formulas/code spans to prevent corrupting math or code
    final tokens = <String>[];
    var lastIndex = 0;

    for (final match in _formulaRegex.allMatches(text)) {
      if (match.start > lastIndex) {
        tokens.add(text.substring(lastIndex, match.start));
      }
      tokens.add(match.group(0)!);
      lastIndex = match.end;
    }
    if (lastIndex < text.length) {
      tokens.add(text.substring(lastIndex));
    }

    final buffer = StringBuffer();
    for (final token in tokens) {
      if (_formulaRegex.hasMatch(token)) {
        buffer.write(token);
      } else {
        buffer.write(_bionicProcess(token, fixationRatio));
      }
    }

    return buffer.toString();
  }

  static String _bionicProcess(String text, double ratio) {
    return text.replaceAllMapped(_wordRegex, (match) {
      final word = match.group(0)!;
      if (word.length <= 1) return word;

      // Fixation length: 1 character for short words, ceil(length * ratio) for longer words
      final fixationLength = (word.length <= 3)
          ? 1
          : math.min(word.length - 1, (word.length * ratio).ceil());

      final boldPart = word.substring(0, fixationLength);
      final rest = word.substring(fixationLength);
      return '**$boldPart**$rest';
    });
  }
}
