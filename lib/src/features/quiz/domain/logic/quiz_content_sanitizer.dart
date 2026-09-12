/// Utility to sanitize quiz questions, prompt texts, option strings, and explanations
/// synthesized from flashcards, past questions, and external AI models.
class QuizContentSanitizer {
  QuizContentSanitizer._();

  static final RegExp _explanationSplitRegex = RegExp(
    r'(?:\n\s*)?(?:\*\*)?Explanation:(?:\*\*)?\s*([\s\S]*)',
    caseSensitive: false,
  );

  static final RegExp _correctAnswerPrefixRegex = RegExp(
    r'^(?:\*\*)?Correct\s+Answer:(?:\*\*)?\s*',
    caseSensitive: false,
  );

  static final RegExp _optionLabelWithSepRegex = RegExp(
    r'^(?:\*\*)?Option\s+[A-Ea-e](?:\*\*)?\s*(?:—|–|-|:)\s*',
    caseSensitive: false,
  );

  static final RegExp _standardOptionPrefixRegex = RegExp(
    r'^(\(?[A-Ea-e][\.\)]|\b[A-Ea-e]\.)\s*',
  );

  static final RegExp _promptOptionsSectionRegex = RegExp(
    r'(?:\n\s*)?(?:\*\*)?Options:(?:\*\*)?[\s\S]*$',
    caseSensitive: false,
  );

  /// Cleans an option text string to ensure it contains only the concise choice text.
  ///
  /// Strips out leaked `**Correct Answer:**`, option labels (`Option B —`),
  /// prefix letters (`A.`), and any leaked `**Explanation:**` trailing blocks.
  static String cleanOptionText(String rawText) {
    var text = rawText.trim();
    if (text.isEmpty) return text;

    // 1. Strip trailing explanation block if present
    final expMatch = _explanationSplitRegex.firstMatch(text);
    if (expMatch != null && expMatch.start > 0) {
      text = text.substring(0, expMatch.start).trim();
    }

    // 2. Strip "**Correct Answer:**" or "Correct Answer:"
    text = text.replaceFirst(_correctAnswerPrefixRegex, '').trim();

    // 3. Strip "Option B — " or "Option B: "
    final withoutOptionLabel = text.replaceFirst(_optionLabelWithSepRegex, '').trim();
    if (withoutOptionLabel.isNotEmpty) {
      text = withoutOptionLabel;
    }

    // 4. Strip standard prefix like "A. " or "(A) "
    final withoutPrefix = text.replaceFirst(_standardOptionPrefixRegex, '').trim();
    if (withoutPrefix.isNotEmpty) {
      text = withoutPrefix;
    }

    return text.trim();
  }

  /// Extracts the explanation body from a card back text, if present.
  static String? extractExplanation(String rawText) {
    final match = _explanationSplitRegex.firstMatch(rawText);
    if (match != null) {
      final exp = match.group(1)?.trim();
      if (exp != null && exp.isNotEmpty) {
        return exp;
      }
    }
    return null;
  }

  /// Cleans a flashcard front so embedded option lists (e.g. `\n\n**Options:**\n• A. ...`)
  /// are stripped from the question prompt.
  static String cleanPrompt(String rawFront) {
    var prompt = rawFront.trim();
    final match = _promptOptionsSectionRegex.firstMatch(prompt);
    if (match != null && match.start > 0) {
      prompt = prompt.substring(0, match.start).trim();
    }
    return prompt;
  }

  /// Cleans or truncates a subtopic string so it does not overflow UI layouts.
  static String cleanSubTopic(
    String? rawTopic, {
    String defaultTopic = 'Cross-Subject Recall',
    int maxLength = 36,
  }) {
    if (rawTopic == null || rawTopic.trim().isEmpty) {
      return defaultTopic;
    }
    var topic = rawTopic.trim();
    if (topic.length > maxLength) {
      topic = '${topic.substring(0, maxLength - 1).trim()}…';
    }
    return topic;
  }
}
