import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../models/model_source.dart';

/// Информация о файле в репозитории HuggingFace
class HuggingFaceFile {
  final String name;
  final String oid;
  final int size;
  final String? lfs;
  
  const HuggingFaceFile({
    required this.name,
    required this.oid,
    required this.size,
    this.lfs,
  });
  
  factory HuggingFaceFile.fromJson(Map<String, dynamic> json) {
    return HuggingFaceFile(
      name: json['path'] as String,
      oid: json['oid'] as String? ?? '',
      size: json['size'] as int? ?? 0,
      lfs: json['lfs'] as String?,
    );
  }
  
  bool get isGGUF => name.toLowerCase().endsWith('.gguf');
  bool get isSafeTensors => name.toLowerCase().endsWith('.safetensors');
  
  String get sizeFormatted {
    final mb = size / 1024 / 1024;
    if (mb < 1024) {
      return '${mb.toStringAsFixed(1)} MB';
    }
    return '${(mb / 1024).toStringAsFixed(2)} GB';
  }
}

/// Сервис для скачивания моделей с HuggingFace
class HuggingFaceDownloader {
  static const String baseUrl = 'https://huggingface.co';
  static const String apiUrl = 'https://huggingface.co/api';
  
  /// Получить список файлов в репозитории
  Future<List<HuggingFaceFile>> listFiles({
    required String modelId,
    String branch = 'main',
  }) async {
    try {
      final url = '$apiUrl/models/$modelId/tree/$branch';
      
      if (kDebugMode) {
        print('[HuggingFaceDownloader] Fetching file list from: $url');
      }
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode != 200) {
        throw Exception('Failed to list files: ${response.statusCode}');
      }
      
      final List<dynamic> files = jsonDecode(response.body) as List<dynamic>;
      
      return files
          .map((f) => HuggingFaceFile.fromJson(f as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('[HuggingFaceDownloader] Error listing files: $e');
      }
      rethrow;
    }
  }
  
  /// Найти GGUF файлы в репозитории
  Future<List<HuggingFaceFile>> findGGUFFiles(String modelId) async {
    final files = await listFiles(modelId: modelId);
    return files.where((f) => f.isGGUF).toList();
  }
  
