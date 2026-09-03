import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';
import 'package:kortex/src/features/decks/domain/logic/sm2_algorithm_engine.dart';
import 'package:kortex/src/features/ingestion/domain/entities/document_upload_entity.dart';
import 'package:kortex/src/features/ingestion/domain/entities/ocr_extraction_entity.dart';
import 'package:kortex/src/features/ingestion/domain/entities/processing_status.dart';
import 'package:kortex/src/features/ingestion/domain/repositories/ingestion_repository.dart';
import 'package:kortex/src/features/ingestion/domain/use_cases/generate_flashcards_from_doc_use_case.dart';
import 'package:kortex/src/features/ingestion/domain/use_cases/process_stem_ocr_use_case.dart';
import 'package:kortex/src/features/ingestion/domain/use_cases/upload_study_document_use_case.dart';
import 'package:mocktail/mocktail.dart';

class MockIngestionRepository extends Mock implements IngestionRepository {}

void main() {
  group(
    'E2E Ingestion to Flashcard Deck & SM-2 Queue Integration Test Suite',
    () {
      late MockIngestionRepository mockIngestionRepository;
      late UploadStudyDocumentUseCase uploadUseCase;
      late ProcessStemOcrUseCase ocrUseCase;
      late GenerateFlashcardsFromDocUseCase generateDeckUseCase;
      const sm2Engine = Sm2AlgorithmEngine();

      final testBytes = Uint8List.fromList([1, 2, 3, 4, 5]);

      final tUploadedDoc = DocumentUploadEntity(
        id: 'doc_999',
        userId: 'user_123',
        filename: 'Electrostatics_Notes.pdf',
        fileType: 'pdf',
        fileSizeBytes: 2048576,
        storagePath: 'documents/user_123/doc_999.pdf',
        contentHash: 'hash_abc_123',
        status: ProcessingStatus.completed,
        createdAt: DateTime(2026, 8, 31),
      );

      const tOcrSnippets = [
        OcrExtractionEntity(
          id: 'snip_1',
          documentId: 'doc_999',
          rawText: 'Coulomb Law states that F = k * (q1 * q2) / r^2',
          latexContent: r'F = k \frac{q_1 q_2}{r^2}',
          topic: 'Physics - Electrostatics',
          confidenceScore: 0.98,
        ),
      ];

      const tGeneratedDeck = DeckEntity(
        id: 'deck_physics_101',
        title: 'Electrostatics Core Mastery',
        subject: 'Physics',
        totalCards: 1,
        dueCards: 1,
        masteryRate: 0,
        category: 'STEM',
        cards: [
          FlashcardEntity(
            id: 'card_coulomb_1',
            deckId: 'deck_physics_101',
            front: 'What is the formula for Coulomb Law?',
            back: 'F = k * (q1 * q2) / r^2 where k is Coulomb constant.',
            backLatex: r'F = k \frac{q_1 q_2}{r^2}',
          ),
        ],
      );

      setUp(() {
        mockIngestionRepository = MockIngestionRepository();
        uploadUseCase = UploadStudyDocumentUseCase(mockIngestionRepository);
        ocrUseCase = ProcessStemOcrUseCase(mockIngestionRepository);
        generateDeckUseCase = GenerateFlashcardsFromDocUseCase(
          mockIngestionRepository,
        );
      });

      test(
        'Full Pipeline: Upload PDF -> OCR -> Deck -> Initial SM-2 Queue',
        () async {
          // 1. Upload PDF
          when(
            () => mockIngestionRepository.uploadDocument(
              filename: 'Electrostatics_Notes.pdf',
              fileType: 'pdf',
              fileBytes: testBytes,
              onProgress: any(named: 'onProgress'),
            ),
          ).thenAnswer((_) async => Right(tUploadedDoc));

          final uploadResult = await uploadUseCase(
            filename: 'Electrostatics_Notes.pdf',
            fileType: 'pdf',
            fileBytes: testBytes,
          );

          expect(uploadResult.isRight, isTrue);
          final doc =
              (uploadResult as Right<dynamic, DocumentUploadEntity>).value;
          expect(doc.id, equals('doc_999'));

          // 2. OCR STEM Extraction
          when(
            () => mockIngestionRepository.processStemOcr(
              documentId: doc.id,
              storagePath: doc.storagePath,
              fileType: doc.fileType,
            ),
          ).thenAnswer((_) async => const Right(tOcrSnippets));

          final ocrResult = await ocrUseCase(
            documentId: doc.id,
            storagePath: doc.storagePath,
            fileType: doc.fileType,
          );
          expect(ocrResult.isRight, isTrue);
          final snippets =
              (ocrResult as Right<dynamic, List<OcrExtractionEntity>>).value;
          expect(snippets.length, equals(1));
          expect(snippets.first.latexContent, contains('frac'));

          // 3. AI Flashcard Deck Generation
          when(
            () => mockIngestionRepository.generateFlashcardsFromDoc(
              documentId: doc.id,
              deckTitle: 'Electrostatics Core Mastery',
              subject: 'Physics',
              snippets: snippets,
            ),
          ).thenAnswer((_) async => const Right(tGeneratedDeck));

          final deckResult = await generateDeckUseCase(
            documentId: doc.id,
            deckTitle: 'Electrostatics Core Mastery',
            subject: 'Physics',
            snippets: snippets,
          );

          expect(deckResult.isRight, isTrue);
          final deck = (deckResult as Right<dynamic, DeckEntity>).value;
          expect(deck.cards.length, equals(1));
          expect(deck.dueCards, equals(1));

          // 4. Initial SM-2 Calculation on the generated flashcard
          final initialCard = deck.cards.first;
          final sm2Result = sm2Engine.calculate(
            quality: 5,
            previousInterval: initialCard.interval,
            previousRepetitions: initialCard.repetitions,
          );

          expect(sm2Result.nextInterval, equals(1));
          expect(sm2Result.newRepetitions, equals(1));
          expect(sm2Result.newEaseFactor, equals(2.6));
        },
      );
    },
  );
}
