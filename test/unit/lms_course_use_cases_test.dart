import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/ingestion/data/data_sources/lms_import_data_source.dart';
import 'package:kortex/src/features/ingestion/data/services/document_parser_service.dart';
import 'package:kortex/src/features/ingestion/domain/entities/ocr_extraction_entity.dart';
import 'package:kortex/src/features/ingestion/domain/entities/processing_status.dart';
import 'package:kortex/src/features/ingestion/domain/repositories/lms_repository.dart';
import 'package:kortex/src/features/ingestion/domain/use_cases/fetch_lms_courses_use_case.dart';
import 'package:kortex/src/features/ingestion/domain/use_cases/fetch_user_documents_use_case.dart';
import 'package:kortex/src/features/ingestion/domain/use_cases/generate_flashcards_from_doc_use_case.dart';
import 'package:kortex/src/features/ingestion/domain/use_cases/import_lms_course_use_case.dart';
import 'package:kortex/src/features/ingestion/domain/use_cases/process_local_camera_ocr_use_case.dart';
import 'package:kortex/src/features/ingestion/domain/use_cases/process_stem_ocr_use_case.dart';
import 'package:kortex/src/features/ingestion/domain/use_cases/upload_study_document_use_case.dart';
import 'package:kortex/src/features/ingestion/presentation/bloc/ingestion_bloc.dart';
import 'package:kortex/src/features/ingestion/presentation/bloc/ingestion_event.dart';
import 'package:kortex/src/features/ingestion/presentation/bloc/ingestion_state.dart';
import 'package:mocktail/mocktail.dart';

class MockLmsRepository extends Mock implements LmsRepository {}

class MockUploadStudyDocumentUseCase extends Mock
    implements UploadStudyDocumentUseCase {}

class MockProcessStemOcrUseCase extends Mock implements ProcessStemOcrUseCase {}

class MockGenerateFlashcardsFromDocUseCase extends Mock
    implements GenerateFlashcardsFromDocUseCase {}

class MockFetchUserDocumentsUseCase extends Mock
    implements FetchUserDocumentsUseCase {}

class MockProcessLocalCameraOcrUseCase extends Mock
    implements ProcessLocalCameraOcrUseCase {}

