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
    r'\bvs\.\b': 'versus',
    r'\bvs\b': 'versus',
    r'\bw/o\b': 'without',
    r'\bw/\b': 'with',
    r'\bDr\.\b': 'Doctor',
    r'\bMr\.\b': 'Mister',
    r'\bMrs\.\b': 'Missus',
    r'\bMs\.\b': 'Miz',
    r'\bProf\.\b': 'Professor',
    r'\bFig\.\b': 'Figure',
    r'\bfig\.\b': 'figure',
    r'\bEq\.\b': 'Equation',
    r'\beq\.\b': 'equation',
    r'\bapprox\.\b': 'approximately',
  };

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
    text = text.replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]+\)'), (m) => m[1]!);

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
      text = text.replaceAll(RegExp(entry.key, caseSensitive: false), entry.value);
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
    // Collapse newlines to natural pause
    text = text.replaceAll(RegExp(r'\n+'), '. ');
    // Collapse multi-spaces
    text = text.replaceAll(RegExp(r'\s{2,}'), ' ');
    // Collapse duplicate punctuation
    text = text.replaceAll(RegExp(r'[,\s]+,'), ',');
    text = text.replaceAll(RegExp(r'\.\s*\.'), '.');

    return text.trim();
  }

  /// Expands common LaTeX syntax to natural spoken phrases.
  static String _normalizeLatex(String input) {
    var text = input;

    // Handle block math $$...$$
    text = text.replaceAllMapped(
      RegExp(r'\$\$([\s\S]*?)\$\$'),
      (m) => ', mathematical equation: ${_expandLatexSymbols(m[1]!)}, ',
    );

    // Handle inline math $...$
    text = text.replaceAllMapped(
      RegExp(r'\$([^$]+)\$'),
      (m) => _expandLatexSymbols(m[1]!),
    );

    return text;
  }

  static String _expandLatexSymbols(String math) {
    var s = math;
    s = s.replaceAllMapped(
      RegExp(r'\\frac\{([^}]+)\}\{([^}]+)\}'),
      (m) => '${m[1]} over ${m[2]}',
    );
    s = s.replaceAllMapped(
      RegExp(r'\\sqrt\{([^}]+)\}'),
      (m) => 'square root of ${m[1]}',
    );
    s = s
        .replaceAll(r'\Delta', 'Delta')
        .replaceAll(r'\pm', 'plus or minus')
        .replaceAll(r'\to', 'to')
        .replaceAll(r'\neq', 'is not equal to')
        .replaceAll(r'\geq', 'is greater than or equal to')
        .replaceAll(r'\leq', 'is less than or equal to')
        .replaceAll(r'\approx', 'approximately equals')
        .replaceAll(r'\infty', 'infinity')
        .replaceAll(r'\alpha', 'alpha')
        .replaceAll(r'\beta', 'beta')
        .replaceAll(r'\gamma', 'gamma')
        .replaceAll(r'\theta', 'theta')
        .replaceAll(r'\pi', 'pi')
        .replaceAll(r'\times', 'times')
        .replaceAll(r'\div', 'divided by')
        .replaceAll(r'\cdot', 'times')
        .replaceAll(r'\circ', 'degrees')
        .replaceAll('^2', ' squared')
        .replaceAll('^3', ' cubed')
        .replaceAll('^', ' to the power of ')
        .replaceAll(RegExp('[{}]'), ' ');

    return s.trim();
  }

  static String _numberToSpoken(int n) {
    const units = [
      'zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight',
      'nine', 'ten', 'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen',
      'sixteen', 'seventeen', 'eighteen', 'nineteen'
    ];
    const tens = [
      '', '', 'twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy',
      'eighty', 'ninety'
    ];

    if (n < 20) return units[n];
    if (n < 100) {
      final t = n ~/ 10;
      final u = n % 10;
      return u == 0 ? tens[t] : '${tens[t]}-${units[u]}';
    }
    return n.toString();
  }

  /// Splits normalized text into natural, cadence-friendly chunks (100–180 chars)
  /// ensuring synthesis starts immediately without mid-sentence chops.
  static List<String> splitIntoChunks(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return [];

    // Split on sentence-ending punctuation while retaining the delimiter
    final sentencePattern = RegExp(r'(?<=[.!?])\s+');
    final rawSentences = clean.split(sentencePattern);

    final chunks = <String>[];
    final buffer = StringBuffer();

    for (final raw in rawSentences) {
      final s = raw.trim();
      if (s.isEmpty) continue;

      // If a single sentence exceeds 180 characters, split on clause boundaries (, ; :)
      if (s.length > 180) {
        final clauseParts = s.split(RegExp(r'(?<=[,;:])\s+'));
        for (final clause in clauseParts) {
          final c = clause.trim();
          if (c.isEmpty) continue;

          if (buffer.isEmpty) {
            buffer.write(c);
          } else if (buffer.length + c.length + 1 > 160) {
            chunks.add(buffer.toString());
            buffer
              ..clear()
              ..write(c);
          } else {
            buffer.write(' $c');
          }
        }
      } else {
        if (buffer.isEmpty) {
          buffer.write(s);
        } else if (buffer.length + s.length + 1 > 150) {
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
