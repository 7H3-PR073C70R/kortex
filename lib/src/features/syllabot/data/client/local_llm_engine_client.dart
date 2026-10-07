import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/local_llm/flutter_llama_adapter.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/syllabot/domain/entities/chat_message_entity.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';
import 'package:path_provider/path_provider.dart';

/// Representation of a local LLM model preset and its disk/active status.
class LocalLlmModelInfo {
  const LocalLlmModelInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.sizeLabel,
    required this.requiredMb,
    required this.preset,
    this.filePath,
    this.isDownloaded = false,
    this.isActive = false,
    this.fileSizeBytes = 0,
    this.partialBytes = 0,
  });

  final String id;
  final String name;
  final String description;
  final String sizeLabel;
  final int requiredMb;
  final PresetModel preset;
  final String? filePath;
  final bool isDownloaded;
  final bool isActive;
  final int fileSizeBytes;
  final int partialBytes;

  bool get hasPartialDownload => !isDownloaded && partialBytes > 0;

  LocalLlmModelInfo copyWith({
    String? id,
    String? name,
    String? description,
    String? sizeLabel,
    int? requiredMb,
    PresetModel? preset,
    String? filePath,
    bool? isDownloaded,
    bool? isActive,
    int? fileSizeBytes,
    int? partialBytes,
  }) {
    return LocalLlmModelInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      sizeLabel: sizeLabel ?? this.sizeLabel,
      requiredMb: requiredMb ?? this.requiredMb,
      preset: preset ?? this.preset,
      filePath: filePath ?? this.filePath,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      isActive: isActive ?? this.isActive,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      partialBytes: partialBytes ?? this.partialBytes,
    );
  }
}

/// Global device download state update.
class ModelDownloadProgressState {
  const ModelDownloadProgressState({
    required this.modelId,
    required this.modelName,
    required this.progress,
    required this.isDownloading,
    this.errorMessage,
  });

  final String modelId;
  final String modelName;
  final double progress;
  final bool isDownloading;
  final String? errorMessage;
}

/// Intelligent on-device local LLM client for Syllabot AI.
///
/// Powered by `flutter_llama` for native quantized GGUF on-device inference,
/// supporting streaming token generation, dynamic model lifecycle management,
/// model switching, deletion, and single-download lock enforcement.
class LocalLlmEngineClient {
  LocalLlmEngineClient();

  static const String _modelStorageKey = '__local_llm_model_downloaded';
  static const String _modelPathKey = '__local_llm_model_path';
  static const String modelsDirectoryName = 'kortex_models';
  bool _isInitialized = false;

  // --- Single Active Download Lock & State ---
  static bool _isGlobalDownloadActive = false;
  static String? _activeDownloadingModelId;
  static String? _activeDownloadingModelName;
  static double _activeDownloadProgress = 0;
  static final StreamController<ModelDownloadProgressState>
      _downloadProgressController =
      StreamController<ModelDownloadProgressState>.broadcast();

  static bool get isGlobalDownloadActive => _isGlobalDownloadActive;
  static String? get activeDownloadingModelId => _activeDownloadingModelId;
  static String? get activeDownloadingModelName => _activeDownloadingModelName;
  static double get activeDownloadProgress => _activeDownloadProgress;
  static Stream<ModelDownloadProgressState> get downloadProgressStream =>
      _downloadProgressController.stream;

  /// Built-in curated local models adaptively sized for device capacity and platform
  static const List<LocalLlmModelInfo> catalogModels = [
    LocalLlmModelInfo(
      id: 'smollm2-135m',
      name: 'SmolLM2 135M',
      description: 'Ultra-fast 4-bit quantized model for budget mobile devices',
      sizeLabel: '100 MB',
      requiredMb: 100,
      preset: PresetModels.smolLM2Q4K,
    ),
    LocalLlmModelInfo(
      id: 'smollm2-360m',
      name: 'SmolLM2 360M',
      description: 'Balanced, fast instruction model for mobile & tablet',
      sizeLabel: '230 MB',
      requiredMb: 230,
      preset: PresetModels.smolLM2_360mQ4K,
    ),
    LocalLlmModelInfo(
      id: 'qwen2.5-0.5b',
      name: 'Qwen 2.5 0.5B',
      description: 'Compact model with good basic Socratic STEM reasoning',
      sizeLabel: '350 MB',
      requiredMb: 350,
      preset: PresetModels.qwen25Q4K,
    ),
    LocalLlmModelInfo(
      id: 'llama3.2-1b',
      name: 'Llama 3.2 1B',
      description: "Meta's high-quality 1B instruction model for mobile & desktop",
      sizeLabel: '750 MB',
      requiredMb: 750,
      preset: PresetModels.llama32_1bQ4K,
    ),
    LocalLlmModelInfo(
      id: 'qwen2.5-1.5b',
      name: 'Qwen 2.5 1.5B Pro',
      description: 'High-intelligence reasoning engine for Desktop & Pro mobile devices',
      sizeLabel: '980 MB',
      requiredMb: 980,
      preset: PresetModels.qwen25_1_5bQ4K,
    ),
  ];

