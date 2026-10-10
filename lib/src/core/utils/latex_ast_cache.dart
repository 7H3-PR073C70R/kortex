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
    clean = clean.replaceAll(RegExp(r'\\to(?![a-zA-Z])'), r'\rightarrow');
    clean = clean.replaceAll('-->', r'\rightarrow');
    clean = clean.replaceAll('<=>', r'\Leftrightarrow');
    clean = clean.replaceAll('<->', r'\leftrightarrow');
    clean = clean.replaceAll(r'\degree', r'^\circ');
    clean = clean.replaceAll('°', r'^\circ');
    clean = clean.replaceAll(RegExp(r'\\le(?![a-zA-Z])'), r'\leq');
    clean = clean.replaceAll(RegExp(r'\\ge(?![a-zA-Z])'), r'\geq');
    clean = clean.replaceAll(r'$', '');

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

    // Remove \left and \right delimiters cleanly
    s = s.replaceAll(RegExp(r'\\(?:left|right)\s*'), '');

    // Convert fractions: \frac{a}{b} -> (a) / (b)
    s = s.replaceAllMapped(
      RegExp(r'\\frac\s*\{([^{}]+)\}\s*\{([^{}]+)\}'),
      (m) => '(${m.group(1)}) / (${m.group(2)})',
    );

    // Convert dot accents: \dot{q} -> q̇, \ddot{q} -> q̈
    s = s.replaceAllMapped(
      RegExp(r'\\dot\s*\{?([a-zA-Z0-9]+)\}?'),
      (m) => '${m.group(1)}̇',
    );
    s = s.replaceAllMapped(
      RegExp(r'\\ddot\s*\{?([a-zA-Z0-9]+)\}?'),
      (m) => '${m.group(1)}̈',
    );

    // Unpack text tags: \text{...}, \mathrm{...}, \mathbf{...}, \mathbb{...}
    s = s.replaceAllMapped(
      RegExp(r'\\(?:text|mathrm|mathbf|mathit|textbf|textrm|mathbb|mathcal)\s*\{([^{}]*)\}'),
      (m) => m.group(1) ?? '',
    );

    // Convert standard math symbols and arrows using word boundary checks (?![a-zA-Z])
    s = s.replaceAll(RegExp(r'\\times(?![a-zA-Z])'), '×');
    s = s.replaceAll(RegExp(r'\\cdot(?![a-zA-Z])'), '·');
    s = s.replaceAll(RegExp(r'\\div(?![a-zA-Z])'), '÷');
    s = s.replaceAll(RegExp(r'\\pm(?![a-zA-Z])'), '±');
    s = s.replaceAll(RegExp(r'\\mp(?![a-zA-Z])'), '∓');
    s = s.replaceAll(RegExp(r'\\approx(?![a-zA-Z])'), '≈');
    s = s.replaceAll(RegExp(r'\\neq(?![a-zA-Z])'), '≠');
    s = s.replaceAll(RegExp(r'\\le(?![a-zA-Z])|\\leq(?![a-zA-Z])'), '≤');
    s = s.replaceAll(RegExp(r'\\ge(?![a-zA-Z])|\\geq(?![a-zA-Z])'), '≥');
    s = s.replaceAll(RegExp(r'\\infty(?![a-zA-Z])'), '∞');
    s = s.replaceAll(RegExp(r'\\sqrt(?![a-zA-Z])'), '√');
    s = s.replaceAll(RegExp(r'\\Longrightarrow(?![a-zA-Z])'), '⟹');
    s = s.replaceAll(RegExp(r'\\implies(?![a-zA-Z])'), '⟹');
    s = s.replaceAll(RegExp(r'\\to(?![a-zA-Z])|\\rightarrow(?![a-zA-Z])'), '→');
    s = s.replaceAll(RegExp(r'\\leftarrow(?![a-zA-Z])'), '←');
    s = s.replaceAll(RegExp(r'\\leftrightarrow(?![a-zA-Z])'), '↔');
    s = s.replaceAll(RegExp(r'\\rightleftharpoons(?![a-zA-Z])'), '⇌');
    s = s.replaceAll(RegExp(r'\\angle(?![a-zA-Z])'), '∠');
    s = s.replaceAll(RegExp(r'\\quad(?![a-zA-Z])'), '  ');
    s = s.replaceAll(RegExp(r'\\qquad(?![a-zA-Z])'), '    ');
    s = s.replaceAll(r'^\circ', '°');

    // Greek letters
    s = s.replaceAll(RegExp(r'\\alpha(?![a-zA-Z])'), 'α');
    s = s.replaceAll(RegExp(r'\\beta(?![a-zA-Z])'), 'β');
    s = s.replaceAll(RegExp(r'\\gamma(?![a-zA-Z])'), 'γ');
    s = s.replaceAll(RegExp(r'\\theta(?![a-zA-Z])'), 'θ');
    s = s.replaceAll(RegExp(r'\\pi(?![a-zA-Z])'), 'π');
    s = s.replaceAll(RegExp(r'\\lambda(?![a-zA-Z])'), 'λ');
    s = s.replaceAll(RegExp(r'\\mu(?![a-zA-Z])'), 'μ');
    s = s.replaceAll(RegExp(r'\\sigma(?![a-zA-Z])'), 'σ');
    s = s.replaceAll(RegExp(r'\\omega(?![a-zA-Z])'), 'ω');
    s = s.replaceAll(RegExp(r'\\Delta(?![a-zA-Z])'), 'Δ');
    s = s.replaceAll(RegExp(r'\\Omega(?![a-zA-Z])'), 'Ω');
    s = s.replaceAll(RegExp(r'\\Sigma(?![a-zA-Z])'), 'Σ');
    s = s.replaceAll(RegExp(r'\\partial(?![a-zA-Z])'), '∂');
    s = s.replaceAll(RegExp(r'\\sum(?![a-zA-Z])'), '∑');
    s = s.replaceAll(RegExp(r'\\int(?![a-zA-Z])'), '∫');
    s = s.replaceAll(RegExp(r'\\oint(?![a-zA-Z])'), '∮');

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
