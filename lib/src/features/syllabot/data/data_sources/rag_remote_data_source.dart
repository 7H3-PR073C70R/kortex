import 'package:kortex/src/features/syllabot/data/models/document_chunk_model.dart';

abstract class RagRemoteDataSource {
  Future<List<DocumentChunkModel>> queryDocumentContext({
    required String query,
    required double matchThreshold,
    required int matchCount,
    String? documentId,
  });

  Future<int> generateDocumentEmbeddings({
    required String documentId,
    String? rawText,
    List<Map<String, dynamic>>? chunks,
    Map<String, dynamic>? metadata,
  });
}
