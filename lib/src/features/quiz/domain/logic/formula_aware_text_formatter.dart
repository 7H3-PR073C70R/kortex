/// Comprehensive, domain-aware utility to detect and format mathematical expressions,
/// chemical reactions, formulas, and raw LaTeX commands across options and study cards.
class FormulaAwareTextFormatter {
  FormulaAwareTextFormatter._();

  static final RegExp _mathDelimiterRegex = RegExp(
    r'(\\\([\s\S]*?\\\)|\$\$[\s\S]*?\$\$|\\\[[\s\S]*?\\\]|\$(?!\$)[\s\S]*?\$)',
  );

  static final RegExp _rawLatexCmdRegex = RegExp(
    r'\\(frac|sqrt|alpha|beta|gamma|theta|pi|pm|times|div|le|ge|neq|approx|infty|circ|partial|sum|int|to|rightarrow|Leftarrow|Rightarrow|mathrm|mathbf|text|lambda|mu|sigma|omega|Delta|Omega)\b',
  );

  static final RegExp _optionPrefixRegex = RegExp(
    r'^(\s*(?:•\s*)?(?:[A-Ea-e][\.\)]|\([A-Ea-e]\))\s*)',
  );

  static final RegExp _commonEnglishWordsRegex = RegExp(
    r'\b(the|is|are|was|were|which|what|when|where|who|how|because|reaction|process|between|compound|element|energy|water|acid|base|salt|solution|state|substance|neutralization|decomposition|diffusion|photosynthesis|respiration|circulation|cellular|mitosis|meiosis|dominant|recessive|ecosystem|increase|decrease|increases|decreases|remains|constant|produces|formed|greater|less|equal|according|principle|concept|definition|corresponds|none|all|above|both|neither|either|true|false|always|never|only|first|second|third|fourth|gas|liquid|solid|precipitate|solution|temperature|pressure|volume|mass|weight|moles|atoms|molecules|electrons|protons|neutrons|catalyst|equilibrium)\b',
    caseSensitive: false,
  );

  static const Set<String> _validElements = {
    'H', 'He', 'Li', 'Be', 'B', 'C', 'N', 'O', 'F', 'Ne',
    'Na', 'Mg', 'Al', 'Si', 'P', 'S', 'Cl', 'Ar', 'K', 'Ca',
    'Sc', 'Ti', 'V', 'Cr', 'Mn', 'Fe', 'Co', 'Ni', 'Cu', 'Zn',
    'Ga', 'Ge', 'As', 'Se', 'Br', 'Kr', 'Rb', 'Sr', 'Y', 'Zr',
    'Nb', 'Mo', 'Tc', 'Ru', 'Rh', 'Pd', 'Ag', 'Cd', 'In', 'Sn',
    'Sb', 'Te', 'I', 'Xe', 'Cs', 'Ba', 'La', 'Ce', 'Pt', 'Au',
    'Hg', 'Pb', 'Bi', 'Ra', 'U',
  };

  static bool _hasChemicalElement(String text) {
    for (final m in RegExp('[A-Z][a-z]?').allMatches(text)) {
      if (_validElements.contains(m.group(0))) {
        return true;
      }
    }
    return false;
  }

  static final RegExp _chemicalSubscriptSpacedRegex = RegExp(
    r'([A-Za-z\)\]])\s+(\d+)\b',
  );

  static final RegExp _reactionArrowRegex = RegExp(
    r'\s*(?:-->|->|→)\s*',
  );

  static final RegExp _equilibriumArrowRegex = RegExp(
    r'\s*(?:<->|<=>|⇌)\s*',
  );

  static final RegExp _stateSymbolRegex = RegExp(
    r'\((aq|s|l|g)\)',
    caseSensitive: false,
  );

  static final RegExp _mathExponentRegex = RegExp(
    r'(?<![a-zA-Z0-9_\\])([a-zA-Z0-9\(\)]+)\^([a-zA-Z0-9\+\-]+|\{[^}]+\})',
  );

  static final RegExp _fractionRegex = RegExp(
    r'^\s*([-+]?[a-zA-Z0-9\(\)]+)\s*\/\s*([a-zA-Z0-9\(\)]+)\s*$',
  );

  static final RegExp _scientificNotationRegex = RegExp(
    r'([-+]?\d+(?:\.\d+)?)\s*[xX\*]\s*10\^([-+]?\d+)',
  );

