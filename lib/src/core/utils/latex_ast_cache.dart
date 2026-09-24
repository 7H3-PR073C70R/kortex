import 'dart:collection';

/// Zero-allocation, high-performance LRU cache for sanitized LaTeX formulas and AST strings.
/// Prevents redundant string manipulations and AST generation across rapid card flips.
class LatexAstCache {
  LatexAstCache._();

  static final LatexAstCache instance = LatexAstCache._();

  static const int defaultCapacity = 250;

  final LinkedHashMap<String, String> _sanitizedCache =
      LinkedHashMap<String, String>();
  final LinkedHashMap<String, String> _cleanedFormulaCache =
      LinkedHashMap<String, String>();

  int capacity = defaultCapacity;

  /// Retrieves or computes sanitized text
  String getOrComputeSanitized(String raw, String Function(String) compute) {
    if (raw.isEmpty) return '';
    final cached = _sanitizedCache[raw];
    if (cached != null) {
      // Refresh LRU order
      _sanitizedCache.remove(raw);
      _sanitizedCache[raw] = cached;
      return cached;
    }

    final computed = compute(raw);
    if (_sanitizedCache.length >= capacity) {
      _sanitizedCache.remove(_sanitizedCache.keys.first);
    }
    _sanitizedCache[raw] = computed;
    return computed;
  }

