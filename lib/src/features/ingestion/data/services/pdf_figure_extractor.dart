import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:kortex/src/features/ingestion/data/services/document_parser_service.dart';
import 'package:kortex/src/features/ingestion/domain/entities/document_ir.dart';

/// Represents an extracted figure, diagram, or graphic attachment from a PDF document,
/// complete with byte payload, file format extension, spatial bounding box,
/// page provenance, and caption association.
class ExtractedPdfFigure {
  const ExtractedPdfFigure({
    required this.bytes,
    required this.extension,
    required this.label,
    required this.page,
    this.caption,
    this.bbox,
    this.figureId,
    this.isVectorDiagram = false,
    this.width,
    this.height,
  });

  /// Raw byte payload of the image (PNG, JPEG, or JP2).
  final Uint8List bytes;

  /// File format extension (e.g. 'png', 'jpg', 'jp2').
  final String extension;

  /// Human-readable label (e.g. 'Figure 1: Feynman diagram...').
  final String label;

  /// 1-based page number where the figure appears.
  final int page;

  /// Extracted caption text associated with the figure.
  final String? caption;

  /// Bounding box geometry of the figure in PDF user space coordinates.
  final BoundingBox? bbox;

  /// Unique identifier for this figure.
  final String? figureId;

  /// Whether this figure was reconstructed from vector drawing operators.
  final bool isVectorDiagram;

  /// Pixel width of the image.
  final int? width;

  /// Pixel height of the image.
  final int? height;

  /// Converts this figure to an [ExtractedImageAttachment] for legacy and pipeline compatibility.
  ExtractedImageAttachment toAttachment() => ExtractedImageAttachment(
    bytes: bytes,
    extension: extension,
    label: label,
    page: page,
    caption: caption,
    bbox: bbox,
  );

  /// Converts this figure into a strongly-typed [FigureBlock] for [DocumentIR].
  FigureBlock toFigureBlock({
    required String docId,
    required int readingOrder,
    List<String> sectionPath = const [] ,
  }) => FigureBlock(
    page: page,
    label: label,
    caption: caption,
    imageRef: 'figures/${figureId ?? "fig_${page}_$readingOrder"}.$extension',
    provenance: BlockProvenance(
      docId: docId,
      page: page,
      readingOrder: readingOrder,
      sectionPath: sectionPath,
      bbox: bbox,
    ),
  );

  @override
  String toString() =>
      'ExtractedPdfFigure(page: $page, label: "$label", ${width ?? "?"}x${height ?? "?"}, ext: $extension)';
}

/// Service that performs PDF XObject tree traversal, multi-color-space decompression,
/// vector diagram rasterization, and spatial caption association.
class PdfFigureExtractor {
  const PdfFigureExtractor();

  /// Extracts embedded images and vector diagrams from [pdfBytes], associating
  /// each figure with its nearest spatial "Figure N" caption and page context.
  List<ExtractedPdfFigure> extractFigures(
    Uint8List pdfBytes, {
    List<String>? pageTexts,
  }) {
    final figures = <ExtractedPdfFigure>[];
    if (pdfBytes.isEmpty) return figures;

    // 1. Build indirect object index
    final objTable = _PdfObjectTable.fromBytes(pdfBytes);

    // 2. Extract Document Pages via Page Tree Traversal
    final pages = _traversePageTree(objTable);

    // 3. Extract figure captions from pages and text
    final pageCaptions = _extractCaptions(pages, pageTexts);

    final processedImageObjs = <int>{};
    var figureIndex = 1;

    // 4. Traverse each page: XObjects, placements, and vector drawings
    for (final page in pages) {
      final pageNum = page.pageNumber;
      final captionsOnPage = pageCaptions[pageNum] ?? [];
      var captionIdx = 0;

      // 4a. Analyze Content Streams for transformations, Do calls, and vector paths
      final analysis = _analyzeContentStreams(page.contentStreams, page.mediaBox);

      // 4b. Process XObjects referenced in page resources
      for (final entry in page.xObjects.entries) {
        final xObjName = entry.key;
        final xObjId = entry.value;

        if (processedImageObjs.contains(xObjId)) continue;
        final xObj = objTable.getObject(xObjId);
        if (xObj == null) continue;

        final isImage = xObj.dict.contains('/Subtype/Image') ||
            xObj.dict.contains('/Subtype /Image');
        if (!isImage) continue;

        processedImageObjs.add(xObjId);

        final placement = analysis.placements[xObjName];
        final bbox = placement?.bbox;

        final decoded = _decodeImageXObject(xObj, objTable);
        if (decoded != null) {
          String? matchedCaption;
          if (captionIdx < captionsOnPage.length) {
            matchedCaption = captionsOnPage[captionIdx++].captionText;
          }

          final label = matchedCaption != null
              ? 'Figure $figureIndex: $matchedCaption'
              : (placement != null
                  ? 'Figure $figureIndex (Page $pageNum)'
                  : 'Diagram $figureIndex (${decoded.width}x${decoded.height})');

          figures.add(
            ExtractedPdfFigure(
              bytes: decoded.bytes,
              extension: decoded.extension,
              label: label,
              page: pageNum,
              caption: matchedCaption,
              bbox: bbox,
              figureId: 'fig_$figureIndex',
              width: decoded.width,
              height: decoded.height,
            ),
          );
          figureIndex++;
        }
      }

      // 4c. Process Vector Diagrams on this page
      final vectorCluster = analysis.vectorCluster;
      final hasUnassignedCaptions = captionIdx < captionsOnPage.length;

      if ((vectorCluster != null && vectorCluster.operationCount >= 4) ||
          hasUnassignedCaptions) {
        // While there are unassigned captions on this page, create vector diagram figures
        while (captionIdx < captionsOnPage.length) {
          final cap = captionsOnPage[captionIdx++];
          final bbox = vectorCluster?.bounds ??
              BoundingBox(
                left: 54,
                top: 200,
                right: page.mediaBox.width - 54,
                bottom: 400,
              );

          final rasterBytes = _rasterizeVectorDiagram(
            vectorCluster,
            width: 480,
            height: 320,
          );

          figures.add(
            ExtractedPdfFigure(
              bytes: rasterBytes,
              extension: 'png',
              label: 'Figure $figureIndex: ${cap.captionText}',
              page: pageNum,
              caption: cap.captionText,
              bbox: bbox,
              figureId: 'fig_$figureIndex',
              isVectorDiagram: true,
              width: 480,
              height: 320,
            ),
          );
          figureIndex++;
        }
      }
    }

    // 5. Fallback: inspect any unreferenced standalone Image XObjects
    for (final obj in objTable.allObjects) {
      if (processedImageObjs.contains(obj.id)) continue;
      final isImage = obj.dict.contains('/Subtype/Image') ||
          obj.dict.contains('/Subtype /Image');
      if (!isImage) continue;

      processedImageObjs.add(obj.id);
      final decoded = _decodeImageXObject(obj, objTable);
      if (decoded != null && decoded.width >= 32 && decoded.height >= 32) {
        figures.add(
          ExtractedPdfFigure(
            bytes: decoded.bytes,
            extension: decoded.extension,
            label: 'Figure $figureIndex (${decoded.width}x${decoded.height})',
            page: 1,
            figureId: 'fig_$figureIndex',
            width: decoded.width,
            height: decoded.height,
          ),
        );
        figureIndex++;
      }
    }

    // Sort by page number then top coordinate
    figures.sort((a, b) {
      final pageComp = a.page.compareTo(b.page);
      if (pageComp != 0) return pageComp;
      final topA = a.bbox?.top ?? 0.0;
      final topB = b.bbox?.top ?? 0.0;
      return topA.compareTo(topB);
    });

    return figures;
  }

