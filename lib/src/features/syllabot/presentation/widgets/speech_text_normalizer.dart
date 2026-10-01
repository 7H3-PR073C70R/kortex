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
    'JAMB': 'J-A-M-B',
    'WAEC': 'W-A-E-C',
    'UTME': 'U-T-M-E',
    'NECO': 'N-E-C-O',
    'NABTEB': 'N-A-B-T-E-B',
    'POST-UTME': 'Post U-T-M-E',
    'Post-UTME': 'Post U-T-M-E',
    'CBT': 'C-B-T',
    'GPA': 'G-P-A',
    'CGPA': 'C-G-P-A',
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

    // 1. Strip code blocks and inline code
    text = text.replaceAll(
      RegExp(r'```[\s\S]*?```'),
      ', here is the code snippet: , ',
    );
    text = text.replaceAllMapped(RegExp('`([^`]+)`'), (m) => m[1]!);

    // 2. Expand LaTeX math commands into spoken words
    text = _normalizeLatex(text);

    // 3. Strip Markdown headings (#, ##, etc.) and bold/italic syntax
    text = text.replaceAll(RegExp(r'#{1,6}\s*'), '');
    text = text.replaceAllMapped(RegExp(r'(\*\*|__)(.*?)\1'), (m) => m[2]!);
    text = text.replaceAllMapped(RegExp(r'(\*|_)(.*?)\1'), (m) => m[2]!);
    text = text.replaceAllMapped(RegExp('~~(.*?)~~'), (m) => m[1]!);

    // 4. Markdown links: retain link title, remove URL
    text = text.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\([^)]+\)'),
      (m) => m[1]!,
    );

    // 5. Remove standalone raw URLs
    text = text.replaceAll(RegExp(r'https?://\S+'), '');

    // 6. Clean bullet points & numbered lists
    // Convert bullet lists into natural pauses
    text = text.replaceAll(RegExp(r'^\s*[-•*]\s+', multiLine: true), ', ');
    text = text.replaceAll(RegExp(r'^\s*\d+\.\s+', multiLine: true), ', ');

    // 7. Strip emojis (Unicode ranges covering standard emoji blocks)
    text = text.replaceAll(
      RegExp(
        r'[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]|[\u{1FA70}-\u{1FAFF}]|[\u{1F000}-\u{1F02F}]',
        unicode: true,
      ),
      '',
    );

    // 8. Normalise Currencies
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

    // 9. Normalise Percentages & Mathematical Comparison Symbols
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)\s*%'),
      (m) => '${m[1]} percent',
    );
    text = text
        .replaceAll(' & ', ' and ')
        .replaceAll('&', ' and ')
        .replaceAll(' > ', ' is greater than ')
        .replaceAll(' < ', ' is less than ')
        .replaceAll(' = ', ' equals ')
        .replaceAll(' != ', ' does not equal ')
        .replaceAll(' ± ', ' plus or minus ');

    // 10. Normalise Times (e.g. "10:30 AM", "8:15 pm")
    text = text.replaceAllMapped(
      RegExp(r'\b(\d{1,2}):(\d{2})\s*(AM|PM|am|pm)\b'),
      (m) {
        final hour = m[1];
        final min = m[2] == '00' ? "o'clock" : m[2];
        final ampm = m[3]!.toUpperCase().split('').join(' ');
        return '$hour $min $ampm';
      },
    );

    // 11. Normalise Academic Acronyms & Abbreviations
    for (final entry in _commonAbbreviations.entries) {
      text = text.replaceAll(
        RegExp(entry.key, caseSensitive: false),
        entry.value,
      );
    }
    for (final entry in _acronymExpansions.entries) {
      text = text.replaceAll(RegExp('\\b${entry.key}\\b'), entry.value);
    }

    // 12. Conversational Year Pronunciation (e.g. 2024 -> "twenty twenty-four")
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

    // 13. Clean punctuation & whitespace
    // Replace em-dash or en-dash with comma pause
    text = text.replaceAll(RegExp('[—–]'), ', ');
    // Replace ellipses with comma pause
    text = text.replaceAll('...', ', ');
    // Collapse newlines: avoid creating double punctuation if preceded by punctuation
    text = text.replaceAll(RegExp(r'(?<=[.!?])\s*\n+'), ' ');
    text = text.replaceAll(RegExp(r'(?<=[,;:])\s*\n+'), ' ');
    text = text.replaceAll(RegExp(r'\n+'), '. ');
    // Collapse multi-spaces
    text = text.replaceAll(RegExp(r'\s{2,}'), ' ');
    // Collapse duplicate punctuation
    text = text.replaceAll(RegExp(r'[,\s]+,'), ',');
    text = text.replaceAll(RegExp(r'([.!?])\s*\.+'), r'$1');
    text = text.replaceAll(RegExp(r'([,:;])\s*\.+'), r'$1');
    text = text.replaceAll(RegExp(r'\.\s*([,:;])'), r'$1');
    text = text.replaceAll(RegExp(r'\.\s*\.'), '.');

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

    // 3. Block math -> spoken
    text = text.replaceAllMapped(
      RegExp(r'\$\$([\s\S]*?)\$\$'),
      (m) => ', ${_expandLatexSymbols(m[1]!)}, ',
    );

    // 4. Inline math -> spoken
    text = text.replaceAllMapped(
      RegExp(r'\$([^$\n]+)\$'),
      (m) => ' ${_expandLatexSymbols(m[1]!)} ',
    );

    // 5. Text/formatting commands outside $: keep inner content only
    text = text.replaceAllMapped(
      RegExp(
        r'\\(?:text|textbf|textit|textrm|textsf|texttt|mathrm|mathbf|mathit|mathsf|mathtt|emph|underline|overline)\{([^}]*)\}',
      ),
      (m) => m[1]!,
    );

    // 6. Strip \left / \right delimiter markers, keep bracket that follows
    text = text.replaceAll(RegExp(r'\\(?:left|right)\s*'), '');

    // 7. Expand all remaining bare LaTeX commands
    text = _expandLatexSymbols(text);

    // 8. Catch-all: \commandname -> drop backslash, keep readable word
    //    Prevents TTS from ever saying "backslash commandname".
    text = text.replaceAllMapped(
      RegExp(r'\\([a-zA-Z]+)'),
      (m) => ' ${m[1]!} ',
    );

    // 9. Lone remaining backslashes -> space
    text = text.replaceAll(RegExp(r'\\'), ' ');

    return text;
  }

  static String _expandLatexSymbols(String math) {
    var s = math;

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
      RegExp('_([a-zA-Z0-9])'),
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
    // avoiding splitting after single-letter initials (e.g., "A.", "B.").
    final sentencePattern = RegExp(r'(?<!\b[A-Z])(?<=[.!?])\s+|\n+');
    final rawSentences = clean.split(sentencePattern);

    final chunks = <String>[];
    final buffer = StringBuffer();

    for (final raw in rawSentences) {
      final s = raw.trim();
      if (s.isEmpty) continue;

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
