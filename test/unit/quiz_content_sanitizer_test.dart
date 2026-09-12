import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/quiz/domain/logic/quiz_content_sanitizer.dart';

void main() {
  group('QuizContentSanitizer', () {
    test('cleans option text with Correct Answer prefix and explanation block', () {
      const raw = '''
**Correct Answer:** Option B — is a neutralization

**Explanation:**
The reaction
NaOH (aq) + HCl (aq) -> NaCl (aq) + H2O (l) is a neutralization reaction because it involves the reaction between an acid (HCl) and a base (NaOH) to form a salt (NaCl) and water.
''';

      final clean = QuizContentSanitizer.cleanOptionText(raw);
      expect(clean, 'is a neutralization');

      final explanation = QuizContentSanitizer.extractExplanation(raw);
      expect(explanation, contains('is a neutralization reaction because it involves'));
    });

    test('cleans option text without markdown bold', () {
      const raw = 'Correct Answer: Option B — is a neutralization\nExplanation:\nDetail here';
      expect(QuizContentSanitizer.cleanOptionText(raw), 'is a neutralization');
    });

    test('cleans option with standard prefix A.', () {
      const raw = 'A. Photosynthesis';
      expect(QuizContentSanitizer.cleanOptionText(raw), 'Photosynthesis');
    });

    test('cleans option with (C) prefix', () {
      const raw = '(C) Osmosis';
      expect(QuizContentSanitizer.cleanOptionText(raw), 'Osmosis');
    });

    test('preserves clean option without prefixes', () {
      const raw = 'Stop loss placed 1 pip below the low';
      expect(QuizContentSanitizer.cleanOptionText(raw), 'Stop loss placed 1 pip below the low');
    });

    test('cleans prompt text by removing embedded options', () {
      const raw = '''
What is the product of this reaction?

**Options:**
• A. H2O
• B. NaCl
''';
      expect(QuizContentSanitizer.cleanPrompt(raw), 'What is the product of this reaction?');
    });

    test('cleans subtopic with truncation', () {
      const raw = "How is the 'Stop Loss (SL)' placed in Step 3C of 'The Only 1 Minute Trading Strategy'?";
      final clean = QuizContentSanitizer.cleanSubTopic(raw, maxLength: 30);
      expect(clean.length, lessThanOrEqualTo(30));
      expect(clean.endsWith('…'), isTrue);
    });
  });
}
