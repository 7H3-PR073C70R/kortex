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

  static final RegExp _bracketedOptionPrefixRegex = RegExp(
    r'^(\([A-Ea-e]\)|\[[A-Ea-e]\]|[A-Ea-e]\))\s*',
  );

  static final RegExp _dottedOptionPrefixRegex = RegExp(
    r'^[A-Ea-e]\.\s*',
  );

  static final RegExp _scientificTermRegex = RegExp(
    r'^(?:[A-Z]\.\s+(?:coli|subtilis|elegans|melanogaster|cerevisiae|aureus|falciparum|histolytica|thaliana|albicans|typhi|cholerae|pneumoniae|tuberculosis|influenzae|faecalis|aeruginosa|stutzeri|marcescens|vulgaris|mirabilis|enterica|retractans|sphaericus|pasteurii|gambiense|rhodesiense|brucei|cruzi|donovani|tropica|major|mexicana|brasiliensis|hominis|gingivalis|tenax|vaginalis|lamblia|intestinalis|duodenalis|dispar|hartmanni|nana|butschlii|mesnili)\b|pH\b|pOH\b|pKa\b|pKb\b|e\.g\.|i\.e\.|d\.c\.|a\.c\.|a\.m\.|p\.m\.)',
    caseSensitive: false,
  );

  static final RegExp _promptOptionsSectionRegex = RegExp(
    r'(?:\n\s*)?(?:\*\*)?Options:(?:\*\*)?[\s\S]*$',
    caseSensitive: false,
  );

  /// Returns true if the text begins with a protected scientific term or genus abbreviation
  /// that should NOT have its leading characters stripped.
  static bool isPreservedScientificTerm(String text) {
    return _scientificTermRegex.hasMatch(text.trim());
  }

  /// Cleans an option text string to ensure it contains only the concise choice text.
  ///
  /// Strips out leaked `**Correct Answer:**`, option labels (`Option B —`),
  /// prefix letters (`A.`, `(A)`), and any leaked `**Explanation:**` trailing blocks,
  /// while strictly preserving scientific abbreviations and terms like "E. coli" or "pH level".
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
    text = text.replaceFirst(_optionLabelWithSepRegex, '').trim();

    // 4. Strip bracketed prefix like "(A) ", "[A] ", or "A) "
    text = text.replaceFirst(_bracketedOptionPrefixRegex, '').trim();

    // 5. Strip standard dotted prefix like "A. " ONLY if not a scientific abbreviation (e.g. "E. coli")
    if (_dottedOptionPrefixRegex.hasMatch(text) &&
        !isPreservedScientificTerm(text)) {
      text = text.replaceFirst(_dottedOptionPrefixRegex, '').trim();
    }

    return text.trim();
  }

  /// Canonical single source of truth for answer grading across Cubit, Repository, and UI.
  static bool isAnswerMatching(String? candidateAnswer, String? correctAnswer) {
    if (candidateAnswer == null || correctAnswer == null) return false;
    final trimmedCandidate = candidateAnswer.trim();
    final trimmedCorrect = correctAnswer.trim();
    if (trimmedCandidate.isEmpty || trimmedCorrect.isEmpty) return false;

    // Fast path: direct case-insensitive match
    if (trimmedCandidate.toLowerCase() == trimmedCorrect.toLowerCase()) {
      return true;
    }

    // Single-letter option label match (e.g. 'A' vs 'A. Mitochondria' or '(A) Mitochondria' or '[C] Chloroplast')
    final letterRegex =
        RegExp(r'^(?:[\[\(]?([A-Ea-e])[\]\)\.]|\b([A-Ea-e])\b)');
    final candidateLetterMatch = letterRegex.firstMatch(trimmedCandidate);
    final correctLetterMatch = letterRegex.firstMatch(trimmedCorrect);

    final candidateLetter = (candidateLetterMatch?.group(1) ??
            candidateLetterMatch?.group(2))
        ?.toUpperCase();
    final correctLetter = (correctLetterMatch?.group(1) ??
            correctLetterMatch?.group(2))
        ?.toUpperCase();

    if (candidateLetter != null && correctLetter != null) {
      if (trimmedCandidate.length == 1 || trimmedCorrect.length == 1) {
        if (candidateLetter == correctLetter) {
          return true;
        }
      }
    }

    // Sanitized comparison (stripping option labels, markdown decorations)
    final cleanCorrect = cleanOptionText(trimmedCorrect).toLowerCase();
    final cleanCandidate = cleanOptionText(trimmedCandidate).toLowerCase();
    if (cleanCorrect.isNotEmpty && cleanCorrect == cleanCandidate) {
      return true;
    }

    return false;
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
