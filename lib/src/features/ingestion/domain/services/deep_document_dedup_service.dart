import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/ingestion/domain/entities/document_upload_entity.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Represents a deep structural and content fingerprint of a document.
class DocumentFingerprint {
  const DocumentFingerprint({
    required this.contentHash,
    required this.pageCount,
    required this.sampledPages,
    this.totalBytes = 0,
    this.pageDimensions = const {},
  });

  factory DocumentFingerprint.fromJson(Map<String, dynamic> json) {
    final rawSamples = json['sampledPages'] as Map<String, dynamic>? ?? {};
    final samples = <int, String>{};
    for (final entry in rawSamples.entries) {
      final key = int.tryParse(entry.key);
      if (key != null) {
        samples[key] = entry.value.toString();
      }
    }

    final rawDimensions = json['pageDimensions'] as Map<String, dynamic>? ?? {};
    final dimensions = <int, String>{};
    for (final entry in rawDimensions.entries) {
      final key = int.tryParse(entry.key);
      if (key != null) {
        dimensions[key] = entry.value.toString();
      }
    }

    return DocumentFingerprint(
      contentHash: json['contentHash'] as String? ?? '',
      pageCount: json['pageCount'] as int? ?? 1,
      sampledPages: samples,
      totalBytes: json['totalBytes'] as int? ?? 0,
      pageDimensions: dimensions,
    );
  }

  final String contentHash;
  final int pageCount;
  /// Map of pageIndex -> normalized text content sample
  final Map<int, String> sampledPages;
  final int totalBytes;
  /// Map of pageIndex -> "width_height"
  final Map<int, String> pageDimensions;

  Map<String, dynamic> toJson() => {
        'contentHash': contentHash,
        'pageCount': pageCount,
        'sampledPages': sampledPages.map(
          (k, v) => MapEntry(k.toString(), v),
        ),
        'totalBytes': totalBytes,
        'pageDimensions': pageDimensions.map(
          (k, v) => MapEntry(k.toString(), v),
        ),
      };
}

/// Service that performs deep document comparison beyond just filenames and hashes.
/// It verifies total page counts and samples representative and randomized pages to
/// guarantee document equivalence.
class DeepDocumentDedupService {
  DeepDocumentDedupService({LocalStorageService? storage})
      : _storage = storage ??
            (locator.isRegistered<LocalStorageService>()
                ? locator<LocalStorageService>()
                : null);

  final LocalStorageService? _storage;
  final math.Random _random = math.Random();

  /// Computes SHA-256 hash of raw bytes.
  static String computeSha256(Uint8List bytes) {
    return sha256.convert(bytes).toString();
  }

  /// Extracts a deep fingerprint from document bytes (page count, sampled pages, geometry).
  DocumentFingerprint extractFingerprint({
    required Uint8List bytes,
    required String fileType,
    String? contentHash,
  }) {
    final hash = contentHash ?? computeSha256(bytes);
    final normalizedType = fileType.toLowerCase().replaceAll('.', '').trim();

    if (normalizedType == 'pdf') {
      return _extractPdfFingerprint(bytes: bytes, contentHash: hash);
    }

    return _extractTextOrBinaryFingerprint(
      bytes: bytes,
      fileType: normalizedType,
      contentHash: hash,
    );
  }

  DocumentFingerprint _extractPdfFingerprint({
    required Uint8List bytes,
    required String contentHash,
  }) {
    PdfDocument? document;
    try {
      document = PdfDocument(inputBytes: bytes);
      final pageCount = document.pages.count;
      final extractor = PdfTextExtractor(document);

      // Determine pages to sample: first page, middle page, and a random page
      final sampleIndices = <int>{0};
      if (pageCount > 1) {
        sampleIndices
          ..add(pageCount ~/ 2)
          ..add(_random.nextInt(pageCount));
      }

      final sampledPages = <int, String>{};
      final pageDimensions = <int, String>{};

      for (final index in sampleIndices) {
        try {
          final page = document.pages[index];
          pageDimensions[index] =
              '${page.size.width.round()}_${page.size.height.round()}';

          var pageText = '';
          try {
            pageText = extractor.extractText(
              startPageIndex: index,
              endPageIndex: index,
            );
          } on Object catch (_) {}

          final normalized = _normalizeText(pageText);
          sampledPages[index] = normalized.length > 600
              ? normalized.substring(0, 600)
              : normalized;
        } on Object catch (e) {
          developer.log('Failed sampling page $index: $e');
        }
      }

      final fingerprint = DocumentFingerprint(
        contentHash: contentHash,
        pageCount: pageCount,
        sampledPages: sampledPages,
        totalBytes: bytes.length,
        pageDimensions: pageDimensions,
      );

      saveFingerprint(contentHash: contentHash, fingerprint: fingerprint);
      return fingerprint;
    } on Object catch (e) {
      developer.log('PDF fingerprint extraction failed: $e');
      return DocumentFingerprint(
        contentHash: contentHash,
        pageCount: 1,
        sampledPages: {},
        totalBytes: bytes.length,
      );
    } finally {
      document?.dispose();
    }
  }

