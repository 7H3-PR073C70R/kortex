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

  /// Evaluates forum title & content for safety compliance.
  ModerationResult validatePost({
    required String title,
    required String content,
  }) {
    final combined = '$title\n$content'.toLowerCase();

    // 1. Check for profanity
    for (final word in _profanityList) {
      if (combined.contains(word)) {
        return const ModerationResult(
          isValid: false,
          reason: 'Inappropriate language detected. Please keep forum discussions professional.',
        );
      }
    }

    // 2. Check for personal contact info (email / phone number sharing)
    if (_emailRegex.hasMatch(combined)) {
      return const ModerationResult(
        isValid: false,
        reason: 'Sharing email addresses in public threads is restricted for privacy safety.',
      );
    }

    if (_phoneRegex.hasMatch(combined)) {
      return const ModerationResult(
        isValid: false,
        reason: 'Sharing phone numbers in public threads is restricted for user safety.',
      );
    }

    // 3. Check title minimum length for high signal
    if (title.trim().length < 5) {
      return const ModerationResult(
        isValid: false,
        reason: 'Thread title is too short. Provide a clear, descriptive academic title.',
      );
    }

    return ModerationResult.clean;
  }
}
