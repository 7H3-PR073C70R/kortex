import 'dart:math' as math;

import 'package:kortex/src/features/ingestion/data/services/synthesis/general_vocabulary.dart';

/// Role a piece of text plays in the document, used to weight the concepts
/// found in it.
enum ConceptSourceKind {
  /// Section headings: concepts named here are what the section is about.
  heading,

  /// Running prose, bullets and table cells.
  prose,

  /// A term the document explicitly defines (glossary entry, "X is a ...").
  definedTerm,
}

/// One unit of text fed into [ConceptInventory.build].
class ConceptSource {
  const ConceptSource(this.text, this.kind, {this.section = ''});

  final String text;
  final ConceptSourceKind kind;
  final String section;
}

/// A domain term the document is about.
class Concept {
  Concept._(this.key, this.wordCount, {required this.isIdentifier, required this.isAcronym});

  /// Normalized lookup key (lowercase, singular head).
  final String key;
  final int wordCount;
  final bool isIdentifier;
  final bool isAcronym;

  double _weight = 0;
  final Set<String> _sections = {};
  final Map<String, int> _casings = {};
  bool isDefined = false;
  bool inHeading = false;
  int mentions = 0;

  /// Relative importance in `[0, 1]`, filled in by [ConceptInventory.build].
  double score = 0;

  /// The most common non-sentence-initial spelling ("StableRef", "glycolysis"),
  /// or `null` when the concept only ever opens a sentence or heading.
  String? get surface {
    if (_casings.isEmpty) return null;
    return _casings.entries.reduce((a, b) => b.value > a.value ? b : a).key;
  }

  int get sectionCount => _sections.length;

  /// Whether the concept is a single everyday word ("collection", "check").
  bool get isGeneric =>
      wordCount == 1 && !isIdentifier && !isAcronym && GeneralVocabulary.isGeneral(key);
}

/// A concept occurrence inside a sentence.
class ConceptMention {
  const ConceptMention(this.concept, this.start, this.end, this.text);

  final Concept concept;
  final int start;
  final int end;

  /// The exact text as written in the sentence.
  final String text;
}

class _Token {
  const _Token(this.text, this.start, this.end, {required this.breakAfter});

  final String text;
  final int start;
  final int end;

  /// Punctuation directly after the token ends any phrase running through it.
  final bool breakAfter;
}

/// Document-level inventory of the concepts worth studying, ranked by how
/// central they are to the document.
///
/// Candidates are identifiers (`findAll()`, `StableRef`), acronyms (`GDPR`),
/// and noun phrases bounded by function words, verbs and punctuation in the
/// spirit of RAKE. Each is scored by frequency, how it is introduced
/// (defined, used as a heading), its form, and whether it is everyday
/// vocabulary. No model or network access is involved.
class ConceptInventory {
  ConceptInventory._(this._byKey, this.topicKeys);

