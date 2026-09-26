/// Result of content safety and copyright moderation scan.
class SanitizationResult {
  const SanitizationResult({
    required this.isApproved,
    required this.sanitizedTitle,
    required this.sanitizedDescription,
    required this.sanitizedCards,
    this.flaggedReason,
    this.personalNotesStrippedCount = 0,
  });

  final bool isApproved;
  final String sanitizedTitle;
  final String sanitizedDescription;
  final List<Map<String, dynamic>> sanitizedCards;
  final String? flaggedReason;
  final int personalNotesStrippedCount;
}

/// Domain service for scanning and sanitizing user decks before public marketplace release.
class ContentSafetyModerationService {
  const ContentSafetyModerationService();

  static const List<String> _bannedKeywords = [
    'malware',
    'exploit',
    'illegal_content',
    'phishing',
  ];

  /// Scans and strips personal user data (thought parking lots, private notes)
  /// and performs content safety checks.
  SanitizationResult moderateAndSanitize({
    required String title,
    required String description,
    required List<Map<String, dynamic>> cardsJson,
  }) {
    final lowerTitle = title.toLowerCase();
    final lowerDesc = description.toLowerCase();

    // 1. Check banned keywords
    for (final word in _bannedKeywords) {
      if (lowerTitle.contains(word) || lowerDesc.contains(word)) {
        return SanitizationResult(
          isApproved: false,
          sanitizedTitle: title,
          sanitizedDescription: description,
          sanitizedCards: cardsJson,
          flaggedReason: 'Content contains restricted key phrases: "$word"',
        );
      }
    }

    // 2. Strip personal thought parking lot notes and private tags
    var strippedCount = 0;
    final cleanCards = <Map<String, dynamic>>[];

    for (final card in cardsJson) {
      final cleanCard = Map<String, dynamic>.from(card);
      
      // Strip personal metadata fields if present
      if (cleanCard.containsKey('personal_notes')) {
        cleanCard.remove('personal_notes');
        strippedCount++;
      }
      if (cleanCard.containsKey('thought_parking_lot')) {
        cleanCard.remove('thought_parking_lot');
        strippedCount++;
      }
      if (cleanCard.containsKey('private_tags')) {
        cleanCard.remove('private_tags');
        strippedCount++;
      }

      // Check card front/back for banned content
      final front = (cleanCard['front'] as String? ?? '').toLowerCase();
      final back = (cleanCard['back'] as String? ?? '').toLowerCase();
      for (final word in _bannedKeywords) {
        if (front.contains(word) || back.contains(word)) {
          return SanitizationResult(
            isApproved: false,
            sanitizedTitle: title,
            sanitizedDescription: description,
            sanitizedCards: cardsJson,
            flaggedReason: 'Card content contains prohibited term "$word"',
          );
        }
      }

      cleanCards.add(cleanCard);
    }

    return SanitizationResult(
      isApproved: true,
      sanitizedTitle: title.trim(),
      sanitizedDescription: description.trim(),
      sanitizedCards: cleanCards,
      personalNotesStrippedCount: strippedCount,
    );
  }
}
