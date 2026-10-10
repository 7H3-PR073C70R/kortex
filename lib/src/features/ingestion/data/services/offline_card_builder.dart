import 'dart:math' as math;

import 'package:kortex/src/features/ingestion/data/models/ocr_extraction_model.dart';

/// The kind of card produced by [OfflineCardBuilder].
enum OfflineCardType { qa, glossary, definition, formula, list, code, cloze }

/// A card built offline together with the type that produced it.
class OfflineCard {
  const OfflineCard({
    required this.type,
    required this.front,
    required this.back,
    required this.confidence,
  });

  final OfflineCardType type;
  final String front;
  final String back;
  final double confidence;
}

/// Deterministic, source-faithful flashcard builder used when the AI server
/// is unavailable.
///
/// Guarantee: the back of every card is text taken from the source document
/// and the front is either `What is <term>?` (term taken from the source),
/// a heading-based prompt quoting a source heading, or a cloze sentence from
/// the source. No sentence is ever invented.
class OfflineCardBuilder {
  const OfflineCardBuilder({this.maxCards = 150});

  final int maxCards;

  static const _minClozeWords = 8;
  static const _maxClozeWords = 35;
  static const _maxClozePerSection = 4;
  static const _maxDefinitionBackChars = 320;

  /// Builds cards from [fullText]. Returns an empty list when nothing in the
  /// text can be turned into a trustworthy card.
  List<OfflineCard> buildCards(String fullText) {
    final blocks = _parseBlocks(fullText);
    if (blocks.isEmpty) return const [];

    final termFrequency = _termFrequency(blocks);

    final structured = <OfflineCard>[];
    final clozeCandidates = <_ClozeCandidate>[];
    final clozePerSection = <String, int>{};

    String? heading;
    var sectionHasCard = false;
    final pendingList = <_Block>[];

    void flushList() {
      final card = _listCard(heading, pendingList);
      if (card != null) {
        structured.add(card);
        sectionHasCard = true;
      }
      pendingList.clear();
    }

    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      if (block.kind != _BlockKind.bullet) flushList();

      switch (block.kind) {
        case _BlockKind.heading:
          heading = block.text;
          sectionHasCard = false;
        case _BlockKind.qa:
          sectionHasCard = true;
          structured.add(
            OfflineCard(
              type: OfflineCardType.qa,
              front: block.term!,
              back: block.text,
              confidence: 0.9,
            ),
          );
        case _BlockKind.glossary:
          sectionHasCard = true;
          structured.add(_glossaryCard(block));
        case _BlockKind.formula:
          sectionHasCard = true;
          structured.add(
            OfflineCard(
              type: OfflineCardType.formula,
              front: 'Formula: ${block.term}',
              back: block.text,
              confidence: 0.75,
            ),
          );
        case _BlockKind.bullet:
          pendingList.add(block);
        case _BlockKind.code:
          final label = _codeLabel(blocks, i, heading);
          if (label != null) {
            sectionHasCard = true;
            structured.add(
              OfflineCard(
                type: OfflineCardType.code,
                front: 'Code: $label',
                back: block.text,
                confidence: 0.7,
              ),
            );
          }
        case _BlockKind.paragraph:
          final sentences = _splitSentences(block.text);
          final consumed = <int>{};
          for (var s = 0; s < sentences.length; s++) {
            if (consumed.contains(s)) continue;
            final def = _definitionCard(sentences, s);
            if (def != null) {
              structured.add(def.card);
              consumed.addAll(def.consumed);
              sectionHasCard = true;
            }
          }
          final overview = sectionHasCard
              ? null
              : _sectionOverviewCard(heading, block.text);
          if (overview != null) {
            structured.add(overview);
            sectionHasCard = true;
          }
          final sectionKey = heading ?? '';
          for (var s = 0; s < sentences.length; s++) {
            if (consumed.contains(s)) continue;
            final cloze = _clozeCandidate(
              sentences[s],
              termFrequency,
              clozeCandidates.length,
            );
            if (cloze == null) continue;
            if (heading != null) {
              final used = clozePerSection[sectionKey] ?? 0;
              if (used >= _maxClozePerSection) continue;
              clozePerSection[sectionKey] = used + 1;
            }
            clozeCandidates.add(cloze);
          }
      }
    }
    flushList();

