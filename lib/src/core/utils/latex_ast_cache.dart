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
      _cleanedFormulaCache.remove(raw);
      _cleanedFormulaCache[raw] = cached;
      return cached;
    }

    var clean = raw.trim();
    if (clean.startsWith(r'\(') && clean.endsWith(r'\)')) {
      clean = clean.substring(2, clean.length - 2).trim();
    } else if (clean.startsWith(r'\[') && clean.endsWith(r'\]')) {
      clean = clean.substring(2, clean.length - 2).trim();
    } else if (clean.startsWith(r'$$') && clean.endsWith(r'$$')) {
      clean = clean.substring(2, clean.length - 2).trim();
    } else if (clean.startsWith(r'$') && clean.endsWith(r'$')) {
      clean = clean.substring(1, clean.length - 1).trim();
    }

    if (_cleanedFormulaCache.length >= capacity) {
      _cleanedFormulaCache.remove(_cleanedFormulaCache.keys.first);
    }
    _cleanedFormulaCache[raw] = clean;
    return clean;
  }

  /// Clears all memoized caches
  void clear() {
    _sanitizedCache.clear();
    _cleanedFormulaCache.clear();
  }

  int get size => _sanitizedCache.length + _cleanedFormulaCache.length;
}
