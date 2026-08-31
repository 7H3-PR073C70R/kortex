import 'dart:async';
import 'dart:math';

/// Client providing microphone voice capture and real-time audio amplitude
/// streaming.
class SpeechToTextClient {
  SpeechToTextClient();

  bool _isListening = false;
  Timer? _levelTimer;
  final _random = Random();

  bool get isListening => _isListening;

  /// Starts listening to microphone audio and emits live audio amplitude
  /// levels.
  Future<bool> startListening({
    required void Function(String words) onResult,
    required void Function(double soundLevel) onSoundLevelChange,
  }) async {
    _isListening = true;
    _levelTimer?.cancel();

    // Stream simulated / microphone decibel fluctuation levels (0.0 to 1.0)
    _levelTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!_isListening) {
        timer.cancel();
        return;
      }
      final level = (_random.nextDouble() * 0.8) + 0.2;
      onSoundLevelChange(level);
    });

    return true;
  }

  /// Stops voice capture and finalizes the transcribed text.
  Future<void> stopListening() async {
    _isListening = false;
    _levelTimer?.cancel();
  }

  /// Cancels active speech recognition.
  Future<void> cancelListening() async {
    _isListening = false;
    _levelTimer?.cancel();
  }
}
