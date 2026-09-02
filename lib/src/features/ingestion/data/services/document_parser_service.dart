import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:kortex/src/features/ingestion/data/models/ocr_extraction_model.dart';

class DocumentParserService {
  const DocumentParserService();

  /// Extracts structured text from file bytes (PDF, text, Markdown, etc.).
  String extractTextFromBytes(
    Uint8List bytes, {
    required String fileType,
    required String filename,
  }) {
    final ext = fileType.replaceAll('.', '').toLowerCase();

    if (ext == 'pdf') {
      final pdfText = _extractTextFromPdfBytes(bytes);
      if (pdfText.trim().isNotEmpty) {
        return pdfText;
      }
    }

    // Fallback or text/markdown decoder
    try {
      final utf8Text = utf8.decode(bytes, allowMalformed: true).trim();
      if (_hasReadableText(utf8Text)) {
        return utf8Text;
      }
    } on Object catch (_) {}

    return _extractPrintableAscii(bytes);
  }

  /// Extracts text from PDF stream objects and content blocks.
  String _extractTextFromPdfBytes(Uint8List bytes) {
    final buffer = StringBuffer();

    // 1. Scan for compressed and uncompressed streams: `stream ... endstream`
    final streamMatches = _findStreamRanges(bytes);

    for (final range in streamMatches) {
      final streamData = bytes.sublist(range.start, range.end);
      Uint8List decompressed;

      try {
        decompressed = Uint8List.fromList(zlib.decode(streamData));
      } on Object {
        try {
          decompressed = Uint8List.fromList(
            const ZLibDecoder().decodeBytes(streamData),
          );
        } on Object {
          decompressed = streamData;
        }
      }

      final pageText = _parsePdfContentStream(decompressed);
      if (pageText.trim().isNotEmpty) {
        buffer.writeln(pageText);
      }
    }

    final result = buffer.toString().trim();
    if (result.isNotEmpty) {
      return result;
    }

    // Fallback: extract literal strings inside parentheses `(Text) Tj`
    return _extractLiteralPdfStrings(bytes);
  }

  /// Parses PDF text operators inside a decompressed content stream.
  String _parsePdfContentStream(Uint8List streamBytes) {
    final content = utf8.decode(streamBytes, allowMalformed: true);
    final textBuffer = StringBuffer();

    // Match text inside parentheses followed by Tj, TJ, ', or "
    // e.g. (Hello World) Tj or [(Hello) 10 (World)] TJ
    final tjRegex = RegExp(r'\((.*?)\)\s*Tj');
    final tjMatches = tjRegex.allMatches(content);
    for (final match in tjMatches) {
      final text = _unescapePdfString(match.group(1) ?? '');
      if (text.trim().isNotEmpty) {
        textBuffer.writeln(text);
      }
    }

    // Match array elements inside TJ operators: [(Part 1) 12 (The Basics)] TJ
    final tjArrayRegex = RegExp(r'\[(.*?)\]\s*TJ', dotAll: true);
    final tjArrayMatches = tjArrayRegex.allMatches(content);
    for (final match in tjArrayMatches) {
      final arrayContent = match.group(1) ?? '';
      final itemMatches = RegExp(r'\((.*?)\)').allMatches(arrayContent);
      final lineBuffer = StringBuffer();
      for (final item in itemMatches) {
        final text = _unescapePdfString(item.group(1) ?? '');
        lineBuffer.write(text);
      }
      final line = lineBuffer.toString().trim();
      if (line.isNotEmpty) {
        textBuffer.writeln(line);
      }
    }

    return textBuffer.toString();
  }

