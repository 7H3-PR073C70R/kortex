import 'package:kortex/src/core/services/tts/speech_abbreviations.dart';
import 'package:kortex/src/core/services/tts/speech_code_formatter.dart';
import 'package:kortex/src/core/services/tts/speech_math_formatter.dart';
import 'package:kortex/src/core/services/tts/speech_units_formatter.dart';

export 'package:kortex/src/core/services/tts/speech_abbreviations.dart';
export 'package:kortex/src/core/services/tts/speech_code_formatter.dart';
export 'package:kortex/src/core/services/tts/speech_math_formatter.dart';
export 'package:kortex/src/core/services/tts/speech_units_formatter.dart';

/// Pure, testable text preprocessor and intelligent chunker for Syllabot TTS.
///
/// Ensures speech output is conversational, warm, and natural:
/// - Strips Markdown, HTML, LaTeX, and Unicode emojis cleanly without reading syntax.
/// - Expands educational acronyms (JAMB, WAEC, UTME) and Latin abbreviations (e.g., i.e.).
/// - Formats times, dates, percentages, and currencies for human pronunciation.
/// - Preserves prosodic punctuation cues (?, !, ;, —) for expressive engine intonation.
/// - Performs intelligent sentence-boundary chunking to prevent latency and staccato speech.
class SpeechTextNormalizer {
  const SpeechTextNormalizer._();

  /// Pre-processes flashcard-specific structural patterns before the generic
  /// [normalize] pass, producing natural spoken phrasing for card content.
  ///
  /// Handles:
  /// - MCQ option blocks (`**Options:**` + `• A. ...` lines)
  /// - Answer keys (`**Correct Answer:**`, `**Answer:**`)
  /// - Section labels (`**Explanation:**`, `**Hint:**`, `**Note:**`)
  /// - Markdown tables → row-by-row narration
  /// - Horizontal rules (`---`, `***`)
  static String normalizeFlashcard(String rawCard) {
    if (rawCard.trim().isEmpty) return '';

    var text = rawCard;

    // 1. Horizontal rules → silence (remove entirely)
    text = text.replaceAll(RegExp(r'^\s*[-*_]{3,}\s*$', multiLine: true), '');

    // 2. Strip markdown table alignment rows (e.g. |---|---|)
    text = text.replaceAll(
      RegExp(r'^[\s|:-]+$', multiLine: true),
      '',
    );

    // 3. Convert markdown table rows into spoken sentences
    // | Cell A | Cell B | → "Cell A, Cell B."
    text = text.replaceAllMapped(
      RegExp(r'^\|(.+)\|\s*$', multiLine: true),
      (m) {
        final cells = m[1]!
            .split('|')
            .map((c) => c.trim())
            .where((c) => c.isNotEmpty)
            .join(', ');
        return '$cells.';
      },
    );

    // 4. Options header → natural spoken intro
    text = text.replaceAll(
      RegExp(r'\*{0,2}Options:\*{0,2}', caseSensitive: false),
      'The options are:',
    );

    // 5. MCQ option lines (• A. text / • B. text) → "Option A: text,"
    text = text.replaceAllMapped(
      RegExp(r'[•·]\s*([A-Ea-e])[.):]\s*(.+)', multiLine: true),
      (m) => 'Option ${m[1]!.toUpperCase()}: ${m[2]!.trim()},',
    );

    // 6. Correct Answer / Answer label
    text = text.replaceAllMapped(
      RegExp(
        r'\*{0,2}Correct\s+Answer:\*{0,2}\s*Option\s+([A-Ea-e])(?:\s*[—–-]\s*(.+))?',
        caseSensitive: false,
      ),
      (m) {
        final letter = m[1]!.toUpperCase();
        final desc = m[2]?.trim();
        return desc != null && desc.isNotEmpty
            ? 'The correct answer is Option $letter: $desc.'
            : 'The correct answer is Option $letter.';
      },
    );
    text = text.replaceAll(
      RegExp(r'\*{0,2}(?:Correct\s+)?Answer:\*{0,2}', caseSensitive: false),
      'The answer is:',
    );

    // 7. Common section labels → natural speech
    text = text
        .replaceAll(
          RegExp(r'\*{0,2}Explanation:\*{0,2}', caseSensitive: false),
          'Explanation:',
        )
        .replaceAll(
          RegExp(r'\*{0,2}Hint:\*{0,2}', caseSensitive: false),
          'Hint:',
        )
        .replaceAll(
          RegExp(r'\*{0,2}Note:\*{0,2}', caseSensitive: false),
          'Note:',
        )
        .replaceAll(
          RegExp(r'\*{0,2}Example:\*{0,2}', caseSensitive: false),
          'Example:',
        )
        .replaceAll(
          RegExp(r'\*{0,2}Summary:\*{0,2}', caseSensitive: false),
          'Summary:',
        );

    // 8. Delegate to the generic normalizer for remaining markdown/latex/etc.
    return normalize(text);
  }

