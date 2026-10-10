/// Represents coordinate bounding box geometry on a document page or viewport.
class BoundingBox {
  const BoundingBox({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  factory BoundingBox.fromJson(Map<String, dynamic> json) => BoundingBox(
    left: (json['left'] as num).toDouble(),
    top: (json['top'] as num).toDouble(),
    right: (json['right'] as num).toDouble(),
    bottom: (json['bottom'] as num).toDouble(),
  );

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;

  Map<String, dynamic> toJson() => {
    'left': left,
    'top': top,
    'right': right,
    'bottom': bottom,
  };

  @override
  String toString() =>
      'BoundingBox($left, $top, $right, $bottom, ${width}x$height)';
}

/// Provenance metadata tracking exact source coordinates, page, reading order,
/// and hierarchical section context for every block in a document.
class BlockProvenance {
  const BlockProvenance({
    required this.docId,
    required this.page,
    required this.readingOrder,
    required this.sectionPath,
    this.bbox,
  });

  factory BlockProvenance.fromJson(Map<String, dynamic> json) =>
      BlockProvenance(
        docId: json['doc_id'] as String,
        page: json['page'] as int? ?? 1,
        readingOrder: json['reading_order'] as int? ?? 0,
        sectionPath: List<String>.from(json['section_path'] as List? ?? []),
        bbox: json['bbox'] != null
            ? BoundingBox.fromJson(json['bbox'] as Map<String, dynamic>)
            : null,
      );

  /// Unique content hash or document identifier.
  final String docId;

  /// 1-based page, slide, or sheet index.
  final int page;

  /// 0-based sequential reading-order index within the document.
  final int readingOrder;

  /// Hierarchical section title path stack (e.g. `["Chapter 1", "Section 1.2"]`).
  final List<String> sectionPath;

  /// Spatial bounding box coordinates, if available from PDF/vector stream.
  final BoundingBox? bbox;

  Map<String, dynamic> toJson() => {
    'doc_id': docId,
    'page': page,
    'reading_order': readingOrder,
    'section_path': sectionPath,
    if (bbox != null) 'bbox': bbox!.toJson(),
  };

  @override
  String toString() =>
      'BlockProvenance(page: $page, order: $readingOrder, path: $sectionPath)';
}

/// Abstract base class for all strongly-typed AST nodes in the Document Intermediate Representation.
sealed class DocumentBlock {
  const DocumentBlock({required this.provenance});

  final BlockProvenance provenance;

  /// Verbatim raw text representation of the block content.
  String get rawText;

  Map<String, dynamic> toJson();
}

/// A structural section heading node (e.g., `#`, `##`, or `Section 1.2`).
class HeadingBlock extends DocumentBlock {
  const HeadingBlock({
    required this.text,
    required this.level,
    required super.provenance,
  });

  factory HeadingBlock.fromJson(Map<String, dynamic> json) => HeadingBlock(
    text: json['text'] as String,
    level: json['level'] as int,
    provenance: BlockProvenance.fromJson(
      json['provenance'] as Map<String, dynamic>,
    ),
  );

  final String text;

  /// Heading depth level from 1 (top-level title) to 6 (deep subsection).
  final int level;

  @override
  String get rawText => text;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'heading',
    'text': text,
    'level': level,
    'provenance': provenance.toJson(),
  };

  @override
  String toString() => 'HeadingBlock(H$level: "$text")';
}

/// A continuous paragraph block consisting of segmented sentences.
class ParagraphBlock extends DocumentBlock {
  const ParagraphBlock({
    required this.text,
    required this.sentences,
    required super.provenance,
  });

  factory ParagraphBlock.fromJson(Map<String, dynamic> json) => ParagraphBlock(
    text: json['text'] as String,
    sentences: List<String>.from(json['sentences'] as List? ?? []),
    provenance: BlockProvenance.fromJson(
      json['provenance'] as Map<String, dynamic>,
    ),
  );

  final String text;
  final List<String> sentences;

  @override
  String get rawText => text;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'paragraph',
    'text': text,
    'sentences': sentences,
    'provenance': provenance.toJson(),
  };

  @override
  String toString() => 'ParagraphBlock(${sentences.length} sentences: "$text")';
}

/// An individual bulleted or numbered item inside a list.
class ListItemBlock extends DocumentBlock {
  const ListItemBlock({
    required this.text,
    required this.bulletPrefix,
    required this.isOrdered,
    required this.level,
    required super.provenance,
  });

  factory ListItemBlock.fromJson(Map<String, dynamic> json) => ListItemBlock(
    text: json['text'] as String,
    bulletPrefix: json['bullet_prefix'] as String,
    isOrdered: json['is_ordered'] as bool,
    level: json['level'] as int? ?? 1,
    provenance: BlockProvenance.fromJson(
      json['provenance'] as Map<String, dynamic>,
    ),
  );

