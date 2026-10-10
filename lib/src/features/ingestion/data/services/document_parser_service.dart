import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:kortex/src/features/ingestion/data/models/ocr_extraction_model.dart';
import 'package:kortex/src/features/ingestion/data/services/formula_extraction_service.dart';
import 'package:kortex/src/features/ingestion/data/services/local_docx_parser_service.dart';
import 'package:kortex/src/features/ingestion/data/services/local_epub_parser_service.dart';
import 'package:kortex/src/features/ingestion/data/services/local_html_parser_service.dart';
import 'package:kortex/src/features/ingestion/data/services/local_pdf_parser_service.dart';
import 'package:kortex/src/features/ingestion/data/services/local_pptx_parser_service.dart';
import 'package:kortex/src/features/ingestion/data/services/offline_card_builder.dart';
import 'package:kortex/src/features/ingestion/data/services/pdf_figure_extractor.dart';
import 'package:kortex/src/features/ingestion/data/services/synthesis/flashcard_synthesizer.dart';
import 'package:kortex/src/features/ingestion/data/services/synthesis/schema_serializer.dart';
import 'package:kortex/src/features/ingestion/domain/entities/document_ir.dart';
import 'package:kortex/src/features/ingestion/domain/entities/extraction_report.dart';
import 'package:kortex/src/features/ingestion/domain/exceptions/ingestion_exceptions.dart';

class DocumentParserService {
  const DocumentParserService();

  /// Extracts structured text from file bytes (PDF, DOCX, EPUB, HTML, Markdown, text, etc.).
  String extractTextFromBytes(
    Uint8List bytes, {
    required String fileType,
    required String filename,
    ExtractionReport? report,
  }) {
    final ext = fileType.replaceAll('.', '').toLowerCase();

    const supportedExtensions = {
      'pdf',
      'docx',
      'pptx',
      'html',
      'htm',
      'xhtml',
      'epub',
      'txt',
      'md',
      'markdown',
      'tex',
      'latex',
    };

    if (!supportedExtensions.contains(ext)) {
      report?.recordWarning('Unsupported file extension: .$ext');
      throw UnsupportedFileTypeException(ext);
    }

    if (ext == 'pdf') {
      try {
        final pdfText = const LocalPdfParserService().extractTextFromPdfBytes(
          bytes,
          filename: filename,
          report: report,
        );
        if (pdfText.trim().isNotEmpty) {
          return pdfText;
        }
      } on EncryptedPdfException {
        rethrow;
      } on CorruptDocumentException {
        rethrow;
      } on ScannedDocumentException {
        rethrow;
      } on Object catch (_) {}
      return extractRawPdfStreamText(bytes);
    }

    if (ext == 'docx') {
      return LocalDocxParserService.extractTextFromBytesSync(
        bytes,
        filename: filename,
        report: report,
      );
    }

    if (ext == 'pptx') {
      try {
        final text = LocalPptxParserService.extractTextFromBytesSync(bytes);
        if (text.isEmpty) {
          throw CorruptDocumentException(
            filename,
            'PPTX presentation contains no slide text',
          );
        }
        return text;
      } on CorruptDocumentException {
        rethrow;
      } on Object catch (e) {
        report?.isCorrupt = true;
        report?.recordDrop(rule: 'corrupted_pptx_archive', sampleText: '$e');
        throw CorruptDocumentException(filename, 'Malformed PPTX file: $e');
      }
    }

    if (ext == 'epub') {
      return LocalEpubParserService.extractTextFromBytesSync(
        bytes,
        filename: filename,
        report: report,
      );
    }

    if (ext == 'html' || ext == 'htm' || ext == 'xhtml') {
      return LocalHtmlParserService.extractTextFromBytesSync(
        bytes,
        filename: filename,
        report: report,
      );
    }

    if ({'txt', 'md', 'markdown', 'tex', 'latex'}.contains(ext)) {
      final text = utf8.decode(bytes, allowMalformed: true).trim();
      return text;
    }

    throw UnsupportedFileTypeException(ext);
  }

