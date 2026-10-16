/// Formats programming code snippets and inline code expressions for human-audible speech.
class SpeechCodeFormatter {
  const SpeechCodeFormatter._();

  /// Converts a fenced code block into speech-friendly conversational English.
  static String normalizeCodeBlock(String rawCodeBlock) {
    final match = RegExp(
      r'```(?:([a-zA-Z0-9_\-+]*)\r?\n)?([\s\S]*?)```',
    ).firstMatch(rawCodeBlock);

    if (match == null) {
      return ', here is the code snippet: , ';
    }

    final rawLang = match.group(1)?.trim() ?? '';
    final code = match.group(2)?.trim() ?? '';

    if (code.isEmpty) {
      return ', here is the code snippet: , ';
    }

    final langName = switch (rawLang.toLowerCase()) {
      'dart' => 'Dart',
      'flutter' => 'Flutter',
      'py' || 'python' => 'Python',
      'js' || 'javascript' => 'JavaScript',
      'ts' || 'typescript' => 'TypeScript',
      'html' => 'HTML',
      'css' => 'CSS',
      'sql' => 'SQL',
      'java' => 'Java',
      'c' => 'C',
      'cpp' || 'c++' => 'C plus plus',
      'cs' || 'c#' => 'C sharp',
      'rb' || 'ruby' => 'Ruby',
      'go' || 'golang' => 'Go',
      'rust' => 'Rust',
      'swift' => 'Swift',
      'kt' || 'kotlin' => 'Kotlin',
      'sh' || 'bash' => 'bash',
      'json' => 'JSON',
      _ => rawLang.isNotEmpty ? rawLang : '',
    };

    final intro = langName.isNotEmpty
        ? ', here is the code snippet in $langName: '
        : ', here is the code snippet: ';

    final lines = code
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    // If concise snippet (<= 4 lines or <= 180 chars), pronounce the code lines
    if (lines.length <= 4 && code.length <= 180) {
      final spokenLines = lines.map(convertCodeLineToSpeech).join(', ');
      return '$intro$spokenLines, ';
    }

    // For longer snippets, announce the language and read the opening 2 lines then summarize
    final preview = lines.take(2).map(convertCodeLineToSpeech).join(', ');
    return '$intro$preview, continuing the implementation, ';
  }

  /// Converts code syntax and symbols in a line to human-audible speech.
  static String convertCodeLineToSpeech(String line) {
    var s = line;

    // Expand common programming operators and symbols
    s = s.replaceAll('=>', ' returns ');
    s = s.replaceAll('===', ' strictly equals ');
    s = s.replaceAll('!==', ' strictly does not equal ');
    s = s.replaceAll('==', ' equals ');
    s = s.replaceAll('!=', ' does not equal ');
    s = s.replaceAll('<=', ' is less than or equal to ');
    s = s.replaceAll('>=', ' is greater than or equal to ');
    s = s.replaceAll('&&', ' and ');
    s = s.replaceAll('||', ' or ');
    s = s.replaceAll('++', ' plus plus ');
    s = s.replaceAll('--', ' minus minus ');
    s = s.replaceAll('+=', ' plus equals ');
    s = s.replaceAll('-=', ' minus equals ');
    s = s.replaceAll('*=', ' times equals ');
    s = s.replaceAll('/=', ' divided by equals ');
    s = s.replaceAll('->', ' points to ');
    s = s.replaceAll('::', ' double colon ');

    // Normalize brackets and delimiters to natural commas/pauses
    s = s.replaceAll(RegExp('[{};]+'), ', ');
    s = s.replaceAll(RegExp(r'\(\s*\)'), '');
    s = s.replaceAll(RegExp(r'\[\s*\]'), '');

    // Split identifiers like camelCase or PascalCase so TTS pronounces distinct words
    s = s.replaceAllMapped(
      RegExp('([a-z])([A-Z])'),
      (m) => '${m[1]} ${m[2]}',
    );
    // Replace underscores with spaces in snake_case
    s = s.replaceAll('_', ' ');

    // Strip remaining punctuation noise
    s = s.replaceAll(RegExp(r'[<>()\[\]"\x27]'), ' ');
    s = s.replaceAll(RegExp(r'\s{2,}'), ' ').trim();

    return s;
  }
}