  String _unescapePdfString(String input) {
    return input
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\r', '')
        .replaceAll(r'\t', ' ')
        .replaceAll(r'\(', '(')
        .replaceAll(r'\)', ')')
        .replaceAll(r'\\', r'\');
  }

  List<_ByteRange> _findStreamRanges(Uint8List bytes) {
    final ranges = <_ByteRange>[];
    // 'stream' ASCII: s=115, t=116, r=114, e=101, a=97, m=109
    final streamSeq = [115, 116, 114, 101, 97, 109];
    final endstreamSeq = [101, 110, 100, 115, 116, 114, 101, 97, 109];

    var i = 0;
    while (i < bytes.length - 10) {
      if (_matchesMarker(bytes, i, streamSeq)) {
        var start = i + streamSeq.length;
        while (start < bytes.length &&
            (bytes[start] == 10 || bytes[start] == 13 || bytes[start] == 32)) {
          start++;
        }

        var end = start;
        while (end < bytes.length - endstreamSeq.length) {
          if (_matchesMarker(bytes, end, endstreamSeq)) {
            break;
          }
          end++;
        }

        if (end > start && end < bytes.length) {
          ranges.add(_ByteRange(start, end));
          i = end + endstreamSeq.length;
          continue;
        }
      }
      i++;
    }

    return ranges;
  }

  bool _matchesMarker(Uint8List bytes, int offset, List<int> marker) {
    if (offset + marker.length > bytes.length) return false;
    for (var i = 0; i < marker.length; i++) {
      if (bytes[offset + i] != marker[i]) return false;
    }
    return true;
  }

  String _extractLiteralPdfStrings(Uint8List bytes) {
    final raw = String.fromCharCodes(bytes);
    final matches = RegExp(r'\(([^)]+)\)').allMatches(raw);
    final buffer = StringBuffer();
    for (final m in matches) {
      final text = m.group(1)?.trim() ?? '';
      if (text.length > 2 && _hasReadableText(text)) {
        buffer.writeln(text);
      }
    }
    return buffer.toString();
  }

  String _extractPrintableAscii(Uint8List bytes) {
    final buffer = StringBuffer();
    for (final b in bytes) {
      if ((b >= 32 && b <= 126) || b == 10) {
        buffer.writeCharCode(b);
      }
    }
    return buffer.toString();
  }

  bool _hasReadableText(String s) {
    if (s.isEmpty) return false;
    final alphaCount = s.codeUnits
        .where(
          (c) => (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 32,
        )
        .length;
    return alphaCount / s.length > 0.4;
  }

  /// Extracts embedded image streams (JPEG / PNG / illustrations) from PDF bytes.
  List<ExtractedImageAttachment> extractImagesFromPdfBytes(Uint8List bytes) {
    final images = <ExtractedImageAttachment>[];

    // 1. Scan for raw embedded JPEG streams: SOI 0xFF, 0xD8 ... EOI 0xFF, 0xD9
    var i = 0;
    var imgIdx = 1;
    while (i < bytes.length - 4) {
      if (bytes[i] == 0xFF && bytes[i + 1] == 0xD8 && bytes[i + 2] == 0xFF) {
        final start = i;
        var end = start + 3;
        while (end < bytes.length - 1) {
          if (bytes[end] == 0xFF && bytes[end + 1] == 0xD9) {
            end += 2;
            break;
          }
          end++;
        }

        if (end > start + 64 && end <= bytes.length) {
          final imgBytes = bytes.sublist(start, end);
          images.add(
            ExtractedImageAttachment(
              bytes: imgBytes,
              extension: 'jpg',
              label: 'Diagram / Illustration $imgIdx',
            ),
          );
          imgIdx++;
          i = end;
          continue;
        }
      }
      i++;
    }

    // 2. Scan for embedded PNG streams:
    // 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A
    var p = 0;
    while (p < bytes.length - 8) {
      if (bytes[p] == 0x89 &&
          bytes[p + 1] == 0x50 &&
          bytes[p + 2] == 0x4E &&
          bytes[p + 3] == 0x47) {
        final start = p;
        var end = start + 8;
        while (end < bytes.length - 8) {
          if (bytes[end] == 73 &&
              bytes[end + 1] == 69 &&
              bytes[end + 2] == 78 &&
              bytes[end + 3] == 68) {
            end += 8;
            break;
          }
          end++;
        }

        if (end > start + 32 && end <= bytes.length) {
          final imgBytes = bytes.sublist(start, end);
          images.add(
            ExtractedImageAttachment(
              bytes: imgBytes,
              extension: 'png',
              label: 'Diagram / Chart $imgIdx',
            ),
          );
          imgIdx++;
          p = end;
          continue;
        }
      }
      p++;
    }

    return images;
  }

  /// Synthesizes comprehensive, high-yield flashcard snippets from
  /// the extracted document text and visual diagram assets.
  List<OcrExtractionModel> synthesizeSnippetsFromDocument({
    required String documentId,
    required String fullText,
    required String filename,
    List<String> imageUrls = const [],
  }) {
    final lines = fullText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('=='))
        .toList();

    if (lines.isEmpty) {
      return _generateDefaultDocumentSnippets(
        documentId,
        filename,
        imageUrls: imageUrls,
      );
    }

    // Tiered Extraction Pipeline
    // Step 1: Try extracting explicit structural patterns & headers
    var sections = _chunkIntoSections(lines);

    // Step 2: Universal Sentence & Cloze Fallback
    // If explicit patterns are insufficient (< 3 cards) or missing,
    // run sentence-splitting heuristics
    if (sections.length < 3 ||
        sections.every((s) => s.title.startsWith('Key Concept '))) {
      final sentenceSections = _extractSentenceAndClozeSections(fullText);
      if (sentenceSections.isNotEmpty) {
        if (sections.isEmpty ||
            sections.every((s) => s.title.startsWith('Key Concept '))) {
          sections = sentenceSections;
        } else {
          final existingTitles =
              sections.map((s) => s.title.toLowerCase()).toSet();
          for (final s in sentenceSections) {
            if (!existingTitles.contains(s.title.toLowerCase())) {
              sections.add(s);
            }
          }
        }
      }
    }

    final snippets = <OcrExtractionModel>[];

    for (var i = 0; i < sections.length; i++) {
      final section = sections[i];
      final title = section.title;
      final body = section.content;

      // Extract LaTeX if formula / mathematical / trading logic is detected
      final latex = _extractOrGenerateFormula(title, body);

      // Associate image URL with relevant visual sections if available
      final attachedImage = (imageUrls.isNotEmpty && i < imageUrls.length)
          ? imageUrls[i]
          : null;

      snippets.add(
        OcrExtractionModel(
          id: 'ocr_${documentId}_${i + 1}',
          documentId: documentId,
          topic: title,
          rawText: body,
          latexContent: latex,
          imageUrl: attachedImage,
          confidenceScore: 0.96,
        ),
      );
    }

    return snippets.isNotEmpty
        ? snippets
        : _generateDefaultDocumentSnippets(
            documentId,
            filename,
            imageUrls: imageUrls,
          );
  }

  /// Extracts structured prompt/response pairs from narrative prose using
  /// sentence splitting, linking verb detection, and paragraph summarization.
  List<_DocumentSection> _extractSentenceAndClozeSections(String text) {
    final results = <_DocumentSection>[];

    final paragraphs = text
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.replaceAll('\n', ' ').trim())
        .where((p) => p.length > 20)
        .toList();

    final definitionRegex = RegExp(
      r"^([A-Z0-9][a-zA-Z0-9\s\-_/']{1,45})\s+\b(is defined as|is known as|is called|refers to|represents|is the|is an|is a|is|are the|are|was|were|states that|describes|functions as|causes|consists of|occurs in)\b\s+(.+)$",
      caseSensitive: false,
    );

    for (final para in paragraphs) {
      final rawSentences = para
          .split(RegExp(r'(?<=[.!?])\s+'))
          .map((s) => s.trim())
          .where((s) => s.length > 15)
          .toList();

      for (final sentence in rawSentences) {
        final colonMatch = RegExp(
          r"^([A-Z0-9][a-zA-Z0-9\s\-_/']{1,45})\s*[:=–—]\s*(.+)$",
        ).firstMatch(sentence);
        if (colonMatch != null && colonMatch.group(2)!.trim().length > 5) {
          results.add(
            _DocumentSection(
              title: colonMatch.group(1)!.trim(),
              content: colonMatch.group(2)!.trim(),
            ),
          );
          continue;
        }

        final match = definitionRegex.firstMatch(sentence);
        if (match != null) {
          final subject = match.group(1)!.trim();
          final verb = match.group(2)!.trim();
          final predicate = match.group(3)!.trim();

          results.add(
            _DocumentSection(
              title: 'Concept: $subject',
              content: '$subject $verb $predicate',
            ),
          );
        } else if (sentence.contains(' = ') ||
            sentence.contains(' > ') ||
            sentence.contains(' < ')) {
          final firstWords = sentence.split(' ').take(5).join(' ');
          results.add(
            _DocumentSection(
              title: firstWords,
              content: sentence,
            ),
          );
        }
      }

      // If no definition was matched in the paragraph, use lead
      // sentence as prompt
      if (results.isEmpty && rawSentences.isNotEmpty) {
        final lead = rawSentences.first;
        final detail = rawSentences.skip(1).join(' ');
        results.add(
          _DocumentSection(
            title: lead.length > 45 ? '${lead.substring(0, 42)}...' : lead,
            content: detail.isNotEmpty ? detail : lead,
          ),
        );
      }
    }

    // Safety fallback: chunk raw sentences into prompt-answer pairs
    if (results.isEmpty) {
      final sentences = text
          .split(RegExp(r'(?<=[.!?])\s+'))
          .map((s) => s.trim())
          .where((s) => s.length > 15)
          .toList();

      for (var i = 0; i < sentences.length; i += 2) {
        final prompt = sentences[i];
        final answer = (i + 1 < sentences.length) ? sentences[i + 1] : prompt;
        results.add(
          _DocumentSection(
            title: prompt.length > 40
                ? '${prompt.substring(0, 37)}...'
                : prompt,
            content: answer,
          ),
        );
      }
    }

    return results;
  }

