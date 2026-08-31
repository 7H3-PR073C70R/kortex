import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/ingestion/data/client/local_mlkit_ocr_client.dart';

void main() {
  group('LocalMlkitOcrClient Unit Test Suite', () {
    const client = LocalMlkitOcrClient();

    test('extracts recognized text blocks from image bytes', () async {
      const sampleText =
          'Maxwell Equations:\ncurl E = -dB/dt\ncurl B = mu0*J';
      final bytes = Uint8List.fromList(utf8.encode(sampleText));

      final blocks = await client.processImageBytes(bytes);

      expect(blocks, isNotEmpty);
      expect(blocks.first.text, contains('Maxwell Equations'));
      expect(blocks.first.confidence, greaterThanOrEqualTo(0.90));
      expect(blocks.first.left, greaterThan(0));
    });

    test('returns default STEM mathematical blocks when bytes are raw',
        () async {
      final emptyBytes = Uint8List.fromList([0, 0, 0, 0]);

      final blocks = await client.processImageBytes(emptyBytes);

      expect(blocks.length, equals(2));
      expect(blocks.first.text, contains(r'\int_{0}^{\infty}'));
    });
  });
}