  /// Builds the inventory for one document.
  ///
  /// [topicWords] are words naming the whole document (its title); they are
  /// valid concepts but too pervasive to be a useful answer.
  factory ConceptInventory.build(
    Iterable<ConceptSource> sources, {
    Set<String> topicWords = const {},
  }) {
    final byKey = <String, Concept>{};
    final sections = <String>{};

    void register(List<_Token> phrase, String sentence, ConceptSource source, {required bool initial}) {
      final text = sentence.substring(phrase.first.start, phrase.last.end);
      final key = normalize(text);
      if (key.length < 2) return;
      final concept = byKey.putIfAbsent(
        key,
        () => Concept._(
          key,
          phrase.length,
          isIdentifier: phrase.length == 1 && isIdentifier(text),
          isAcronym: phrase.length == 1 && isAcronym(text),
        ),
      );
      concept
        ..mentions += 1
        .._sections.add(source.section);
      final weight = switch (source.kind) {
        ConceptSourceKind.heading => 2.0,
        ConceptSourceKind.definedTerm => 3.0,
        ConceptSourceKind.prose => 1.0,
      };
      concept._weight += weight;
      if (source.kind == ConceptSourceKind.heading) concept.inHeading = true;
      if (source.kind == ConceptSourceKind.definedTerm) concept.isDefined = true;
      if (!initial || concept.isIdentifier || concept.isAcronym) {
        concept._casings.update(text, (v) => v + 1, ifAbsent: () => 1);
      }
    }

    for (final source in sources) {
      sections.add(source.section);
      for (final sentence in _sentencesOf(source.text)) {
        final tokens = _tokenize(sentence);
        for (final phrase in _phrases(tokens)) {
          final initial = phrase.first.start == tokens.first.start;
          register(phrase, sentence, source, initial: initial);
          // Shorter phrases sharing the head ("suspending functions" inside
          // "multiple suspending functions") are mentions too.
          for (var s = 1; s < phrase.length; s++) {
            register(phrase.sublist(s), sentence, source, initial: false);
          }
        }
      }
    }

    final totalSections = math.max(1, sections.length);
    final topicKeys = {for (final w in topicWords) normalize(w)}..removeWhere((k) => k.isEmpty);
    var maxRaw = 0.0;
    final raw = <Concept, double>{};
    for (final c in byKey.values) {
      var s = math.log(1 + c._weight);
      if (c.isIdentifier) s *= 1.6;
      if (c.isAcronym) s *= 1.4;
      if (c.wordCount > 1) s *= 1 + 0.2 * math.min(c.wordCount - 1, 3);
      if (c.isDefined) s *= 2.0;
      if (c.inHeading) s *= 1.5;
      if (c.isGeneric) s *= 0.2;
      if (c.wordCount > 1 && c.key.split(' ').every(GeneralVocabulary.isGeneral)) s *= 0.3;
      // Terms present in most sections are the document's backdrop, not its
      // content ("Kotlin" in the Kotlin reference).
      final spread = c.sectionCount / totalSections;
      if (totalSections >= 8 && spread > 0.25) s *= 0.5;
      if (topicKeys.contains(c.key)) s *= 0.3;
      raw[c] = s;
      if (s > maxRaw) maxRaw = s;
    }
    for (final entry in raw.entries) {
      entry.key.score = maxRaw == 0 ? 0 : entry.value / maxRaw;
    }
    return ConceptInventory._(byKey, topicKeys);
  }

  final Map<String, Concept> _byKey;

  /// Normalized keys of the document topic (title words).
  final Set<String> topicKeys;

  /// All concepts, most important first.
  List<Concept> get ranked => _byKey.values.toList()..sort((a, b) => b.score.compareTo(a.score));

  Concept? lookup(String phrase) => _byKey[normalize(phrase)];

  /// Importance of [phrase] in `[0, 1]`, or 0 when it is not a concept.
  double scoreOf(String phrase) => lookup(phrase)?.score ?? 0;

  /// Concept mentions in [sentence], longest match first, without overlaps.
  List<ConceptMention> mentionsIn(String sentence) {
    final tokens = _tokenize(sentence);
    final mentions = <ConceptMention>[];
    var i = 0;
    while (i < tokens.length) {
      ConceptMention? found;
      for (var n = math.min(_maxPhraseWords, tokens.length - i); n >= 1; n--) {
        // A phrase never spans punctuation.
        if (tokens.sublist(i, i + n - 1).any((t) => t.breakAfter)) continue;
        final text = sentence.substring(tokens[i].start, tokens[i + n - 1].end);
        final concept = _byKey[normalize(text)];
        if (concept != null) {
          found = ConceptMention(concept, tokens[i].start, tokens[i + n - 1].end, text);
          i += n;
          break;
        }
      }
      if (found != null) {
        mentions.add(found);
      } else {
        i++;
      }
    }
    return mentions;
  }

  static const _maxPhraseWords = 4;

