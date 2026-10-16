/// Centralized boundary-level HTML, XML, and numeric entity decoder.
///
/// Decodes:
/// 1. Hexadecimal numeric entities (`&#x27;` -> `'`, `&#x2019;` -> `’`, `&#xC9;` -> `É`)
/// 2. Decimal numeric entities (`&#39;` -> `'`, `&#160;` -> ` `, `&#8212;` -> `—`)
/// 3. Named HTML5 and XML entities (`&times;` -> `×`, `&amp;` -> `&`, `&lt;` -> `<`, etc.)
class HtmlEntityDecoder {
  const HtmlEntityDecoder._();

  static final RegExp _entityRegex = RegExp(
    '&(#[xX][0-9a-fA-F]+|#[0-9]+|[a-zA-Z0-9]+);',
  );

  /// Decodes all HTML/XML named and numeric character references in [input].
  ///
  /// Supports up to [maxPasses] (default 2) to resolve double-escaped entities
  /// common in XML packages (e.g. `&amp;times;` -> `&times;` -> `×` or
  /// `&amp;#x27;` -> `&#x27;` -> `'`).
  ///
  /// Returns [input] unchanged immediately if no `&` character is present.
  static String decode(String input, {int maxPasses = 2}) {
    if (!input.contains('&')) return input;

    var current = input;
    for (var pass = 0; pass < maxPasses; pass++) {
      if (!current.contains('&')) break;

      final next = current.replaceAllMapped(_entityRegex, (match) {
        final code = match.group(1)!;

        // 1. Hexadecimal numeric entity: &#x27; / &#X27; -> 39
        if (code.startsWith('#x') || code.startsWith('#X')) {
          final hexStr = code.substring(2);
          final codePoint = int.tryParse(hexStr, radix: 16);
          if (codePoint != null && _isValidUnicode(codePoint)) {
            if (codePoint == 0x00A0) return ' '; // Normalize non-breaking space
            return String.fromCharCode(codePoint);
          }
          return match.group(0)!;
        }

        // 2. Decimal numeric entity: &#39; -> 39, &#160; -> ' '
        if (code.startsWith('#')) {
          final decStr = code.substring(1);
          final codePoint = int.tryParse(decStr, radix: 10);
          if (codePoint != null && _isValidUnicode(codePoint)) {
            if (codePoint == 160) return ' '; // Normalize non-breaking space
            return String.fromCharCode(codePoint);
          }
          return match.group(0)!;
        }

        // 3. Named HTML5 / XML entity lookup
        final replacement = _namedEntities[code];
        if (replacement != null) {
          return replacement;
        }

        // Case-insensitive fallback for common names like &Times; or &AMP;
        final lowerReplacement = _namedEntities[code.toLowerCase()];
        if (lowerReplacement != null) {
          return lowerReplacement;
        }

        return match.group(0)!;
      });

      if (next == current) break;
      current = next;
    }

    return current;
  }

  static bool _isValidUnicode(int codePoint) {
    return (codePoint >= 0x0000 && codePoint <= 0xD7FF) ||
        (codePoint >= 0xE000 && codePoint <= 0x10FFFF);
  }

