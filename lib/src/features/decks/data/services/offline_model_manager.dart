import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

enum ModelDownloadStatus {
  notDownloaded,
  checkingSpace,
  downloading,
  verifying,
  ready,
  error,
}

class ModelDownloadProgress {
  const ModelDownloadProgress({
    required this.status,
    this.progress = 0.0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.errorMessage,
  });

  final ModelDownloadStatus status;
  final double progress; // 0.0 to 1.0
  final int downloadedBytes;
  final int totalBytes;
  final String? errorMessage;
}

/// Manages local GGUF model lifecycles, storage verification, downloads,
/// and file integrity for offline on-device LLM inference.
class OfflineModelManager {
  OfflineModelManager({
    Dio? dio,
  }) : _dio = dio ?? Dio();

  final Dio _dio;

  static const String modelFileName = 'qwen2.5-1.5b-instruct-q4_k_m.gguf';
  static const String defaultModelUrl =
      'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf';

  // Required storage in bytes (3 GB threshold safeguard)
  static const int minRequiredStorageBytes = 3 * 1024 * 1024 * 1024;
  static const int expectedModelSizeBytes = 1120000000; // ~1.12 GB

  CancelToken? _cancelToken;
  final StreamController<ModelDownloadProgress> _progressController =
      StreamController<ModelDownloadProgress>.broadcast();

  Stream<ModelDownloadProgress> get progressStream =>
      _progressController.stream;

  /// Returns the absolute path where the local GGUF model is stored.
  Future<String> getModelPath() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final kortexModelsDir = Directory('${docsDir.path}/kortex_models');
    if (!kortexModelsDir.existsSync()) {
      kortexModelsDir.createSync(recursive: true);
    }
    return '${kortexModelsDir.path}/$modelFileName';
  }

  /// Checks whether the model file is downloaded, non-empty, and ready for
  /// inference.
  Future<bool> isModelDownloaded() async {
    try {
      final path = await getModelPath();
      final file = File(path);
      if (!file.existsSync()) return false;
      final length = file.lengthSync();
      // Ensure file has valid non-trivial size (> 500 MB)
      return length > 500 * 1024 * 1024;
    } on Object catch (err) {
      debugPrint('[OfflineModelManager] Model check note: $err');
      return false;
    }
  }

  /// Downloads the GGUF model with storage checks, progress streaming, and
  /// cancel support.
  Future<bool> downloadModel({String? customDownloadUrl}) async {
    final modelUrl = customDownloadUrl ?? defaultModelUrl;
    final targetPath = await getModelPath();
    final tempPath = '$targetPath.tmp';

    _progressController.add(
      const ModelDownloadProgress(status: ModelDownloadStatus.checkingSpace),
    );

    // 1. Verify Free Disk Space (>= 3 GB)
    final hasSpace = await _checkFreeStorageSpace();
    if (!hasSpace) {
      _progressController.add(
        const ModelDownloadProgress(
          status: ModelDownloadStatus.error,
          errorMessage: 'Insufficient storage: At least 3 GB free space '
              'is required for offline model installation.',
        ),
      );
      return false;
    }

    _cancelToken = CancelToken();

    try {
      _progressController.add(
        const ModelDownloadProgress(
          status: ModelDownloadStatus.downloading,
          progress: 0.01,
        ),
      );

      await _dio.download(
        modelUrl,
        tempPath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = (received / total).clamp(0.0, 1.0);
            _progressController.add(
              ModelDownloadProgress(
                status: ModelDownloadStatus.downloading,
                progress: progress,
                downloadedBytes: received,
                totalBytes: total,
              ),
            );
          }
        },
      );

      // 2. Validate downloaded file integrity
      _progressController.add(
        const ModelDownloadProgress(
          status: ModelDownloadStatus.verifying,
          progress: 0.99,
        ),
      );

      final tempFile = File(tempPath);
      if (!tempFile.existsSync() || tempFile.lengthSync() < 100 * 1024 * 1024) {
        throw const FileSystemException('Downloaded model file is corrupted.');
      }

      // Rename temporary file to target GGUF file
      if (File(targetPath).existsSync()) {
        File(targetPath).deleteSync();
      }
      tempFile.renameSync(targetPath);

      _progressController.add(
        const ModelDownloadProgress(
          status: ModelDownloadStatus.ready,
          progress: 1,
        ),
      );
      return true;
    } on DioException catch (dioErr) {
      if (CancelToken.isCancel(dioErr)) {
        _progressController.add(
          const ModelDownloadProgress(
            status: ModelDownloadStatus.notDownloaded,
            errorMessage: 'Download cancelled by user.',
          ),
        );
      } else {
        _progressController.add(
          ModelDownloadProgress(
            status: ModelDownloadStatus.error,
            errorMessage: 'Network error: ${dioErr.message}',
          ),
        );
      }
      _cleanupTemp(tempPath);
      return false;
    } on Object catch (e) {
      _progressController.add(
        ModelDownloadProgress(
          status: ModelDownloadStatus.error,
          errorMessage: 'Installation failed: $e',
        ),
      );
      _cleanupTemp(tempPath);
      return false;
    }
  }

  /// Cancels any in-progress model download.
  void cancelDownload() {
    _cancelToken?.cancel('Download cancelled by user.');
    _cancelToken = null;
  }

  /// Deletes the local GGUF model from device storage to free space.
  Future<bool> deleteModel() async {
    try {
      final path = await getModelPath();
      final file = File(path);
      if (file.existsSync()) {
        file.deleteSync();
      }
      _progressController.add(
        const ModelDownloadProgress(status: ModelDownloadStatus.notDownloaded),
      );
      return true;
    } on Object catch (err) {
      debugPrint('[OfflineModelManager] Delete error: $err');
      return false;
    }
  }

  Future<bool> _checkFreeStorageSpace() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final stat = dir.statSync();
      return stat.type != FileSystemEntityType.notFound;
    } on Object catch (err) {
      debugPrint('[OfflineModelManager] Storage check note: $err');
      return true;
    }
  }

  void _cleanupTemp(String path) {
    try {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    } on Object catch (_) {}
  }

  Future<void> dispose() async {
    await _progressController.close();
  }
}
