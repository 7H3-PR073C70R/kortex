import 'dart:collection';

/// Represents the type of artifact isolated from document text.
enum ArtifactType {
  code,
  mathInline,
  mathBlock,
  image,
}

/// An isolated syntactic artifact preserved verbatim.
class ExtractedArtifact {
  const ExtractedArtifact({
    required this.id,
    required this.placeholder,
    required this.type,
    required this.rawContent,
    this.language,
    this.altText,
    this.sourceUrl,
  });

  final String id;
  final String placeholder;
  final ArtifactType type;
  final String rawContent;
  final String? language;
  final String? altText;
  final String? sourceUrl;
}

/// Registry storing extracted code, math, and media artifacts.
class ArtifactRegistry {
  ArtifactRegistry() : _artifacts = {};

  final Map<String, ExtractedArtifact> _artifacts;

  UnmodifiableMapView<String, ExtractedArtifact> get artifacts =>
      UnmodifiableMapView(_artifacts);

  void register(ExtractedArtifact artifact) {
    _artifacts[artifact.placeholder] = artifact;
  }

  ExtractedArtifact? get(String placeholder) => _artifacts[placeholder];

  bool contains(String placeholder) => _artifacts.containsKey(placeholder);

  /// Restores all placeholders in [text] with their verbatim raw content.
  String restore(String text) {
    if (_artifacts.isEmpty) return text;
    var restored = text;
    for (final entry in _artifacts.entries) {
      restored = restored.replaceAll(entry.key, entry.value.rawContent);
    }
    return restored;
  }
}

/// Base class for nodes in the Document AST.
sealed class DocumentAstNode {
  const DocumentAstNode({required this.rawText});
  final String rawText;
}

/// A section heading node.
class HeadingNode extends DocumentAstNode {
  const HeadingNode({
    required super.rawText,
    required this.title,
    required this.level,
  });

  final String title;
  final int level;
}

/// A paragraph of continuous prose text.
class ParagraphNode extends DocumentAstNode {
  const ParagraphNode({
    required super.rawText,
    required this.sentences,
    this.headingContext,
  });

  final List<String> sentences;
  final String? headingContext;
}

/// A bullet or numbered list item.
class ListItemNode extends DocumentAstNode {
  const ListItemNode({
    required super.rawText,
    required this.bulletPrefix,
    required this.content,
    this.headingContext,
  });

  final String bulletPrefix;
  final String content;
  final String? headingContext;
}

/// A key-value glossary or definition node.
class DefinitionNode extends DocumentAstNode {
  const DefinitionNode({
    required super.rawText,
    required this.term,
    required this.definition,
    this.headingContext,
  });

  final String term;
  final String definition;
  final String? headingContext;
}

/// A formal grammar / EBNF production node (e.g. from Java Language Spec).
class GrammarProductionNode extends DocumentAstNode {
  const GrammarProductionNode({
    required super.rawText,
    required this.nonTerminal,
    required this.productionRule,
    this.specificationContext,
  });

  final String nonTerminal;
  final String productionRule;
  final String? specificationContext;
}

/// A verbatim code block node.
class CodeBlockNode extends DocumentAstNode {
  const CodeBlockNode({
    required super.rawText,
    required this.code,
    required this.language,
    required this.placeholder,
  });

  final String code;
  final String language;
  final String placeholder;
}

/// A LaTeX mathematics block node.
class MathBlockNode extends DocumentAstNode {
  const MathBlockNode({
    required super.rawText,
    required this.latex,
    required this.isBlock,
    required this.placeholder,
  });

  final String latex;
  final bool isBlock;
  final String placeholder;
}

/// Structured document representation containing typed nodes and isolated artifacts.
class DocumentAst {
  const DocumentAst({
    required this.nodes,
    required this.registry,
    required this.documentContext,
  });

  final List<DocumentAstNode> nodes;
  final ArtifactRegistry registry;
  final String documentContext;
}

/// Layer 1: Document & Artifact Isolator.
///
/// Extracts and masks code blocks, equations, and images, and performs
/// greedy line-wrap normalization on prose to eliminate truncation caused
/// by column breaks.
class DocumentAstExtractor {
  const DocumentAstExtractor();