  /// Returns the shared on-device models directory used across Syllabot and Decks.
  static Future<Directory> getSharedModelsDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/$modelsDirectoryName');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  /// Scans the shared `kortex_models` directory for an existing valid GGUF model.
  static Future<String?> findSharedModelPath() async {
    try {
      final dir = await getSharedModelsDirectory();
      if (dir.existsSync()) {
        final ggufFiles = dir
            .listSync()
            .whereType<File>()
            .where(
              (f) {
                if (!f.path.endsWith('.gguf')) return false;
                final size = f.lengthSync();
                // Complete models are at least 80MB (SmolLM2 ~100MB, Qwen ~350MB)
                if (size >= 80 * 1024 * 1024) return true;
                // Automatically clean up incomplete or partial downloads
                try {
                  f.deleteSync();
                } on Object catch (_) {}
                return false;
              },
            )
            .toList();
        if (ggufFiles.isNotEmpty) {
          ggufFiles.sort(
            (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
          );
          return ggufFiles.first.path;
        }
      }
    } on Object catch (_) {
      // Ignored
    }
    return null;
  }

  /// Checks if the on-device model weights are downloaded and exist locally on disk.
  bool get isModelDownloaded {
    try {
      final storage = locator<LocalStorageService>();
      final path = storage.getPreference(key: _modelPathKey);
      if (path != null && path.isNotEmpty && File(path).existsSync()) {
        final size = File(path).lengthSync();
        if (size >= 80 * 1024 * 1024) {
          return true;
        } else {
          // Clean up partial download and clear preference keys
          try {
            File(path).deleteSync();
          } on Object catch (_) {}
          unawaited(storage.deletePreference(key: _modelStorageKey));
          unawaited(storage.deletePreference(key: _modelPathKey));
          unawaited(storage.deletePreference(key: PrefKeys.syllabotActiveLocalModelPath));
          unawaited(storage.deletePreference(key: PrefKeys.syllabotActiveLocalModelId));
        }
      }
      return false;
    } on Object {
      return false;
    }
  }

  /// Asynchronously checks if a model exists in local preferences or the unified directory.
  Future<bool> checkModelDownloaded() async {
    if (isModelDownloaded) return true;
    final sharedPath = await findSharedModelPath();
    if (sharedPath != null) {
      final storage = locator<LocalStorageService>();
      await storage.savePreference(key: _modelStorageKey, data: 'true');
      await storage.savePreference(key: _modelPathKey, data: sharedPath);
      return true;
    }
    return false;
  }

  /// Queries all available catalog models and resolves their download & active status.
  Future<List<LocalLlmModelInfo>> getAvailableModels() async {
    final sharedDir = await getSharedModelsDirectory();
    final storage = locator.isRegistered<LocalStorageService>()
        ? locator<LocalStorageService>()
        : null;

    final activePath = storage?.getPreference(key: PrefKeys.syllabotActiveLocalModelPath) ??
        storage?.getPreference(key: _modelPathKey);
    final activeId = storage?.getPreference(key: PrefKeys.syllabotActiveLocalModelId);

    final resolved = <LocalLlmModelInfo>[];

    for (final catalog in catalogModels) {
      String? foundPath;
      var sizeBytes = 0;
      var downloaded = false;

      final presetFileName = catalog.preset.files.isNotEmpty
          ? catalog.preset.files.first
          : '${catalog.id}.gguf';
      final targetFile = File('${sharedDir.path}/$presetFileName');
      final minExpectedBytes = (catalog.requiredMb * 0.8 * 1024 * 1024).toInt();

      if (targetFile.existsSync()) {
        final len = targetFile.lengthSync();
        if (len >= minExpectedBytes) {
          downloaded = true;
          foundPath = targetFile.path;
          sizeBytes = len;
        } else {
          try {
            targetFile.deleteSync();
          } on Object catch (_) {}
        }
      }

      if (!downloaded) {
        try {
          final hfPath = await ModelManager.fromPreset(catalog.preset).getModelPath();
          if (hfPath != null && File(hfPath).existsSync()) {
            final len = File(hfPath).lengthSync();
            if (len >= minExpectedBytes) {
              downloaded = true;
              foundPath = hfPath;
              sizeBytes = len;
            } else {
              try {
                File(hfPath).deleteSync();
              } on Object catch (_) {}
            }
          }
        } on Object catch (_) {}
      }

      if (!downloaded && activePath != null && File(activePath).existsSync()) {
        final f = File(activePath);
        final fname = f.path.split(Platform.pathSeparator).last.toLowerCase();
        final len = f.lengthSync();
        if ((fname.contains(catalog.id.toLowerCase()) ||
                (catalog.id.contains('smollm2') && fname.contains('smollm')) ||
                (catalog.id.contains('qwen') && fname.contains('qwen'))) &&
            len >= minExpectedBytes) {
          downloaded = true;
          foundPath = activePath;
          sizeBytes = len;
        } else if (len < minExpectedBytes) {
          try {
            f.deleteSync();
          } on Object catch (_) {}
        }
      }

      var partialBytes = 0;
      if (!downloaded) {
        final sharedTemp = File('${sharedDir.path}/$presetFileName.tmp');
        if (sharedTemp.existsSync()) {
          partialBytes = sharedTemp.lengthSync();
        } else {
          try {
            final appDir = await getApplicationDocumentsDirectory();
            final hfTemp = File(
              '${appDir.path}/models/huggingface/${catalog.preset.id.replaceAll('/', '_')}/$presetFileName.tmp',
            );
            if (hfTemp.existsSync()) {
              partialBytes = hfTemp.lengthSync();
            }
          } on Object catch (_) {}
        }
      }

      final isActive = downloaded &&
          (activeId == catalog.id ||
              (activePath != null && foundPath != null && activePath == foundPath) ||
              (activeId == null && resolved.every((m) => !m.isActive) && downloaded));

      resolved.add(
        catalog.copyWith(
          filePath: foundPath,
          isDownloaded: downloaded,
          isActive: isActive,
          fileSizeBytes: sizeBytes,
          partialBytes: partialBytes,
        ),
      );
    }

    return resolved;
  }

  /// Builds high-performance LlamaConfig leveraging GPU/Metal acceleration and optimal 4-thread Performance core allocation.
  static LlamaConfig _buildOptimalConfig(String modelPath) {
    // Mobile ARM big.LITTLE architectures (Snapdragon, Dimensity, Tensor, Apple A/M)
    // require locking threads to physical Performance cores (4 threads).
    // Using >4 threads forces work onto slow Efficiency cores, causing severe barrier latency.
    final cpuCores = Platform.numberOfProcessors;
    final nThreads = (cpuCores >= 4 ? 4 : cpuCores).clamp(2, 4);
    return LlamaConfig(
      modelPath: modelPath,
      nThreads: nThreads,
      nGpuLayers: 99, // Offload all transformer layers to Metal (iOS/macOS) / GPU (Android)
    );
  }

  /// Sets a downloaded local model as the active cognitive reasoning engine.
  Future<void> setActiveModel(String modelId) async {
    final models = await getAvailableModels();
    final target = models.firstWhere(
      (m) => m.id == modelId,
      orElse: () => throw Exception('Model $modelId not found in catalog.'),
    );

    if (!target.isDownloaded || target.filePath == null) {
      throw Exception('Model ${target.name} is not downloaded on this device.');
    }

    final storage = locator<LocalStorageService>();
    await storage.savePreference(
      key: PrefKeys.syllabotActiveLocalModelId,
      data: target.id,
    );
    await storage.savePreference(
      key: PrefKeys.syllabotActiveLocalModelPath,
      data: target.filePath!,
    );
    await storage.savePreference(key: _modelStorageKey, data: 'true');
    await storage.savePreference(key: _modelPathKey, data: target.filePath!);

    try {
      if (FlutterLlama.instance.isModelLoaded) {
        await FlutterLlama.instance.unloadModel();
      }
      await FlutterLlama.instance.loadModel(
        _buildOptimalConfig(target.filePath!),
      );
      _isInitialized = true;
    } on Object catch (e) {
      if (kDebugMode) {
        print('[LocalLlmEngineClient] Failed to reload model $modelId: $e');
      }
    }
  }

  /// Streams model weight download progress from 0.0 to 1.0.
  /// Enforces a single active download per device lock.
  Stream<double> downloadModel({
    PresetModel preset = PresetModels.smolLM2Q4K,
    bool force = false,
  }) async* {
    if (_isGlobalDownloadActive && !force) {
      throw const LocalLlmAlreadyDownloadingException(
        'Another model download is already in progress on this device. Only one download is permitted at a time.',
      );
    }

    final catalogMatch = catalogModels.firstWhere(
      (m) => m.preset.id == preset.id,
      orElse: () => catalogModels.first,
    );

    _isGlobalDownloadActive = true;
    _activeDownloadingModelId = catalogMatch.id;
    _activeDownloadingModelName = catalogMatch.name;
    _activeDownloadProgress = 0;

    _downloadProgressController.add(
      ModelDownloadProgressState(
        modelId: catalogMatch.id,
        modelName: catalogMatch.name,
        progress: 0,
        isDownloading: true,
      ),
    );

    final controller = StreamController<double>();

    unawaited(() async {
      try {
        var lastEmitMs = 0;
        final success = await FlutterLlama.instance.loadPresetModel(
          preset: preset,
          onProgress: (progress) {
            final p = progress.progress.clamp(0.0, 1.0);
            _activeDownloadProgress = p;
            final now = DateTime.now().millisecondsSinceEpoch;

            if (now - lastEmitMs >= 100 || p >= 1.0 || p == 0.0) {
              lastEmitMs = now;
              _downloadProgressController.add(
                ModelDownloadProgressState(
                  modelId: catalogMatch.id,
                  modelName: catalogMatch.name,
                  progress: p,
                  isDownloading: true,
                ),
              );
              if (!controller.isClosed) {
                controller.add(p);
              }
            }
          },
        );

        if (success) {
          _isInitialized = true;
          final storage = locator<LocalStorageService>();
          await storage.savePreference(key: _modelStorageKey, data: 'true');
          final originalPath = FlutterLlama.instance.modelPath ??
              await ModelManager.fromPreset(preset).getModelPath();
          if (originalPath != null && File(originalPath).existsSync()) {
            var finalPath = originalPath;
            try {
              final sharedDir = await getSharedModelsDirectory();
              final fileName = originalPath.split(Platform.pathSeparator).last;
              final targetUnifiedPath = '${sharedDir.path}/$fileName';
              if (originalPath != targetUnifiedPath) {
                final sourceFile = File(originalPath);
                final destFile = await sourceFile.copy(targetUnifiedPath);
                finalPath = destFile.path;
              }
            } on Object catch (copyErr) {
              if (kDebugMode) {
                print('[LocalLlmEngineClient] Unified dir copy note: $copyErr');
              }
            }
            await storage.savePreference(
              key: _modelPathKey,
              data: finalPath,
            );
            await storage.savePreference(
              key: PrefKeys.syllabotActiveLocalModelId,
              data: catalogMatch.id,
            );
            await storage.savePreference(
              key: PrefKeys.syllabotActiveLocalModelPath,
              data: finalPath,
            );
          }

          _downloadProgressController.add(
            ModelDownloadProgressState(
              modelId: catalogMatch.id,
              modelName: catalogMatch.name,
              progress: 1,
              isDownloading: false,
            ),
          );
        } else {
          const msg =
              'Download interrupted (app minimized or connection dropped). Tap Download Model to retry.';
          if (!controller.isClosed) {
            controller.addError(Exception(msg));
          }
          _downloadProgressController.add(
            ModelDownloadProgressState(
              modelId: catalogMatch.id,
              modelName: catalogMatch.name,
              progress: _activeDownloadProgress,
              isDownloading: false,
              errorMessage: msg,
            ),
          );
        }
      } on Object catch (e) {
        if (kDebugMode) {
          print('[LocalLlmEngineClient] Native download error: $e');
        }
        const msg =
            'Download interrupted (app minimized or connection dropped). Tap Download Model to retry.';
        _downloadProgressController.add(
          ModelDownloadProgressState(
            modelId: catalogMatch.id,
            modelName: catalogMatch.name,
            progress: _activeDownloadProgress,
            isDownloading: false,
            errorMessage: msg,
          ),
        );
        if (!controller.isClosed) {
          controller.addError(e);
        }
      } finally {
        _isGlobalDownloadActive = false;
        _activeDownloadingModelId = null;
        _activeDownloadingModelName = null;
        if (!controller.isClosed) {
          await controller.close();
        }
      }
    }());

    yield* controller.stream;
  }

  /// Removes local model weights for a specific model or the current active model across all storage locations.
  Future<void> deleteModel([String? modelId]) async {
    try {
      final storage = locator.isRegistered<LocalStorageService>()
          ? locator<LocalStorageService>()
          : null;
      final available = await getAvailableModels();

      final target = modelId != null
          ? available.firstWhere((m) => m.id == modelId, orElse: () => available.first)
          : available.firstWhere((m) => m.isDownloaded, orElse: () => available.first);

      // 1. Unload native model if currently loaded
      try {
        if (FlutterLlama.instance.isModelLoaded) {
          await FlutterLlama.instance.unloadModel();
        }
      } on Object catch (_) {}

      // 2. Delete file from target.filePath if present
      if (target.filePath != null && File(target.filePath!).existsSync()) {
        try {
          await File(target.filePath!).delete();
        } on Object catch (_) {}
      }

      // 3. Delete HuggingFace model cache directory via ModelManager
      try {
        await ModelManager.fromPreset(target.preset).deleteModel();
      } on Object catch (_) {}

      final appDir = await getApplicationDocumentsDirectory();
      final hfDir = Directory(
        '${appDir.path}/models/huggingface/${target.preset.id.replaceAll('/', '_')}',
      );
      if (hfDir.existsSync()) {
        try {
          hfDir.deleteSync(recursive: true);
        } on Object catch (_) {}
      }

      // 4. Delete model file in unified kortex_models directory
      final sharedDir = await getSharedModelsDirectory();
      final presetFileName = target.preset.files.isNotEmpty
          ? target.preset.files.first
          : '${target.id}.gguf';
      final sharedFile = File('${sharedDir.path}/$presetFileName');
      if (sharedFile.existsSync()) {
        try {
          sharedFile.deleteSync();
        } on Object catch (_) {}
      }

      final tempFile = File('${sharedDir.path}/$presetFileName.tmp');
      if (tempFile.existsSync()) {
        try {
          tempFile.deleteSync();
        } on Object catch (_) {}
      }

      // 5. Clean up preferences
      final activePath = storage?.getPreference(key: PrefKeys.syllabotActiveLocalModelPath) ??
          storage?.getPreference(key: _modelPathKey);
      final activeId = storage?.getPreference(key: PrefKeys.syllabotActiveLocalModelId);

      if (activePath == target.filePath || activeId == target.id || modelId == null) {
        await storage?.deletePreference(key: PrefKeys.syllabotActiveLocalModelId);
        await storage?.deletePreference(key: PrefKeys.syllabotActiveLocalModelPath);
        await storage?.deletePreference(key: _modelStorageKey);
        await storage?.deletePreference(key: _modelPathKey);

        final remaining = (await getAvailableModels()).where((m) => m.isDownloaded).toList();
        if (remaining.isNotEmpty) {
          await setActiveModel(remaining.first.id);
        } else {
          _isInitialized = false;
        }
      }
    } on Object catch (e) {
      if (kDebugMode) {
        print('[LocalLlmEngineClient] Error deleting model $modelId: $e');
      }
    }
  }

  /// Purges a corrupted or uninitializable model file and all associated storage locations and preferences.
  Future<void> _purgeCorruptedModel(String modelPath) async {
    try {
      if (FlutterLlama.instance.isModelLoaded) {
        await FlutterLlama.instance.unloadModel();
      }
    } on Object catch (_) {}

    try {
      final f = File(modelPath);
      if (f.existsSync()) {
        f.deleteSync();
      }
    } on Object catch (_) {}

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final hfDir = Directory('${appDir.path}/models/huggingface');
      if (hfDir.existsSync()) {
        await for (final entity in hfDir.list(recursive: true)) {
          if (entity is File) {
            try {
              entity.deleteSync();
            } on Object catch (_) {}
          }
        }
      }
    } on Object catch (_) {}

    final storage = locator.isRegistered<LocalStorageService>()
        ? locator<LocalStorageService>()
        : null;
    await storage?.deletePreference(key: PrefKeys.syllabotActiveLocalModelId);
    await storage?.deletePreference(key: PrefKeys.syllabotActiveLocalModelPath);
    await storage?.deletePreference(key: _modelStorageKey);
    await storage?.deletePreference(key: _modelPathKey);

    _isInitialized = false;
  }

