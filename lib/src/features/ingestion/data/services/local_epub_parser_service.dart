import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:kortex/src/features/ingestion/data/services/local_html_parser_service.dart';
import 'package:kortex/src/features/ingestion/domain/entities/extraction_report.dart';
import 'package:kortex/src/features/ingestion/domain/exceptions/ingestion_exceptions.dart';

/// Native EPUB ebook parser service.
///
/// Follows IDPF Open Publication Structure (OPS) and Open Packaging Format (OPF):
/// 1. Unzips EPUB container
/// 2. Reads `META-INF/container.xml` to discover the OPF rootfile
/// 3. Parses `content.opf` `<manifest>` and `<spine>` for true sequential chapter order
/// 4. Processes each chapter XHTML in spine order via [LocalHtmlParserService]
/// 5. Captures headings, tables, code, formulas, and figures across chapters
class LocalEpubParserService {
  const LocalEpubParserService();

  static const LocalEpubParserService instance = LocalEpubParserService();

  /// Extracts structured text from EPUB bytes synchronously.
  static String extractTextFromBytesSync(
    Uint8List bytes, {
    String? filename,
    ExtractionReport? report,
  }) {
    final epubFilename = filename ?? 'document.epub';

    if (bytes.isEmpty) {
      report?.isCorrupt = true;
      report?.recordDrop(
        rule: 'corrupted_epub_archive',
        sampleText: 'Empty byte payload',
      );
      throw CorruptDocumentException(epubFilename, 'EPUB file is empty');
    }

    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      report?.isCorrupt = true;
      report?.recordDrop(
        rule: 'corrupted_epub_archive',
        sampleText: '$e',
      );
      throw CorruptDocumentException(
        epubFilename,
        'Malformed EPUB zip container: $e',
      );
    }

    // 1. Locate META-INF/container.xml
    final containerFile = archive.findFile('META-INF/container.xml');
    if (containerFile == null) {
      report?.isCorrupt = true;
      report?.recordDrop(
        rule: 'corrupted_epub_archive',
        sampleText: 'Missing META-INF/container.xml',
      );
      throw CorruptDocumentException(
        epubFilename,
        'EPUB missing META-INF/container.xml',
      );
    }

    final containerXml = utf8.decode(
      containerFile.content as List<int>,
      allowMalformed: true,
    );

    // 2. Discover rootfile full-path
    final rootfileMatch = RegExp(
      '<rootfile[^>]*full-path="([^"]+)"',
      caseSensitive: false,
    ).firstMatch(containerXml);

    if (rootfileMatch == null) {
      report?.isCorrupt = true;
      report?.recordDrop(
        rule: 'corrupted_epub_archive',
        sampleText: 'container.xml missing rootfile full-path',
      );
      throw CorruptDocumentException(
        epubFilename,
        'EPUB container.xml missing rootfile full-path',
      );
    }

    final opfFullPath = rootfileMatch.group(1)!;

    // 3. Locate and parse OPF package file
    final opfFile = archive.findFile(opfFullPath);
    if (opfFile == null) {
      report?.isCorrupt = true;
      report?.recordDrop(
        rule: 'corrupted_epub_archive',
        sampleText: 'Missing OPF file at $opfFullPath',
      );
      throw CorruptDocumentException(
        epubFilename,
        'EPUB missing OPF package file at $opfFullPath',
      );
    }

    final opfXml = utf8.decode(
      opfFile.content as List<int>,
      allowMalformed: true,
    );

    // Base directory for resolving relative chapter hrefs
    final lastSlashIndex = opfFullPath.lastIndexOf('/');
    final opfBaseDir = lastSlashIndex != -1
        ? opfFullPath.substring(0, lastSlashIndex + 1)
        : '';

    // 4. Parse <manifest> (item id -> href)
    final manifestMap = <String, String>{};
    final itemMatches = RegExp(
      '<item[^>]*id="([^"]+)"[^>]*href="([^"]+)"',
      caseSensitive: false,
    ).allMatches(opfXml);

    for (final m in itemMatches) {
      manifestMap[m.group(1)!] = m.group(2)!;
    }

    // Also support reversed attribute order href then id
    if (manifestMap.isEmpty) {
      final altItemMatches = RegExp(
        '<item[^>]*href="([^"]+)"[^>]*id="([^"]+)"',
        caseSensitive: false,
      ).allMatches(opfXml);
      for (final m in altItemMatches) {
        manifestMap[m.group(2)!] = m.group(1)!;
      }
    }

