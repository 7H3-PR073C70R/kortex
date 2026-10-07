import '../models/generation_params.dart';
import '../models/llama_config.dart';
import '../models/llama_response.dart';

/// Web fallback stub for LlamaFfiEngine when dart:ffi is unavailable.
class LlamaFfiEngine {
  static final LlamaFfiEngine _instance = LlamaFfiEngine._();
  LlamaFfiEngine._();

  static LlamaFfiEngine get instance => _instance;

  bool get isModelLoaded => false;
  String? get modelPath => null;

  Future<bool> loadModel(LlamaConfig config, {String? nativeLibraryPath}) async => false;

  Stream<String> generateResponseStream(String prompt, {GenerationParams? params}) async* {
    throw UnsupportedError('LlamaFfiEngine is not supported on web.');
  }

  Future<LlamaResponse> generateResponse(String prompt, {GenerationParams? params}) async {
    throw UnsupportedError('LlamaFfiEngine is not supported on web.');
  }

  void stopGeneration() {}
  void unloadModel() {}
}

/// Web fallback stub for LlamaFfiBindings when dart:ffi is unavailable.
class LlamaFfiBindings {
  static dynamic openLibrary([String? path]) {
    throw UnsupportedError('LlamaFfiBindings is not supported on web.');
  }
}
