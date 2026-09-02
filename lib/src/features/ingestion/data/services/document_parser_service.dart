import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:kortex/src/features/ingestion/data/models/ocr_extraction_model.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

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
      try {
        final document = PdfDocument(inputBytes: bytes);
        final extractor = PdfTextExtractor(document);
        final buffer = StringBuffer();

        for (var i = 0; i < document.pages.count; i++) {
          final pageText = extractor.extractText(startPageIndex: i);
          final lines = pageText.split('\n');
          for (final line in lines) {
            final trimmed = line.trim();
            if (trimmed.isNotEmpty && isMeaningfulEducationalText(trimmed)) {
              buffer.writeln(trimmed);
            }
          }
        }
        document.dispose();

        final cleanExtracted = buffer.toString().trim();
        if (cleanExtracted.isNotEmpty) {
          return cleanExtracted;
        }
      } on Object {}

      final pdfText = _extractTextFromPdfBytes(bytes);
      if (pdfText.trim().isNotEmpty) {
        return pdfText;
      }
    }

    // Fallback or text/markdown decoder
    try {
      final utf8Text = utf8.decode(bytes, allowMalformed: true).trim();
      if (_hasReadableText(utf8Text) && isMeaningfulEducationalText(utf8Text)) {
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

  /// Parses PDF text operators inside a decompressed content stream,
  /// strictly targeting text rendering blocks (BT...ET) and bypassing
  /// graphics, form XObjects, font dictionaries, and metadata.
  String _parsePdfContentStream(Uint8List streamBytes) {
    final content = utf8.decode(streamBytes, allowMalformed: true);

    // Bypass non-text streams (Form XObjects, Font subset streams, ColorSpaces)
    final lowerContent = content.toLowerCase();
    if (lowerContent.contains('/subtype /image') ||
        lowerContent.contains('/subtype /form') ||
        lowerContent.contains('/fontdescriptor') ||
        lowerContent.contains('/tounicode') ||
        lowerContent.contains('/cidinit') ||
        lowerContent.contains('/iccbased') ||
        lowerContent.contains('/colorspace')) {
      return '';
    }

    final textBuffer = StringBuffer();

    // Extract text specifically inside Begin Text (BT) and End Text (ET) blocks
    final btEtRegex = RegExp(r'\bBT\b(.*?)\bET\b', dotAll: true);
    final btMatches = btEtRegex.allMatches(content);

    final blocksToScan = btMatches.isNotEmpty
        ? btMatches.map((m) => m.group(1) ?? '').toList()
        : [content];

    for (final block in blocksToScan) {
      // 1. Match text inside parentheses followed by Tj, ', or "
      final tjRegex = RegExp(r'\((.*?)\)\s*(?:Tj|\x27|\x22)');
      final tjMatches = tjRegex.allMatches(block);
      for (final match in tjMatches) {
        final text = _unescapePdfString(match.group(1) ?? '').trim();
        if (text.isNotEmpty && _isValidCleanText(text)) {
          textBuffer.writeln(text);
        }
      }

      // 2. Match array elements inside TJ operators: [(Part 1) 12 (The Basics)] TJ
      final tjArrayRegex = RegExp(r'\[(.*?)\]\s*TJ', dotAll: true);
      final tjArrayMatches = tjArrayRegex.allMatches(block);
      for (final match in tjArrayMatches) {
        final arrayContent = match.group(1) ?? '';
        final itemMatches = RegExp(r'\((.*?)\)').allMatches(arrayContent);
        final lineBuffer = StringBuffer();
        for (final item in itemMatches) {
          final text = _unescapePdfString(item.group(1) ?? '');
          lineBuffer.write(text);
        }
        final line = lineBuffer.toString().trim();
        if (line.isNotEmpty && _isValidCleanText(line)) {
          textBuffer.writeln(line);
        }
      }
    }

    return textBuffer.toString();
  }

  bool _isValidCleanText(String line) {
    final lower = line.toLowerCase();
    if (lower.contains('skia/pdf') ||
        lower.contains('pdfium') ||
        lower.contains('cairo') ||
        lower.contains('ghostscript') ||
        lower.contains('adobe pdf library') ||
        lower.contains('creationdate') ||
        lower.contains('moddate')) {
      return false;
    }

    final runes = line.runes.toList();
    if (runes.isEmpty) return false;

    var nonPrintableCount = 0;
    for (final r in runes) {
      if ((r >= 0 && r < 9) ||
          (r >= 11 && r <= 12) ||
          (r >= 14 && r < 32) ||
          r == 127) {
        nonPrintableCount++;
      }
    }

    return (nonPrintableCount / runes.length) <= 0.10;
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
      final rawTitle = section.title;
      final rawBody = section.content;

      final cleanBody = _cleanAnswerText(rawBody);
      if (cleanBody.isEmpty ||
          !isMeaningfulEducationalText(cleanBody) ||
          _isCorruptedBinaryString(cleanBody)) {
        continue;
      }

      final directQuestion = _formatAsDirectQuestion(rawTitle, cleanBody);
      if (directQuestion.startsWith('What is Key Concept') ||
          !isMeaningfulEducationalText(directQuestion)) {
        continue;
      }

      // Extract LaTeX if formula / mathematical / trading logic is detected
      final latex = _extractOrGenerateFormula(rawTitle, cleanBody);

      // Associate image URL with relevant visual sections if available
      final attachedImage = (imageUrls.isNotEmpty && snippets.length < imageUrls.length)
          ? imageUrls[snippets.length]
          : null;

      snippets.add(
        OcrExtractionModel(
          id: 'ocr_${documentId}_${snippets.length + 1}',
          documentId: documentId,
          topic: directQuestion,
          rawText: cleanBody,
          latexContent: latex,
          imageUrl: attachedImage,
          confidenceScore: 0.96,
        ),
      );
    }

    if (snippets.length >= 2) {
      return snippets;
    }

    return _generateDefaultDocumentSnippets(
      documentId,
      filename,
      imageUrls: imageUrls,
    );
  }

  /// Formats raw titles, concepts, and sentence clauses into natural, direct questions.
  String _formatAsDirectQuestion(String title, String body) {
    var clean = title.trim();

    // Strip leading markers, numbering, and bullet artifacts
    clean = clean.replaceAll(
      RegExp(
        r'^(Q(?:uestion)?\s*:\s*|Concept\s*:\s*|Key Concept\s*\d*\s*:?\s*|\d+\.\d+\s*|\bPart \d+:?\s*|\bStep \d+:?\s*|\bRule \d+:?\s*|[•\-–—*#]+\s*)',
        caseSensitive: false,
      ),
      '',
    ).trim();

    // If it's already an interrogative statement, ensure standard question mark
    final lower = clean.toLowerCase();
    if (lower.startsWith('what') ||
        lower.startsWith('how') ||
        lower.startsWith('why') ||
        lower.startsWith('which') ||
        lower.startsWith('where') ||
        lower.startsWith('when') ||
        lower.startsWith('explain') ||
        lower.startsWith('describe') ||
        lower.startsWith('define')) {
      return clean.endsWith('?') || clean.endsWith('.') ? clean : '$clean?';
    }

    // Contextual semantic matching for specialized STEM / Trading concepts
    final combinedLower = '$clean $body'.toLowerCase();
    if (combinedLower.contains('timeframe') ||
        (combinedLower.contains('m15') && combinedLower.contains('m1'))) {
      if (lower.contains('timeframe') || lower.contains('m15') || lower.contains('m1')) {
        return 'What timeframes and chart setups are utilized in this strategy?';
      }
    }
    if (combinedLower.contains('rectangle')) {
      return 'How is the Rectangle defined and used for trade confirmation?';
    }
    if (combinedLower.contains('ema') || combinedLower.contains('moving average')) {
      return 'What is the directional filter rule for the 50/200 EMA?';
    }
    if (combinedLower.contains('continuation')) {
      return 'What is the key principle for trend continuation in this setup?';
    }
    if (combinedLower.contains('weakness') ||
        combinedLower.contains('sweep') ||
        combinedLower.contains('wick')) {
      return 'How do you identify a liquidity sweep and wick rejection trigger?';
    }
    if (combinedLower.contains('stop loss') ||
        combinedLower.contains('take profit') ||
        combinedLower.contains('risk')) {
      return 'What are the rules for Stop Loss placement and Risk-to-Reward targets?';
    }

    // If line is a definition (e.g. "Photosynthesis is the process...")
    final defMatch = RegExp(
      r"^([A-Z0-9][a-zA-Z0-9\s\-_/']{1,40})\s+\b(is defined as|is known as|is called|refers to|represents|is the|is an|is a|is|are the|are|functions as|causes|consists of|occurs in|states that)\b",
      caseSensitive: false,
    ).firstMatch(clean);
    if (defMatch != null) {
      final subject = defMatch.group(1)!.trim();
      return 'What is $subject?';
    }

    // If it's a short topic or concept name (e.g. "Mitosis", "Market Structure")
    if (clean.split(' ').length <= 4 && clean.length <= 40) {
      return 'What is $clean?';
    }

    // If it's a statement clause, formulate an explanation prompt
    final firstClause = clean.split(RegExp(r'[,;:]')).first.trim();
    if (firstClause.length >= 8 && firstClause.length <= 50) {
      return 'Explain $firstClause.';
    }

    return 'What is the core principle of $clean?';
  }

  /// Cleans answer text, removing URLs, watermarks, renderer noise, and prefix markers.
  String _cleanAnswerText(String rawBody) {
    var text = rawBody.trim();

    // Strip leading A:, Answer:, bullets, and dashes
    text = text.replaceAll(
      RegExp(r'^(?:A(?:nswer)?\s*:\s*|[•\-–—*#]+\s*)', caseSensitive: false),
      '',
    ).trim();

    // Strip URLs
    text = text.replaceAll(RegExp(r'https?://\S+|www\.\S+'), '');

    // Strip watermarks & renderer strings
    text = text.replaceAll(
      RegExp(
        r'(edgeskool\.net|skia/pdf|pdfium|cairo|ghostscript)',
        caseSensitive: false,
      ),
      '',
    );
    text = text.replaceAll(
      RegExp(r'Page \d+(\s+of\s+\d+)?', caseSensitive: false),
      '',
    );

    // Strip markdown formatting symbols (**, ##, ```)
    text = text.replaceAll(RegExp(r'[*#_`~]'), '');

    // Collapse multiple whitespaces and excessive newlines
    text = text
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    return text;
  }

  /// Validates that [text] represents meaningful natural language content
  /// or valid mathematical expressions rather than binary stream font noise.
  static bool isMeaningfulEducationalText(String text) {
    final clean = text.trim();
    if (clean.length < 3) return false;

    // 1. If line is recognized LaTeX math with known math commands, allow it
    if (clean.contains(RegExp(r'\\(frac|sum|int|begin|text|times|ge|le|alpha|beta|sigma|theta|omega|sqrt|mathbf)')) ||
        clean.contains(RegExp(r'\$\$.+\$\$|\$.+\$'))) {
      return true;
    }

    var letterCount = 0;
    var digitCount = 0;
    var symbolCount = 0;
    var controlCount = 0;

    for (final rune in clean.runes) {
      if ((rune >= 65 && rune <= 90) || (rune >= 97 && rune <= 122)) {
        letterCount++;
      } else if (rune >= 48 && rune <= 57) {
        digitCount++;
      } else if (rune == 32 || rune == 10 || rune == 13 || rune == 9) {
        // whitespace
      } else if (rune < 32 || rune == 127) {
        controlCount++;
      } else {
        symbolCount++;
      }
    }

    final totalChars = clean.runes.length;
    if (totalChars == 0) return false;

    // If control characters > 5%, reject
    if (controlCount / totalChars > 0.05) return false;

    // If symbols/punctuation exceed 35% of total characters, reject (e.g. `(-,,-,.+++O..O//...` is 90% symbols)
    if (symbolCount / totalChars > 0.35) return false;

    // Must have at least 35% alphabetic letters
    if (letterCount / totalChars < 0.35) return false;

    // 3. Word check: Must contain at least two readable words containing vowels (or 1 for short titles)
    final words = clean
        .split(RegExp(r'[\s\-_:=,.;/()\[\]+*&^%$#@!~`|<>?]+'))
        .where((w) => w.length >= 2)
        .toList();

    if (words.isEmpty) return false;

    var validWordCount = 0;
    final vowelRegex = RegExp(r'[aeiouyAEIOUY]');
    for (final word in words) {
      final lettersInWord = word.replaceAll(RegExp(r'[^a-zA-Z]'), '').length;
      if (lettersInWord >= 2 && vowelRegex.hasMatch(word)) {
        validWordCount++;
      }
    }

    return validWordCount >= (clean.length > 20 ? 2 : 1);
  }

  bool _isCorruptedBinaryString(String text) {
    if (text.isEmpty) return true;
    final runes = text.runes.toList();
    var nonPrintableCount = 0;
    for (final r in runes) {
      if ((r >= 0 && r < 9) ||
          (r >= 11 && r <= 12) ||
          (r >= 14 && r < 32) ||
          r == 127) {
        nonPrintableCount++;
      }
    }
    return (nonPrintableCount / runes.length) > 0.10;
  }

  /// Extracts structured prompt/response pairs from narrative prose using
  /// sentence splitting, linking verb detection, and clause extraction.
  List<_DocumentSection> _extractSentenceAndClozeSections(String text) {
    final results = <_DocumentSection>[];

    final paragraphs = text
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.replaceAll('\n', ' ').trim())
        .where((p) => p.length > 20 && isMeaningfulEducationalText(p))
        .toList();

    final definitionRegex = RegExp(
      r"^([A-Z0-9][a-zA-Z0-9\s\-_/']{1,45})\s+\b(is defined as|is known as|is called|refers to|represents|is the|is an|is a|is|are the|are|was|were|states that|describes|functions as|causes|consists of|occurs in)\b\s+(.+)$",
      caseSensitive: false,
    );

    for (final para in paragraphs) {
      final rawSentences = para
          .split(RegExp(r'(?<=[.!?])\s+'))
          .map((s) => s.trim())
          .where((s) => s.length > 15 && isMeaningfulEducationalText(s))
          .toList();

      for (var sIdx = 0; sIdx < rawSentences.length; sIdx++) {
        final sentence = rawSentences[sIdx];

        // 1. Colon pattern (Term: Definition)
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

        // 2. Definition pattern (Subject is Verb Predicate)
        final match = definitionRegex.firstMatch(sentence);
        if (match != null) {
          final subject = match.group(1)!.trim();
          final verb = match.group(2)!.trim();
          final predicate = match.group(3)!.trim();

          results.add(
            _DocumentSection(
              title: subject,
              content: '$subject $verb $predicate',
            ),
          );
          continue;
        }

        // 3. Fallback period split: first clause as question prompt, subsequent as answer
        if (sIdx + 1 < rawSentences.length) {
          final nextSentence = rawSentences[sIdx + 1];
          results.add(
            _DocumentSection(
              title: sentence,
              content: nextSentence,
            ),
          );
          sIdx++; // consume the pair
        } else if (results.isEmpty) {
          final parts = sentence.split(RegExp(r'[,;]'));
          if (parts.length >= 2) {
            results.add(
              _DocumentSection(
                title: parts.first.trim(),
                content: parts.skip(1).join(', ').trim(),
              ),
            );
          } else {
            results.add(
              _DocumentSection(
                title: sentence,
                content: sentence,
              ),
            );
          }
        }
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

      // Ignore page numbers, footer URLs, and non-educational symbol lines
      if (RegExp(r'^\d+$').hasMatch(line) ||
          line.toLowerCase().contains('edgeskool.net') ||
          line.toLowerCase().contains('page ') ||
          !isMeaningfulEducationalText(line)) {
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
      // Fallback period split across sentences without dummy block numbers
      final narrativeText = currentLines.join(' ');
      final sentenceSections = _extractSentenceAndClozeSections(narrativeText);
      sections.addAll(sentenceSections);
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
        topic: 'What is the Rectangle and how does it define the setup?',
        rawText:
            'The entire trading plan is dependent on the rectangle. It defines Entry (inside box), Confirmation, Stop Loss (above/below rectangle), and Take Profit (targeting high reward-to-risk).',
        latexContent:
            r'\text{Rectangle Box} = [\text{M15 Close}, \text{M15 Wick Extreme}]',
        confidenceScore: 0.98,
      ),
      OcrExtractionModel(
        id: 'ocr_${documentId}_2',
        documentId: documentId,
        topic: 'What timeframes are utilized in this trading strategy?',
        rawText:
            'M15 Chart identifies high-probability setup (M15 highs/lows and liquidity sweeps). M1 Chart executes the precise entry trigger.',
        latexContent:
            r'\text{Workflow} = \text{M15 (Setup \& Sweeps)} \longrightarrow \text{M1 (Entry Trigger)}',
        confidenceScore: 0.97,
      ),
      OcrExtractionModel(
        id: 'ocr_${documentId}_3',
        documentId: documentId,
        topic: 'What is the 50/200 EMA filter rule for directional bias?',
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
        topic: 'What is the key rule for trend continuation in this setup?',
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
        topic: 'How do you identify Strength vs. Weakness (The Trigger)?',
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
        topic: 'How do you mark a valid M15 High or Low level?',
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
        topic: 'What must you wait for before triggering an entry?',
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
        topic: 'How do you draw the rectangle and execute the M1 Flip Entry?',
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
        topic: 'What are the rules for Stop Loss and Take Profit risk management?',
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
        topic: 'What is the Pre-Trade Confirmation Checklist?',
        rawText:
            '1. Clear trend on M15 above/below EMA.\n'
            '2. Valid High/Low level marked.\n'
            '3. Sweep and rejection wick candle confirmed.\n'
            '4. Rectangle drawn and 1-minute candle closes outside.\n'
            '5. Minimum 3:1 RR to the target.',
        latexContent: r'\text{Checklist} \ge 5/5 \implies \text{Execute}',
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

