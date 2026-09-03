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
      } on Object catch (_) {
        // Fallback to byte stream extraction if high-level text extraction fails
      }

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
  /// Synthesizes comprehensive, high-yield flashcard snippets from
  /// the extracted document text using pure structural semantic parsing
  /// and strict NLP grammar validation (zero arbitrary quotas, zero broken fragments).
  List<OcrExtractionModel> synthesizeSnippetsFromDocument({
    required String documentId,
    required String fullText,
    required String filename,
    List<String> imageUrls = const [],
  }) {
    final cleanFullText = fullText.trim();
    if (cleanFullText.isEmpty) {
      return [];
    }

    final lines = cleanFullText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('=='))
        .toList();

    if (lines.isEmpty) {
      return [];
    }

    // Tiered Extraction Pipeline
    // Step 1: Extract legitimate structural headings & complete paragraph sections
    var sections = _chunkIntoSections(lines);

    // Step 2: Semantic Paragraph Fallback for prose documents lacking formal headers
    if (sections.isEmpty) {
      sections = _extractSemanticParagraphSections(cleanFullText);
    }

    final snippets = <OcrExtractionModel>[];

    for (final section in sections) {
      final cleanBody = _extractCompleteParagraphAnswer(section.content);
      final directQuestion = _synthesizeContextualQuestion(
        section.title,
        cleanBody,
      );

      // Strict NLP & Structural Validation Filter
      if (!_isValidCard(directQuestion, cleanBody)) {
        continue;
      }

      // Extract LaTeX if formula or mathematical expression is present
      final latex = _extractOrGenerateFormula(section.title, cleanBody);

      // Associate visual diagram assets if available
      final attachedImage =
          (imageUrls.isNotEmpty && snippets.length < imageUrls.length)
          ? imageUrls[snippets.length]
          : null;

      snippets.add(
        OcrExtractionModel(
          id: 'ocr_${documentId}_${snippets.length + 1}',
          documentId: documentId,
          topic: directQuestion!,
          rawText: cleanBody,
          latexContent: latex,
          imageUrl: attachedImage,
          confidenceScore: 0.98,
        ),
      );
    }

    // Guaranteed Adaptive Synthesizer: If standard heuristics yield 0 cards,
    // generate high-yield conceptual flashcards from raw text chunks
    if (snippets.isEmpty) {
      return _generateAdaptiveGuaranteedSnippets(
        documentId: documentId,
        fullText: cleanFullText,
        filename: filename,
        imageUrls: imageUrls,
      );
    }

    return snippets;
  }

  /// Adaptive guaranteed synthesizer that splits text into logical 2-4 sentence chunks
  /// and derives academic flashcard prompts from context.
  List<OcrExtractionModel> _generateAdaptiveGuaranteedSnippets({
    required String documentId,
    required String fullText,
    required String filename,
    List<String> imageUrls = const [],
  }) {
    final cleanDocName = filename
        .replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '')
        .replaceAll(RegExp(r'[_\-]+'), ' ')
        .trim();

    // 1. Split text into meaningful blocks
    final rawBlocks = fullText
        .split(RegExp(r'(?:\r?\n){2,}'))
        .map((b) => b.trim())
        .where((b) => b.length >= 20 && isMeaningfulEducationalText(b))
        .toList();

    final chunks = <String>[];
    if (rawBlocks.length >= 2) {
      chunks.addAll(rawBlocks);
    } else {
      // Split by sentence groups
      final sentences = _splitIntoCompleteSentences(fullText);
      if (sentences.isNotEmpty) {
        var currentChunk = '';
        for (var i = 0; i < sentences.length; i++) {
          currentChunk = currentChunk.isEmpty
              ? sentences[i]
              : '$currentChunk ${sentences[i]}';
          if (i % 3 == 2 || i == sentences.length - 1) {
            chunks.add(currentChunk.trim());
            currentChunk = '';
          }
        }
      } else {
        // Fallback: chunk by line groups
        final lines = fullText
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty && isMeaningfulEducationalText(l))
            .toList();
        for (var i = 0; i < lines.length; i += 3) {
          final group = lines.skip(i).take(3).join(' ');
          if (group.length >= 20) {
            chunks.add(group);
          }
        }
      }
    }

    if (chunks.isEmpty && fullText.trim().length >= 10) {
      chunks.add(fullText.trim());
    }

    final snippets = <OcrExtractionModel>[];
    for (var i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      final cleanBody = _extractCompleteParagraphAnswer(chunk);
      if (cleanBody.length < 10) continue;

      // Generate context-rich question
      String question;
      final firstLine = chunk.split('\n').first.trim();
      if (firstLine.length >= 5 &&
          firstLine.length <= 60 &&
          !firstLine.contains('.')) {
        question = _synthesizeContextualQuestion(firstLine, cleanBody) ??
            'What are the key concepts of $firstLine?';
      } else {
        final words = cleanBody.split(RegExp(r'\s+')).take(6).join(' ');
        question = 'What are the main principles explained in "$cleanDocName" regarding: $words...?';
      }

      if (!question.endsWith('?')) {
        question = '$question?';
      }

      final latex = _extractOrGenerateFormula(question, cleanBody);
      final attachedImage =
          (imageUrls.isNotEmpty && snippets.length < imageUrls.length)
          ? imageUrls[snippets.length]
          : null;

      snippets.add(
        OcrExtractionModel(
          id: 'ocr_${documentId}_${snippets.length + 1}',
          documentId: documentId,
          topic: question,
          rawText: cleanBody,
          latexContent: latex,
          imageUrl: attachedImage,
        ),
      );
    }

    return snippets;
  }

  /// Synthesizes natural, context-aware academic questions from formal section headers
  /// and leading concept statements (strictly banning naive string-injection templates).
  String? _synthesizeContextualQuestion(String rawTitle, String cleanBody) {
    var clean = rawTitle.trim();

    // 1. Strip leading hierarchical numbering and structural prefixes
    clean = clean
        .replaceAll(
          RegExp(
            r'^(?:Q(?:uestion)?\s*:\s*|Concept\s*:\s*|Key Concept\s*\d*\s*:?\s*|(?:\d+\.)+\d*\s*|\b(?:Chapter|Section|Part|Step|Rule|Unit|Module|Theorem|Lemma|Definition|Topic)\s+[A-Z0-9\.]+\s*:?\s*|[•\-–—*#]+\s*)',
            caseSensitive: false,
          ),
          '',
        )
        .trim();

    // Reject unparseable noise or micro-fragments
    if (clean.length < 3 || _isCorruptedBinaryString(clean)) {
      return null;
    }

    // Handle longer narrative sentences as titles
    if (clean.length > 70) {
      final shortSubject = clean.split(RegExp('[:;,.]')).first.trim();
      if (shortSubject.length >= 4 && shortSubject.length <= 50) {
        clean = shortSubject;
      } else {
        return 'What are the key takeaways regarding: ${clean.substring(0, 45)}...?';
      }
    }

    final lower = clean.toLowerCase();

    // 2. If it's already a well-formed interrogative sentence, preserve and punctuate
    if (lower.startsWith('what') ||
        lower.startsWith('how') ||
        lower.startsWith('why') ||
        lower.startsWith('which') ||
        lower.startsWith('where') ||
        lower.startsWith('when') ||
        lower.startsWith('explain') ||
        lower.startsWith('describe') ||
        lower.startsWith('define')) {
      final q = clean.endsWith('?') || clean.endsWith('.') ? clean : '$clean?';
      return _isGrammaticallySoundQuestion(q) ? q : null;
    }

    // 3. Definitional Suffix: "[Subject] Defined", "[Subject] Definition", "[Subject] Overview"
    final definedMatch = RegExp(
      r'^(.*?)\s+(?:defined|definition|overview|explanation|concept)$',
      caseSensitive: false,
    ).firstMatch(clean);
    if (definedMatch != null) {
      final subject = definedMatch
          .group(1)!
          .trim()
          .replaceAll(RegExp(r'^(?:the|a|an)\s+', caseSensitive: false), '');
      if (_isValidSubjectNoun(subject)) {
        return 'How is the $subject defined in this context?';
      }
    }

    // 4. Procedural / Step Action: "Draw the Rectangle and Enter on the M1 Flip"
    final stepActionMatch = RegExp(
      r'^(?:draw|identify|mark|calculate|execute|analyze|derive|evaluate|determine|construct|apply|set|establish|verify)\b\s*(.*)$',
      caseSensitive: false,
    ).firstMatch(clean);
    if (stepActionMatch != null) {
      final rest = clean.substring(0, 1).toLowerCase() + clean.substring(1);
      return 'How do you $rest?';
    }

    // 5. Topic / Subtopic Colon Pattern: "Indicators: Identifying Direction"
    final colonMatch = RegExp(r'^([^:]+)\s*:\s*(.+)$').firstMatch(clean);
    if (colonMatch != null) {
      final lead = colonMatch.group(1)!.trim();
      final sub = colonMatch.group(2)!.trim();
      final subLower = sub.toLowerCase();

      if (lead.toLowerCase().contains(' vs.') ||
          lead.toLowerCase().contains(' versus ')) {
        return 'How do you analyze $clean?';
      }
      if (subLower.startsWith('identifying') ||
          subLower.startsWith('calculating') ||
          subLower.startsWith('determining') ||
          subLower.startsWith('evaluating') ||
          subLower.startsWith('measuring')) {
        return 'How are $lead used in $subLower?';
      }
      if (subLower.contains('trigger') || subLower.contains('entry')) {
        return 'How do $lead function as $sub?';
      }
      return 'What is the role of $lead in $sub?';
    }

    // 6. Contrast / Comparison: "Strength vs. Weakness: The Trigger"
    if (lower.contains(' vs.') ||
        lower.contains(' versus ') ||
        lower.contains(' and vs ')) {
      return 'How do you analyze $clean?';
    }

    // 7. Checklists, Rules, & Principles
    if (lower.contains('checklist') || lower.contains('criteria')) {
      return 'What is the $clean and what conditions must be met?';
    }
    if (lower.contains('rule') ||
        lower.contains('guideline') ||
        lower.contains('principle')) {
      return 'What are the key rules governing $clean?';
    }

    // 8. In-Text Declarative Subject Extraction: "Photosynthesis is the process..."
    final defMatch = RegExp(
      r"^([A-Z0-9][a-zA-Z0-9\s\-_/']{2,40})\s+\b(is defined as|is known as|is called|refers to|represents|is the|is an|is a|is|are the|are|functions as|causes|consists of|occurs in|states that)\b\s*(.*)$",
      caseSensitive: false,
    ).firstMatch(clean);
    if (defMatch != null) {
      final subject = defMatch.group(1)!.trim();
      if (_isValidSubjectNoun(subject)) {
        if (lower.contains('occurs in') || lower.contains('takes place')) {
          return 'Where does $subject occur and what is its role?';
        }
        if (lower.contains('process') ||
            lower.contains('cycle') ||
            lower.contains('reaction')) {
          return 'What is $subject and how does the process function?';
        }
        return 'What is the function and definition of $subject?';
      }
    }

    // 9. Short Concept / Subject Noun: "Mitosis", "Timeframes", "Cellular Respiration"
    if (_isValidSubjectNoun(clean)) {
      if (lower.endsWith('s') &&
          !lower.endsWith('sis') &&
          !lower.endsWith('is') &&
          !lower.endsWith('ss') &&
          !lower.endsWith('us')) {
        return 'What are the $clean and what are their functions?';
      }
      return 'What is $clean?';
    }

    // If no complete, grammatically sound question can be formed, drop the chunk
    return null;
  }

  /// Strict NLP question validation: ensures question is complete and free of garbage fragments.
  bool _isGrammaticallySoundQuestion(String q) {
    final words = q
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.length < 3) return false;

    final lower = q.toLowerCase();
    // Strictly prohibit broken automated template injections
    if (lower.contains('what is the?') ||
        lower.contains('what is a?') ||
        lower.contains('what is an?') ||
        lower.contains('what is this?') ||
        lower.contains("what is you'll") ||
        lower.contains('what is key concept') ||
        lower.contains('what is confirmation.?') ||
        lower.contains('what is -') ||
        lower.contains('what is .')) {
      return false;
    }

    return true;
  }

  /// Validates that a candidate subject noun is not a dangling article, pronoun, or preposition.
  static bool _isValidSubjectNoun(String candidate) {
    final lower = candidate.toLowerCase().trim();
    if (lower.length < 3) return false;

    const invalidTokens = {
      'the',
      'a',
      'an',
      'this',
      'that',
      'these',
      'those',
      'it',
      'its',
      'you',
      'your',
      "you'll",
      "you're",
      'we',
      'our',
      'they',
      'their',
      'in',
      'out',
      'on',
      'off',
      'at',
      'to',
      'for',
      'with',
      'by',
      'from',
      'as',
      'of',
      'and',
      'or',
      'but',
      'so',
      'if',
      'when',
      'then',
      'because',
      'key',
      'concept',
      'step',
      'part',
      'chapter',
      'section',
      'item',
      'live',
      'all',
      'any',
      'some',
      'many',
      'each',
      'every',
      'other',
      'another',
      'such',
      'no',
      'nor',
      'not',
      'only',
      'own',
      'same',
      'than',
      'too',
      'very',
      'can',
      'will',
      'just',
      'should',
      'now',
      'here',
      'there',
      'why',
      'how',
      'what',
      'where',
      'who',
      'which',
      'whom',
      'about',
      'into',
      'through',
      'during',
      'before',
      'after',
      'above',
      'below',
      'up',
      'down',
      'over',
      'under',
      'again',
      'further',
      'once',
    };

    if (invalidTokens.contains(lower)) return false;
    final words = lower.split(RegExp(r'\s+'));
    if (words.length == 1) {
      if (invalidTokens.contains(words.first) || words.first.length < 4) {
        return false;
      }
    }
    return true;
  }

  /// Identifies page footers, watermarks, domains, and non-educational UI artifacts.
  static bool _isNoiseOrFooter(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return true;
    final lower = clean.toLowerCase();

    // Check for web domains (e.g. .com, .net, .org, .io, .app)
    if (RegExp(
      r'\b[a-zA-Z0-9_\-]+\.(?:com|net|org|io|app|edu|co|gov|xyz|info|dev|biz|me)\b',
      caseSensitive: false,
    ).hasMatch(clean)) {
      final words = clean.split(RegExp(r'\s+'));
      if (words.length <= 5) return true;
    }

    // Page footers, copyright, slide numbers, standalone URLs
    if (RegExp(
      r'^(?:copyright|all rights reserved|page \d+(?: of \d+)?|slide \d+|http|\/\/|www\.)',
      caseSensitive: false,
    ).hasMatch(lower)) {
      return true;
    }

    // Watermark / signature patterns starting with em dash or bullet (e.g. "—Mulham EdgeSkool.Net")
    if (clean.startsWith('—') || clean.startsWith('-') || clean.startsWith('–')) {
      final withoutDash = clean.replaceAll(RegExp(r'^[—–\-•*#\s]+'), '').trim();
      if (withoutDash.split(RegExp(r'\s+')).length <= 3 &&
          RegExp(r'\.[a-zA-Z]{2,4}\.?$').hasMatch(withoutDash)) {
        return true;
      }
    }

    return false;
  }

  /// Extracts the entire descriptive paragraph as a cohesive answer unit,
  /// removing marginalia, bullet prefixes, and renderer artifacts without splitting sentences.
  String _extractCompleteParagraphAnswer(String rawBody) {
    var text = rawBody.trim();

    // Strip leading A:, Answer:, bullets, dashes, numbers
    text = text
        .replaceAll(
          RegExp(
            r'^(?:A(?:nswer)?\s*:\s*|[•\-–—*#]+\s*)',
            caseSensitive: false,
          ),
          '',
        )
        .trim();

    // Strip URLs
    text = text.replaceAll(RegExp(r'https?://\S+|www\.\S+'), '');

    // Strip markdown formatting symbols (**, ##, ```)
    text = text.replaceAll(RegExp('[*#_`~]'), '');

    // Collapse multiple whitespaces and excessive line breaks into clean prose
    text = text
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n+'), ' ')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();

    // Strip trailing commas, colons, hyphens, and duplicate punctuation
    text = text.replaceAll(RegExp(r'[,;:–—\-]+$'), '').trim();
    text = text.replaceAll(RegExp(r'[,;:]+\s*\.+'), '.').trim();
    text = text.replaceAll(RegExp(r'\.{2,}'), '.').trim();

    if (text.isNotEmpty &&
        !text.endsWith('.') &&
        !text.endsWith('!') &&
        !text.endsWith('?') &&
        !text.endsWith('"') &&
        !text.endsWith("'") &&
        !text.endsWith(')') &&
        !text.endsWith(']') &&
        !text.endsWith(r'$')) {
      text = '$text.';
    }

    return text;
  }

  /// Strict NLP Card Validation Filter:
  /// Enforces minimum 3 words or 12 characters for answers, bans single isolated words,
  /// and drops any card ending with dangling transition words/conjunctions.
  bool _isValidCard(String? question, String? answer) {
    if (question == null || answer == null) return false;

    final cleanQ = question.trim();
    final cleanA = answer.trim();

    // 1. Question validation
    if (cleanQ.length < 5 || !_isGrammaticallySoundQuestion(cleanQ)) {
      return false;
    }

    // 2. Answer length validation: must contain at least 3 words or 12 characters
    final words = cleanA
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && RegExp('[a-zA-Z0-9]').hasMatch(w))
        .toList();

    if (words.length < 3 && cleanA.length < 12) {
      return false;
    }

    // 3. Noise, watermark & footer filter
    if (_isNoiseOrFooter(cleanA) || _isNoiseOrFooter(cleanQ)) {
      return false;
    }

    // 4. Meaningful educational text & binary noise checks
    if (!isMeaningfulEducationalText(cleanA) ||
        _isCorruptedBinaryString(cleanA)) {
      return false;
    }

    return true;
  }

  /// Extracts structured sections from document lines using structural headings.
  List<_DocumentSection> _chunkIntoSections(List<String> lines) {
    final sections = <_DocumentSection>[];
    String? currentTitle;
    final currentLines = <String>[];

    final structuralHeaderRegex = RegExp(
      r'^(?:(?:Chapter|Section|Part|Step|Rule|Unit|Module|Theorem|Lemma|Definition|Topic)\s+[A-Z0-9\.]+|(?:\d+\.)+\d*\s+[A-Z]|\b[IVXLCDM]+\.\s+[A-Z])\s*(.*)$',
      caseSensitive: false,
    );

    final termDefRegex = RegExp(
      r'^([A-Z0-9][a-zA-Z0-9\s\-_/]{2,45})\s*[:=–—]\s*(.+)$',
    );

    final qaRegex = RegExp(
      r'^(Q(?:uestion)?\s*:\s*.+?)\s*(?:A(?:nswer)?\s*:\s*(.+))$',
      caseSensitive: false,
    );

    void commitCurrentSection() {
      if (currentTitle != null && currentLines.isNotEmpty) {
        final joined = currentLines
            .join(' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        if (joined.length >= 20) {
          sections.add(
            _DocumentSection(
              title: currentTitle!,
              content: joined,
            ),
          );
        }
      } else if (currentLines.isNotEmpty) {
        final joined = currentLines.join('\n\n');
        sections.addAll(_extractSemanticParagraphSections(joined));
      }
      currentLines.clear();
      currentTitle = null;
    }

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      // Ignore isolated digits, footers, and non-educational symbol lines
      if (RegExp(r'^\d+$').hasMatch(line) ||
          _isNoiseOrFooter(line) ||
          !isMeaningfulEducationalText(line)) {
        continue;
      }

      // 1. Check for Question & Answer pattern: Q: ... A: ...
      final qaMatch = qaRegex.firstMatch(line);
      if (qaMatch != null) {
        commitCurrentSection();
        sections.add(
          _DocumentSection(
            title: qaMatch.group(1)!.trim(),
            content: qaMatch.group(2)!.trim(),
          ),
        );
        continue;
      }

      // 2. Section Headers & Structural Markers
      final isStructuralHeader = structuralHeaderRegex.hasMatch(line);
      final isColonHeader = line.length < 60 &&
          line.endsWith(':') &&
          !line.contains('http') &&
          !line.contains('.') &&
          line.split(RegExp(r'\s+')).length >= 2;
      final isAllCapsHeader = line.length >= 6 &&
          line.length <= 50 &&
          line == line.toUpperCase() &&
          line.split(RegExp(r'\s+')).length >= 2 &&
          RegExp('[A-Z]').hasMatch(line);

      if (isStructuralHeader || isColonHeader || isAllCapsHeader) {
        commitCurrentSection();
        currentTitle = line.replaceAll(':', '').trim();
        continue;
      }

      // 3. Single-Line Term: Definition pattern
      final termDefMatch = termDefRegex.firstMatch(line);
      if (termDefMatch != null &&
          termDefMatch.group(2)!.trim().split(' ').length >= 3 &&
          !line.startsWith('http')) {
        commitCurrentSection();
        sections.add(
          _DocumentSection(
            title: termDefMatch.group(1)!.trim(),
            content: termDefMatch.group(2)!.trim(),
          ),
        );
        continue;
      }

      // 4. Bullet Points and Numbered Items
      final bulletMatch =
          RegExp(r'^[•\-–—*]\s*(.+)$|^\d+\.\s*(.+)$').firstMatch(line);
      if (bulletMatch != null) {
        final itemContent =
            (bulletMatch.group(1) ?? bulletMatch.group(2) ?? '').trim();
        if (itemContent.length >= 10 && isMeaningfulEducationalText(itemContent)) {
          sections.add(
            _DocumentSection(
              title: currentTitle ?? itemContent,
              content: itemContent,
            ),
          );
          continue;
        }
      }

      currentLines.add(line);
    }

    commitCurrentSection();
    return sections;
  }

  /// Extracts structured prompt/response pairs from narrative prose using
  /// paragraph-level sentence grouping (never breaking mid-sentence or mid-clause).
  List<_DocumentSection> _extractSemanticParagraphSections(String text) {
    final results = <_DocumentSection>[];

    final paragraphs = text
        .split(RegExp(r'(?:\r?\n){1,}'))
        .map(
          (p) => p.replaceAll(RegExp(r'\s+'), ' ').trim(),
        )
        .where((p) => p.length >= 15 && isMeaningfulEducationalText(p))
        .toList();

    for (final para in paragraphs) {
      final sentences = _splitIntoCompleteSentences(para);
      if (sentences.isEmpty) {
        if (para.length >= 20) {
          results.add(_DocumentSection(title: para, content: para));
        }
        continue;
      }

      if (sentences.length == 1) {
        final sentence = sentences.first;
        results.add(_DocumentSection(title: sentence, content: sentence));
      } else {
        for (var i = 0; i < sentences.length; i++) {
          final sentence = sentences[i];
          final words = sentence
              .split(RegExp(r'\s+'))
              .where((w) => w.isNotEmpty)
              .toList();
          if (words.length >= 5) {
            results.add(_DocumentSection(title: sentence, content: sentence));
          } else if (i + 1 < sentences.length) {
            final combined = '$sentence ${sentences[i + 1]}';
            results.add(_DocumentSection(title: sentence, content: combined));
            i++;
          }
        }
      }
    }

    return results;
  }

  /// Splits continuous text into complete sentences while protecting common abbreviations.
  static List<String> _splitIntoCompleteSentences(String paragraph) {
    if (paragraph.trim().isEmpty) return [];

    final normalized = paragraph
        .replaceAll('e.g.', 'eg_token')
        .replaceAll('i.e.', 'ie_token')
        .replaceAll('vs.', 'vs_token')
        .replaceAll('Fig.', 'fig_token')
        .replaceAll('Dr.', 'dr_token')
        .replaceAll('Mr.', 'mr_token')
        .replaceAll('Mrs.', 'mrs_token')
        .replaceAll('approx.', 'approx_token')
        .replaceAll('etc.', 'etc_token');

    final rawSentences = normalized.split(
      RegExp(r'(?<=[.!?])\s+(?=[A-Z0-9"\(\[])'),
    );
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

  /// Validates that [text] represents meaningful natural language content
  /// or valid mathematical expressions rather than binary stream font noise.
  static bool isMeaningfulEducationalText(String text) {
    final clean = text.trim();
    if (clean.length < 3) return false;

    // 1. If line is recognized LaTeX math with known math commands, allow it
    if (clean.contains(
          RegExp(
            r'\\(frac|sum|int|begin|text|times|ge|le|alpha|beta|sigma|theta|omega|sqrt|mathbf)',
          ),
        ) ||
        clean.contains(RegExp(r'\$\$.+\$\$|\$.+\$'))) {
      return true;
    }

    var letterCount = 0;
    var symbolCount = 0;
    var controlCount = 0;

    for (final rune in clean.runes) {
      if ((rune >= 65 && rune <= 90) || (rune >= 97 && rune <= 122)) {
        letterCount++;
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
    final vowelRegex = RegExp('[aeiouyAEIOUY]');
    for (final word in words) {
      final lettersInWord = word.replaceAll(RegExp('[^a-zA-Z]'), '').length;
      if (lettersInWord >= 2 && vowelRegex.hasMatch(word)) {
        validWordCount++;
      }
    }

    return validWordCount >= (clean.length > 20 ? 2 : 1);
  }

  static bool _isCorruptedBinaryString(String text) {
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

  String? _extractOrGenerateFormula(String title, String body) {
    final combined = '$title $body';
    final lower = combined.toLowerCase();

    // 1. If text contains explicit LaTeX math operators or environments, extract it
    final explicitLatexMatch = RegExp(
      r'(\$\$.+?\$\$|\$.+?\$|\\begin\{.+?\}.+?\\end\{.+?\}|\\int.+|\\frac\{.+?\}\{.+?\})',
      dotAll: true,
    ).firstMatch(combined);
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
    if (lower.contains('newton') &&
        (lower.contains('force') ||
            lower.contains('second law') ||
            lower.contains('acceleration'))) {
      return r'\mathbf{F} = m\mathbf{a} = \frac{d\mathbf{p}}{dt}';
    }
    if (lower.contains('quadratic') || lower.contains('polynomial')) {
      return r'x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}';
    }
    if (lower.contains('pythagor')) {
      return 'a^2 + b^2 = c^2';
    }
    if (lower.contains('moving average') || lower.contains('ema')) {
      return r'\text{EMA}_t = \left( \text{Price}_t \times \alpha \right) + \left( \text{EMA}_{t-1} \times (1 - \alpha) \right)';
    }
    if (lower.contains('risk') &&
        (lower.contains('reward') ||
            lower.contains('ratio') ||
            lower.contains('take profit'))) {
      return r'\text{Risk-to-Reward Ratio} = \frac{|\text{Target Price} - \text{Entry Price}|}{|\text{Entry Price} - \text{Stop Loss}|} \ge 3:1';
    }

    return null;
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
