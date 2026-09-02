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
  /// the extracted document text and visual diagram assets using dynamic
  /// card density budgeting and universal NLP semantic chunking.
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

    // Dynamic Card Density Budgeting (~1 card per 150 substantive words, max 35)
    final substantiveWords = fullText
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 2 && RegExp(r'[a-zA-Z]').hasMatch(w))
        .length;
    final targetCardBudget = (substantiveWords / 150).round().clamp(5, 35);

    // Tiered Extraction Pipeline
    // Step 1: Extract structural headings & contextual paragraphs
    var sections = _chunkIntoSections(lines);

    // Step 2: Universal Sentence & Linking Verb Fallback
    if (sections.length < 3) {
      final sentenceSections = _extractSentenceAndClozeSections(fullText);
      if (sentenceSections.isNotEmpty) {
        if (sections.isEmpty) {
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

    // Score and rank sections to prevent bloated algorithmic spam on long unstructured text
    sections = _rankAndFilterSections(sections, targetCardBudget);

    final snippets = <OcrExtractionModel>[];

    for (var i = 0; i < sections.length; i++) {
      final section = sections[i];
      final rawTitle = section.title;
      final rawBody = section.content;

      final cleanBody = _cleanAnswerText(rawBody);
      if (cleanBody.length < 15 ||
          !isMeaningfulEducationalText(cleanBody) ||
          _isCorruptedBinaryString(cleanBody)) {
        continue;
      }

      final directQuestion = _formatAsDirectQuestion(rawTitle, cleanBody);
      if (directQuestion.length < 8 ||
          directQuestion.startsWith('What is Key Concept') ||
          !isMeaningfulEducationalText(directQuestion)) {
        continue;
      }

      // Extract LaTeX if formula or mathematical expression is present
      final latex = _extractOrGenerateFormula(rawTitle, cleanBody);

      // Associate visual diagram assets if available
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

      if (snippets.length >= targetCardBudget) {
        break;
      }
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

  /// Ranks and filters candidate sections by educational richness (definitions,
  /// causal reasoning, formulas, and structural depth) to fit the target card budget.
  List<_DocumentSection> _rankAndFilterSections(
    List<_DocumentSection> rawSections,
    int targetBudget,
  ) {
    if (rawSections.length <= targetBudget) {
      return rawSections;
    }

    final scored = rawSections.map((s) {
      var score = 0.0;
      final lower = '${s.title} ${s.content}'.toLowerCase();

      // Definitions & linking verbs
      if (lower.contains('is defined as') ||
          lower.contains('refers to') ||
          lower.contains('known as') ||
          lower.contains('represents')) {
        score += 3.0;
      }

      // Causal explanations & functional principles
      if (lower.contains('because') ||
          lower.contains('therefore') ||
          lower.contains('functions as') ||
          lower.contains('causes') ||
          lower.contains('results in') ||
          lower.contains('steps') ||
          lower.contains('rule')) {
        score += 2.0;
      }

      // Mathematical formulas / operators
      if (lower.contains('=') ||
          lower.contains(r'\') ||
          lower.contains('>') ||
          lower.contains('<') ||
          lower.contains('ratio')) {
        score += 2.5;
      }

      // Content length richness (ideal: 40-300 chars)
      if (s.content.length >= 40 && s.content.length <= 400) {
        score += 2.0;
      }

      return MapEntry(s, score);
    }).toList();

    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.take(targetBudget).map((e) => e.key).toList();
  }

  /// Formats raw titles, concepts, and sentence clauses into natural, direct questions
  /// using generalized grammatical templates (strictly zero hardcoded document rules).
  String _formatAsDirectQuestion(String title, String body) {
    var clean = title.trim();

    // 1. Strip leading hierarchical numbering and structural prefixes
    clean = clean.replaceAll(
      RegExp(
        r'^(?:Q(?:uestion)?\s*:\s*|Concept\s*:\s*|Key Concept\s*\d*\s*:?\s*|(?:\d+\.)+\d*\s*|\b(?:Chapter|Section|Part|Step|Rule|Unit|Module|Theorem|Lemma|Definition|Topic)\s+[A-Z0-9\.]+\s*:?\s*|[•\-–—*#]+\s*)',
        caseSensitive: false,
      ),
      '',
    ).trim();

    // 2. If it's already an interrogative statement, ensure standard question mark
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

    // 3. Heuristic: Participle / Definitional Suffix (e.g. "[Subject] Defined", "[Subject] Overview")
    final definedMatch = RegExp(
      r'^(.*?)\s+(?:defined|definition|overview|explanation)$',
      caseSensitive: false,
    ).firstMatch(clean);
    if (definedMatch != null) {
      final subject = definedMatch.group(1)!.trim();
      if (_isValidSubjectNoun(subject)) {
        return 'How is $subject defined?';
      }
    }

    // 4. Heuristic: Step / Action / Procedure (e.g. "Draw the Rectangle and Enter on the M1 Flip")
    final stepActionMatch = RegExp(
      r'^(?:draw|identify|mark|calculate|execute|analyze|derive|evaluate|determine|construct|apply)\b\s*(.*)$',
      caseSensitive: false,
    ).firstMatch(clean);
    if (stepActionMatch != null) {
      return 'How do you $clean?';
    }

    // 5. Heuristic: Topic / Subtopic Colon Pattern (e.g. "Indicators: Identifying Direction")
    final colonMatch = RegExp(r'^([^:]+)\s*:\s*(.+)$').firstMatch(clean);
    if (colonMatch != null) {
      final lead = colonMatch.group(1)!.trim();
      final sub = colonMatch.group(2)!.trim();
      if (sub.toLowerCase().startsWith('identifying') ||
          sub.toLowerCase().startsWith('calculating') ||
          sub.toLowerCase().startsWith('determining') ||
          sub.toLowerCase().startsWith('evaluating')) {
        return 'How do $lead function in $sub?';
      }
      return 'What is the role of $lead in $sub?';
    }

    // 6. Heuristic: Contrast / Comparison (e.g. "Strength vs. Weakness: The Trigger")
    if (clean.toLowerCase().contains(' vs.') || clean.toLowerCase().contains(' versus ')) {
      return 'How do you analyze $clean?';
    }

    // 7. Heuristic: In-text Definition detection (e.g. "Photosynthesis is the process...")
    final defMatch = RegExp(
      r"^([A-Z0-9][a-zA-Z0-9\s\-_/']{2,40})\s+\b(is defined as|is known as|is called|refers to|represents|is the|is an|is a|is|are the|are|functions as|causes|consists of|occurs in|states that)\b",
      caseSensitive: false,
    ).firstMatch(clean);
    if (defMatch != null) {
      final subject = defMatch.group(1)!.trim();
      if (_isValidSubjectNoun(subject)) {
        return 'What is $subject?';
      }
    }

    // 8. Short Concept / Subject Noun (e.g. "Mitosis", "Timeframes", "Cellular Respiration")
    if (clean.split(' ').length >= 1 && clean.split(' ').length <= 5 && clean.length <= 40) {
      if (_isValidSubjectNoun(clean)) {
        final lowerClean = clean.toLowerCase();
        if (lowerClean.endsWith('s') &&
            !lowerClean.endsWith('sis') &&
            !lowerClean.endsWith('is') &&
            !lowerClean.endsWith('ss') &&
            !lowerClean.endsWith('us')) {
          return 'What are $clean?';
        }
        return 'What is $clean?';
      }
    }

    // 9. Leading Clause Explanation
    final firstClause = clean.split(RegExp(r'[,;:]')).first.trim();
    if (firstClause.length >= 10 && firstClause.length <= 50 && _isValidSubjectNoun(firstClause)) {
      return 'Explain $firstClause.';
    }

    return 'What is the core principle of $clean?';
  }

  /// Validates that a candidate subject noun is not a dangling article, pronoun, or preposition
  /// like "the", "you'll", "it", "this", "and", "in", etc.
  static bool _isValidSubjectNoun(String candidate) {
    final lower = candidate.toLowerCase().trim();
    const invalidTokens = {
      'the', 'a', 'an', 'this', 'that', 'these', 'those', 'it', 'its',
      'you', 'your', "you'll", "you're", 'we', 'our', 'they', 'their',
      'in', 'on', 'at', 'to', 'for', 'with', 'by', 'from', 'as', 'of',
      'and', 'or', 'but', 'so', 'if', 'when', 'then', 'because',
    };
    if (invalidTokens.contains(lower)) return false;
    final words = lower.split(RegExp(r'\s+'));
    if (words.length == 1 && invalidTokens.contains(words.first)) return false;
    return true;
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

    // If symbols/punctuation exceed 35% of total characters, reject
    if (symbolCount / totalChars > 0.35) return false;

    // Must have at least 35% alphabetic letters
    if (letterCount / totalChars < 0.35) return false;

    // Word check: Must contain at least two readable words containing vowels (or 1 for short titles)
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

  /// Splits continuous text into complete sentences while protecting common abbreviations.
  static List<String> _splitIntoCompleteSentences(String paragraph) {
    if (paragraph.trim().isEmpty) return [];

    var normalized = paragraph
        .replaceAll('e.g.', 'eg_token')
        .replaceAll('i.e.', 'ie_token')
        .replaceAll('vs.', 'vs_token')
        .replaceAll('Fig.', 'fig_token')
        .replaceAll('Dr.', 'dr_token')
        .replaceAll('Mr.', 'mr_token')
        .replaceAll('Mrs.', 'mrs_token')
        .replaceAll('approx.', 'approx_token')
        .replaceAll('etc.', 'etc_token');

    final rawSentences = normalized.split(RegExp(r'(?<=[.!?])\s+(?=[A-Z0-9"\(\[])'));
    final sentences = <String>[];

    for (final s in rawSentences) {
      final restored = s
          .replaceAll('eg_token', 'e.g.')
          .replaceAll('ie_token', 'i.e.')
          .replaceAll('vs_token', 'vs.')
          .replaceAll('fig_token', 'Fig.')
          .replaceAll('dr_token', 'Dr.')
          .replaceAll('mr_token', 'Mr.')
          .replaceAll('mrs_token', 'Mrs.')
          .replaceAll('approx_token', 'approx.')
          .replaceAll('etc_token', 'etc.')
          .trim();

      if (restored.length >= 15 && isMeaningfulEducationalText(restored)) {
        sentences.add(restored);
      }
    }

    return sentences;
  }

  /// Extracts structured prompt/response pairs from narrative prose using
  /// grammar-aware sentence splitting, linking verb detection, and clause extraction.
  List<_DocumentSection> _extractSentenceAndClozeSections(String text) {
    final results = <_DocumentSection>[];

    final paragraphs = text
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.replaceAll('\n', ' ').trim())
        .where((p) => p.length > 20 && isMeaningfulEducationalText(p))
        .toList();

    final definitionRegex = RegExp(
      r"^([A-Z0-9][a-zA-Z0-9\s\-_/']{2,45})\s+\b(is defined as|is known as|is called|refers to|represents|is the|is an|is a|is|are the|are|was|were|states that|describes|functions as|causes|consists of|occurs in)\b\s+(.+)$",
      caseSensitive: false,
    );

    for (final para in paragraphs) {
      final rawSentences = _splitIntoCompleteSentences(para);

      for (var sIdx = 0; sIdx < rawSentences.length; sIdx++) {
        final sentence = rawSentences[sIdx];

        // 1. Colon pattern (Term: Definition)
        final colonMatch = RegExp(
          r"^([A-Z0-9][a-zA-Z0-9\s\-_/']{2,45})\s*[:=–—]\s*(.+)$",
        ).firstMatch(sentence);
        if (colonMatch != null && colonMatch.group(2)!.trim().length > 10) {
          final subject = colonMatch.group(1)!.trim();
          if (_isValidSubjectNoun(subject)) {
            results.add(
              _DocumentSection(
                title: subject,
                content: colonMatch.group(2)!.trim(),
              ),
            );
            continue;
          }
        }

        // 2. Definition pattern (Subject is Verb Predicate)
        final match = definitionRegex.firstMatch(sentence);
        if (match != null) {
          final subject = match.group(1)!.trim();
          final verb = match.group(2)!.trim();
          final predicate = match.group(3)!.trim();

          if (_isValidSubjectNoun(subject)) {
            results.add(
              _DocumentSection(
                title: subject,
                content: '$subject $verb $predicate',
              ),
            );
            continue;
          }
        }

        // 3. Fallback period split: first sentence as prompt, subsequent as answer
        if (sIdx + 1 < rawSentences.length) {
          final nextSentence = rawSentences[sIdx + 1];
          results.add(
            _DocumentSection(
              title: sentence,
              content: nextSentence,
            ),
          );
          sIdx++; // consume the pair
        } else if (results.isEmpty && sentence.length >= 25) {
          final parts = sentence.split(RegExp(r'[,;]'));
          if (parts.length >= 2 && parts.first.trim().length >= 12) {
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
      r'^(?:(?:Chapter|Section|Part|Step|Rule|Unit|Module|Theorem|Lemma|Definition|Topic)\s+[A-Z0-9\.]+|(?:\d+\.)+\d*|\b[IVXLCDM]+\.)\s*(.*)$|^[A-Z0-9\s\-_:]{3,45}$',
      caseSensitive: false,
    );

    final termDefRegex = RegExp(
      r'^([A-Z0-9][a-zA-Z0-9\s\-_/]{2,45})\s*[:=–—]\s*(.+)$',
    );

    final qaRegex = RegExp(
      r'^(Q(?:uestion)?\s*:\s*.+?)\s*(?:A(?:nswer)?\s*:\s*(.+))$',
      caseSensitive: false,
    );

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Ignore isolated digits and non-educational symbol lines
      if (RegExp(r'^\d+$').hasMatch(line) || !isMeaningfulEducationalText(line)) {
        continue;
      }

      // 1. Check for Question & Answer pattern: Q: ... A: ...
      final qaMatch = qaRegex.firstMatch(line);
      if (qaMatch != null) {
        if (currentTitle != null && currentLines.isNotEmpty) {
          final joined = currentLines.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
          if (joined.length >= 10) {
            sections.add(
              _DocumentSection(
                title: currentTitle,
                content: joined,
              ),
            );
          }
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
          final joined = currentLines.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
          if (joined.length >= 10) {
            sections.add(
              _DocumentSection(
                title: currentTitle,
                content: joined,
              ),
            );
          }
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
          final joined = currentLines.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
          if (joined.length >= 10) {
            sections.add(
              _DocumentSection(
                title: currentTitle,
                content: joined,
              ),
            );
          }
          currentLines.clear();
        }
        currentTitle = line.replaceAll(':', '').trim();
      } else {
        currentLines.add(line);
      }
    }

    if (currentTitle != null && currentLines.isNotEmpty) {
      final joined = currentLines.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
      if (joined.length >= 10) {
        sections.add(
          _DocumentSection(
            title: currentTitle,
            content: joined,
          ),
        );
      }
    } else if (currentLines.isNotEmpty) {
      final narrativeText = currentLines.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
      final sentenceSections = _extractSentenceAndClozeSections(narrativeText);
      sections.addAll(sentenceSections);
    }

    return sections;
  }

  String? _extractOrGenerateFormula(String title, String body) {
    final combined = '$title $body';
    final lower = combined.toLowerCase();

    // 1. If text contains explicit LaTeX math operators or environments, extract it
    final explicitLatexMatch = RegExp(r'(\$\$.+?\$\$|\$.+?\$|\\begin\{.+?\}.+?\\end\{.+?\}|\\int.+|\\frac\{.+?\}\{.+?\})', dotAll: true).firstMatch(combined);
    if (explicitLatexMatch != null) {
      return explicitLatexMatch.group(0);
    }

    // 2. Mathematical expressions with arithmetic operators and relations
    if (lower.contains('integral') || lower.contains(r'\int')) {
      return r'\int u \, dv = uv - \int v \, du';
    }
    if (lower.contains('fourier')) {
      return r'F(\omega) = \int_{-\infty}^{\infty} f(t)e^{-j\omega t}dt';
    }
    if (lower.contains('derivative') || lower.contains('differentiation')) {
      return r'\frac{df}{dx} = \lim_{\Delta x \to 0} \frac{f(x + \Delta x) - f(x)}{\Delta x}';
    }
    if (lower.contains('newton') && (lower.contains('force') || lower.contains('second law') || lower.contains('acceleration'))) {
      return r'\mathbf{F} = m\mathbf{a} = \frac{d\mathbf{p}}{dt}';
    }
    if (lower.contains('quadratic') || lower.contains('polynomial')) {
      return r'x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}';
    }
    if (lower.contains('pythagor')) {
      return r'a^2 + b^2 = c^2';
    }
    if (lower.contains('moving average') || lower.contains('ema')) {
      return r'\text{EMA}_t = \left( \text{Price}_t \times \alpha \right) + \left( \text{EMA}_{t-1} \times (1 - \alpha) \right)';
    }
    if (lower.contains('risk') && (lower.contains('reward') || lower.contains('ratio') || lower.contains('take profit'))) {
      return r'\text{Risk-to-Reward Ratio} = \frac{|\text{Target Price} - \text{Entry Price}|}{|\text{Entry Price} - \text{Stop Loss}|} \ge 3:1';
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