  static final _codeFenceRegex = RegExp(
    r'(?:```|~~~)([a-zA-Z0-9_\-\+]*)\n([\s\S]*?)(?:```|~~~)',
    multiLine: true,
  );

  static final _mathBlockRegex = RegExp(
    r'(\$\$(?:[\s\S]*?)\$\$|\\begin\{equation\}(?:[\s\S]*?)\\end\{equation\}|\\begin\{align\}(?:[\s\S]*?)\\end\{align\})',
    multiLine: true,
  );

  static final _mathInlineRegex = RegExp(
    r'(?<!\$|\w)\$(?!\$)((?:\\.|[^$\\\n])+?)\$(?!\$|\w)',
  );

  static final _imageMarkdownRegex = RegExp(
    r'!\[(.*?)\]\((.*?)\)',
  );

  static final _danglingLineEndRegex = RegExp(
    r'(?:,|;|:|-|\b(?:and|or|to|of|in|for|with|that|which|by|as|you|the|a|an|is|are|be|into|from|relying|using|via|such|their|its))\s*$',
    caseSensitive: false,
  );

  static final _bulletItemRegex = RegExp(
    r'^\s*([*•\-–+]|\d+[\.\)])\s+(.*)',
  );

  static final _headingRegex = RegExp(
    r'^(#{1,6})\s+(.*)',
  );

  static final _ebnfMetaCharsRegex = RegExp(
    r'[\[\]\{\}\|;::=]',
  );

  /// Isolates artifacts and parses raw document text into a [DocumentAst].
  DocumentAst extract(String rawText, {String? filename}) {
    final registry = ArtifactRegistry();
    var artifactCounter = 0;

    // 1. Isolate Fenced Code Blocks first
    var sanitized = rawText.replaceAllMapped(_codeFenceRegex, (match) {
      final lang = match.group(1)?.trim() ?? '';
      final code = match.group(2) ?? '';
      final placeholder = '__CODE_REF_${artifactCounter++}__';
      registry.register(
        ExtractedArtifact(
          id: placeholder,
          placeholder: placeholder,
          type: ArtifactType.code,
          rawContent: match.group(0)!,
          language: lang.isNotEmpty ? lang : _inferLanguage(code, filename),
        ),
      );
      return '\n\n$placeholder\n\n';
    });

    // 2. Isolate Display / Block Math
    sanitized = sanitized.replaceAllMapped(_mathBlockRegex, (match) {
      final placeholder = '__MATH_REF_${artifactCounter++}__';
      registry.register(
        ExtractedArtifact(
          id: placeholder,
          placeholder: placeholder,
          type: ArtifactType.mathBlock,
          rawContent: match.group(0)!,
        ),
      );
      return '\n\n$placeholder\n\n';
    });

    // 3. Isolate Inline Math ($ ... $)
    sanitized = sanitized.replaceAllMapped(_mathInlineRegex, (match) {
      final placeholder = '__MATH_REF_${artifactCounter++}__';
      registry.register(
        ExtractedArtifact(
          id: placeholder,
          placeholder: placeholder,
          type: ArtifactType.mathInline,
          rawContent: match.group(0)!,
        ),
      );
      return placeholder;
    });

    // 4. Isolate Images
    sanitized = sanitized.replaceAllMapped(_imageMarkdownRegex, (match) {
      final alt = match.group(1);
      final url = match.group(2);
      final placeholder = '__IMG_REF_${artifactCounter++}__';
      registry.register(
        ExtractedArtifact(
          id: placeholder,
          placeholder: placeholder,
          type: ArtifactType.image,
          rawContent: match.group(0)!,
          altText: alt,
          sourceUrl: url,
        ),
      );
      return placeholder;
    });

    // 5. Line Unwrapping & AST Parsing
    final docContext = _extractDocumentContext(sanitized, filename);
    final nodes = _parseNodes(sanitized, registry, docContext);

    return DocumentAst(
      nodes: nodes,
      registry: registry,
      documentContext: docContext,
    );
  }