  /// Low-level stream fallback for raw PDF text extraction.
  String extractRawPdfStreamText(Uint8List bytes) =>
      _extractTextFromPdfBytes(bytes);

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

  bool _hasReadableText(String s) {
    if (s.isEmpty) return false;
    final alphaCount = s.codeUnits
        .where(
          (c) => (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 32,
        )
        .length;
    return alphaCount / s.length > 0.4;
  }

  static final Uint32List _crcTable = () {
    final table = Uint32List(256);
    for (var i = 0; i < 256; i++) {
      var c = i;
      for (var k = 0; k < 8; k++) {
        c = (c & 1) != 0 ? (0xedb88320 ^ (c >>> 1)) : (c >>> 1);
      }
      table[i] = c;
    }
    return table;
  }();

  static int _crc32(List<int> bytes) {
    var crc = 0xffffffff;
    for (var i = 0; i < bytes.length; i++) {
      crc = (crc >>> 8) ^ _crcTable[(crc ^ bytes[i]) & 0xff];
    }
    return (crc ^ 0xffffffff) >>> 0;
  }

  static Uint8List _encodePixelsToPng(
    Uint8List rawPixels,
    int width,
    int height, {
    int channels = 3,
  }) {
    final rowBytes = width * channels;
    final scanlines = Uint8List(height * (rowBytes + 1));
    var dest = 0;
    for (var y = 0; y < height; y++) {
      scanlines[dest++] = 0; // Filter: None
      final src = y * rowBytes;
      scanlines.setRange(
        dest,
        dest + rowBytes,
        rawPixels.sublist(src, src + rowBytes),
      );
      dest += rowBytes;
    }

    final idatCompressed = Uint8List.fromList(zlib.encode(scanlines));
    final colorType = channels == 3 ? 2 : (channels == 4 ? 6 : 0);

    final totalLength = 8 + 25 + (12 + idatCompressed.length) + 12;
    final png = Uint8List(totalLength);
    final view = ByteData.sublistView(png);
    var offset = 0;

    // 1. Signature
    png.setRange(0, 8, const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
    offset += 8;

    // 2. IHDR
    final ihdrPayload = Uint8List(17)..setRange(0, 4, utf8.encode('IHDR'));
    ByteData.sublistView(ihdrPayload, 4, 17)
      ..setUint32(0, width)
      ..setUint32(4, height)
      ..setUint8(8, 8)
      ..setUint8(9, colorType)
      ..setUint8(10, 0)
      ..setUint8(11, 0)
      ..setUint8(12, 0);

    view.setUint32(offset, 13);
    offset += 4;
    png.setRange(offset, offset + 17, ihdrPayload);
    offset += 17;
    view.setUint32(offset, _crc32(ihdrPayload));
    offset += 4;

    // 3. IDAT
    final idatHeader = Uint8List(4 + idatCompressed.length)
      ..setRange(0, 4, utf8.encode('IDAT'))
      ..setRange(4, 4 + idatCompressed.length, idatCompressed);
    view.setUint32(offset, idatCompressed.length);
    offset += 4;
    png.setRange(offset, offset + idatHeader.length, idatHeader);
    offset += idatHeader.length;
    view.setUint32(offset, _crc32(idatHeader));
    offset += 4;

    // 4. IEND
    final iendHeader = Uint8List.fromList(utf8.encode('IEND'));
    view.setUint32(offset, 0);
    offset += 4;
    png.setRange(offset, offset + 4, iendHeader);
    offset += 4;
    view.setUint32(offset, _crc32(iendHeader));

    return png;
  }

  /// Extracts embedded image streams and diagrams (PDF Image XObjects, Flate raster, JPEG) from PDF bytes.
  List<ExtractedImageAttachment> extractImagesFromPdfBytes(Uint8List bytes) {
    try {
      const extractor = PdfFigureExtractor();
      final figures = extractor.extractFigures(bytes);
      if (figures.isNotEmpty) {
        return figures.map((f) => f.toAttachment()).toList();
      }
    } on Object catch (_) {}

    final images = <ExtractedImageAttachment>[];

    // 1. PDF Image XObject Parsing (FlateDecode & DCTDecode)
    final pdfText = latin1.decode(bytes, allowInvalid: true);
    final imageRegex = RegExp(
      r'<<([^>]*\/Subtype\s*\/Image[^>]*)>>\s*stream[\r\n]+',
      multiLine: true,
    );

    for (final match in imageRegex.allMatches(pdfText)) {
      final dictStr = match.group(1) ?? '';
      final streamStart = match.end;

      final wMatch = RegExp(r'/Width\s+(\d+)').firstMatch(dictStr);
      final hMatch = RegExp(r'/Height\s+(\d+)').firstMatch(dictStr);
      final lMatch = RegExp(r'/Length\s+(\d+)').firstMatch(dictStr);

      final width = wMatch != null ? int.tryParse(wMatch.group(1)!) ?? 0 : 0;
      final height = hMatch != null ? int.tryParse(hMatch.group(1)!) ?? 0 : 0;
      final declaredLength = lMatch != null
          ? int.tryParse(lMatch.group(1)!) ?? 0
          : 0;

      // Filter out small non-diagram images (icons, bullet markers, separators, avatars)
      if (width < 160 || height < 120) continue;
      final aspectRatio = width / (height > 0 ? height : 1);
      if (aspectRatio < 0.25 || aspectRatio > 4.0) continue;

      final isFlate = dictStr.contains('/FlateDecode');
      final isDct = dictStr.contains('/DCTDecode');

      Uint8List streamBytes;
      if (declaredLength > 0 && streamStart + declaredLength <= bytes.length) {
        streamBytes = bytes.sublist(streamStart, streamStart + declaredLength);
      } else {
        final endstreamIdx = pdfText.indexOf('endstream', streamStart);
        if (endstreamIdx == -1) continue;
        streamBytes = bytes.sublist(streamStart, endstreamIdx);
      }

      if (isFlate) {
        try {
          final decompressed = Uint8List.fromList(zlib.decode(streamBytes));
          final expectedRgb = width * height * 3;
          final expectedGray = width * height;
          final expectedRgba = width * height * 4;

          var channels = 3;
          var rawData = decompressed;

          if (decompressed.length == expectedRgb) {
            channels = 3;
          } else if (decompressed.length == expectedGray) {
            channels = 1;
          } else if (decompressed.length == expectedRgba) {
            channels = 4;
          } else if (decompressed.length == height * (width * 3 + 1)) {
            // Strip predictor filter byte per scanline
            channels = 3;
            final stripped = Uint8List(width * height * 3);
            final rowLen = width * 3;
            for (var y = 0; y < height; y++) {
              stripped.setRange(
                y * rowLen,
                (y + 1) * rowLen,
                decompressed.sublist(
                  y * (rowLen + 1) + 1,
                  (y + 1) * (rowLen + 1),
                ),
              );
            }
            rawData = stripped;
          } else {
            // Check direct PNG container
            if (decompressed.length > 8 &&
                decompressed[0] == 0x89 &&
                decompressed[1] == 0x50 &&
                decompressed[2] == 0x4E &&
                decompressed[3] == 0x47) {
              images.add(
                ExtractedImageAttachment(
                  bytes: decompressed,
                  extension: 'png',
                  label: 'Diagram ${images.length + 1} (${width}x$height)',
                ),
              );
            }
            continue;
          }

          final pngBytes = _encodePixelsToPng(
            rawData,
            width,
            height,
            channels: channels,
          );
          images.add(
            ExtractedImageAttachment(
              bytes: pngBytes,
              extension: 'png',
              label: 'Diagram / Chart ${images.length + 1} (${width}x$height)',
            ),
          );
        } on Object catch (_) {}
      } else if (isDct) {
        images.add(
          ExtractedImageAttachment(
            bytes: streamBytes,
            extension: 'jpg',
            label: 'Figure ${images.length + 1} (${width}x$height)',
          ),
        );
      }
    }

    // 2. Fallback scan for standalone JPEG streams (SOI ... EOI)
    if (images.isEmpty) {
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
    }

    return images;
  }

  /// Synthesizes flashcards offline (no AI) from the extracted document text.
  /// Unified pipeline synthesizing a complete, schema-validated [PedagogicalDeck]
  /// directly from document text.
  ///
  /// Reconciles offline card extraction with pedagogical validation, source
  /// provenance tracking, and multi-modal asset packaging.
  PedagogicalDeck synthesizeDeckFromDocument({
    required String documentId,
    required String fullText,
    required String filename,
    String? deckTitle,
    String? subject,
    String? category,
    List<String> imageUrls = const [],
    ExtractionReport? report,
    Clock? clock,
  }) {
    final cleanFullText = LocalPdfParserService.repairDetachedInitialCapitals(
      fullText.trim(),
    );
    final cleanDeckTitle = deckTitle ??
        filename.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
    final inferredSubject = subject ?? _inferSubject(filename);
    final effectiveCategory = category ?? 'Study';

    if (cleanFullText.isEmpty) {
      return PedagogicalDeck(
        schemaVersion: SchemaSerializer.currentSchemaVersion,
        deckId: 'deck_$documentId',
        deckTitle: cleanDeckTitle,
        subject: inferredSubject,
        category: effectiveCategory,
        totalCards: 0,
        cards: const [],
        generatedAt: (clock ?? const SystemUtcClock()).now().toUtc(),
      );
    }

    final cards = const OfflineCardBuilder().buildCards(
      cleanFullText,
      report: report,
    );
    final usedImageUrls = <String>{};
    final candidates = <PedagogicalCandidateCard>[];

    for (var i = 0; i < cards.length; i++) {
      final card = cards[i];
      final assets = List<CardAsset>.from(card.assets);

      final matchedImage = _matchRelevantImageUrl(
        title: card.front,
        content: card.back,
        imageUrls: imageUrls,
        usedImageUrls: usedImageUrls,
      );
      if (matchedImage != null) {
        assets.add(
          CardAsset(
            id: 'img_${documentId}_$i',
            type: CardAssetType.image,
            content: matchedImage,
          ),
        );
      }

      final formula = _extractOrGenerateFormula(card.front, card.back);
      if (formula != null &&
          !assets.any((a) => a.type == CardAssetType.latexEquation)) {
        assets.add(
          CardAsset(
            id: 'math_${documentId}_$i',
            type: CardAssetType.latexEquation,
            content: formula,
          ),
        );
      }

      final source = card.source ??
          CardSource(
            docId: documentId,
            page: 1,
            sectionPath: [card.heading ?? cleanDeckTitle],
            blockId: 'block_$i',
          );

      candidates.add(
        PedagogicalCandidateCard(
          front: card.front,
          back: card.back,
          type: card.type.toCognitiveType(),
          sourceTopic: source.sectionPath.join(' > '),
          source: source,
          assets: assets,
          backLatex: formula,
          imageUrl: matchedImage,
          confidenceScore: card.confidence,
        ),
      );
    }

    final serializer = SchemaSerializer(clock: clock);
    return serializer.serializeDeck(
      deckId: 'deck_$documentId',
      deckTitle: cleanDeckTitle,
      subject: inferredSubject,
      category: effectiveCategory,
      candidateCards: candidates,
    );
  }

  /// Synthesizes flashcards offline (no AI) from the extracted document text.
  ///
  /// Routes through the unified [synthesizeDeckFromDocument] pipeline and emits
  /// validated [OcrExtractionModel]s for persistence.
  List<OcrExtractionModel> synthesizeSnippetsFromDocument({
    required String documentId,
    required String fullText,
    required String filename,
    List<String> imageUrls = const [],
    ExtractionReport? report,
    Clock? clock,
  }) {
    final deck = synthesizeDeckFromDocument(
      documentId: documentId,
      fullText: fullText,
      filename: filename,
      imageUrls: imageUrls,
      report: report,
      clock: clock,
    );
    return deck.toExtractionModels();
  }

  static String _inferSubject(String filename) {
    final lower = filename.toLowerCase();
    if (lower.contains('bio')) return 'Biology';
    if (lower.contains('chem')) return 'Chemistry';
    if (lower.contains('phys') || lower.contains('quantum')) return 'Physics';
    if (lower.contains('flutter') ||
        lower.contains('dart') ||
        lower.contains('cpp') ||
        lower.contains('jls') ||
        lower.contains('comput')) {
      return 'Computer Science';
    }
    if (lower.contains('contract') ||
        lower.contains('agreement') ||
        lower.contains('engagement')) {
      return 'Law';
    }
    if (lower.contains('finance') ||
        lower.contains('portfolio') ||
        lower.contains('invoice')) {
      return 'Finance';
    }
    return 'General';
  }

  static const _commonStopWords = {
    // Pronouns & Determiners (4+ letters)
    'that', 'this', 'these', 'those', 'what', 'which', 'where', 'when',
    'they', 'them', 'their', 'theirs', 'themselves', 'yourself', 'yourselves',

    // Prepositions & Connectors (4+ letters)
    'about', 'above', 'across', 'after', 'against', 'along', 'among',
    'around', 'before', 'behind', 'below', 'beneath', 'beside', 'between',
    'beyond', 'during', 'except', 'from', 'inside', 'into', 'onto', 'outside',
    'over', 'through', 'toward', 'under', 'until', 'upon', 'with', 'within',
    'without', 'because', 'although', 'while', 'since',

    // Verbs & Modals (4+ letters)
    'were', 'been', 'being', 'have', 'does', 'done', 'will', 'would',
    'shall', 'should', 'might', 'must', 'could', 'also', 'just',

    // Domain Structural Words
    'section', 'chapter', 'part', 'step', 'rule', 'unit',
    'module', 'concept', 'notes', 'review', 'overview',
  };

  /// Matches an image URL to a card section ONLY if there is an explicit figure reference
  /// or a strong topical keyword match between the section and image filename/label.
  String? _matchRelevantImageUrl({
    required String title,
    required String content,
    required List<String> imageUrls,
    required Set<String> usedImageUrls,
  }) {
    if (imageUrls.isEmpty) return null;

    final combined = '$title $content'.toLowerCase();

    // 1. Direct figure/diagram label or number match (e.g. "Figure 2", "Fig 2", "Diagram 3")
    final figMatch = RegExp(
      r'\b(?:fig(?:ure)?\.?|diagram|chart|illustration)\s*#?\s*(\d+)',
      caseSensitive: false,
    ).firstMatch(combined);

    if (figMatch != null) {
      final figNum = figMatch.group(1);
      final match = imageUrls.where((url) {
        if (usedImageUrls.contains(url)) return false;
        final lower = url.toLowerCase();
        return lower.contains('fig_$figNum.') ||
            lower.contains('fig$figNum.') ||
            lower.contains('fig_${figNum}_') ||
            lower.contains('diagram_$figNum.') ||
            lower.contains('diagram_${figNum}_') ||
            lower.contains('diagram$figNum.') ||
            lower.contains('img_$figNum.') ||
            lower.contains('figure_$figNum.') ||
            lower.contains('fig-$figNum') ||
            lower.contains('figure-$figNum');
      }).firstOrNull;

      if (match != null) {
        usedImageUrls.add(match);
        return match;
      }
    }

    // 2. Topical keyword matching between section title and image URL / label
    // e.g., "mitosis.jpg" matching section with title "Mitosis"
    final titleWords = title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 4 && !_commonStopWords.contains(w))
        .toList();

    for (final word in titleWords) {
      final match = imageUrls.where((url) {
        if (usedImageUrls.contains(url)) return false;
        final urlLower = url.toLowerCase();
        final filename = urlLower.split('/').last;
        return filename.contains(word);
      }).firstOrNull;

      if (match != null) {
        usedImageUrls.add(match);
        return match;
      }
    }

    // 3. Explicit diagram/chart reference in text (e.g. "as shown in the diagram", "architecture diagram")
    final hasExplicitDiagramRef = RegExp(
      r'\b(?:as shown in the (?:diagram|figure|illustration|chart)|refer to the (?:diagram|figure|chart|model)|flowchart below|architecture diagram|schematic diagram|illustrated diagram)\b',
      caseSensitive: false,
    ).hasMatch(combined);

    if (hasExplicitDiagramRef) {
      final available = imageUrls
          .where((url) => !usedImageUrls.contains(url))
          .firstOrNull;
      if (available != null) {
        usedImageUrls.add(available);
        return available;
      }
    }

    // Purely textual/conceptual card: do NOT attach an unrelated image!
    return null;
  }

  /// Validates that [text] represents meaningful natural language content
  /// or valid mathematical expressions rather than binary stream font noise.
  static bool isMeaningfulEducationalText(String text) {
    final clean = text.trim();
    if (clean.length < 3) return false;

    // 1. If line is recognized LaTeX math or algebraic equation with math symbols, allow it
    if (clean.contains(
          RegExp(
            r'\\(frac|sum|int|begin|text|times|ge|le|alpha|beta|sigma|theta|omega|sqrt|mathbf)',
          ),
        ) ||
        clean.contains(RegExp(r'\$\$.+\$\$|\$.+\$')) ||
        RegExp(
          r'^[a-zA-Z0-9_()^]{1,15}\s*=\s*[a-zA-Z0-9_()^+\-*/\\ \t]+$',
        ).hasMatch(clean)) {
      return true;
    }

    // 2. If line is a markdown code fence or recognized code syntax with adequate alphanumeric content
    if (clean.startsWith('```') || clean.contains('```')) {
      return true;
    }

    if (isCodeSyntaxLine(clean) &&
        (clean.length <= 15 ||
            clean.runes
                        .where(
                          (r) =>
                              (r >= 65 && r <= 90) ||
                              (r >= 97 && r <= 122) ||
                              (r >= 48 && r <= 57),
                        )
                        .length /
                    clean.length >=
                0.40)) {
      return true;
    }

    var letterCount = 0;
    var symbolCount = 0;
    var controlCount = 0;

    final unicodeLetter = RegExp(r'^\p{L}$', unicode: true);

    for (final rune in clean.runes) {
      if ((rune >= 65 && rune <= 90) ||
          (rune >= 97 && rune <= 122) ||
          unicodeLetter.hasMatch(String.fromCharCode(rune))) {
        letterCount++;
      } else if (rune == 32 || rune == 10 || rune == 13 || rune == 9) {
        // whitespace
      } else if (rune < 32 || rune == 127 || (rune >= 128 && rune <= 159)) {
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
    final vowelRegex = RegExp(
      '[aeiouyáéíóúàèìòùäëïöüâêîôûãõọẹAEIOUYÁÉÍÓÚÀÈÌÒÙÄËÏÖÜÂÊÎÔÛÃÕỌẸ]',
    );
    final letterRegex = RegExp(r'\p{L}', unicode: true);
    for (final word in words) {
      final lettersInWord = letterRegex.allMatches(word).length;
      if (lettersInWord >= 2 && vowelRegex.hasMatch(word)) {
        validWordCount++;
      }
    }

    return validWordCount >= (clean.length > 20 ? 2 : 1);
  }

  String? _extractOrGenerateFormula(String title, String body) {
    final combined = '$title $body';
    final extracted = FormulaExtractionService.instance.extractFormula(combined);
    if (extracted != null) {
      final latex = extracted.latex;
      if (latex.startsWith(r'$$') ||
          latex.startsWith(r'\[') ||
          latex.startsWith(r'\(') ||
          latex.startsWith(r'$') ||
          latex.startsWith(r'\begin{')) {
        return latex;
      }
      return extracted.isDisplay ? '\$\$$latex\$\$' : r'\(' + latex + r'\)';
    }
    return null;
  }

  /// Checks whether a text line exhibits programming syntax (Dart, Flutter, Python, JS, etc.)
  static bool isCodeSyntaxLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return false;

    // Direct code fence check
    if (trimmed.startsWith('```') || trimmed == '`') return true;

    // Discard glyph / punctuation soup immediately
    if (trimmed.length > 20) {
      final symbolCount = trimmed.runes.where((r) {
        return r != 32 &&
            r != 9 &&
            r != 10 &&
            r != 13 &&
            !((r >= 65 && r <= 90) ||
                (r >= 97 && r <= 122) ||
                (r >= 48 && r <= 57));
      }).length;
      if (symbolCount / trimmed.length > 0.55) {
        return false;
      }
    }

    // Structural braces/brackets lines
    if ((RegExp(r'^[{}()\[\];, ]+$').hasMatch(trimmed) &&
            trimmed.length <= 15) ||
        trimmed == '}' ||
        trimmed == '};' ||
        trimmed == '});' ||
        trimmed == '),' ||
        trimmed == '],' ||
        trimmed == '{') {
      return true;
    }

    // Language keywords & declarations
    final codeKeywordRegex = RegExp(
      r'^(?:(?:public|private|protected|static|final|const|var|late|abstract|override|async|await)\s+)?'
      r'(?:class|interface|enum|mixin|extension|typedef|struct|void|function|def|import|package|export|from)\b'
      r'|^\s*@(?:override|deprecated|visibleForTesting|pragma)\b'
      r'|^\s*(?:return|throw|rethrow|yield|break|continue)\b'
      r'|^\s*(?:if|while|for|switch|case|catch|finally)\s*\('
      r'|^\s*(?:Widget|BuildContext|State<|StatefulWidget|StatelessWidget)\b'
      r'|^\s*(?:setState|print|console\.log|System\.out\.println)\s*\('
      r'|=>\s*[a-zA-Z0-9_\$]|(?:\+\+|--|\+=|-=|\*=|/=|&&|\|\||===|!==)\s+[a-zA-Z0-9_\$]',
    );

    if (codeKeywordRegex.hasMatch(trimmed)) {
      return true;
    }

    // Dart/Flutter constructor / widget instantiation pattern: `child: Container(...)` or `body: Center(...)`
    if (RegExp(
          r'^[a-zA-Z0-9_]+\s*:\s*[A-Z][a-zA-Z0-9_]*\s*\(',
        ).hasMatch(trimmed) ||
        RegExp(r'^[A-Z][a-zA-Z0-9_]*\s*\(').hasMatch(trimmed)) {
      return true;
    }

    return false;
  }
}

class ExtractedImageAttachment {
  const ExtractedImageAttachment({
    required this.bytes,
    required this.extension,
    required this.label,
    this.page = 1,
    this.caption,
    this.bbox,
    this.xObjectName,
  });

  final Uint8List bytes;
  final String extension;
  final String label;
  final int page;
  final String? caption;
  final BoundingBox? bbox;
  final String? xObjectName;
}

class _ByteRange {
  const _ByteRange(this.start, this.end);
  final int start;
  final int end;
}
