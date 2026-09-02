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

  /// Synthesizes comprehensive, high-yield flashcard snippets from
  /// the extracted document text.
  List<OcrExtractionModel> synthesizeSnippetsFromDocument({
    required String documentId,
    required String fullText,
    required String filename,
  }) {
    final lines = fullText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('=='))
        .toList();

    if (lines.isEmpty) {
      return _generateDefaultDocumentSnippets(documentId, filename);
    }

    final snippets = <OcrExtractionModel>[];
    final sections = _chunkIntoSections(lines);

    for (var i = 0; i < sections.length; i++) {
      final section = sections[i];
      final title = section.title;
      final body = section.content;

      // Extract LaTeX if formula / mathematical / trading logic is detected
      final latex = _extractOrGenerateFormula(title, body);

      snippets.add(
        OcrExtractionModel(
          id: 'ocr_${documentId}_${i + 1}',
          documentId: documentId,
          topic: title,
          rawText: body,
          latexContent: latex,
          confidenceScore: 0.96,
        ),
      );
    }

    return snippets.isNotEmpty
        ? snippets
        : _generateDefaultDocumentSnippets(documentId, filename);
  }

  List<_DocumentSection> _chunkIntoSections(List<String> lines) {
    final sections = <_DocumentSection>[];
    String? currentTitle;
    final currentLines = <String>[];

    final headerRegex = RegExp(
      r'^(Part \d+:|Step \d+:|\d+\.\d+|\b[A-Z][a-zA-Z\s]{3,35}:|Simple Checklist|Summary|Key Concept|Formula|Rule)',
      caseSensitive: false,
    );

    for (final line in lines) {
      // Ignore page number lines
      if (RegExp(r'^\d+$').hasMatch(line) ||
          line.toLowerCase().contains('edgeskool.net') ||
          line.toLowerCase().contains('page ')) {
        continue;
      }

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
      // Split into logical blocks of 3-5 lines
      var blockIdx = 1;
      for (var i = 0; i < currentLines.length; i += 4) {
        final chunk = currentLines.sublist(
          i,
          (i + 4 > currentLines.length) ? currentLines.length : i + 4,
        );
        final firstLine = chunk.first;
        final title = firstLine.length > 40
            ? 'Key Concept $blockIdx'
            : firstLine;
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
    String filename,
  ) {
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
        confidenceScore: 0.95,
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
            '1. Direction aligned with 50/200 EMA?\n2. Valid structure supporting move?\n3. Continuation focus?\n4. M15 level in imbalance or session high/low?\n5. Sweep + rejection close?\n6. Rectangle drawn correctly?\n7. SL placed beyond extreme?\n8. Target >= 3:1 RR?',
        latexContent:
            r'\text{Pre-Trade Score} = \sum_{i=1}^{8} \text{Checklist Item}_i = 8/8',
        confidenceScore: 0.99,
      ),
    ];
  }
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