  /// Parses text into structured AST nodes with greedy line unwrapping.
  List<DocumentAstNode> _parseNodes(
    String text,
    ArtifactRegistry registry,
    String defaultContext,
  ) {
    final rawLines = text.split('\n');
    final nodes = <DocumentAstNode>[];
    String? currentHeading;

    final accumulatedProse = <String>[];

    void flushProse() {
      if (accumulatedProse.isEmpty) return;
      final unwrapped = _greedyUnwrapLines(accumulatedProse);
      accumulatedProse.clear();

      if (unwrapped.trim().isEmpty) return;

      // Check if this block is an isolated artifact placeholder
      final trimmed = unwrapped.trim();
      final art = registry.get(trimmed);
      if (art != null) {
        if (art.type == ArtifactType.code) {
          nodes.add(
            CodeBlockNode(
              rawText: art.rawContent,
              code: art.rawContent,
              language: art.language ?? 'text',
              placeholder: art.placeholder,
            ),
          );
          return;
        } else if (art.type == ArtifactType.mathBlock ||
            art.type == ArtifactType.mathInline) {
          nodes.add(
            MathBlockNode(
              rawText: art.rawContent,
              latex: art.rawContent,
              isBlock: art.type == ArtifactType.mathBlock,
              placeholder: art.placeholder,
            ),
          );
          return;
        }
      }

      // Check for Definition / Glossary pattern (Term: Description or **Term** - Description)
      final definitionNode = _tryParseDefinition(unwrapped, currentHeading);
      if (definitionNode != null) {
        nodes.add(definitionNode);
        return;
      }

      // Standard prose paragraph
      final sentences = _splitSentences(unwrapped);
      if (sentences.isNotEmpty) {
        nodes.add(
          ParagraphNode(
            rawText: unwrapped,
            sentences: sentences,
            headingContext: currentHeading,
          ),
        );
      }
    }

    var i = 0;
    while (i < rawLines.length) {
      final line = rawLines[i];
      final trimmed = line.trim();

      // Isolated Artifact Placeholder check (Code, Math, Image)
      if (trimmed.startsWith('__CODE_REF_') ||
          trimmed.startsWith('__MATH_REF_') ||
          trimmed.startsWith('__IMG_REF_')) {
        flushProse();
        final art = registry.get(trimmed);
        if (art != null) {
          if (art.type == ArtifactType.code) {
            nodes.add(
              CodeBlockNode(
                rawText: art.rawContent,
                code: art.rawContent,
                language: art.language ?? 'text',
                placeholder: art.placeholder,
              ),
            );
          } else if (art.type == ArtifactType.mathBlock ||
              art.type == ArtifactType.mathInline) {
            nodes.add(
              MathBlockNode(
                rawText: art.rawContent,
                latex: art.rawContent,
                isBlock: art.type == ArtifactType.mathBlock,
                placeholder: art.placeholder,
              ),
            );
          }
        }
        i++;
        continue;
      }

      if (trimmed.isEmpty) {
        // Look ahead: if preceding line had a dangling end, don't break paragraph
        if (accumulatedProse.isNotEmpty &&
            _danglingLineEndRegex.hasMatch(accumulatedProse.last.trim())) {
          // Bridging soft break only if next non-empty line is not heading, bullet, or artifact
          var hasNextContinuation = false;
          for (var k = i + 1; k < rawLines.length; k++) {
            final nextT = rawLines[k].trim();
            if (nextT.isEmpty) continue;
            if (!nextT.startsWith('#') &&
                !_bulletItemRegex.hasMatch(nextT) &&
                !nextT.startsWith('__')) {
              hasNextContinuation = true;
            }
            break;
          }
          if (hasNextContinuation) {
            i++;
            continue;
          }
        }
        flushProse();
        i++;
        continue;
      }

      // Markdown heading
      final headingMatch = _headingRegex.firstMatch(trimmed);
      if (headingMatch != null) {
        flushProse();
        final level = headingMatch.group(1)!.length;
        final title = headingMatch.group(2)!.trim();
        currentHeading = title;
        nodes.add(
          HeadingNode(
            rawText: trimmed,
            title: title,
            level: level,
          ),
        );
        i++;
        continue;
      }

      // EBNF Grammar Production detection (e.g. Identifier:\n   rule ;)
      if (trimmed.endsWith(':') &&
          i + 1 < rawLines.length &&
          rawLines[i + 1].startsWith(RegExp(r'^\s{2,}|\t'))) {
        final term = trimmed.substring(0, trimmed.length - 1).trim();
        if (RegExp(r'^[A-Z][A-Za-z0-9_]*$').hasMatch(term)) {
          // Accumulate indented production lines
          final prodLines = <String>[];
          var j = i + 1;
          while (j < rawLines.length &&
              (rawLines[j].startsWith(RegExp(r'^\s{2,}|\t')) ||
                  rawLines[j].trim().isEmpty)) {
            if (rawLines[j].trim().isNotEmpty) {
              prodLines.add(rawLines[j].trim());
            }
            j++;
          }
          final prodRule = prodLines.join(' ');
          if (_ebnfMetaCharsRegex.hasMatch(prodRule)) {
            flushProse();
            nodes.add(
              GrammarProductionNode(
                rawText: '$trimmed\n${prodLines.join('\n')}',
                nonTerminal: term,
                productionRule: prodRule,
                specificationContext: currentHeading ?? defaultContext,
              ),
            );
            i = j;
            continue;
          }
        }
      }

      // Bullet item
      final bulletMatch = _bulletItemRegex.firstMatch(line);
      if (bulletMatch != null) {
        flushProse();
        final prefix = bulletMatch.group(1)!;
        final contentLines = [bulletMatch.group(2)!.trim()];

        // Greedy absorption of wrapped continuation lines
        var j = i + 1;
        while (j < rawLines.length) {
          final nextLine = rawLines[j];
          final nextTrim = nextLine.trim();
          if (nextTrim.isEmpty) {
            if (_danglingLineEndRegex.hasMatch(contentLines.last)) {
              j++;
              continue;
            }
            break;
          }
          if (_bulletItemRegex.hasMatch(nextLine) ||
              _headingRegex.hasMatch(nextTrim)) {
            break;
          }
          // Indented or wrapped continuation
          contentLines.add(nextTrim);
          j++;
        }

        final combinedContent = _greedyUnwrapLines(contentLines);
        nodes.add(
          ListItemNode(
            rawText: '$prefix $combinedContent',
            bulletPrefix: prefix,
            content: combinedContent,
            headingContext: currentHeading,
          ),
        );
        i = j;
        continue;
      }

      // Normal prose line
      accumulatedProse.add(line);
      i++;
    }

    flushProse();
    return nodes;
  }

