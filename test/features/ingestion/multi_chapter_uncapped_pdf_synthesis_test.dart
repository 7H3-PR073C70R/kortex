import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/ingestion/data/services/document_parser_service.dart';

void main() {
  const service = DocumentParserService();

  group('Multi-Chapter Uncapped Document Parsing Suite', () {
    test('parses entire multi-chapter book without truncation or artificial card caps', () {
      // Simulate a 500+ page textbook with 15 distinct academic chapters
      final bookBuffer = StringBuffer();

      for (var chapter = 1; chapter <= 15; chapter++) {
        bookBuffer
          ..writeln('Chapter $chapter: Advanced Principles of Domain Architecture $chapter')
          ..writeln('Section $chapter.1 Core Theoretical Foundation')
          ..writeln(
            'The primary operational foundation of Chapter $chapter defines how systemic models '
            'integrate boundary conditions with empirical observations. Every system under Chapter $chapter '
            'must satisfy the equilibrium relation and conserve energy states across all intervals.\n',
          )
          ..writeln('Section $chapter.2 Mathematical Formulations and Governing Rules')
          ..writeln(
            'Rule $chapter.2.1: The primary governance criterion specifies that the coefficient of determination '
            'R^2 must exceed 0.95 under standard testing protocols. All anomalous deviations must be recorded '
            'and cataloged in the diagnostic ledger.\n',
          )
          ..writeln('Section $chapter.3 Execution Framework and Checklist')
          ..writeln(
            'Step 1: Calibrate telemetry sensors before testing.\n'
            'Step 2: Apply dynamic frequency sampling at 100Hz.\n'
            'Step 3: Verify boundary limits and log experimental outcomes.\n',
          );
      }

      final fullBookText = bookBuffer.toString();

      // Synthesize snippets using DocumentParserService
      final snippets = service.synthesizeSnippetsFromDocument(
        documentId: 'doc_textbook_545_pages',
        fullText: fullBookText,
        filename: 'Biomedical_Engineering_545_Pages.pdf',
      );

      // Verify that flashcards are NOT capped at 18 or 22 or 30
      expect(
        snippets.length,
        greaterThan(30),
        reason: 'Flashcards should not be artificially capped at 18, 22, or 30',
      );

      // Verify that every single chapter from Chapter 1 through Chapter 15 is represented
      for (var chapter = 1; chapter <= 15; chapter++) {
        final hasChapterCard = snippets.any(
          (s) =>
              s.topic.toLowerCase().contains('$chapter') ||
              s.rawText.toLowerCase().contains('chapter $chapter') ||
              s.rawText.toLowerCase().contains('domain architecture $chapter'),
        );
        expect(
          hasChapterCard,
          isTrue,
          reason: 'Chapter $chapter must be covered in generated flashcards, not discarded',
        );
      }
    });

    test('retains all semantic sections in massive continuous text without headers', () {
      // Simulate 50 continuous academic paragraphs lacking formal chapter headers
      final buffer = StringBuffer();
      for (var i = 1; i <= 40; i++) {
        buffer.writeln(
          'Concept $i focuses on distributed synchronization protocol $i. '
          'Nodes in cluster $i exchange heartbeat beacons every 50 milliseconds. '
          'If a quorum failure occurs in group $i, the consensus leader triggers an automated failover sequence.\n',
        );
      }

      final text = buffer.toString();
      final snippets = service.synthesizeSnippetsFromDocument(
        documentId: 'doc_continuous_prose',
        fullText: text,
        filename: 'Distributed_Systems.pdf',
      );

      // Uncapped cards across the whole document
      expect(snippets.length, greaterThanOrEqualTo(20));

      // Ensure beginning, middle, and end concepts are present
      expect(
        snippets.any((s) => s.rawText.contains('cluster 1') || s.topic.contains('1')),
        isTrue,
        reason: 'Beginning of document must be covered',
      );
      expect(
        snippets.any((s) => s.rawText.contains('cluster 20') || s.topic.contains('20')),
        isTrue,
        reason: 'Middle of document must be covered',
      );
      expect(
        snippets.any((s) => s.rawText.contains('cluster 40') || s.topic.contains('40')),
        isTrue,
        reason: 'End of document must be covered',
      );
    });
  });
}
