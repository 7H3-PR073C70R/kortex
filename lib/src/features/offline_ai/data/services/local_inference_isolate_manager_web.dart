// Web stub for local_inference_isolate_manager.
// On web, on-device LLM inference is not supported.
// All classes are provided as no-ops to satisfy the type system.

// ignore_for_file: document_ignores

class InferenceTimeoutException implements Exception {
  const InferenceTimeoutException(this.message);
  final String message;
  @override
  String toString() => 'InferenceTimeoutException: $message';
}

class InsufficientContentException implements Exception {
  const InsufficientContentException([
    this.message = 'Insufficient content to synthesize study cards on-device.',
  ]);
  final String message;
  @override
  String toString() => 'InsufficientContentException: $message';
}

class MemoryLimitConfig {
  const MemoryLimitConfig({
    required this.contextTokens,
    required this.maxOutputTokens,
    required this.maxChunkWords,
    required this.isLowRamProfile,
  });

  factory MemoryLimitConfig.fromSystemRam({int estimatedRamMb = 4096}) {
    if (estimatedRamMb < 4000) {
      return const MemoryLimitConfig(
        contextTokens: 1024,
        maxOutputTokens: 256,
        maxChunkWords: 800,
        isLowRamProfile: true,
      );
    }
    return const MemoryLimitConfig(
      contextTokens: 2048,
      maxOutputTokens: 512,
      maxChunkWords: 800,
      isLowRamProfile: false,
    );
  }

  final int contextTokens;
  final int maxOutputTokens;
  final int maxChunkWords;
  final bool isLowRamProfile;
}

class InferenceTask {
  const InferenceTask({
    required this.modelPath,
    required this.prompt,
    required this.config,
    this.systemInstruction,
    this.numGpuLayers = 99,
  });

  final String modelPath;
  final String prompt;
  final MemoryLimitConfig config;
  final String? systemInstruction;
  final int numGpuLayers;

  Map<String, dynamic> toJson() => {
        'modelPath': modelPath,
        'prompt': prompt,
        'contextTokens': config.contextTokens,
        'maxOutputTokens': config.maxOutputTokens,
        'numGpuLayers': numGpuLayers,
        if (systemInstruction != null) 'systemInstruction': systemInstruction,
      };
}

class LocalInferenceIsolateManager {
  LocalInferenceIsolateManager({int estimatedSystemRamMb = 4096})
      : _memoryConfig =
            MemoryLimitConfig.fromSystemRam(estimatedRamMb: estimatedSystemRamMb);

  final MemoryLimitConfig _memoryConfig;
  static const Duration wallClockTimeout = Duration(seconds: 35);

  MemoryLimitConfig get config => _memoryConfig;

  Future<String> runIsolatedInference(InferenceTask task) async {
    if (task.prompt.trim().length <= 5) {
      throw const InsufficientContentException();
    }
    return 'Simulated Web Inference Output for ${task.prompt}';
  }

  Future<List<Map<String, dynamic>>> executeChunkedInference({
    required String modelPath,
    required String topic,
    String? sourceText,
  }) async {
    throw UnsupportedError('On-device inference is not supported on web.');
  }

  Future<void> releaseContext() async {}
  Future<void> dispose() async {}
}