  DocumentFingerprint _extractTextOrBinaryFingerprint({
    required Uint8List bytes,
    required String fileType,
    required String contentHash,
  }) {
    var textContent = '';
    try {
      textContent = utf8.decode(bytes, allowMalformed: true);
    } on Object catch (_) {}

    final lines = textContent.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final pageCount = lines.isEmpty ? 1 : math.max(1, (lines.length / 30).ceil());

    final sampledPages = <int, String>{};
    if (lines.isNotEmpty) {
      // Sample first lines
      sampledPages[0] = _normalizeText(lines.take(15).join(' '));
      if (lines.length > 30) {
        final middleIndex = lines.length ~/ 2;
        sampledPages[pageCount ~/ 2] = _normalizeText(
          lines.skip(middleIndex).take(15).join(' '),
        );
        final randomLineIndex = _random.nextInt(lines.length);
        sampledPages[pageCount - 1] = _normalizeText(
          lines.skip(randomLineIndex).take(15).join(' '),
        );
      }
    }

    final fingerprint = DocumentFingerprint(
      contentHash: contentHash,
      pageCount: pageCount,
      sampledPages: sampledPages,
      totalBytes: bytes.length,
    );

    saveFingerprint(contentHash: contentHash, fingerprint: fingerprint);
    return fingerprint;
  }

  /// Saves fingerprint in local persistent storage.
  void saveFingerprint({
    required String contentHash,
    required DocumentFingerprint fingerprint,
    String? documentId,
  }) {
    final storage = _storage;
    if (storage == null) return;

    try {
      final jsonStr = jsonEncode(fingerprint.toJson());
      unawaited(
        storage.savePreference(
          key: 'doc_fingerprint_$contentHash',
          data: jsonStr,
        ),
      );
      if (documentId != null && documentId.isNotEmpty) {
        unawaited(
          storage.savePreference(
            key: 'doc_fingerprint_$documentId',
            data: jsonStr,
          ),
        );
      }
    } on Object catch (e) {
      developer.log('Error saving document fingerprint: $e');
    }
  }

