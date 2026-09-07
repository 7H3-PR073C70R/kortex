import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/speech_text_normalizer.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/tts_config.dart';

void main() {
  group('SpeechTextNormalizer', () {
    test('strips markdown headings, bold, and italics cleanly', () {
      const input = '### Introduction to Physics\nThis is **very** important and *essential*.';
      final result = SpeechTextNormalizer.normalize(input);
      expect(result.contains('#'), isFalse);
      expect(result.contains('*'), isFalse);
      expect(result, contains('Introduction to Physics'));
      expect(result, contains('very important and essential'));
    });

    test('replaces code blocks with conversational spoken cues', () {
      const input = 'Here is how you solve it:\n```python\nprint("Hello")\n```\nIt runs smoothly.';
      final result = SpeechTextNormalizer.normalize(input);
      expect(result.contains('```'), isFalse);
      expect(result, contains('here is the code snippet'));
      expect(result, contains('It runs smoothly'));
    });

    test('expands educational acronyms to spelled-out phonetics', () {
      const input = 'Prepare for your JAMB, WAEC, and UTME exams with CBT practice.';
      final result = SpeechTextNormalizer.normalize(input);
      expect(result, contains('J-A-M-B'));
      expect(result, contains('W-A-E-C'));
      expect(result, contains('U-T-M-E'));
      expect(result, contains('C-B-T'));
    });

    test('expands LaTeX formulas into spoken equivalents', () {
      const input = r'The formula is $\frac{a}{b}$ and $\sqrt{x} \pm \Delta$.';
      final result = SpeechTextNormalizer.normalize(input);
      expect(result, contains('a over b'));
      expect(result, contains('square root of x'));
      expect(result, contains('plus or minus'));
      expect(result, contains('Delta'));
    });

    test('formats times, currencies, and percentages for natural speech', () {
      const input = 'Your session is at 10:30 AM. Total fee is ₦5,000, with a 15% discount.';
      final result = SpeechTextNormalizer.normalize(input);
      expect(result, contains('10 30 A M'));
      expect(result, contains('5,000 Naira'));
      expect(result, contains('15 percent'));
    });

    test('pronounces years conversationally', () {
      const input = 'The constitution of 1999 was amended in 2024.';
      final result = SpeechTextNormalizer.normalize(input);
      expect(result, contains('nineteen ninety-nine'));
      expect(result, contains('twenty twenty-four'));
    });

    test('strips unicode emojis', () {
      const input = 'Great work! 🎉 Keep it up! 🚀';
      final result = SpeechTextNormalizer.normalize(input);
      expect(result, equals('Great work! Keep it up!'));
    });

    test('intelligently chunks long text along natural sentence boundaries', () {
      const text =
          'Welcome to Syllabot. We are going to review your biology curriculum today. '
          'First, let us examine cell structure and the role of the mitochondria. '
          'The mitochondria is known as the powerhouse of the cell because it produces energy in the form of ATP. '
          'Finally, we will solve three past examination questions together.';

      final chunks = SpeechTextNormalizer.splitIntoChunks(text);
      expect(chunks.length, greaterThanOrEqualTo(2));
      for (final chunk in chunks) {
        expect(chunk.trim().isNotEmpty, isTrue);
      }
    });
  });

  group('TtsConfig', () {
    test('creates valid calibrated platform defaults', () {
      final config = TtsConfig.forCurrentPlatform();
      expect(config.pitch, equals(1.0));
      expect(config.volume, equals(1.0));
      expect(config.effectiveSpeechRate, greaterThan(0));
      expect(config.effectiveSpeechRate, lessThan(2.0));
    });

    test('copyWith updates fields correctly', () {
      final initial = TtsConfig.forCurrentPlatform();
      final updated = initial.copyWith(
        gender: VoiceGender.male,
        speechRateMultiplier: 1.2,
      );
      expect(updated.gender, equals(VoiceGender.male));
      expect(updated.speechRateMultiplier, equals(1.2));
    });
  });
}
