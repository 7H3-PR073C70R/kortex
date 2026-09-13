import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_llama/flutter_llama.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/syllabot/domain/entities/chat_message_entity.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';
import 'package:path_provider/path_provider.dart';

/// Intelligent on-device local LLM client for Syllabot AI.
///
/// Powered by `flutter_llama` for native quantized GGUF on-device inference,
/// supporting streaming token generation, dynamic model lifecycle management,
/// and pedagogical Socratic instruction synthesis.
class LocalLlmEngineClient {
  LocalLlmEngineClient();

  static const String _modelStorageKey = '__local_llm_model_downloaded';
  static const String _modelPathKey = '__local_llm_model_path';
  static const String modelsDirectoryName = 'kortex_models';
  bool _isInitialized = false;

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
            .where((f) => f.path.endsWith('.gguf') && f.lengthSync() >= 50 * 1024 * 1024)
            .toList();
        if (ggufFiles.isNotEmpty) {
          ggufFiles.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
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
      final isMarked = storage.getPreference(key: _modelStorageKey) == 'true';
      final path = storage.getPreference(key: _modelPathKey);
      if (isMarked && path != null && path.isNotEmpty && File(path).existsSync()) {
        return true;
      }
      if (path != null && path.isNotEmpty && File(path).existsSync() && File(path).lengthSync() >= 50 * 1024 * 1024) {
        return true;
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

  /// Streams real model weight download progress from 0.0 to 1.0.
  /// Skips downloading if model weights already exist in unified storage.
  Stream<double> downloadModel({
    PresetModel preset = PresetModels.smolLM2Q4K,
  }) async* {
    // Prevent duplicate model download if already present
    if (await checkModelDownloaded()) {
      _isInitialized = true;
      yield 1.0;
      return;
    }

    final controller = StreamController<double>();

    unawaited(() async {
      try {
        final success = await FlutterLlama.instance.loadPresetModel(
          preset: preset,
          onProgress: (progress) {
            if (!controller.isClosed) {
              controller.add(progress.progress.clamp(0.0, 1.0));
            }
          },
        );

        if (success) {
          _isInitialized = true;
          final storage = locator<LocalStorageService>();
          await storage.savePreference(key: _modelStorageKey, data: 'true');
          final originalPath = FlutterLlama.instance.modelPath;
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
          }
        } else {
          if (!controller.isClosed) {
            controller.addError(
              Exception('Failed to download and initialize on-device LLM.'),
            );
          }
        }
      } on Object catch (e) {
        if (kDebugMode) {
          print('[LocalLlmEngineClient] Native download error: $e');
        }
        if (!controller.isClosed) {
          controller.addError(e);
        }
      } finally {
        if (!controller.isClosed) {
          await controller.close();
        }
      }
    }());

    yield* controller.stream;
  }

  /// Removes local model weights and frees memory.
  Future<void> deleteModel() async {
    try {
      if (FlutterLlama.instance.isModelLoaded) {
        await FlutterLlama.instance.unloadModel();
      }
    } on Object catch (e) {
      if (kDebugMode) {
        print('[LocalLlmEngineClient] Error unloading model: $e');
      }
    }

    try {
      final storage = locator<LocalStorageService>();
      final savedPath = storage.getPreference(key: _modelPathKey);
      if (savedPath != null && savedPath.isNotEmpty) {
        final file = File(savedPath);
        if (file.existsSync()) {
          await file.delete();
        }
      }
      await storage.deletePreference(key: _modelStorageKey);
      await storage.deletePreference(key: _modelPathKey);
    } on Object {
      // Ignored
    }
    _isInitialized = false;
  }

  /// Initializes the cognitive engine context.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final storage = locator<LocalStorageService>();
      var savedPath = storage.getPreference(key: _modelPathKey);

      if (savedPath == null || savedPath.isEmpty || !File(savedPath).existsSync()) {
        savedPath = await findSharedModelPath();
        if (savedPath != null) {
          await storage.savePreference(key: _modelStorageKey, data: 'true');
          await storage.savePreference(key: _modelPathKey, data: savedPath);
        }
      }

      if (savedPath != null &&
          savedPath.isNotEmpty &&
          File(savedPath).existsSync() &&
          !FlutterLlama.instance.isModelLoaded) {
        await FlutterLlama.instance.loadModel(
          LlamaConfig(
            modelPath: savedPath,
          ),
        );
      }
    } on Object {
      // Native binding unavailable in unit test harness
    }

    _isInitialized = true;
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
        'On-device neural engine is not downloaded. Please download the 248MB model weights to enable offline reasoning.',
      );
    }

    final formattedPrompt = _buildPrompt(
      prompt: prompt,
      systemInstruction: systemInstruction,
      mode: socraticMode,
      contextHistory: contextHistory,
    );

    // 1. If native model is loaded in memory, stream directly from llama.cpp
    if (FlutterLlama.instance.isModelLoaded) {
      var yieldedCharCount = 0;
      final specialTokenRegex = RegExp(
        r'<\|[a-zA-Z0-9_\-]+\|>|<think>[\s\S]*?<\/think>|<\/?think>',
      );

      try {
        final stream = FlutterLlama.instance.generateStream(
          GenerationParams(
            prompt: formattedPrompt,
            maxTokens: maxTokens > 512 ? 512 : maxTokens,
            temperature: 0.35,
            repeatPenalty: 1.25,
            stopSequences: const ['<|im_end|>', '<|endoftext|>', '<|im_start|>'],
          ),
        );

        await for (final token in stream) {
          final cleanToken = token.replaceAll(specialTokenRegex, '');
          if (cleanToken.isNotEmpty) {
            yieldedCharCount += cleanToken.trim().length;
            yield cleanToken;
          }
        }

        if (yieldedCharCount > 0) {
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
    final buffer = StringBuffer()
      ..writeln('<|im_start|>system')
      ..writeln('You are Syllabot, an expert educational tutor.')
      ..writeln('Provide direct, accurate, and concise explanations with clear definitions and examples.')
      ..writeln('Do not repeat yourself or loop.');
    if (systemInstruction.trim().isNotEmpty) {
      buffer.writeln(systemInstruction);
    }
    buffer.writeln('<|im_end|>');

    final history =
        contextHistory.where((m) => m.text.trim().isNotEmpty).toList();
    // Take the last 4 most recent turns to keep edge model focused and within context budget
    final recentHistory =
        history.length > 4 ? history.sublist(history.length - 4) : history;
    for (final msg in recentHistory) {
      final role = msg.sender == MessageSender.user ? 'user' : 'assistant';
      final text = msg.text.length > 800
          ? '${msg.text.substring(0, 800)}...'
          : msg.text;
      buffer
        ..writeln('<|im_start|>$role')
        ..writeln(text)
        ..writeln('<|im_end|>');
    }

    buffer
      ..writeln('<|im_start|>user')
      ..writeln(prompt)
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

class LocalLlmGenerationException implements Exception {
  const LocalLlmGenerationException(this.message);
  final String message;

  @override
  String toString() => 'LocalLlmGenerationException: $message';
}
