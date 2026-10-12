import 'dart:async';

import 'package:kortex/src/features/syllabot/presentation/widgets/text_to_speech_handler.dart';

/// Coordinates incremental LLM text streaming chunks with low-latency TTS playback.
class VoiceStreamSpeechCoordinator {
  static Future<void> processStream({
    required Stream<String> stream,
    required TextToSpeechHandler ttsHandler,
    required bool isMuted,
    required bool Function() isCancelled,
    required void Function() onFirstSentenceSpoken,
    required void Function(String chunk) onChunkReceived,
  }) async {
    final timedStream = stream.timeout(
      const Duration(seconds: 180),
      onTimeout: (sink) {
        sink.addError('Connection or inference timeout. Please try again.');
      },
    );

    final sentenceDelimiters = RegExp(r'([.!?\n]+)\s*');
    final clauseDelimiters = RegExp(r'([,;:—–]+)\s*');
    final accumulatedBuffer = StringBuffer();
    var firstSentenceSpoken = false;

    await for (final chunk in timedStream) {
      if (isCancelled()) break;
      accumulatedBuffer.write(chunk);
      var accumulated = accumulatedBuffer.toString();

      if (!firstSentenceSpoken) {
        final sentenceMatch = sentenceDelimiters.firstMatch(accumulated);
        final clauseMatch = clauseDelimiters.firstMatch(accumulated);
        final words = accumulated.trim().split(RegExp(r'\s+'));
        final wordCount = words.length;

        int? splitIndex;

        if (sentenceMatch != null) {
          splitIndex = sentenceMatch.end;
        } else if (clauseMatch != null) {
          final textBeforeClause =
              accumulated.substring(0, clauseMatch.start).trim();
          final clauseWords = textBeforeClause
              .split(RegExp(r'\s+'))
              .where((w) => w.isNotEmpty)
              .length;
          if (clauseWords >= 5) {
            splitIndex = clauseMatch.end;
          }
        } else if (wordCount >= 14) {
          final targetSpaces = words.take(10).join(' ').length;
          splitIndex =
              targetSpaces < accumulated.length ? targetSpaces : accumulated.length;
        }

        if (splitIndex != null && splitIndex > 0) {
          final firstChunkText = accumulated.substring(0, splitIndex).trim();
          accumulated = accumulated.substring(splitIndex);
          accumulatedBuffer
            ..clear()
            ..write(accumulated);

          if (firstChunkText.isNotEmpty) {
            firstSentenceSpoken = true;
            onFirstSentenceSpoken();
            if (!isMuted) {
              await ttsHandler.enqueueSentence(firstChunkText);
            }
          }
        }
      } else {
        while (true) {
          final sentenceMatch = sentenceDelimiters.firstMatch(accumulated);
          final clauseMatch = clauseDelimiters.firstMatch(accumulated);
          final words = accumulated.trim().split(RegExp(r'\s+'));
          final wordCount = words.length;

          int? splitIndex;

          if (sentenceMatch != null) {
            splitIndex = sentenceMatch.end;
          } else if (clauseMatch != null) {
            final textBeforeClause =
                accumulated.substring(0, clauseMatch.start).trim();
            final clauseWords = textBeforeClause
                .split(RegExp(r'\s+'))
                .where((w) => w.isNotEmpty)
                .length;
            if (clauseWords >= 7) {
              splitIndex = clauseMatch.end;
            }
          } else if (wordCount >= 16) {
            final targetSpaces = words.take(12).join(' ').length;
            splitIndex =
                targetSpaces < accumulated.length ? targetSpaces : accumulated.length;
          }

          if (splitIndex == null || splitIndex <= 0) break;

          final chunkText = accumulated.substring(0, splitIndex).trim();
          accumulated = accumulated.substring(splitIndex);
          accumulatedBuffer
            ..clear()
            ..write(accumulated);

          if (chunkText.isNotEmpty && !isMuted) {
            await ttsHandler.enqueueSentence(chunkText);
          }
        }
      }

      onChunkReceived(chunk);
    }

    final remaining = accumulatedBuffer.toString().trim();
    if (remaining.isNotEmpty) {
      if (!firstSentenceSpoken) {
        onFirstSentenceSpoken();
      }
      if (!isMuted) {
        await ttsHandler.enqueueSentence(remaining);
      }
    }

    if (!isMuted) {
      await ttsHandler.waitForQueueDrained();
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 600));
    }
  }
}
