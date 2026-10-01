import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// Contract for application audio recording services.
abstract class AudioRecordingService {
  /// Checks and requests microphone permission if needed.
  Future<bool> hasPermission();

  /// Starts capturing microphone audio into an AAC/M4A file.
  Future<void> startRecording({String? customPath});

  /// Stops capturing and returns the absolute path of the recorded audio file.
  Future<String?> stopRecording();

  /// Cancels recording and deletes the partially recorded file.
  Future<void> cancelRecording();

  /// Returns whether a recording session is currently active.
  Future<bool> isRecording();

  /// Stream of normalized audio input amplitude (0.0 to 1.0).
  Stream<double> get amplitudeStream;

  /// Releases recorder and stream resources.
  void dispose();
}

/// Production implementation of [AudioRecordingService] using the `record` package.
class AudioRecordingServiceImpl implements AudioRecordingService {
  AudioRecordingServiceImpl({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  final StreamController<double> _amplitudeController =
      StreamController<double>.broadcast();

  StreamSubscription<Amplitude>? _ampSub;
  String? _currentRecordingPath;
  bool _isDisposed = false;

  @override
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  @override
  Future<bool> hasPermission() async {
    try {
      final micGranted = await _recorder.hasPermission();
      if (micGranted) return true;

      // Fallback check through permission_handler if platform-specific
      final status = await Permission.microphone.status;
      if (status.isGranted) return true;

      final requested = await Permission.microphone.request();
      return requested.isGranted;
    } on Object catch (e) {
      debugPrint('AudioRecordingService: Error requesting permission: $e');
      return false;
    }
  }

  @override
  Future<void> startRecording({String? customPath}) async {
    if (_isDisposed) return;

    final isAlreadyRecording = await _recorder.isRecording();
    if (isAlreadyRecording) {
      await cancelRecording();
    }

    final permitted = await hasPermission();
    if (!permitted) {
      throw Exception('Microphone permission not granted for voice recording');
    }

    String targetPath;
    if (customPath != null && customPath.trim().isNotEmpty) {
      targetPath = customPath.trim();
    } else {
      final tempDir = await getTemporaryDirectory();
      final voiceNotesDir = Directory(p.join(tempDir.path, 'voice_notes'));
      if (!voiceNotesDir.existsSync()) {
        await voiceNotesDir.create(recursive: true);
      }
      targetPath = p.join(
        voiceNotesDir.path,
        'vn_${DateTime.now().millisecondsSinceEpoch}.m4a',
      );
    }

    _currentRecordingPath = targetPath;

    const config = RecordConfig(
      numChannels: 1,
      autoGain: true,
      echoCancel: true,
      noiseSuppress: true,
    );

    await _recorder.start(config, path: targetPath);

    await _ampSub?.cancel();
    _ampSub = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 80))
        .listen((amp) {
      if (_amplitudeController.isClosed) return;
      // Convert dBFS (-60dB to 0dB) to normalized 0.0 - 1.0 range
      final currentDb = amp.current.clamp(-60.0, 0.0);
      final normalized = ((currentDb + 60.0) / 60.0).clamp(0.0, 1.0);
      _amplitudeController.add(normalized);
    });
  }

  @override
  Future<String?> stopRecording() async {
    if (_isDisposed) return null;

    try {
      await _ampSub?.cancel();
      _ampSub = null;

      final stoppedPath = await _recorder.stop();
      final effectivePath = stoppedPath ?? _currentRecordingPath;
      _currentRecordingPath = null;

      if (effectivePath != null && effectivePath.isNotEmpty) {
        final file = File(effectivePath);
        if (file.existsSync() && file.lengthSync() > 0) {
          debugPrint(
            'AudioRecordingService: Successfully saved recording to $effectivePath (${file.lengthSync()} bytes)',
          );
          return effectivePath;
        }
      }
      return null;
    } on Object catch (e) {
      debugPrint('AudioRecordingService: Error stopping recording: $e');
      return null;
    }
  }

  @override
  Future<void> cancelRecording() async {
    if (_isDisposed) return;

    try {
      await _ampSub?.cancel();
      _ampSub = null;

      await _recorder.cancel();

      if (_currentRecordingPath != null) {
        final file = File(_currentRecordingPath!);
        if (file.existsSync()) {
          try {
            await file.delete();
          } on Object catch (_) {}
        }
        _currentRecordingPath = null;
      }
    } on Object catch (e) {
      debugPrint('AudioRecordingService: Error cancelling recording: $e');
    }
  }

  @override
  Future<bool> isRecording() async {
    if (_isDisposed) return false;
    try {
      return await _recorder.isRecording();
    } on Object catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    unawaited(_ampSub?.cancel());
    unawaited(_amplitudeController.close());
    unawaited(_recorder.dispose());
  }
}
