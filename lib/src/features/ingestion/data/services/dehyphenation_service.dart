import 'package:kortex/src/features/ingestion/data/services/local_pdf_parser_service.dart';
import 'package:kortex/src/features/ingestion/data/services/standard_lexicon.dart';

/// The action to take when resolving a line-break hyphenation.
enum DehyphenationAction {
  /// Join the preceding word and next word without a hyphen
  /// (e.g., `infor-` + `mation` -> `information`).
  joinWithoutHyphen,

  /// Preserve the hyphen between the preceding word and next word
  /// (e.g., `happens-` + `before` -> `happens-before`, `20-` + `40` -> `20-40`).
  preserveHyphen,
}

/// In-memory document-level corpus capturing intact hyphenated compounds
/// and unhyphenated vocabulary across the active document.
class DocumentCorpus {
  DocumentCorpus()
      : _hyphenatedCompounds = <String>{},
        _unhyphenatedWords = <String>{};

  /// Creates a [DocumentCorpus] by indexing lines from a document layout.
  factory DocumentCorpus.fromLines(Iterable<PdfLineLayout> lines) {
    return DocumentCorpus()..indexLines(lines);
  }

  /// Creates a [DocumentCorpus] from raw document text.
  factory DocumentCorpus.fromText(String text) {
    return DocumentCorpus()..indexText(text);
  }

  DocumentCorpus.withSets({
    required Set<String> hyphenatedCompounds,
    required Set<String> unhyphenatedWords,
  })  : _hyphenatedCompounds = hyphenatedCompounds,
        _unhyphenatedWords = unhyphenatedWords;

  final Set<String> _hyphenatedCompounds;
  final Set<String> _unhyphenatedWords;

  /// Intact hyphenated compounds (e.g. 'happens-before', 'class-based').
  Set<String> get hyphenatedCompounds => Set.unmodifiable(_hyphenatedCompounds);

  /// Unhyphenated vocabulary (e.g. 'information', 'implementation').
  Set<String> get unhyphenatedWords => Set.unmodifiable(_unhyphenatedWords);

  /// Indexes intact hyphenated compounds and unhyphenated words from [text].
  void indexText(String text) {
    if (text.isEmpty) return;

    // Scan for intact hyphenated compounds on lines (not at line ends)
    final lines = text.split('\n');
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      // Extract intact hyphenated compounds
      final compoundMatches =
          RegExp(r'\b([A-Za-z0-9]+)-([A-Za-z0-9]+)\b').allMatches(line);
      for (final match in compoundMatches) {
        final p1 = match.group(1)!;
        final p2 = match.group(2)!;
        // Avoid line-end hyphens falsely indexed as intact
        if (match.end < line.length) {
          _hyphenatedCompounds.add('${p1.toLowerCase()}-${p2.toLowerCase()}');
        }
      }

      // Extract unhyphenated words (3+ alphabetical characters)
      final wordMatches = RegExp(r'\b[A-Za-z]{3,}\b').allMatches(line);
      for (final match in wordMatches) {
        _unhyphenatedWords.add(match.group(0)!.toLowerCase());
      }
    }
  }

  /// Indexes lines from a [PdfLineLayout] collection.
  void indexLines(Iterable<PdfLineLayout> lines) {
    for (final line in lines) {
      indexText(line.text);
    }
  }

  /// Returns true if the compound [part1]-[part2] was observed intact in the corpus.
  bool hasHyphenatedCompound(String part1, String part2) {
    return _hyphenatedCompounds.contains('${part1.toLowerCase()}-${part2.toLowerCase()}');
  }

  /// Returns true if [word] was observed unhyphenated in the corpus.
  bool hasUnhyphenatedWord(String word) {
    return _unhyphenatedWords.contains(word.toLowerCase());
  }
}

/// Service providing evidence-driven dehyphenation decisions.
///
/// Replaces arbitrary guessing and static prefix/suffix compound blacklists with
/// a three-tiered evidence hierarchy:
/// 1. Document Corpus Evidence: Check if the hyphenated compound or unhyphenated token
///    was observed intact elsewhere in the document.
/// 2. Standard Lexicon Lookup: Check if the joined token is an authentic English word
///    (e.g., `infor-` + `mation` -> `information`).
/// 3. Conservative Fallback: Default to preserving the hyphen when ambiguous,
///    capitalized, or containing mixed alphanumeric formatting (e.g. `Java-enabled`,
///    `UTF-8`, `class-based`).
class DehyphenationService {
  const DehyphenationService._();

  /// Evaluates whether to join [precedingWord] and [nextWord] or preserve the hyphen.
  static DehyphenationAction evaluate({
    required String precedingWord,
    required String nextWord,
    DocumentCorpus? corpus,
  }) {
    final p1 = precedingWord.trim();
    final p2 = nextWord.trim();
    if (p1.isEmpty || p2.isEmpty) {
      return DehyphenationAction.preserveHyphen;
    }

    // Rule 0: Numeric ranges (e.g. "20-" + "40" -> "20-40")
    if (RegExp(r'^\d+$').hasMatch(p1) && RegExp(r'^\d+').hasMatch(p2)) {
      return DehyphenationAction.preserveHyphen;
    }

    // Single-character prefix (e.g. "x-ray", "e-mail", "a-priori")
    if (p1.length == 1) {
      return DehyphenationAction.preserveHyphen;
    }

    final p1Lower = p1.toLowerCase();
    final p2Lower = p2.toLowerCase();
    final joined = '$p1$p2';
    final joinedLower = joined.toLowerCase();

    // Rule 3 (part a): Mixed capitalization / internal uppercase / numbers in word
    // e.g. "Java-enabled", "UTF-8", "x86-64", "Node-RED", "OAuth-based"
    final hasMixedOrSpecialCasing =
        (p1.length > 1 && RegExp('[A-Z]').hasMatch(p1.substring(1)) && !RegExp(r'^[A-Z]+$').hasMatch(p1)) ||
        (p2.length > 1 && RegExp('[A-Z]').hasMatch(p2.substring(1)) && !RegExp(r'^[A-Z]+$').hasMatch(p2)) ||
        (RegExp(r'^[A-Z]+$').hasMatch(p1) && p1.length >= 2) ||
        (RegExp(r'^[A-Z]+$').hasMatch(p2) && p2.length >= 2) ||
        RegExp(r'\d').hasMatch(p1) ||
        RegExp(r'\d').hasMatch(p2);

    if (hasMixedOrSpecialCasing) {
      if (!StandardLexicon.contains(joinedLower) &&
          !(corpus?.hasUnhyphenatedWord(joinedLower) ?? false)) {
        return DehyphenationAction.preserveHyphen;
      }
    }

    // Rule 2: Check if hyphenated compound appears elsewhere in document corpus
    if (corpus != null && corpus.hasHyphenatedCompound(p1Lower, p2Lower)) {
      return DehyphenationAction.preserveHyphen;
    }

    // Rule 1 (part a): Check if joined token appears unhyphenated elsewhere in document corpus
    if (corpus != null && corpus.hasUnhyphenatedWord(joinedLower)) {
      return DehyphenationAction.joinWithoutHyphen;
    }

    // Rule 1 (part b): Check if joined token exists in standard lexicon
    if (StandardLexicon.contains(joinedLower)) {
      return DehyphenationAction.joinWithoutHyphen;
    }

    // Rule 3 (part b): Default to preserving the hyphen if ambiguous
    // (e.g., "class-based", "happens-before", "lock-free", "fine-grained")
    return DehyphenationAction.preserveHyphen;
  }
}
