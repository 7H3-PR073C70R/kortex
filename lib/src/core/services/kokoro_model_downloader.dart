import 'dart:async';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Managed downloader for Kokoro ONNX on-device TTS assets with HTTP Range
/// resumable download capabilities and automatic background scheduling.
class KokoroModelDownloader {
  KokoroModelDownloader({
    Connectivity? connectivity,
    http.Client? httpClient,
  })  : _connectivity = connectivity ?? Connectivity(),
        _httpClient = httpClient;

  static const _revision = 'f46687f7e41512228ae953af24a11b2640ea0f22';
  static const _hfBase =
      'https://huggingface.co/onnx-community/Kokoro-82M-ONNX/resolve/$_revision';

  static const _modelSha256 =
      '0d55b15d4b735d61a21b0105136bc81b8768c4db94753193c19354fa863cd556';

  static const Map<String, String> _voiceHashes = {
    'af.bin':
        'a4f11d9d055a12bfa0db2668a3e4f0ef8fd1f1ccca69494479718e44dbf9e41a',
    'af_bella.bin':
        '38e12d4b9b31a751282ab9154fb083dad3df3a749772687cde7873da107160fa',
    'af_nicole.bin':
        'f27666996f2d227711e97ff27374099df6f619f3bfb60cd67fc0d114f5384d13',
    'af_sarah.bin':
        'fe4f8b49c272dc5e484ae31a39004fd4ee2b1afc28cbed75da44fc3510b9f984',
    'am_adam.bin':
        '6d5255a4b4803f594bfa0c0d7539c4d8bb0829c7f190f0f6a8fa0afa0023b6e4',
    'am_michael.bin':
        '9c3be118019ddb41b6b529a7f75c7a3dc92613f573ca03b037748b9383b0d9d0',
  };

  static const _modelDirName = 'Kokoro-82M-ONNX';
  static const _readyMarker = '.ready';

  final Connectivity _connectivity;
  final http.Client? _httpClient;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  final ValueNotifier<bool> isReadyNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isDownloadingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<double> progressNotifier = ValueNotifier<double>(0);
  final ValueNotifier<String> statusNotifier =
      ValueNotifier<String>('Checking offline voice model...');

  bool _isDownloading = false;
  bool _shouldCancel = false;
  Directory? _modelDir;

  /// Initializes state, checks if model files exist/are valid, and sets up network listener.
  Future<void> initialize() async {
    if (kIsWeb) {
      statusNotifier.value = 'Web Speech Synthesizer Ready';
      progressNotifier.value = 1.0;
      isReadyNotifier.value = true;
      return;
    }
    final ready = await isReady();
    isReadyNotifier.value = ready;

    if (ready) {
      statusNotifier.value = 'Offline Neural Voice Pack Ready';
      progressNotifier.value = 1.0;
    } else {
      statusNotifier.value = 'Offline Neural Voice Pack update available';
      _listenToConnectivity();
      unawaited(startAutoDownload());
    }
  }