  final String text;
  final String bulletPrefix;
  final bool isOrdered;
  final int level;

  @override
  String get rawText => '$bulletPrefix $text'.trim();

  @override
  Map<String, dynamic> toJson() => {
    'type': 'list_item',
    'text': text,
    'bullet_prefix': bulletPrefix,
    'is_ordered': isOrdered,
    'level': level,
    'provenance': provenance.toJson(),
  };

  @override
  String toString() => 'ListItemBlock("$bulletPrefix $text")';
}

/// A structured list container holding ordered or unordered item blocks.
class ListBlock extends DocumentBlock {
  const ListBlock({
    required this.isOrdered,
    required this.items,
    required super.provenance,
  });

  factory ListBlock.fromJson(Map<String, dynamic> json) => ListBlock(
    isOrdered: json['is_ordered'] as bool,
    items: (json['items'] as List)
        .map((i) => ListItemBlock.fromJson(i as Map<String, dynamic>))
        .toList(),
    provenance: BlockProvenance.fromJson(
      json['provenance'] as Map<String, dynamic>,
    ),
  );

  final bool isOrdered;
  final List<ListItemBlock> items;

  @override
  String get rawText => items.map((i) => i.rawText).join('\n');

  @override
  Map<String, dynamic> toJson() => {
    'type': 'list',
    'is_ordered': isOrdered,
    'items': items.map((i) => i.toJson()).toList(),
    'provenance': provenance.toJson(),
  };

  @override
  String toString() =>
      'ListBlock(${isOrdered ? "ordered" : "unordered"}, ${items.length} items)';
}

/// A tabular data block with headers and structured data rows.
class TableBlock extends DocumentBlock {
  const TableBlock({
    required this.headers,
    required this.rows,
    required super.provenance,
    this.caption,
  });

  factory TableBlock.fromJson(Map<String, dynamic> json) => TableBlock(
    headers: List<String>.from(json['headers'] as List? ?? []),
    rows: (json['rows'] as List? ?? [])
        .map((r) => List<String>.from(r as List))
        .toList(),
    caption: json['caption'] as String?,
    provenance: BlockProvenance.fromJson(
      json['provenance'] as Map<String, dynamic>,
    ),
  );

  final List<String> headers;
  final List<List<String>> rows;
  final String? caption;

  @override
  String get rawText {
    final buffer = StringBuffer();
    if (caption != null) buffer.writeln('Table: $caption');
    if (headers.isNotEmpty) buffer.writeln(headers.join(' | '));
    for (final row in rows) {
      buffer.writeln(row.join(' | '));
    }
    return buffer.toString().trim();
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'table',
    'headers': headers,
    'rows': rows,
    if (caption != null) 'caption': caption,
    'provenance': provenance.toJson(),
  };

  @override
  String toString() =>
      'TableBlock(${headers.length} cols, ${rows.length} rows)';
}

/// A verbatim source code block with language annotation and preserved whitespace.
class CodeBlock extends DocumentBlock {
  const CodeBlock({
    required this.code,
    required this.lineCount,
    required super.provenance,
    this.language,
  });

  factory CodeBlock.fromJson(Map<String, dynamic> json) => CodeBlock(
    code: json['code'] as String,
    language: json['language'] as String?,
    lineCount: json['line_count'] as int? ?? 1,
    provenance: BlockProvenance.fromJson(
      json['provenance'] as Map<String, dynamic>,
    ),
  );

  final String code;
  final String? language;
  final int lineCount;

  @override
  String get rawText =>
      '```${language ?? ""}\n$code${code.endsWith("\n") ? "" : "\n"}```';

  @override
  Map<String, dynamic> toJson() => {
    'type': 'code',
    'code': code,
    if (language != null) 'language': language,
    'line_count': lineCount,
    'provenance': provenance.toJson(),
  };

  @override
  String toString() =>
      'CodeBlock(${language ?? "plain"}, $lineCount lines)';
}

/// A mathematical expression block (display formula, equation environment, or inline math).
class MathBlock extends DocumentBlock {
  const MathBlock({
    required this.latex,
    required this.isDisplay,
    required this.rawMathText,
    required super.provenance,
  });

  factory MathBlock.fromJson(Map<String, dynamic> json) => MathBlock(
    latex: json['latex'] as String,
    isDisplay: json['is_display'] as bool? ?? true,
    rawMathText: json['raw_math_text'] as String? ?? '',
    provenance: BlockProvenance.fromJson(
      json['provenance'] as Map<String, dynamic>,
    ),
  );

  final String latex;
  final bool isDisplay;
  final String rawMathText;

