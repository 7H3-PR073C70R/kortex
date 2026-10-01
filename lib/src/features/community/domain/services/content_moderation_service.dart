/// Moderation violation category.
enum ModerationCategory {
  maliciousScript,
  profanity,
  commercialSpam,
  educationalPurpose,
  personalContact,
  lowQualityOrGibberish,
  lengthConstraint,
}

/// Moderation validation result for community forum discussions.
class ModerationResult {
  const ModerationResult({
    required this.isValid,
    this.reason,
    this.suggestion,
    this.category,
  });

  final bool isValid;
  final String? reason;
  final String? suggestion;
  final ModerationCategory? category;

  static const ModerationResult clean = ModerationResult(isValid: true);
}

/// Automated content moderation service to preserve academic signal-to-noise ratio.
class ContentModerationService {
  const ContentModerationService();

  static final RegExp _emailRegex = RegExp(
    r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
  );

  static final RegExp _phoneRegex = RegExp(
    r'(\+?\d{1,3}[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}',
  );

  static final RegExp _scriptInjectionRegex = RegExp(
    r'(?:<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>|javascript:|data:text\/html|<iframe\b|<object\b|<embed\b|<applet\b|<\w+\s+[^>]*?on(?:error|load|click|mouse\w+|key\w+)\s*=)',
    caseSensitive: false,
  );

  static final RegExp _dangerousTagsRegex = RegExp(
    r'<\s*\/?\s*(?:script|iframe|object|embed|applet|style|form|input|meta|link)[^>]*>',
    caseSensitive: false,
  );

  static final RegExp _inlineEventHandlerRegex = RegExp(
    r'\s+on[a-zA-Z]+\s*=\s*(?:"[^"]*"|' r"'[^']*'|[^\s>]+)",
    caseSensitive: false,
  );

  /// Word-boundary regexes for foul language and explicit vulgarity to prevent false-positives
  /// on valid academic terms (e.g. 'class', 'assignment', 'scrap', 'pass', 'cockpit').
  static final List<RegExp> _profanityRegexes = [
    RegExp(r'\b(?:f+u+c+k+(?:e+r|i+n+g|s|e+d)?|f+k|f\*+k)\b', caseSensitive: false),
    RegExp(r'\b(?:s+h+i+t+(?:t+y|s|e+d)?|b+u+l+l+s+h+i+t)\b', caseSensitive: false),
    RegExp(r'\b(?:b+i+t+c+h+(?:e+s|i+n+g)?)\b', caseSensitive: false),
    RegExp(r'\b(?:b+a+s+t+a+r+d+(?:s)?)\b', caseSensitive: false),
    RegExp(r'\b(?:a+s+s+h+o+l+e+(?:s)?|a+r+s+e+h+o+l+e+(?:s)?)\b', caseSensitive: false),
    RegExp(r'\b(?:d+i+c+k+(?:h+e+a+d|s)?)\b', caseSensitive: false),
    RegExp(r'\b(?:p+u+s+s+y+(?:i+e+s)?)\b', caseSensitive: false),
    RegExp(r'\b(?:c+u+n+t+(?:s)?)\b', caseSensitive: false),
    RegExp(r'\b(?:c+o+c+k+(?:s+u+c+k+e+r)?)\b', caseSensitive: false),
    RegExp(r'\b(?:w+h+o+r+e+(?:s)?|s+l+u+t+(?:s)?)\b', caseSensitive: false),
    RegExp(r'\b(?:m+o+t+h+e+r+f+u+c+k+(?:e+r|i+n+g)?)\b', caseSensitive: false),
    RegExp(r'\b(?:n+i+g+g+(?:e+r|a)+(?:s)?)\b', caseSensitive: false),
    RegExp(r'\b(?:f+a+g+g+o+t+(?:s)?)\b', caseSensitive: false),
    RegExp(r'\b(?:c+r+a+p+(?:p+y)?)\b', caseSensitive: false),
    RegExp(r'\b(?:r+e+t+a+r+d+(?:e+d)?)\b', caseSensitive: false),
  ];

