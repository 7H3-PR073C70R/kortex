import 'dart:math' as math;

import 'package:kortex/src/features/ingestion/data/models/ocr_extraction_model.dart';
import 'package:kortex/src/features/ingestion/data/services/formula_extraction_service.dart';
import 'package:kortex/src/features/ingestion/data/services/synthesis/flashcard_synthesizer.dart';
import 'package:kortex/src/features/ingestion/domain/entities/document_ir.dart';
import 'package:kortex/src/features/ingestion/domain/entities/extraction_report.dart';
import 'package:kortex/src/features/ingestion/domain/entities/pedagogical_card_schema.dart';

/// The kind of card produced by [OfflineCardBuilder].
enum OfflineCardType { qa, glossary, definition, formula, list, code, cloze, table, figure }

/// Maps [OfflineCardType] to canonical [CognitiveQuestionType].
extension OfflineCardTypeMapping on OfflineCardType {
  CognitiveQuestionType toCognitiveType() {
    switch (this) {
      case OfflineCardType.definition:
      case OfflineCardType.glossary:
      case OfflineCardType.cloze:
        return CognitiveQuestionType.definition;
      case OfflineCardType.qa:
        return CognitiveQuestionType.mechanism;
      case OfflineCardType.formula:
        return CognitiveQuestionType.math;
      case OfflineCardType.code:
        return CognitiveQuestionType.code;
      case OfflineCardType.list:
      case OfflineCardType.table:
        return CognitiveQuestionType.yieldResult;
      case OfflineCardType.figure:
        return CognitiveQuestionType.location;
    }
  }
}

/// A card built offline together with the type that produced it.
class OfflineCard {
  const OfflineCard({
    required this.type,
    required this.front,
    required this.back,
    required this.confidence,
    this.heading,
    this.source,
    this.assets = const [],
  });

  final OfflineCardType type;
  final String front;
  final String back;
  final double confidence;
  final String? heading;
  final CardSource? source;
  final List<CardAsset> assets;

  OfflineCard copyWith({
    OfflineCardType? type,
    String? front,
    String? back,
    double? confidence,
    String? heading,
    CardSource? source,
    List<CardAsset>? assets,
  }) =>
      OfflineCard(
        type: type ?? this.type,
        front: front ?? this.front,
        back: back ?? this.back,
        confidence: confidence ?? this.confidence,
        heading: heading ?? this.heading,
        source: source ?? this.source,
        assets: assets ?? this.assets,
      );
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

  static const _minClozeWords = 5;
  static const _maxClozeWords = 40;
  static const _maxDefinitionBackChars = 320;