  @override
  String get rawText => isDisplay ? '\$\$\n$latex\n\$\$' : '\$$latex\$';

  @override
  Map<String, dynamic> toJson() => {
    'type': 'math',
    'latex': latex,
    'is_display': isDisplay,
    'raw_math_text': rawMathText,
    'provenance': provenance.toJson(),
  };

  @override
  String toString() =>
      'MathBlock(${isDisplay ? "display" : "inline"}: "$latex")';
}

/// A figure, diagram, or graphic attachment with caption and page context.
class FigureBlock extends DocumentBlock {
  const FigureBlock({
    required this.page,
    required super.provenance,
    this.imageRef,
    this.caption,
    this.label,
  });

  factory FigureBlock.fromJson(Map<String, dynamic> json) => FigureBlock(
    imageRef: json['image_ref'] as String?,
    caption: json['caption'] as String?,
    label: json['label'] as String?,
    page: json['page'] as int? ?? 1,
    provenance: BlockProvenance.fromJson(
      json['provenance'] as Map<String, dynamic>,
    ),
  );

  final String? imageRef;
  final String? caption;
  final String? label;
  final int page;

  @override
  String get rawText =>
      caption ?? label ?? (imageRef != null ? '![Figure]($imageRef)' : '');

  @override
  Map<String, dynamic> toJson() => {
    'type': 'figure',
    if (imageRef != null) 'image_ref': imageRef,
    if (caption != null) 'caption': caption,
    if (label != null) 'label': label,
    'page': page,
    'provenance': provenance.toJson(),
  };

  @override
  String toString() =>
      'FigureBlock(page: $page, label: "$label", caption: "$caption")';
}

/// Strongly-typed Intermediate Representation (DocumentIR) of an ingested document.
class DocumentIR {
  const DocumentIR({
    required this.docId,
    required this.filename,
    required this.blocks,
    this.metadata = const {},
  });

  factory DocumentIR.fromJson(Map<String, dynamic> json) {
    final rawBlocks = json['blocks'] as List? ?? [];
    final blocks = <DocumentBlock>[];

    for (final raw in rawBlocks) {
      final map = raw as Map<String, dynamic>;
      final type = map['type'] as String?;
      switch (type) {
        case 'heading':
          blocks.add(HeadingBlock.fromJson(map));
        case 'paragraph':
          blocks.add(ParagraphBlock.fromJson(map));
        case 'list_item':
          blocks.add(ListItemBlock.fromJson(map));
        case 'list':
          blocks.add(ListBlock.fromJson(map));
        case 'table':
          blocks.add(TableBlock.fromJson(map));
        case 'code':
          blocks.add(CodeBlock.fromJson(map));
        case 'math':
          blocks.add(MathBlock.fromJson(map));
        case 'figure':
          blocks.add(FigureBlock.fromJson(map));
      }
    }

    return DocumentIR(
      docId: json['doc_id'] as String,
      filename: json['filename'] as String? ?? 'document',
      blocks: blocks,
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
    );
  }

  final String docId;
  final String filename;
  final List<DocumentBlock> blocks;
  final Map<String, dynamic> metadata;

  /// All heading blocks in document reading order.
  List<HeadingBlock> get headings => blocks.whereType<HeadingBlock>().toList();

  /// All prose paragraph blocks in document reading order.
  List<ParagraphBlock> get paragraphs =>
      blocks.whereType<ParagraphBlock>().toList();

  /// All structured list blocks in document reading order.
  List<ListBlock> get lists => blocks.whereType<ListBlock>().toList();

  /// All tabular data blocks in document reading order.
  List<TableBlock> get tables => blocks.whereType<TableBlock>().toList();

  /// All code blocks in document reading order.
  List<CodeBlock> get codeBlocks => blocks.whereType<CodeBlock>().toList();

  /// All mathematical blocks in document reading order.
  List<MathBlock> get mathBlocks => blocks.whereType<MathBlock>().toList();

  /// All figure and visual diagram blocks in document reading order.
  List<FigureBlock> get figures => blocks.whereType<FigureBlock>().toList();

  /// Total number of blocks in the DocumentIR.
  int get blockCount => blocks.length;

  /// Reconstructs the complete document content from its AST blocks.
  String toFullText() => blocks.map((b) => b.rawText).join('\n\n');

  Map<String, dynamic> toJson() => {
    'doc_id': docId,
    'filename': filename,
    'blocks': blocks.map((b) => b.toJson()).toList(),
    'metadata': metadata,
  };

  @override
  String toString() =>
      'DocumentIR($filename, blocks: ${blocks.length}, headings: ${headings.length}, code: ${codeBlocks.length}, math: ${mathBlocks.length})';
}