  /// Patterns detecting non-educational commercial solicitations and academic dishonesty services.
  static final List<RegExp> _commercialSpamRegexes = [
    RegExp(
      r'\b(?:essay\s*writing\s*service|write\s*my\s*essay|buy\s*essay|pay\s*for\s*(?:essay|homework|assignment)|homework\s*for\s*(?:money|cash)|do\s*my\s*(?:exam|quiz|homework|assignment)\s*for\s*money)\b',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(?:buy\s*crypto|crypto\s*signals?|forex\s*trading|earn\s*\$?\d+\s*(?:daily|weekly)|investment\s*opportunity|dm\s*(?:me\s*)?on\s*(?:telegram|whatsapp)|whatsapp\s*group\s*link)\b',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(?:online\s*casino|slot\s*machine|betting\s*odds|sports\s*betting|onlyfans|sugar\s*(?:daddy|mommy))\b',
      caseSensitive: false,
    ),
  ];

  /// Patterns detecting keyboard mash or low-effort non-educational spam.
  static final RegExp _repeatedCharSpam = RegExp(r'(.)\1{6,}');
  static final RegExp _consonantMashSpam = RegExp(
    r'\b[bcdfghjklmnpqrstvwxyz]{9,}\b',
    caseSensitive: false,
  );

  /// Sanitizes text by stripping harmful executable script tags, iframes, and inline event handlers,
  /// while preserving standard LaTeX equations and markdown formatting.
  static String sanitizeText(String input) {
    if (input.trim().isEmpty) return '';
    var sanitized = input.replaceAll(_dangerousTagsRegex, '');
    sanitized = sanitized.replaceAll(_inlineEventHandlerRegex, '');
    sanitized = sanitized.replaceAll(
      RegExp(r'javascript:\s*', caseSensitive: false),
      '',
    );
    sanitized = sanitized.replaceAll(
      RegExp(r'data:text\/html[^\s]*', caseSensitive: false),
      '',
    );
    return sanitized;
  }

  /// Normalizes leetspeak symbols to letters to defeat obfuscation.
  static String _normalizeLeetspeak(String input) {
    return input
        .replaceAll('@', 'a')
        .replaceAll(r'$', 's')
        .replaceAll('0', 'o')
        .replaceAll('1', 'i')
        .replaceAll('3', 'e')
        .replaceAll('!', 'i')
        .replaceAll('+', 't');
  }

  /// Evaluates forum title & content for safety compliance and educational purpose.
  ModerationResult validatePost({
    required String title,
    required String content,
  }) {
    final combined = '$title\n$content';
    final normalized = _normalizeLeetspeak(combined);

    // 1. Check for malicious script / HTML injection
    if (_scriptInjectionRegex.hasMatch(combined)) {
      return const ModerationResult(
        isValid: false,
        category: ModerationCategory.maliciousScript,
        reason:
            'Potentially malicious scripts or unsafe HTML detected. Please use standard Markdown or LaTeX.',
        suggestion:
            'Remove any HTML tags or script references and format your post using standard Markdown or LaTeX math.',
      );
    }

    // 2. Check for profanity and foul language
    for (final reg in _profanityRegexes) {
      if (reg.hasMatch(combined) || reg.hasMatch(normalized)) {
        return const ModerationResult(
          isValid: false,
          category: ModerationCategory.profanity,
          reason:
              'Inappropriate language detected. Please keep forum discussions professional and respectful.',
          suggestion:
              'Kortex is a peer educational environment. Please remove profane or vulgar words before posting.',
        );
      }
    }

    // 3. Educational purpose check: commercial spam, essay mill, or solicitations
    for (final reg in _commercialSpamRegexes) {
      if (reg.hasMatch(combined)) {
        return const ModerationResult(
          isValid: false,
          category: ModerationCategory.commercialSpam,
          reason:
              'Non-educational promotional content or academic dishonesty solicitation detected.',
          suggestion:
              'Commercial promotions, paid assignment services, and third-party solicitations are not permitted on Kortex.',
        );
      }
    }

    // 4. Check for personal contact info (email / phone number sharing)
    if (_emailRegex.hasMatch(combined)) {
      return const ModerationResult(
        isValid: false,
        category: ModerationCategory.personalContact,
        reason:
            'Sharing email addresses in public threads is restricted for privacy safety.',
        suggestion:
            'Keep discussion within the Kortex thread to protect your privacy and ensure all learners benefit.',
      );
    }

    if (_phoneRegex.hasMatch(combined)) {
      return const ModerationResult(
        isValid: false,
        category: ModerationCategory.personalContact,
        reason:
            'Sharing phone numbers in public threads is restricted for user safety.',
        suggestion:
            'Avoid posting direct phone numbers to safeguard your identity.',
      );
    }

    // 5. Check for gibberish / low-effort spam
    if (_repeatedCharSpam.hasMatch(title) ||
        _repeatedCharSpam.hasMatch(content)) {
      return const ModerationResult(
        isValid: false,
        category: ModerationCategory.lowQualityOrGibberish,
        reason:
            'Excessive repeated characters or low-effort formatting detected.',
        suggestion:
            'Please write a clear, coherent question so your peers and educators can assist you.',
      );
    }

    if (_consonantMashSpam.hasMatch(title) ||
        _consonantMashSpam.hasMatch(content)) {
      return const ModerationResult(
        isValid: false,
        category: ModerationCategory.lowQualityOrGibberish,
        reason:
            'Unrecognizable text or keyboard mash detected. Posts must be relevant for educational study.',
        suggestion:
            'Ensure your post is articulated with real words and clear academic context.',
      );
    }

    // 6. Check title minimum length for high signal
    if (title.trim().length < 5) {
      return const ModerationResult(
        isValid: false,
        category: ModerationCategory.lengthConstraint,
        reason:
            'Thread title is too short. Provide a clear, descriptive academic title.',
        suggestion:
            'A good title briefly states the subject, theorem, or specific concept you wish to discuss.',
      );
    }

    return ModerationResult.clean;
  }

