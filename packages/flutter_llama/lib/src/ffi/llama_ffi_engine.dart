import 'dart:async';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import '../models/generation_params.dart';
import '../models/llama_config.dart';
import '../models/llama_response.dart';
import 'llama_ffi_bindings.dart';

/// Dart FFI engine implementation for desktop platforms (Windows, Linux, macOS).
///
/// Binds directly to the compiled native llama.cpp library via dart:ffi,
/// running token generation in non-blocking event loops without MethodChannel overhead.
class LlamaFfiEngine {
  static LlamaFfiEngine? _instance;

  LlamaFfiBindings? _bindings;
  bool _isModelLoaded = false;
  String? _modelPath;
  bool _shouldStop = false;

  LlamaFfiEngine._();

  static LlamaFfiEngine get instance {
    _instance ??= LlamaFfiEngine._();
    return _instance!;
  }

  bool get isModelLoaded => _isModelLoaded;
  String? get modelPath => _modelPath;

  /// Ensures native dynamic library bindings are loaded.
  LlamaFfiBindings _ensureBindings([String? libraryPath]) {
    if (_bindings != null) return _bindings!;
    final dylib = LlamaFfiBindings.openLibrary(libraryPath);
    _bindings = LlamaFfiBindings(dylib);
    return _bindings!;
  }

  /// Loads a GGUF model from [config].
  Future<bool> loadModel(LlamaConfig config, {String? nativeLibraryPath}) async {
    try {
      if (kDebugMode) {
        print('[LlamaFfiEngine] Loading model via FFI: ${config.modelPath}');
      }

      final bindings = _ensureBindings(nativeLibraryPath);

      final pathPtr = config.modelPath.toNativeUtf8();
      try {
        final success = bindings.initModel(
          pathPtr,
          config.nThreads,
          config.nGpuLayers,
          config.contextSize,
          config.batchSize,
          config.useGpu,
          config.verbose,
        );

        _isModelLoaded = success;
        if (success) {
          _modelPath = config.modelPath;
          if (kDebugMode) {
            print('[LlamaFfiEngine] Model loaded successfully: ${config.modelPath}');
          }
        } else {
          _modelPath = null;
          if (kDebugMode) {
            print('[LlamaFfiEngine] Failed to initialize model');
          }
        }
        return success;
      } finally {
        calloc.free(pathPtr);
      }
    } catch (e) {
      if (kDebugMode) {
        print('[LlamaFfiEngine] Exception in loadModel: $e');
      }
      _isModelLoaded = false;
      _modelPath = null;
      rethrow;
    }
  }

  /// Generates a complete text response synchronously or asynchronously via FFI.
  Future<LlamaResponse> generate(GenerationParams params) async {
    if (!_isModelLoaded) {
      throw StateError('Model is not loaded. Call loadModel first.');
    }

    final bindings = _ensureBindings();
    final stopwatch = Stopwatch()..start();
    _shouldStop = false;

    const bufferSize = 16384;
    final promptPtr = params.prompt.toNativeUtf8();
    final outputPtr = calloc<Uint8>(bufferSize).cast<Utf8>();
    final tokensGenPtr = calloc<Int32>();

    try {
      final success = bindings.generate(
        promptPtr,
        params.temperature,
        params.topP,
        params.topK,
        params.maxTokens,
        params.repeatPenalty,
        outputPtr,
        bufferSize,
        tokensGenPtr,
      );

      stopwatch.stop();

      if (!success) {
        throw StateError('FFI generation failed.');
      }

      final text = outputPtr.toDartString();
      final tokensGenerated = tokensGenPtr.value;

      return LlamaResponse(
        text: text,
        tokensGenerated: tokensGenerated,
        generationTimeMs: stopwatch.elapsedMilliseconds,
      );
    } finally {
      calloc.free(promptPtr);
      calloc.free(outputPtr);
      calloc.free(tokensGenPtr);
    }
  }

  /// Generates a stream of text tokens.
  Stream<String> generateStream(GenerationParams params) {
    if (!_isModelLoaded) {
      throw StateError('Model is not loaded. Call loadModel first.');
    }

    final bindings = _ensureBindings();
    final controller = StreamController<String>();

    _shouldStop = false;
    final promptPtr = params.prompt.toNativeUtf8();

    bindings.generateStreamInit(
      promptPtr,
      params.temperature,
      params.topP,
      params.topK,
      params.maxTokens,
      params.repeatPenalty,
    );
    calloc.free(promptPtr);

    const tokenBufSize = 512;
    final tokenBuf = calloc<Uint8>(tokenBufSize).cast<Utf8>();

    void closeAndCleanup() {
      try {
        bindings.generateStreamEnd();
      } catch (_) {}
      try {
        calloc.free(tokenBuf);
      } catch (_) {}
      if (!controller.isClosed) {
        controller.close();
      }
    }

    controller.onCancel = () {
      _shouldStop = true;
      bindings.stopGeneration();
      closeAndCleanup();
    };

    // Iterate token by token asynchronously to keep UI responsive
    Future<void> runLoop() async {
      try {
        while (!controller.isClosed && !_shouldStop) {
          final hasNext = bindings.generateStreamNext(tokenBuf, tokenBufSize);
          if (!hasNext) {
            break;
          }

          final piece = tokenBuf.toDartString();
          if (piece.isEmpty) {
            continue;
          }

          // Check user stop sequences
          var shouldBreak = false;
          for (final stopSeq in params.stopSequences) {
            if (piece.contains(stopSeq)) {
              shouldBreak = true;
              break;
            }
          }

          if (shouldBreak) {
            break;
          }

          controller.add(piece);

          // Yield execution to the Dart event loop between tokens
          await Future<void>.delayed(Duration.zero);
        }
      } catch (e, stack) {
        if (!controller.isClosed) {
          controller.addError(e, stack);
        }
      } finally {
        closeAndCleanup();
      }
    }

    runLoop();
    return controller.stream;
  }

  /// Unloads the current model and frees native memory.
  Future<bool> unloadModel() async {
    if (!_isModelLoaded) return true;
    try {
      final bindings = _ensureBindings();
      bindings.freeModel();
      _isModelLoaded = false;
      _modelPath = null;
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('[LlamaFfiEngine] Error in unloadModel: $e');
      }
      return false;
    }
  }

  /// Retrieves metadata about the loaded model.
  Future<Map<String, dynamic>?> getModelInfo() async {
    if (!_isModelLoaded) return null;

    final bindings = _ensureBindings();
    final nParamsPtr = calloc<Int64>();
    final nLayersPtr = calloc<Int32>();
    final ctxSizePtr = calloc<Int32>();

    try {
      bindings.getModelInfo(nParamsPtr, nLayersPtr, ctxSizePtr);
      return <String, dynamic>{
        'modelPath': _modelPath,
        'nParams': nParamsPtr.value,
        'nLayers': nLayersPtr.value,
        'contextSize': ctxSizePtr.value,
      };
    } finally {
      calloc.free(nParamsPtr);
      calloc.free(nLayersPtr);
      calloc.free(ctxSizePtr);
    }
  }

  /// Stops ongoing token generation.
  Future<void> stopGeneration() async {
    _shouldStop = true;
    try {
      final bindings = _ensureBindings();
      bindings.stopGeneration();
    } catch (e) {
      if (kDebugMode) {
        print('[LlamaFfiEngine] Error stopping generation: $e');
      }
    }
  }
}