  void _listenToConnectivity() {
    unawaited(_connectivitySub?.cancel());
    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      final isOnline = results.any(
        (c) =>
            c == ConnectivityResult.wifi ||
            c == ConnectivityResult.mobile ||
            c == ConnectivityResult.ethernet,
      );
      if (isOnline && !isReadyNotifier.value && !_isDownloading) {
        unawaited(startAutoDownload());
      }
    });
  }

  /// Checks whether all model files are completely downloaded and match expected hashes.
  Future<bool> isReady() async {
    if (kIsWeb) return true;
    try {
      final dir = await _getModelDir();
      final marker = File(p.join(dir.path, _readyMarker));
      if (!marker.existsSync()) return false;

      final modelPath = p.join(dir.path, 'model_quantized.onnx');
      if (!await _verifyHash(modelPath, _modelSha256)) return false;

      for (final voice in _voiceHashes.keys) {
        final voicePath = p.join(dir.path, 'voices', voice);
        if (!await _verifyHash(voicePath, _voiceHashes[voice]!)) return false;
      }
      return true;
    } on Object catch (e) {
      debugPrint('[KokoroDownloader] Readiness check failed: $e');
      return false;
    }
  }

  /// Triggers automatic background download if online and not already ready.
  Future<void> startAutoDownload() async {
    if (kIsWeb || _isDownloading || isReadyNotifier.value) return;

    final isOnline = await _checkInternetConnection();
    if (!isOnline) {
      statusNotifier.value = 'Offline (Download will resume when connected)';
      return;
    }

    await downloadModelAndVoices();
  }

  /// Manually starts or resumes downloading with HTTP Range headers.
  Future<void> downloadModelAndVoices() async {
    if (kIsWeb || _isDownloading) return;
    _isDownloading = true;
    _shouldCancel = false;
    isDownloadingNotifier.value = true;

    final client = _httpClient ?? http.Client();

    try {
      final dir = await _getModelDir();
      final voiceDir = Directory(p.join(dir.path, 'voices'));
      if (!voiceDir.existsSync()) {
        await voiceDir.create(recursive: true);
      }

      statusNotifier.value = 'Preparing download...';
      progressNotifier.value = 0.05;

      // 1. Resumable download for ONNX Quantized Model (~86 MB)
      final modelDestination = p.join(dir.path, 'model_quantized.onnx');
      await _downloadResumableFile(
        client: client,
        url: '$_hfBase/onnx/model_quantized.onnx',
        destination: modelDestination,
        expectedSha256: _modelSha256,
        progressWeight: 0.70,
        progressOffset: 0.05,
        description: 'ONNX Neural Model',
      );

      if (_shouldCancel) throw Exception('Download cancelled by user.');

      // 2. Resumable download for Voices (~3 MB total across 6 files)
      final voices = _voiceHashes.keys.toList();
      for (var i = 0; i < voices.length; i++) {
        if (_shouldCancel) throw Exception('Download cancelled by user.');

        final voice = voices[i];
        final voiceDestination = p.join(voiceDir.path, voice);
        final weightPerVoice = 0.20 / voices.length;
        final currentOffset = 0.75 + (i * weightPerVoice);

        await _downloadResumableFile(
          client: client,
          url: '$_hfBase/voices/$voice',
          destination: voiceDestination,
          expectedSha256: _voiceHashes[voice]!,
          progressWeight: weightPerVoice,
          progressOffset: currentOffset,
          description: 'Voice $voice',
        );
      }

      // 3. Ensure espeak-ng phonemizer data is ready
      statusNotifier.value = 'Verifying phonemizer data...';
      progressNotifier.value = 0.98;
      try {
        await _ensureEspeakData(dir.parent.path);
      } on Object catch (e) {
        debugPrint('[KokoroDownloader] ensureEspeakData warning: $e');
      }

      // 4. Create .ready marker
      final readyMarkerFile = File(p.join(dir.path, _readyMarker));
      await readyMarkerFile.create();

      isReadyNotifier.value = true;
      progressNotifier.value = 1.0;
      statusNotifier.value = 'Offline Neural Voice Pack Ready';
      debugPrint('[KokoroDownloader] Successfully ready for 100% offline TTS!');
    } on Object catch (e) {
      debugPrint('[KokoroDownloader] Download error: $e');
      statusNotifier.value = 'Download paused (Will resume automatically)';
    } finally {
      _isDownloading = false;
      isDownloadingNotifier.value = false;
      if (_httpClient == null) {
        client.close();
      }
    }
  }

  /// Cancels ongoing download loop.
  void cancelDownload() {
    _shouldCancel = true;
  }

  /// Ensures espeak-ng-data directory exists under base kokoro directory.
  Future<void> _ensureEspeakData(String baseDir) async {
    if (baseDir.isEmpty) return;
    final phontabPath = p.join(baseDir, 'espeak-ng-data', 'phontab');
    if (File(phontabPath).existsSync()) return;

    try {
      final data = await rootBundle.load(
        'packages/flutter_kokoro_tts/assets/espeak_ng_data.zip',
      );
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      final archive = ZipDecoder().decodeBytes(bytes);
      final targetDir = Directory(baseDir);
      if (!targetDir.existsSync()) {
        await targetDir.create(recursive: true);
      }

      for (final file in archive) {
        final name = file.name.replaceAll(r'\', '/').trim();
        if (name.isEmpty) continue;
        final path = p.join(baseDir, name);
        if (file.isFile) {
          final out = File(path);
          if (!out.parent.existsSync()) {
            await out.parent.create(recursive: true);
          }
          await out.writeAsBytes(file.content as List<int>);
        } else {
          final d = Directory(path);
          if (!d.existsSync()) {
            await d.create(recursive: true);
          }
        }
      }
    } on Object catch (e) {
      debugPrint('[KokoroDownloader] espeak-ng data extraction skipped: $e');
    }
  }

  /// Downloads a file using HTTP Range headers for resumable downloads.
  Future<void> _downloadResumableFile({
    required http.Client client,
    required String url,
    required String destination,
    required String expectedSha256,
    required double progressWeight,
    required double progressOffset,
    required String description,
  }) async {
    final finalFile = File(destination);

    // If final file already exists and passes SHA-256 verification, skip!
    if (finalFile.existsSync() &&
        await _verifyHash(destination, expectedSha256)) {
      progressNotifier.value = progressOffset + progressWeight;
      return;
    }

    final partPath = '$destination.part';
    final partFile = File(partPath);

    var existingBytes = 0;
    if (partFile.existsSync()) {
      existingBytes = partFile.lengthSync();
    }

    final request = http.Request('GET', Uri.parse(url));
    if (existingBytes > 0) {
      request.headers['Range'] = 'bytes=$existingBytes-';
    }

    final response = await client.send(request);

    final isPartialResponse = response.statusCode == 206;
    final isOkResponse = response.statusCode == 200;

    if (!isPartialResponse && !isOkResponse) {
      // 416 Range Not Satisfiable or other code -> delete stale part file and restart
      if (partFile.existsSync()) {
        await partFile.delete();
      }
      if (response.statusCode == 416) {
        return _downloadResumableFile(
          client: client,
          url: url,
          destination: destination,
          expectedSha256: expectedSha256,
          progressWeight: progressWeight,
          progressOffset: progressOffset,
          description: description,
        );
      }
      throw Exception('HTTP ${response.statusCode} downloading $description');
    }

    // If server sent full file (200), reset byte count
    if (isOkResponse && existingBytes > 0) {
      existingBytes = 0;
      if (partFile.existsSync()) {
        await partFile.delete();
      }
    }

    final totalContentLength =
        (response.contentLength ?? 0) + existingBytes;
    final sink = partFile.openWrite(
      mode: isPartialResponse ? FileMode.append : FileMode.write,
    );

    var downloadedBytes = existingBytes;

    try {
      await for (final chunk in response.stream) {
        if (_shouldCancel) {
          throw Exception('Download cancelled');
        }
        sink.add(chunk);
        downloadedBytes += chunk.length;

        if (totalContentLength > 0) {
          final fileProgress = downloadedBytes / totalContentLength;
          final currentOverallProgress =
              progressOffset + (fileProgress * progressWeight);
          progressNotifier.value = currentOverallProgress.clamp(0.0, 1.0);

          final mbDownloaded = (downloadedBytes / (1024 * 1024)).toStringAsFixed(1);
          final mbTotal = (totalContentLength / (1024 * 1024)).toStringAsFixed(1);
          statusNotifier.value =
              'Downloading $description ($mbDownloaded / $mbTotal MB)...';
        }
      }

      await sink.flush();
      await sink.close();
    } on Object catch (_) {
      try {
        await sink.close();
      } on Object catch (_) {}
      rethrow;
    }

    // Verify hash of completed .part file before renaming
    final isHashValid = await _verifyHash(partPath, expectedSha256);
    if (!isHashValid) {
      if (partFile.existsSync()) {
        await partFile.delete();
      }
      throw Exception('Integrity check failed for $description');
    }

    // Hash is valid! Atomically move .part file to final destination
    await partFile.rename(destination);
  }

  Future<bool> _verifyHash(String filePath, String expectedSha256) async {
    final file = File(filePath);
    if (!file.existsSync()) return false;

    try {
      final digest = await sha256.bind(file.openRead()).first;
      return digest.toString().toLowerCase() == expectedSha256.toLowerCase();
    } on Object catch (e) {
      debugPrint('[KokoroDownloader] SHA-256 calculation error on $filePath: $e');
      return false;
    }
  }

  Future<bool> _checkInternetConnection() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.any(
        (c) =>
            c == ConnectivityResult.wifi ||
            c == ConnectivityResult.mobile ||
            c == ConnectivityResult.ethernet,
      );
    } on Object catch (_) {
      return false;
    }
  }

  Future<Directory> _getModelDir() async {
    if (_modelDir != null) return _modelDir!;
    final appDir = await getApplicationDocumentsDirectory();
    final modelPath = p.join(appDir.path, 'kokoro', _modelDirName);
    _modelDir = Directory(modelPath);
    if (!_modelDir!.existsSync()) {
      await _modelDir!.create(recursive: true);
    }
    return _modelDir!;
  }

  void dispose() {
    unawaited(_connectivitySub?.cancel());
    isReadyNotifier.dispose();
    isDownloadingNotifier.dispose();
    progressNotifier.dispose();
    statusNotifier.dispose();
  }
}
