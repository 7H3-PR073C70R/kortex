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

    test(r'never generates $1 from duplicate punctuation collapse', () {
      const input = 'Great job!... Can you solve this?... Yes!.... Exactly.';
      final result = SpeechTextNormalizer.normalize(input);
      expect(result.contains(r'$1'), isFalse);
      expect(result.contains('1'), isFalse);
      expect(result.toLowerCase().contains('dollar'), isFalse);
      expect(result, contains('Great job!'));
      expect(result, contains('Can you solve this?'));
      expect(result, contains('Yes!'));
      expect(result, contains('Exactly.'));
    });

    test(r'explicitly cuts out $1, escaped \$1, and placeholder tokens', () {
      const input = r'Replace $1 with value and ignore \$1 or $2 or $3.';
      final result = SpeechTextNormalizer.normalize(input);
      expect(result.contains(r'$1'), isFalse);
      expect(result.contains(r'$2'), isFalse);
      expect(result.contains(r'$3'), isFalse);
      expect(result.contains(r'\$1'), isFalse);
      expect(result.contains(r'$'), isFalse);
      expect(result.toLowerCase().contains('dollar'), isFalse);
      expect(result, contains('Replace with value and ignore or or.'));
    });

    test('strips escape characters and unescapes markdown escapes cleanly', () {
      const input = r'Here is \*bold\* and \_italic\_ with \# heading, \[brackets\], and \{braces\}. Also literal\nnewline and\ttab.';
      final result = SpeechTextNormalizer.normalize(input);
      expect(result.contains(r'\'), isFalse);
      expect(result.contains('*'), isFalse);
      expect(result.contains('_'), isFalse);
      expect(result.contains('#'), isFalse);
      expect(result.contains('['), isFalse);
      expect(result.contains(']'), isFalse);
      expect(result.contains('{'), isFalse);
      expect(result.contains('}'), isFalse);
      expect(result, contains('Here is bold and italic with heading'));
      expect(result, contains('brackets'));
      expect(result, contains('braces'));
      expect(result, contains('newline'));
      expect(result, contains('tab'));
    });

    test('strips markdown tables into natural spoken sentences', () {
      const input = '''
| Organelle | Primary Function |
| :--- | :--- |
| Mitochondria | Cellular respiration |
| Ribosome | Protein synthesis |
''';
      final result = SpeechTextNormalizer.normalize(input);
      expect(result.contains('|'), isFalse);
      expect(result.contains('---'), isFalse);
      expect(result, contains('Organelle, Primary Function.'));
      expect(result, contains('Mitochondria, Cellular respiration.'));
      expect(result, contains('Ribosome, Protein synthesis.'));
    });

    test('strips markdown images cleanly while preserving alt text', () {
      const input = 'Look at this diagram: ![Plant Cell Structure](https://example.com/cell.png). Also empty image: ![](https://example.com/empty.jpg).';
      final result = SpeechTextNormalizer.normalize(input);
      expect(result.contains('!['), isFalse);
      expect(result.contains('https://'), isFalse);
      expect(result.contains('.png'), isFalse);
      expect(result.contains('.jpg'), isFalse);
      expect(result, contains('Look at this diagram: Plant Cell Structure'));
      expect(result, contains('Also empty image:'));
    });

    test('strips task list checkboxes and footnotes cleanly', () {
      const input = '''
Review tasks:
- [ ] Review mitosis
- [x] Complete WAEC practice
* [X] Study meiosis
Fact stated[^1].
[^1]: Citation from 2020.
''';
      final result = SpeechTextNormalizer.normalize(input);
      expect(result.contains('[ ]'), isFalse);
      expect(result.contains('[x]'), isFalse);
      expect(result.contains('[X]'), isFalse);
      expect(result.contains('[^1]'), isFalse);
      expect(result, contains('Review mitosis'));
      expect(result, contains('Complete Way-eck practice'));
      expect(result, contains('Study meiosis'));
      expect(result, contains('Fact stated'));
    });

    test('strips AI thinking tags and internal reasoning', () {
      const input = '<think>I should break down photosynthesis into light and dark reactions.</think>Photosynthesis occurs in chloroplasts.';
      final result = SpeechTextNormalizer.normalize(input);
      expect(result.contains('think'), isFalse);
      expect(result.contains('break down'), isFalse);
      expect(result, equals('Photosynthesis occurs in chloroplasts.'));
    });

    test('pronounces percentage ranges properly like 0-100% as zero to hundred percent', () {
      const input = 'Your score is between 0-100%, and confidence is 0% - 100%.';
      final result = SpeechTextNormalizer.normalize(input);
      expect(result, contains('zero to hundred percent'));
      expect(result.contains('0-100%'), isFalse);
      expect(result.contains('%'), isFalse);

      const singleInput = 'Starting from 0% all the way up to 100%.';
      final singleResult = SpeechTextNormalizer.normalize(singleInput);
      expect(singleResult, contains('zero percent'));
      expect(singleResult, contains('hundred percent'));
    });

    test('pronounces number ranges properly like 0-100 as zero to hundred', () {
      const input = 'Score between 0-100 or 10-20 points.';
      final result = SpeechTextNormalizer.normalize(input);
      expect(result, contains('zero to hundred'));
      expect(result, contains('10 to 20'));
    });

    test('pronounces / as or where appropriate while keeping scientific units and fractions', () {
      const input = 'Choose true/false, yes/no, A/B, or 0/1. The car moves at 60 km/h with 1/2 tank.';
      final result = SpeechTextNormalizer.normalize(input);
      expect(result, contains('true or false'));
      expect(result, contains('yes or no'));
      expect(result, contains('A or B'));
      expect(result, contains('0 or 1'));
      expect(result, contains('kilometers per hour'));
      expect(result, contains('one half'));
      expect(result.contains('/'), isFalse);
    });

    test('preserves list numbers and question headers with smooth list colon formatting', () {
      const input = '''
### 1. Kinematics
1. Calculate the velocity when distance is 50 meters and time is 5 seconds.
2. Find the acceleration.
''';
      final result = SpeechTextNormalizer.normalize(input);
      expect(result, contains('Question 1: Kinematics'));
      expect(result, contains('1: Calculate the velocity when distance is 50 meters and time is 5 seconds.'));
      expect(result, contains('2: Find the acceleration.'));

      final chunks = SpeechTextNormalizer.splitIntoChunks(result);
      expect(chunks.first, contains('1: Calculate the velocity'));
      expect(chunks.first.startsWith('1.'), isFalse);
    });

    test('normalizes LaTeX text units without uttering est or ext', () {
      const input = r'The acceleration is $9.8\ \text{m/s}^2$ and frequency is $50\ \text{Hz}$.';
      final result = SpeechTextNormalizer.normalize(input);
      expect(result, isNot(contains('est')));
      expect(result, isNot(contains('ext')));
      expect(result, contains('9.8 meters per second squared'));
      expect(result, contains('50 hertz'));
    });

    test('normalizes electrical and physics units attached to numbers', () {
      const input = r'A circuit has $5\ \text{V}$, $10\ \Omega$, and $20\ \mu\text{F}$.';
      final result = SpeechTextNormalizer.normalize(input);
      expect(result, contains('5 volts'));
      expect(result, contains('10 ohms'));
      expect(result, contains('20 microfarads'));
    });

    test('converts --- into a distinct pause marker and splitIntoChunks isolates it', () {
      const input = '''
Here is the first question.
---
Question 2: What is gravity?
''';
      final chunks = SpeechTextNormalizer.splitIntoChunks(input);
      expect(chunks.length, greaterThanOrEqualTo(2));
      expect(chunks.any((c) => c.contains('Here is the first question.')), isTrue);
      expect(chunks.any((c) => c.contains('Question 2')), isTrue);
    });

    test('formats multiple-choice options with natural pause cadence', () {
      const input = '''
**A)** 10 m/s
**B)** 20 m/s
''';
      final result = SpeechTextNormalizer.normalize(input);
      expect(result, contains('Option A: 10 meters per second'));
      expect(result, contains('Option B: 20 meters per second'));
    });

    test('replaces checkmarks and crosses with clear audio equivalents', () {
      const input = '✅ Correct answer! ❌ Incorrect approach.';
      final result = SpeechTextNormalizer.normalize(input);
      expect(result, contains('correct Correct answer!'));
      expect(result, contains('incorrect Incorrect approach.'));
      expect(result.contains('✅'), isFalse);
      expect(result.contains('❌'), isFalse);
    });

    test('strips quotation marks cleanly so TTS never utters quotation mark while preserving contractions', () {
      const input = 'He said "Hello world" &quot;WAEC&quot; ‘mitochondria’ and it\'s 10 o\'clock so don\'t worry.';
      final result = SpeechTextNormalizer.normalize(input);
      expect(result.contains('"'), isFalse);
      expect(result.contains('“'), isFalse);
      expect(result.contains('”'), isFalse);
      expect(result.contains('‘'), isFalse);
      expect(result.contains('’'), isFalse);
      expect(result, contains('He said Hello world Way-eck mitochondria'));
      expect(result, contains("it's 10 o'clock so don't worry"));
    });
  });

  group('TtsConfig', () {
    test('creates valid calibrated platform defaults with sentencePauseMs', () {
      final config = TtsConfig.forCurrentPlatform();
      expect(config.pitch, equals(1.0));
      expect(config.volume, equals(1.0));
      expect(config.sentencePauseMs, equals(60));
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