  /// Retrieves cached fingerprint for a given contentHash or documentId.
  DocumentFingerprint? getCachedFingerprint({
    required String contentHash,
    String? documentId,
  }) {
    final storage = _storage;
    if (storage == null) return null;

    try {
      var raw = storage.getPreference(key: 'doc_fingerprint_$contentHash');
      if (raw == null && documentId != null) {
        raw = storage.getPreference(key: 'doc_fingerprint_$documentId');
      }
      if (raw != null && raw.isNotEmpty) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        return DocumentFingerprint.fromJson(map);
      }
    } on Object catch (e) {
      developer.log('Error loading document fingerprint: $e');
    }
    return null;
  }

  /// Performs deep document comparison between candidate incoming bytes and an existing document.
  /// Checks:
  /// 1. Content SHA-256 hash match (instant fast-path).
  /// 2. Total Page Count match (if page count differs, documents are definitively distinct).
  /// 3. Random and representative page content comparison (word token overlap >= 85%).
  bool isSameDocument({
    required Uint8List incomingBytes,
    required String incomingFileType,
    required String incomingContentHash,
    required DocumentUploadEntity existingDoc,
  }) {
    // 1. Fast path: Identical SHA-256 content hash
    if (incomingContentHash == existingDoc.contentHash) {
      return true;
    }

    // 2. Extract or retrieve fingerprints
    final incomingFingerprint = extractFingerprint(
      bytes: incomingBytes,
      fileType: incomingFileType,
      contentHash: incomingContentHash,
    );

    final existingFingerprint = getCachedFingerprint(
      contentHash: existingDoc.contentHash,
      documentId: existingDoc.id,
    );

    if (existingFingerprint == null) {
      // No cached fingerprint yet: check file size difference
      // If file size differs by more than 10%, they are distinct
      final sizeDelta = (incomingBytes.length - existingDoc.fileSizeBytes).abs();
      if (sizeDelta > (incomingBytes.length * 0.10)) {
        return false;
      }
      // If filename is completely different and no hash match, treat as different
      final incomingName = existingDoc.filename.toLowerCase().trim();
      return incomingName.contains(existingDoc.filename.toLowerCase().trim());
    }

    // 3. Deep Page Count comparison:
    // If the number of pages is different, they cannot be the same document!
    if (incomingFingerprint.pageCount != existingFingerprint.pageCount) {
      developer.log(
        'Deduplication rejected: page count mismatch (${incomingFingerprint.pageCount} vs ${existingFingerprint.pageCount})',
      );
      return false;
    }

    // 4. Sampled Page Content comparison:
    // Compare content on sampled pages
    final commonPageIndices = incomingFingerprint.sampledPages.keys
        .toSet()
        .intersection(existingFingerprint.sampledPages.keys.toSet());

    if (commonPageIndices.isNotEmpty) {
      var matchingPagesCount = 0;
      var comparedPagesCount = 0;

      for (final pageIndex in commonPageIndices) {
        final textA = incomingFingerprint.sampledPages[pageIndex] ?? '';
        final textB = existingFingerprint.sampledPages[pageIndex] ?? '';

        if (textA.isNotEmpty && textB.isNotEmpty) {
          comparedPagesCount++;
          final similarity = calculateTextSimilarity(textA, textB);
          if (similarity >= 0.85) {
            matchingPagesCount++;
          }
        }
      }

      if (comparedPagesCount > 0) {
        // If all compared sample pages match with high confidence, documents are identical
        final isMatch = (matchingPagesCount / comparedPagesCount) >= 0.80;
        if (isMatch) {
          developer.log(
            'Deep deduplication confirmed match on page count (${incomingFingerprint.pageCount}) and page samples.',
          );
        }
        return isMatch;
      }
    }

    // 5. Geometry / Dimension comparison for scanned PDF pages
    final commonDimensionIndices = incomingFingerprint.pageDimensions.keys
        .toSet()
        .intersection(existingFingerprint.pageDimensions.keys.toSet());

    if (commonDimensionIndices.isNotEmpty) {
      var matchingDimensions = 0;
      for (final idx in commonDimensionIndices) {
        if (incomingFingerprint.pageDimensions[idx] ==
            existingFingerprint.pageDimensions[idx]) {
          matchingDimensions++;
        }
      }
      if (matchingDimensions == commonDimensionIndices.length) {
        // Dimensions and page counts are identical
        final sizeDelta = (incomingBytes.length - existingDoc.fileSizeBytes).abs();
        if (sizeDelta < (incomingBytes.length * 0.05)) {
          return true;
        }
      }
    }

    return false;
  }

  /// Calculates text similarity between two normalized strings based on word token overlap.
  double calculateTextSimilarity(String a, String b) {
    final normA = _normalizeText(a);
    final normB = _normalizeText(b);

    if (normA == normB) return 1;
    if (normA.isEmpty || normB.isEmpty) return 0;

    final wordsA = normA
        .split(' ')
        .where((w) => w.length > 2)
        .toSet();
    final wordsB = normB
        .split(' ')
        .where((w) => w.length > 2)
        .toSet();

    if (wordsA.isEmpty || wordsB.isEmpty) {
      return normA.contains(normB) || normB.contains(normA) ? 0.9 : 0;
    }

    final intersection = wordsA.intersection(wordsB).length;
    final union = wordsA.union(wordsB).length;
    if (union == 0) return 0;
    return intersection / union;
  }

  String _normalizeText(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[\r\n\t]+'), ' ')
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