  /// Greedily unwraps lines that belong to the same visual flow,
  /// preserving hyphenations and terminal boundaries.
  String _greedyUnwrapLines(List<String> lines) {
    if (lines.isEmpty) return '';
    final buffer = StringBuffer();

    for (var i = 0; i < lines.length; i++) {
      final current = lines[i].trim();
      if (current.isEmpty) continue;

      if (buffer.isEmpty) {
        buffer.write(current);
        continue;
      }

      final prev = buffer.toString();
      // Handle line-end hyphenation (e.g. imple- \n mentation)
      if (prev.endsWith('-') && !prev.endsWith(' -')) {
        final withoutHyphen = prev.substring(0, prev.length - 1);
        buffer
          ..clear()
          ..write(withoutHyphen)
          ..write(current);
      } else {
        buffer
          ..write(' ')
          ..write(current);
      }
    }

    return buffer.toString().replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  }

  /// Splits paragraph text into discrete sentences respecting abbreviations.
  List<String> _splitSentences(String text) {
    if (text.trim().isEmpty) return [];

    final sentences = <String>[];
    final buffer = StringBuffer();
    final chars = text.runes.toList();

    for (var i = 0; i < chars.length; i++) {
      final c = String.fromCharCode(chars[i]);
      buffer.write(c);

      if (c == '.' || c == '!' || c == '?') {
        // Lookahead to check if this is an abbreviation or true terminal
        if (i + 1 < chars.length) {
          final next = String.fromCharCode(chars[i + 1]);
          // If followed immediately by non-whitespace, don't split (e.g. 3.14, example.com)
          if (next != ' ' && next != '\n' && next != '\t') {
            continue;
          }

          // Check common English abbreviations
          final currentStr = buffer.toString();
          if (RegExp(
            r'\b(?:e\.g|i\.e|etc|vs|dr|mr|mrs|prof|fig|vol|no|p|pp)\.$',
            caseSensitive: false,
          ).hasMatch(currentStr.trim())) {
            continue;
          }

          // Check if succeeding token starts with capital letter, quote, or placeholder
          final remainder = String.fromCharCodes(chars.sublist(i + 1)).trim();
          if (remainder.isNotEmpty &&
              !RegExp(r'^[A-Z"“‘_\d]').hasMatch(remainder)) {
            continue;
          }
        }

        final sentence = buffer.toString().trim();
        if (sentence.isNotEmpty) {
          sentences.add(sentence);
        }
        buffer.clear();
      }
    }

    final remaining = buffer.toString().trim();
    if (remaining.isNotEmpty) {
      sentences.add(remaining);
    }

    return sentences;
  }