void main() {
  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  late MockLmsRepository mockLmsRepository;
  late DocumentParserService documentParserService;
  late FetchLmsCoursesUseCase fetchLmsCoursesUseCase;
  late ImportLmsCourseUseCase importLmsCourseUseCase;

  setUp(() {
    mockLmsRepository = MockLmsRepository();
    documentParserService = const DocumentParserService();
    fetchLmsCoursesUseCase = FetchLmsCoursesUseCase(mockLmsRepository);
    importLmsCourseUseCase = ImportLmsCourseUseCase(
      mockLmsRepository,
      documentParserService,
    );
  });

  group('LMS Use Cases Test Suite', () {
    const testCourse = LmsCourse(
      id: 'course-123',
      name: 'Organic Chemistry II',
      section: 'CHM202',
      platform: 'google_classroom',
      description: 'Reaction mechanisms, stereochemistry, and synthesis.',
    );

    test('FetchLmsCoursesUseCase fetches courses from Google Classroom', () async {
      when(
        () => mockLmsRepository.fetchGoogleClassroomCourses(
          oauthToken: any(named: 'oauthToken'),
        ),
      ).thenAnswer((_) async => const Right([testCourse]));

      final result = await fetchLmsCoursesUseCase(
        platform: 'google_classroom',
        authToken: 'valid_oauth_token',
      );

      expect(result.isRight, isTrue);
      result.fold(
        (_) => fail('Should succeed'),
        (courses) {
          expect(courses.length, 1);
          expect(courses.first.name, 'Organic Chemistry II');
        },
      );
    });

    test('FetchLmsCoursesUseCase fetches courses from Canvas LMS', () async {
      const canvasCourse = LmsCourse(
        id: 'canvas-456',
        name: 'Linear Algebra',
        section: 'MTH250',
        platform: 'canvas',
      );

      when(
        () => mockLmsRepository.fetchCanvasCourses(
          canvasDomain: any(named: 'canvasDomain'),
          apiToken: any(named: 'apiToken'),
        ),
      ).thenAnswer((_) async => const Right([canvasCourse]));

      final result = await fetchLmsCoursesUseCase(
        platform: 'canvas',
        authToken: 'api_token_123',
        canvasDomain: 'myuniversity.instructure.com',
      );

      expect(result.isRight, isTrue);
      result.fold(
        (_) => fail('Should succeed'),
        (courses) {
          expect(courses.length, 1);
          expect(courses.first.platform, 'canvas');
        },
      );
    });

    test('ImportLmsCourseUseCase imports bundle and synthesizes flashcards', () async {
      final bundle = LmsImportBundle(
        course: testCourse,
        assignments: [
          LmsAssignment(
            id: 'assign-1',
            title: 'Aldol Condensation Problem Set',
            dueDate: DateTime.now().add(const Duration(days: 7)),
            maxPoints: 100,
            description:
                'Aldol Condensation is a key organic reaction forming beta-hydroxy aldehydes.',
          ),
        ],
        syllabusContent:
            'Aldol Condensation: The reaction between enolate ions and carbonyl compounds.\n'
            'Electrophilic Addition: Reaction where a pi bond is broken and two new sigma bonds are formed.',
      );

      when(
        () => mockLmsRepository.importCourse(
          platform: any(named: 'platform'),
          courseId: any(named: 'courseId'),
          authToken: any(named: 'authToken'),
          canvasDomain: any(named: 'canvasDomain'),
        ),
      ).thenAnswer((_) async => Right(bundle));

      final result = await importLmsCourseUseCase(
        platform: 'google_classroom',
        courseId: 'course-123',
        authToken: 'valid_oauth_token',
      );

      expect(result.isRight, isTrue);
      result.fold(
        (_) => fail('Should succeed'),
        (importResult) {
          expect(importResult.bundle.course.name, 'Organic Chemistry II');
          expect(importResult.snippets.isNotEmpty, isTrue);
          expect(
            importResult.snippets.any(
              (s) => s.rawText.contains('Aldol Condensation') ||
                  s.topic.contains('Aldol'),
            ),
            isTrue,
          );
        },
      );
    });
  });

  group('IngestionBloc Camera OCR & LMS Integration Test Suite', () {
    late MockUploadStudyDocumentUseCase mockUpload;
    late MockProcessStemOcrUseCase mockProcessOcr;
    late MockGenerateFlashcardsFromDocUseCase mockGenerateDeck;
    late MockFetchUserDocumentsUseCase mockFetchUserDocs;
    late MockProcessLocalCameraOcrUseCase mockCameraOcr;
    late IngestionBloc bloc;

    setUp(() {
      mockUpload = MockUploadStudyDocumentUseCase();
      mockProcessOcr = MockProcessStemOcrUseCase();
      mockGenerateDeck = MockGenerateFlashcardsFromDocUseCase();
      mockFetchUserDocs = MockFetchUserDocumentsUseCase();
      mockCameraOcr = MockProcessLocalCameraOcrUseCase();

      bloc = IngestionBloc(
        uploadUseCase: mockUpload,
        processOcrUseCase: mockProcessOcr,
        generateDeckUseCase: mockGenerateDeck,
        fetchUserDocsUseCase: mockFetchUserDocs,
        processCameraOcrUseCase: mockCameraOcr,
        fetchLmsCoursesUseCase: fetchLmsCoursesUseCase,
        importLmsCourseUseCase: importLmsCourseUseCase,
      );
    });

    tearDown(() async {
      await bloc.close();
    });

    test('ProcessCameraImageEvent processes image with on-device camera OCR', () async {
      const dummySnippet = OcrExtractionEntity(
        id: 'ocr_cam_1',
        documentId: 'doc_cam_1',
        topic: 'Newtonian Dynamics',
        rawText: 'Force equals mass multiplied by acceleration.',
      );

      when(
        () => mockCameraOcr(
          imageBytes: any(named: 'imageBytes'),
          documentId: any(named: 'documentId'),
          imagePath: any(named: 'imagePath'),
          isOnline: any(named: 'isOnline'),
        ),
      ).thenAnswer((_) async => const Right([dummySnippet]));

      final expectedStates = <ProcessingStatus>[];
      final subscription = bloc.stream.listen((state) {
        expectedStates.add(state.status);
      });

      bloc.add(
        ProcessCameraImageEvent(
          filename: 'textbook_snap.jpg',
          imageBytes: Uint8List.fromList([1, 2, 3, 4]),
        ),
      );

      await expectLater(
        bloc.stream,
        emitsThrough(
          predicate<IngestionState>(
            (state) =>
                state.status == ProcessingStatus.completed &&
                state.snippets.isNotEmpty &&
                state.snippets.first.topic == 'Newtonian Dynamics',
          ),
        ),
      );

      await subscription.cancel();
    });

    test('FetchLmsCoursesEvent updates state with fetched courses', () async {
      const course = LmsCourse(
        id: 'gc-101',
        name: 'Biochemistry 101',
        section: 'BIO101',
        platform: 'google_classroom',
      );

      when(
        () => mockLmsRepository.fetchGoogleClassroomCourses(
          oauthToken: any(named: 'oauthToken'),
        ),
      ).thenAnswer((_) async => const Right([course]));

      bloc.add(
        const FetchLmsCoursesEvent(
          platform: 'google_classroom',
          authToken: 'token_abc',
        ),
      );

      await expectLater(
        bloc.stream,
        emitsThrough(
          predicate<IngestionState>(
            (state) =>
                state.lmsCourses.isNotEmpty &&
                state.lmsCourses.first.name == 'Biochemistry 101',
          ),
        ),
      );
    });
  });
}
