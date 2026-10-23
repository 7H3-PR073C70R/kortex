import 'package:kortex/src/features/ingestion/data/services/synthesis/general_vocabulary.dart';

/// Decides whether a source sentence can stand on its own as study material.
///
/// A flashcard is reviewed weeks later without the surrounding page, so a
/// sentence that leans on its neighbours ("these anti-patterns", "as explained
/// above"), talks about the document itself ("this chapter delves into"),
/// instructs the reader ("Spread the word"), or is a broken extraction
/// fragment produces a card nobody can answer.
class SentenceQuality {
  const SentenceQuality._();

  static const minWords = 6;
  static const maxWords = 40;

  /// Returns why [sentence] is unusable, or `null` when it is self-contained.
  static String? rejectionReason(String sentence) {
    final s = sentence.trim();
    final words = s.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length < minWords) return 'too_short';
    if (words.length > maxWords) return 'too_long';
    if (!RegExp(r'^[\p{Lu}\p{N}`]', unicode: true).hasMatch(s)) return 'not_capitalized';
    if (!RegExp(r'[.!]["”)]?$').hasMatch(s)) return 'unterminated';
    if (_leadingDependency.hasMatch(s)) return 'leading_dependency';
    if (_externalReference.hasMatch(s)) return 'external_reference';
    if (_metaText.hasMatch(s)) return 'meta_text';
    if (_isImperative(words)) return 'imperative';
    if (_extractionDamage.hasMatch(s)) return 'extraction_damage';
    if (RegExp(r':\s+\p{Lu}', unicode: true).hasMatch(s) && !RegExp(r'^\S+:').hasMatch(s)) {
      return 'list_lead_in';
    }
    // Long sentences almost always have a predicate the lexicon may not know.
    if (words.length < 10 && !_hasFiniteVerb(words)) return 'no_verb';
    final letters = RegExp(r'\p{L}', unicode: true).allMatches(s).length;
    if (letters / s.length < 0.6) return 'symbol_heavy';
    return null;
  }

  static bool isSelfContained(String sentence) => rejectionReason(sentence) == null;

  /// Soft quality in `(0, 1]` for sentences that pass [rejectionReason]:
  /// prefers 10-25 words and few parenthetical cross-references.
  static double score(String sentence) {
    final words = sentence.trim().split(RegExp(r'\s+')).length;
    var q = 1.0;
    if (words < 9) q *= 0.8;
    if (words > 28) q *= 0.75;
    q *= 1 / (1 + 0.3 * '('.allMatches(sentence).length);
    if (sentence.contains('§')) q *= 0.7;
    return q;
  }

  // Openers that only make sense after the previous sentence.
  static final _leadingDependency = RegExp(
    r'^(?:it|this|that|these|those|they|them|their|its|he|she|his|her|such|both|here|there|which|who|'
    r'also|so|then|thus|hence|however|therefore|moreover|furthermore|additionally|similarly|likewise|'
    r'consequently|instead|otherwise|nevertheless|nonetheless|meanwhile|finally|next|now|again|still|'
    r'in\s+addition|in\s+contrast|in\s+other\s+words|in\s+this|in\s+that|in\s+these|in\s+such|'
    r'as\s+(?:explained|mentioned|described|shown|discussed|noted|seen|stated|we|you)|'
    r'for\s+(?:example|instance|this|that|these)|by\s+(?:doing|contrast)\s+(?:so|this)|'
    r'on\s+the\s+other\s+hand|at\s+this\s+point|to\s+do\s+(?:so|this)|unlike\s+(?:this|that)|'
    r"let's|let\s+us|note|remember|recall|see|keep\s+in\s+mind|ultimately|overall|in\s+summary|"
    r'in\s+conclusion|to\s+summarize|to\s+recap|first|second|third|lastly|later|above|below)\b',
    caseSensitive: false,
  );

  // References that point outside the sentence.
  static final _externalReference = RegExp(
    r'\b(?:th(?:is|ese|ose)\s+(?:\w+\s+)?(?:chapter|section|example|examples|book|guide|tutorial|page|article|'
    r'code|snippet|approach|case|cases|one|ones|pattern|patterns|feature|features|issue|issues|method|'
    r'methods|step|steps|tool|tools|question|questions|point|points|technique|techniques|anti-patterns?|'
    r'things|scenario|scenarios|estimate|setup|change|changes|option|options|function|functions|class|'
    r'classes|type|types|rule|rules|value|values|problem|problems|figure|table|list|way|ways|kind)|'
    r'the\s+(?:following|above|previous|preceding|next|latter|former|same)\b|'
    r'(?:shown|listed|described|discussed|mentioned|explained|defined|illustrated)\s+(?:above|below|earlier|later|previously|before)|'
    r'as\s+follows|aforementioned|(?:above|below)\s+(?:example|code|figure|table|snippet)|'
    r'in\s+the\s+(?:example|snippet|code\s+above|code\s+below|figure|table)\b|'
    r'(?:figure|fig\.|table|listing|example)\s+\d|'
    r'\b(?:here|there)\s+(?:is|are)\b)',
    caseSensitive: false,
  );

  // Text about the document, the author or the reader's journey.
  static final _metaText = RegExp(
    r"\b(?:we(?:'ll|\s+will|\s+have|'ve|\s+are\s+going)|i\s+(?:will|have|think|believe|recommend)|"
    r"you(?:'ll|\s+will)\s+(?:learn|see|find|discover|explore)|in\s+this\s+(?:book|chapter|section|guide|tutorial|article|document|course|page)|"
    r'this\s+(?:book|chapter|section|guide|tutorial|article|document|course)\b|'
    r'(?:read|learn)\s+more|for\s+more\s+(?:details|information|info)|refer\s+to|check\s+out|click|'
    r'good\s+luck|stay\s+tuned|the\s+author|my\s+|our\s+(?:team|book|guide)|'
    r'(?:previous|next|following|upcoming|last)\s+(?:chapter|section|lesson|part))',
    caseSensitive: false,
  );

  // Interleaved columns, glued tokens, dangling cross-references.
  static final _extractionDamage = RegExp(
    r'[a-z]\.[A-Z][a-z]|\d\.[A-Z][a-z]|\b[a-z]{2,}[A-Z]\b|\ba\s+[A-Z][a-z]+\s+\d+(?:\.\d+)+|'
    r'\s[,.;:]\s|\(\s*\)|\.\.\.|…|_{3,}|\s{2,}\S\s{2,}',
  );

  static const _determiners = {
    'the', 'a', 'an', 'your', 'this', 'these', 'those', 'it', 'them', 'all',
    'any', 'each', 'some', 'that', 'our', 'its', 'their', 'every', 'one', 'out',
    'up', 'more', 'sure', 'to', 'with', 'on', 'in', 'at', 'for', 'from',
  };

  /// "Spread the word...", "Read the docs...", "Add the content of ...".
  static bool _isImperative(List<String> words) {
    if (words.length < 2) return false;
    final first = words[0].toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    final second = words[1].toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    if (first.isEmpty || first.endsWith('s') || first.endsWith('ing') || first.endsWith('ed')) return false;
    if (!GeneralVocabulary.isCommonVerb(first)) return false;
    return _determiners.contains(second) || GeneralVocabulary.isAdverb(second);
  }

  static const _auxiliaries = {
    'is', 'are', 'was', 'were', 'be', 'been', 'has', 'have', 'had', 'can',
    'cannot', 'could', 'will', 'would', 'shall', 'should', 'may', 'might',
    'must', 'does', 'do', 'did', "isn't", "aren't", "doesn't", "don't",
    "can't", "won't", 'isn’t', 'aren’t', 'doesn’t', 'don’t', 'can’t', 'won’t',
  };

  static bool _hasFiniteVerb(List<String> words) {
    for (var i = 0; i < words.length; i++) {
      final w = words[i].toLowerCase().replaceAll(RegExp(r'[^a-z’\x27]'), '');
      if (_auxiliaries.contains(w)) return true;
      if (i == 0) continue;
      if (GeneralVocabulary.isFunctionWord(w)) continue;
      // Inflected or plural-subject forms of a known verb ("provides", "created", "emit").
      if (GeneralVocabulary.looksLikeVerb(w) && !w.endsWith('ing')) return true;
      // Unknown words with typical verb morphology after a noun.
      if (RegExp(r'(?:ates|izes|ises|ifies|ects|ains|ires|ores|ols|ows|uces|ides|ines|ses)$').hasMatch(w) &&
          !GeneralVocabulary.isGenericNoun(w)) {
        return true;
      }
    }
    return false;
  }
}
