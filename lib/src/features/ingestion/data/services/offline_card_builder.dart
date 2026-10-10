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
  const OfflineCardBuilder({
    this.maxCards,
    this.maxClozePerSection,
  });

  final int? maxCards;
  final int? maxClozePerSection;

  static const _minClozeWords = 8;
  static const _maxClozeWords = 35;
  static const _maxDefinitionBackChars = 320;

  /// Builds cards from [fullText]. Returns an empty list when nothing in the
  /// text can be turned into a trustworthy card.
  List<OfflineCard> buildCards(String fullText) {
    final blocks = _parseBlocks(fullText);
    if (blocks.isEmpty) return const [];

    final docContext = _extractDocumentContext(fullText);
    final termFrequency = _termFrequency(blocks);

    final structured = <OfflineCard>[];
    final clozeCandidates = <_ClozeCandidate>[];
    final clozePerSection = <String, int>{};

    String? heading;
    final pendingList = <_Block>[];

    void flushList() {
      final card = _listCard(heading, pendingList);
      if (card != null) {
        structured.add(card);
      }
      pendingList.clear();
    }

    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      if (block.kind != _BlockKind.bullet) flushList();

      switch (block.kind) {
        case _BlockKind.heading:
          heading = block.text;
        case _BlockKind.qa:
          structured.add(
            OfflineCard(
              type: OfflineCardType.qa,
              front: block.term!,
              back: block.text,
              confidence: 0.9,
            ),
          );
        case _BlockKind.glossary:
          final card = _glossaryCard(block, docContext);
          if (card != null) {
            structured.add(card);
          }
        case _BlockKind.formula:
          final card = _formulaCard(block, heading, docContext);
          if (card != null) {
            structured.add(card);
          }
        case _BlockKind.bullet:
          pendingList.add(block);
        case _BlockKind.code:
          final card = _codeCard(blocks, i, heading, docContext);
          if (card != null) {
            structured.add(card);
          }
        case _BlockKind.paragraph:
          final sentences = _splitSentences(block.text);
          final consumed = <int>{};
          for (var s = 0; s < sentences.length; s++) {
            if (consumed.contains(s)) continue;
            final discourse = _discourseCard(sentences, s, heading, docContext);
            if (discourse != null) {
              structured.add(discourse.card);
              consumed.addAll(discourse.consumed);
            }
          }
          for (var s = 0; s < sentences.length; s++) {
            if (consumed.contains(s)) continue;
            final def = _definitionCard(sentences, s);
            if (def != null) {
              structured.add(def.card);
              consumed.addAll(def.consumed);
            }
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
            if (heading != null && maxClozePerSection != null) {
              final used = clozePerSection[sectionKey] ?? 0;
              if (used >= maxClozePerSection!) continue;
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
      if (maxCards != null && result.length >= maxCards!) break;
      if (_isMeaningfulCard(card) && seen.add(norm(card.front))) {
        result.add(card);
      }
    }

    // Sort clozes by score descending so the highest-yield domain terms come first
    final sortedClozes = List<_ClozeCandidate>.from(clozes)
      ..sort((a, b) => b.score.compareTo(a.score));

    final room = maxCards == null ? sortedClozes.length : (maxCards! - result.length);
    if (room > 0 && sortedClozes.isNotEmpty) {
      for (final c in sortedClozes) {
        if (maxCards != null && result.length >= maxCards!) break;
        if (_isMeaningfulCard(c.card) && seen.add(norm(c.card.front))) {
          result.add(c.card);
        }
      }
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Parsing
  // ---------------------------------------------------------------------------

  static final _danglingLineEndRe = RegExp(
    r'(?:[,\-;:]|\b(?:and|or|the|a|an|to|of|in|that|with|for|you|we|as|at|by|from|into|on|is|are|was|were|suggests|allows|requires|focuses|enables|means|relying))\s*$',
    caseSensitive: false,
  );

  static const _nounPluralExclusions = {
    'types',
    'methods',
    'classes',
    'declarations',
    'operations',
    'failures',
    'errors',
    'exceptions',
    'values',
    'results',
    'expressions',
    'statements',
    'items',
    'objects',
    'instances',
    'references',
    'arguments',
    'parameters',
    'variables',
    'constructors',
    'packages',
    'modules',
    'members',
    'fields',
    'arrays',
    'interfaces',
    'modifiers',
    'literals',
    'characters',
    'tokens',
    'lines',
    'words',
    'terms',
    'rules',
    'steps',
    'stages',
    'phases',
    'points',
    'principles',
    'guidelines',
    'requirements',
    'conventions',
    'standards',
  };

  static final _bulletRe = RegExp(
    r'^([-•*●▪◦–—]|\d{1,2}[.)]|[a-z][.)])\s+(\S.*)$',
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
    String? currentSectionTitle;

    void flushParagraph() {
      if (paragraph.isEmpty) return;
      final joined = _joinWrapped(paragraph);
      paragraph.clear();
      if (joined.length >= 20) {
        blocks.add(_Block(_BlockKind.paragraph, joined, sectionTitle: currentSectionTitle));
      }
    }

    // Appends PDF-wrapped continuation lines to a bullet/glossary body.
    // Returns the merged body and the index of the last line consumed.
    (String, int) absorb(int index, String body) {
      final buf = StringBuffer(body);
      var last = index;
      while (last + 1 < lines.length) {
        final next = lines[last + 1].trim();
        if (next.isEmpty) {
          final current = buf.toString().trim();
          final unfinished = _danglingLineEndRe.hasMatch(current);
          if (unfinished && last + 2 < lines.length) {
            final afterNext = lines[last + 2].trim();
            if (afterNext.isNotEmpty &&
                !afterNext.startsWith('```') &&
                !_bulletRe.hasMatch(afterNext) &&
                _headingText(afterNext, false) == null &&
                !(_glossaryRe.firstMatch(afterNext) != null &&
                    _isGlossaryTerm(_glossaryRe.firstMatch(afterNext)!.group(1)!))) {
              last++;
              continue;
            }
          }
          break;
        }
        if (next.startsWith('```') ||
            _bulletRe.hasMatch(next) ||
            _headingText(next, false) != null) {
          break;
        }
        final glossaryNext = _glossaryRe.firstMatch(next);
        if (glossaryNext != null && _isGlossaryTerm(glossaryNext.group(1)!)) {
          break;
        }
        final currentText = buf.toString().trim();
        final unfinished = !RegExp(r'[.!?:"”)]$').hasMatch(currentText);
        if (!unfinished && !RegExp('^[a-z]').hasMatch(next)) break;
        buf.write(' ${_cleanInline(next)}');
        last++;
      }
      return (buf.toString(), last);
    }

    var i = 0;
    var previousBlank = true;
    while (i < lines.length) {
      final line = lines[i].trim();

      if (line.isEmpty) {
        if (paragraph.isNotEmpty) {
          final lastParaLine = paragraph.last.trim();
          final unfinished = _danglingLineEndRe.hasMatch(lastParaLine);
          if (unfinished && i + 1 < lines.length) {
            final nextLine = lines[i + 1].trim();
            if (nextLine.isNotEmpty &&
                !nextLine.startsWith('```') &&
                !_bulletRe.hasMatch(nextLine) &&
                _headingText(nextLine, false) == null &&
                _glossaryRe.firstMatch(nextLine) == null) {
              i++;
              continue;
            }
          }
        }
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
        currentSectionTitle = _cleanInline(headingText);
        blocks.add(_Block(_BlockKind.heading, currentSectionTitle, sectionTitle: currentSectionTitle));
        previousBlank = false;
        i++;
        continue;
      }

      // Check if line is an introductory header for a bullet/glossary list (ends with ':')
      if (line.endsWith(':') && i + 1 < lines.length) {
        final nextLine = lines.sublist(i + 1).firstWhere(
          (l) => l.trim().isNotEmpty,
          orElse: () => '',
        ).trim();
        if (_bulletRe.hasMatch(nextLine) || _glossaryRe.hasMatch(nextLine)) {
          flushParagraph();
          currentSectionTitle = _cleanSectionTitle(line);
          blocks.add(_Block(_BlockKind.heading, currentSectionTitle, sectionTitle: currentSectionTitle));
          previousBlank = false;
          i++;
          continue;
        }
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
          blocks.add(_Block(_BlockKind.glossary, body, term: term, sectionTitle: currentSectionTitle));
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
            sectionTitle: currentSectionTitle,
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
      ).hasMatch(l)) {
        return true;
      }
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
      final cnt = counts[l.toLowerCase()] ?? 0;
      final isRepeatingHeader = isLong &&
          l.isNotEmpty &&
          cnt >= 3 &&
          _wordCount(l) >= 3 &&
          !_bulletRe.hasMatch(l) &&
          !_orderedRe.hasMatch(l);

      if (drop[k] ||
          (_pageNoiseRe.hasMatch(l) && l.isNotEmpty) ||
          isRepeatingHeader) {
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
    final answerBuf = StringBuffer(_cleanInline(a.group(1)!));
    var last = i + 1;
    while (last + 1 < lines.length) {
      final next = lines[last + 1].trim();
      if (next.isEmpty ||
          _qaQuestionRe.hasMatch(next) ||
          _bulletRe.hasMatch(next) ||
          RegExp(r'[.!?]$').hasMatch(answerBuf.toString())) {
        break;
      }
      answerBuf.write(' ${_cleanInline(next)}');
      last++;
    }
    return _QaMatch(_cleanInline(q.group(1)!), answerBuf.toString(), last);
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

  static final _bannedHeadingPattern = RegExp(
    r'\b(?:dear\s|welcome\s|copyright|rights reserved|all rights reserved|version\b|status\b|release\b|isbn\b|issn\b|contents\b|table of contents|page\s+\d|figure\s+\d|table\s+\d|signature)\b',
    caseSensitive: false,
  );

  String? _headingText(String line, bool previousBlank) {
    final trimmed = line.trim();
    if (_bannedHeadingPattern.hasMatch(trimmed)) return null;
    if (RegExp(r'\s+\d{1,4}$').hasMatch(trimmed)) return null;
    if (trimmed.length < 3) return null;

    final md = _markdownHeadingRe.firstMatch(trimmed);
    if (md != null) {
      final text = md.group(1)!.trim();
      return _bannedHeadingPattern.hasMatch(text) ? null : text;
    }

    final numbered = _numberedHeadingRe.firstMatch(trimmed);
    if (numbered != null && _wordCount(trimmed) <= 12 && !_endsSentence(trimmed)) {
      return trimmed;
    }

    if (_keywordHeadingRe.hasMatch(trimmed) &&
        _wordCount(trimmed) <= 12 &&
        !_endsSentence(trimmed)) {
      return trimmed;
    }

    final letters = trimmed.replaceAll(RegExp('[^A-Za-z]'), '');
    if (letters.length >= 4 &&
        letters == letters.toUpperCase() &&
        _wordCount(trimmed) <= 8 &&
        !_endsSentence(trimmed) &&
        !_bulletRe.hasMatch(trimmed)) {
      return trimmed;
    }

    if (previousBlank && _wordCount(trimmed) <= 6 && !_endsSentence(trimmed)) {
      final words = trimmed.split(RegExp(r'\s+'));
      final isTitle = words.every(
        (w) =>
            RegExp('^[A-Z]').hasMatch(w) ||
            {'and', 'or', 'of', 'in', 'the', 'for', 'to', 'with'}.contains(
              w.toLowerCase(),
            ),
      );
      if (isTitle && words.length >= 2) {
        return trimmed;
      }
    }

    return null;
  }

  bool _isGlossaryTerm(String raw) {
    final term = _cleanInline(raw).trim();
    if (term.isEmpty || term.endsWith('.')) return false;
    final words = term.split(RegExp(r'\s+'));
    if (words.length > 5) return false;
    if (_metaLabels.contains(term.toLowerCase())) return false;
    if (!RegExp('^[A-Z0-9]').hasMatch(term)) return false;
    if (RegExp(r'\d+$').hasMatch(term)) return false; // Reject "Statement 440", "Step 2"
    if (RegExp(r'^\d').hasMatch(term)) return false; // Reject "12.2 Compile-Time"
    if (RegExp(r"^(?:not|never|avoid|don'?t)\b", caseSensitive: false).hasMatch(term)) {
      return false; // Reject "Not testing the app"
    }
    if (RegExp(
      r'^(?:stay|ensure|build|develop|collaborate|work|maintain|write|participate|manage|create|implement|monitor|follow|review|use|apply|handle)\b',
      caseSensitive: false,
    ).hasMatch(term)) {
      return false; // Reject task duties
    }
    if (RegExp(
      r'\b(?:chapter|section|part|step|rule|figure|table|item|statement|syntax|grammar|notation|level|phase|stage|version|index)\b',
      caseSensitive: false,
    ).hasMatch(term)) {
      return false;
    }
    if (_bannedHeadingPattern.hasMatch(term)) return false;
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
      } else if (RegExp(r'\d-$').hasMatch(buffer.toString()) &&
          RegExp(r'^\d').hasMatch(line)) {
        buffer.write(line);
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
        RegExp(r'\\(.)'),
        (m) => m.group(1)!,
      )
      .replaceAll('ﬁ', 'fi')
      .replaceAll('ﬂ', 'fl')
      .trim();

  int _wordCount(String s) =>
      s.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

  bool _endsSentence(String s) => RegExp(r'[.!?]["”)]?$').hasMatch(s.trim());

  static String _cleanSectionTitle(String leadIn) {
    final clean = leadIn.trim().replaceFirst(RegExp(r':\s*$'), '').trim();
    final lower = clean.toLowerCase();

    if (lower.contains('bonus feature')) return 'Bonus Features';
    if (lower.contains('anti-pattern') || lower.contains('avoid')) return 'Anti-patterns to avoid';
    if (lower.contains('non-functional requirement')) return 'Non-functional requirements';
    if (lower.contains('functional requirement')) return 'Functional requirements';
    if (lower.contains('api service')) return 'API Services';
    if (lower.contains('scope of work')) return 'Scope of Work';
    if (lower.contains('duties') || lower.contains('responsibilities')) return 'Duties and Responsibilities';
    if (clean.length <= 40) return clean;

    final m = RegExp(
      r'\b(?:the following|these|a few|some)\s+([A-Za-z0-9_\s\-]+)',
      caseSensitive: false,
    ).firstMatch(clean);
    if (m != null) {
      final candidate = m.group(1)!.trim();
      if (candidate.length <= 35) return candidate;
    }
    return clean;
  }

  // ---------------------------------------------------------------------------
  // Card builders
  // ---------------------------------------------------------------------------

  static const _anaphoraBlacklist = {
    'it',
    'this',
    'that',
    'these',
    'those',
    'they',
    'he',
    'she',
    'there',
    'here',
    'which',
    'who',
    'its',
    'their',
    'such',
  };

  String _extractDocumentContext(String fullText) {
    final firstLines = fullText.split('\n').take(15);
    for (final l in firstLines) {
      final trimmed = l.trim();
      final md = _markdownHeadingRe.firstMatch(trimmed);
      if (md != null) {
        final title = md.group(1)!.trim();
        if (title.length <= 40 && !_bannedHeadingPattern.hasMatch(title)) {
          return title;
        }
      }
    }
    return '';
  }

  OfflineCard? _glossaryCard(_Block block, String docContext) {
    final term = block.term!;
    final body = block.text;

    if (_bannedHeadingPattern.hasMatch(term)) return null;
    final lower = body.toLowerCase();
    if (_isBannedBoilerplate(lower)) return null;

    final cleanBody = body.trim();
    if (RegExp(r'\s+\d{1,4}$').hasMatch(cleanBody)) return null;
    if (cleanBody.startsWith('-') || cleanBody.startsWith('–') || cleanBody.startsWith('—')) return null;
    if (RegExp(r'\b\d+\.\d+(?:\.\d+)*\b').hasMatch(cleanBody)) return null;
    if (cleanBody.length < 15) return null;

    final sanitizedBody = cleanBody.replaceFirst(
      RegExp(r'\s*All other tasks as assigned by.*$', caseSensitive: false),
      '',
    ).trim();
    if (sanitizedBody.length < 15) return null;

    final isSyntax = RegExp(r'[{}[\];]').hasMatch(sanitizedBody) || sanitizedBody.contains('::=');
    if (isSyntax) {
      final lang = docContext.isNotEmpty ? ' in $docContext' : '';
      return OfflineCard(
        type: OfflineCardType.glossary,
        front: 'What is the syntax of $term$lang?',
        back: sanitizedBody,
        confidence: 0.88,
      );
    }

    final lowerBody = sanitizedBody.toLowerCase();
    String front;

    final sectionTitle = block.sectionTitle;
    final isGenericSection = sectionTitle == null ||
        {'key terms', 'definitions', 'glossary', 'key terms:'}.contains(sectionTitle.toLowerCase());

    if (!isGenericSection) {
      final sec = sectionTitle;
      if (lowerBody.contains('suggests that you') || lowerBody.contains('principle suggests')) {
        front = 'In "$sec", what is the core principle of $term?';
      } else if (lowerBody.contains('development process') || lowerBody.contains('process relying on')) {
        front = 'In "$sec", what is the core process of $term?';
      } else if (lowerBody.contains('optimized for performance') ||
          lowerBody.contains('fast loading') ||
          lowerBody.contains('designed with the user')) {
        front = 'In "$sec", what does $term require?';
      } else if (RegExp(
            r'^(?:implement|add|allow|build|develop|create|integrate|support|work|track|collaborate|write|maintain)\b',
            caseSensitive: false,
          ).hasMatch(sanitizedBody) ||
          lowerBody.contains('allow users') ||
          lowerBody.contains('integrate with other')) {
        front = 'In "$sec", what does "$term" involve?';
      } else {
        front = 'In "$sec", what is $term?';
      }
    } else {
      if (lowerBody.contains('suggests that you') || lowerBody.contains('principle suggests')) {
        front = 'What is the core principle of $term?';
      } else if (lowerBody.contains('should be designed with') || lowerBody.contains('designed with the user')) {
        front = 'What are the main principles of $term?';
      } else if (lowerBody.contains('optimized for performance') || lowerBody.contains('fast loading')) {
        front = 'What does $term require?';
      } else if (lowerBody.contains('development process') || lowerBody.contains('process relying on')) {
        front = 'What is the core process of $term?';
      } else if (lowerBody.contains('compatible with both android and ios') || lowerBody.contains('cross-platform')) {
        front = 'How is $term achieved across Android and iOS?';
      } else if (lowerBody.contains('allow users to customize') || lowerBody.contains('customize the look')) {
        front = 'What capability does $term provide?';
      } else if (lowerBody.contains('integrate with other') || lowerBody.contains('third-party')) {
        front = 'What is the goal of $term?';
      } else if (lowerBody.contains('work offline')) {
        front = 'What does $term allow?';
      } else if (lowerBody.contains('add support for different languages') || lowerBody.contains('multi-language')) {
        front = 'What is the purpose of $term?';
      } else if (lowerBody.contains('reusable and maintainable') && lowerBody.contains('widgets')) {
        front = 'What is the objective of $term in Flutter?';
      } else if (lowerBody.contains('collaborate with the design team')) {
        front = 'What is the focus of $term?';
      } else if (lowerBody.contains('write unit tests') || lowerBody.contains('perform debugging')) {
        front = 'What is the role of $term?';
      } else if (lowerBody.contains('code reviews')) {
        front = 'What is the purpose of $term?';
      } else if (lowerBody.contains('documentation for the')) {
        front = 'What is the goal of $term?';
      } else if (lowerBody.contains('backend engineers') || lowerBody.contains('collaborate')) {
        front = 'What is the focus of $term?';
      } else {
        front = 'What is $term?';
      }
    }

    if (term.endsWith(' principle') && front.contains('principle of $term')) {
      front = front.replaceFirst(' principle?', '?');
    }

    return OfflineCard(
      type: OfflineCardType.glossary,
      front: front,
      back: sanitizedBody,
      confidence: 0.85,
    );
  }

  OfflineCard? _formulaCard(_Block block, String? heading, String docContext) {
    final formulaText = block.text.trim();
    final term = block.term ?? heading ?? 'this reaction';
    final front = formulaText.contains(r'\') || formulaText.contains('=')
        ? 'What is the formula for $term?'
        : 'What is the chemical equation for $term?';
    return OfflineCard(
      type: OfflineCardType.formula,
      front: front,
      back: formulaText,
      confidence: 0.85,
    );
  }

  OfflineCard? _codeCard(
    List<_Block> blocks,
    int index,
    String? heading,
    String docContext,
  ) {
    final block = blocks[index];
    final code = block.text.trim();
    if (code.length < 15) return null;

    final firstLine = code.split('\n').first.trim();
    var lang = '';
    if (firstLine.startsWith('```')) {
      lang = firstLine.substring(3).trim();
    }
    if (lang.isEmpty) {
      if (docContext == 'Flutter' || code.contains('Widget') || code.contains('setState')) {
        lang = 'dart';
      } else if (docContext == 'Java' || code.contains('public class') || code.contains('System.out')) {
        lang = 'java';
      } else {
        lang = 'dart';
      }
    }

    final classMatch = RegExp(r'\bclass\s+([A-Za-z0-9_]+)').firstMatch(code);
    final funcMatch = RegExp(r'\b(?:void|Future<[^>]+>|Widget|int|String|[A-Z][a-zA-Z0-9_]*)\s+([a-zA-Z0-9_]+)\s*\(').firstMatch(code);

    String front;
    if (classMatch != null) {
      final className = classMatch.group(1)!;
      final langDisplay = lang.isNotEmpty ? ' in ${lang[0].toUpperCase()}${lang.substring(1)}' : '';
      front = 'How do you implement the $className class$langDisplay?';
    } else if (funcMatch != null && !{'if', 'for', 'while', 'switch'}.contains(funcMatch.group(1))) {
      final funcName = funcMatch.group(1)!;
      final langDisplay = lang.isNotEmpty ? ' in ${lang[0].toUpperCase()}${lang.substring(1)}' : '';
      front = 'How do you write the $funcName() function$langDisplay?';
    } else {
      final label = _codeLabel(blocks, index, heading);
      if (label != null) {
        front = 'What is the implementation of "$label" in code?';
      } else {
        front = 'What is the code implementation?';
      }
    }

    return OfflineCard(
      type: OfflineCardType.code,
      front: front,
      back: code,
      confidence: 0.85,
    );
  }

  _DefinitionResult? _discourseCard(
    List<String> sentences,
    int index,
    String? heading,
    String docContext,
  ) {
    final sentence = sentences[index].trim();
    if (!_endsSentence(sentence) || !_looksLikeProse(sentence)) return null;
    final lowerSentence = sentence.toLowerCase();
    if (_isBannedBoilerplate(lowerSentence)) return null;

    final consumed = <int>{index};

    // 1. Causal / Reason ("Why")
    final becauseMatch = RegExp(
      r'^([A-Z][a-zA-Z0-9_\s]{2,45}?)\s+(are|is|were|was)\s+(.+?)\s+because\s+(.+)$',
    ).firstMatch(sentence);
    if (becauseMatch != null) {
      final rawSubject = becauseMatch.group(1)!.trim();
      final copula = becauseMatch.group(2)!;
      final predicate = becauseMatch.group(3)!.trim();
      final subject = _resolveSubject(rawSubject, heading);
      if (subject != null) {
        final contextSuffix = (docContext.isNotEmpty && !sentence.toLowerCase().contains(docContext.toLowerCase()))
            ? ' in $docContext'
            : '';
        final front = 'Why $copula $subject $predicate$contextSuffix?';
        return _DefinitionResult(
          OfflineCard(
            type: OfflineCardType.qa,
            front: front,
            back: sentence,
            confidence: 0.88,
          ),
          consumed,
        );
      }
    }

    // 2. Mechanism / Method ("How does X ..." or "How is X ...")
    final methodMatch = RegExp(
      r'^([A-Z][a-zA-Z0-9_\s]{2,40}?)\s+([a-z]{3,}(?:s|es))\s+(.+?)\s+(?:using|by|via)\s+(.+)$',
    ).firstMatch(sentence);
    if (methodMatch != null) {
      final rawSubject = methodMatch.group(1)!.trim();
      final verbS = methodMatch.group(2)!.toLowerCase();
      final obj = methodMatch.group(3)!.trim();
      final subject = _resolveSubject(rawSubject, heading);
      if (subject != null &&
          !_subjectBannedWords.contains(verbS) &&
          !_nounPluralExclusions.contains(verbS) &&
          !_anaphoraBlacklist.contains(rawSubject.toLowerCase())) {
        final baseVerb = _toBaseVerb(verbS);
        final contextSuffix = (docContext.isNotEmpty && !sentence.toLowerCase().contains(docContext.toLowerCase()))
            ? ' in $docContext'
            : '';
        final front = 'How does $subject $baseVerb $obj$contextSuffix?';
        return _DefinitionResult(
          OfflineCard(
            type: OfflineCardType.qa,
            front: front,
            back: sentence,
            confidence: 0.88,
          ),
          consumed,
        );
      }
    }

    final passiveMatch = RegExp(
      r'^([A-Z][a-zA-Z0-9_\s]{2,45}?)\s+(are|is|were|was)\s+([a-z]+(?:ed|en))\s+(?:by|via|using)\s+(.+)$',
    ).firstMatch(sentence);
    if (passiveMatch != null) {
      final rawSubject = passiveMatch.group(1)!.trim();
      final copula = passiveMatch.group(2)!;
      final participle = passiveMatch.group(3)!;
      final subject = _resolveSubject(rawSubject, heading);
      if (subject != null && !_anaphoraBlacklist.contains(rawSubject.toLowerCase())) {
        final contextSuffix = (docContext.isNotEmpty && !sentence.toLowerCase().contains(docContext.toLowerCase()))
            ? ' in $docContext'
            : '';
        final front = 'How $copula $subject $participle$contextSuffix?';
        return _DefinitionResult(
          OfflineCard(
            type: OfflineCardType.qa,
            front: front,
            back: sentence,
            confidence: 0.88,
          ),
          consumed,
        );
      }
    }

    // 3. Event / Trigger ("What happens when ...")
    final eventMatch = RegExp(
      r'^(?:Calling|Invoking)\s+([a-zA-Z0-9_().]+)\s+(?:tells|notifies|causes|triggers|informs)\s+(.+)$',
    ).firstMatch(sentence);
    if (eventMatch != null) {
      final callTarget = eventMatch.group(1)!.replaceAll(RegExp('[( )]'), '');
      final contextSuffix = docContext.isNotEmpty ? ' in $docContext' : '';
      final front = 'What happens when $callTarget is called$contextSuffix?';
      return _DefinitionResult(
        OfflineCard(
          type: OfflineCardType.qa,
          front: front,
          back: sentence,
          confidence: 0.90,
        ),
        consumed,
      );
    }

    // 4. Contrast ("How does X differ from Y ...")
    final contrastMatch = RegExp(
      r'^([A-Z][a-zA-Z0-9_\s]{1,35}?)\s+is\s+a\s+(?:simplified\s+)?([A-Z][a-zA-Z0-9_\s]{1,35}?)\s+that\s+(?:exposes|uses|provides)\s+(.+?)\s+instead\s+of\s+(.+)$',
    ).firstMatch(sentence);
    if (contrastMatch != null) {
      final subj1 = contrastMatch.group(1)!.trim();
      final subj2 = contrastMatch.group(2)!.trim();
      if (!_anaphoraBlacklist.contains(subj1.toLowerCase()) && !_anaphoraBlacklist.contains(subj2.toLowerCase())) {
        final front = 'How does $subj1 differ from $subj2?';
        return _DefinitionResult(
          OfflineCard(
            type: OfflineCardType.qa,
            front: front,
            back: sentence,
            confidence: 0.88,
          ),
          consumed,
        );
      }
    }

    // 5. Scientific Net Yield / Output
    final yieldMatch = RegExp(
      r'^([A-Z][a-zA-Z0-9_\s]{2,40}?)\s+yields\s+a\s+net\s+(?:gain|yield)\s+of\s+(.+)$',
    ).firstMatch(sentence);
    if (yieldMatch != null) {
      final rawSubject = yieldMatch.group(1)!.trim();
      final subject = _resolveSubject(rawSubject, heading);
      if (subject != null) {
        final front = 'What is the net yield of $subject?';
        return _DefinitionResult(
          OfflineCard(
            type: OfflineCardType.qa,
            front: front,
            back: sentence,
            confidence: 0.90,
          ),
          consumed,
        );
      }
    }

    // 6. Cellular / Anatomical Location ("Where does X take place?")
    final locationMatch = RegExp(
      r'^([A-Z][a-zA-Z0-9_\s]{1,40}?)\s+takes\s+place\s+in\s+(?:the\s+)?(.+?)(?:\.|\s+and\s+|$)',
    ).firstMatch(sentence);
    if (locationMatch != null) {
      final rawSubject = locationMatch.group(1)!.trim();
      final subject = _resolveSubject(rawSubject, heading);
      if (subject != null) {
        final front = 'Where does $subject take place?';
        return _DefinitionResult(
          OfflineCard(
            type: OfflineCardType.qa,
            front: front,
            back: sentence,
            confidence: 0.88,
          ),
          consumed,
        );
      }
    }

    // 7. Purpose / Objective ("What is the primary objective of ...")
    final purposeMatch = RegExp(
      r'^(?:The\s+)?([A-Z][a-zA-Z0-9_\s]{2,40}?)\s+(?:is designed to|aims to|serves to)\s+(.+)$',
    ).firstMatch(sentence);
    if (purposeMatch != null) {
      final rawSubject = purposeMatch.group(1)!.trim();
      final subject = _resolveSubject(rawSubject, heading);
      if (subject != null) {
        final front = 'What is the primary objective of $subject?';
        return _DefinitionResult(
          OfflineCard(
            type: OfflineCardType.qa,
            front: front,
            back: sentence,
            confidence: 0.85,
          ),
          consumed,
        );
      }
    }

    return null;
  }

  String _toBaseVerb(String verb) {
    if (verb.endsWith('ies')) return '${verb.substring(0, verb.length - 3)}y';
    if (RegExp(r'(?:ss|sh|ch|x|z)es$').hasMatch(verb)) {
      return verb.substring(0, verb.length - 2);
    }
    if (verb.endsWith('s')) return verb.substring(0, verb.length - 1);
    return verb;
  }

  String? _resolveSubject(String rawSubject, String? heading) {
    var s = rawSubject.trim();
    s = s.replaceFirst(RegExp(r'^(?:the|a|an)\s+', caseSensitive: false), '').trim();
    if (s.isEmpty) return null;
    final lower = s.toLowerCase();
    if (_anaphoraBlacklist.contains(lower)) {
      if (heading != null && heading.isNotEmpty && !_bannedHeadingPattern.hasMatch(heading)) {
        return heading.replaceFirst(RegExp(r'^#+\s*'), '').trim();
      }
      return null;
    }
    if (_badSubjectStarts.contains(lower.split(RegExp(r'\s+')).first)) return null;
    if (_subjectBannedWords.contains(lower)) return null;
    return s;
  }

  bool _isBannedBoilerplate(String lower) {
    return lower.contains('copyright') ||
        lower.contains('all rights reserved') ||
        lower.contains('oracle america') ||
        lower.contains('contractor') ||
        lower.contains('the company') ||
        lower.contains('welcome to') ||
        lower.contains('dear ') ||
        lower.contains('street') ||
        lower.contains('lagos') ||
        lower.contains('oyebode') ||
        lower.contains('remuneration') ||
        lower.contains('salary') ||
        lower.contains('allowance') ||
        lower.contains('in witness whereof') ||
        lower.contains('severability') ||
        lower.contains('governing law') ||
        lower.contains('indemnif') ||
        lower.contains('confidentiality') ||
        lower.contains('terms of appointment') ||
        lower.contains('acceptance of the terms');
  }

  OfflineCard? _listCard(String? heading, List<_Block> items) {
    if (heading == null || items.length < 2) return null;

    final cleanHeading = heading
        .replaceFirst(RegExp(r'^#+\s*'), '')
        .replaceFirst(RegExp(r'^\d+(?:\.\d+)*[.)]?\s+'), '')
        .trim();

    if (_bannedHeadingPattern.hasMatch(cleanHeading)) return null;

    final isProcess = RegExp(
      r'\b(?:steps?|stages?|phases?|process(?:es)?|procedure|algorithm|lifecycle|workflow|cycle|order|sequence|method)\b',
      caseSensitive: false,
    ).hasMatch(cleanHeading);

    final isKeyProperties = RegExp(
      r'\b(?:principles?|features?|tips?|guidelines?|properties?|components?|requirements?|rules?|advantages?|disadvantages?|objectives?|best practices?|criteria|goals?)\b',
      caseSensitive: false,
    ).hasMatch(cleanHeading);

    final ordered = items.every((b) => b.ordered);

    // Only generate a list card if heading is genuinely a process or a recognized key property list
    if (ordered && !isProcess) return null;
    if (!ordered && !isKeyProperties && !isProcess) return null;
    if (items.length > 7) return null;

    final back = [
      for (var i = 0; i < items.length; i++)
        ordered ? '${items[i].marker} ${items[i].text}' : '• ${items[i].text}',
    ].join('\n');

    if (back.length > 600) return null;

    return OfflineCard(
      type: OfflineCardType.list,
      front: ordered
          ? 'What are the steps in "$cleanHeading", in order?'
          : 'What are the key points of "$cleanHeading"?',
      back: back,
      confidence: 0.75,
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
    final lowerSentence = sentence.toLowerCase();
    if (lowerSentence.contains('copyright') ||
        lowerSentence.contains('all rights reserved') ||
        lowerSentence.contains('oracle america') ||
        lowerSentence.contains('contractor') ||
        lowerSentence.contains('the company') ||
        lowerSentence.contains('challenge is') ||
        lowerSentence.contains('welcome to') ||
        lowerSentence.contains('street') ||
        lowerSentence.contains('lagos') ||
        lowerSentence.contains('dear ')) {
      return null;
    }

    final m = _definitionRe.firstMatch(sentence);
    if (m == null) return null;
    final verb = m.group(2)!;
    if ((verb == 'is' || verb == 'are') &&
        !_copulaObjectRe.hasMatch(m.group(3)!)) {
      return null;
    }

    var subject = m.group(1)!.trim();
    // Strip leading chapter/section/heading artifacts
    subject = subject.replaceFirst(
      RegExp(
        r'^(?:introduction|overview|preface|chapter\s+\d+|section\s+\d+)\s+',
        caseSensitive: false,
      ),
      '',
    );
    subject = subject.replaceFirst(
      RegExp(r'^(?:HE|THE)\s+', caseSensitive: false),
      '',
    );
    subject = subject.replaceFirst(
      RegExp(r'^[A-Z\s]{3,}\s+(?=[A-Z][a-z])'),
      '',
    );
    subject = subject.replaceFirst(
      RegExp(r'^(?:the|a|an)\s+', caseSensitive: false),
      '',
    );
    subject = subject.replaceAll('®', '').replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    if (subject.length < 2) return null;

    final words = subject.split(RegExp(r'\s+'));
    if (words.length > 5) return null;
    if (!RegExp('^[A-Z]').hasMatch(subject)) return null;
    if (_badSubjectStarts.contains(words.first.toLowerCase())) return null;
    if (words.any((w) => _subjectBannedWords.contains(w.toLowerCase()))) {
      return null;
    }
    if (_bannedHeadingPattern.hasMatch(subject)) return null;
    if (RegExp(r'\d+(?:\.\d+)*').hasMatch(subject)) return null;
    if (RegExp('[,;:()]').hasMatch(subject)) return null;

    final plural = verb == 'are';

    final consumed = <int>{index};
    var back = sentence;
    if (index + 1 < sentences.length) {
      final next = sentences[index + 1];
      if (back.length + next.length + 1 <= _maxDefinitionBackChars &&
          !_definitionRe.hasMatch(next) &&
          _endsSentence(next) &&
          _looksLikeProse(next)) {
        back = '$back $next';
        consumed.add(index + 1);
      }
    }

    if (back.startsWith('HE ')) {
      back = 'The ${back.substring(3)}';
    }
    back = back.replaceAll('®', '').replaceAll(RegExp(r'\s{2,}'), ' ').trim();

    if (!_endsSentence(back)) return null;

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
    'parties',
    'party',
    'appointment',
    'agreement',
    'contract',
    'contractor',
    'clause',
    'schedule',
    'herein',
    'hereunder',
    'undersigned',
    'signed',
    'sign',
    'date',
    'month',
    'year',
    'days',
    'letter',
    'shall',
    'terms',
    'challenge',
    'requirements',
    'requirement',
    'estimate',
    'experience',
    'ideas',
    'factors',
    'something',
    'anything',
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
    if (!RegExp('^[A-Z]').hasMatch(sentence)) return null;
    if (!RegExp(r'[.!?]$').hasMatch(sentence)) return null;
    if (sentence.endsWith('?')) return null;
    if (RegExp(r'https?://|www\.').hasMatch(sentence)) return null;
    if (!_looksLikeProse(sentence)) return null;

    final trimmed = sentence.trim();
    if (RegExp(
      r'^(?:however\b|keep in mind\b|it(?:\x27|’|s)? important\b|as a rough estimate\b|we recommend\b|please submit\b|good luck\b|you can\b)',
      caseSensitive: false,
    ).hasMatch(trimmed)) {
      return null;
    }

    final firstWord = sentence
        .split(RegExp(r'\s+'))
        .first
        .toLowerCase()
        .replaceAll(RegExp('[^a-z]'), '');
    // Reject cloze cards starting with pronouns ("It occurs in the _____")
    if (_badSubjectStarts.contains(firstWord)) return null;

    final lower = sentence.toLowerCase();
    if (lower.contains('welcome to') ||
        lower.contains('dear ') ||
        lower.contains('copyright') ||
        lower.contains('all rights reserved') ||
        lower.contains('oracle america') ||
        lower.contains('contractor') ||
        lower.contains('street') ||
        lower.contains('lagos') ||
        lower.contains('oyebode') ||
        lower.contains('hereunder') ||
        lower.contains('herein') ||
        lower.contains('hereof') ||
        lower.contains('challenge is to') ||
        lower.contains('dispute') ||
        lower.contains('jurisdiction') ||
        lower.contains('court') ||
        lower.contains('undersigned') ||
        lower.contains('acceptance of the terms') ||
        lower.contains('terms of appointment') ||
        lower.contains('in witness whereof') ||
        lower.contains('severability') ||
        lower.contains('governing law') ||
        lower.contains('indemnif') ||
        lower.contains('confidentiality') ||
        lower.contains('agreement') ||
        lower.contains('employment') ||
        lower.contains('remuneration') ||
        lower.contains('salary') ||
        lower.contains('allowance') ||
        lower.contains('signed') ||
        lower.contains('sign and return') ||
        lower.contains('line manager') ||
        lower.contains('engagement') ||
        lower.contains('letter') ||
        lower.contains('nigeria') ||
        lower.contains('regulation') ||
        lower.contains('terms and conditions') ||
        lower.contains('clause') ||
        lower.contains('schedule') ||
        lower.contains('republic') ||
        lower.contains('public knowledge') ||
        lower.contains('fee') ||
        lower.contains('monthly') ||
        lower.contains('n850') ||
        lower.contains('charges')) {
      return null;
    }

    String? best;
    var bestScore = 0.0;
    final matches = RegExp(
      r"[A-Za-z][A-Za-z0-9'’\-]*[A-Za-z0-9]|[A-Z]{2,}",
    ).allMatches(sentence);
    for (final m in matches) {
      final word = m.group(0)!;
      final lowerWord = word.toLowerCase();
      if (word.length < 4 && !RegExp(r'^[A-Z]{2,}$').hasMatch(word)) continue;
      if (_stopWords.contains(lowerWord)) continue;

      var score = math.log(1 + word.length);
      final midSentence = m.start > 0;
      if (RegExp(r'^[A-Z]{2,}[a-z0-9]*$').hasMatch(word)) {
        score *= 2.2; // acronym
      } else if (midSentence && RegExp('^[A-Z]').hasMatch(word)) {
        score *= 1.8; // proper / technical noun
      } else if (RegExp(r'\d').hasMatch(word)) {
        score *= 1.5;
      }
      if ((freq[lowerWord] ?? 1) >= 2) score *= 1.4;
      if (score > bestScore) {
        bestScore = score;
        best = word;
      }
    }
    if (best == null) return null;

    final blank = sentence.replaceAll(
      RegExp('\\b${RegExp.escape(best)}\\b'),
      '_____',
    );
    if (blank == sentence) return null;

    return _ClozeCandidate(
      card: OfflineCard(
        type: OfflineCardType.cloze,
        front: blank,
        back: '$best\n\n$sentence',
        confidence: 0.75,
      ),
      score: bestScore,
      order: order,
    );
  }

  /// Rejects non-educational, metadata, and incomplete sentence cards.
  bool _isMeaningfulCard(OfflineCard card) {
    final frontLower = card.front.toLowerCase();
    final backLower = card.back.toLowerCase();

    if (frontLower.contains('welcome') ||
        frontLower.contains('dear ') ||
        frontLower.contains('copyright') ||
        frontLower.contains('rights reserved') ||
        frontLower.contains('all rights reserved') ||
        frontLower.contains('status') ||
        frontLower.contains('version') ||
        frontLower.contains('specification') ||
        frontLower.contains('take-home')) {
      return false;
    }

    if (backLower.contains('copyright ©') ||
        backLower.contains('all rights reserved') ||
        backLower.contains('take-home challenge') ||
        backLower.contains('we write further')) {
      return false;
    }

    final backTrimmed = card.back.trim();
    final isListOrCode = card.type == OfflineCardType.list ||
        card.type == OfflineCardType.code ||
        card.type == OfflineCardType.formula ||
        card.type == OfflineCardType.glossary ||
        backTrimmed.startsWith('•') ||
        RegExp(r'^\d+[.)]').hasMatch(backTrimmed);

    if (!isListOrCode && !_endsSentence(backTrimmed)) {
      return false;
    }

    if (backTrimmed.endsWith('...') ||
        RegExp(
          r'\b(?:and|or|of|in|to|the|a|an|as|with|for|no|not|are|is|were|was|be|have|has)\s*[.!?]?$',
          caseSensitive: false,
        ).hasMatch(backTrimmed)) {
      return false;
    }

    if (card.front.length < 5 || card.back.length < 10) return false;

    return true;
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
      if (!RegExp('[A-Z0-9"“(•]').hasMatch(paragraph[next])) continue;

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
    this.sectionTitle,
  });

  final _BlockKind kind;
  final String text;
  final String? term;
  final bool ordered;
  final String? marker;
  final String? sectionTitle;
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