  /// Lowercases, collapses whitespace and singularizes the head word.
  static String normalize(String phrase) {
    final words = phrase
        .trim()
        .replaceAll(RegExp(r'[“”"`*_]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '';
    final last = words.last;
    if (!isIdentifier(last) && !isAcronym(last)) {
      words[words.length - 1] = _singular(last.toLowerCase());
    }
    return words.map((w) => isIdentifier(w) ? w : w.toLowerCase()).join(' ');
  }

  static String _singular(String w) {
    if (w.length <= 3) return w;
    if (w.endsWith('ies') && w.length > 4) return '${w.substring(0, w.length - 3)}y';
    if (RegExp(r'(?:ss|sh|ch|x|z)es$').hasMatch(w)) return w.substring(0, w.length - 2);
    if (w.endsWith('s') && !RegExp(r'(?:ss|us|is|ous|ics)$').hasMatch(w)) {
      return w.substring(0, w.length - 1);
    }
    return w;
  }

  /// Code-like identifiers: `findAll()`, `StableRef`, `groupingBy`, `java.lang`,
  /// `snake_case`.
  static bool isIdentifier(String token) {
    if (token.endsWith('()') && token.length > 2) return true;
    if (RegExp(r'^[a-z]+[A-Z][A-Za-z0-9]*$').hasMatch(token)) return true;
    if (RegExp(r'^[A-Z][a-z0-9]+[A-Z][A-Za-z0-9]*$').hasMatch(token)) return true;
    if (RegExp(r'^[A-Za-z]\w*_\w+$').hasMatch(token)) return true;
    return RegExp(r'^[a-z][a-z0-9]*(?:\.[a-z][A-Za-z0-9]*)+$').hasMatch(token) &&
        !RegExp(r'^(?:e\.g|i\.e)$').hasMatch(token);
  }

  /// Acronyms such as `GDPR`, `JVM`, `ATP`, `NADH`, `APIs`.
  static bool isAcronym(String token) =>
      RegExp(r'^[A-Z][A-Z0-9]{1,6}s?$').hasMatch(token) && RegExp('[A-Z].*[A-Z]').hasMatch(token);

  static Iterable<String> _sentencesOf(String text) =>
      text.split(RegExp(r'(?<=[.!?])\s+(?=[A-Z“"(])|\n+')).map((s) => s.trim()).where((s) => s.isNotEmpty);

  static final _tokenRe = RegExp(r"[\p{L}\p{N}_][\p{L}\p{N}_'’\-.]*(?:\(\))?", unicode: true);

  static List<_Token> _tokenize(String sentence) {
    final tokens = <_Token>[];
    for (final m in _tokenRe.allMatches(sentence)) {
      var text = m.group(0)!;
      var end = m.end;
      // Trailing dots and possessives belong to the sentence, not the token.
      while (text.endsWith('.') || text.endsWith('-')) {
        text = text.substring(0, text.length - 1);
        end--;
      }
      if (text.isEmpty) continue;
      final rest = sentence.substring(end, math.min(sentence.length, end + 2));
      final breakAfter = rest.isNotEmpty && RegExp(r'^\s*[,;:.!?()\[\]{}"“”]').hasMatch(rest);
      tokens.add(_Token(text, m.start, end, breakAfter: breakAfter));
    }
    return tokens;
  }

  /// Splits [tokens] into candidate concept phrases.
  static Iterable<List<_Token>> _phrases(List<_Token> tokens) sync* {
    var run = <_Token>[];

    Iterable<List<_Token>> flush() sync* {
      final phrase = _trimPhrase(run);
      run = <_Token>[];
      if (phrase.isNotEmpty) yield phrase;
    }

    for (final token in tokens) {
      final t = token.text;
      if (isIdentifier(t)) {
        yield* flush();
        yield [token];
        continue;
      }
      final stop = GeneralVocabulary.isFunctionWord(t) ||
          GeneralVocabulary.isFiniteCommonVerb(t) ||
          GeneralVocabulary.isAdverb(t) ||
          RegExp(r'^[\d.,\-]+$').hasMatch(t) ||
          (t.length < 2) ||
          t.contains("'") ||
          t.contains('’');
      if (stop) {
        yield* flush();
        continue;
      }
      run.add(token);
      if (token.breakAfter || run.length > _maxPhraseWords + 2) yield* flush();
    }
    yield* flush();
  }

  /// Trims modifiers that cannot end or start a concept phrase and caps length.
  static List<_Token> _trimPhrase(List<_Token> run) {
    var phrase = List<_Token>.from(run);
    bool weakEdge(String w) =>
        GeneralVocabulary.isCommonAdjective(w) || GeneralVocabulary.isCommonVerb(w) && !w.endsWith('ing');
    while (phrase.isNotEmpty && weakEdge(phrase.first.text)) {
      phrase = phrase.sublist(1);
    }
    while (phrase.isNotEmpty &&
        (GeneralVocabulary.isCommonAdjective(phrase.last.text) ||
            GeneralVocabulary.isCommonVerb(phrase.last.text))) {
      phrase = phrase.sublist(0, phrase.length - 1);
    }
    if (phrase.length > _maxPhraseWords) phrase = phrase.sublist(phrase.length - _maxPhraseWords);
    return phrase;
  }
}
