import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/ingestion/data/data_sources/lms_import_data_source.dart';
import 'package:kortex/src/features/ingestion/data/services/document_parser_service.dart';
import 'package:kortex/src/features/ingestion/domain/entities/ocr_extraction_entity.dart';
import 'package:kortex/src/features/ingestion/domain/repositories/lms_repository.dart';

class LmsImportResult {
  const LmsImportResult({
    required this.bundle,
    required this.snippets,
  });

  final LmsImportBundle bundle;
  final List<OcrExtractionEntity> snippets;
}

class ImportLmsCourseUseCase {
  const ImportLmsCourseUseCase(
    this._repository,
    this._parserService,
  );

  final LmsRepository _repository;
  final DocumentParserService _parserService;

  Future<Either<Failure, LmsImportResult>> call({
    required String platform,
    required String courseId,
    required String authToken,
    String? canvasDomain,
  }) async {
    final result = await _repository.importCourse(
      platform: platform,
      courseId: courseId,
      authToken: authToken,
      canvasDomain: canvasDomain,
    );

    return result.fold(
      Left.new,
      (bundle) {
        final buffer = StringBuffer()
          ..writeln('# ${bundle.course.name} (${bundle.course.section})');

        if (bundle.course.description != null &&
            bundle.course.description!.isNotEmpty) {
          buffer.writeln(bundle.course.description);
        }
        buffer
          ..writeln()
          ..writeln(bundle.syllabusContent)
          ..writeln();

        for (final assignment in bundle.assignments) {
          buffer.writeln('Assignment: ${assignment.title}');
          if (assignment.description != null) {
            buffer.writeln(assignment.description);
          }
          buffer.writeln();
        }

        final docId = 'lms_${bundle.course.platform}_${bundle.course.id}';
        final snippetModels = _parserService.synthesizeSnippetsFromDocument(
          documentId: docId,
          fullText: buffer.toString(),
          filename: '${bundle.course.name}.txt',
        );

        final entitySnippets = snippetModels.map((m) => m.toEntity()).toList();

        return Right(
          LmsImportResult(
            bundle: bundle,
            snippets: entitySnippets,
          ),
        );
      },
    );
  }
}
