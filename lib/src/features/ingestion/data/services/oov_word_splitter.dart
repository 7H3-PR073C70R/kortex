import 'dart:math' as math;

import 'package:kortex/src/features/ingestion/data/services/standard_lexicon.dart';
import 'package:kortex/src/features/ingestion/domain/entities/extraction_report.dart';

/// Dynamic programming word segmentation and out-of-vocabulary (OOV) safety net.
///
/// Detects spaceless glued word runs in body text (e.g., `distinctsections` -> `distinct sections`,
/// `softwareapplication` -> `software application`) using a Viterbi / unigram frequency
/// word-break algorithm, while strictly safeguarding:
/// 1. Programming identifiers (`camelCase`, `PascalCase`, `snake_case`, `SCREAMING_SNAKE`).
/// 2. URLs, URIs, file paths, and email addresses.
/// 3. Legitimate long words recognized in [StandardLexicon] (e.g. `internationalization`, `synchronization`).
/// 4. Domain scientific terms that cannot be decomposed into authentic English dictionary words.
class OovWordSplitter {
  const OovWordSplitter._();

  static const Set<String> _validTwoLetterWords = {
    'in', 'on', 'at', 'to', 'is', 'of', 'by', 'as', 'or', 'an',
    'if', 'we', 'do', 'so', 'up', 'no', 'my', 'he', 'me', 'it',
  };

