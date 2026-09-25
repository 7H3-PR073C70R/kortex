/// Converts spoken natural-language mathematical phrases into KaTeX LaTeX math syntax.
class SpokenMathToKaTeXConverter {
  const SpokenMathToKaTeXConverter._();

  /// Converts spoken math phrases (e.g. "x squared plus y squared equals z squared") into KaTeX syntax.
  static String convertSpokenMathToKaTeX(String spoken) {
    if (spoken.trim().isEmpty) return spoken;

    var result = spoken;

    // Direct math expressions & formula patterns
    final replacementRules = <_ReplacementRule>[
      // Power / Squares / Cubes
      _ReplacementRule(
        RegExp(r'\b([a-zA-Z0-9]+)\s+squared\b', caseSensitive: false),
        r'$\1^2$',
      ),
      _ReplacementRule(
        RegExp(r'\b([a-zA-Z0-9]+)\s+cubed\b', caseSensitive: false),
        r'$\1^3$',
      ),
      _ReplacementRule(
        RegExp(r'\b([a-zA-Z0-9]+)\s+(?:to the power of|power)\s+([a-zA-Z0-9]+)\b', caseSensitive: false),
        r'$\1^{\2}$',
      ),

      // Roots
      _ReplacementRule(
        RegExp(r'\bsquare root of\s+([a-zA-Z0-9]+)\b', caseSensitive: false),
        r'$\sqrt{\1}$',
      ),
      _ReplacementRule(
        RegExp(r'\bcube root of\s+([a-zA-Z0-9]+)\b', caseSensitive: false),
        r'$\sqrt[3]{\1}$',
      ),

      // Calculus & Integrals
      _ReplacementRule(
        RegExp(r'\bintegral of\s+([^\s]+)\s+d([a-zA-Z])\b', caseSensitive: false),
        r'$\int \1 \, d\2$',
      ),
      _ReplacementRule(
        RegExp(r'\bderivative of\s+([^\s]+)\b', caseSensitive: false),
        r'$\frac{d}{dx}(\1)$',
      ),

      // Fractions
      _ReplacementRule(
        RegExp(r'\b([a-zA-Z0-9]+)\s+over\s+([a-zA-Z0-9]+)\b', caseSensitive: false),
        r'$\frac{\1}{\2}$',
      ),
      _ReplacementRule(
        RegExp(r'\b([a-zA-Z0-9]+)\s+divided by\s+([a-zA-Z0-9]+)\b', caseSensitive: false),
        r'$\frac{\1}{\2}$',
      ),

      // Greek letters & symbols
      _ReplacementRule(
        RegExp(r'\balpha\b', caseSensitive: false),
        r'$\alpha$',
      ),
      _ReplacementRule(
        RegExp(r'\bbeta\b', caseSensitive: false),
        r'$\beta$',
      ),
      _ReplacementRule(
        RegExp(r'\btheta\b', caseSensitive: false),
        r'$\theta$',
      ),
      _ReplacementRule(
        RegExp(r'\bpi\b', caseSensitive: false),
        r'$\pi$',
      ),
      _ReplacementRule(
        RegExp(r'\binfinity\b', caseSensitive: false),
        r'$\infty$',
      ),
      _ReplacementRule(
        RegExp(r'\bplus or minus\b', caseSensitive: false),
        r'$\pm$',
      ),

      // Equalities / Comparison
      _ReplacementRule(
        RegExp(r'\bplus\b', caseSensitive: false),
        '+',
      ),
      _ReplacementRule(
        RegExp(r'\bminus\b', caseSensitive: false),
        '-',
      ),
      _ReplacementRule(
        RegExp(r'\btimes\b', caseSensitive: false),
        r'\times',
      ),
      _ReplacementRule(
        RegExp(r'\bequals\b', caseSensitive: false),
        '=',
      ),
      _ReplacementRule(
        RegExp(r'\bis equal to\b', caseSensitive: false),
        '=',
      ),
      _ReplacementRule(
        RegExp(r'\bgreater than or equal to\b', caseSensitive: false),
        r'\ge',
      ),
      _ReplacementRule(
        RegExp(r'\bless than or equal to\b', caseSensitive: false),
        r'\le',
      ),
    ];

    for (final rule in replacementRules) {
      result = result.replaceAllMapped(rule.pattern, (match) {
        var rep = rule.template;
        for (var i = 1; i <= match.groupCount; i++) {
          final groupVal = match.group(i) ?? '';
          rep = rep.replaceAll(RegExp('\\\\$i'), groupVal);
        }
        return rep;
      });
    }

    return result.replaceAll(RegExp(r'\${2,}'), r'$');
  }
}

class _ReplacementRule {
  const _ReplacementRule(this.pattern, this.template);
  final RegExp pattern;
  final String template;
}
