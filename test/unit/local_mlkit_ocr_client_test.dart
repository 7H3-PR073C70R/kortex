import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/ingestion/data/client/local_mlkit_ocr_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    const pathChannel =
        MethodChannel('plugins.flutter.io/path_provider');
    const pathChannelMacos =
        MethodChannel('plugins.flutter.io/path_provider_macos');
    const mlkitChannel =
        MethodChannel('google_mlkit_text_recognizer');

    Future<Object?> pathHandler(MethodCall call) async =>
        Directory.systemTemp.path;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, pathHandler);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannelMacos, pathHandler);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(mlkitChannel, (call) async {
      if (call.method == 'vision#startTextRecognizer') {
        final argsStr = call.arguments.toString();
        if (argsStr.contains('path')) {
          final map = call.arguments as Map;
          final path = map['path'] as String? ??
              (map['imageData'] as Map?)?['path'] as String?;
          if (path != null && File(path).existsSync()) {
            final fileBytes = File(path).readAsBytesSync();
            if (fileBytes.every((b) => b == 0)) {
              return {
                'text': '',
                'blocks': <dynamic>[],
              };
            }
          }
        }
        return {
          'text': 'Maxwell Equations:\ncurl E = -dB/dt\ncurl B = mu0*J',
          'blocks': [
            {
              'text': 'Maxwell Equations',
              'rect': <String, dynamic>{
                'left': 0.0,
                'top': 0.0,
                'right': 100.0,
                'bottom': 20.0,
              },
              'points': <dynamic>[],
              'recognizedLanguages': <dynamic>[],
              'lines': <dynamic>[],
            }
          ]
        };
      }
      return null;
    });
  });

  group('LocalMlkitOcrClient Unit Test Suite', () {
    const client = LocalMlkitOcrClient();

    test('extracts recognized text blocks from image bytes', () async {
      const sampleText = 'Maxwell Equations:\ncurl E = -dB/dt\ncurl B = mu0*J';
      final bytes = Uint8List.fromList(utf8.encode(sampleText));

      final blocks = await client.processImageBytes(bytes);

      expect(blocks, isNotEmpty);
      expect(blocks.first.text, contains('Maxwell Equations'));
      expect(blocks.first.confidence, greaterThanOrEqualTo(0.90));
    });

    test(
      'throws OcrProcessingException when bytes are corrupted or zero-filled',
      () async {
        final emptyBytes = Uint8List.fromList([0, 0, 0, 0]);

        // When text returned is empty, processImageBytes throws OcrProcessingException
        expect(
          () => client.processImageBytes(emptyBytes),
          throwsA(isA<OcrProcessingException>()),
        );
      },
    );

    test('throws OcrProcessingException when bytes are empty', () async {
      expect(
        () => client.processImageBytes(Uint8List(0)),
        throwsA(
          isA<OcrProcessingException>().having(
            (e) => e.message,
            'message',
            contains('Empty document payload'),
          ),
        ),
      );
    });
  });
}