  /// Returns true if [token] matches programming identifier or system naming patterns.
  static bool isProgrammingIdentifier(String token) {
    if (token.isEmpty) return false;

    // Snake case or screaming snake case (e.g., local_pdf_parser, MAX_BUFFER)
    if (token.contains('_')) return true;

    // Contains digits (e.g., SHA256, UTF8, x86, v2)
    if (RegExp(r'\d').hasMatch(token)) return true;

    // URLs, file paths, URIs, or email addresses
    if (token.contains('/') ||
        token.contains(r'\') ||
        token.contains('@') ||
        token.contains(':') ||
        token.startsWith('http')) {
      return true;
    }

    // Pure uppercase acronyms of 2+ chars (e.g., PDF, HTML, JSON, AST)
    if (token.length >= 2 && RegExp(r'^[A-Z]+$').hasMatch(token)) {
      return true;
    }

    // CamelCase (starts with lowercase, has subsequent uppercase, e.g. textEditingController)
    if (token.length > 2 && RegExp('^[a-z]+[A-Z]').hasMatch(token)) {
      return true;
    }

    // PascalCase (starts with uppercase, then lowercase, then another uppercase, e.g. StatefulWidget)
    if (token.length > 2 && RegExp('^[A-Z][a-z]+[A-Z]').hasMatch(token)) {
      return true;
    }

    return false;
  }

  /// Returns true if [token] is a candidate for OOV word splitting.
  static bool isCandidateForOovSplitting(String token, {int minLength = 14}) {
    if (token.length < minLength) return false;

    // Must be purely alphabetical characters
    if (!RegExp(r'^[A-Za-z]+$').hasMatch(token)) return false;

    // Must not be a programming identifier
    if (isProgrammingIdentifier(token)) return false;

    // Legitimate long dictionary words are In-Vocabulary (IV) and must not be split
    if (StandardLexicon.contains(token)) return false;

    return true;
  }

  /// Splits an out-of-vocabulary glued run into authentic words using DP Viterbi word-break.
  ///
  /// Returns the segmented words joined with a space (e.g. `distinct sections`),
  /// or the original [token] if no valid dictionary decomposition exists.
  static String splitGluedWord(String token, {int minLength = 14}) {
    if (!isCandidateForOovSplitting(token, minLength: minLength)) {
      return token;
    }

    final isFirstUpper = RegExp('^[A-Z]').hasMatch(token);
    final lower = token.toLowerCase();
    final len = lower.length;

    // DP Viterbi arrays:
    // bestScore[i] is the maximum score of segmenting lower[0...i]
    // bestPrev[i] is the index of the start of the last word lower[bestPrev[i]...i]
    final bestScore = List<double>.filled(len + 1, -double.infinity);
    final bestPrev = List<int>.filled(len + 1, -1);
    final wordCount = List<int>.filled(len + 1, 0);

    bestScore[0] = 0.0;
    wordCount[0] = 0;

    for (var i = 0; i < len; i++) {
      if (bestScore[i] == -double.infinity) continue;

      final maxWordLen = math.min(i + 24, len);
      for (var j = i + 2; j <= maxWordLen; j++) {
        final sub = lower.substring(i, j);
        final subLen = j - i;

        if (!_isValidSubword(sub)) continue;

        // Quadratic length scoring rewards authentic longer words over tiny fragments
        // plus split penalty to avoid over-segmentation
        final score = bestScore[i] + (subLen * subLen) - 2.0;

        if (score > bestScore[j]) {
          bestScore[j] = score;
          bestPrev[j] = i;
          wordCount[j] = wordCount[i] + 1;
        }
      }
    }

    // Must reach end of token and have at least 2 distinct words
    if (bestScore[len] == -double.infinity || bestPrev[len] == -1 || wordCount[len] < 2) {
      return token;
    }

    // Backtrack to extract the segmented words
    final words = <String>[];
    var curr = len;
    while (curr > 0) {
      final prev = bestPrev[curr];
      words.add(token.substring(prev, curr));
      curr = prev;
    }

    final orderedWords = words.reversed.toList();

    // Preserve initial sentence capitalization on the first word
    if (isFirstUpper && orderedWords.isNotEmpty) {
      final first = orderedWords.first;
      orderedWords[0] = '${first[0].toUpperCase()}${first.substring(1)}';
    }

    return orderedWords.join(' ');
  }

  /// Determines if [sub] is a valid subword candidate.
  static bool _isValidSubword(String sub) {
    if (sub.length == 2) {
      return _validTwoLetterWords.contains(sub);
    }
    if (sub.length >= 3) {
      return StandardLexicon.contains(sub);
    }
    return false;
  }

  /// Scans [text] line by line, repairing any OOV spaceless glued runs.
  ///
  /// Protected spans (code fences, math blocks) are preserved byte-for-byte.
  /// Any splits performed are recorded in [report] for transparency.
  static String repairGluedRunsInText(
    String text, {
    ExtractionReport? report,
    int? page,
    int minLength = 14,
  }) {
    if (text.isEmpty) return text;

    final lines = text.split('\n');
    final outputLines = <String>[];
    var inCode = false;
    var inMath = false;
    String? codeFence;

    for (final rawLine in lines) {
      final trimmed = rawLine.trim();

      // Code fence detection
      if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) {
        final fence = trimmed.substring(0, 3);
        if (!inCode) {
          inCode = true;
          codeFence = fence;
        } else if (fence == codeFence) {
          inCode = false;
          codeFence = null;
        }
        outputLines.add(rawLine);
        continue;
      }
      if (inCode) {
        outputLines.add(rawLine);
        continue;
      }

      // Math block detection
      if (trimmed.startsWith(r'$$') || trimmed.startsWith(r'\[')) {
        if (!inMath) {
          inMath = true;
          if (trimmed.length > 2 &&
              (trimmed.endsWith(r'$$') || trimmed.endsWith(r'\]'))) {
            inMath = false;
          }
        } else {
          inMath = false;
        }
        outputLines.add(rawLine);
        continue;
      }
      if (trimmed.startsWith(r'\begin{')) {
        inMath = true;
        outputLines.add(rawLine);
        continue;
      }
      if (inMath) {
        if (trimmed.endsWith(r'$$') ||
            trimmed.endsWith(r'\]') ||
            trimmed.startsWith(r'\end{')) {
          inMath = false;
        }
        outputLines.add(rawLine);
        continue;
      }

      // Prose line: inspect word tokens
      final repairedLine = _repairLineTokens(
        rawLine,
        report: report,
        page: page,
        minLength: minLength,
      );
      outputLines.add(repairedLine);
    }

    return outputLines.join('\n');
  }

  /// Repairs glued runs inside a single prose line while preserving surrounding punctuation.
  static String _repairLineTokens(
    String line, {
    ExtractionReport? report,
    int? page,
    int minLength = 14,
  }) {
    if (line.length < minLength) return line;

    // Match word boundaries with optional punctuation
    return line.replaceAllMapped(
      RegExp(r'\b([A-Za-z]+)\b'),
      (match) {
        final token = match.group(1)!;
        if (!isCandidateForOovSplitting(token, minLength: minLength)) {
          return token;
        }

        final splitResult = splitGluedWord(token, minLength: minLength);
        if (splitResult != token) {
          report?.recordGluedWordSplit(
            fusedToken: token,
            splitResult: splitResult,
            page: page,
          );
          return splitResult;
        }
        return token;
      },
    );
  }
}
