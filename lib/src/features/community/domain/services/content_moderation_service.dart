/// Moderation validation result for community forum discussions.
class ModerationResult {
  const ModerationResult({
    required this.isValid,
    this.reason,
  });

  final bool isValid;
  final String? reason;

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

  static const List<String> _profanityList = [
    'fuck',
    'shit',
    'bitch',
    'bastard',
    'asshole',
    'dick',
    'pussy',
    'crap',
    'scam',
    'spam',
  ];

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

  /// Evaluates forum title & content for safety compliance.
  ModerationResult validatePost({
    required String title,
    required String content,
  }) {
    final combined = '$title\n$content';
    final combinedLower = combined.toLowerCase();

    // 1. Check for malicious script / HTML injection
    if (_scriptInjectionRegex.hasMatch(combined)) {
      return const ModerationResult(
        isValid: false,
        reason:
            'Potentially malicious scripts or unsafe HTML detected. Please use standard Markdown or LaTeX.',
      );
    }

    // 2. Check for profanity
    for (final word in _profanityList) {
      if (combinedLower.contains(word)) {
        return const ModerationResult(
          isValid: false,
          reason:
              'Inappropriate language detected. Please keep forum discussions professional.',
        );
      }
    }

    // 3. Check for personal contact info (email / phone number sharing)
    if (_emailRegex.hasMatch(combinedLower)) {
      return const ModerationResult(
        isValid: false,
        reason:
            'Sharing email addresses in public threads is restricted for privacy safety.',
      );
    }

    if (_phoneRegex.hasMatch(combinedLower)) {
      return const ModerationResult(
        isValid: false,
        reason:
            'Sharing phone numbers in public threads is restricted for user safety.',
      );
    }

    // 4. Check title minimum length for high signal
    if (title.trim().length < 5) {
      return const ModerationResult(
        isValid: false,
        reason:
            'Thread title is too short. Provide a clear, descriptive academic title.',
      );
    }

    return ModerationResult.clean;
  }

  /// Evaluates a forum reply for safety compliance.
  ModerationResult validateReply({required String content}) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return const ModerationResult(
        isValid: false,
        reason: 'Reply content cannot be empty.',
      );
    }

    // 1. Check for malicious script / HTML injection
    if (_scriptInjectionRegex.hasMatch(content)) {
      return const ModerationResult(
        isValid: false,
        reason:
            'Potentially malicious scripts or unsafe HTML detected in reply.',
      );
    }

    // 2. Check for profanity
    final lower = content.toLowerCase();
    for (final word in _profanityList) {
      if (lower.contains(word)) {
        return const ModerationResult(
          isValid: false,
          reason:
              'Inappropriate language detected. Please keep peer replies constructive and respectful.',
        );
      }
    }

    // 3. Check for personal contact info
    if (_emailRegex.hasMatch(lower)) {
      return const ModerationResult(
        isValid: false,
        reason:
            'Sharing email addresses in replies is restricted for privacy safety.',
      );
    }

    if (_phoneRegex.hasMatch(lower)) {
      return const ModerationResult(
        isValid: false,
        reason:
            'Sharing phone numbers in replies is restricted for user safety.',
      );
    }

    return ModerationResult.clean;
  }
}