  /// Formats a complete multi-line text block, making options, equations,
  /// and chemical formulas LaTeX-ready while preserving existing markdown and text.
  static String formatFormulaAware(String input) {
    if (input.trim().isEmpty) return input;

    final lines = input.split('\n');
    final processedLines = <String>[];

    for (final line in lines) {
      processedLines.add(_formatLine(line));
    }

    return processedLines.join('\n');
  }

  static String _formatLine(String line) {
    if (line.trim().isEmpty) return line;

    // Separate option/bullet prefix (e.g. "• A. " or "A. ") from the core content
    var prefix = '';
    var body = line;
    final prefixMatch = _optionPrefixRegex.firstMatch(line);
    if (prefixMatch != null) {
      prefix = prefixMatch.group(1)!;
      body = line.substring(prefix.length);
    }

    // If body already contains math delimiters, normalize spaced chemical subscripts inside it
    if (_mathDelimiterRegex.hasMatch(body)) {
      return prefix + _normalizeSpacedSubscriptsInDelimitedMath(body);
    }

    // 1. Raw LaTeX command without delimiters (e.g. "\frac{1}{2}" or "\sqrt{16}")
    if (_rawLatexCmdRegex.hasMatch(body)) {
      final formatted = _wrapRawLatex(body);
      return prefix + formatted;
    }

    // 2. Scientific notation (e.g. "3 x 10^8" -> "$3 \times 10^{8}$")
    if (_scientificNotationRegex.hasMatch(body.trim()) && !_commonEnglishWordsRegex.hasMatch(body)) {
      final formatted = body.trim().replaceAllMapped(
        _scientificNotationRegex,
        (m) => '\$${m.group(1)} \\times 10^{${m.group(2)}}\$',
      );
      return prefix + formatted;
    }

    // 3. Pure fraction (e.g. "3/4" or "-1/2" or "x/2")
    final fracMatch = _fractionRegex.firstMatch(body.trim());
    if (fracMatch != null && !_commonEnglishWordsRegex.hasMatch(body)) {
      final num = fracMatch.group(1);
      final den = fracMatch.group(2);
      return '$prefix\$\\frac{$num}{$den}\$';
    }

    // 4. Chemical reaction / formula (e.g. "Cu(NO 3 ) 3 + NO + N 2 O 4 + H 2 O", "H2O", "Ca(OH)2")
    if (_isChemicalFormulaOrEquation(body)) {
      final chemLatex = _formatChemicalToLatex(body);
      return '$prefix\$\\mathrm{$chemLatex}\$';
    }

    // 5. Mathematical equation with exponents or algebra without English sentences (e.g. "2^x = 32" or "x^2 - 4 = 0")
    if (_isMathExpression(body)) {
      final mathLatex = _formatMathToLatex(body);
      return '$prefix\$$mathLatex\$';
    }

    return line;
  }

  /// Normalizes spaced chemical subscripts in already-delimited math (e.g. `\mathrm{Cu(NO 3 ) 2}`)
  static String _normalizeSpacedSubscriptsInDelimitedMath(String text) {
    return text.replaceAllMapped(_chemicalSubscriptSpacedRegex, (m) => '${m.group(1)}_${m.group(2)}');
  }

  /// Determines if the text represents a chemical equation or compound formula
  static bool _isChemicalFormulaOrEquation(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return false;

    // Disqualify if it has standard natural language sentences
    if (_commonEnglishWordsRegex.hasMatch(trimmed)) {
      return false;
    }

    // Look for spaced subscript pattern (e.g. "NO 3", "H 2", ") 2")
    final hasSpacedSubscript = _chemicalSubscriptSpacedRegex.hasMatch(trimmed);

    // Look for standard chemical formula pattern (e.g. "Cu(NO_3)_2", "H2O", "Fe2O3", "NaOH")
    final hasElementToken = _hasChemicalElement(trimmed);

    // Look for chemical reactions (e.g. "A + B -> C + D" or contains state symbols "(aq)", "(s)")
    final hasReactionSigns = _reactionArrowRegex.hasMatch(trimmed) ||
        _equilibriumArrowRegex.hasMatch(trimmed) ||
        _stateSymbolRegex.hasMatch(trimmed) ||
        (hasElementToken && trimmed.contains('+'));

    if ((hasSpacedSubscript && hasElementToken) || hasReactionSigns) {
      return true;
    }

    // Check single chemical compounds without spaces (e.g. "H2O", "CO2", "Ca(OH)2", "NaCl", "KMnO4", "Fe2O3")
    final isCompoundPattern = RegExp(
      r'^(?:[A-Z][a-z]?\d*|\((?:[A-Z][a-z]?\d*)+\)\d*|\[(?:[A-Z][a-z]?\d*)+\]\d*)+$',
    ).hasMatch(trimmed);

    if (isCompoundPattern && hasElementToken) {
      // Avoid false positive on single short words if they don't have digits or uppercase transitions
      final hasDigit = RegExp(r'\d').hasMatch(trimmed);
      final hasParens = trimmed.contains('(') || trimmed.contains('[');
      final hasMultipleElements = RegExp('[A-Z].*[A-Z]').hasMatch(trimmed);

      if (hasDigit || hasParens || hasMultipleElements) {
        return true;
      }
    }

    return false;
  }

