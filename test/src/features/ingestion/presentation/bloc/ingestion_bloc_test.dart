import 'dart:typed_data';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/ingestion/domain/entities/document_upload_entity.dart';
import 'package:kortex/src/features/ingestion/domain/entities/ocr_extraction_entity.dart';
import 'package:kortex/src/features/ingestion/domain/entities/processing_status.dart';
import 'package:kortex/src/features/ingestion/domain/use_cases/fetch_user_documents_use_case.dart';
import 'package:kortex/src/features/ingestion/domain/use_cases/generate_flashcards_from_doc_use_case.dart';
import 'package:kortex/src/features/ingestion/domain/use_cases/process_stem_ocr_use_case.dart';
import 'package:kortex/src/features/ingestion/domain/use_cases/upload_study_document_use_case.dart';
import 'package:kortex/src/features/ingestion/presentation/bloc/ingestion_bloc.dart';
import 'package:kortex/src/features/ingestion/presentation/bloc/ingestion_event.dart';
import 'package:kortex/src/features/ingestion/presentation/bloc/ingestion_state.dart';
import 'package:mocktail/mocktail.dart';

class MockUploadStudyDocumentUseCase extends Mock
    implements UploadStudyDocumentUseCase {}

class MockProcessStemOcrUseCase extends Mock implements ProcessStemOcrUseCase {}

class MockGenerateFlashcardsFromDocUseCase extends Mock
    implements GenerateFlashcardsFromDocUseCase {}

class MockFetchUserDocumentsUseCase extends Mock
    implements FetchUserDocumentsUseCase {}

