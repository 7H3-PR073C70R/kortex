import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/shared/audio/client/text_to_speech_client.dart';

void main() {
  group('TextToSpeechClient & LaTeX Cleaner Unit Test Suite', () {
    late TextToSpeechClient client;

    setUp(() {
      client = TextToSpeechClient();
    });

    test('cleanLatexForSpeech converts mathematical formulas to plain English',
        () {
      const raw = r'Calculate \frac{a}{b} and \sqrt{x} where \alpha \approx 1';
      final cleaned = client.cleanLatexForSpeech(raw);

      expect(cleaned, contains('a over b'));
      expect(cleaned, contains('square root of x'));
      expect(cleaned, contains('alpha is approximately equal to 1'));
    });

    test('cleanLatexForSpeech handles integrals, summations, and symbols', () {
      const raw = r'The value is \int_0^\infty f(x) dx \pm \infty';
      final cleaned = client.cleanLatexForSpeech(raw);

      expect(cleaned, contains('integral from 0 to infinity of'));
      expect(cleaned, contains('plus or minus infinity'));
    });

    test('speak starts playback and stop terminates playback', () async {
      await client.speak('Hello world');
      expect(client.isPlaying, isTrue);

      await client.stop();
      expect(client.isPlaying, isFalse);
    });
  });
}
