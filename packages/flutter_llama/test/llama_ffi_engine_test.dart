import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_llama/flutter_llama.dart';

void main() {
  group('LlamaFfiEngine Tests', () {
    test('initial state has no model loaded', () {
      final engine = LlamaFfiEngine.instance;
      expect(engine.isModelLoaded, isFalse);
      expect(engine.modelPath, isNull);
    });

    test('generate throws StateError when model is not loaded', () async {
      final engine = LlamaFfiEngine.instance;
      expect(
        () => engine.generate(const GenerationParams(prompt: 'Hello')),
        throwsStateError,
      );
    });

    test('generateStream throws StateError when model is not loaded', () {
      final engine = LlamaFfiEngine.instance;
      expect(
        () => engine.generateStream(const GenerationParams(prompt: 'Hello')),
        throwsStateError,
      );
    });

    test('unloadModel returns true when no model is loaded', () async {
      final engine = LlamaFfiEngine.instance;
      final result = await engine.unloadModel();
      expect(result, isTrue);
      expect(engine.isModelLoaded, isFalse);
      expect(engine.modelPath, isNull);
    });

    test('getModelInfo returns null when no model is loaded', () async {
      final engine = LlamaFfiEngine.instance;
      final info = await engine.getModelInfo();
      expect(info, isNull);
    });

    test('FlutterLlama.isDesktopFfi reflects desktop platform state', () {
      final isWindowsOrLinux = Platform.isWindows || Platform.isLinux;
      expect(FlutterLlama.isDesktopFfi, equals(isWindowsOrLinux));
    });
  });
}