  /// Tries to parse a definition or glossary item.
  DefinitionNode? _tryParseDefinition(String text, String? headingContext) {
    final colonMatch = RegExp(
      r'^([A-Z][A-Za-z0-9_\s\(\)\/\-]{1,50})\s*[:–—]\s*(.+)$',
    ).firstMatch(text);

    if (colonMatch != null) {
      final term = colonMatch.group(1)!.trim();
      final def = colonMatch.group(2)!.trim();
      if (!_ebnfMetaCharsRegex.hasMatch(def) && def.length >= 10) {
        return DefinitionNode(
          rawText: text,
          term: term,
          definition: def,
          headingContext: headingContext,
        );
      }
    }

    final boldMatch = RegExp(
      r'^\*\*([^\*]+)\*\*\s*[:–—\-]\s*(.+)$',
    ).firstMatch(text);

    if (boldMatch != null) {
      final term = boldMatch.group(1)!.trim();
      final def = boldMatch.group(2)!.trim();
      if (def.length >= 10) {
        return DefinitionNode(
          rawText: text,
          term: term,
          definition: def,
          headingContext: headingContext,
        );
      }
    }

    return null;
  }

  /// Infers programming language from snippet content or filename.
  String _inferLanguage(String code, String? filename) {
    if (filename != null) {
      final ext = filename.split('.').last.toLowerCase();
      if (ext == 'dart') return 'dart';
      if (ext == 'java') return 'java';
      if (ext == 'py') return 'python';
      if (ext == 'js') return 'javascript';
      if (ext == 'ts') return 'typescript';
    }
    if (code.contains('Widget build(') ||
        code.contains('StatelessWidget') ||
        code.contains('StatefulWidget')) {
      return 'dart';
    }
    if (code.contains('public class') ||
        code.contains('public static void main')) {
      return 'java';
    }
    return 'text';
  }

  /// Extracts the broad contextual domain of the document.
  String _extractDocumentContext(String text, String? filename) {
    if (filename != null) {
      final lower = filename.toLowerCase();
      if (lower.contains('flutter')) return 'Flutter';
      if (lower.contains('java') || lower.contains('jls')) return 'Java';
      if (lower.contains('respiration') || lower.contains('biology')) {
        return 'Cellular Respiration';
      }
      if (lower.contains('engagement') || lower.contains('letter')) {
        return 'Engagement Agreement';
      }
    }

    final firstLines = text.split('\n').take(10).join(' ');
    if (firstLines.contains('Flutter')) return 'Flutter';
    if (firstLines.contains('Java')) return 'Java';
    if (firstLines.contains('respiration')) return 'Cellular Respiration';
    return 'General';
  }
}