  /// Retrieves or cleans formula string
  String getOrCleanFormula(String raw) {
    if (raw.isEmpty) return '';
    final cached = _cleanedFormulaCache[raw];
    if (cached != null) {
      // Refresh LRU order
      _cleanedFormulaCache.remove(raw);
      _cleanedFormulaCache[raw] = cached;
      return cached;
    }

    var clean = raw.trim();

    // 1. Repeatedly strip enclosing or dangling math delimiters
    bool changed;
    do {
      changed = false;
      final prev = clean;

      // Paired delimiters
      if (clean.startsWith(r'\(') && clean.endsWith(r'\)')) {
        clean = clean.substring(2, clean.length - 2).trim();
      } else if (clean.startsWith(r'\[') && clean.endsWith(r'\]')) {
        clean = clean.substring(2, clean.length - 2).trim();
      } else if (clean.startsWith(r'$$') && clean.endsWith(r'$$')) {
        clean = clean.substring(2, clean.length - 2).trim();
      } else if (clean.startsWith(r'$') &&
          clean.endsWith(r'$') &&
          clean.length >= 2) {
        clean = clean.substring(1, clean.length - 1).trim();
      }

      // Dangling leading delimiters
      if (clean.startsWith(r'$$')) {
        clean = clean.substring(2).trim();
      } else if (clean.startsWith(r'\[') || clean.startsWith(r'\(')) {
        clean = clean.substring(2).trim();
      } else if (clean.startsWith(r'$')) {
        clean = clean.substring(1).trim();
      }

      // Dangling trailing delimiters
      if (clean.endsWith(r'$$')) {
        clean = clean.substring(0, clean.length - 2).trim();
      } else if (clean.endsWith(r'\]') || clean.endsWith(r'\)')) {
        clean = clean.substring(0, clean.length - 2).trim();
      } else if (clean.endsWith(r'$')) {
        clean = clean.substring(0, clean.length - 1).trim();
      }

      if (clean != prev) {
        changed = true;
      }
    } while (changed);

    // 2. Normalize common unsupported TeX macros and environments
    // Chemical equilibrium arrows: \xrightleftharpoons{...} -> \overset{...}{\rightleftharpoons}
    clean = clean.replaceAllMapped(
      RegExp(r'\\xrightleftharpoons(?:\[([^\]]*)\])?\{([^}]*)\}'),
      (m) => '\\overset{${m.group(2) ?? ''}}{\\rightleftharpoons}',
    );
    // Unsupported arrows & relations
    clean = clean.replaceAll(r'\implies', r'\Longrightarrow');
    clean = clean.replaceAll(r'\iff', r'\Longleftrightarrow');
    clean = clean.replaceAll(r'\ointctrclockwise', r'\oint');
    clean = clean.replaceAll(r'\to', r'\rightarrow');
    clean = clean.replaceAll('-->', r'\rightarrow');
    clean = clean.replaceAll('<=>', r'\Leftrightarrow');
    clean = clean.replaceAll('<->', r'\leftrightarrow');
    clean = clean.replaceAll(r'\degree', r'^\circ');
    clean = clean.replaceAll('°', r'^\circ');

    // Number sets: \R, \N, \Z, \Q, \C without mathbb
    clean = clean.replaceAllMapped(
      RegExp(r'\\(R|N|Z|Q|C)\b'),
      (m) => '\\mathbb{${m.group(1)}}',
    );

    // Unescape escaped single quotes or quotes inside \text
    clean = clean.replaceAll(r"\'", "'");

    // Fix unescaped percentage signs in math: "100%" -> "100\%"
    clean = clean.replaceAllMapped(
      RegExp(r'(?<!\\)%'),
      (m) => r'\%',
    );

    // 3. Remove dangling backslash at the end
    while (clean.endsWith(r'\') && !clean.endsWith(r'\\')) {
      clean = clean.substring(0, clean.length - 1).trim();
    }

    // 4. Balance \left and \right delimiters (prevent flutter_math_fork parsing crashes)
    final leftMatches = RegExp(r'\\left[\(\[\{\.\|]').allMatches(clean).length;
    final rightMatches = RegExp(r'\\right[\)\]\}\.\|]').allMatches(clean).length;
    if (leftMatches > rightMatches) {
      clean = clean + (r'\right.' * (leftMatches - rightMatches));
    } else if (rightMatches > leftMatches) {
      clean = (r'\left.' * (rightMatches - leftMatches)) + clean;
    }

    // 5. Balance unclosed curly braces (e.g. truncated "\text{Pote")
    var openBraces = 0;
    for (var i = 0; i < clean.length; i++) {
      if (clean[i] == '{' && (i == 0 || clean[i - 1] != r'\')) {
        openBraces++;
      } else if (clean[i] == '}' && (i == 0 || clean[i - 1] != r'\')) {
        if (openBraces > 0) {
          openBraces--;
        }
      }
    }
    if (openBraces > 0) {
      clean = clean + ('}' * openBraces);
    }

    if (_cleanedFormulaCache.length >= capacity) {
      _cleanedFormulaCache.remove(_cleanedFormulaCache.keys.first);
    }
    _cleanedFormulaCache[raw] = clean;
    return clean;
  }

  /// Converts a broken or unsupported LaTeX formula into human-readable math typography
  String formatLatexHumanReadableFallback(String formula) {
    var s = getOrCleanFormula(formula);
    if (s.isEmpty) return '';

    // Convert fractions: \frac{a}{b} -> (a) / (b)
    s = s.replaceAllMapped(
      RegExp(r'\\frac\s*\{([^{}]+)\}\s*\{([^{}]+)\}'),
      (m) => '(${m.group(1)}) / (${m.group(2)})',
    );

    // Unpack text tags: \text{...}, \mathrm{...}, \mathbf{...}, \mathbb{...}
    s = s.replaceAllMapped(
      RegExp(r'\\(?:text|mathrm|mathbf|mathit|textbf|textrm|mathbb|mathcal)\s*\{([^{}]*)\}'),
      (m) => m.group(1) ?? '',
    );

    // Convert standard math symbols and arrows
    s = s.replaceAll(r'\times', '×');
    s = s.replaceAll(r'\cdot', '·');
    s = s.replaceAll(r'\div', '÷');
    s = s.replaceAll(r'\pm', '±');
    s = s.replaceAll(r'\mp', '∓');
    s = s.replaceAll(r'\approx', '≈');
    s = s.replaceAll(r'\neq', '≠');
    s = s.replaceAll(r'\le', '≤');
    s = s.replaceAll(r'\ge', '≥');
    s = s.replaceAll(r'\infty', '∞');
    s = s.replaceAll(r'\sqrt', '√');
    s = s.replaceAll(r'\Longrightarrow', '⟹');
    s = s.replaceAll(r'\implies', '⟹');
    s = s.replaceAll(r'\rightarrow', '→');
    s = s.replaceAll(r'\leftarrow', '←');
    s = s.replaceAll(r'\leftrightarrow', '↔');
    s = s.replaceAll(r'\rightleftharpoons', '⇌');
    s = s.replaceAll(r'\angle', '∠');
    s = s.replaceAll(r'\quad', '  ');
    s = s.replaceAll(r'\qquad', '    ');
    s = s.replaceAll(r'^\circ', '°');

    // Greek letters
    s = s.replaceAll(r'\alpha', 'α');
    s = s.replaceAll(r'\beta', 'β');
    s = s.replaceAll(r'\gamma', 'γ');
    s = s.replaceAll(r'\theta', 'θ');
    s = s.replaceAll(r'\pi', 'π');
    s = s.replaceAll(r'\lambda', 'λ');
    s = s.replaceAll(r'\mu', 'μ');
    s = s.replaceAll(r'\sigma', 'σ');
    s = s.replaceAll(r'\omega', 'ω');
    s = s.replaceAll(r'\Delta', 'Δ');
    s = s.replaceAll(r'\Omega', 'Ω');
    s = s.replaceAll(r'\Sigma', 'Σ');
    s = s.replaceAll(r'\partial', '∂');
    s = s.replaceAll(r'\sum', '∑');
    s = s.replaceAll(r'\int', '∫');
    s = s.replaceAll(r'\oint', '∮');

    // Remove remaining stray LaTeX commands and braces
    s = s.replaceAll(RegExp(r'\\[a-zA-Z]+'), '');
    s = s.replaceAll('{', '');
    s = s.replaceAll('}', '');
    s = s.replaceAll(RegExp(r'\s{2,}'), ' ');

    return s.trim();
  }

  /// Clears all memoized caches
  void clear() {
    _sanitizedCache.clear();
    _cleanedFormulaCache.clear();
  }

  int get size => _sanitizedCache.length + _cleanedFormulaCache.length;
}
