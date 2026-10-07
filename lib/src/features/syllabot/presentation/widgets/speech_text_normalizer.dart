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

  // ---------------------------------------------------------------------------
  // Educational & Academic Abbreviations
  // ---------------------------------------------------------------------------
  static const Map<String, String> _acronymExpansions = {
    'WAEC': 'Way-eck',
    'WASSCE': 'Was-see',
    'JAMB': 'Jamb',
    'NECO': 'Neco',
    'NABTEB': 'Nabteb',
    'BECE': 'Beh-seh',
    'JUPEB': 'Joo-peb',
    'ASUU': 'Ah-soo',
    'UTME': 'U-T-M-E',
    'POST-UTME': 'Post U-T-M-E',
    'Post-UTME': 'Post U-T-M-E',
    'CBT': 'C-B-T',
    'GPA': 'G-P-A',
    'CGPA': 'C-G-P-A',
    'SSCE': 'S-S-C-E',
    'GCE': 'G-C-E',
    'IJMB': 'I-J-M-B',
    'NUC': 'N-U-C',
    'NYSC': 'N-Y-S-C',
    'API': 'A-P-I',
    'AI': 'A-I',
    'UI': 'U-I',
    'UX': 'U-X',
    'PDF': 'P-D-F',
    'FAQ': 'F-A-Q',
  };

  static const Map<String, String> _commonAbbreviations = {
    r'\be\.g\.,?': 'for example',
    r'\bi\.e\.,?': 'that is',
    r'\betc\.,?': 'etcetera',
    r'\bvs\.(?!\w)': 'versus',
    r'\bvs\b': 'versus',
    r'\bw/o\b': 'without',
    r'\bw/\b': 'with',
    r'\bDr\.(?!\w)': 'Doctor',
    r'\bMr\.(?!\w)': 'Mister',
    r'\bMrs\.(?!\w)': 'Missus',
    r'\bMs\.(?!\w)': 'Miz',
    r'\bProf\.(?!\w)': 'Professor',
    r'\bSr\.(?!\w)': 'Senior',
    r'\bJr\.(?!\w)': 'Junior',
    r'\bSt\.(?!\w)': 'Saint',
    r'\bPh\.D\.(?!\w)': 'P-h-D',
    r'\bNo\.(?!\w)': 'Number',
    r'\bDept\.(?!\w)': 'Department',
    r'\bUniv\.(?!\w)': 'University',
    r'\bFig\.(?!\w)': 'Figure',
    r'\bfig\.(?!\w)': 'figure',
    r'\bEq\.(?!\w)': 'Equation',
    r'\beq\.(?!\w)': 'equation',
    r'\bapprox\.(?!\w)': 'approximately',
  };

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
      (m) => _normalizeCodeBlock(m[0]!),
    );
    text = text.replaceAllMapped(
      RegExp('`([^`]+)`'),
      (m) => ' ${_convertCodeLineToSpeech(m[1]!)} ',
    );
    text = text.replaceAll('`', '');

    // 6. Expand LaTeX math commands into spoken words EARLY (protects numbers and units)
    text = _normalizeLatex(text);

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
    text = _normalizeUnits(text);

    // 20. Normalise Degrees, Percentages, and Math Symbols
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

    // 21. Normalise Times (e.g. "10:30 AM", "8:15 pm")
    text = text.replaceAllMapped(
      RegExp(r'\b(\d{1,2}):(\d{2})\s*(AM|PM|am|pm)\b'),
      (m) {
        final hour = m[1];
        final min = m[2] == '00' ? "o'clock" : m[2];
        final ampm = m[3]!.toUpperCase().split('').join(' ');
        return '$hour $min $ampm';
      },
    );

    // 22. Normalise Academic Acronyms & Abbreviations
    for (final entry in _commonAbbreviations.entries) {
      text = text.replaceAll(
        RegExp(entry.key, caseSensitive: false),
        entry.value,
      );
    }
    for (final entry in _acronymExpansions.entries) {
      text = text.replaceAll(
        RegExp('\\b${entry.key}\\b', caseSensitive: false),
        entry.value,
      );
    }

    // 23. Conversational Year Pronunciation (e.g. 2024 -> "twenty twenty-four")
    text = text.replaceAllMapped(
      RegExp(r'\b(19\d{2}|20\d{2})\b'),
      (m) {
        final year = int.tryParse(m[1] ?? '') ?? 0;
        if (year >= 1900 && year <= 2099) {
          final century = year ~/ 100;
          final remainder = year % 100;
          if (remainder == 0) {
            return '${_numberToSpoken(century)} hundred';
          } else if (remainder < 10) {
            return '${_numberToSpoken(century)} oh ${_numberToSpoken(remainder)}';
          } else {
            return '${_numberToSpoken(century)} ${_numberToSpoken(remainder)}';
          }
        }
        return m[0]!;
      },
    );

    // 24. Clean remaining stray syntax characters that would be read aloud by TTS
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

    // 25. Clean punctuation & whitespace
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

  /// Expands LaTeX syntax to natural spoken phrases.
  ///
  /// Handles both dollar-sign-delimited math blocks and bare LaTeX commands
  /// that appear outside delimiters (common in flashcard content).
  static String _normalizeLatex(String input) {
    var text = input;

    // 1. LaTeX line-break double-backslash -> space
    text = text.replaceAll(r'\\', ' ');

    // 2. Strip LaTeX environments
    text = text.replaceAll(
      RegExp(r'\\begin\{[^}]*\}|\\end\{[^}]*\}'),
      '',
    );

    // 3. Block math -> spoken ($$...$$ or \[...\])
    text = text.replaceAllMapped(
      RegExp(r'(?<!\\)\$\$([\s\S]*?)(?<!\\)\$\$|\\\[([\s\S]*?)\\\]'),
      (m) => ', ${_expandLatexSymbols(m[1] ?? m[2]!)}, ',
    );

    // 4. Inline math -> spoken ($...$ or \(...\))
    text = text.replaceAllMapped(
      RegExp(r'(?<!\\)\$(?!\s)([^$\n]+?)(?<!\s)(?<!\\)\$|\\\(([^)\n]+)\\\)'),
      (m) => ' ${_expandLatexSymbols(m[1] ?? m[2]!)} ',
    );

    // 5. Strip \left / \right delimiter markers, keep bracket that follows
    text = text.replaceAll(RegExp(r'\\(?:left|right)\s*'), '');

    // 6. Expand all remaining bare LaTeX commands
    text = _expandLatexSymbols(text);

    // 7. Catch-all: \commandname -> drop backslash, keep readable word
    //    Prevents TTS from ever saying "backslash commandname".
    text = text.replaceAllMapped(
      RegExp(r'\\([a-zA-Z]+)'),
      (m) => ' ${m[1]!} ',
    );

    // 8. Lone remaining backslashes -> space
    text = text.replaceAll(RegExp(r'\\'), ' ');

    return text;
  }

  static String _expandLatexSymbols(String math) {
    var s = math;

    // ── Unpack text formatting commands inside math mode (\text{...}) ────────
    s = s.replaceAllMapped(
      RegExp(
        r'\\(?:text|mathrm|mathbf|mathit|mathsf|mathtt|textbf|textit|textrm)\{([^}]*)\}',
      ),
      (m) => ' ${m[1]!} ',
    );

    // LaTeX escaped non-breaking space (\ ) -> space
    s = s.replaceAll(r'\ ', ' ');

    // ── Structural: fractions, roots, decorated symbols ──────────────────────

    s = s.replaceAllMapped(
      RegExp(r'\\frac\{([^}]+)\}\{([^}]+)\}'),
      (m) => '${m[1]} over ${m[2]}',
    );
    s = s.replaceAllMapped(
      RegExp(r'\\sqrt\[([^\]]+)\]\{([^}]+)\}'),
      (m) => '${m[1]} root of ${m[2]}',
    );
    s = s.replaceAllMapped(
      RegExp(r'\\sqrt\{([^}]+)\}'),
      (m) => 'square root of ${m[1]}',
    );
    s = s.replaceAllMapped(
      RegExp(r'\\vec\{([^}]+)\}'),
      (m) => 'vector ${m[1]}',
    );
    s = s.replaceAllMapped(
      RegExp(r'\\hat\{([^}]+)\}'),
      (m) => '${m[1]} hat',
    );
    s = s.replaceAllMapped(
      RegExp(r'\\bar\{([^}]+)\}'),
      (m) => '${m[1]} bar',
    );
    s = s.replaceAllMapped(
      RegExp(r'\\tilde\{([^}]+)\}'),
      (m) => '${m[1]} tilde',
    );
    s = s.replaceAllMapped(
      RegExp(r'\\dot\{([^}]+)\}'),
      (m) => '${m[1]} dot',
    );
    s = s.replaceAllMapped(
      RegExp(r'\\ddot\{([^}]+)\}'),
      (m) => '${m[1]} double dot',
    );
    s = s.replaceAllMapped(
      RegExp(r'\\mathbb\{([^}]+)\}'),
      (m) {
        const sets = {
          'R': 'the real numbers',
          'N': 'the natural numbers',
          'Z': 'the integers',
          'Q': 'the rational numbers',
          'C': 'the complex numbers',
          'P': 'the prime numbers',
        };
        return sets[m[1]] ?? m[1]!;
      },
    );

    // ── Superscripts & subscripts ─────────────────────────────────────────────

    s = s.replaceAllMapped(
      RegExp(r'\^\{([^}]+)\}'),
      (m) => ' to the power of ${m[1]}',
    );
    s = s.replaceAllMapped(
      RegExp(r'_\{([^}]+)\}'),
      (m) => ' sub ${m[1]}',
    );
    s = s.replaceAll('^2', ' squared');
    s = s.replaceAll('^3', ' cubed');
    s = s.replaceAllMapped(
      RegExp(r'\^(-?\d+)'),
      (m) => ' to the power of ${m[1]}',
    );
    s = s.replaceAllMapped(
      RegExp(r'\^([a-zA-Z])'),
      (m) => ' to the power of ${m[1]}',
    );
    s = s.replaceAllMapped(
      RegExp(r'(?<=\b[a-zA-Z])_(\d+)\b'),
      (m) => ' sub ${m[1]}',
    );

    // ── Trig, inverse trig, hyperbolic ────────────────────────────────────────

    s = s
        .replaceAll(r'\arcsin', 'arc sine')
        .replaceAll(r'\arccos', 'arc cosine')
        .replaceAll(r'\arctan', 'arc tangent')
        .replaceAll(r'\arccot', 'arc cotangent')
        .replaceAll(r'\arcsec', 'arc secant')
        .replaceAll(r'\arccsc', 'arc cosecant')
        .replaceAll(r'\sinh', 'hyperbolic sine')
        .replaceAll(r'\cosh', 'hyperbolic cosine')
        .replaceAll(r'\tanh', 'hyperbolic tangent')
        .replaceAll(r'\coth', 'hyperbolic cotangent')
        .replaceAll(r'\sin', 'sine')
        .replaceAll(r'\cos', 'cosine')
        .replaceAll(r'\tan', 'tangent')
        .replaceAll(r'\cot', 'cotangent')
        .replaceAll(r'\sec', 'secant')
        .replaceAll(r'\csc', 'cosecant')
        .replaceAll(r'\log', 'log')
        .replaceAll(r'\ln', 'natural log')
        .replaceAll(r'\exp', 'e to the power of')
        .replaceAll(r'\lim', 'limit')
        .replaceAll(r'\max', 'maximum')
        .replaceAll(r'\min', 'minimum')
        .replaceAll(r'\sup', 'supremum')
        .replaceAll(r'\inf', 'infimum')
        .replaceAll(r'\gcd', 'G-C-D')
        .replaceAll(r'\deg', 'degrees');

    // ── Calculus ──────────────────────────────────────────────────────────────

    s = s
        .replaceAll(r'\iiint', 'triple integral')
        .replaceAll(r'\iint', 'double integral')
        .replaceAll(r'\int', 'integral')
        .replaceAll(r'\oint', 'contour integral')
        .replaceAll(r'\sum', 'sum')
        .replaceAll(r'\prod', 'product')
        .replaceAll(r'\partial', 'partial')
        .replaceAll(r'\nabla', 'nabla');

    // ── Comparison & equality ─────────────────────────────────────────────────

    s = s
        .replaceAll(r'\neq', 'is not equal to')
        .replaceAll(r'\ne', 'is not equal to')
        .replaceAll(r'\geq', 'is greater than or equal to')
        .replaceAll(r'\ge', 'is greater than or equal to')
        .replaceAll(r'\leq', 'is less than or equal to')
        .replaceAll(r'\le', 'is less than or equal to')
        .replaceAll(r'\gg', 'is much greater than')
        .replaceAll(r'\ll', 'is much less than')
        .replaceAllMapped(
          RegExp(r'\\approx\s*(\d)'),
          (m) => 'approximately ${m[1]}',
        )
        .replaceAll(r'\approx', 'approximately equals')
        .replaceAll(r'\sim', 'is similar to')
        .replaceAll(r'\cong', 'is congruent to')
        .replaceAll(r'\equiv', 'is equivalent to')
        .replaceAll(r'\propto', 'is proportional to')
        .replaceAll(r'\pm', 'plus or minus')
        .replaceAll(r'\mp', 'minus or plus');

    // ── Arithmetic ────────────────────────────────────────────────────────────

    s = s
        .replaceAll(r'\times', 'times')
        .replaceAll(r'\cdot', 'times')
        .replaceAll(r'\div', 'divided by')
        .replaceAll(r'\oplus', 'plus')
        .replaceAll(r'\ominus', 'minus')
        .replaceAll(r'\otimes', 'tensor product')
        .replaceAll(r'\circ', 'composed with')
        .replaceAll(r'\%', 'percent');

    // ── Set theory ────────────────────────────────────────────────────────────

    s = s
        .replaceAll(r'\notin', 'not in')
        .replaceAll(r'\in', 'in')
        .replaceAll(r'\ni', 'contains')
        .replaceAll(r'\subseteq', 'is a subset of or equal to')
        .replaceAll(r'\subset', 'is a subset of')
        .replaceAll(r'\supseteq', 'is a superset of or equal to')
        .replaceAll(r'\supset', 'is a superset of')
        .replaceAll(r'\cup', 'union')
        .replaceAll(r'\cap', 'intersection')
        .replaceAll(r'\setminus', 'minus')
        .replaceAll(r'\varnothing', 'empty set')
        .replaceAll(r'\emptyset', 'empty set')
        .replaceAll(r'\infty', 'infinity');

    // ── Logic ─────────────────────────────────────────────────────────────────

    s = s
        .replaceAll(r'\forall', 'for all')
        .replaceAll(r'\nexists', 'there does not exist')
        .replaceAll(r'\exists', 'there exists')
        .replaceAll(r'\lnot', 'not')
        .replaceAll(r'\neg', 'not')
        .replaceAll(r'\land', 'and')
        .replaceAll(r'\lor', 'or')
        .replaceAll(r'\Leftrightarrow', 'if and only if')
        .replaceAll(r'\Rightarrow', 'implies')
        .replaceAll(r'\Leftarrow', 'is implied by')
        .replaceAll(r'\leftrightarrow', 'corresponds to')
        .replaceAll(r'\rightarrow', 'maps to')
        .replaceAll(r'\leftarrow', 'comes from')
        .replaceAll(r'\longrightarrow', 'maps to')
        .replaceAll(r'\mapsto', 'maps to')
        .replaceAll(r'\to', 'to')
        .replaceAll(r'\iff', 'if and only if')
        .replaceAll(r'\implies', 'implies')
        .replaceAll(r'\therefore', 'therefore')
        .replaceAll(r'\because', 'because');

    // ── Lowercase Greek ───────────────────────────────────────────────────────

    s = s
        .replaceAll(r'\varepsilon', 'epsilon')
        .replaceAll(r'\epsilon', 'epsilon')
        .replaceAll(r'\vartheta', 'theta')
        .replaceAll(r'\varpi', 'pi')
        .replaceAll(r'\varrho', 'rho')
        .replaceAll(r'\varsigma', 'sigma')
        .replaceAll(r'\varphi', 'phi')
        .replaceAll(r'\alpha', 'alpha')
        .replaceAll(r'\beta', 'beta')
        .replaceAll(r'\gamma', 'gamma')
        .replaceAll(r'\delta', 'delta')
        .replaceAll(r'\zeta', 'zeta')
        .replaceAll(r'\eta', 'eta')
        .replaceAll(r'\theta', 'theta')
        .replaceAll(r'\iota', 'iota')
        .replaceAll(r'\kappa', 'kappa')
        .replaceAll(r'\lambda', 'lambda')
        .replaceAll(r'\mu', 'mu')
        .replaceAll(r'\nu', 'nu')
        .replaceAll(r'\xi', 'xi')
        .replaceAll(r'\pi', 'pi')
        .replaceAll(r'\rho', 'rho')
        .replaceAll(r'\sigma', 'sigma')
        .replaceAll(r'\tau', 'tau')
        .replaceAll(r'\upsilon', 'upsilon')
        .replaceAll(r'\phi', 'phi')
        .replaceAll(r'\chi', 'chi')
        .replaceAll(r'\psi', 'psi')
        .replaceAll(r'\omega', 'omega');

    // ── Uppercase Greek ───────────────────────────────────────────────────────

    s = s
        .replaceAll(r'\Gamma', 'Gamma')
        .replaceAll(r'\Delta', 'Delta')
        .replaceAll(r'\Theta', 'Theta')
        .replaceAll(r'\Lambda', 'Lambda')
        .replaceAll(r'\Xi', 'Xi')
        .replaceAll(r'\Pi', 'Pi')
        .replaceAll(r'\Sigma', 'Sigma')
        .replaceAll(r'\Upsilon', 'Upsilon')
        .replaceAll(r'\Phi', 'Phi')
        .replaceAll(r'\Psi', 'Psi')
        .replaceAll(r'\Omega', 'Omega');

    // ── Dots, spacing, ellipses ───────────────────────────────────────────────

    s = s
        .replaceAll(r'\cdots', ', and so on,')
        .replaceAll(r'\ldots', ', and so on,')
        .replaceAll(r'\vdots', '')
        .replaceAll(r'\ddots', '')
        .replaceAll(r'\qquad', ' ')
        .replaceAll(r'\quad', ' ')
        .replaceAll(r'\;', ' ')
        .replaceAll(r'\,', ' ')
        .replaceAll(r'\!', '');

    // ── Brackets / delimiters ─────────────────────────────────────────────────

    s = s
        .replaceAll(r'\langle', '(')
        .replaceAll(r'\rangle', ')')
        .replaceAll(r'\lfloor', 'floor of ')
        .replaceAll(r'\rfloor', '')
        .replaceAll(r'\lceil', 'ceiling of ')
        .replaceAll(r'\rceil', '')
        .replaceAll(r'\{', '')
        .replaceAll(r'\}', '');

    // ── Strip remaining curly braces ──────────────────────────────────────────
    s = s.replaceAll(RegExp('[{}]'), ' ');

    return s.trim();
  }

  static String _numberToSpoken(int n) {
    const units = [
      'zero',
      'one',
      'two',
      'three',
      'four',
      'five',
      'six',
      'seven',
      'eight',
      'nine',
      'ten',
      'eleven',
      'twelve',
      'thirteen',
      'fourteen',
      'fifteen',
      'sixteen',
      'seventeen',
      'eighteen',
      'nineteen',
    ];
    const tens = [
      '',
      '',
      'twenty',
      'thirty',
      'forty',
      'fifty',
      'sixty',
      'seventy',
      'eighty',
      'ninety',
    ];

    if (n < 20) return units[n];
    if (n < 100) {
      final t = n ~/ 10;
      final u = n % 10;
      return u == 0 ? tens[t] : '${tens[t]}-${units[u]}';
    }
    return n.toString();
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

  /// Normalizes scientific measurements, electricity, and SI units into natural spoken words.
  static String _normalizeUnits(String input) {
    var text = input;

    // Compound units with /
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
          RegExp(r'\bm/s²\b', caseSensitive: false),
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
        );

    // Units attached to numbers (e.g. 10μF, 5V, 4A, 2kg, 30kJ, 500Hz)
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:μ|u|mu|micro)\s*F\b', caseSensitive: false),
      (m) => '${m[1]} microfarads',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:nF)\b'),
      (m) => '${m[1]} nanofarads',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:pF)\b'),
      (m) => '${m[1]} picofarads',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:mF)\b'),
      (m) => '${m[1]} millifarads',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:kHz)\b', caseSensitive: false),
      (m) => '${m[1]} kilohertz',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:MHz)\b'),
      (m) => '${m[1]} megahertz',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:GHz)\b'),
      (m) => '${m[1]} gigahertz',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:Hz)\b', caseSensitive: false),
      (m) => '${m[1]} hertz',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:kJ)\b', caseSensitive: false),
      (m) => '${m[1]} kilojoules',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:mJ)\b'),
      (m) => '${m[1]} millijoules',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:MJ)\b'),
      (m) => '${m[1]} megajoules',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*J\b'),
      (m) => '${m[1]} joules',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:kN)\b', caseSensitive: false),
      (m) => '${m[1]} kilonewtons',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*N\b'),
      (m) => '${m[1]} newtons',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:kW)\b', caseSensitive: false),
      (m) => '${m[1]} kilowatts',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:MW)\b'),
      (m) => '${m[1]} megawatts',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*W\b'),
      (m) => '${m[1]} watts',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:kΩ|kOmega)\b', caseSensitive: false),
      (m) => '${m[1]} kilo-ohms',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:MΩ|MOmega)\b'),
      (m) => '${m[1]} mega-ohms',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:Ω|Omega|ohms?)\b', caseSensitive: false),
      (m) => '${m[1]} ohms',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:kV)\b', caseSensitive: false),
      (m) => '${m[1]} kilovolts',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:mV)\b'),
      (m) => '${m[1]} millivolts',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*V\b'),
      (m) => '${m[1]} volts',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:mA)\b'),
      (m) => '${m[1]} milliamperes',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*A\b'),
      (m) => '${m[1]} amperes',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*T\b'),
      (m) => '${m[1]} teslas',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:kg)\b', caseSensitive: false),
      (m) => '${m[1]} kilograms',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:mg)\b', caseSensitive: false),
      (m) => '${m[1]} milligrams',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:km)\b', caseSensitive: false),
      (m) => '${m[1]} kilometers',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:cm)\b', caseSensitive: false),
      (m) => '${m[1]} centimeters',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:mm)\b', caseSensitive: false),
      (m) => '${m[1]} millimeters',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:nm)\b', caseSensitive: false),
      (m) => '${m[1]} nanometers',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*m\b'),
      (m) => '${m[1]} meters',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:mL)\b', caseSensitive: false),
      (m) => '${m[1]} milliliters',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*L\b'),
      (m) => '${m[1]} liters',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:ms)\b'),
      (m) => '${m[1]} milliseconds',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*s\b'),
      (m) => '${m[1]} seconds',
    );

    return text;
  }

  /// Converts a fenced code block into speech-friendly conversational English.
  static String _normalizeCodeBlock(String rawCodeBlock) {
    final match = RegExp(
      r'```(?:([a-zA-Z0-9_\-+]*)\r?\n)?([\s\S]*?)```',
    ).firstMatch(rawCodeBlock);

    if (match == null) {
      return ', here is the code snippet: , ';
    }

    final rawLang = match.group(1)?.trim() ?? '';
    final code = match.group(2)?.trim() ?? '';

    if (code.isEmpty) {
      return ', here is the code snippet: , ';
    }

    final langName = switch (rawLang.toLowerCase()) {
      'dart' => 'Dart',
      'flutter' => 'Flutter',
      'py' || 'python' => 'Python',
      'js' || 'javascript' => 'JavaScript',
      'ts' || 'typescript' => 'TypeScript',
      'html' => 'HTML',
      'css' => 'CSS',
      'sql' => 'SQL',
      'java' => 'Java',
      'c' => 'C',
      'cpp' || 'c++' => 'C plus plus',
      'cs' || 'c#' => 'C sharp',
      'rb' || 'ruby' => 'Ruby',
      'go' || 'golang' => 'Go',
      'rust' => 'Rust',
      'swift' => 'Swift',
      'kt' || 'kotlin' => 'Kotlin',
      'sh' || 'bash' => 'bash',
      'json' => 'JSON',
      _ => rawLang.isNotEmpty ? rawLang : '',
    };

    final intro = langName.isNotEmpty
        ? ', here is the code snippet in $langName: '
        : ', here is the code snippet: ';

    final lines = code
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    // If concise snippet (<= 4 lines or <= 180 chars), pronounce the code lines
    if (lines.length <= 4 && code.length <= 180) {
      final spokenLines = lines.map(_convertCodeLineToSpeech).join(', ');
      return '$intro$spokenLines, ';
    }

    // For longer snippets, announce the language and read the opening 2 lines then summarize
    final preview = lines.take(2).map(_convertCodeLineToSpeech).join(', ');
    return '$intro$preview, continuing the implementation, ';
  }

  /// Converts code syntax and symbols in a line to human-audible speech.
  static String _convertCodeLineToSpeech(String line) {
    var s = line;

    // Expand common programming operators and symbols
    s = s.replaceAll('=>', ' returns ');
    s = s.replaceAll('===', ' strictly equals ');
    s = s.replaceAll('!==', ' strictly does not equal ');
    s = s.replaceAll('==', ' equals ');
    s = s.replaceAll('!=', ' does not equal ');
    s = s.replaceAll('<=', ' is less than or equal to ');
    s = s.replaceAll('>=', ' is greater than or equal to ');
    s = s.replaceAll('&&', ' and ');
    s = s.replaceAll('||', ' or ');
    s = s.replaceAll('++', ' plus plus ');
    s = s.replaceAll('--', ' minus minus ');
    s = s.replaceAll('+=', ' plus equals ');
    s = s.replaceAll('-=', ' minus equals ');
    s = s.replaceAll('*=', ' times equals ');
    s = s.replaceAll('/=', ' divided by equals ');
    s = s.replaceAll('->', ' points to ');
    s = s.replaceAll('::', ' double colon ');

    // Normalize brackets and delimiters to natural commas/pauses
    s = s.replaceAll(RegExp('[{};]+'), ', ');
    s = s.replaceAll(RegExp(r'\(\s*\)'), '');
    s = s.replaceAll(RegExp(r'\[\s*\]'), '');

    // Split identifiers like camelCase or PascalCase so TTS pronounces distinct words
    s = s.replaceAllMapped(
      RegExp('([a-z])([A-Z])'),
      (m) => '${m[1]} ${m[2]}',
    );
    // Replace underscores with spaces in snake_case
    s = s.replaceAll('_', ' ');

    // Strip remaining punctuation noise
    s = s.replaceAll(RegExp(r'[<>()\[\]"\x27]'), ' ');
    s = s.replaceAll(RegExp(r'\s{2,}'), ' ').trim();

    return s;
  }
}
