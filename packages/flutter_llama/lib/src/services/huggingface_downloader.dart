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
    int fileSize = json['size'] as int? ?? 0;
    String? lfsOid;
    if (json['lfs'] is Map) {
      final lfsMap = json['lfs'] as Map<String, dynamic>;
      lfsOid = lfsMap['oid']?.toString();
      fileSize = (lfsMap['size'] as int?) ?? fileSize;
    } else if (json['lfs'] is String) {
      lfsOid = json['lfs'] as String;
    }

    return HuggingFaceFile(
      name: json['path'] as String? ?? json['rpath'] as String? ?? '',
      oid: json['oid'] as String? ?? lfsOid ?? '',
      size: fileSize,
      lfs: lfsOid,
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
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'Kortex/1.0 (Mobile)'},
      );
      
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
      
      final appDir = await getApplicationDocumentsDirectory();
      final modelsDir = Directory(path.join(appDir.path, 'models', 'huggingface'));
      
      if (!await modelsDir.exists()) {
        await modelsDir.create(recursive: true);
      }
      
      final modelDir = Directory(
        path.join(modelsDir.path, modelId.replaceAll('/', '_')),
      );
      
      if (!await modelDir.exists()) {
        await modelDir.create(recursive: true);
      }
      
      final filePath = path.join(modelDir.path, fileName);
      final tempFilePath = '$filePath.tmp';
      final file = File(filePath);
      final tempFile = File(tempFilePath);

      // Clean up stale temporary download file if present
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }

      if (await file.exists() && !force) {
        final size = await file.length();
        // Verify file is complete (at least 80MB) rather than accepting partial downloads
        if (size >= 80 * 1024 * 1024) {
          onProgress?.call(DownloadProgress(
            progress: 1.0,
            status: 'Model file verified',
            downloadedBytes: size,
            totalBytes: size,
          ));

          if (kDebugMode) {
            print('[HuggingFaceDownloader] File already exists and verified: $filePath ($size bytes)');
          }

          return filePath;
        } else {
          if (kDebugMode) {
            print('[HuggingFaceDownloader] Deleting incomplete/corrupted file ($size bytes): $filePath');
          }
          try {
            await file.delete();
          } catch (_) {}
        }
      }

      final url = '$baseUrl/$modelId/resolve/$branch/$fileName';

      if (kDebugMode) {
        print('[HuggingFaceDownloader] Downloading from: $url');
      }

      onProgress?.call(const DownloadProgress(
        progress: 0.0,
        status: 'Connecting to HuggingFace...',
      ));

      final client = HttpClient();
      var currentUri = Uri.parse(url);
      HttpClientResponse? response;

      for (var redirectCount = 0; redirectCount < 10; redirectCount++) {
        final request = await client.getUrl(currentUri);
        request.headers.set(HttpHeaders.userAgentHeader, 'Kortex/1.0 (Mobile)');
        request.followRedirects = false;
        final res = await request.close();

        if (res.statusCode == HttpStatus.movedPermanently ||
            res.statusCode == HttpStatus.found ||
            res.statusCode == HttpStatus.seeOther ||
            res.statusCode == HttpStatus.temporaryRedirect ||
            res.statusCode == 308) {
          final location = res.headers.value(HttpHeaders.locationHeader);
          if (location != null) {
            currentUri = currentUri.resolve(location);
            await res.drain();
            continue;
          }
        }
        response = res;
        break;
      }

      if (response == null || response.statusCode != 200) {
        final status = response?.statusCode;
        client.close();
        throw Exception('Download failed: HTTP $status');
      }

      final contentLength = response.contentLength;
      var receivedBytes = 0;
      final sink = tempFile.openWrite();

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
      } catch (e) {
        try {
          await sink.close();
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        } catch (_) {}
        rethrow;
      } finally {
        await sink.flush();
        await sink.close();
        client.close();
      }

      final tempSize = await tempFile.length();

      if (contentLength > 0 && tempSize != contentLength) {
        try {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        } catch (_) {}
        throw Exception('Download incomplete: expected $contentLength bytes, got $tempSize');
      }

      // Download complete & verified! Atomically promote temp file to final .gguf model file
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
      await tempFile.rename(filePath);

      onProgress?.call(DownloadProgress(
        progress: 1.0,
        status: 'Download completed',
        downloadedBytes: tempSize,
        totalBytes: tempSize,
      ));

      if (kDebugMode) {
        print('[HuggingFaceDownloader] Download completed and verified: $filePath');
        print('[HuggingFaceDownloader] File size: ${(tempSize / 1024 / 1024).toStringAsFixed(2)} MB');
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
      if (specificFile != null) {
        return await downloadFile(
          modelId: modelId,
          fileName: specificFile,
          onProgress: onProgress,
        );
      }
      
      onProgress?.call(const DownloadProgress(
        progress: 0.0,
        status: 'Поиск GGUF файлов...',
      ));
      
      final ggufFiles = await findGGUFFiles(modelId);
      
      if (ggufFiles.isEmpty) {
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
            continue;
          }
        }
        
        throw ModelNotFoundException(modelId, 'No GGUF files found');
      }
      
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
        if (await file.length() >= 80 * 1024 * 1024) {
          return filePath;
        }
        try {
          await file.delete();
        } catch (_) {}
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


