import 'dart:math' as math;
import 'package:equatable/equatable.dart';
import 'package:kortex/src/features/ingestion/domain/entities/ocr_extraction_entity.dart';

/// Represents a semantically chunked unit of text ready for embedding and indexing.
class TextChunk extends Equatable {
  const TextChunk({
    required this.content,
    required this.chunkIndex,
    this.pageNumber,
    this.paragraphNumber,
    this.metadata = const {},
  });

  final String content;
  final int chunkIndex;
  final int? pageNumber;
  final int? paragraphNumber;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toJson() => {
    'content': content,
    'chunk_index': chunkIndex,
    if (pageNumber != null) 'page_number': pageNumber,
    if (paragraphNumber != null) 'paragraph_number': paragraphNumber,
    'metadata': {
      ...metadata,
      if (pageNumber != null) 'page_number': pageNumber,
      if (paragraphNumber != null) 'paragraph_number': paragraphNumber,
    },
  };

  @override
  List<Object?> get props => [
    content,
    chunkIndex,
    pageNumber,
    paragraphNumber,
    metadata,
  ];
}

/// Recursive Text Splitter implementing hierarchical splitting:
/// Paragraphs ('\n\n') -> Lines ('\n') -> Sentences ('. ') -> Words (' ') -> Characters ('').
/// Target chunk size is ~500 tokens with a 50-token overlap window.
class RecursiveTextSplitter {
  const RecursiveTextSplitter({
    this.chunkSize = defaultChunkSize,
    this.chunkOverlap = defaultChunkOverlap,
    this.separators = defaultSeparators,
  });

  /// 500 tokens is approximately 2000 characters (avg 4 chars per token).
  static const int defaultChunkSize = 500;

  /// 50 tokens is approximately 200 characters.
  static const int defaultChunkOverlap = 50;

  static const List<String> defaultSeparators = [
    '\n\n',
    '\n',
    '. ',
    '? ',
    '! ',
    ' ',
    '',
  ];

  final int chunkSize;
  final int chunkOverlap;
  final List<String> separators;

  /// Approximates token count from string length (1 token ~= 4 chars).
  int countTokens(String text) {
    if (text.isEmpty) return 0;
    // Hybrid estimation: max of word count and length / 4
    final words = text.trim().split(RegExp(r'\s+')).length;
    final charEstimate = (text.length / 4.0).ceil();
    return math.max(words, charEstimate);
  }

  /// Splits a document's full raw text recursively into [TextChunk]s.
  List<TextChunk> splitText({
    required String text,
    int? pageNumber,
    int startingChunkIndex = 0,
    Map<String, dynamic>? baseMetadata,
  }) {
    if (text.trim().isEmpty) return [];

    final rawChunks = _splitRecursively(text.trim(), separators);
    final mergedChunks = _mergeChunks(rawChunks);

    final result = <TextChunk>[];
    var currentParagraph = 1;

    for (var i = 0; i < mergedChunks.length; i++) {
      final chunkContent = mergedChunks[i].trim();
      if (chunkContent.isEmpty) continue;

      result.add(
        TextChunk(
          content: chunkContent,
          chunkIndex: startingChunkIndex + i,
          pageNumber: pageNumber,
          paragraphNumber: currentParagraph,
          metadata: {
            ...?baseMetadata,
            'token_count': countTokens(chunkContent),
          },
        ),
      );

      // Advance paragraph counter when double linebreaks exist in the chunk
      final paragraphsInChunk = '\n\n'.allMatches(chunkContent).length;
      currentParagraph += math.max(1, paragraphsInChunk);
    }

    return result;
  }

  /// Splits a list of [OcrExtractionEntity] snippets, preserving page numbers
  /// and sequencing paragraph indices across the entire document.
  List<TextChunk> splitSnippets(
    List<OcrExtractionEntity> snippets, {
    Map<String, dynamic>? baseMetadata,
  }) {
    final allChunks = <TextChunk>[];
    var globalChunkIndex = 0;

    for (var i = 0; i < snippets.length; i++) {
      final snippet = snippets[i];
      final snippetText = snippet.rawText.trim();
      if (snippetText.isEmpty) continue;

      // Extract page number from topic/metadata if available, or default to 1-indexed snippet position
      final pageNumber = _extractPageNumber(snippet, fallback: i + 1);

      final chunksForSnippet = splitText(
        text: snippetText,
        pageNumber: pageNumber,
        startingChunkIndex: globalChunkIndex,
        baseMetadata: {
          ...?baseMetadata,
          'topic': snippet.topic,
          'has_latex': snippet.latexContent != null && snippet.latexContent!.isNotEmpty,
        },
      );

      allChunks.addAll(chunksForSnippet);
      globalChunkIndex += chunksForSnippet.length;
    }

    return allChunks;
  }

  int _extractPageNumber(OcrExtractionEntity snippet, {required int fallback}) {
    // Check if topic or rawText contains page markers (e.g. "Page 3" or "p. 3")
    final pageRegExp = RegExp(r'(?:page|p\.)\s*(\d+)', caseSensitive: false);
    final topicMatch = pageRegExp.firstMatch(snippet.topic);
    if (topicMatch != null) {
      final parsed = int.tryParse(topicMatch.group(1)!);
      if (parsed != null) return parsed;
    }

    final textMatch = pageRegExp.firstMatch(snippet.rawText);
    if (textMatch != null) {
      final parsed = int.tryParse(textMatch.group(1)!);
      if (parsed != null) return parsed;
    }

    return fallback;
  }

  List<String> _splitRecursively(String text, List<String> currentSeparators) {
    if (text.isEmpty) return [];

    if (countTokens(text) <= chunkSize || currentSeparators.isEmpty) {
      return [text];
    }

    final separator = currentSeparators.first;
    final remainingSeparators = currentSeparators.sublist(1);

    List<String> splits;
    if (separator.isEmpty) {
      splits = text.split('');
    } else {
      splits = text.split(separator);
    }

    final result = <String>[];
    for (final split in splits) {
      if (split.trim().isEmpty) continue;

      if (countTokens(split) <= chunkSize) {
        result.add(split);
      } else {
        result.addAll(_splitRecursively(split, remainingSeparators));
      }
    }

    return result;
  }

  List<String> _mergeChunks(List<String> splits) {
    final merged = <String>[];
    var currentChunk = StringBuffer();
    var currentTokens = 0;

    for (final piece in splits) {
      final pieceTokens = countTokens(piece);

      if (currentTokens + pieceTokens > chunkSize && currentTokens > 0) {
        merged.add(currentChunk.toString());

        // Retain overlap window from previous chunk
        final overlapText = _extractOverlap(currentChunk.toString(), chunkOverlap);
        currentChunk = StringBuffer();
        if (overlapText.isNotEmpty) {
          currentChunk.write('$overlapText ');
          currentTokens = countTokens(overlapText);
        } else {
          currentTokens = 0;
        }
      }

      if (currentChunk.isNotEmpty && !currentChunk.toString().endsWith('\n') && !currentChunk.toString().endsWith(' ')) {
        currentChunk.write(' ');
      }
      currentChunk.write(piece);
      currentTokens += pieceTokens;
    }

    if (currentChunk.isNotEmpty && currentChunk.toString().trim().isNotEmpty) {
      merged.add(currentChunk.toString().trim());
    }

    return merged;
  }

  String _extractOverlap(String text, int targetOverlapTokens) {
    final words = text.trim().split(RegExp(r'\s+'));
    if (words.length <= targetOverlapTokens) {
      return text;
    }
    return words.sublist(words.length - targetOverlapTokens).join(' ');
  }
}
