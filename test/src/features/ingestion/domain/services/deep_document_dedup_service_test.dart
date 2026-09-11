import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/features/ingestion/domain/entities/document_upload_entity.dart';
import 'package:kortex/src/features/ingestion/domain/entities/processing_status.dart';
import 'package:kortex/src/features/ingestion/domain/services/deep_document_dedup_service.dart';
import 'package:mocktail/mocktail.dart';

class MockLocalStorageService extends Mock implements LocalStorageService {}

void main() {
  late MockLocalStorageService mockStorage;
  late DeepDocumentDedupService service;

  setUp(() {
    mockStorage = MockLocalStorageService();
    service = DeepDocumentDedupService(storage: mockStorage);
    when(() => mockStorage.savePreference(
          key: any(named: 'key'),
          data: any(named: 'data'),
        )).thenAnswer((_) async {});
  });

  group('DeepDocumentDedupService', () {
    test('Identical contentHash immediately returns true', () {
      final bytes = Uint8List.fromList(utf8.encode('Hello World Lecture Notes'));
      const hash = 'abc_123_hash';
      final existingDoc = DocumentUploadEntity(
        id: 'doc_1',
        userId: 'user_1',
        filename: 'Different_Name.pdf',
        fileType: 'pdf',
        fileSizeBytes: bytes.length,
        storagePath: 'docs/doc_1.pdf',
        contentHash: hash,
        status: ProcessingStatus.completed,
        createdAt: DateTime.now(),
      );

      final isSame = service.isSameDocument(
        incomingBytes: bytes,
        incomingFileType: 'pdf',
        incomingContentHash: hash,
        existingDoc: existingDoc,
      );

      expect(isSame, isTrue);
    });

    test('Different page counts definitively reject deduplication', () {
      final bytes = Uint8List.fromList(utf8.encode('Page 1 Content\nPage 2 Content'));
      const incomingHash = 'hash_new';
      const existingHash = 'hash_existing';

      // Mock cached fingerprint for existing doc with 5 pages
      const existingFingerprint = DocumentFingerprint(
        contentHash: existingHash,
        pageCount: 5,
        sampledPages: {0: 'introduction to physics', 2: 'thermodynamics'},
        totalBytes: 5000,
      );

      when(() => mockStorage.getPreference(key: 'doc_fingerprint_$existingHash'))
          .thenReturn(jsonEncode(existingFingerprint.toJson()));

      final existingDoc = DocumentUploadEntity(
        id: 'doc_existing',
        userId: 'user_1',
        filename: 'Physics.pdf',
        fileType: 'pdf',
        fileSizeBytes: 5000,
        storagePath: 'docs/physics.pdf',
        contentHash: existingHash,
        status: ProcessingStatus.completed,
        createdAt: DateTime.now(),
      );

      final isSame = service.isSameDocument(
        incomingBytes: bytes,
        incomingFileType: 'txt', // Generates ~1 page
        incomingContentHash: incomingHash,
        existingDoc: existingDoc,
      );

      expect(isSame, isFalse);
    });

    test('Identical page count and sampled content confirm document is the same', () {
      final text = List.generate(35, (i) => 'Line $i of general chemistry lecture notes').join('\n');
      final bytes = Uint8List.fromList(utf8.encode(text));
      final incomingHash = DeepDocumentDedupService.computeSha256(bytes);
      const existingHash = 'hash_cached_chem';

      // Pre-extract incoming fingerprint so we know page count & sample
      final incomingFingerprint = service.extractFingerprint(
        bytes: bytes,
        fileType: 'txt',
        contentHash: incomingHash,
      );

      // Existing doc has same page count and same sampled page text
      final existingFingerprint = DocumentFingerprint(
        contentHash: existingHash,
        pageCount: incomingFingerprint.pageCount,
        sampledPages: incomingFingerprint.sampledPages,
        totalBytes: bytes.length,
      );

      when(() => mockStorage.getPreference(key: 'doc_fingerprint_$existingHash'))
          .thenReturn(jsonEncode(existingFingerprint.toJson()));

      final existingDoc = DocumentUploadEntity(
        id: 'doc_chem',
        userId: 'user_1',
        filename: 'Chemistry_101.pdf',
        fileType: 'txt',
        fileSizeBytes: bytes.length,
        storagePath: 'docs/chem.txt',
        contentHash: existingHash,
        status: ProcessingStatus.completed,
        createdAt: DateTime.now(),
      );

      final isSame = service.isSameDocument(
        incomingBytes: bytes,
        incomingFileType: 'txt',
        incomingContentHash: incomingHash,
        existingDoc: existingDoc,
      );

      expect(isSame, isTrue);
    });

    test('calculateTextSimilarity accurately measures token overlap', () {
      const a = 'Cellular mitosis consists of prophase, metaphase, anaphase, and telophase.';
      const b = 'Cellular mitosis consists of prophase, metaphase, anaphase, telophase with cytokinesis.';
      const c = 'Quantum mechanics Schrödinger equation wave function collapse.';

      final similarityAB = service.calculateTextSimilarity(a, b);
      final similarityAC = service.calculateTextSimilarity(a, c);

      expect(similarityAB, greaterThanOrEqualTo(0.70));
      expect(similarityAC, lessThan(0.15));
    });
  });
}