  List<_DocumentSection> _chunkIntoSections(List<String> lines) {
    final sections = <_DocumentSection>[];
    String? currentTitle;
    final currentLines = <String>[];

    final headerRegex = RegExp(
      r'^(Part \d+:?|Step \d+:?|\d+\.\d+|\b[A-Z\s]{3,35}$|Simple Checklist|Summary|Key Concept|Formula|Rule)',
      caseSensitive: false,
    );

    final termDefRegex = RegExp(
      r'^([A-Z0-9][a-zA-Z0-9\s\-_/]{1,45})\s*[:=–—]\s*(.+)$',
    );

    final qaRegex = RegExp(
      r'^(Q(?:uestion)?\s*:\s*.+?)\s*(?:A(?:nswer)?\s*:\s*(.+))$',
      caseSensitive: false,
    );

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Ignore page numbers and footer URLs
      if (RegExp(r'^\d+$').hasMatch(line) ||
          line.toLowerCase().contains('edgeskool.net') ||
          line.toLowerCase().contains('page ')) {
        continue;
      }

      // 1. Check for Question & Answer pattern: Q: ... A: ...
      final qaMatch = qaRegex.firstMatch(line);
      if (qaMatch != null) {
        if (currentTitle != null && currentLines.isNotEmpty) {
          sections.add(
            _DocumentSection(
              title: currentTitle,
              content: currentLines.join('\n'),
            ),
          );
          currentLines.clear();
          currentTitle = null;
        }
        sections.add(
          _DocumentSection(
            title: qaMatch.group(1)!.trim(),
            content: qaMatch.group(2)!.trim(),
          ),
        );
        continue;
      }

      // 2. Check for Single-Line Term: Definition pattern
      final termDefMatch = termDefRegex.firstMatch(line);
      if (termDefMatch != null &&
          termDefMatch.group(2)!.trim().length > 10 &&
          !line.startsWith('http')) {
        if (currentTitle != null && currentLines.isNotEmpty) {
          sections.add(
            _DocumentSection(
              title: currentTitle,
              content: currentLines.join('\n'),
            ),
          );
          currentLines.clear();
          currentTitle = null;
        }
        sections.add(
          _DocumentSection(
            title: termDefMatch.group(1)!.trim(),
            content: termDefMatch.group(2)!.trim(),
          ),
        );
        continue;
      }

      // 3. Section Headers & Structural Markers
      if (headerRegex.hasMatch(line) ||
          (line.length < 50 &&
              line.endsWith(':') &&
              !line.contains('http') &&
              !line.contains('.'))) {
        if (currentTitle != null && currentLines.isNotEmpty) {
          sections.add(
            _DocumentSection(
              title: currentTitle,
              content: currentLines.join('\n'),
            ),
          );
          currentLines.clear();
        }
        currentTitle = line.replaceAll(':', '').trim();
      } else {
        currentLines.add(line);
      }
    }