  /// Converts a chemical formula/equation string into LaTeX math notation
  static String _formatChemicalToLatex(String raw) {
    var s = raw.trim();

    // 1. Clean spaces inside parentheses: "(NO 3 )" -> "(NO 3)"
    s = s.replaceAll(RegExp(r'\(\s+'), '(');
    s = s.replaceAll(RegExp(r'\s+\)'), ')');

    // 2. Convert spaced subscripts: "NO 3" -> "NO_3", ") 2" -> ")_2"
    s = s.replaceAllMapped(_chemicalSubscriptSpacedRegex, (m) => '${m.group(1)}_${m.group(2)}');

    // 3. Convert unspaced subscripts for standard formula notation: "H2O" -> "H_2O"
    s = s.replaceAllMapped(
      RegExp(r'([A-Z][a-z]?|\))\s*(\d+)'),
      (m) => '${m.group(1)}_${m.group(2)}',
    );

    // 4. Remove space between subscript and next element letter: "H_2 O" -> "H_2O", "N_2 O_4" -> "N_2O_4"
    s = s.replaceAllMapped(RegExp(r'_(\d+)\s+([A-Z]|\))'), (m) => '_${m.group(1)}${m.group(2)}');

    // 5. Convert hydrate dots: "CuSO4 . 5H2O" or "CuSO4*5H2O" -> "CuSO_4 \cdot 5H_2O"
    s = s.replaceAll(RegExp(r'\s*[\.\*]\s*(?=\d*[A-Z])'), r' \cdot ');

    // 6. Convert reaction arrows
    s = s.replaceAll(_reactionArrowRegex, r' \rightarrow ');
    s = s.replaceAll(_equilibriumArrowRegex, r' \rightleftharpoons ');

    // 7. Convert state symbols
    s = s.replaceAllMapped(_stateSymbolRegex, (m) => '\\text{(${m.group(1)})}');

    return s.trim();
  }

  /// Determines if the text is a standalone mathematical expression
  static bool _isMathExpression(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return false;

    // Disqualify if contains natural English words
    if (_commonEnglishWordsRegex.hasMatch(trimmed)) {
      return false;
    }

    // Contains power notation like "2^x = 32" or "x^2 + y^2 = 25"
    if (_mathExponentRegex.hasMatch(trimmed)) {
      return true;
    }

    // Contains degree symbol: "45°"
    if (trimmed.contains('°')) {
      return true;
    }

    // Contains plus-minus: "+/- 4"
    if (trimmed.contains('+/-')) {
      return true;
    }

    // Contains basic algebra equation like "x + y = 10" or "dy/dx = 4"
    if (RegExp(r'^[a-zA-Z0-9\s\+\-\*\/\(\)\=]+$').hasMatch(trimmed) &&
        trimmed.contains('=') &&
        RegExp('[a-zA-Z]').hasMatch(trimmed)) {
      return true;
    }

    return false;
  }

  /// Formats algebraic math expressions into clean LaTeX
  static String _formatMathToLatex(String raw) {
    var s = raw.trim();
    // Convert * into \times if between numbers/variables
    s = s.replaceAllMapped(RegExp(r'(\d)\s*\*\s*(\d)'), (m) => '${m.group(1)} \\times ${m.group(2)}');
    // Convert +/- into \pm
    s = s.replaceAll('+/-', r'\pm ');
    // Convert degrees 45° -> 45^\circ
    s = s.replaceAllMapped(RegExp(r'(\d+)\s*°'), (m) => '${m.group(1)}^\\circ');
    return s;
  }

  /// Wraps raw LaTeX command text in `$...$`
  static String _wrapRawLatex(String body) {
    final trimmed = body.trim();
    if (!trimmed.startsWith(r'$') && !trimmed.endsWith(r'$')) {
      return '\$$trimmed\$';
    }
    return body;
  }
}