  // ===========================================================================
  // PAGE TREE TRAVERSAL
  // ===========================================================================

  List<_PdfPageInfo> _traversePageTree(_PdfObjectTable table) {
    final pages = <_PdfPageInfo>[];

    var catalogId = table.trailerRootId;
    if (catalogId == null) {
      for (final obj in table.allObjects) {
        if (obj.dict.contains('/Type/Catalog') ||
            obj.dict.contains('/Type /Catalog')) {
          catalogId = obj.id;
          break;
        }
      }
    }

    if (catalogId == null) return _fallbackScanPages(table);

    final catalogObj = table.getObject(catalogId);
    if (catalogObj == null) return _fallbackScanPages(table);

    final pagesRefMatch = RegExp(r'/Pages\s+(\d+)\s+0\s+R').firstMatch(catalogObj.dict);
    if (pagesRefMatch == null) return _fallbackScanPages(table);

    final rootPagesId = int.parse(pagesRefMatch.group(1)!);
    _recursePageNode(
      rootPagesId,
      table,
      pages,
      parentMediaBox: const BoundingBox(left: 0, top: 0, right: 612, bottom: 792),
      parentResources: '',
    );

    if (pages.isEmpty) {
      return _fallbackScanPages(table);
    }

    return pages;
  }

  void _recursePageNode(
    int nodeId,
    _PdfObjectTable table,
    List<_PdfPageInfo> result, {
    required BoundingBox parentMediaBox,
    required String parentResources,
  }) {
    final nodeObj = table.getObject(nodeId);
    if (nodeObj == null) return;

    final dict = nodeObj.dict;

    // Check MediaBox inheritance
    var currentMediaBox = parentMediaBox;
    final mbMatch = RegExp(r'/MediaBox\s*\[\s*([0-9\.\-]+)\s+([0-9\.\-]+)\s+([0-9\.\-]+)\s+([0-9\.\-]+)\s*\]').firstMatch(dict);
    if (mbMatch != null) {
      final x1 = double.tryParse(mbMatch.group(1)!) ?? 0;
      final y1 = double.tryParse(mbMatch.group(2)!) ?? 0;
      final x2 = double.tryParse(mbMatch.group(3)!) ?? 612;
      final y2 = double.tryParse(mbMatch.group(4)!) ?? 792;
      currentMediaBox = BoundingBox(left: x1, top: y1, right: x2, bottom: y2);
    }

    // Check Resources inheritance
    var currentResources = parentResources;
    final resMatch = RegExp(r'/Resources\s*(<<.*?>>|\d+\s+0\s+R)', dotAll: true).firstMatch(dict);
    if (resMatch != null) {
      final resRaw = resMatch.group(1)!;
      if (resRaw.contains('0 R')) {
        final refMatch = RegExp(r'(\d+)\s+0\s+R').firstMatch(resRaw);
        if (refMatch != null) {
          final refId = int.tryParse(refMatch.group(1)!);
          if (refId != null) {
            final resObj = table.getObject(refId);
            if (resObj != null) currentResources = resObj.dict;
          }
        }
      } else {
        currentResources = resRaw;
      }
    }

    // Check if this node is /Pages with /Kids
    final kidsMatch = RegExp(r'/Kids\s*\[(.*?)\]', dotAll: true).firstMatch(dict);
    if (kidsMatch != null) {
      final kidsStr = kidsMatch.group(1)!;
      final refMatches = RegExp(r'(\d+)\s+0\s+R').allMatches(kidsStr);
      for (final ref in refMatches) {
        final kidId = int.parse(ref.group(1)!);
        _recursePageNode(
          kidId,
          table,
          result,
          parentMediaBox: currentMediaBox,
          parentResources: currentResources,
        );
      }
      return;
    }

    // This is a single /Page leaf
    final pageNum = result.length + 1;
    final xObjects = _extractXObjectsFromResources(currentResources, table);
    final contents = _extractPageContents(nodeObj, table);

    result.add(
      _PdfPageInfo(
        pageNumber: pageNum,
        mediaBox: currentMediaBox,
        resourcesDict: currentResources,
        xObjects: xObjects,
        contentStreams: contents,
      ),
    );
  }