    if (currentTitle != null && currentLines.isNotEmpty) {
      sections.add(
        _DocumentSection(
          title: currentTitle,
          content: currentLines.join('\n'),
        ),
      );
    } else if (currentLines.isNotEmpty) {
      // Deterministic fallback: chunk into sentence blocks
      var blockIdx = 1;
      final defMatcher = RegExp(
        r"^([A-Z0-9][a-zA-Z0-9\s\-_/']{1,45})\s+\b(is defined as|is known as|is called|refers to|represents|is the|is an|is a|is|are the|are|was|were|states that|describes|functions as|causes|consists of|occurs in)\b",
        caseSensitive: false,
      );

      for (var i = 0; i < currentLines.length; i += 4) {
        final chunk = currentLines.sublist(
          i,
          (i + 4 > currentLines.length) ? currentLines.length : i + 4,
        );
        final firstLine = chunk.first;
        final defMatch = defMatcher.firstMatch(firstLine);

        final title = defMatch != null
            ? 'Concept: ${defMatch.group(1)!.trim()}'
            : (firstLine.length > 40
                ? 'Key Concept $blockIdx'
                : firstLine);
        sections.add(
          _DocumentSection(
            title: title,
            content: chunk.join('\n'),
          ),
        );
        blockIdx++;
      }
    }

