import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

// Native typedefs
typedef LlamaInitModelNative = Bool Function(
  Pointer<Utf8> modelPath,
  Int32 nThreads,
  Int32 nGpuLayers,
  Int32 contextSize,
  Int32 batchSize,
  Bool useGpu,
  Bool verbose,
);
typedef LlamaInitModelDart = bool Function(
  Pointer<Utf8> modelPath,
  int nThreads,
  int nGpuLayers,
  int contextSize,
  int batchSize,
  bool useGpu,
  bool verbose,
);

typedef LlamaGenerateNative = Bool Function(
  Pointer<Utf8> prompt,
  Float temperature,
  Float topP,
  Int32 topK,
  Int32 maxTokens,
  Float repeatPenalty,
  Pointer<Utf8> output,
  Int32 outputSize,
  Pointer<Int32> tokensGenerated,
);
typedef LlamaGenerateDart = bool Function(
  Pointer<Utf8> prompt,
  double temperature,
  double topP,
  int topK,
  int maxTokens,
  double repeatPenalty,
  Pointer<Utf8> output,
  int outputSize,
  Pointer<Int32> tokensGenerated,
);

typedef LlamaGenerateStreamInitNative = Void Function(
  Pointer<Utf8> prompt,
  Float temperature,
  Float topP,
  Int32 topK,
  Int32 maxTokens,
  Float repeatPenalty,
);
typedef LlamaGenerateStreamInitDart = void Function(
  Pointer<Utf8> prompt,
  double temperature,
  double topP,
  int topK,
  int maxTokens,
  double repeatPenalty,
);

typedef LlamaGenerateStreamNextNative = Bool Function(
  Pointer<Utf8> output,
  Int32 outputSize,
);
typedef LlamaGenerateStreamNextDart = bool Function(
  Pointer<Utf8> output,
  int outputSize,
);

typedef LlamaGenerateStreamEndNative = Void Function();
typedef LlamaGenerateStreamEndDart = void Function();

typedef LlamaGetModelInfoNative = Void Function(
  Pointer<Int64> nParams,
  Pointer<Int32> nLayers,
  Pointer<Int32> contextSize,
);
typedef LlamaGetModelInfoDart = void Function(
  Pointer<Int64> nParams,
  Pointer<Int32> nLayers,
  Pointer<Int32> contextSize,
);

typedef LlamaFreeModelNative = Void Function();
typedef LlamaFreeModelDart = void Function();

typedef LlamaStopGenerationNative = Void Function();
typedef LlamaStopGenerationDart = void Function();

/// Holds the low-level dart:ffi function bindings for flutter_llama.
class LlamaFfiBindings {
  final DynamicLibrary library;

  late final LlamaInitModelDart initModel;
  late final LlamaGenerateDart generate;
  late final LlamaGenerateStreamInitDart generateStreamInit;
  late final LlamaGenerateStreamNextDart generateStreamNext;
  late final LlamaGenerateStreamEndDart generateStreamEnd;
  late final LlamaGetModelInfoDart getModelInfo;
  late final LlamaFreeModelDart freeModel;
  late final LlamaStopGenerationDart stopGeneration;

  LlamaFfiBindings(this.library) {
    initModel = library
        .lookup<NativeFunction<LlamaInitModelNative>>('llama_init_model')
        .asFunction<LlamaInitModelDart>();

    generate = library
        .lookup<NativeFunction<LlamaGenerateNative>>('llama_generate')
        .asFunction<LlamaGenerateDart>();

    generateStreamInit = library
        .lookup<NativeFunction<LlamaGenerateStreamInitNative>>(
            'llama_generate_stream_init')
        .asFunction<LlamaGenerateStreamInitDart>();

    generateStreamNext = library
        .lookup<NativeFunction<LlamaGenerateStreamNextNative>>(
            'llama_generate_stream_next')
        .asFunction<LlamaGenerateStreamNextDart>();

    generateStreamEnd = library
        .lookup<NativeFunction<LlamaGenerateStreamEndNative>>(
            'llama_generate_stream_end')
        .asFunction<LlamaGenerateStreamEndDart>();

    getModelInfo = library
        .lookup<NativeFunction<LlamaGetModelInfoNative>>('llama_get_model_info')
        .asFunction<LlamaGetModelInfoDart>();

    freeModel = library
        .lookup<NativeFunction<LlamaFreeModelNative>>(
            'llama_cpp_bridge_free_model')
        .asFunction<LlamaFreeModelDart>();

    stopGeneration = library
        .lookup<NativeFunction<LlamaStopGenerationNative>>(
            'llama_stop_generation')
        .asFunction<LlamaStopGenerationDart>();
  }

  /// Locates and opens the appropriate native shared library for the current platform.
  static DynamicLibrary openLibrary([String? customPath]) {
    if (customPath != null && customPath.isNotEmpty) {
      return DynamicLibrary.open(customPath);
    }

    final exeDir = p.dirname(Platform.resolvedExecutable);

    if (Platform.isWindows) {
      const candidates = [
        'flutter_llama_plugin.dll',
        'flutter_llama.dll',
        'llama.dll',
      ];
      for (final name in candidates) {
        final fullPath = p.join(exeDir, name);
        if (File(fullPath).existsSync()) {
          return DynamicLibrary.open(fullPath);
        }
      }
      for (final name in candidates) {
        try {
          return DynamicLibrary.open(name);
        } catch (_) {}
      }
    } else if (Platform.isLinux) {
      const candidates = [
        'libflutter_llama_plugin.so',
        'libflutter_llama.so',
        'libllama.so',
      ];
      final libDir = p.join(exeDir, 'lib');
      for (final name in candidates) {
        final pathInLib = p.join(libDir, name);
        if (File(pathInLib).existsSync()) {
          return DynamicLibrary.open(pathInLib);
        }
        final pathInExe = p.join(exeDir, name);
        if (File(pathInExe).existsSync()) {
          return DynamicLibrary.open(pathInExe);
        }
      }
      for (final name in candidates) {
        try {
          return DynamicLibrary.open(name);
        } catch (_) {}
      }
    } else if (Platform.isMacOS) {
      try {
        return DynamicLibrary.process();
      } catch (_) {
        return DynamicLibrary.open('libllama.dylib');
      }
    }

    // Default fallback to process symbols
    return DynamicLibrary.process();
  }
}