  /// Evaluates a forum reply for safety compliance and educational purpose.
  ModerationResult validateReply({required String content}) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return const ModerationResult(
        isValid: false,
        category: ModerationCategory.lengthConstraint,
        reason: 'Reply content cannot be empty.',
      );
    }

    // 1. Check for malicious script / HTML injection
    if (_scriptInjectionRegex.hasMatch(content)) {
      return const ModerationResult(
        isValid: false,
        category: ModerationCategory.maliciousScript,
        reason:
            'Potentially malicious scripts or unsafe HTML detected in reply.',
        suggestion: 'Remove HTML tags or scripts from your response.',
      );
    }

    // 2. Check for profanity and foul language
    final normalized = _normalizeLeetspeak(content);
    for (final reg in _profanityRegexes) {
      if (reg.hasMatch(content) || reg.hasMatch(normalized)) {
        return const ModerationResult(
          isValid: false,
          category: ModerationCategory.profanity,
          reason:
              'Inappropriate language detected. Please keep peer replies constructive and respectful.',
          suggestion:
              'Help maintain an encouraging and professional academic environment by avoiding foul words.',
        );
      }
    }

    // 3. Educational purpose: commercial spam
    for (final reg in _commercialSpamRegexes) {
      if (reg.hasMatch(content)) {
        return const ModerationResult(
          isValid: false,
          category: ModerationCategory.commercialSpam,
          reason:
              'Non-educational promotional content or external solicitation detected.',
          suggestion:
              'Replies should focus on solving the academic question or clarifying the concept.',
        );
      }
    }

    // 4. Check for personal contact info
    if (_emailRegex.hasMatch(content)) {
      return const ModerationResult(
        isValid: false,
        category: ModerationCategory.personalContact,
        reason:
            'Sharing email addresses in replies is restricted for privacy safety.',
      );
    }

    if (_phoneRegex.hasMatch(content)) {
      return const ModerationResult(
        isValid: false,
        category: ModerationCategory.personalContact,
        reason:
            'Sharing phone numbers in replies is restricted for user safety.',
      );
    }

    // 5. Gibberish check
    if (_repeatedCharSpam.hasMatch(content) ||
        _consonantMashSpam.hasMatch(content)) {
      return const ModerationResult(
        isValid: false,
        category: ModerationCategory.lowQualityOrGibberish,
        reason:
            'Unrecognizable text or keyboard mash detected. Replies should contribute constructively to learning.',
      );
    }

    return ModerationResult.clean;
  }
}