  /// Extracts the deck title prioritizing:
  /// 1. Document metadata title.
  /// 2. Primary first-page heading (Level 1 heading, or first heading on page 1).
  /// 3. Fallback to clean document filename.
  static String extractDeckTitle({
    String? fullText,
    DocumentIR? ir,
    Map<String, dynamic>? metadata,
    String? filename,
  }) {
    if (metadata != null) {
      final t = metadata['title'] ?? metadata['deck_title'] ?? metadata['deckTitle'];
      if (t is String && t.trim().isNotEmpty) {
        return t.trim();
      }
    }
    if (ir != null && ir.metadata.isNotEmpty) {
      final t = ir.metadata['title'] ?? ir.metadata['deck_title'] ?? ir.metadata['deckTitle'];
      if (t is String && t.trim().isNotEmpty) {
        return t.trim();
      }
    }

    if (ir != null && ir.headings.isNotEmpty) {
      final page1Headings = ir.headings.where((h) => h.provenance.page == 1).toList();
      if (page1Headings.isNotEmpty) {
        final h1 = page1Headings.firstWhere((h) => h.level == 1, orElse: () => page1Headings.first);
        final clean = h1.text.trim();
        if (clean.isNotEmpty && clean.length <= 100) return clean;
      } else {
        final clean = ir.headings.first.text.trim();
        if (clean.isNotEmpty && clean.length <= 100) return clean;
      }
    }

    if (fullText != null && fullText.trim().isNotEmpty) {
      final lines = fullText.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('# ') && trimmed.length > 2) {
          final clean = trimmed.substring(2).trim();
          if (clean.isNotEmpty && clean.length <= 100) return clean;
        }
      }
      for (final line in lines.take(15)) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty &&
            trimmed.length <= 80 &&
            !trimmed.startsWith('Page ') &&
            !trimmed.startsWith('http') &&
            !trimmed.contains('===') &&
            !trimmed.contains('---')) {
          final clean = trimmed.replaceFirst(RegExp(r'^(?:#+|\d+(?:\.\d+)*\.?)\s*'), '').trim();
          if (clean.length >= 3) return clean;
        }
      }
    }

    if (filename != null && filename.isNotEmpty) {
      final name = filename.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
      return name.replaceAll(RegExp(r'[_\-]+'), ' ').trim();
    }

    return 'Study Deck';
  }

  /// Builds cards from strongly-typed [DocumentIR].
  List<OfflineCard> buildCardsFromIR(DocumentIR ir, {ExtractionReport? report}) {
    final blocks = _irToBlocks(ir);
    if (blocks.isEmpty) return const [];
    final docContext = extractDeckTitle(ir: ir, filename: ir.filename);
    return _buildCardsFromBlocks(blocks, docContext: docContext, report: report);
  }

  /// Builds cards from [fullText]. Returns an empty list when nothing in the
  /// text can be formed into educational cards.
  List<OfflineCard> buildCards(
    String fullText, {
    ExtractionReport? report,
    DocumentIR? ir,
    Map<String, dynamic>? metadata,
  }) {
    if (ir != null) {
      return buildCardsFromIR(ir, report: report);
    }
    final blocks = _parseBlocks(fullText, report: report);
    if (blocks.isEmpty) return const [];

    final docContext = extractDeckTitle(
      fullText: fullText,
      metadata: metadata,
    );
    return _buildCardsFromBlocks(blocks, docContext: docContext, report: report);
  }

  List<_Block> _irToBlocks(DocumentIR ir) {
    final blocks = <_Block>[];
    String? currentHeading;

    for (final node in ir.blocks) {
      switch (node) {
        case HeadingBlock():
          currentHeading = node.text.trim();
          blocks.add(
            _Block(
              _BlockKind.heading,
              node.text.trim(),
              sectionTitle: currentHeading,
              page: node.provenance.page,
              provenance: node.provenance,
            ),
          );
        case ParagraphBlock():
          blocks.add(
            _Block(
              _BlockKind.paragraph,
              node.text.trim(),
              sectionTitle: currentHeading,
              page: node.provenance.page,
              provenance: node.provenance,
            ),
          );
        case ListBlock():
          for (final item in node.items) {
            blocks.add(
              _Block(
                _BlockKind.bullet,
                item.text.trim(),
                ordered: item.isOrdered,
                marker: item.bulletPrefix,
                sectionTitle: currentHeading,
                page: item.provenance.page,
                provenance: item.provenance,
              ),
            );
          }
        case ListItemBlock():
          blocks.add(
            _Block(
              _BlockKind.bullet,
              node.text.trim(),
              ordered: node.isOrdered,
              marker: node.bulletPrefix,
              sectionTitle: currentHeading,
              page: node.provenance.page,
              provenance: node.provenance,
            ),
          );
        case TableBlock():
          blocks.add(
            _Block(
              _BlockKind.table,
              node.rawText,
              term: node.caption ?? currentHeading,
              tableHeaders: node.headers,
              tableRows: node.rows,
              sectionTitle: currentHeading,
              page: node.provenance.page,
              provenance: node.provenance,
            ),
          );
        case CodeBlock():
          blocks.add(
            _Block(
              _BlockKind.code,
              node.rawText,
              codeLanguage: node.language,
              sectionTitle: currentHeading,
              page: node.provenance.page,
              provenance: node.provenance,
            ),
          );
        case MathBlock():
          blocks.add(
            _Block(
              _BlockKind.formula,
              node.rawText,
              term: currentHeading,
              sectionTitle: currentHeading,
              page: node.provenance.page,
              provenance: node.provenance,
            ),
          );
        case FigureBlock():
          blocks.add(
            _Block(
              _BlockKind.figure,
              node.caption ?? node.label ?? 'Figure',
              term: node.label ?? 'Figure',
              imageRef: node.imageRef,
              sectionTitle: currentHeading,
              page: node.page,
              provenance: node.provenance,
            ),
          );
      }
    }
    return blocks;
  }

  List<OfflineCard> _buildCardsFromBlocks(
    List<_Block> blocks, {
    required String docContext,
    ExtractionReport? report,
  }) {
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
              heading: heading,
              source: block.provenance != null
                  ? CardSource(
                      docId: block.provenance!.docId,
                      page: block.provenance!.page,
                      sectionPath: block.provenance!.sectionPath,
                      bbox: block.provenance!.bbox,
                      blockId: 'qa_$i',
                    )
                  : null,
            ),
          );
        case _BlockKind.glossary:
          final card = _glossaryCard(block, docContext);
          if (card != null) {
            structured.add(card);
          }
        case _BlockKind.formula:
          final card = _formulaCard(block, heading, docContext, index: i);
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
        case _BlockKind.table:
          final tableCards = _tableCards(block, heading, docContext, index: i);
          structured.addAll(tableCards);
        case _BlockKind.figure:
          final figCard = _figureCard(block, heading, docContext, index: i);
          if (figCard != null) {
            structured.add(figCard);
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
              heading: heading,
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

    final assembled = _assemble(structured, clozeCandidates, report: report);
    return _bindAdjacentAssets(assembled, blocks);
  }

  List<OfflineCard> _bindAdjacentAssets(
    List<OfflineCard> cards,
    List<_Block> blocks,
  ) {
    final assetsBySection = <String, List<CardAsset>>{};

    for (var i = 0; i < blocks.length; i++) {
      final b = blocks[i];
      final section = b.sectionTitle ?? '';
      if (b.kind == _BlockKind.figure && b.imageRef != null && b.imageRef!.isNotEmpty) {
        final asset = CardAsset(
          id: 'fig_$i',
          type: CardAssetType.image,
          content: b.imageRef!,
          label: b.term ?? b.text,
        );
        assetsBySection.putIfAbsent(section, () => []).add(asset);
      } else if (b.kind == _BlockKind.formula && b.text.isNotEmpty) {
        final asset = CardAsset(
          id: 'math_$i',
          type: CardAssetType.latexEquation,
          content: b.text,
          label: b.term ?? 'Formula',
        );
        assetsBySection.putIfAbsent(section, () => []).add(asset);
      }
    }

    if (assetsBySection.isEmpty) return cards;

    return cards.map((card) {
      if (card.assets.isNotEmpty) return card;

      final refMatch = RegExp(
        r'\b(Figure\s+\d+|Equation\s+\d+|Diagram\s+\d+)\b',
        caseSensitive: false,
      ).firstMatch('${card.front} ${card.back}');

      if (refMatch != null) {
        final refText = refMatch.group(1)!.toLowerCase();
        for (final list in assetsBySection.values) {
          for (final a in list) {
            if ((a.label?.toLowerCase() ?? '').contains(refText)) {
              return card.copyWith(assets: [a]);
            }
          }
        }
      }

      if (card.heading != null) {
        final secAssets = assetsBySection[card.heading];
        if (secAssets != null && secAssets.length == 1) {
          return card.copyWith(assets: [secAssets.first]);
        }
      }

      return card;
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // Assembly
  // ---------------------------------------------------------------------------

  List<OfflineCard> _assemble(
    List<OfflineCard> structured,
    List<_ClozeCandidate> clozes, {
    ExtractionReport? report,
  }) {
    final seen = <String>{};
    final seenFrontTokens = <String, Set<String>>{};
    final result = <OfflineCard>[];

    String norm(String s) =>
        s.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');

    Set<String> contentTokens(String s) {
      final clean = s.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ');
      return clean.split(RegExp(r'\s+')).where((w) => w.length > 2).toSet()
        ..removeAll({
          'what', 'does', 'how', 'why', 'who', 'where', 'when',
          'the', 'and', 'for', 'with', 'involve', 'complete',
          'implementation', 'structure', 'class', 'function',
          'which', 'that', 'this', 'from', 'into', 'in', 'of',
        });
    }

    bool isSemanticDuplicate(String front) {
      final tokens = contentTokens(front);
      if (tokens.isEmpty) return false;
      for (final existing in seenFrontTokens.values) {
        if (existing.isEmpty) continue;
        final intersection = tokens.intersection(existing).length;
        final union = tokens.union(existing).length;
        if (union > 0 && (intersection / union) >= 0.80) {
          return true;
        }
      }
      return false;
    }

    for (final card in structured) {
      if (maxCards != null && result.length >= maxCards!) break;
      if (_isMeaningfulCard(card)) {
        final normFront = norm(card.front);
        if (seen.contains(normFront)) {
          report?.recordDrop(
            rule: 'duplicate_card_front',
            sampleText: card.front,
          );
        } else if (isSemanticDuplicate(card.front)) {
          report?.recordDrop(
            rule: 'semantic_duplicate_card_front',
            sampleText: card.front,
          );
        } else {
          seen.add(normFront);
          seenFrontTokens[normFront] = contentTokens(card.front);
          result.add(card);
        }
      } else {
        report?.recordDrop(
          rule: 'meaningless_card_rejected',
          sampleText: '${card.front} -> ${card.back}',
        );
      }
    }

    // Sort clozes by score descending so the highest-yield domain terms come first
    final sortedClozes = List<_ClozeCandidate>.from(clozes)
      ..sort((a, b) => b.score.compareTo(a.score));

    final room = maxCards == null ? sortedClozes.length : (maxCards! - result.length);
    if (room > 0 && sortedClozes.isNotEmpty) {
      for (final c in sortedClozes) {
        if (maxCards != null && result.length >= maxCards!) break;
        if (_isMeaningfulCard(c.card)) {
          final normFront = norm(c.card.front);
          if (seen.contains(normFront)) {
            report?.recordDrop(
              rule: 'duplicate_card_front',
              sampleText: c.card.front,
            );
          } else if (isSemanticDuplicate(c.card.front)) {
            report?.recordDrop(
              rule: 'semantic_duplicate_card_front',
              sampleText: c.card.front,
            );
          } else {
            seen.add(normFront);
            seenFrontTokens[normFront] = contentTokens(c.card.front);
            result.add(c.card);
          }
        } else {
          report?.recordDrop(
            rule: 'meaningless_card_rejected',
            sampleText: '${c.card.front} -> ${c.card.back}',
          );
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

  List<_Block> _parseBlocks(String text, {ExtractionReport? report}) {
    final rawLines = text.replaceAll('\r\n', '\n').split('\n');
    final lines = _dropNoise(rawLines, report: report);

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
        final unfinished = _danglingLineEndRe.hasMatch(currentText);
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

      final figMatch = RegExp(r'^!\[(.*?)\]\((.*?)\)$').firstMatch(line);
      if (figMatch != null) {
        flushParagraph();
        final alt = figMatch.group(1) ?? '';
        final url = figMatch.group(2) ?? '';
        final labelMatch = RegExp(r'^(Figure\s+\d+)(?::\s*(.*))?', caseSensitive: false).firstMatch(alt);
        final label = labelMatch?.group(1);
        final caption = labelMatch?.group(2) ?? alt;
        blocks.add(
          _Block(
            _BlockKind.figure,
            caption.isNotEmpty ? caption : alt,
            term: label ?? (alt.isNotEmpty ? alt : 'Figure'),
            imageRef: url,
            sectionTitle: currentSectionTitle,
          ),
        );
        previousBlank = true;
        i++;
        continue;
      }

      if (_looksLikeTableRow(line) && i + 1 < lines.length && _looksLikeTableDivider(lines[i + 1])) {
        flushParagraph();
        final tableLines = <String>[lines[i], lines[i + 1]];
        i += 2;
        while (i < lines.length && _looksLikeTableRow(lines[i])) {
          tableLines.add(lines[i]);
          i++;
        }
        final headers = _parseTableRow(tableLines[0]);
        final rows = tableLines.skip(2).map(_parseTableRow).where((r) => r.isNotEmpty).toList();
        blocks.add(
          _Block(
            _BlockKind.table,
            tableLines.join('\n'),
            term: currentSectionTitle,
            tableHeaders: headers,
            tableRows: rows,
            sectionTitle: currentSectionTitle,
          ),
        );
        previousBlank = true;
        continue;
      }

      if (line.startsWith('```') || line.startsWith('~~~')) {
        flushParagraph();
        final fence = line.startsWith('```') ? '```' : '~~~';
        final code = <String>[lines[i]];
        i++;
        while (i < lines.length && !lines[i].trim().startsWith(fence)) {
          code.add(lines[i]);
          i++;
        }
        if (i < lines.length) {
          code.add(lines[i]);
          i++;
        }
        blocks.add(_Block(_BlockKind.code, code.join('\n')));
        previousBlank = true;
        continue;
      }

      if (line.startsWith(r'$$') || line.startsWith(r'\[') || line.startsWith(r'\begin{')) {
        String? lead;
        if (paragraph.isNotEmpty) {
          lead = paragraph.removeLast();
          flushParagraph();
        } else if (blocks.isNotEmpty && blocks.last.kind == _BlockKind.heading) {
          lead = blocks.last.text;
        } else {
          flushParagraph();
        }

        final mathLines = <String>[lines[i]];
        final isSingleLine = (line.startsWith(r'$$') && line.length > 2 && line.endsWith(r'$$')) ||
            (line.startsWith(r'\[') && line.length > 2 && line.endsWith(r'\]'));
        if (!isSingleLine) {
          final isBegin = line.startsWith(r'\begin{');
          i++;
          while (i < lines.length) {
            final curLine = lines[i];
            final curTrim = curLine.trim();
            mathLines.add(curLine);
            i++;
            if (isBegin) {
              if (curTrim.startsWith(r'\end{')) break;
            } else {
              if (curTrim.endsWith(r'$$') || curTrim.endsWith(r'\]')) break;
            }
          }
        } else {
          i++;
        }

        blocks.add(
          _Block(
            _BlockKind.formula,
            mathLines.join('\n'),
            term: lead?.replaceFirst(RegExp(r'\s*:\s*$'), ''),
          ),
        );
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
              lines[i],
              term: lead.replaceFirst(RegExp(r'\s*:\s*$'), ''),
            ),
          );
          previousBlank = false;
          i++;
          continue;
        } else if (lead == null && FormulaExtractionService.isFormula(lines[i])) {
          blocks.add(
            _Block(
              _BlockKind.formula,
              lines[i],
              term: currentSectionTitle,
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
      if (line.endsWith(':') && _wordCount(line) <= 15 && i + 1 < lines.length) {
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
  List<String> _dropNoise(List<String> rawLines, {ExtractionReport? report}) {
    // 1. Mark which lines belong to protected regions (code blocks and math blocks)
    final isProtected = List<bool>.filled(rawLines.length, false);
    var inCode = false;
    var inMath = false;
    String? codeFence;

    for (var idx = 0; idx < rawLines.length; idx++) {
      final line = rawLines[idx];
      final trimmed = line.trim();

      // Check code fences (``` or ~~~)
      if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) {
        final fence = trimmed.substring(0, 3);
        if (!inCode) {
          inCode = true;
          codeFence = fence;
          isProtected[idx] = true;
        } else if (fence == codeFence) {
          inCode = false;
          codeFence = null;
          isProtected[idx] = true;
        } else {
          isProtected[idx] = inCode;
        }
        continue;
      }
      if (inCode) {
        isProtected[idx] = true;
        continue;
      }

      // Check display math delimiters
      if (trimmed.startsWith(r'$$') || trimmed.startsWith(r'\[')) {
        if (!inMath) {
          inMath = true;
          isProtected[idx] = true;
          if (trimmed.length > 2 && (trimmed.endsWith(r'$$') || trimmed.endsWith(r'\]'))) {
            inMath = false;
          }
        } else {
          inMath = false;
          isProtected[idx] = true;
        }
        continue;
      }
      if (trimmed.startsWith(r'\begin{')) {
        inMath = true;
        isProtected[idx] = true;
        continue;
      }
      if (inMath) {
        isProtected[idx] = true;
        if (trimmed.endsWith(r'$$') || trimmed.endsWith(r'\]') || trimmed.startsWith(r'\end{')) {
          inMath = false;
        }
        continue;
      }
    }

    final trimmed = rawLines.map((l) => l.trim()).toList();

    final counts = <String, int>{};
    for (var idx = 0; idx < trimmed.length; idx++) {
      if (isProtected[idx]) continue; // Code and math never count as repeating headers/footers
      final l = trimmed[idx];
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
      if (!isProtected[i] && isTocLine(trimmed[i])) {
        var j = i;
        while (j < trimmed.length &&
            !isProtected[j] &&
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
      if (isProtected[k]) {
        // Preserves protected code and math regions byte-for-byte with exact indentation
        out.add(rawLines[k]);
        continue;
      }
      final l = trimmed[k];
      final cnt = counts[l.toLowerCase()] ?? 0;
      final isRepeatingHeader = isLong &&
          l.isNotEmpty &&
          cnt >= 3 &&
          _wordCount(l) >= 3 &&
          !_bulletRe.hasMatch(l) &&
          !_orderedRe.hasMatch(l);

      if (drop[k]) {
        report?.recordDrop(
          rule: 'table_of_contents_run',
          sampleText: rawLines[k],
        );
        out.add('');
      } else if (_pageNoiseRe.hasMatch(l) && l.isNotEmpty) {
        report?.recordDrop(rule: 'page_noise', sampleText: rawLines[k]);
        out.add('');
      } else if (isRepeatingHeader) {
        report?.recordDrop(rule: 'repeating_header', sampleText: rawLines[k]);
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

  bool _isFormulaLine(String line) {
    if (FormulaExtractionService.isCodeAssignment(line)) return false;
    return FormulaExtractionService.isFormula(line);
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

  int _wordCount(String s) {
    final trimmed = s.trim();
    if (trimmed.isEmpty) return 0;
    final spaceWords = trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final cjkChars = RegExp(r'[\p{Lo}\p{Sc}]', unicode: true).allMatches(trimmed).length;
    return spaceWords + (cjkChars > 3 ? (cjkChars ~/ 2) : 0);
  }

  bool _endsSentence(String s) =>
      RegExp(r'[.!?\u3002\uFF01\uFF1F\u0964\u06D4]["”)]?$').hasMatch(s.trim());

  bool _looksLikeTableRow(String line) {
    final t = line.trim();
    if (!t.contains('|')) return false;
    return t.startsWith('|') || t.endsWith('|') || t.split('|').length >= 3;
  }

  bool _looksLikeTableDivider(String line) {
    final t = line.trim();
    if (!t.contains('|') && !t.contains('-')) return false;
    return RegExp(r'^\|?[\s\-:|]+\|?$').hasMatch(t) && t.contains('-');
  }

  List<String> _parseTableRow(String line) {
    var t = line.trim();
    if (t.startsWith('|')) t = t.substring(1);
    if (t.endsWith('|')) t = t.substring(0, t.length - 1);
    return t.split('|').map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
  }

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
      } else if (RegExp(
            r'^(?:implement|add|allow|build|develop|create|integrate|support|work|track|collaborate|write|maintain)\b',
            caseSensitive: false,
          ).hasMatch(sanitizedBody) ||
          lowerBody.contains('allow users') ||
          lowerBody.contains('integrate with other')) {
        front = 'What does "$term" involve?';
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

  OfflineCard? _formulaCard(_Block block, String? heading, String docContext, {int index = 0}) {
    final formulaText = block.text.trim();
    final term = block.term ?? heading ?? (formulaText.contains(r'\') || formulaText.contains('=') ? 'this formula' : 'this reaction');
    final front = formulaText.contains(r'\') || formulaText.contains('=')
        ? 'What is the formula for $term?'
        : 'What is the chemical equation for $term?';

    final assets = <CardAsset>[
      CardAsset(
        id: 'math_$index',
        type: CardAssetType.latexEquation,
        content: formulaText,
        label: term,
      ),
    ];

    CardSource? source;
    if (block.provenance != null) {
      source = CardSource(
        docId: block.provenance!.docId,
        page: block.provenance!.page,
        sectionPath: block.provenance!.sectionPath.isNotEmpty
            ? block.provenance!.sectionPath
            : [heading ?? docContext],
        bbox: block.provenance!.bbox,
        blockId: 'math_$index',
      );
    }

    return OfflineCard(
      type: OfflineCardType.formula,
      front: front,
      back: formulaText,
      confidence: 0.85,
      heading: heading,
      source: source,
      assets: assets,
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
    var lang = block.codeLanguage ?? '';
    if (lang.isEmpty && (firstLine.startsWith('```') || firstLine.startsWith('~~~'))) {
      lang = firstLine.substring(3).trim();
    }
    if (lang.isEmpty) {
      if (code.contains('Widget') || code.contains('setState') || code.contains('BuildContext')) {
        lang = 'dart';
      } else if (code.contains('public class') || code.contains('System.out') || code.contains('public static void main')) {
        lang = 'java';
      } else if (code.contains('def ') || code.contains('import asyncio') || code.contains('elif ')) {
        lang = 'python';
      } else if (code.contains('fn ') || code.contains('let mut ') || code.contains('impl ')) {
        lang = 'rust';
      } else if (code.contains('package main') || code.contains('func ')) {
        lang = 'go';
      } else if (code.contains('#include') || code.contains('std::') || code.contains('template <')) {
        lang = 'cpp';
      } else if (code.contains('SELECT ') || code.contains('FROM ') || code.contains('WHERE ')) {
        lang = 'sql';
      } else if (code.contains('const ') || code.contains('export default') || code.contains('console.log')) {
        lang = 'typescript';
      }
    }

    final classMatch = RegExp(r'\bclass\s+([A-Za-z0-9_]+)').firstMatch(code);
    final funcMatch = RegExp(r'\b(?:def|fn|func|function|void|Future<[^>]+>|Widget|int|String|[A-Z][a-zA-Z0-9_]*)\s+([a-zA-Z0-9_]+)\s*\(').firstMatch(code);

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

    final assets = <CardAsset>[
      CardAsset(
        id: 'code_$index',
        type: CardAssetType.syntaxCode,
        content: code,
        label: lang.isNotEmpty ? lang : 'code',
      ),
    ];

    CardSource? source;
    if (block.provenance != null) {
      source = CardSource(
        docId: block.provenance!.docId,
        page: block.provenance!.page,
        sectionPath: block.provenance!.sectionPath.isNotEmpty
            ? block.provenance!.sectionPath
            : [heading ?? docContext],
        bbox: block.provenance!.bbox,
        blockId: 'code_$index',
      );
    }

    return OfflineCard(
      type: OfflineCardType.code,
      front: front,
      back: code,
      confidence: 0.85,
      heading: heading,
      source: source,
      assets: assets,
    );
  }

  OfflineCard? _figureCard(
    _Block block,
    String? heading,
    String docContext, {
    int index = 0,
  }) {
    final label = block.term;
    final caption = block.text.trim();
    final imageRef = block.imageRef;

    String front;
    if (label != null && label.isNotEmpty && caption.isNotEmpty && caption != label) {
      front = 'According to $label ($caption), what is illustrated?';
    } else if (label != null && label.isNotEmpty) {
      front = 'What does $label illustrate?';
    } else if (caption.isNotEmpty) {
      final context = heading != null ? 'In "$heading", ' : '';
      front = '${context}what does the diagram depicting "$caption" illustrate?';
    } else {
      return null;
    }

    final assets = <CardAsset>[];
    if (imageRef != null && imageRef.isNotEmpty) {
      assets.add(
        CardAsset(
          id: 'fig_$index',
          type: CardAssetType.image,
          content: imageRef,
          label: label ?? caption,
        ),
      );
    }

    CardSource? source;
    if (block.provenance != null) {
      source = CardSource(
        docId: block.provenance!.docId,
        page: block.provenance!.page,
        sectionPath: block.provenance!.sectionPath.isNotEmpty
            ? block.provenance!.sectionPath
            : [heading ?? docContext],
        bbox: block.provenance!.bbox,
        blockId: 'fig_$index',
      );
    }

    return OfflineCard(
      type: OfflineCardType.figure,
      front: front,
      back: caption.isNotEmpty ? caption : (label ?? 'Diagram'),
      confidence: 0.85,
      heading: heading,
      source: source,
      assets: assets,
    );
  }

  List<OfflineCard> _tableCards(
    _Block block,
    String? heading,
    String docContext, {
    int index = 0,
  }) {
    final headers = block.tableHeaders;
    final rows = block.tableRows;
    if (headers.isEmpty || rows.isEmpty) return const [];
    final cards = <OfflineCard>[];
    final tableName = block.term ?? heading ?? 'the summary table';

    for (var r = 0; r < rows.length && r < 3; r++) {
      final row = rows[r];
      if (row.isEmpty) continue;
      final entity = row.first.trim();
      if (entity.isEmpty || entity.length > 50) continue;

      String front;
      if (row.length == 2 && headers.length >= 2) {
        front = 'In $tableName, what is the ${headers[1]} for $entity?';
      } else if (row.length >= 3 && headers.length >= 3) {
        front = 'In $tableName, what are the ${headers[1]} and ${headers[2]} for $entity?';
      } else {
        front = 'In $tableName, what are the details for $entity?';
      }

      final back = '| ${row.join(" | ")} |';

      CardSource? source;
      if (block.provenance != null) {
        source = CardSource(
          docId: block.provenance!.docId,
          page: block.provenance!.page,
          sectionPath: block.provenance!.sectionPath.isNotEmpty
              ? block.provenance!.sectionPath
              : [heading ?? docContext],
          bbox: block.provenance!.bbox,
          blockId: 'table_${index}_$r',
        );
      }

      cards.add(
        OfflineCard(
          type: OfflineCardType.table,
          front: front,
          back: back,
          confidence: 0.88,
          heading: heading,
          source: source,
        ),
      );
    }
    return cards;
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
    final trimmed = lower.trim();
    return RegExp(
      r'^\s*(?:_{3,}|-{3,}|={3,}|copyright\b|all\s+rights\s+reserved\b|dear\s+[a-z]+|welcome\s+to\b|in\s+witness\s+whereof\b|signed\s+by\b)',
      caseSensitive: false,
    ).hasMatch(trimmed);
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
    final trimmed = sentence.trim();
    if (RegExp(
      r'^\s*(?:copyright\b|all\s+rights\s+reserved\b|dear\s+[a-z]+|welcome\s+to\b)',
      caseSensitive: false,
    ).hasMatch(trimmed)) {
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
    r"[\p{L}\p{N}][\p{L}\p{N}'’\-]*[\p{L}\p{N}]|[\p{Lu}]{2,}|[\p{Lo}]+",
    unicode: true,
  ).allMatches(text).map((m) => m.group(0)!);

  _ClozeCandidate? _clozeCandidate(
    String sentence,
    Map<String, int> freq,
    int order, {
    String? heading,
  }) {
    final words = _wordCount(sentence);
    if (words < _minClozeWords || words > _maxClozeWords) return null;
    if (!RegExp(r'^[\p{Lu}\p{Lo}\p{Lt}]', unicode: true).hasMatch(sentence)) return null;
    if (!RegExp(r'[.!?\u3002\uFF01\uFF1F\u0964\u06D4]$').hasMatch(sentence.trim())) return null;
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
        .replaceAll(RegExp(r'[^\p{L}]', unicode: true), '');
    // Reject cloze cards starting with pronouns ("It occurs in the _____")
    if (_badSubjectStarts.contains(firstWord)) return null;

    if (RegExp(
      r'^\s*(?:copyright\b|all\s+rights\s+reserved\b|dear\s+[a-z]+|welcome\s+to\b|in\s+witness\s+whereof\b|signed\s+by\b)',
      caseSensitive: false,
    ).hasMatch(trimmed)) {
      return null;
    }

    String? best;
    var bestScore = 0.0;
    final matches = RegExp(
      r"[\p{L}\p{N}][\p{L}\p{N}'’\-]*[\p{L}\p{N}]|[\p{Lu}]{2,}|[\p{Lo}]+",
      unicode: true,
    ).allMatches(sentence);
    for (final m in matches) {
      final word = m.group(0)!;
      final lowerWord = word.toLowerCase();
      if (word.length < 3 && !RegExp(r'^\p{Lu}{2,}$', unicode: true).hasMatch(word)) continue;
      if (_stopWords.contains(lowerWord)) continue;

      var score = math.log(1 + word.length);
      final midSentence = m.start > 0;
      if (RegExp(r'^\p{Lu}{2,}[\p{Ll}\p{N}]*$', unicode: true).hasMatch(word)) {
        score *= 2.2; // acronym
      } else if (midSentence && RegExp(r'^\p{Lu}', unicode: true).hasMatch(word)) {
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
      RegExp(r'(?<=[^\p{L}]|^)' + RegExp.escape(best) + r'(?=[^\p{L}]|$)', unicode: true),
      '_____',
    );
    if (blank == sentence) return null;

    final cleanHeading = heading
        ?.replaceFirst(RegExp(r'^(?:#+|\d+(?:\.\d+)*\.?)\s*'), '')
        .trim();
    final contextualFront = (cleanHeading != null &&
            cleanHeading.isNotEmpty &&
            !sentence.toLowerCase().contains(cleanHeading.toLowerCase()))
        ? 'In "$cleanHeading", complete: $blank'
        : blank;

    return _ClozeCandidate(
      card: OfflineCard(
        type: OfflineCardType.cloze,
        front: contextualFront,
        back: '$best\n\n$sentence',
        confidence: 0.75,
        heading: heading,
      ),
      score: bestScore,
      order: order,
    );
  }

  static final _danglingPronounRe = RegExp(
    r'\b(?:what\s+is\s+it|what\s+does\s+it|why\s+does\s+it|how\s+does\s+it|what\s+is\s+this|what\s+does\s+this|why\s+does\s+this|how\s+does\s+this|what\s+are\s+they|what\s+do\s+they|why\s+do\s+they|how\s+do\s+they|what\s+is\s+that|what\s+are\s+these|what\s+are\s+those|what\s+does\s+which|why\s+does\s+which|what\s+are\s+its|what\s+is\s+their)\b',
    caseSensitive: false,
  );

  static final _clauseInitialTransitionRe = RegExp(
    r'^(?:however|therefore|moreover|furthermore|additionally|in addition|also|nevertheless|consequently|meanwhile|hence|thus)\b[,:]?\s*',
    caseSensitive: false,
  );

  /// Rejects non-educational, metadata, and incomplete sentence cards.
  bool _isMeaningfulCard(OfflineCard card) {
    final frontLower = card.front.toLowerCase();
    final backLower = card.back.toLowerCase();

    if (_danglingPronounRe.hasMatch(card.front) || _clauseInitialTransitionRe.hasMatch(card.front)) {
      return false;
    }

    if (RegExp(r'\b(?:welcome\s+to|dear\s+[a-z]+|copyright|all\s+rights\s+reserved)\b', caseSensitive: false).hasMatch(frontLower)) {
      return false;
    }

    if (RegExp(r'\b(?:copyright\s+(?:©|\(c\))?\s*\d{4}|all\s+rights\s+reserved)\b', caseSensitive: false).hasMatch(backLower)) {
      return false;
    }

    final backTrimmed = card.back.trim();
    final isListOrCode = card.type == OfflineCardType.list ||
        card.type == OfflineCardType.code ||
        card.type == OfflineCardType.formula ||
        card.type == OfflineCardType.glossary ||
        card.type == OfflineCardType.table ||
        card.type == OfflineCardType.figure ||
        backTrimmed.startsWith('•') ||
        backTrimmed.startsWith('|') ||
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

    if (card.front.length < 5) return false;
    if (card.type != OfflineCardType.formula &&
        card.type != OfflineCardType.figure &&
        card.back.length < 10) {
      return false;
    }
    if (card.type == OfflineCardType.formula && card.back.length < 3) return false;

    return true;
  }

  /// Rejects sentences that are mostly symbols/numbers (tables, code, noise).
  bool _looksLikeProse(String sentence) {
    final letters = RegExp(r'\p{L}', unicode: true).allMatches(sentence).length;
    if (sentence.isEmpty) return false;
    if (letters / sentence.length < 0.4) return false;
    final words = sentence.trim().split(RegExp(r'\s+'));
    if (words.length < 3 && letters < 6) return false;
    return true;
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
    const terminators = {'.', '!', '?', '\u3002', '\uFF01', '\uFF1F', '\u0964', '\u06D4'};

    for (var i = 0; i < paragraph.length; i++) {
      final c = paragraph[i];
      if (!terminators.contains(c)) continue;

      var end = i + 1;
      while (end < paragraph.length && '"”\')'.contains(paragraph[end])) {
        end++;
      }
      if (end < paragraph.length && paragraph[end] != ' ' && c != '\u3002' && c != '\u0964') {
        continue;
      }
      if (end >= paragraph.length) break;

      var next = end;
      while (next < paragraph.length && paragraph[next] == ' ') {
        next++;
      }
      if (next >= paragraph.length) break;
      if (!RegExp(r'[\p{Lu}\p{N}"“(•\p{Lo}]', unicode: true).hasMatch(paragraph[next])) {
        continue;
      }

      if (c == '.') {
        final before = paragraph.substring(start, i);
        final token = before.split(RegExp(r'\s+')).last.toLowerCase();
        if (_abbreviations.contains(token) ||
            RegExp(r'^[a-z]$').hasMatch(token) ||
            (RegExp(r'^\d+$').hasMatch(token) && token.length <= 2)) {
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

enum _BlockKind { heading, qa, glossary, formula, bullet, code, paragraph, table, figure }

class _Block {
  const _Block(
    this.kind,
    this.text, {
    this.term,
    this.ordered = false,
    this.marker,
    this.sectionTitle,
    this.tableHeaders = const [],
    this.tableRows = const [],
    this.imageRef,
    this.page = 1,
    this.codeLanguage,
    this.provenance,
  });

  final _BlockKind kind;
  final String text;
  final String? term;
  final bool ordered;
  final String? marker;
  final String? sectionTitle;
  final List<String> tableHeaders;
  final List<List<String>> tableRows;
  final String? imageRef;
  final int page;
  final String? codeLanguage;
  final BlockProvenance? provenance;
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