void main() {
  late MockUploadStudyDocumentUseCase mockUpload;
  late MockProcessStemOcrUseCase mockProcessOcr;
  late MockGenerateFlashcardsFromDocUseCase mockGenerateDeck;
  late MockFetchUserDocumentsUseCase mockFetchUserDocs;
  late IngestionBloc bloc;

  final testDoc = DocumentUploadEntity(
    id: 'doc_123',
    userId: 'user_abc',
    filename: 'calculus.pdf',
    fileType: 'pdf',
    fileSizeBytes: 1024,
    storagePath: 'doc_123.pdf',
    contentHash: 'hash_123',
    status: ProcessingStatus.uploading,
    createdAt: DateTime(2026, 8, 31),
  );

  const testSnippet = OcrExtractionEntity(
    id: 'snippet_1',
    documentId: 'doc_123',
    rawText: 'Fourier transform equation',
    latexContent: r'$$\hat{f}(\xi) = \int f(x) e^{-2\pi i x \xi} dx$$',
    topic: 'Calculus',
  );

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(const <OcrExtractionEntity>[]);
  });

  setUp(() {
    mockUpload = MockUploadStudyDocumentUseCase();
    mockProcessOcr = MockProcessStemOcrUseCase();
    mockGenerateDeck = MockGenerateFlashcardsFromDocUseCase();
    mockFetchUserDocs = MockFetchUserDocumentsUseCase();

    bloc = IngestionBloc(
      uploadUseCase: mockUpload,
      processOcrUseCase: mockProcessOcr,
      generateDeckUseCase: mockGenerateDeck,
      fetchUserDocsUseCase: mockFetchUserDocs,
    );
  });

  tearDown(() async {
    await bloc.close();
  });

  group('IngestionBloc', () {
    test('initial state is idle with 0.0 progress', () {
      expect(bloc.state.status, ProcessingStatus.idle);
      expect(bloc.state.uploadProgress, 0.0);
      expect(bloc.state.snippets, isEmpty);
    });

    blocTest<IngestionBloc, IngestionState>(
      'emits uploading -> completed when upload and OCR succeed',
      build: () {
        when(
          () => mockUpload.call(
            filename: any(named: 'filename'),
            fileType: any(named: 'fileType'),
            fileBytes: any(named: 'fileBytes'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer((_) async => Right(testDoc));

        when(
          () => mockProcessOcr.call(
            documentId: any(named: 'documentId'),
            storagePath: any(named: 'storagePath'),
            fileType: any(named: 'fileType'),
          ),
        ).thenAnswer((_) async => const Right([testSnippet]));

        return bloc;
      },
      act: (bloc) => bloc.add(
        PickAndUploadFileEvent(
          filename: 'calculus.pdf',
          fileType: 'pdf',
          fileBytes: Uint8List.fromList([1, 2, 3]),
        ),
      ),
      expect: () => [
        const IngestionState(
          status: ProcessingStatus.uploading,
          uploadProgress: 0.1,
        ),
        IngestionState(
          status: ProcessingStatus.uploading,
          uploadProgress: 1,
          currentDocument: testDoc,
        ),
        IngestionState(
          status: ProcessingStatus.parsingOcr,
          uploadProgress: 1,
          currentDocument: testDoc,
        ),
        IngestionState(
          status: ProcessingStatus.completed,
          uploadProgress: 1,
          currentDocument: testDoc,
          snippets: const [testSnippet],
        ),
      ],
    );

    blocTest<IngestionBloc, IngestionState>(
      'emits failed state when upload fails',
      build: () {
        when(
          () => mockUpload.call(
            filename: any(named: 'filename'),
            fileType: any(named: 'fileType'),
            fileBytes: any(named: 'fileBytes'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer(
          (_) async => const Left(ServerFailure(message: 'Storage full')),
        );

        return bloc;
      },
      act: (bloc) => bloc.add(
        PickAndUploadFileEvent(
          filename: 'calculus.pdf',
          fileType: 'pdf',
          fileBytes: Uint8List.fromList([1, 2, 3]),
        ),
      ),
      expect: () => [
        const IngestionState(
          status: ProcessingStatus.uploading,
          uploadProgress: 0.1,
        ),
        const IngestionState(
          status: ProcessingStatus.failed,
          uploadProgress: 0.1,
          errorMessage: 'Storage full',
        ),
      ],
    );

    blocTest<IngestionBloc, IngestionState>(
      'updates snippet content in state',
      build: () => bloc,
      seed: () => const IngestionState(
        status: ProcessingStatus.completed,
        snippets: [testSnippet],
      ),
      act: (bloc) => bloc.add(
        const UpdateSnippetContentEvent(
          snippetId: 'snippet_1',
          updatedRawText: 'Updated text',
          updatedTopic: 'Advanced Analysis',
        ),
      ),
      expect: () => [
        IngestionState(
          status: ProcessingStatus.completed,
          snippets: [
            testSnippet.copyWith(
              rawText: 'Updated text',
              topic: 'Advanced Analysis',
            ),
          ],
        ),
      ],
    );

    blocTest<IngestionBloc, IngestionState>(
      'generates flashcards deck successfully',
      build: () {
        const deck = DeckEntity(
          id: 'deck_123',
          title: 'Calculus Mastery',
          subject: 'STEM',
          totalCards: 1,
          dueCards: 1,
          masteryRate: 0,
          category: 'STEM Ingestion',
          description: 'Auto-synthesized',
        );

        when(
          () => mockGenerateDeck.call(
            documentId: any(named: 'documentId'),
            deckTitle: any(named: 'deckTitle'),
            subject: any(named: 'subject'),
            snippets: any(named: 'snippets'),
          ),
        ).thenAnswer((_) async => const Right(deck));

        return bloc;
      },
      act: (bloc) => bloc.add(
        const GenerateFlashcardsFromSnippetsEvent(
          documentId: 'doc_123',
          deckTitle: 'Calculus Mastery',
          subject: 'STEM',
          snippets: [testSnippet],
        ),
      ),
      expect: () => [
        const IngestionState(status: ProcessingStatus.generatingCards),
        isA<IngestionState>()
            .having((s) => s.status, 'status', ProcessingStatus.completed)
            .having(
              (s) => s.generatedDeck?.title,
              'deckTitle',
              'Calculus Mastery',
            ),
      ],
    );
  });
}