  static const Map<String, String> _namedEntities = {
    // XML essentials
    'amp': '&',
    'lt': '<',
    'gt': '>',
    'quot': '"',
    'apos': "'",

    // Whitespace and formatting
    'nbsp': ' ',
    'ensp': ' ',
    'emsp': ' ',
    'thinsp': ' ',
    'zwnj': '\u200C',
    'zwj': '\u200D',

    // Quotes and Dashes
    'lsquo': '‘',
    'rsquo': '’',
    'sbquo': '‚',
    'ldquo': '“',
    'rdquo': '”',
    'bdquo': '„',
    'laquo': '«',
    'raquo': '»',
    'ndash': '–',
    'mdash': '—',
    'minus': '−',
    'bull': '•',
    'hellip': '…',
    'prime': '′',
    'Prime': '″',

    // Mathematical symbols
    'times': '×',
    'divide': '÷',
    'plusmn': '±',
    'middot': '·',
    'radic': '√',
    'infin': '∞',
    'ne': '≠',
    'le': '≤',
    'ge': '≥',
    'approx': '≈',
    'asymp': '≈',
    'equiv': '≡',
    'sum': '∑',
    'prod': '∏',
    'int': '∫',
    'part': '∂',
    'partial': '∂',
    'nabla': '∇',
    'isin': '∈',
    'notin': '∉',
    'ni': '∋',
    'empty': '∅',
    'exist': '∃',
    'forall': '∀',
    'sub': '⊂',
    'sup': '⊃',
    'sube': '⊆',
    'supe': '⊇',
    'cup': '∪',
    'cap': '∩',
    'oplus': '⊕',
    'otimes': '⊗',
    'perp': '⊥',
    'prop': '∝',
    'ang': '∠',
    'sim': '~',
    'lang': '⟨',
    'rang': '⟩',

    // Arrows
    'larr': '←',
    'rarr': '→',
    'uarr': '↑',
    'darr': '↓',
    'harr': '↔',
    'crarr': '↵',
    'lArr': '⇐',
    'rArr': '⇒',
    'uArr': '⇑',
    'dArr': '⇓',
    'hArr': '⇔',

    // Currency and Common
    'cent': '¢',
    'pound': '£',
    'curren': '¤',
    'yen': '¥',
    'euro': '€',
    'copy': '©',
    'reg': '®',
    'trade': '™',
    'deg': '°',
    'micro': 'µ',
    'para': '¶',
    'sect': '§',

    // Greek letters (lowercase)
    'alpha': 'α',
    'beta': 'β',
    'gamma': 'γ',
    'delta': 'δ',
    'epsilon': 'ε',
    'zeta': 'ζ',
    'eta': 'η',
    'theta': 'θ',
    'iota': 'ι',
    'kappa': 'κ',
    'lambda': 'λ',
    'mu': 'μ',
    'nu': 'ν',
    'xi': 'ξ',
    'omicron': 'ο',
    'pi': 'π',
    'rho': 'ρ',
    'sigma': 'σ',
    'sigmaf': 'ς',
    'tau': 'τ',
    'upsilon': 'υ',
    'phi': 'φ',
    'chi': 'χ',
    'psi': 'ψ',
    'omega': 'ω',

    // Greek letters (uppercase)
    'Alpha': 'Α',
    'Beta': 'Β',
    'Gamma': 'Γ',
    'Delta': 'Δ',
    'Epsilon': 'Ε',
    'Zeta': 'Ζ',
    'Eta': 'Η',
    'Theta': 'Θ',
    'Iota': 'Ι',
    'Kappa': 'Κ',
    'Lambda': 'Λ',
    'Xi': 'Ξ',
    'Omicron': 'Ο',
    'Pi': 'Π',
    'Rho': 'Ρ',
    'Sigma': 'Σ',
    'Tau': 'Τ',
    'Upsilon': 'Υ',
    'Phi': 'Φ',
    'Chi': 'Χ',
    'Psi': 'Ψ',
    'Omega': 'Ω',

    // Latin extended / Accented characters
    'Agrave': 'À', 'Aacute': 'Á', 'Acirc': 'Â', 'Atilde': 'Ã', 'Auml': 'Ä', 'Aring': 'Å', 'AElig': 'Æ',
    'agrave': 'à', 'aacute': 'á', 'acirc': 'â', 'atilde': 'ã', 'auml': 'ä', 'aring': 'å', 'aelig': 'æ',
    'Ccedil': 'Ç', 'ccedil': 'ç',
    'Egrave': 'È', 'Eacute': 'É', 'Ecirc': 'Ê', 'Euml': 'Ë',
    'egrave': 'è', 'eacute': 'é', 'ecirc': 'ê', 'euml': 'ë',
    'Igrave': 'Ì', 'Iacute': 'Í', 'Icirc': 'Î', 'Iuml': 'Ï',
    'igrave': 'ì', 'iacute': 'í', 'icirc': 'î', 'iuml': 'ï',
    'Ntilde': 'Ñ', 'ntilde': 'ñ',
    'Ograve': 'Ò', 'Oacute': 'Ó', 'Ocirc': 'Ô', 'Otilde': 'Õ', 'Ouml': 'Ö', 'Oslash': 'Ø',
    'ograve': 'ò', 'oacute': 'ó', 'ocirc': 'ô', 'otilde': 'õ', 'ouml': 'ö', 'oslash': 'ø',
    'Ugrave': 'Ù', 'Uacute': 'Ú', 'Ucirc': 'Û', 'Uuml': 'Ü',
    'ugrave': 'ù', 'uacute': 'ú', 'ucirc': 'û', 'uuml': 'ü',
    'Yacute': 'Ý', 'yacute': 'ý', 'yuml': 'ÿ',
    'THORN': 'Þ', 'thorn': 'þ', 'ETH': 'Ð', 'eth': 'ð', 'szlig': 'ß',
  };
}
