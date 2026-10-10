/// Strongly-typed audit log recording dropped lines, skipped pages,
/// noise filters, and extraction anomalies across document parsing.
class DroppedElement {
  const DroppedElement({
    required this.rule,
    required this.sampleText,
    this.page,
  });

  /// 1-based page, slide, or sheet index (null if document-wide).
  final int? page;

  /// Exact rule or filter triggered (e.g. 'repeating_marginalia', 'page_noise',
  /// 'non_educational_front_matter', 'toc_run', 'renderer_metadata', 'syntax_noise').
  final String rule;

  /// Verbatim sample text of dropped lines, pages, or elements.
  final String sampleText;

  Map<String, dynamic> toJson() => {
    if (page != null) 'page': page,
    'rule': rule,
    'sample_text': sampleText,
  };

  @override
  String toString() =>
      'DroppedElement(page: $page, rule: "$rule", sample: "$sampleText")';
}

/// Audit report documenting text extraction status, anomalies, and dropped content.
class ExtractionReport {
  ExtractionReport({
    required this.filename,
    this.fileType = '',
    this.isEncrypted = false,
    this.isScanned = false,
    this.isCorrupt = false,
    List<DroppedElement>? droppedElements,
    List<String>? warnings,
  })  : droppedElements = droppedElements ?? [],
        warnings = warnings ?? [];

  final String filename;
  final String fileType;
  bool isEncrypted;
  bool isScanned;
  bool isCorrupt;
  final List<DroppedElement> droppedElements;
  final List<String> warnings;

  int totalLinesProcessed = 0;
  int totalLinesRetained = 0;

  int get totalDroppedElements => droppedElements.length;

  /// Records an element dropped by a specific extraction filter.
  void recordDrop({
    required String rule,
    required String sampleText,
    int? page,
  }) {
    final trimmed = sampleText.trim();
    if (trimmed.isEmpty) return;
    droppedElements.add(
      DroppedElement(
        page: page,
        rule: rule,
        sampleText: trimmed.length > 200
            ? '${trimmed.substring(0, 197)}...'
            : trimmed,
      ),
    );
  }

  /// Records an extraction warning or non-fatal anomaly.
  void recordWarning(String warning) {
    warnings.add(warning);
  }

  Map<String, dynamic> toJson() => {
    'filename': filename,
    'file_type': fileType,
    'is_encrypted': isEncrypted,
    'is_scanned': isScanned,
    'is_corrupt': isCorrupt,
    'total_lines_processed': totalLinesProcessed,
    'total_lines_retained': totalLinesRetained,
    'total_dropped_elements': totalDroppedElements,
    'dropped_elements': droppedElements.map((e) => e.toJson()).toList(),
    'warnings': warnings,
  };

  @override
  String toString() =>
      'ExtractionReport($filename, dropped: $totalDroppedElements, '
      'encrypted: $isEncrypted, scanned: $isScanned, corrupt: $isCorrupt)';
}