    return _assemble(structured, clozeCandidates);
  }

  // ---------------------------------------------------------------------------
  // Assembly
  // ---------------------------------------------------------------------------

  List<OfflineCard> _assemble(
    List<OfflineCard> structured,
    List<_ClozeCandidate> clozes,
  ) {
    final seen = <String>{};
    final result = <OfflineCard>[];

    String norm(String s) =>
        s.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');

    for (final card in structured) {
      if (result.length >= maxCards) break;
      if (seen.add(norm(card.front))) result.add(card);
    }

    final room = maxCards - result.length;
    if (room > 0 && clozes.isNotEmpty) {
      // Sample evenly across the document so coverage is not biased toward
      // one chapter when there are more candidates than room.
      final chosen = clozes.length <= room
          ? clozes
          : [
              for (var k = 0; k < room; k++)
                clozes[(k * clozes.length) ~/ room],
            ];
      for (final c in chosen) {
        if (seen.add(norm(c.card.front))) result.add(c.card);
      }
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Parsing
  // ---------------------------------------------------------------------------

  static final _bulletRe = RegExp(
    r'^([-•*●▪◦]|\d{1,2}[.)]|[a-z][.)])\s+(\S.*)$',
  );
  static final _orderedRe = RegExp(r'^\d{1,2}[.)]\s');
  static final _markdownHeadingRe = RegExp(r'^#{1,6}\s+(\S.*)$');
  static final _numberedHeadingRe = RegExp(
    r'^\d+(?:\.\d+)+\.?\s+([A-Z].{2,70})$',
  );
  static final _keywordHeadingRe = RegExp(
    r'^(?:chapter|section|part|unit|module|lesson)\s+(?:\d+|[ivxlcdm]+)\b.*$',
    caseSensitive: false,
  );
  static final _pageNoiseRe = RegExp(
    r'^(?:page\s+\d+(?:\s+of\s+\d+)?|\d{1,4}|[-–—_=*\s]{3,})$',
    caseSensitive: false,
  );
  static final _glossaryRe = RegExp(
    r'^[-•*●▪◦]?\s*\**([A-Za-z0-9][^:\n–—]{1,50}?)\**\s*(?::\s|\s[–—-]\s)\s*\**(\S.{10,})$',
  );
  static const _metaLabels = {
    'note',
    'tip',
    'tips',
    'example',
    'examples',
    'warning',
    'caution',
    'important',
    'summary',
    'overview',
    'step',
    'answer',
    'question',
    'hint',
  };
  static const _glossaryBannedTermWords = {
    'is',
    'are',
    'was',
    'were',
    'has',
    'have',
    'had',
    'will',
    'can',
    'should',
    'must',
    'does',
    'do',
    'shall',
    'may',
    'we',
    'you',
    'i',
    'it',
    'they',
  };
  static const _tocLeadWords = {
    'step',
    'stage',
    'phase',
    'part',
    'chapter',
    'section',
    'unit',
    'figure',
    'fig',
    'table',
    'page',
    'week',
    'day',
    'level',
    'rule',
    'lesson',
    'module',
    'question',
    'q',
    'no',
    'number',
  };

  List<_Block> _parseBlocks(String text) {
    final rawLines = text.replaceAll('\r\n', '\n').split('\n');
    final lines = _dropNoise(rawLines);

    final blocks = <_Block>[];
    final paragraph = <String>[];

    void flushParagraph() {
      if (paragraph.isEmpty) return;
      final joined = _joinWrapped(paragraph);
      paragraph.clear();
      if (joined.length >= 20) {
        blocks.add(_Block(_BlockKind.paragraph, joined));
      }
    }

    // Appends PDF-wrapped continuation lines to a bullet/glossary body.
    // Returns the merged body and the index of the last line consumed.
    (String, int) absorb(int index, String body) {
      var merged = body;
      var last = index;
      while (last + 1 < lines.length) {
        final next = lines[last + 1].trim();
        if (next.isEmpty ||
            next.startsWith('```') ||
            _bulletRe.hasMatch(next) ||
            _headingText(next, false) != null) {
          break;
        }
        final glossaryNext = _glossaryRe.firstMatch(next);
        if (glossaryNext != null && _isGlossaryTerm(glossaryNext.group(1)!)) {
          break;
        }
        final unfinished = !RegExp(r'[.!?:"”)]$').hasMatch(merged);
        if (!unfinished && !RegExp('^[a-z]').hasMatch(next)) break;
        merged = '$merged ${_cleanInline(next)}';
        last++;
      }
      return (merged, last);
    }

    var i = 0;
    var previousBlank = true;
    while (i < lines.length) {
      final line = lines[i].trim();

      if (line.isEmpty) {
        flushParagraph();
        previousBlank = true;
        i++;
        continue;
      }

      if (line.startsWith('```')) {
        flushParagraph();
        final code = <String>[line];
        i++;
        while (i < lines.length && !lines[i].trim().startsWith('```')) {
          code.add(lines[i].trimRight());
          i++;
        }
        if (i < lines.length) code.add(lines[i].trim());
        i++;
        blocks.add(_Block(_BlockKind.code, code.join('\n')));
        previousBlank = true;
        continue;
      }

      final qa = _matchQa(lines, i);
      if (qa != null) {
        flushParagraph();
        blocks.add(_Block(_BlockKind.qa, qa.answer, term: qa.question));
        previousBlank = false;
        i = qa.lastIndex + 1;
        continue;
      }

      if (_isFormulaLine(line)) {
        String? lead;
        if (paragraph.isNotEmpty) {
          lead = paragraph.removeLast();
          flushParagraph();
        } else if (blocks.isNotEmpty &&
            blocks.last.kind == _BlockKind.heading) {
          lead = blocks.last.text;
        }
        if (lead != null && _wordCount(lead) <= 25) {
          blocks.add(
            _Block(
              _BlockKind.formula,
              line,
              term: lead.replaceFirst(RegExp(r'\s*:\s*$'), ''),
            ),
          );
          previousBlank = false;
          i++;
          continue;
        }
        if (lead != null) paragraph.add(lead);
      }

      final headingText = _headingText(line, previousBlank);
      if (headingText != null) {
        flushParagraph();
        blocks.add(_Block(_BlockKind.heading, _cleanInline(headingText)));
        previousBlank = false;
        i++;
        continue;
      }

      final glossary = _glossaryRe.firstMatch(line);
      if (glossary != null) {
        final term = _cleanInline(glossary.group(1)!).replaceFirst(
          RegExp(r'^(?:\d{1,2}[.)]|[•\-*●▪◦])\s*'),
          '',
        );
        if (_isGlossaryTerm(term)) {
          flushParagraph();
          final (body, last) = absorb(i, _cleanInline(glossary.group(2)!));
          blocks.add(_Block(_BlockKind.glossary, body, term: term));
          previousBlank = false;
          i = last + 1;
          continue;
        }
      }

      final bullet = _bulletRe.firstMatch(line);
      if (bullet != null) {
        flushParagraph();
        final ordered = _orderedRe.hasMatch(line);
        final (body, last) = absorb(i, _cleanInline(bullet.group(2)!));
        blocks.add(
          _Block(
            _BlockKind.bullet,
            body,
            ordered: ordered,
            marker: bullet.group(1),
          ),
        );
        previousBlank = false;
        i = last + 1;
        continue;
      }

      paragraph.add(_cleanInline(line));
      previousBlank = false;
      i++;
    }
    flushParagraph();
    return blocks;
  }

  /// Removes page numbers, separators, table-of-contents runs and lines that
  /// repeat across the document (running headers / footers).
  List<String> _dropNoise(List<String> rawLines) {
    final trimmed = rawLines.map((l) => l.trim()).toList();

    final counts = <String, int>{};
    for (final l in trimmed) {
      if (l.isEmpty || l.length > 80) continue;
      counts.update(l.toLowerCase(), (v) => v + 1, ifAbsent: () => 1);
    }
    final isLong = trimmed.length > 30;

    bool isTocLine(String l) {
      if (l.isEmpty) return false;
      if (RegExp(
        r'\.{3,}\s*(?:\d{1,4}|[ivxlcdm]{1,8})$',
        caseSensitive: false,
      ).hasMatch(l))
        return true;
      final m = RegExp(
        r'^(.{2,}?)\s+(?:\d{1,4}|[ivxlcdm]{1,8})$',
        caseSensitive: false,
      ).firstMatch(l);
      if (m == null) return false;
      final lead = m.group(1)!.trim();
      final words = lead.split(RegExp(r'\s+'));
      if (words.length > 10) return false;
      return !_tocLeadWords.contains(words.last.toLowerCase());
    }

    final drop = List<bool>.filled(trimmed.length, false);

    var i = 0;
    while (i < trimmed.length) {
      if (isTocLine(trimmed[i])) {
        var j = i;
        while (j < trimmed.length &&
            (isTocLine(trimmed[j]) || trimmed[j].isEmpty)) {
          j++;
        }
        final run = trimmed.sublist(i, j).where(isTocLine).length;
        if (run >= 3) {
          for (var k = i; k < j; k++) {
            drop[k] = true;
          }
        }
        i = j == i ? i + 1 : j;
      } else {
        i++;
      }
    }

    final out = <String>[];
    for (var k = 0; k < rawLines.length; k++) {
      final l = trimmed[k];
      if (drop[k] ||
          (_pageNoiseRe.hasMatch(l) && l.isNotEmpty) ||
          (isLong && l.isNotEmpty && (counts[l.toLowerCase()] ?? 0) >= 3)) {
        out.add('');
      } else {
        out.add(rawLines[k]);
      }
    }
    return out;
  }

  static final _qaInlineRe = RegExp(
    r'^Q(?:uestion)?\s*[:.)]\s*(.+?\?)\s*A(?:nswer)?\s*[:.)]\s*(\S.*)$',
    caseSensitive: false,
  );
  static final _qaQuestionRe = RegExp(
    r'^Q(?:uestion)?\s*[:.)]\s*(\S.*)$',
    caseSensitive: false,
  );
  static final _qaAnswerRe = RegExp(
    r'^A(?:nswer)?\s*[:.)]\s*(\S.*)$',
    caseSensitive: false,
  );

  _QaMatch? _matchQa(List<String> lines, int i) {
    final line = lines[i].trim();
    final inline = _qaInlineRe.firstMatch(line);
    if (inline != null) {
      return _QaMatch(
        _cleanInline(inline.group(1)!),
        _cleanInline(inline.group(2)!),
        i,
      );
    }
    final q = _qaQuestionRe.firstMatch(line);
    if (q == null || i + 1 >= lines.length) return null;
    final a = _qaAnswerRe.firstMatch(lines[i + 1].trim());
    if (a == null) return null;
    var answer = _cleanInline(a.group(1)!);
    var last = i + 1;
    while (last + 1 < lines.length) {
      final next = lines[last + 1].trim();
      if (next.isEmpty ||
          _qaQuestionRe.hasMatch(next) ||
          _bulletRe.hasMatch(next) ||
          RegExp(r'[.!?]$').hasMatch(answer)) {
        break;
      }
      answer = '$answer ${_cleanInline(next)}';
      last++;
    }
    return _QaMatch(_cleanInline(q.group(1)!), answer, last);
  }

  static final _latexCommandRe = RegExp(
    r'\\(?:frac|lim|sum|int|sqrt|prod|alpha|beta|gamma|theta|sigma|omega|partial)\b',
  );
  static final _equationRe = RegExp(
    r'^[A-Za-z][A-Za-z0-9_()^]{0,14}\s*=\s*\S.*$',
  );

  bool _isFormulaLine(String line) {
    if (_latexCommandRe.hasMatch(line)) return true;
    if (!_equationRe.hasMatch(line)) return false;
    if (_wordCount(line) > 12 || _endsSentence(line)) return false;
    return RegExp(r'[\^+*/\d]|\\').hasMatch(line.split('=').last);
  }

  String? _headingText(String line, bool previousBlank) {
    final md = _markdownHeadingRe.firstMatch(line);
    if (md != null) return md.group(1);

    final numbered = _numberedHeadingRe.firstMatch(line);
    if (numbered != null && _wordCount(line) <= 12 && !_endsSentence(line)) {
      return line;
    }

    if (_keywordHeadingRe.hasMatch(line) &&
        _wordCount(line) <= 12 &&
        !_endsSentence(line)) {
      return line;
    }

    final letters = line.replaceAll(RegExp('[^A-Za-z]'), '');
    if (letters.length >= 4 &&
        letters == letters.toUpperCase() &&
        _wordCount(line) <= 8 &&
        !_endsSentence(line) &&
        !_bulletRe.hasMatch(line)) {
      return line;
    }

    if (previousBlank &&
        _wordCount(line) <= 8 &&
        RegExp(r'^[A-Z]').hasMatch(line) &&
        !RegExp(r'[.!?,;:]$').hasMatch(line) &&
        !_bulletRe.hasMatch(line) &&
        !RegExp(r'^\d').hasMatch(line)) {
      return line;
    }
    return null;
  }

  bool _isGlossaryTerm(String raw) {
    final term = _cleanInline(raw).trim();
    if (term.isEmpty || term.endsWith('.')) return false;
    final words = term.split(RegExp(r'\s+'));
    if (words.length > 5) return false;
    if (_metaLabels.contains(term.toLowerCase())) return false;
    if (!RegExp(r'^[A-Z0-9]').hasMatch(term)) return false;
    return !words.any(
      (w) => _glossaryBannedTermWords.contains(w.toLowerCase()),
    );
  }

  /// Joins wrapped lines, repairing words hyphenated at a line break.
  String _joinWrapped(List<String> lines) {
    final buffer = StringBuffer();
    for (final line in lines) {
      if (buffer.isEmpty) {
        buffer.write(line);
      } else if (RegExp(r'[a-z]-$').hasMatch(buffer.toString()) &&
          RegExp('^[a-z]').hasMatch(line)) {
        final current = buffer.toString();
        buffer
          ..clear()
          ..write(current.substring(0, current.length - 1))
          ..write(line);
      } else {
        buffer
          ..write(' ')
          ..write(line);
      }
    }
    return buffer.toString().replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  }

  /// Strips emphasis markers only; every other character is preserved.
  String _cleanInline(String s) => s
      .replaceAllMapped(RegExp(r'(\*\*|__)(.+?)\1'), (m) => m.group(2)!)
      .replaceAllMapped(
        RegExp(r'\\([\\`*_{}\[\]()#+\-.!|<>~])'),
        (m) => m.group(1)!,
      )
      .replaceAll('ﬁ', 'fi')
      .replaceAll('ﬂ', 'fl')
      .trim();

  int _wordCount(String s) =>
      s.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

  bool _endsSentence(String s) => RegExp(r'[.!?]["”)]?$').hasMatch(s.trim());

  // ---------------------------------------------------------------------------
  // Card builders
  // ---------------------------------------------------------------------------

  OfflineCard _glossaryCard(_Block block) => OfflineCard(
    type: OfflineCardType.glossary,
    front: 'What is ${block.term}?',
    back: block.text,
    confidence: 0.85,
  );

  /// Heading + short body with nothing more specific to ask: quote the
  /// heading and give the verbatim body.
  OfflineCard? _sectionOverviewCard(String? heading, String body) {
    if (heading == null || body.length > _maxDefinitionBackChars + 80) {
      return null;
    }
    final title = heading
        .replaceFirst(RegExp(r'^\d+(?:\.\d+)*[.)]?\s+'), '')
        .trim();
    if (title.length < 3) return null;
    return OfflineCard(
      type: OfflineCardType.list,
      front: 'What does "$title" cover?',
      back: body,
      confidence: 0.6,
    );
  }

  OfflineCard? _listCard(String? heading, List<_Block> items) {
    if (heading == null || items.length < 2) return null;
    final ordered = items.every((b) => b.ordered);
    final back = [
      for (var i = 0; i < items.length; i++)
        ordered ? '${items[i].marker} ${items[i].text}' : '• ${items[i].text}',
    ].join('\n');
    if (back.length > 700) return null;
    return OfflineCard(
      type: OfflineCardType.list,
      front: ordered
          ? 'What are the steps in "$heading", in order?'
          : 'What are the key points of "$heading"?',
      back: back,
      confidence: 0.7,
    );
  }

  String? _codeLabel(List<_Block> blocks, int index, String? heading) {
    if (index > 0) {
      final prev = blocks[index - 1];
      if ((prev.kind == _BlockKind.heading ||
              prev.kind == _BlockKind.paragraph) &&
          _wordCount(prev.text) <= 8) {
        return prev.text.replaceFirst(
          RegExp(r'^(?:example|code)\s*:\s*', caseSensitive: false),
          '',
        );
      }
    }
    return heading;
  }

  static final _definitionRe = RegExp(
    r'^(.{2,60}?)\s+(is defined as|is known as|is called|refers to|means|states that|occurs in|occurs at|is|are)\s+(.{8,})$',
    dotAll: true,
  );
  static final _copulaObjectRe = RegExp(
    r'^(?:a|an|the|any|one|each|used|called|known|defined|composed|made|formed|when|where)\b',
  );
  static const _badSubjectStarts = {
    'it',
    'this',
    'that',
    'these',
    'those',
    'they',
    'there',
    'he',
    'she',
    'we',
    'you',
    'which',
    'what',
    'who',
    'here',
    'such',
    'both',
    'some',
    'many',
  };
  static const _subjectBannedWords = {
    'is',
    'are',
    'was',
    'were',
    'has',
    'have',
    'had',
    'can',
    'will',
    'shall',
    'may',
    'does',
    'do',
    'because',
    'although',
    'while',
    'if',
    'when',
  };

  _DefinitionResult? _definitionCard(List<String> sentences, int index) {
    final sentence = sentences[index];
    final m = _definitionRe.firstMatch(sentence);
    if (m == null) return null;
    final verb = m.group(2)!;
    if ((verb == 'is' || verb == 'are') &&
        !_copulaObjectRe.hasMatch(m.group(3)!)) {
      return null;
    }

    var subject = m.group(1)!.trim();
    final words = subject.split(RegExp(r'\s+'));
    if (words.length > 6) return null;
    if (!RegExp(r'^[A-Z]').hasMatch(subject)) return null;
    if (_badSubjectStarts.contains(words.first.toLowerCase())) return null;
    if (words.any((w) => _subjectBannedWords.contains(w.toLowerCase()))) {
      return null;
    }
    if (RegExp(r'[,;:()]').hasMatch(subject)) return null;

    subject = subject.replaceFirst(
      RegExp(r'^(?:the|a|an)\s+', caseSensitive: false),
      '',
    );
    if (subject.length < 2) return null;

    final plural = verb == 'are';

    final consumed = <int>{index};
    var back = sentence;
    if (index + 1 < sentences.length) {
      final next = sentences[index + 1];
      if (back.length + next.length + 1 <= _maxDefinitionBackChars &&
          !_definitionRe.hasMatch(next)) {
        back = '$back $next';
        consumed.add(index + 1);
      }
    }

    return _DefinitionResult(
      OfflineCard(
        type: OfflineCardType.definition,
        front: switch (verb) {
          'states that' => 'What does $subject state?',
          'occurs in' || 'occurs at' => 'Where does $subject occur?',
          _ => plural ? 'What are $subject?' : 'What is $subject?',
        },
        back: back,
        confidence: 0.8,
      ),
      consumed,
    );
  }

  // ---------------------------------------------------------------------------
  // Cloze
  // ---------------------------------------------------------------------------

  static const _stopWords = {
    'about',
    'above',
    'after',
    'again',
    'also',
    'among',
    'because',
    'been',
    'before',
    'being',
    'between',
    'both',
    'could',
    'does',
    'during',
    'each',
    'from',
    'have',
    'into',
    'more',
    'most',
    'must',
    'other',
    'over',
    'same',
    'should',
    'since',
    'some',
    'such',
    'than',
    'that',
    'their',
    'them',
    'then',
    'there',
    'these',
    'they',
    'this',
    'those',
    'through',
    'under',
    'until',
    'upon',
    'using',
    'very',
    'were',
    'what',
    'when',
    'where',
    'which',
    'while',
    'will',
    'with',
    'within',
    'without',
    'would',
    'your',
    'only',
    'many',
    'often',
    'usually',
    'well',
    'just',
    'like',
    'make',
    'makes',
    'made',
    'used',
    'uses',
    'take',
    'takes',
    'place',
    'first',
    'second',
    'third',
    'every',
    'either',
    'neither',
    'however',
    'therefore',
  };

  Map<String, int> _termFrequency(List<_Block> blocks) {
    final freq = <String, int>{};
    for (final b in blocks) {
      if (b.kind == _BlockKind.code) continue;
      for (final w in _tokens(b.text)) {
        freq.update(w.toLowerCase(), (v) => v + 1, ifAbsent: () => 1);
      }
    }
    return freq;
  }

  Iterable<String> _tokens(String text) => RegExp(
    r"[A-Za-z][A-Za-z0-9'’\-]*[A-Za-z0-9]|[A-Z]{2,}",
  ).allMatches(text).map((m) => m.group(0)!);

  _ClozeCandidate? _clozeCandidate(
    String sentence,
    Map<String, int> freq,
    int order,
  ) {
    final words = _wordCount(sentence);
    if (words < _minClozeWords || words > _maxClozeWords) return null;
    if (!RegExp(r'^[A-Z]').hasMatch(sentence)) return null;
    if (!RegExp(r'[.!?]$').hasMatch(sentence)) return null;
    if (sentence.endsWith('?')) return null;
    if (RegExp(r'https?://|www\.').hasMatch(sentence)) return null;
    if (!_looksLikeProse(sentence)) return null;

    String? best;
    var bestScore = 0.0;
    final matches = RegExp(
      r"[A-Za-z][A-Za-z0-9'’\-]*[A-Za-z0-9]|[A-Z]{2,}",
    ).allMatches(sentence);
    for (final m in matches) {
      final word = m.group(0)!;
      final lower = word.toLowerCase();
      if (word.length < 4 && !RegExp(r'^[A-Z]{2,}$').hasMatch(word)) continue;
      if (_stopWords.contains(lower)) continue;

      var score = math.log(1 + word.length);
      final midSentence = m.start > 0;
      if (RegExp(r'^[A-Z]{2,}[a-z0-9]*$').hasMatch(word)) {
        score *= 2.2; // acronym
      } else if (midSentence && RegExp(r'^[A-Z]').hasMatch(word)) {
        score *= 1.8; // proper / technical noun
      } else if (RegExp(r'\d').hasMatch(word)) {
        score *= 1.5;
      }
      if ((freq[lower] ?? 1) >= 2) score *= 1.4;
      if (score > bestScore) {
        bestScore = score;
        best = word;
      }
    }
    if (best == null) return null;

    final blank = sentence.replaceFirst(
      RegExp('\\b${RegExp.escape(best)}\\b'),
      '_____',
    );
    if (blank == sentence) return null;

    return _ClozeCandidate(
      card: OfflineCard(
        type: OfflineCardType.cloze,
        front: blank,
        back: '$best\n\n$sentence',
        confidence: 0.6,
      ),
      score: bestScore,
      order: order,
    );
  }

  /// Rejects sentences that are mostly symbols/numbers (tables, code, noise).
  bool _looksLikeProse(String sentence) {
    final letters = sentence.replaceAll(RegExp('[^A-Za-z]'), '').length;
    if (letters / sentence.length < 0.6) return false;
    final lowerWords = sentence
        .split(RegExp(r'\s+'))
        .where((w) => RegExp('^[a-z]{2,}').hasMatch(w))
        .length;
    return lowerWords >= 4;
  }

  // ---------------------------------------------------------------------------
  // Sentence splitting
  // ---------------------------------------------------------------------------

  static const _abbreviations = {
    'e.g',
    'i.e',
    'etc',
    'vs',
    'dr',
    'mr',
    'mrs',
    'ms',
    'prof',
    'fig',
    'no',
    'approx',
    'cf',
    'al',
    'inc',
    'ltd',
    'st',
    'eq',
    'sec',
    'vol',
  };

  List<String> _splitSentences(String paragraph) {
    final out = <String>[];
    var start = 0;
    for (var i = 0; i < paragraph.length; i++) {
      final c = paragraph[i];
      if (c != '.' && c != '!' && c != '?') continue;

      var end = i + 1;
      while (end < paragraph.length && '"”\')'.contains(paragraph[end])) {
        end++;
      }
      if (end < paragraph.length && paragraph[end] != ' ') continue;
      if (end >= paragraph.length) break;

      var next = end;
      while (next < paragraph.length && paragraph[next] == ' ') {
        next++;
      }
      if (next >= paragraph.length) break;
      if (!RegExp(r'[A-Z0-9"“(•]').hasMatch(paragraph[next])) continue;

      if (c == '.') {
        final before = paragraph.substring(start, i);
        final token = before.split(RegExp(r'\s+')).last.toLowerCase();
        if (_abbreviations.contains(token) ||
            RegExp(r'^[a-z]$').hasMatch(token) ||
            RegExp(r'^\d+$').hasMatch(token) && token.length <= 2) {
          continue;
        }
      }
      out.add(paragraph.substring(start, end).trim());
      start = next;
      i = next - 1;
    }
    final tail = paragraph.substring(start).trim();
    if (tail.isNotEmpty) out.add(tail);
    return out;
  }
}

enum _BlockKind { heading, qa, glossary, formula, bullet, code, paragraph }

class _Block {
  const _Block(
    this.kind,
    this.text, {
    this.term,
    this.ordered = false,
    this.marker,
  });

  final _BlockKind kind;
  final String text;
  final String? term;
  final bool ordered;
  final String? marker;
}

class _DefinitionResult {
  const _DefinitionResult(this.card, this.consumed);

  final OfflineCard card;
  final Set<int> consumed;
}

class _ClozeCandidate {
  const _ClozeCandidate({
    required this.card,
    required this.score,
    required this.order,
  });

  final OfflineCard card;
  final double score;
  final int order;
}

/// Converts [OfflineCard]s into persisted extraction models.
extension OfflineCardMapping on List<OfflineCard> {
  List<OcrExtractionModel> toExtractionModels(String documentId) => [
    for (var i = 0; i < length; i++)
      OcrExtractionModel(
        id: 'ocr_${documentId}_${i + 1}',
        documentId: documentId,
        topic: this[i].front,
        rawText: this[i].back,
        confidenceScore: this[i].confidence,
      ),
  ];
}

class _QaMatch {
  const _QaMatch(this.question, this.answer, this.lastIndex);

  final String question;
  final String answer;
  final int lastIndex;
}
