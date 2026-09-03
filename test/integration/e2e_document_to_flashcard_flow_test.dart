import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';
import 'package:kortex/src/features/decks/domain/entities/fsrs_card_state.dart';
import 'package:kortex/src/features/decks/domain/logic/fsrs_algorithm_engine.dart';
import 'package:kortex/src/features/decks/domain/logic/scheduler_factory.dart';
import 'package:kortex/src/features/ingestion/domain/entities/document_upload_entity.dart';
import 'package:kortex/src/features/ingestion/domain/entities/ocr_extraction_entity.dart';
import 'package:kortex/src/features/ingestion/domain/entities/processing_status.dart';
import 'package:kortex/src/features/ingestion/domain/repositories/ingestion_repository.dart';
import 'package:kortex/src/features/ingestion/domain/use_cases/generate_flashcards_from_doc_use_case.dart';
import 'package:kortex/src/features/ingestion/domain/use_cases/process_stem_ocr_use_case.dart';
import 'package:kortex/src/features/ingestion/domain/use_cases/upload_study_document_use_case.dart';
import 'package:kortex/src/features/syllabot/domain/entities/document_chunk_entity.dart';
import 'package:kortex/src/features/syllabot/domain/repositories/rag_repository.dart';
import 'package:kortex/src/features/syllabot/domain/use_cases/query_document_context_use_case.dart';
import 'package:mocktail/mocktail.dart';

class MockIngestionRepository extends Mock implements IngestionRepository {}

class MockRagRepository extends Mock implements RagRepository {}

