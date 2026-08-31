import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

class StreamingFlashcard {
  const StreamingFlashcard({
    required this.id,
    required this.deckId,
    required this.index,
    required this.front,
    required this.back,
    required this.isImmediate,
  });

  factory StreamingFlashcard.fromJson(Map<String, dynamic> json) {
    return StreamingFlashcard(
      id: json['id'] as String,
      deckId: json['deckId'] as String,
      index: json['index'] as int,
      front: json['front'] as String,
      back: json['back'] as String,
      isImmediate: json['isImmediate'] as bool? ?? false,
    );
  }

  final String id;
  final String deckId;
  final int index;
  final String front;
  final String back;
  final bool isImmediate;
}

/// Simulated SSE flashcard stream source emitting chunks.
Stream<String> createMockFlashcardSseStream({
  required String deckId,
  required int totalCards,
}) async* {
  // Start event
  yield 'event: start\n'
      'data: {"status":"streaming","deckId":"$deckId",'
      ' "targetCount":$totalCards}\n\n';

  // First 3 immediate flashcards (sub-1s generation)
  for (var i = 1; i <= 3; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final cardJson = jsonEncode({
      'id': 'card_${deckId}_$i',
      'deckId': deckId,
      'index': i,
      'front': 'Immediate Card Front $i: Calculus Fundamental Theorem',
      'back': r'$$\int_a^b f^\prime(x) dx = f(b) - f(a)$$',
      'isImmediate': true,
    });
    yield 'event: card\n'
        'data: {"card":$cardJson,"isInitialBatch":true,'
        ' "currentCount":$i}\n\n';
  }

  // Remaining background flashcards
  for (var i = 4; i <= totalCards; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 40));
    final cardJson = jsonEncode({
      'id': 'card_${deckId}_$i',
      'deckId': deckId,
      'index': i,
      'front': 'Background Card Front $i: Matrix Eigenvalues',
      'back': r'$$\det(A - \lambda I) = 0$$',
      'isImmediate': false,
    });
    yield 'event: card\n'
        'data: {"card":$cardJson,"isInitialBatch":false,'
        ' "currentCount":$i}\n\n';
  }

  yield 'event: done\n'
      'data: {"status":"completed","deckId":"$deckId",'
      ' "totalCards":$totalCards}\n\n';
}

void main() {
  group('Sub-10-Second Time-to-Value Streaming Killer Loop', () {
    test(
      'Delivers first 3 flashcards in < 5 seconds and streams remainder',
      () async {
        final stopwatch = Stopwatch()..start();
        const deckId = 'test_deck_777';
        const totalCards = 10;

        final sseStream = createMockFlashcardSseStream(
          deckId: deckId,
          totalCards: totalCards,
        );

        final receivedCards = <StreamingFlashcard>[];
        var initialBatchTimeMs = 0;
        var completed = false;

        final completer = Completer<void>();

        sseStream.listen((chunk) {
          final lines = chunk.split('\n');
          for (final line in lines) {
            if (line.startsWith('data:')) {
              final jsonStr = line.replaceFirst('data:', '').trim();
              if (jsonStr.isEmpty) continue;

              final dynamic parsed = jsonDecode(jsonStr);
              if (parsed is Map<String, dynamic>) {
                if (parsed.containsKey('card')) {
                  final card = StreamingFlashcard.fromJson(
                    parsed['card'] as Map<String, dynamic>,
                  );
                  receivedCards.add(card);

                  if (receivedCards.length == 3) {
                    initialBatchTimeMs = stopwatch.elapsedMilliseconds;
                  }
                }

                if (parsed['status'] == 'completed') {
                  completed = true;
                  completer.complete();
                }
              }
            }
          }
        });

        await completer.future;
        stopwatch.stop();

        // 1. Assert killer loop sub-5-second constraint
        expect(
          initialBatchTimeMs,
          lessThan(5000),
          reason: 'First 3 flashcards must be delivered in under 5 seconds',
        );

        // 2. Assert all 3 initial cards are marked as immediate
        expect(receivedCards.take(3).every((c) => c.isImmediate), isTrue);

        // 3. Assert full deck completed streaming
        expect(receivedCards.length, equals(totalCards));
        expect(completed, isTrue);

        // Access properties to verify getters
        for (final c in receivedCards) {
          expect(c.id, isNotEmpty);
          expect(c.deckId, equals(deckId));
          expect(c.index, greaterThan(0));
          expect(c.front, isNotEmpty);
        }
      },
    );

    test(
      'Parses LaTeX mathematical formulas inside streamed cards correctly',
      () async {
        const deckId = 'latex_deck_1';
        final sseStream = createMockFlashcardSseStream(
          deckId: deckId,
          totalCards: 3,
        );

        final receivedCards = <StreamingFlashcard>[];
        await for (final chunk in sseStream) {
          if (chunk.contains('event: card')) {
            final dataLine = chunk
                .split('\n')
                .firstWhere((l) => l.startsWith('data:'))
                .replaceFirst('data:', '')
                .trim();
            final parsed = jsonDecode(dataLine) as Map<String, dynamic>;
            receivedCards.add(
              StreamingFlashcard.fromJson(
                parsed['card'] as Map<String, dynamic>,
              ),
            );
          }
        }

        expect(receivedCards.length, equals(3));
        expect(receivedCards.first.back, contains(r'\int_a^b'));
      },
    );
  });
}
