/// Formats LaTeX mathematical formulas and mathematical expressions for natural spoken speech.
class SpeechMathFormatter {
  const SpeechMathFormatter._();

  /// Converts an integer into its conversational spoken word representation (e.g. 19 -> nineteen).
  static String numberToSpoken(int n) {
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

  /// Expands LaTeX syntax to natural spoken phrases.
  ///
  /// Handles both dollar-sign-delimited math blocks and bare LaTeX commands
  /// that appear outside delimiters (common in flashcard content).
  static String normalizeLatex(String input) {
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
}