  /// Normalizes raw markdown/assistant text into spoken conversational English.
  static String normalize(String rawMarkdown) {
    if (rawMarkdown.trim().isEmpty) return '';

    var text = rawMarkdown;

    // 0. Clean model thinking tags, prompt leakage, control characters & zero-width tokens
    text = text
        .replaceAll(
          RegExp(r'<think>[\s\S]*?<\/think>|<\/?think>|<\|[a-zA-Z0-9_\-]+\|>'),
          ' ',
        )
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '')
        .replaceAll('\u00A0', ' ')
        .replaceAll(
          RegExp(
            r'[\u200B-\u200D\uFEFF\u200E\u200F\u2028\u2029\u2060\u00AD]',
          ),
          '',
        );

    // 1. Normalize real tab characters without stripping \t from LaTeX commands
    text = text.replaceAll('\t', ' ');

    // 2. Decode HTML entities so they do not leak as codes or ampersands
    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', ' and ')
        .replaceAll('&lt;', ' is less than ')
        .replaceAll('&gt;', ' is greater than ')
        .replaceAll('&quot;', ' ')
        .replaceAll('&ldquo;', ' ')
        .replaceAll('&rdquo;', ' ')
        .replaceAll('&lsquo;', "'")
        .replaceAll('&rsquo;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&#39;', "'")
        .replaceAll('&cent;', ' cents')
        .replaceAll('&copy;', ' copyright')
        .replaceAll('&deg;', ' degrees')
        .replaceAll('&pound;', ' pounds ')
        .replaceAll('&euro;', ' euros ')
        .replaceAll(RegExp(r'&#\d+;'), ' ')
        .replaceAll(RegExp('&#x[0-9a-fA-F]+;'), ' ');

    // 3. Strip HTML comments and tags
    text = text.replaceAll(RegExp(r'<!--[\s\S]*?-->'), ' ');
    text = text.replaceAll(RegExp('<[^>]+>'), ' ');

    // 4. Horizontal rules (---, ***, ___) -> explicit section breath pause
    text = text.replaceAll(
      RegExp(r'^\s*[-*_]{3,}\s*$', multiLine: true),
      '\n\n—\n\n',
    );

    // 5. Intelligently process code blocks and inline code for speech
    text = text.replaceAllMapped(
      RegExp(r'```(?:[a-zA-Z0-9_\-+]*\r?\n)?[\s\S]*?```'),
      (m) => SpeechCodeFormatter.normalizeCodeBlock(m[0]!),
    );
    text = text.replaceAllMapped(
      RegExp('`([^`]+)`'),
      (m) => ' ${SpeechCodeFormatter.convertCodeLineToSpeech(m[1]!)} ',
    );
    text = text.replaceAll('`', '');

    // 6. Expand LaTeX math commands into spoken words EARLY (protects numbers and units)
    text = SpeechMathFormatter.normalizeLatex(text);