  List<_PdfPageInfo> _fallbackScanPages(_PdfObjectTable table) {
    final pages = <_PdfPageInfo>[];
    for (final obj in table.allObjects) {
      final isPage = obj.dict.contains('/Type/Page') ||
          (obj.dict.contains('/Type /Page') && !obj.dict.contains('/Type /Pages'));
      if (isPage) {
        final xObjects = _extractXObjectsFromResources(obj.dict, table);
        final contents = _extractPageContents(obj, table);
        pages.add(
          _PdfPageInfo(
            pageNumber: pages.length + 1,
            mediaBox: const BoundingBox(left: 0, top: 0, right: 612, bottom: 792),
            resourcesDict: obj.dict,
            xObjects: xObjects,
            contentStreams: contents,
          ),
        );
      }
    }
    return pages;
  }

  Map<String, int> _extractXObjectsFromResources(
    String resourcesDict,
    _PdfObjectTable table,
  ) {
    final map = <String, int>{};
    final xObjBlockMatch = RegExp(
      r'/XObject\s*(<<.*?>>|\d+\s+0\s+R)',
      dotAll: true,
    ).firstMatch(resourcesDict);

    if (xObjBlockMatch == null) return map;

    var block = xObjBlockMatch.group(1)!;
    if (block.contains('0 R')) {
      final refMatch = RegExp(r'(\d+)\s+0\s+R').firstMatch(block);
      if (refMatch != null) {
        final refId = int.tryParse(refMatch.group(1)!);
        if (refId != null) {
          final resObj = table.getObject(refId);
          if (resObj != null) block = resObj.dict;
        }
      }
    }

    final entryRegex = RegExp(r'/([A-Za-z0-9_]+)\s+(\d+)\s+0\s+R');
    for (final m in entryRegex.allMatches(block)) {
      final name = m.group(1)!;
      final objId = int.parse(m.group(2)!);
      map[name] = objId;
    }

    return map;
  }

  List<Uint8List> _extractPageContents(_PdfObject pageObj, _PdfObjectTable table) {
    final contents = <Uint8List>[];
    final cMatch = RegExp(r'/Contents\s*(\[.*?\]|\d+\s+0\s+R)', dotAll: true).firstMatch(pageObj.dict);
    if (cMatch == null) {
      if (pageObj.stream != null && pageObj.stream!.isNotEmpty) {
        contents.add(pageObj.stream!);
      }
      return contents;
    }

    final raw = cMatch.group(1)!;
    final refs = RegExp(r'(\d+)\s+0\s+R').allMatches(raw);
    for (final ref in refs) {
      final cId = int.parse(ref.group(1)!);
      final cObj = table.getObject(cId);
      if (cObj != null && cObj.stream != null) {
        // Decompress if FlateDecode
        if (cObj.dict.contains('/FlateDecode')) {
          try {
            contents.add(Uint8List.fromList(zlib.decode(cObj.stream!)));
          } on Object catch (_) {
            contents.add(cObj.stream!);
          }
        } else {
          contents.add(cObj.stream!);
        }
      }
    }

    return contents;
  }

  // ===========================================================================
  // CONTENT STREAM OPERATORS & VECTOR DIAGRAM ANALYSIS
  // ===========================================================================

  _ContentStreamAnalysis _analyzeContentStreams(
    List<Uint8List> contentStreams,
    BoundingBox mediaBox,
  ) {
    final placements = <String, _ImagePlacement>{};
    final pathPoints = <math.Point<double>>[];
    var operationCount = 0;

    final fullText = contentStreams
        .map((s) => latin1.decode(s, allowInvalid: true))
        .join('\n');

    final matrixStack = <List<double>>[];
    var currentMatrix = [1.0, 0.0, 0.0, 1.0, 0.0, 0.0];

    final pageHeight = mediaBox.height > 0 ? mediaBox.height : 792.0;

    final tokens = fullText.split(RegExp(r'\s+'));
    final numBuffer = <double>[];

    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i].trim();
      if (token.isEmpty) continue;

      final numVal = double.tryParse(token);
      if (numVal != null) {
        numBuffer.add(numVal);
        continue;
      }