void main() {
  group(
    'E2E Document to Vector Chunk & Flashcard Scheduler Flow Test Suite',
    () {
      late MockIngestionRepository mockIngestionRepo;
      late MockRagRepository mockRagRepo;
      late UploadStudyDocumentUseCase uploadUseCase;
      late ProcessStemOcrUseCase ocrUseCase;
      late GenerateFlashcardsFromDocUseCase generateDeckUseCase;
      late QueryDocumentContextUseCase ragQueryUseCase;
      late SchedulerFactory schedulerFactory;

      final testBytes = Uint8List.fromList([10, 20, 30, 40]);

      final tDoc = DocumentUploadEntity(
        id: 'doc-chemistry-101',
        userId: 'user-789',
        filename: 'Thermodynamics_Lecture.pdf',
        fileType: 'pdf',
        fileSizeBytes: 1048576,
        storagePath: 'documents/user-789/thermo.pdf',
        contentHash: 'hash_thermo_789',
        status: ProcessingStatus.completed,
        createdAt: DateTime(2026, 8, 31),
      );

      const tOcrResults = [
        OcrExtractionEntity(
          id: 'ocr-1',
          documentId: 'doc-chemistry-101',
          rawText:
              'Gibbs Free Energy is given by delta G = delta H - T delta S',
          latexContent: r'\Delta G = \Delta H - T\Delta S',
          topic: 'Chemical Thermodynamics',
          confidenceScore: 0.99,
        ),
      ];

      const tGeneratedDeck = DeckEntity(
        id: 'deck-thermo-01',
        title: 'Thermodynamics Mastery',
        subject: 'Chemistry',
        totalCards: 1,
        dueCards: 1,
        masteryRate: 0,
        category: 'STEM',
        cards: [
          FlashcardEntity(
            id: 'card-1',
            deckId: 'deck-thermo-01',
            front: 'What is Gibbs Free Energy equation?',
            back: r'\Delta G = \Delta H - T\Delta S',
          ),
        ],
      );

      const tChunks = [
        DocumentChunkEntity(
          id: 'chunk-1',
          documentId: 'doc-chemistry-101',
          content: r'Thermodynamics: \Delta G = \Delta H - T\Delta S',
          metadata: {'page': 1, 'subject': 'Chemistry'},
          similarityScore: 0.95,
        ),
      ];

      setUp(() {
        mockIngestionRepo = MockIngestionRepository();
        mockRagRepo = MockRagRepository();
        uploadUseCase = UploadStudyDocumentUseCase(mockIngestionRepo);
        ocrUseCase = ProcessStemOcrUseCase(mockIngestionRepo);
        generateDeckUseCase = GenerateFlashcardsFromDocUseCase(
          mockIngestionRepo,
        );
        ragQueryUseCase = QueryDocumentContextUseCase(mockRagRepo);
        schedulerFactory = SchedulerFactory(
          fsrsEngine: const FsrsAlgorithmEngine(),
        );
      });

      test(
        'Upload -> OCR -> RAG Semantic Context -> Deck Scheduler Review',
        () async {
          // 1. Upload Document
          when(
            () => mockIngestionRepo.uploadDocument(
              fileBytes: testBytes,
              filename: 'Thermodynamics_Lecture.pdf',
              fileType: 'pdf',
            ),
          ).thenAnswer((_) async => Right(tDoc));

          final uploadResult = await uploadUseCase(
            fileBytes: testBytes,
            filename: 'Thermodynamics_Lecture.pdf',
            fileType: 'pdf',
          );
          expect(uploadResult.isRight, isTrue);

          // 2. Perform OCR Extraction
          when(
            () => mockIngestionRepo.processStemOcr(
              documentId: 'doc-chemistry-101',
              storagePath: 'documents/user-789/thermo.pdf',
              fileType: 'pdf',
            ),
          ).thenAnswer((_) async => const Right(tOcrResults));

          final ocrResult = await ocrUseCase(
            documentId: 'doc-chemistry-101',
            storagePath: 'documents/user-789/thermo.pdf',
            fileType: 'pdf',
          );
          expect(ocrResult.isRight, isTrue);
          ocrResult.fold(
            (l) => fail('Expected OCR success'),
            (snippets) =>
                expect(snippets.first.latexContent, contains(r'\Delta G')),
          );

          // 3. Query RAG Vector Search for Document Context
          when(
            () => mockRagRepo.queryDocumentContext(
              query: 'Gibbs Free Energy equation',
              documentId: 'doc-chemistry-101',
              matchThreshold: 0.85,
            ),
          ).thenAnswer((_) async => const Right(tChunks));

          final ragResult = await ragQueryUseCase(
            query: 'Gibbs Free Energy equation',
            documentId: 'doc-chemistry-101',
            matchThreshold: 0.85,
          );
          expect(ragResult.isRight, isTrue);
          ragResult.fold(
            (l) => fail('Expected RAG success'),
            (chunks) => expect(chunks.first.similarityScore, equals(0.95)),
          );

          // 4. Generate Deck & Schedule Review with FSRS
          when(
            () => mockIngestionRepo.generateFlashcardsFromDoc(
              documentId: 'doc-chemistry-101',
              deckTitle: 'Thermodynamics Mastery',
              subject: 'Chemistry',
              snippets: tOcrResults,
            ),
          ).thenAnswer((_) async => const Right(tGeneratedDeck));

          final deckResult = await generateDeckUseCase(
            documentId: 'doc-chemistry-101',
            deckTitle: 'Thermodynamics Mastery',
            subject: 'Chemistry',
            snippets: tOcrResults,
          );
          expect(deckResult.isRight, isTrue);
          deckResult.fold(
            (l) => fail('Expected Deck success'),
            (deck) => expect(deck.cards.length, equals(1)),
          );

          // 5. Compute FSRS Review Transition for newly generated card
          final initialFsrs = FsrsCardState.initial();
          final reviewResult = schedulerFactory.calculate(
            algorithm: SpacedRepetitionAlgorithm.fsrs,
            rating: 3, // Good
            previousFsrsState: initialFsrs,
          );

          expect(
            reviewResult.algorithm,
            equals(SpacedRepetitionAlgorithm.fsrs),
          );
          expect(reviewResult.fsrsState?.stability, equals(2.4));
          expect(reviewResult.nextIntervalDays, greaterThanOrEqualTo(2));
        },
      );
    },
  );
}
