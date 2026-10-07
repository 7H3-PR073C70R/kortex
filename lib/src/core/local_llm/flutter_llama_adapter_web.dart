// Web stub adapter: provides no-op stubs for all flutter_llama types used by
// the app. On web, on-device LLM inference is unsupported — all methods throw
// UnsupportedError or return empty/false values.


// ignore_for_file: document_ignores, prefer_constructors_over_static_methods

/// Stub: ModelSource enum (pure data — safe to duplicate)
enum ModelSource { huggingFace, ollama, local }

extension ModelSourceExtension on ModelSource {
  String get displayName {
    switch (this) {
      case ModelSource.huggingFace:
        return 'HuggingFace';
      case ModelSource.ollama:
        return 'Ollama';
      case ModelSource.local:
        return 'Local file';
    }
  }

  String get description => '';
  String get icon => '';
}

class ModelNotFoundException implements Exception {
  ModelNotFoundException(this.modelId, [this.message]);
  final String modelId;
  final String? message;
  @override
  String toString() => 'ModelNotFoundException: $modelId';
}

class ModelDownloadException implements Exception {
  ModelDownloadException(this.modelId, this.message, [this.originalError]);
  final String modelId;
  final String message;
  final dynamic originalError;
  @override
  String toString() => 'ModelDownloadException: $modelId: $message';
}

class DownloadProgress {
  const DownloadProgress({
    required this.progress,
    required this.status,
    this.downloadedBytes,
    this.totalBytes,
  });
  final double progress;
  final String status;
  final int? downloadedBytes;
  final int? totalBytes;
  String get progressPercent => '${(progress * 100).toStringAsFixed(1)}%';
  String get downloadedMB => 'N/A';
  String get totalMB => 'N/A';
}

typedef DownloadProgressCallback = void Function(DownloadProgress progress);

/// Stub: LlamaConfig (pure data)
class LlamaConfig {

  const LlamaConfig({
    required this.modelPath,
    this.nThreads = 4,
    this.nGpuLayers = 0,
    this.contextSize = 2048,
    this.batchSize = 512,
    this.useGpu = true,
    this.verbose = false,
  });
  final String modelPath;
  final int nThreads;
  final int nGpuLayers;
  final int contextSize;
  final int batchSize;
  final bool useGpu;
  final bool verbose;
}

/// Stub: LlamaResponse (pure data)
class LlamaResponse {

  const LlamaResponse({
    required this.text,
    this.tokensGenerated = 0,
    this.generationTimeMs = 0,
  });
  final String text;
  final int tokensGenerated;
  final int generationTimeMs;
  double get tokensPerSecond => 0;
}

/// Stub: GenerationParams (pure data)
class GenerationParams {

  const GenerationParams({
    required this.prompt,
    this.temperature = 0.8,
    this.topP = 0.95,
    this.topK = 40,
    this.maxTokens = 512,
    this.repeatPenalty = 1.1,
    this.stopSequences = const [],
  });
  final String prompt;
  final double temperature;
  final double topP;
  final int topK;
  final int maxTokens;
  final double repeatPenalty;
  final List<String> stopSequences;
}

/// Stub: PresetModel (pure data)
class PresetModel {

  const PresetModel({
    required this.id,
    required this.name,
    required this.description,
    required this.source,
    required this.size, this.variant,
    this.files = const [],
    this.languages = const [],
    this.contextSize,
    this.metadata,
  });
  final String id;
  final String name;
  final String description;
  final ModelSource source;
  final String? variant;
  final List<String> files;
  final List<String> languages;
  final String size;
  final int? contextSize;
  final Map<String, dynamic>? metadata;

  String get fullName => variant != null ? '$id:$variant' : id;
}

/// Stub: PresetModels (pure data constants)
class PresetModels {
  static const smolLM2Q4K = PresetModel(
    id: 'Segilmez06/SmolLM2-135M-Instruct-Q4_K_M-GGUF',
    name: 'SmolLM2 135M Instruct (Q4_K_M)',
    description: 'Ultra-fast 4-bit quantized model for mobile',
    source: ModelSource.huggingFace,
    files: ['smollm2-135m-instruct-q4_k_m.gguf'],
    languages: ['🇬🇧 English'],
    size: '100 MB',
    contextSize: 2048,
  );
  static const smolLM2_360mQ4K = PresetModel(
    id: 'HuggingFaceTB/SmolLM2-360M-Instruct-GGUF',
    name: 'SmolLM2 360M Instruct (Q4_K_M)',
    description: 'Fast, balanced lightweight model',
    source: ModelSource.huggingFace,
    files: ['smollm2-360m-instruct-q4_k_m.gguf'],
    languages: ['🇬🇧 English'],
    size: '230 MB',
    contextSize: 2048,
  );
  static const qwen25Q4K = PresetModel(
    id: 'Qwen/Qwen2.5-0.5B-Instruct-GGUF',
    name: 'Qwen 2.5 0.5B Instruct (Q4_K_M)',
    description: 'Compact model with good STEM reasoning',
    source: ModelSource.huggingFace,
    files: ['qwen2.5-0.5b-instruct-q4_k_m.gguf'],
    languages: ['🇬🇧 English'],
    size: '350 MB',
    contextSize: 2048,
  );
  static const qwen25_1_5bQ4K = PresetModel(
    id: 'Qwen/Qwen2.5-1.5B-Instruct-GGUF',
    name: 'Qwen 2.5 1.5B Instruct (Q4_K_M)',
    description: 'High-intelligence reasoning model',
    source: ModelSource.huggingFace,
    files: ['qwen2.5-1.5b-instruct-q4_k_m.gguf'],
    languages: ['🇬🇧 English'],
    size: '980 MB',
    contextSize: 4096,
  );
  static const llama32_1bQ4K = PresetModel(
    id: 'unsloth/Llama-3.2-1B-Instruct-GGUF',
    name: 'Llama 3.2 1B Instruct (Q4_K_M)',
    description: "Meta's 1B instruction model",
    source: ModelSource.huggingFace,
    files: ['Llama-3.2-1B-Instruct-Q4_K_M.gguf'],
    languages: ['🇬🇧 English'],
    size: '750 MB',
    contextSize: 4096,
  );
  static const all = <PresetModel>[
    smolLM2Q4K, smolLM2_360mQ4K, qwen25Q4K, qwen25_1_5bQ4K, llama32_1bQ4K,
  ];
}

/// Stub: ModelManager (no-op on web)
class ModelManager {
  ModelManager._();
  static ModelManager fromPreset(PresetModel preset) => ModelManager._();
  Future<String?> getModelPath() async => null;
  Future<void> deleteModel() async {}
}

/// Stub: FlutterLlama (no-op on web — all inference is cloud-side)
class FlutterLlama {
  FlutterLlama._();
  static final FlutterLlama _instance = FlutterLlama._();
  static FlutterLlama get instance => _instance;

  bool get isModelLoaded => false;
  String? get modelPath => null;
  bool get isInitialized => false;

  Future<bool> loadModel(LlamaConfig config) async => false;
  Future<bool> loadPresetModel({
    required PresetModel preset,
    LlamaConfig? config,
    DownloadProgressCallback? onProgress,
  }) async => false;
  Future<void> unloadModel() async {}

  Future<LlamaResponse> generate(GenerationParams params) async {
    throw UnsupportedError('On-device LLM is not supported on web.');
  }

  Stream<String> generateStream(GenerationParams params) async* {
    throw UnsupportedError('On-device LLM is not supported on web.');
  }
}