    // 7. Expand and normalize Markdown tables before symbol stripping
    text = text.replaceAll(
      RegExp(r'^\s*\|?[\s|:-]+\|?\s*$', multiLine: true),
      '',
    );
    text = text.replaceAllMapped(
      RegExp(r'^\s*\|(.+)\|\s*$', multiLine: true),
      (m) {
        final cells = m[1]!
            .split('|')
            .map((c) => c.trim())
            .where((c) => c.isNotEmpty && !RegExp(r'^[-:]+$').hasMatch(c))
            .join(', ');
        return cells.isNotEmpty ? '$cells.' : '';
      },
    );

    // 8. Question headings and section titles: e.g. "### 1. Mechanics" -> "Question 1: Mechanics."
    text = text.replaceAllMapped(
      RegExp(r'^\s*#{1,6}\s*(\d+)[\.\:]\s*(.+)$', multiLine: true),
      (m) => 'Question ${m[1]}: ${m[2]}.',
    );
    text = text.replaceAll(RegExp(r'^\s*#{1,6}\s*', multiLine: true), '');
    text = text.replaceAll(RegExp(r'\s*#{1,6}\s*$', multiLine: true), '. ');
    text = text.replaceAllMapped(RegExp(r'#(\d+)'), (m) => 'number ${m[1]}');
    text = text.replaceAll('#', '');

    // 9. Strip Markdown task list checkboxes (- [ ], - [x], * [x])
    text = text.replaceAll(
      RegExp(r'^\s*[-*+]\s+\[[ xX]\]\s+', multiLine: true),
      ', ',
    );
    text = text.replaceAll(RegExp(r'\[[ xX]\]'), '');

    // 10. Strip Footnotes ([^1], [^note], [^1]: ...)
    text = text.replaceAll(
      RegExp(r'^\s*\[\^[^\]]+\]:\s*', multiLine: true),
      '',
    );
    text = text.replaceAll(RegExp(r'\[\^[^\]]+\]'), '');

    // 11. Clean Blockquotes (strip leading > without confusing with math)
    text = text.replaceAll(RegExp(r'^\s*>+\s*', multiLine: true), '');

    // 12. MCQ Option labels e.g. "**A)**" or "A)" or "• A)" -> "Option A: "
    text = text.replaceAllMapped(
      RegExp(
        r'^\s*(?:[•·*-]\s*)?(?:\*{0,2})\(?([A-Ea-e])\)[.:]?(?:\*{0,2})\s*',
        multiLine: true,
      ),
      (m) => 'Option ${m[1]!.toUpperCase()}: ',
    );

    // 13. Numbered lists: format list numbers with a colon for smooth TTS phrasing without full-stop breaks (e.g. "1. Read..." -> "1: Read...")
    text = text.replaceAllMapped(
      RegExp(r'^\s*(\d+)[\.\)]\s+', multiLine: true),
      (m) => '${m[1]}: ',
    );

    // 14. Unescape markdown backslash escapes (\*, \_, \[, \], etc.)
    text = text.replaceAllMapped(
      RegExp(r"""\\([*#_\[\](){}+.!?~$|><"'`^=~-])"""),
      (m) => m[1]!,
    );

    // 15. Strip Markdown bold, italic, strikethrough syntax cleanly
    text = text.replaceAllMapped(
      RegExp(r'(\*{1,3}|_{1,3})(.*?)\1'),
      (m) => m[2]!,
    );
    text = text.replaceAllMapped(RegExp(r'(\*\*|__)(.*?)\1'), (m) => m[2]!);
    text = text.replaceAllMapped(RegExp(r'(\*|_)(.*?)\1'), (m) => m[2]!);
    text = text.replaceAllMapped(RegExp('~~(.*?)~~'), (m) => m[1]!);