      switch (token) {
        case 'q':
          matrixStack.add(List<double>.from(currentMatrix));
          numBuffer.clear();
        case 'Q':
          if (matrixStack.isNotEmpty) {
            currentMatrix = matrixStack.removeLast();
          }
          numBuffer.clear();
        case 'cm':
          if (numBuffer.length >= 6) {
            final a = numBuffer[numBuffer.length - 6];
            final b = numBuffer[numBuffer.length - 5];
            final c = numBuffer[numBuffer.length - 4];
            final d = numBuffer[numBuffer.length - 3];
            final e = numBuffer[numBuffer.length - 2];
            final f = numBuffer[numBuffer.length - 1];
            currentMatrix = _multiplyMatrix(currentMatrix, [a, b, c, d, e, f]);
          }
          numBuffer.clear();
        case 'Do':
          if (i > 0) {
            final nameToken = tokens[i - 1].replaceAll('/', '');
            if (nameToken.isNotEmpty) {
              final x0 = currentMatrix[4];
              final y0 = currentMatrix[5];
              final x1 = currentMatrix[0] + currentMatrix[4];
              final y1 = currentMatrix[3] + currentMatrix[5];

              final left = math.min(x0, x1);
              final right = math.max(x0, x1);
              final top = pageHeight - math.max(y0, y1);
              final bottom = pageHeight - math.min(y0, y1);

              placements[nameToken] = _ImagePlacement(
                nameToken,
                BoundingBox(left: left, top: top, right: right, bottom: bottom),
              );
            }
          }
          numBuffer.clear();
        case 'm':
          if (numBuffer.length >= 2) {
            final x = numBuffer[numBuffer.length - 2];
            final y = numBuffer[numBuffer.length - 1];
            pathPoints.add(_transformPoint(x, y, currentMatrix, pageHeight));
            operationCount++;
          }
          numBuffer.clear();
        case 'l':
          if (numBuffer.length >= 2) {
            final x = numBuffer[numBuffer.length - 2];
            final y = numBuffer[numBuffer.length - 1];
            pathPoints.add(_transformPoint(x, y, currentMatrix, pageHeight));
            operationCount++;
          }
          numBuffer.clear();
        case 'c':
          if (numBuffer.length >= 6) {
            final x3 = numBuffer[numBuffer.length - 2];
            final y3 = numBuffer[numBuffer.length - 1];
            pathPoints.add(_transformPoint(x3, y3, currentMatrix, pageHeight));
            operationCount++;
          }
          numBuffer.clear();
        case 're':
          if (numBuffer.length >= 4) {
            final x = numBuffer[numBuffer.length - 4];
            final y = numBuffer[numBuffer.length - 3];
            final w = numBuffer[numBuffer.length - 2];
            final h = numBuffer[numBuffer.length - 1];
            pathPoints.addAll([
              _transformPoint(x, y, currentMatrix, pageHeight),
              _transformPoint(x + w, y + h, currentMatrix, pageHeight),
            ]);
            operationCount++;
          }
          numBuffer.clear();
        default:
          numBuffer.clear();
      }
    }

    _VectorPathCluster? vectorCluster;
    if (pathPoints.length >= 4) {
      var minX = double.infinity;
      var minY = double.infinity;
      var maxX = double.negativeInfinity;
      var maxY = double.negativeInfinity;

      for (final pt in pathPoints) {
        if (pt.x < minX) minX = pt.x;
        if (pt.y < minY) minY = pt.y;
        if (pt.x > maxX) maxX = pt.x;
        if (pt.y > maxY) maxY = pt.y;
      }

      final w = maxX - minX;
      final h = maxY - minY;
      if (w >= 40 && h >= 30) {
        vectorCluster = _VectorPathCluster(
          bounds: BoundingBox(left: minX, top: minY, right: maxX, bottom: maxY),
          points: pathPoints,
          operationCount: operationCount,
        );
      }
    }

    return _ContentStreamAnalysis(
      placements: placements,
      vectorCluster: vectorCluster,
    );
  }

  static List<double> _multiplyMatrix(List<double> m1, List<double> m2) {
    final a1 = m1[0];
    final b1 = m1[1];
    final c1 = m1[2];
    final d1 = m1[3];
    final e1 = m1[4];
    final f1 = m1[5];

    final a2 = m2[0];
    final b2 = m2[1];
    final c2 = m2[2];
    final d2 = m2[3];
    final e2 = m2[4];
    final f2 = m2[5];

    return [
      a1 * a2 + c1 * b2,
      b1 * a2 + d1 * b2,
      a1 * c2 + c1 * d2,
      b1 * c2 + d1 * d2,
      a1 * e2 + c1 * f2 + e1,
      b1 * e2 + d1 * f2 + f1,
    ];
  }

  static math.Point<double> _transformPoint(
    double x,
    double y,
    List<double> m,
    double pageHeight,
  ) {
    final tx = m[0] * x + m[2] * y + m[4];
    final ty = m[1] * x + m[3] * y + m[5];
    return math.Point<double>(tx, pageHeight - ty);
  }

  // ===========================================================================
  // IMAGE XOBJECT DECODING (Flate, DCT, JPX, CMYK, Indexed, SMask)
  // ===========================================================================

  _DecodedImageData? _decodeImageXObject(
    _PdfObject imageObj,
    _PdfObjectTable table,
  ) {
    final dict = imageObj.dict;
    final stream = imageObj.stream;
    if (stream == null || stream.isEmpty) return null;

    final width = _parseDictInt(dict, 'Width', table) ?? 0;
    final height = _parseDictInt(dict, 'Height', table) ?? 0;
    if (width <= 0 || height <= 0) return null;

    final isFlate = dict.contains('/FlateDecode');
    final isDct = dict.contains('/DCTDecode');
    final isJpx = dict.contains('/JPXDecode');

    // 1. DCTDecode (JPEG)
    if (isDct) {
      return _DecodedImageData(
        bytes: stream,
        extension: 'jpg',
        width: width,
        height: height,
      );
    }

    // 2. JPXDecode (JPEG 2000)
    if (isJpx) {
      return _DecodedImageData(
        bytes: stream,
        extension: 'jp2',
        width: width,
        height: height,
      );
    }

    // 3. FlateDecode
    if (isFlate) {
      Uint8List decompressed;
      try {
        decompressed = Uint8List.fromList(zlib.decode(stream));
      } on Object catch (_) {
        return null;
      }

      final predictor = _parseDictInt(dict, 'Predictor', table) ?? 1;
      final colors = _parseDictInt(dict, 'Colors', table) ??
          (dict.contains('/DeviceGray') ? 1 : (dict.contains('/DeviceCMYK') ? 4 : 3));
      final bpc = _parseDictInt(dict, 'BitsPerComponent', table) ?? 8;
      final bytesPerPixel = math.max(1, (colors * bpc + 7) ~/ 8);

      Uint8List rawPixels;
      if (predictor >= 10) {
        rawPixels = _unfilterPngPredictor(
          filtered: decompressed,
          width: width,
          height: height,
          bytesPerPixel: bytesPerPixel,
        );
      } else if (decompressed.length == height * (width * bytesPerPixel + 1)) {
        rawPixels = _unfilterPngPredictor(
          filtered: decompressed,
          width: width,
          height: height,
          bytesPerPixel: bytesPerPixel,
        );
      } else {
        rawPixels = decompressed;
      }

      // Check ColorSpace: CMYK
      if (dict.contains('/DeviceCMYK') || colors == 4) {
        rawPixels = _cmykToRgb(rawPixels, width, height);
      }
      // Check ColorSpace: Indexed
      else if (dict.contains('/Indexed')) {
        final palette = _extractIndexedPalette(dict, table);
        if (palette != null) {
          rawPixels = _indexedToRgb(rawPixels, palette, width, height);
        }
      }

      // Check SMask for Alpha Transparency
      final smaskMatch = RegExp(r'/SMask\s+(\d+)\s+0\s+R').firstMatch(dict);
      if (smaskMatch != null) {
        final smaskObjId = int.parse(smaskMatch.group(1)!);
        final smaskObj = table.getObject(smaskObjId);
        if (smaskObj != null && smaskObj.stream != null) {
          try {
            final smaskRaw = smaskObj.dict.contains('/FlateDecode')
                ? Uint8List.fromList(zlib.decode(smaskObj.stream!))
                : smaskObj.stream!;
            rawPixels = _compositeRgbWithSMask(rawPixels, smaskRaw, width, height);
            final pngBytes = encodePixelsToPng(rawPixels, width, height, channels: 4);
            return _DecodedImageData(
              bytes: pngBytes,
              extension: 'png',
              width: width,
              height: height,
            );
          } on Object catch (_) {}
        }
      }

      final channels = rawPixels.length == width * height ? 1 : 3;
      final pngBytes = encodePixelsToPng(rawPixels, width, height, channels: channels);
      return _DecodedImageData(
        bytes: pngBytes,
        extension: 'png',
        width: width,
        height: height,
      );
    }

    return null;
  }

  Uint8List _unfilterPngPredictor({
    required Uint8List filtered,
    required int width,
    required int height,
    required int bytesPerPixel,
  }) {
    final rowStride = width * bytesPerPixel;
    final uncompressed = Uint8List(width * height * bytesPerPixel);
    final priorRow = Uint8List(rowStride);

    var srcOffset = 0;
    var destOffset = 0;

    for (var y = 0; y < height; y++) {
      if (srcOffset >= filtered.length) break;
      final filterType = filtered[srcOffset++];
      final currentRow = Uint8List(rowStride);

      for (var x = 0; x < rowStride; x++) {
        if (srcOffset >= filtered.length) break;
        final byteVal = filtered[srcOffset++];
        final rawLeft = (x >= bytesPerPixel) ? currentRow[x - bytesPerPixel] : 0;
        final rawAbove = priorRow[x];
        final rawAboveLeft = (x >= bytesPerPixel) ? priorRow[x - bytesPerPixel] : 0;

        int reconstructed;
        switch (filterType) {
          case 0:
            reconstructed = byteVal;
          case 1:
            reconstructed = (byteVal + rawLeft) & 0xFF;
          case 2:
            reconstructed = (byteVal + rawAbove) & 0xFF;
          case 3:
            reconstructed = (byteVal + ((rawLeft + rawAbove) >> 1)) & 0xFF;
          case 4:
            reconstructed = (byteVal + _paethPredictor(rawLeft, rawAbove, rawAboveLeft)) & 0xFF;
          default:
            reconstructed = byteVal;
        }
        currentRow[x] = reconstructed;
        if (destOffset < uncompressed.length) {
          uncompressed[destOffset++] = reconstructed;
        }
      }
      priorRow.setAll(0, currentRow);
    }

    return uncompressed;
  }

  static int _paethPredictor(int a, int b, int c) {
    final p = a + b - c;
    final pa = (p - a).abs();
    final pb = (p - b).abs();
    final pc = (p - c).abs();
    if (pa <= pb && pa <= pc) return a;
    if (pb <= pc) return b;
    return c;
  }

  static Uint8List _cmykToRgb(Uint8List cmyk, int width, int height) {
    final rgb = Uint8List(width * height * 3);
    final pixelCount = width * height;
    for (var i = 0; i < pixelCount; i++) {
      final src = i * 4;
      if (src + 3 >= cmyk.length) break;
      final c = cmyk[src] / 255.0;
      final m = cmyk[src + 1] / 255.0;
      final y = cmyk[src + 2] / 255.0;
      final k = cmyk[src + 3] / 255.0;

      rgb[i * 3] = ((1 - c) * (1 - k) * 255).round().clamp(0, 255);
      rgb[i * 3 + 1] = ((1 - m) * (1 - k) * 255).round().clamp(0, 255);
      rgb[i * 3 + 2] = ((1 - y) * (1 - k) * 255).round().clamp(0, 255);
    }
    return rgb;
  }

  static Uint8List _indexedToRgb(
    Uint8List indices,
    Uint8List palette,
    int width,
    int height,
  ) {
    final rgb = Uint8List(width * height * 3);
    final pixelCount = width * height;
    for (var i = 0; i < pixelCount; i++) {
      if (i >= indices.length) break;
      final idx = indices[i];
      final palOffset = idx * 3;
      if (palOffset + 2 < palette.length) {
        rgb[i * 3] = palette[palOffset];
        rgb[i * 3 + 1] = palette[palOffset + 1];
        rgb[i * 3 + 2] = palette[palOffset + 2];
      }
    }
    return rgb;
  }

  Uint8List? _extractIndexedPalette(String dict, _PdfObjectTable table) {
    final idxMatch = RegExp(r'/Indexed\s*\[\s*\/DeviceRGB\s+(\d+)\s+([<(\d].*?)\]', dotAll: true).firstMatch(dict);
    if (idxMatch == null) return null;
    final lookup = idxMatch.group(2)!.trim();

    if (lookup.startsWith('<') && lookup.endsWith('>')) {
      final hex = lookup.substring(1, lookup.length - 1).replaceAll(RegExp(r'\s+'), '');
      final bytes = Uint8List(hex.length ~/ 2);
      for (var i = 0; i < bytes.length; i++) {
        bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
      }
      return bytes;
    }

    if (lookup.contains('0 R')) {
      final refMatch = RegExp(r'(\d+)\s+0\s+R').firstMatch(lookup);
      if (refMatch != null) {
        final refId = int.tryParse(refMatch.group(1)!);
        if (refId != null) {
          final palObj = table.getObject(refId);
          if (palObj != null && palObj.stream != null) {
            if (palObj.dict.contains('/FlateDecode')) {
              try {
                return Uint8List.fromList(zlib.decode(palObj.stream!));
              } on Object catch (_) {}
            }
            return palObj.stream;
          }
        }
      }
    }

    return null;
  }

  static Uint8List _compositeRgbWithSMask(
    Uint8List rgb,
    Uint8List smaskAlpha,
    int width,
    int height,
  ) {
    final rgba = Uint8List(width * height * 4);
    final pixelCount = width * height;
    for (var i = 0; i < pixelCount; i++) {
      final rgbSrc = i * 3;
      final rgbaDest = i * 4;
      if (rgbSrc + 2 < rgb.length) {
        rgba[rgbaDest] = rgb[rgbSrc];
        rgba[rgbaDest + 1] = rgb[rgbSrc + 1];
        rgba[rgbaDest + 2] = rgb[rgbSrc + 2];
      }
      rgba[rgbaDest + 3] = (i < smaskAlpha.length) ? smaskAlpha[i] : 255;
    }
    return rgba;
  }

  int? _parseDictInt(String dict, String key, _PdfObjectTable table) {
    final m = RegExp('/$key\\s+([0-9]+|\\d+\\s+0\\s+R)').firstMatch(dict);
    if (m == null) return null;
    final val = m.group(1)!;
    if (val.contains('0 R')) {
      final refMatch = RegExp(r'(\d+)\s+0\s+R').firstMatch(val);
      if (refMatch != null) {
        final refId = int.tryParse(refMatch.group(1)!);
        if (refId != null) {
          final obj = table.getObject(refId);
          if (obj != null) {
            final intMatch = RegExp(r'(\d+)').firstMatch(obj.dict);
            if (intMatch != null) return int.tryParse(intMatch.group(1)!);
          }
        }
      }
      return null;
    }
    return int.tryParse(val);
  }

  // ===========================================================================
  // VECTOR DIAGRAM RASTERIZATION
  // ===========================================================================

  Uint8List _rasterizeVectorDiagram(
    _VectorPathCluster? cluster, {
    required int width,
    required int height,
  }) {
    final pixels = Uint8List(width * height * 3);

    // 1. Fill background with clean off-white (#F8FAFC)
    for (var i = 0; i < width * height; i++) {
      pixels[i * 3] = 248;
      pixels[i * 3 + 1] = 250;
      pixels[i * 3 + 2] = 252;
    }

    // Draw subtle border around figure frame
    _drawRect(pixels, width, height, 4, 4, width - 8, height - 8, r: 226, g: 232, b: 240);

    if (cluster != null && cluster.points.length >= 2) {
      final bounds = cluster.bounds;
      final bWidth = math.max(1, bounds.width);
      final bHeight = math.max(1, bounds.height);

      const padX = 24;
      const padY = 24;
      final drawW = width - padX * 2;
      final drawH = height - padY * 2;

      for (var i = 0; i < cluster.points.length - 1; i++) {
        final p1 = cluster.points[i];
        final p2 = cluster.points[i + 1];

        final x1 = ((p1.x - bounds.left) / bWidth * drawW + padX).round().clamp(0, width - 1);
        final y1 = ((p1.y - bounds.top) / bHeight * drawH + padY).round().clamp(0, height - 1);
        final x2 = ((p2.x - bounds.left) / bWidth * drawW + padX).round().clamp(0, width - 1);
        final y2 = ((p2.y - bounds.top) / bHeight * drawH + padY).round().clamp(0, height - 1);

        _drawLine(pixels, width, height, x1, y1, x2, y2, r: 30, g: 41, b: 59);
      }
    } else {
      _drawLine(pixels, width, height, 40, height - 40, width - 40, height - 40, r: 71, g: 85, b: 105);
      _drawLine(pixels, width, height, 40, 40, 40, height - 40, r: 71, g: 85, b: 105);
      _drawLine(pixels, width, height, 40, height - 40, width ~/ 2, 60, r: 37, g: 99, b: 235);
      _drawLine(pixels, width, height, width ~/ 2, 60, width - 40, height - 80, r: 37, g: 99, b: 235);
    }

    return encodePixelsToPng(pixels, width, height);
  }

  static void _drawLine(
    Uint8List pixels,
    int width,
    int height,
    int x0,
    int y0,
    int x1,
    int y1, {
    required int r,
    required int g,
    required int b,
  }) {
    final dx = (x1 - x0).abs();
    final dy = -(y1 - y0).abs();
    final sx = x0 < x1 ? 1 : -1;
    final sy = y0 < y1 ? 1 : -1;
    var err = dx + dy;

    var curX = x0;
    var curY = y0;

    while (true) {
      if (curX >= 0 && curX < width && curY >= 0 && curY < height) {
        final idx = (curY * width + curX) * 3;
        pixels[idx] = r;
        pixels[idx + 1] = g;
        pixels[idx + 2] = b;
      }
      if (curX == x1 && curY == y1) break;
      final e2 = 2 * err;
      if (e2 >= dy) {
        err += dy;
        curX += sx;
      }
      if (e2 <= dx) {
        err += dx;
        curY += sy;
      }
    }
  }

  static void _drawRect(
    Uint8List pixels,
    int width,
    int height,
    int x,
    int y,
    int w,
    int h, {
    required int r,
    required int g,
    required int b,
  }) {
    _drawLine(pixels, width, height, x, y, x + w, y, r: r, g: g, b: b);
    _drawLine(pixels, width, height, x + w, y, x + w, y + h, r: r, g: g, b: b);
    _drawLine(pixels, width, height, x + w, y + h, x, y + h, r: r, g: g, b: b);
    _drawLine(pixels, width, height, x, y + h, x, y, r: r, g: g, b: b);
  }

  // ===========================================================================
  // CAPTION EXTRACTION & ASSOCIATION
  // ===========================================================================

  Map<int, List<_ExtractedCaption>> _extractCaptions(
    List<_PdfPageInfo> pages,
    List<String>? pageTexts,
  ) {
    final map = <int, List<_ExtractedCaption>>{};

    final captionRegex = RegExp(
      r'(?:Figure|Fig\.?|Diagram|Chart)\s+(\d+(?:\.\d+)?)\s*(?:\([^\)]+\))?[:\.\-—–]?\s*([^\r\n]+)',
      caseSensitive: false,
    );

    // 1. From provided pageTexts
    if (pageTexts != null) {
      for (var i = 0; i < pageTexts.length; i++) {
        final pNum = i + 1;
        final text = pageTexts[i];
        for (final m in captionRegex.allMatches(text)) {
          final numStr = m.group(1)!;
          final capText = m.group(2)!.trim();
          map.putIfAbsent(pNum, () => []).add(
            _ExtractedCaption(number: numStr, captionText: capText),
          );
        }
      }
    }

    // 2. From content stream strings if not yet found
    for (final page in pages) {
      final pNum = page.pageNumber;
      if (map.containsKey(pNum) && map[pNum]!.isNotEmpty) continue;

      final unescapedText = page.contentStreams
          .map((s) => latin1.decode(s, allowInvalid: true))
          .join('\n')
          .replaceAll(r'\(', '(')
          .replaceAll(r'\)', ')')
          .replaceAll(r'\\', r'\');

      for (final m in captionRegex.allMatches(unescapedText)) {
        final numStr = m.group(1)!;
        var capText = m.group(2)!.trim();
        // Remove trailing PDF operator artifacts
        capText = capText.replaceAll(RegExp(r'\)\s*T[j*].*$'), '').trim();
        // Remove leading (Page N): prefix if present
        capText = capText.replaceFirst(
          RegExp(r'^\(?Page\s+\d+\)?[:\.\-—–]?\s*', caseSensitive: false),
          '',
        ).trim();
        // Remove trailing unescaped paren artifact if any
        if (capText.endsWith(')')) {
          capText = capText.substring(0, capText.length - 1).trim();
        }
        if (capText.isNotEmpty) {
          map.putIfAbsent(pNum, () => []).add(
            _ExtractedCaption(number: numStr, captionText: capText),
          );
        }
      }
    }

    return map;
  }

  // ===========================================================================
  // PNG ENCODER (1, 3, 4 Channels)
  // ===========================================================================

  static Uint8List encodePixelsToPng(
    Uint8List rawPixels,
    int width,
    int height, {
    int channels = 3,
  }) {
    final rowBytes = width * channels;
    final scanlines = Uint8List(height * (rowBytes + 1));
    var dest = 0;
    for (var y = 0; y < height; y++) {
      scanlines[dest++] = 0;
      final src = y * rowBytes;
      final copyLen = math.min(rowBytes, rawPixels.length - src);
      if (copyLen > 0) {
        scanlines.setRange(dest, dest + copyLen, rawPixels.sublist(src, src + copyLen));
      }
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

  static int _crc32(Uint8List data) {
    var crc = 0xffffffff;
    for (final byte in data) {
      crc = _crcTable[(crc ^ byte) & 0xff] ^ (crc >>> 8);
    }
    return (crc ^ 0xffffffff) >>> 0;
  }

  static final List<int> _crcTable = () {
    final table = List<int>.filled(256, 0);
    for (var i = 0; i < 256; i++) {
      var c = i;
      for (var j = 0; j < 8; j++) {
        c = (c & 1) != 0 ? (0xedb88320 ^ (c >>> 1)) : (c >>> 1);
      }
      table[i] = c >>> 0;
    }
    return table;
  }();
}

// =============================================================================
// INTERNAL PDF STRUCTURE ENTITIES
// =============================================================================

class _PdfObject {
  _PdfObject({
    required this.id,
    required this.generation,
    required this.dict,
    this.stream,
  });

  final int id;
  final int generation;
  final String dict;
  final Uint8List? stream;
}

class _PdfObjectTable {
  _PdfObjectTable._(this._objects, this.trailerRootId);

  factory _PdfObjectTable.fromBytes(Uint8List bytes) {
    final objects = <int, _PdfObject>{};
    final latinText = latin1.decode(bytes, allowInvalid: true);

    int? rootId;
    final rootMatch = RegExp(r'/Root\s+(\d+)\s+0\s+R').firstMatch(latinText);
    if (rootMatch != null) {
      rootId = int.tryParse(rootMatch.group(1)!);
    }

    final objRegex = RegExp(r'(\d+)\s+(\d+)\s+obj\b');
    final matches = objRegex.allMatches(latinText).toList();

    for (var i = 0; i < matches.length; i++) {
      final match = matches[i];
      final id = int.parse(match.group(1)!);
      final gen = int.parse(match.group(2)!);
      final startPos = match.end;

      final nextPos = (i + 1 < matches.length)
          ? matches[i + 1].start
          : latinText.length;

      final objSlice = latinText.substring(startPos, nextPos);
      final endObjIdx = objSlice.indexOf('endobj');
      final objBody = endObjIdx != -1 ? objSlice.substring(0, endObjIdx) : objSlice;

      var dictStr = '';
      final dictStart = objBody.indexOf('<<');
      if (dictStart != -1) {
        var depth = 0;
        var endIdx = -1;
        for (var j = dictStart; j < objBody.length - 1; j++) {
          if (objBody[j] == '<' && objBody[j + 1] == '<') {
            depth++;
            j++;
          } else if (objBody[j] == '>' && objBody[j + 1] == '>') {
            depth--;
            j++;
            if (depth == 0) {
              endIdx = j + 1;
              break;
            }
          }
        }
        if (endIdx != -1) {
          dictStr = objBody.substring(dictStart, endIdx);
        }
      }

      Uint8List? streamBytes;
      final streamMarker = RegExp(r'stream\r?\n');
      final streamMatch = streamMarker.firstMatch(objBody);
      if (streamMatch != null) {
        final streamByteStart = startPos + streamMatch.end;

        var streamLength = -1;
        final lenMatch = RegExp(r'/Length\s+(\d+)').firstMatch(dictStr);
        if (lenMatch != null) {
          streamLength = int.parse(lenMatch.group(1)!);
        }

        if (streamLength >= 0 && streamByteStart + streamLength <= bytes.length) {
          streamBytes = bytes.sublist(streamByteStart, streamByteStart + streamLength);
        } else {
          final endstreamIdx = latinText.indexOf('endstream', streamByteStart);
          if (endstreamIdx != -1 && endstreamIdx <= bytes.length) {
            streamBytes = bytes.sublist(streamByteStart, endstreamIdx);
          }
        }
      }

      objects[id] = _PdfObject(
        id: id,
        generation: gen,
        dict: dictStr.isNotEmpty ? dictStr : objBody,
        stream: streamBytes,
      );
    }

    return _PdfObjectTable._(objects, rootId);
  }

  final Map<int, _PdfObject> _objects;
  final int? trailerRootId;

  Iterable<_PdfObject> get allObjects => _objects.values;

  _PdfObject? getObject(int id) => _objects[id];
}

class _PdfPageInfo {
  const _PdfPageInfo({
    required this.pageNumber,
    required this.mediaBox,
    required this.resourcesDict,
    required this.xObjects,
    required this.contentStreams,
  });

  final int pageNumber;
  final BoundingBox mediaBox;
  final String resourcesDict;
  final Map<String, int> xObjects;
  final List<Uint8List> contentStreams;
}

class _ImagePlacement {
  const _ImagePlacement(this.name, this.bbox);
  final String name;
  final BoundingBox bbox;
}

class _VectorPathCluster {
  const _VectorPathCluster({
    required this.bounds,
    required this.points,
    required this.operationCount,
  });

  final BoundingBox bounds;
  final List<math.Point<double>> points;
  final int operationCount;
}

class _ContentStreamAnalysis {
  const _ContentStreamAnalysis({
    required this.placements,
    this.vectorCluster,
  });

  final Map<String, _ImagePlacement> placements;
  final _VectorPathCluster? vectorCluster;
}

class _DecodedImageData {
  const _DecodedImageData({
    required this.bytes,
    required this.extension,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final String extension;
  final int width;
  final int height;
}

class _ExtractedCaption {
  const _ExtractedCaption({
    required this.number,
    required this.captionText,
  });

  final String number;
  final String captionText;
}
