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
      } else if (clean.startsWith(r'$') && clean.endsWith(r'$') && clean.length >= 2) {
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

    // 2. Remove dangling backslash at the end
    while (clean.endsWith(r'\') && !clean.endsWith(r'\\')) {
      clean = clean.substring(0, clean.length - 1).trim();
    }

    // 3. Balance unclosed curly braces (e.g. truncated "\text{Pote")
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

    // Unpack text tags: \text{...}, \mathrm{...}, \mathbf{...}
    s = s.replaceAllMapped(
      RegExp(r'\\(?:text|mathrm|mathbf|mathit|textbf|textrm)\s*\{([^{}]*)\}'),
      (m) => m.group(1) ?? '',
    );

    // Convert standard math symbols
    s = s.replaceAll(r'\times', '×');
    s = s.replaceAll(r'\cdot', '·');
    s = s.replaceAll(r'\div', '÷');
    s = s.replaceAll(r'\pm', '±');
    s = s.replaceAll(r'\approx', '≈');
    s = s.replaceAll(r'\neq', '≠');
    s = s.replaceAll(r'\le', '≤');
    s = s.replaceAll(r'\ge', '≥');
    s = s.replaceAll(r'\infty', '∞');
    s = s.replaceAll(r'\sqrt', '√');
    s = s.replaceAll(r'\alpha', 'α');
    s = s.replaceAll(r'\beta', 'β');
    s = s.replaceAll(r'\gamma', 'γ');
    s = s.replaceAll(r'\theta', 'θ');
    s = s.replaceAll(r'\pi', 'π');
    s = s.replaceAll(r'\Delta', 'Δ');
    s = s.replaceAll(r'\Omega', 'Ω');
    s = s.replaceAll(r'\partial', '∂');
    s = s.replaceAll(r'\sum', '∑');
    s = s.replaceAll(r'\int', '∫');

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