  /// Скачать файл с HuggingFace
  Future<String> downloadFile({
    required String modelId,
    required String fileName,
    String branch = 'main',
    DownloadProgressCallback? onProgress,
    bool force = false,
  }) async {
    try {
      if (kDebugMode) {
        print('[HuggingFaceDownloader] Downloading: $modelId/$fileName');
      }
      
      // Получаем директорию для хранения моделей
      final appDir = await getApplicationDocumentsDirectory();
      final modelsDir = Directory(path.join(appDir.path, 'models', 'huggingface'));
      
      if (!await modelsDir.exists()) {
        await modelsDir.create(recursive: true);
      }
      
      // Создаем поддиректорию для конкретной модели
      final modelDir = Directory(
        path.join(modelsDir.path, modelId.replaceAll('/', '_')),
      );
      
      if (!await modelDir.exists()) {
        await modelDir.create(recursive: true);
      }
      
      final filePath = path.join(modelDir.path, fileName);
      final file = File(filePath);
      
      // Проверяем, не скачан ли уже файл
      if (await file.exists() && !force) {
        final size = await file.length();
        
        onProgress?.call(DownloadProgress(
          progress: 1.0,
          status: 'Файл уже существует',
          downloadedBytes: size,
          totalBytes: size,
        ));
        
        if (kDebugMode) {
          print('[HuggingFaceDownloader] File already exists: $filePath');
        }
        
        return filePath;
      }
      
      // Формируем URL для скачивания
      final url = '$baseUrl/$modelId/resolve/$branch/$fileName';
      
      if (kDebugMode) {
        print('[HuggingFaceDownloader] Downloading from: $url');
      }
      
      onProgress?.call(const DownloadProgress(
        progress: 0.0,
        status: 'Connecting to HuggingFace...',
      ));
      
      final client = HttpClient();
      final uri = Uri.parse(url);
      final request = await client.getUrl(uri);
      final response = await request.close();
      
      if (response.statusCode != 200) {
        client.close();
        throw Exception('Download failed: HTTP ${response.statusCode}');
      }
      
      final contentLength = response.contentLength;
      var receivedBytes = 0;
      final sink = file.openWrite();
      
      try {
        onProgress?.call(DownloadProgress(
          progress: 0.0,
          status: 'Downloading...',
          downloadedBytes: 0,
          totalBytes: contentLength > 0 ? contentLength : null,
        ));
        
        await for (final chunk in response) {
          sink.add(chunk);
          receivedBytes += chunk.length;
          
          if (contentLength > 0) {
            final progress = receivedBytes / contentLength;
            onProgress?.call(DownloadProgress(
              progress: progress,
              status: 'Downloading: ${(receivedBytes / 1024 / 1024).toStringAsFixed(1)} MB / ${(contentLength / 1024 / 1024).toStringAsFixed(1)} MB',
              downloadedBytes: receivedBytes,
              totalBytes: contentLength,
            ));
          } else {
            onProgress?.call(DownloadProgress(
              progress: 0.5,
              status: 'Downloading: ${(receivedBytes / 1024 / 1024).toStringAsFixed(1)} MB',
              downloadedBytes: receivedBytes,
            ));
          }
        }
      } finally {
        await sink.flush();
        await sink.close();
        client.close();
      }
      
      // Проверяем размер скачанного файла
      final fileSize = await file.length();
      
      if (contentLength > 0 && fileSize != contentLength) {
        await file.delete();
        throw Exception('Download incomplete: expected $contentLength bytes, got $fileSize');
      }
      
      onProgress?.call(DownloadProgress(
        progress: 1.0,
        status: 'Загрузка завершена',
        downloadedBytes: fileSize,
        totalBytes: fileSize,
      ));
      
      if (kDebugMode) {
        print('[HuggingFaceDownloader] Download completed: $filePath');
        print('[HuggingFaceDownloader] File size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
      }
      
      return filePath;
    } catch (e) {
      if (kDebugMode) {
        print('[HuggingFaceDownloader] Download failed: $e');
      }
      
      throw ModelDownloadException(modelId, 'Failed to download from HuggingFace', e);
    }
  }
  
  /// Скачать GGUF модель (автоматически найти и скачать первый GGUF файл)
  Future<String> downloadGGUFModel({
    required String modelId,
    String? specificFile,
    DownloadProgressCallback? onProgress,
  }) async {
    try {
      // Если указан конкретный файл, скачиваем его
      if (specificFile != null) {
        return await downloadFile(
          modelId: modelId,
          fileName: specificFile,
          onProgress: onProgress,
        );
      }
      
      // Иначе ищем GGUF файлы
      onProgress?.call(const DownloadProgress(
        progress: 0.0,
        status: 'Поиск GGUF файлов...',
      ));
      
      final ggufFiles = await findGGUFFiles(modelId);
      
      if (ggufFiles.isEmpty) {
        // Пробуем распространённые имена
        final commonNames = [
          'model.gguf',
          'ggml-model-q4_0.gguf',
          'ggml-model-q4_1.gguf',
          'ggml-model-q5_0.gguf',
          'ggml-model-q5_1.gguf',
          'ggml-model-q8_0.gguf',
          'ggml-model-f16.gguf',
          '${modelId.split('/').last}.gguf',
        ];
        
        for (final name in commonNames) {
          try {
            return await downloadFile(
              modelId: modelId,
              fileName: name,
              onProgress: onProgress,
            );
          } catch (e) {
            // Продолжаем поиск
            continue;
          }
        }
        
        throw ModelNotFoundException(modelId, 'No GGUF files found');
      }
      
      // Скачиваем первый найденный GGUF файл
      final firstGGUF = ggufFiles.first;
      
      if (kDebugMode) {
        print('[HuggingFaceDownloader] Found GGUF file: ${firstGGUF.name} (${firstGGUF.sizeFormatted})');
      }
      
      return await downloadFile(
        modelId: modelId,
        fileName: firstGGUF.name,
        onProgress: onProgress,
      );
    } catch (e) {
      if (kDebugMode) {
        print('[HuggingFaceDownloader] Error downloading GGUF model: $e');
      }
      rethrow;
    }
  }
  
  /// Получить путь к скачанной модели
  Future<String?> getModelPath(String modelId, String fileName) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final modelDir = path.join(
        appDir.path,
        'models',
        'huggingface',
        modelId.replaceAll('/', '_'),
      );
      final filePath = path.join(modelDir, fileName);
      final file = File(filePath);
      
      if (await file.exists()) {
        return filePath;
      }
      
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('[HuggingFaceDownloader] Error getting model path: $e');
      }
      return null;
    }
  }
  
  /// Получить список скачанных моделей
  Future<List<String>> getDownloadedModels() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final modelsDir = Directory(path.join(appDir.path, 'models', 'huggingface'));
      
      if (!await modelsDir.exists()) {
        return [];
      }
      
      final models = <String>[];
      
      await for (var entity in modelsDir.list()) {
        if (entity is Directory) {
          final modelName = path.basename(entity.path);
          models.add(modelName);
        }
      }
      
      return models;
    } catch (e) {
      if (kDebugMode) {
        print('[HuggingFaceDownloader] Error listing downloaded models: $e');
      }
      return [];
    }
  }
  
  /// Удалить скачанную модель
  Future<bool> deleteModel(String modelId) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final modelDir = Directory(path.join(
        appDir.path,
        'models',
        'huggingface',
        modelId.replaceAll('/', '_'),
      ));
      
      if (await modelDir.exists()) {
        await modelDir.delete(recursive: true);
        return true;
      }
      
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('[HuggingFaceDownloader] Error deleting model: $e');
      }
      return false;
    }
  }
  
  /// Получить размер скачанной модели
  Future<int> getModelSize(String modelId) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final modelDir = Directory(path.join(
        appDir.path,
        'models',
        'huggingface',
        modelId.replaceAll('/', '_'),
      ));
      
      if (!await modelDir.exists()) {
        return 0;
      }
      
      var totalSize = 0;
      
      await for (var entity in modelDir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
      
      return totalSize;
    } catch (e) {
      if (kDebugMode) {
        print('[HuggingFaceDownloader] Error getting model size: $e');
      }
      return 0;
    }
  }
}