    // 5. Parse <spine> (<itemref idref="...">) for canonical chapter sequence
    final spineChapterPaths = <String>[];
    final spineMatch = RegExp(
      r'<spine[^>]*>([\s\S]*?)</spine>',
      caseSensitive: false,
    ).firstMatch(opfXml);

    if (spineMatch != null) {
      final spineContent = spineMatch.group(1)!;
      final itemrefMatches = RegExp(
        '<itemref[^>]*idref="([^"]+)"',
        caseSensitive: false,
      ).allMatches(spineContent);

      for (final ref in itemrefMatches) {
        final idref = ref.group(1)!;
        final href = manifestMap[idref];
        if (href != null) {
          final resolvedPath = _resolveArchiveHref(opfBaseDir, href);
          spineChapterPaths.add(resolvedPath);
        }
      }
    }

    // Fallback: If spine was missing or unparseable, collect XHTML/HTML files from manifest or archive
    if (spineChapterPaths.isEmpty) {
      for (final href in manifestMap.values) {
        final lower = href.toLowerCase();
        if (lower.endsWith('.xhtml') ||
            lower.endsWith('.html') ||
            lower.endsWith('.htm')) {
          spineChapterPaths.add(_resolveArchiveHref(opfBaseDir, href));
        }
      }
    }

    // Secondary fallback: All html files in archive if manifest is corrupt
    if (spineChapterPaths.isEmpty) {
      for (final file in archive.files) {
        if (file.isFile) {
          final lower = file.name.toLowerCase();
          if (lower.endsWith('.xhtml') ||
              lower.endsWith('.html') ||
              lower.endsWith('.htm')) {
            spineChapterPaths.add(file.name);
          }
        }
      }
    }

    if (spineChapterPaths.isEmpty) {
      report?.isCorrupt = true;
      report?.recordDrop(
        rule: 'corrupted_epub_archive',
        sampleText: 'No readable XHTML or HTML chapters found in EPUB',
      );
      throw CorruptDocumentException(
        epubFilename,
        'EPUB archive contains no text chapters',
      );
    }

    // 6. Extract and process each chapter in spine order
    final documentBuffer = StringBuffer();

    // Check title in metadata
    final titleMatch = RegExp(
      r'<dc:title[^>]*>([\s\S]*?)</dc:title>',
      caseSensitive: false,
    ).firstMatch(opfXml);

    if (titleMatch != null) {
      final bookTitle = titleMatch.group(1)!.replaceAll(RegExp('<[^>]+>'), '').trim();
      if (bookTitle.isNotEmpty) {
        documentBuffer
          ..writeln('# $bookTitle')
          ..writeln();
      }
    }

    var validChapterCount = 0;

    for (final chapterPath in spineChapterPaths) {
      final chapterFile = archive.findFile(chapterPath);
      if (chapterFile == null) {
        continue;
      }

      final chapterHtml = utf8.decode(
        chapterFile.content as List<int>,
        allowMalformed: true,
      );

      final chapterMarkdown = LocalHtmlParserService.extractTextFromString(
        chapterHtml,
        filename: chapterPath,
      );

      if (chapterMarkdown.trim().isNotEmpty) {
        documentBuffer
          ..writeln(chapterMarkdown)
          ..writeln();
        validChapterCount++;
      }
    }

    final extractedText = documentBuffer.toString().trim();
    if (extractedText.isEmpty || validChapterCount == 0) {
      report?.isCorrupt = true;
      report?.recordDrop(
        rule: 'corrupted_epub_archive',
        sampleText: 'All chapters resulted in empty text',
      );
      throw CorruptDocumentException(
        epubFilename,
        'EPUB archive contains no readable chapter text',
      );
    }

    return extractedText;
  }

  /// Extracts structured text asynchronously.
  Future<String> extractText(
    Uint8List bytes, {
    String? filename,
    ExtractionReport? report,
  }) async {
    return extractTextFromBytesSync(
      bytes,
      filename: filename,
      report: report,
    );
  }

  /// Resolves relative chapter href paths against base directory of OPF.
  static String _resolveArchiveHref(String baseDir, String href) {
    // Strip URL query or hash anchors (#chapter1)
    var cleanHref = href.split('#').first.split('?').first;

    if (cleanHref.startsWith('/')) {
      cleanHref = cleanHref.substring(1);
    }

    final combined = '$baseDir$cleanHref';
    final segments = combined.split('/');
    final normalized = <String>[];

    for (final seg in segments) {
      if (seg == '' || seg == '.') {
        continue;
      }
      if (seg == '..') {
        if (normalized.isNotEmpty) {
          normalized.removeLast();
        }
      } else {
        normalized.add(seg);
      }
    }

    return normalized.join('/');
  }
}
