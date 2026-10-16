import 'package:flutter/material.dart';

/// Extracts 2-letter uppercase initials from user display names or handles.
String extractTwoLetterInitials(String? text) {
  if (text == null) return 'KO';
  final trimmed = text.trim();
  if (trimmed.isEmpty) return 'KO';

  // 1. If multi-word (e.g. "John Doe"), take the first letter of the first two words
  final parts = trimmed
      .split(RegExp(r'[\s_.\-]+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.length >= 2) {
    final first = parts[0].characters.isNotEmpty
        ? parts[0].characters.first
        : '';
    final second = parts[1].characters.isNotEmpty
        ? parts[1].characters.first
        : '';
    final combined = '$first$second'.toUpperCase();
    if (combined.isNotEmpty) return combined;
  }

  // 2. If single word/username (e.g. "toxicbishop01"), strip non-alphanumeric and take first 2 chars
  final clean = trimmed.replaceAll(RegExp('[^a-zA-Z0-9]'), '');
  if (clean.characters.length >= 2) {
    return clean.characters.take(2).toString().toUpperCase();
  }
  if (clean.characters.length == 1) {
    return clean.toUpperCase();
  }

  // 3. Fallback to raw characters if only unicode/emojis or special symbols
  if (trimmed.characters.length >= 2) {
    return trimmed.characters.take(2).toString().toUpperCase();
  }
  if (trimmed.characters.length == 1) {
    return trimmed.toUpperCase();
  }

  return 'KO';
}
