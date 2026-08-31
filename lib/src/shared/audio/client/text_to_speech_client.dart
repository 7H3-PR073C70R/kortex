import 'dart:async';

/// Client providing text-to-speech synthesized narration with intelligent
/// LaTeX-to-English translation.
class TextToSpeechClient {
  TextToSpeechClient();

  bool _isPlaying = false;
  double _speechRate = 1;
  Timer? _playbackTimer;

  bool get isPlaying => _isPlaying;
  double get speechRate => _speechRate;

  /// Sanitizes raw markdown and LaTeX equations into natural spoken English.
  String cleanLatexForSpeech(String text) {
    var cleaned = text;

    // Replace common LaTeX expressions with natural pronunciation
    cleaned = cleaned
        .replaceAllMapped(
          RegExp(r'\\int_\{?([^\}^_\s]+)\}?\^\{?([^\}\s]+)\}?'),
          (m) => 'integral from ${m[1]} to ${m[2]} of ',
        )
        .replaceAllMapped(
          RegExp(r'\\frac\{([^\}]+)\}\{([^\}]+)\}'),
          (m) => '${m[1]} over ${m[2]}',
        )
        .replaceAllMapped(
          RegExp(r'\\sqrt\{([^\}]+)\}'),
          (m) => 'square root of ${m[1]}',
        )
        .replaceAll(r'\sum', 'summation of ')
        .replaceAll(r'\nabla \times', 'curl of ')
        .replaceAll(r'\nabla \cdot', 'divergence of ')
        .replaceAll(r'\partial', 'partial derivative ')
        .replaceAll(r'\alpha', 'alpha')
        .replaceAll(r'\beta', 'beta')
        .replaceAll(r'\theta', 'theta')
        .replaceAll(r'\lambda', 'lambda')
        .replaceAll(r'\pm', 'plus or minus ')
        .replaceAll(r'\infty', 'infinity')
        .replaceAll(r'\approx', 'is approximately equal to ')
        .replaceAll(r'\neq', 'is not equal to ')
        .replaceAll(r'\le', 'is less than or equal to ')
        .replaceAll(r'\ge', 'is greater than or equal to ')
        .replaceAll(r'\mathbf', '')
        .replaceAll(r'\text', '')
        .replaceAll(RegExp(r'[$#*_`\\]'), ' ');

    return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Synthesizes text audio output.
  Future<void> speak(
    String text, {
    double rate = 1.0,
    void Function()? onComplete,
  }) async {
    _speechRate = rate;
    _isPlaying = true;
    _playbackTimer?.cancel();

    final spokenText = cleanLatexForSpeech(text);
    // Estimate reading duration based on word count and speech rate (~180 wpm)
    final wordCount = spokenText.split(' ').length;
    final durationMs =
        ((wordCount / (3.0 * rate)) * 1000).clamp(500, 30000).toInt();

    _playbackTimer = Timer(Duration(milliseconds: durationMs), () {
      _isPlaying = false;
      onComplete?.call();
    });
  }

  /// Stops speech playback.
  Future<void> stop() async {
    _isPlaying = false;
    _playbackTimer?.cancel();
  }

  /// Pauses speech playback.
  Future<void> pause() async {
    _isPlaying = false;
    _playbackTimer?.cancel();
  }
}
