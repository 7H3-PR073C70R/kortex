/// Educational and academic abbreviations and acronym expansions for conversational TTS.
class SpeechAbbreviations {
  const SpeechAbbreviations._();

  static const Map<String, String> acronymExpansions = {
    'WAEC': 'Way-eck',
    'WASSCE': 'Was-see',
    'JAMB': 'Jamb',
    'NECO': 'Neco',
    'NABTEB': 'Nabteb',
    'BECE': 'Beh-seh',
    'JUPEB': 'Joo-peb',
    'ASUU': 'Ah-soo',
    'UTME': 'U-T-M-E',
    'POST-UTME': 'Post U-T-M-E',
    'Post-UTME': 'Post U-T-M-E',
    'CBT': 'C-B-T',
    'GPA': 'G-P-A',
    'CGPA': 'C-G-P-A',
    'SSCE': 'S-S-C-E',
    'GCE': 'G-C-E',
    'IJMB': 'I-J-M-B',
    'NUC': 'N-U-C',
    'NYSC': 'N-Y-S-C',
    'API': 'A-P-I',
    'AI': 'A-I',
    'UI': 'U-I',
    'UX': 'U-X',
    'PDF': 'P-D-F',
    'FAQ': 'F-A-Q',
  };

  static const Map<String, String> commonAbbreviations = {
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

  /// Expands abbreviations and acronyms in text into phonetic, conversational speech.
  static String expand(String input) {
    var text = input;

    // Expand Latin & common abbreviations
    for (final entry in commonAbbreviations.entries) {
      text = text.replaceAll(
        RegExp(entry.key, caseSensitive: false),
        entry.value,
      );
    }

    // Expand acronyms (whole word only)
    for (final entry in acronymExpansions.entries) {
      text = text.replaceAll(
        RegExp('\\b${entry.key}\\b', caseSensitive: false),
        entry.value,
      );
    }

    return text;
  }
}