  /// Initializes the cognitive engine context using active model preference.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final storage = locator.isRegistered<LocalStorageService>()
          ? locator<LocalStorageService>()
          : null;
      var savedPath = storage?.getPreference(key: PrefKeys.syllabotActiveLocalModelPath) ??
          storage?.getPreference(key: _modelPathKey);

      if (savedPath == null ||
          savedPath.isEmpty ||
          !File(savedPath).existsSync()) {
        savedPath = await findSharedModelPath();
        if (savedPath != null && storage != null) {
          await storage.savePreference(key: _modelStorageKey, data: 'true');
          await storage.savePreference(key: _modelPathKey, data: savedPath);
          await storage.savePreference(
            key: PrefKeys.syllabotActiveLocalModelPath,
            data: savedPath,
          );
        }
      }

      if (savedPath != null &&
          savedPath.isNotEmpty &&
          File(savedPath).existsSync() &&
          !FlutterLlama.instance.isModelLoaded) {
        try {
          await FlutterLlama.instance.loadModel(
            _buildOptimalConfig(savedPath),
          );
          _isInitialized = true;
        } on Object catch (e) {
          if (kDebugMode) {
            print('[LocalLlmEngineClient] Corrupt or invalid model detected at $savedPath: $e');
          }
          await _purgeCorruptedModel(savedPath);
          _isInitialized = false;
          rethrow;
        }
      } else {
        _isInitialized = FlutterLlama.instance.isModelLoaded;
      }
    } on Object catch (e) {
      _isInitialized = false;
      if (kDebugMode) {
        print('[LocalLlmEngineClient] Initialization error: $e');
      }
    }
  }

  bool get isInitialized => _isInitialized;

  /// Generates a streaming academic response dynamically tailored to prompt.
  Stream<String> generate({
    required String prompt,
    required String systemInstruction,
    SocraticMode socraticMode = SocraticMode.stepByStep,
    List<ChatMessageEntity> contextHistory = const [],
    int maxTokens = 1024,
    double temperature = 0.7,
  }) async* {
    if (!_isInitialized) {
      await initialize();
    }

    if (!isModelDownloaded && !FlutterLlama.instance.isModelLoaded) {
      throw const LocalLlmNotDownloadedException(
        'On-device neural engine is not downloaded. Please download the model weights to enable offline reasoning.',
      );
    }

    final formattedPrompt = _buildPrompt(
      prompt: prompt,
      systemInstruction: systemInstruction,
      mode: socraticMode,
      contextHistory: contextHistory,
    );

    if (FlutterLlama.instance.isModelLoaded) {
      var yieldedTokenCount = 0;
      final specialTokenRegex = RegExp(
        r'<\|[a-zA-Z0-9_\-]+\|>|<think>[\s\S]*?<\/think>|<\/?think>|</s>',
      );

      const stopTokens = [
        '<|im_end|>',
        '<|im_start|>',
        '<|eot_id|>',
        '<|endoftext|>',
        '<|end_of_text|>',
        '</s>',
        '<|end_of_sentence|>',
      ];

      try {
        final stream = FlutterLlama.instance.generateStream(
          GenerationParams(
            prompt: formattedPrompt,
            maxTokens: maxTokens > 384 ? 384 : maxTokens,
            temperature: 0.6,
            repeatPenalty: 1.15,
            stopSequences: stopTokens,
          ),
        );

        await for (final rawToken in stream) {
          if (stopTokens.any(rawToken.contains)) {
            break;
          }
          final cleanToken = rawToken.replaceAll(specialTokenRegex, '');
          if (cleanToken.isNotEmpty) {
            yieldedTokenCount++;
            yield cleanToken;
          }
        }

        if (yieldedTokenCount > 0) {
          return;
        }
      } on Object catch (e) {
        if (kDebugMode) {
          print(
            '[LocalLlmEngineClient] Generation exception in native llama: $e',
          );
        }
        throw LocalLlmGenerationException(
          'On-device generation failed ($e). Ensure device has sufficient memory or switch to Cloud AI.',
        );
      }
    }

    throw const LocalLlmGenerationException(
      'On-device neural engine could not generate a response. Please check device memory or use Cloud AI.',
    );
  }

  String _buildPrompt({
    required String prompt,
    required String systemInstruction,
    required SocraticMode mode,
    List<ChatMessageEntity> contextHistory = const [],
  }) {
    final storage = locator.isRegistered<LocalStorageService>()
        ? locator<LocalStorageService>()
        : null;
    final activeId =
        storage?.getPreference(key: PrefKeys.syllabotActiveLocalModelId) ?? '';
    final activePath =
        storage?.getPreference(key: PrefKeys.syllabotActiveLocalModelPath) ?? '';
    final isLlamaModel = activeId.toLowerCase().contains('llama') ||
        activePath.toLowerCase().contains('llama');

    final trimmedPrompt = prompt.trim();
    final history = contextHistory
        .where(
          (m) =>
              m.text.trim().isNotEmpty &&
              m.text.trim().toLowerCase() != trimmedPrompt.toLowerCase(),
        )
        .toList();
    final recentHistory = history.length > 2
        ? history.sublist(history.length - 2)
        : history;

    if (isLlamaModel) {
      final buffer = StringBuffer()
        ..write('<|begin_of_text|><|start_header_id|>system<|end_header_id|>\n\n')
        ..writeln('You are Syllabot, an expert educational tutor.')
        ..writeln('Provide direct, accurate, and concise explanations with clear definitions.')
        ..writeln('Do not repeat yourself or loop.');
      if (systemInstruction.trim().isNotEmpty) {
        buffer.writeln(systemInstruction);
      }
      buffer.write('<|eot_id|>');

      for (final msg in recentHistory) {
        final role = msg.sender == MessageSender.user ? 'user' : 'assistant';
        final text = msg.text.length > 350
            ? '${msg.text.substring(0, 350)}...'
            : msg.text;
        buffer
          ..write('<|start_header_id|>$role<|end_header_id|>\n\n')
          ..writeln(text)
          ..write('<|eot_id|>');
      }

      buffer
        ..write('<|start_header_id|>user<|end_header_id|>\n\n')
        ..writeln(trimmedPrompt)
        ..write('<|eot_id|><|start_header_id|>assistant<|end_header_id|>\n\n');
      return buffer.toString();
    }

    final buffer = StringBuffer()
      ..writeln('<|im_start|>system')
      ..writeln('You are Syllabot, an expert educational tutor.')
      ..writeln(
        'Provide direct, accurate, and concise explanations with clear definitions.',
      )
      ..writeln('Do not repeat yourself or loop.');
    if (systemInstruction.trim().isNotEmpty) {
      buffer.writeln(systemInstruction);
    }
    buffer.writeln('<|im_end|>');

    for (final msg in recentHistory) {
      final role = msg.sender == MessageSender.user ? 'user' : 'assistant';
      final text = msg.text.length > 350
          ? '${msg.text.substring(0, 350)}...'
          : msg.text;
      buffer
        ..writeln('<|im_start|>$role')
        ..writeln(text)
        ..writeln('<|im_end|>');
    }

    buffer
      ..writeln('<|im_start|>user')
      ..writeln(trimmedPrompt)
      ..writeln('<|im_end|>')
      ..writeln('<|im_start|>assistant');
    return buffer.toString();
  }

  /// Disposes the on-device model context.
  Future<void> dispose() async {
    try {
      if (FlutterLlama.instance.isModelLoaded) {
        await FlutterLlama.instance.unloadModel();
      }
    } on Object {
      // Ignored
    }
    _isInitialized = false;
  }
}

class LocalLlmNotDownloadedException implements Exception {
  const LocalLlmNotDownloadedException(this.message);
  final String message;

  @override
  String toString() => 'LocalLlmNotDownloadedException: $message';
}

class LocalLlmAlreadyDownloadingException implements Exception {
  const LocalLlmAlreadyDownloadingException(this.message);
  final String message;

  @override
  String toString() => 'LocalLlmAlreadyDownloadingException: $message';
}

class LocalLlmGenerationException implements Exception {
  const LocalLlmGenerationException(this.message);
  final String message;

  @override
  String toString() => 'LocalLlmGenerationException: $message';
}