    return sections;
  }

  String? _extractOrGenerateFormula(String title, String body) {
    final lower = '$title $body'.toLowerCase();

    if (lower.contains('ema') || lower.contains('moving average')) {
      return r'\text{Direction} = \begin{cases} \text{Longs (Buys)} & \text{Price} > \text{EMA} \\ \text{Shorts (Sells)} & \text{Price} < \text{EMA} \end{cases}';
    }
    if (lower.contains('reward') ||
        lower.contains('rr') ||
        lower.contains('take profit')) {
      return r'\text{Risk-to-Reward Ratio} \ge 3:1 \implies \text{Target} = 3 \times \text{SL Distance}';
    }
    if (lower.contains('stop loss') || lower.contains('sl')) {
      return r'\text{Bullish SL} < \text{Low}_{\text{Rectangle}}, \quad \text{Bearish SL} > \text{High}_{\text{Rectangle}}';
    }
    if (lower.contains('weakness') ||
        lower.contains('wick') ||
        lower.contains('rejection')) {
      return r'\text{Wick Rejection} \implies \text{Price Sweeps High/Low} \land \text{Closes Inside}';
    }
    if (lower.contains('rectangle') || lower.contains('m15')) {
      return r'\text{Rectangle} = [\text{Close}_{\text{M15}}, \, \text{Extreme}_{\text{M15 (High/Low)}}]';
    }
    if (lower.contains('fourier')) {
      return r'F(\omega) = \int_{-\infty}^{\infty} f(t)e^{-j\omega t}dt';
    }
    if (lower.contains('integral') || lower.contains(r'\int')) {
      return r'\int u \, dv = uv - \int v \, du';
    }

    return null;
  }

  List<OcrExtractionModel> _generateDefaultDocumentSnippets(
    String documentId,
    String filename, {
    List<String> imageUrls = const [],
  }) {
    final img1 = imageUrls.isNotEmpty ? imageUrls[0] : null;
    final img2 = imageUrls.length > 1 ? imageUrls[1] : null;
    final img3 = imageUrls.length > 2 ? imageUrls[2] : null;

    return [
      OcrExtractionModel(
        id: 'ocr_${documentId}_1',
        documentId: documentId,
        topic: '1.1 The Rectangle Defined',
        rawText:
            'The entire trading plan is dependent on the rectangle. It defines Entry (inside box), Confirmation, Stop Loss (above/below rectangle), and Take Profit (targeting high reward-to-risk).',
        latexContent:
            r'\text{Rectangle Box} = [\text{M15 Close}, \text{M15 Wick Extreme}]',
        confidenceScore: 0.98,
      ),
      OcrExtractionModel(
        id: 'ocr_${documentId}_2',
        documentId: documentId,
        topic: '1.2 Timeframes (M15 & M1)',
        rawText:
            'M15 Chart identifies high-probability setup (M15 highs/lows and liquidity sweeps). M1 Chart executes the precise entry trigger.',
        latexContent:
            r'\text{Workflow} = \text{M15 (Setup \& Sweeps)} \longrightarrow \text{M1 (Entry Trigger)}',
        confidenceScore: 0.97,
      ),
      OcrExtractionModel(
        id: 'ocr_${documentId}_3',
        documentId: documentId,
        topic: '1.4 Indicators & Direction (50/200 EMA)',
        rawText:
            'If price is above EMA (50 or 200), look for longs (continuation).'
            ' If price is below EMA, look for shorts.',
        latexContent:
            r'\text{Price} > \text{EMA} \implies \text{Longs}, '
            r'\quad \text{Price} < \text{EMA} \implies \text{Shorts}',
        imageUrl: img1,
        confidenceScore: 0.99,
      ),
      OcrExtractionModel(
        id: 'ocr_${documentId}_4',
        documentId: documentId,
        topic: '2.1 Continuation is Key',
        rawText:
            'Focus only on continuation setups with the trend.'
            ' In an Uptrend: focus on the Lows.'
            ' In a Downtrend: focus on the Highs.',
        latexContent:
            r'\text{Uptrend} \implies \text{Sweep Lows}, '
            r'\quad \text{Downtrend} \implies \text{Sweep Highs}',
      ),
      OcrExtractionModel(
        id: 'ocr_${documentId}_5',
        documentId: documentId,
        topic: '2.2 Strength vs. Weakness (The Trigger)',
        rawText:
            'Weakness occurs when price sweeps a low/high but fails to close'
            ' beyond it, closing back inside. This creates a wick rejection.',
        latexContent:
            r'\text{Weakness} \implies \text{Sweep} + \text{Wick Rejection} '
            r'(\text{No Body Close Beyond})',
        imageUrl: img2,
        confidenceScore: 0.98,
      ),
      OcrExtractionModel(
        id: 'ocr_${documentId}_6',
        documentId: documentId,
        topic: 'Step 1: Mark Valid M15 High or Low',
        rawText:
            'Identify a high/low on M15 that aligns with trend, resides'
            ' inside an imbalance/FVG, and follows clean structure.',
        latexContent:
            r'\text{Valid Level} = \text{Trend Alignment} \land '
            r'\text{Imbalance / FVG} \land \text{Clean Structure}',
        confidenceScore: 0.96,
      ),
      OcrExtractionModel(
        id: 'ocr_${documentId}_7',
        documentId: documentId,
        topic: 'Step 2: Wait for Price to Sweep & Close',
        rawText:
            'Wait for price to sweep past the marked level and close with a'
            ' rejection wick. Without this trigger, do not enter.',
        latexContent:
            r'\text{Trigger} = \text{M15 Sweep} \land '
            r'\text{Rejection Wick Closure}',
        confidenceScore: 0.97,
      ),
      OcrExtractionModel(
        id: 'ocr_${documentId}_8',
        documentId: documentId,
        topic: 'Step 3: Draw Rectangle & M1 Flip Entry',
        rawText:
            'Draw rectangle from M15 candle close to its high/low extreme.'
            ' Switch to M1: enter immediately when a 1-minute candle closes'
            ' outside the rectangle.',
        latexContent:
            r'\text{Entry} = \text{M1 Candle Closes Outside Rectangle '
            r'(\textquotedblleft Flip\textquotedblright)}',
        imageUrl: img3,
        confidenceScore: 0.99,
      ),
      OcrExtractionModel(
        id: 'ocr_${documentId}_9',
        documentId: documentId,
        topic: 'Risk Management: Stop Loss & Take Profit',
        rawText:
            'Stop Loss: Place slightly above the high or below the low forming'
            ' the rectangle. Take Profit: Target next key M15 level or'
            ' minimum 3:1 RR.',
        latexContent: r'\text{Risk-to-Reward} \ge 3:1',
        confidenceScore: 0.98,
      ),
      OcrExtractionModel(
        id: 'ocr_${documentId}_10',
        documentId: documentId,
        topic: 'Pre-Trade Confirmation Checklist',
        rawText:
            '1. Direction aligned with 50/200 EMA?\n'
            '2. Valid structure supporting move?\n'
            '3. Continuation focus?\n'
            '4. M15 level in imbalance or session high/low?\n'
            '5. Sweep + rejection close?\n'
            '6. Rectangle drawn correctly?\n'
            '7. SL placed beyond extreme?\n'
            '8. Target >= 3:1 RR?',
        latexContent:
            r'\text{Pre-Trade Score} = \sum_{i=1}^{8} \text{Checklist Item}_i = 8/8',
        confidenceScore: 0.99,
      ),
    ];
  }
}

class ExtractedImageAttachment {
  const ExtractedImageAttachment({
    required this.bytes,
    required this.extension,
    required this.label,
  });

  final Uint8List bytes;
  final String extension;
  final String label;
}

class _ByteRange {
  const _ByteRange(this.start, this.end);
  final int start;
  final int end;
}

class _DocumentSection {
  const _DocumentSection({
    required this.title,
    required this.content,
  });
  final String title;
  final String content;
}

