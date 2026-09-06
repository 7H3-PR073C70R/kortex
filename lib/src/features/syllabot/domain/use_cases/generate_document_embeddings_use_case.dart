import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/ingestion/domain/entities/ocr_extraction_entity.dart';
import 'package:kortex/src/features/ingestion/domain/services/recursive_text_splitter.dart';
import 'package:kortex/src/features/syllabot/domain/repositories/rag_repository.dart';

/// Dispatches raw document text or extracted OCR snippets through a recursive
/// 500-token (50 overlap) text splitter to generate embeddings and index chunks into pgvector.
class GenerateDocumentEmbeddingsUseCase {
  const GenerateDocumentEmbeddingsUseCase(
    this._repository, {
    RecursiveTextSplitter? splitter,
  }) : _splitter = splitter ?? const RecursiveTextSplitter();

  final RagRepository _repository;
  final RecursiveTextSplitter _splitter;

  Future<Either<Failure, int>> call({
    required String documentId,
    String? rawText,
    List<OcrExtractionEntity>? snippets,
    List<TextChunk>? chunks,
    Map<String, dynamic>? metadata,
  }) async {
    List<TextChunk> effectiveChunks;

    if (chunks != null && chunks.isNotEmpty) {
      effectiveChunks = chunks;
    } else if (snippets != null && snippets.isNotEmpty) {
      effectiveChunks = _splitter.splitSnippets(
        snippets,
        baseMetadata: metadata,
      );
    } else if (rawText != null && rawText.trim().isNotEmpty) {
      effectiveChunks = _splitter.splitText(
        text: rawText,
        baseMetadata: metadata,
      );
    } else {
      effectiveChunks = const [];
    }

    final chunkPayloads = effectiveChunks.map((c) => c.toJson()).toList();

    return _repository.generateDocumentEmbeddings(
      documentId: documentId,
      rawText: rawText ?? (snippets?.map((s) => s.rawText).join('\n\n') ?? ''),
      chunks: chunkPayloads.isNotEmpty ? chunkPayloads : null,
      metadata: metadata,
    );
  }
}
