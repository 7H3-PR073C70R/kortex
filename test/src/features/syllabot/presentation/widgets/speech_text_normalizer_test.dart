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
      expect(result, contains('print Hello'));
      expect(result, contains('It runs smoothly'));
    });

    test('pronounces Dart and Flutter code blocks with operators in natural speech', () {
      const input = '```dart\nvoid main() => runApp(const MyApp());\nif (score >= 50 && isValid) {\n  setState(() => count++);\n}\n```';
      final result = SpeechTextNormalizer.normalize(input);
      expect(result, contains('here is the code snippet in Dart:'));
      expect(result, contains('void main returns run App'));
      expect(result, contains('is greater than or equal to 50 and is Valid'));
      expect(result, contains('set State returns count plus plus'));
      expect(result.contains(';'), isFalse);
      expect(result.contains('=>'), isFalse);
      expect(result.contains('{'), isFalse);
    });

    test('expands educational acronyms to spoken phonetics (WAEC as Way-eck, JAMB as Jamb)', () {
      const input = 'Prepare for your JAMB, WAEC, waec, WASSCE, NECO, and UTME exams with CBT practice.';
      final result = SpeechTextNormalizer.normalize(input);
      expect(result, contains('Jamb'));
      expect(result, contains('Way-eck'));
      expect(result, contains('Was-see'));
      expect(result, contains('Neco'));
      expect(result, contains('U-T-M-E'));
      expect(result, contains('C-B-T'));
      expect(result.contains('W-A-E-C'), isFalse);
      expect(result.contains('J-A-M-B'), isFalse);
      expect(result.contains('N-E-C-O'), isFalse);
    });

    test('strips HTML tags and decodes HTML entities cleanly', () {
      const input = '<p>Check your <b>WAEC</b> result&nbsp;at the portal &amp; print&nbsp;it.<br>Is A &lt; B and C &gt; D?</p>';
      final result = SpeechTextNormalizer.normalize(input);
      expect(result.contains('<p>'), isFalse);
      expect(result.contains('<b>'), isFalse);
      expect(result.contains('<br>'), isFalse);
      expect(result.contains('&nbsp;'), isFalse);
      expect(result.contains('&amp;'), isFalse);
      expect(result.contains('&lt;'), isFalse);
      expect(result.contains('&gt;'), isFalse);
      expect(result, contains('Way-eck'));
      expect(result, contains('and'));
      expect(result, contains('is less than'));
      expect(result, contains('is greater than'));
    });

    test('cleans stray characters (asterisks, underscores, brackets, carets, tildes)', () {
      const input = 'Calculate [H+] for ~5 minutes: x^2 + y^2 = z^2. Fill in the blank: ______ and check user_id.';
      final result = SpeechTextNormalizer.normalize(input);
      expect(result.contains('['), isFalse);
      expect(result.contains(']'), isFalse);
      expect(result.contains('^'), isFalse);
      expect(result.contains('~'), isFalse);
      expect(result, contains('squared'));
      expect(result, contains('blank'));
      expect(result, contains('user id'));
    });

    test('normalizes degrees, superscripts, subscripts, and checkmarks', () {
      const input = 'Water is H₂O at 25°C. Option A: ✓ Correct, Option B: ✗ False. Area is 10 m².';
      final result = SpeechTextNormalizer.normalize(input);
      expect(result.contains('°'), isFalse);
      expect(result.contains('✓'), isFalse);
      expect(result.contains('✗'), isFalse);
      expect(result, contains('degrees Celsius'));
      expect(result, contains('correct'));
      expect(result, contains('incorrect'));
      expect(result, contains('squared'));
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

    test('normalizes newlines and punctuation cleanly without duplicate dots', () {
      const input = 'Introduction:\nFirst point!\nSecond point.\nThird point?';
      final result = SpeechTextNormalizer.normalize(input);
      expect(result.contains(':.'), isFalse);
      expect(result.contains('!.'), isFalse);
      expect(result.contains('?.'), isFalse);
      expect(result.contains('..'), isFalse);
    });

    test('keeps initials together without chopping on single-letter periods', () {
      const text = 'Dr. J. K. Rowling and Prof. A. Smith published No. 1 paper.';
      final normalized = SpeechTextNormalizer.normalize(text);
      expect(normalized, contains('Doctor'));
      expect(normalized, contains('Professor'));
      expect(normalized, contains('Number 1'));

      final chunks = SpeechTextNormalizer.splitIntoChunks(normalized);
      // Shouldn't split into 5 tiny single-word chunks
      expect(chunks.length, equals(1));
    });

    test('groups short sentences into continuous natural prosody chunks', () {
      const text = 'Hello there. How are you today? Let us begin.';
      final chunks = SpeechTextNormalizer.splitIntoChunks(text);
      // Entire greeting fits in one natural chunk to avoid awkward pauses after periods
      expect(chunks.length, equals(1));
      expect(chunks.first, contains('Hello there. How are you today? Let us begin.'));
    });
  });

  group('TtsConfig', () {
    test('creates valid calibrated platform defaults with sentencePauseMs', () {
      final config = TtsConfig.forCurrentPlatform();
      expect(config.pitch, equals(1.0));
      expect(config.volume, equals(1.0));
      expect(config.sentencePauseMs, equals(0));
      expect(config.effectiveSpeechRate, greaterThan(0));
      expect(config.effectiveSpeechRate, lessThan(2.0));
    });

    test('copyWith updates fields correctly including sentencePauseMs', () {
      final initial = TtsConfig.forCurrentPlatform();
      final updated = initial.copyWith(
        gender: VoiceGender.male,
        speechRateMultiplier: 1.2,
        sentencePauseMs: 300,
      );
      expect(updated.gender, equals(VoiceGender.male));
      expect(updated.speechRateMultiplier, equals(1.2));
      expect(updated.sentencePauseMs, equals(300));
    });
  });
}