    // 16. Markdown images and links:
    text = text.replaceAllMapped(
      RegExp(r'!\[([^\]]*)\]\([^)]+\)'),
      (m) => m[1]!.isNotEmpty ? '${m[1]} ' : '',
    );
    text = text.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\([^)]+\)'),
      (m) => m[1]!,
    );

    // 17. Remove standalone raw URLs
    text = text.replaceAll(RegExp(r'https?://\S+'), '');
    text = text.replaceAll(RegExp(r'\bwww\.\S+'), '');

    // 18. Clean remaining bullet points into natural pauses
    text = text.replaceAll(RegExp(r'^\s*[-•*+]\s+', multiLine: true), ', ');
    text = text.replaceAll(RegExp('[•·▪▫◦‣⁃■□●○★☆]'), ', ');

    // 19. Checkmarks and crossmarks (including emojis before generic emoji strip)
    text = text
        .replaceAll(RegExp('[✓✔✅]'), ' correct ')
        .replaceAll(RegExp('[✕✖✗✘❌]'), ' incorrect ');

    // 20. Strip emojis (all standard Unicode emoji ranges)
    text = text.replaceAll(
      RegExp(
        r'[\u{1F000}-\u{1FAFF}]|[\u{2600}-\u{27BF}]|[\u{FE00}-\u{FE0F}]|[\u{1F900}-\u{1F9FF}]',
        unicode: true,
      ),
      '',
    );

    // 21. Cut out standalone placeholder tokens ($1, $2, etc., and escaped \$1)
    text = text.replaceAll(RegExp(r'\\?\$1(?!\.\d|\d)'), '');
    text = text.replaceAll(RegExp(r'\\?\$[0-9]+(?!\.\d)'), '');
    text = text.replaceAll(RegExp(r'\$'), '');

    // 22. Normalise Currencies
    text = text.replaceAllMapped(
      RegExp(r'₦\s*(\d+(?:,\d+)*(?:\.\d{1,2})?)'),
      (m) => '${m[1]} Naira',
    );
    text = text.replaceAllMapped(
      RegExp(r'\$\s*(\d+(?:,\d+)*(?:\.\d{1,2})?)'),
      (m) => '${m[1]} dollars',
    );
    text = text.replaceAllMapped(
      RegExp(r'£\s*(\d+(?:,\d+)*(?:\.\d{1,2})?)'),
      (m) => '${m[1]} pounds',
    );
    text = text.replaceAllMapped(
      RegExp(r'€\s*(\d+(?:,\d+)*(?:\.\d{1,2})?)'),
      (m) => '${m[1]} euros',
    );

    // 23. Expand SI Units and Scientific Measurements
    text = SpeechUnitsFormatter.normalizeUnits(text);

    // 24. Normalise Degrees, Percentages, and Math Symbols
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*°\s*C\b'),
      (m) => '${m[1]} degrees Celsius',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*°\s*F\b'),
      (m) => '${m[1]} degrees Fahrenheit',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*°'),
      (m) => '${m[1]} degrees',
    );
    text = text.replaceAll('°', ' degrees ');

    // Percentage ranges (e.g. "0-100%" -> "zero to hundred percent", "10-20%" -> "10 to 20 percent")
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*[-–—]\s*(\d+(?:\.\d+)?)\s*%'),
      (m) {
        final start = m[1]!;
        final end = m[2]!;
        final spokenStart = start == '0' ? 'zero' : start;
        final spokenEnd = end == '100' ? 'hundred' : end;
        return '$spokenStart to $spokenEnd percent';
      },
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*%\s*[-–—]\s*(\d+(?:\.\d+)?)\s*%'),
      (m) {
        final start = m[1]!;
        final end = m[2]!;
        final spokenStart = start == '0' ? 'zero' : start;
        final spokenEnd = end == '100' ? 'hundred' : end;
        return '$spokenStart to $spokenEnd percent';
      },
    );

    // Single percentages: e.g. 0% -> "zero percent", 100% -> "hundred percent"
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*%'),
      (m) {
        final val = m[1]!;
        if (val == '0') return 'zero percent';
        if (val == '100') return 'hundred percent';
        return '$val percent';
      },
    );
    text = text.replaceAll('%', ' percent ');

    // Conversational number ranges (e.g. "0-100" -> "zero to hundred", "10-20" -> "10 to 20")
    text = text.replaceAllMapped(
      RegExp(r'(?<=\b|\s)0\s*[-–—]\s*100(?=\b|\s)'),
      (m) => 'zero to hundred',
    );
    text = text.replaceAllMapped(
      RegExp(r'(?<!\d{4}-)(?<!\d{2}-)\b(\d{1,4})\s*[-–—]\s*(\d{1,4})\b(?!-\d)'),
      (m) => '${m[1]} to ${m[2]}',
    );

    // Powers and exponents outside LaTeX: e.g. x^2, 10^3, 2^5
    text = text.replaceAllMapped(
      RegExp(r'(\w+)\^2\b'),
      (m) => '${m[1]} squared',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\w+)\^3\b'),
      (m) => '${m[1]} cubed',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\w+)\^(-?\d+)'),
      (m) => '${m[1]} to the power of ${m[2]}',
    );

    // Unicode superscripts & subscripts
    text = text
        .replaceAll('²', ' squared')
        .replaceAll('³', ' cubed')
        .replaceAll('¹', ' to the power of 1')
        .replaceAll('⁰', ' to the power of 0')
        .replaceAll('⁴', ' to the power of 4')
        .replaceAll('⁵', ' to the power of 5')
        .replaceAll('⁶', ' to the power of 6')
        .replaceAll('⁷', ' to the power of 7')
        .replaceAll('⁸', ' to the power of 8')
        .replaceAll('⁹', ' to the power of 9');

    // Subscripts in chemical formulas (e.g. H₂O -> H 2 O, CO₂ -> C O 2)
    text = text.replaceAllMapped(
      RegExp('([A-Za-z])([₀₁₂₃₄₅₆₇₈₉])'),
      (m) {
        const subMap = {
          '₀': ' 0 ',
          '₁': ' 1 ',
          '₂': ' 2 ',
          '₃': ' 3 ',
          '₄': ' 4 ',
          '₅': ' 5 ',
          '₆': ' 6 ',
          '₇': ' 7 ',
          '₈': ' 8 ',
          '₉': ' 9 ',
        };
        return '${m[1]}${subMap[m[2]] ?? ''}';
      },
    );

    // Math operators & comparisons
    text = text
        .replaceAll(' ± ', ' plus or minus ')
        .replaceAll('±', ' plus or minus ')
        .replaceAll(' × ', ' times ')
        .replaceAll('×', ' times ')
        .replaceAll(' ÷ ', ' divided by ')
        .replaceAll('÷', ' divided by ')
        .replaceAll(' − ', ' minus ')
        .replaceAll(' ≠ ', ' does not equal ')
        .replaceAll('≠', ' does not equal ')
        .replaceAll(' ≤ ', ' is less than or equal to ')
        .replaceAll('≤', ' is less than or equal to ')
        .replaceAll(' ≥ ', ' is greater than or equal to ')
        .replaceAll('≥', ' is greater than or equal to ')
        .replaceAll(' ≈ ', ' approximately equals ')
        .replaceAll('≈', ' approximately equals ')
        .replaceAll(' ∞ ', ' infinity ')
        .replaceAll('∞', ' infinity ')
        .replaceAll(' & ', ' and ')
        .replaceAll('&', ' and ')
        .replaceAll(' > ', ' is greater than ')
        .replaceAll(' < ', ' is less than ')
        .replaceAll(' = ', ' equals ')
        .replaceAll(' != ', ' does not equal ');

    // Directional arrows
    text = text
        .replaceAll(RegExp(r'(\s*[-=]>|\s*→)'), ' leads to ')
        .replaceAll(RegExp(r'(\s*<[-=]|\s*←)'), ' comes from ')
        .replaceAll(RegExp(r'(\s*<[-=]>|\s*↔)'), ' is equivalent to ');

    // Units with slashes (pronounced as "per")
    text = text
        .replaceAll(
          RegExp(r'\bkm/h\b', caseSensitive: false),
          'kilometers per hour',
        )
        .replaceAll(
          RegExp(r'\bm/s\^?2\b', caseSensitive: false),
          'meters per second squared',
        )
        .replaceAll(
          RegExp(r'\bm/s\b', caseSensitive: false),
          'meters per second',
        )
        .replaceAll(
          RegExp(r'\bkg/m\^?3\b', caseSensitive: false),
          'kilograms per cubic meter',
        )
        .replaceAll(
          RegExp(r'\bkg/m³\b', caseSensitive: false),
          'kilograms per cubic meter',
        )
        .replaceAll(
          RegExp(r'\bg/cm\^?3\b', caseSensitive: false),
          'grams per cubic centimeter',
        )
        .replaceAll(
          RegExp(r'\bg/cm³\b', caseSensitive: false),
          'grams per cubic centimeter',
        )
        .replaceAll(
          RegExp(r'\brad/s\b', caseSensitive: false),
          'radians per second',
        )
        .replaceAll(
          RegExp(r'\brev/min\b', caseSensitive: false),
          'revolutions per minute',
        )
        .replaceAll(
          RegExp(r'\bmiles/h\b', caseSensitive: false),
          'miles per hour',
        )
        .replaceAll(
          RegExp(r'\bmol/dm\^?3\b', caseSensitive: false),
          'moles per decimeter cubed',
        )
        .replaceAll(
          RegExp(r'\bmol/dm³\b', caseSensitive: false),
          'moles per decimeter cubed',
        )
        .replaceAll(
          RegExp(r'\bmol/L\b', caseSensitive: false),
          'moles per liter',
        )
        .replaceAll(
          RegExp(r'\bft/s\b', caseSensitive: false),
          'feet per second',
        )
        .replaceAll(
          RegExp(r'\bbytes/s\b', caseSensitive: false),
          'bytes per second',
        )
        .replaceAll(
          RegExp(r'\bkb/s\b', caseSensitive: false),
          'kilobits per second',
        )
        .replaceAll(
          RegExp(r'\bmb/s\b', caseSensitive: false),
          'megabits per second',
        )
        .replaceAll(RegExp(r'\band/or\b', caseSensitive: false), 'and or')
        .replaceAll(RegExp(r'\beither/or\b', caseSensitive: false), 'either or')
        .replaceAll(
          RegExp(r'\bapprox\.\s*', caseSensitive: false),
          'approximately ',
        );

    // Common fractions with slashes (e.g. 1/2 -> "one half", 3/4 -> "three quarters")
    text = text
        .replaceAll(RegExp(r'\b1/2\b'), 'one half')
        .replaceAll(RegExp(r'\b1/3\b'), 'one third')
        .replaceAll(RegExp(r'\b1/4\b'), 'one quarter')
        .replaceAll(RegExp(r'\b3/4\b'), 'three quarters')
        .replaceAll(RegExp(r'\b2/3\b'), 'two thirds');

    // Words separated by slashes pronounced as "or" (e.g. true/false -> "true or false", yes/no, A/B, pass/fail)
    text = text.replaceAllMapped(
      RegExp(r'(?<=[a-zA-Z])\s*\/\s*(?=[a-zA-Z])'),
      (m) => ' or ',
    );

    // Standalone slash between words or options (e.g. "red / blue" -> "red or blue", "0/1" -> "0 or 1")
    text = text.replaceAllMapped(
      RegExp(r'(?<=\w)\s+\/\s+(?=\w)'),
      (m) => ' or ',
    );
    text = text.replaceAllMapped(
      RegExp(r'\b0\s*\/\s*1\b'),
      (m) => '0 or 1',
    );
    text = text.replaceAllMapped(
      RegExp(r'\b1\s*\/\s*0\b'),
      (m) => '1 or 0',
    );

    // 25. Normalise Times (e.g. "10:30 AM", "8:15 pm")
    text = text.replaceAllMapped(
      RegExp(r'\b(\d{1,2}):(\d{2})\s*(AM|PM|am|pm)\b'),
      (m) {
        final hour = m[1];
        final min = m[2] == '00' ? "o'clock" : m[2];
        final ampm = m[3]!.toUpperCase().split('').join(' ');
        return '$hour $min $ampm';
      },
    );

    // 26. Normalise Academic Acronyms & Abbreviations
    text = SpeechAbbreviations.expand(text);

    // 27. Conversational Year Pronunciation (e.g. 2024 -> "twenty twenty-four")
    text = text.replaceAllMapped(
      RegExp(r'\b(19\d{2}|20\d{2})\b'),
      (m) {
        final year = int.tryParse(m[1] ?? '') ?? 0;
        if (year >= 1900 && year <= 2099) {
          final century = year ~/ 100;
          final remainder = year % 100;
          if (remainder == 0) {
            return '${SpeechMathFormatter.numberToSpoken(century)} hundred';
          } else if (remainder < 10) {
            return '${SpeechMathFormatter.numberToSpoken(century)} oh ${SpeechMathFormatter.numberToSpoken(remainder)}';
          } else {
            return '${SpeechMathFormatter.numberToSpoken(century)} ${SpeechMathFormatter.numberToSpoken(remainder)}';
          }
        }
        return m[0]!;
      },
    );

    // 28. Clean remaining stray syntax characters that would be read aloud by TTS
    // Fill in the blanks: ______ -> ", blank, "
    text = text.replaceAll(RegExp('_{2,}'), ', blank, ');
    // Snake_case between words: user_id -> user id
    text = text.replaceAllMapped(
      RegExp('([a-zA-Z0-9])_([a-zA-Z0-9])'),
      (m) => '${m[1]} ${m[2]}',
    );
    // Remove stray underscores
    text = text.replaceAll('_', ' ');

    // Multiply star e.g. 5 * 2 -> 5 times 2
    text = text.replaceAllMapped(
      RegExp(r'(\d+)\s*\*\s*(\d+)'),
      (m) => '${m[1]} times ${m[2]}',
    );
    // Remove stray asterisks so TTS never says "asterisk"
    text = text.replaceAll('*', ' ');

    // Strip brackets and braces but keep inner text
    text = text
        .replaceAll('[', ' ')
        .replaceAll(']', ' ')
        .replaceAll('{', ' ')
        .replaceAll('}', ' ')
        .replaceAll('|', ', ')
        .replaceAll(r'\', ' ')
        .replaceAll('^', ' ')
        .replaceAll('~', ' ')
        .replaceAll(RegExp(r'\$'), '');

    // Clean quotation marks so TTS engines (Kokoro, Edge, System TTS) never read
    // quote characters aloud as "quotation mark" or "quote".
    // 1) Strip all double quotes (standard, smart, escaped).
    text = text.replaceAll(RegExp('["“”«»]'), ' ');
    // 2) Strip single quotes that are NOT word-internal apostrophes (e.g. keep don't, it's).
    text = text
        .replaceAll(RegExp('[‘’`]'), "'")
        .replaceAll(RegExp("(?<![a-zA-Z0-9])'|'(?![a-zA-Z0-9])"), ' ');

    // 29. Clean punctuation & whitespace
    // Replace em-dash or en-dash with comma pause
    text = text.replaceAll(RegExp('[—–―]'), ', ');
    // Replace ellipses with comma pause
    text = text.replaceAll('...', ', ');
    text = text.replaceAll('…', ', ');
    // Collapse newlines: avoid creating double punctuation if preceded by punctuation
    text = text.replaceAll(RegExp(r'(?<=[.!?])\s*\n+'), ' ');
    text = text.replaceAll(RegExp(r'(?<=[,;:])\s*\n+'), ' ');
    text = text.replaceAll(RegExp(r'\n+'), '. ');
    // Collapse duplicate punctuation safely with replaceAllMapped (NEVER use r'$1' in replaceAll)
    text = text.replaceAll(RegExp(r'[,\s]+,'), ',');
    text = text.replaceAllMapped(RegExp(r'([.!?])\s*\.+'), (m) => m[1]!);
    text = text.replaceAllMapped(RegExp(r'([,:;])\s*\.+'), (m) => m[1]!);
    text = text.replaceAllMapped(RegExp(r'\.\s*([,:;])'), (m) => m[1]!);
    text = text.replaceAll(RegExp(r'\.\s*\.'), '.');
    text = text.replaceAll(RegExp('!+'), '!');
    text = text.replaceAll(RegExp(r'\?+'), '?');
    text = text.replaceAll(RegExp(r'[,;]\s*[,;]+'), ',');

    // Remove stray spaces before punctuation
    text = text.replaceAllMapped(RegExp(r'\s+([,.:;!?])'), (m) => m[1]!);

    // Final cut-out of any residual $1 placeholder tokens
    text = text.replaceAll(RegExp(r'\\?\$[0-9]+(?!\w)'), '');
    text = text.replaceAll(RegExp(r'\$'), '');

    // Collapse multi-spaces
    text = text.replaceAll(RegExp(r'\s{2,}'), ' ');

    return text.trim();
  }

  /// Splits normalized text into natural, cadence-friendly sentence and clause chunks.
  ///
  /// Keeps sentences distinct (or splits long sentences along clause boundaries)
  /// so synthesis takes natural human breathing pauses rather than reading long paragraph blocks.
  static List<String> splitIntoChunks(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return [];

    // Split on sentence-ending punctuation (. ! ?) or paragraph linebreaks,
    // avoiding splitting after single-letter initials (e.g., "A.", "B.") or list digits (e.g., "1.", "2.").
    final sentencePattern = RegExp(r'(?<!\b\d+)(?<!\b[A-Z])(?<=[.!?])\s+|\n+');
    final rawSentences = clean.split(sentencePattern);

    final chunks = <String>[];
    final buffer = StringBuffer();

    for (final raw in rawSentences) {
      final s = raw.trim();
      if (s.isEmpty) continue;

      // Handle explicit section break marker (—) by flushing the current buffer immediately
      if (s == '—' || s == '–') {
        if (buffer.isNotEmpty) {
          chunks.add(buffer.toString());
          buffer.clear();
        }
        continue;
      }

      // If sentence starts a new question, flush preceding content so question starts a new chunk
      if (s.startsWith('Question ') && buffer.isNotEmpty) {
        chunks.add(buffer.toString());
        buffer.clear();
      }

      // If a single sentence is exceptionally long (> 200 characters), split along clause pauses (, ; :)
      if (s.length > 200) {
        final clauseParts = s.split(RegExp(r'(?<=[,;:])\s+'));
        for (final clause in clauseParts) {
          final c = clause.trim();
          if (c.isEmpty) continue;

          if (buffer.isEmpty) {
            buffer.write(c);
          } else if (buffer.length + c.length + 1 > 140) {
            chunks.add(buffer.toString());
            buffer
              ..clear()
              ..write(c);
          } else {
            buffer.write(' $c');
          }
        }
      } else {
        // Group sentences into natural, cadence-friendly chunks (up to ~160 chars)
        // so neural TTS engines can render natural sentence-to-sentence prosody
        // without robotic pauses after every period.
        if (buffer.isEmpty) {
          buffer.write(s);
        } else if (buffer.length + s.length + 1 > 160) {
          chunks.add(buffer.toString());
          buffer
            ..clear()
            ..write(s);
        } else {
          buffer.write(' $s');
        }
      }
    }

    if (buffer.isNotEmpty) {
      chunks.add(buffer.toString());
    }

    return chunks.where((c) => c.trim().isNotEmpty).toList();
  }
}
