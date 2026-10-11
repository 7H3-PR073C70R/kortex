/// Functional document zones representing standard publishing structures
/// (DocBook, JATS, and Dublin Core taxonomies).
enum DocumentZone {
  /// Zone A: Front matter, table of contents, lists of figures/tables, indices.
  frontMatter,

  /// Zone B: Administrative metadata, licensing, copyright, community guidelines, surveys, social channels.
  administrative,

  /// Zone C: Ephemeral lifecycle events, release highlights, changelogs, migration guides, deprecation notes.
  lifecycle,

  /// Zone D: Formative assessment, exercise prompts, drills, problem sets, homework, hints, solution scaffolds.
  assessment,

  /// Zone E: Core pedagogical knowledge body (concepts, definitions, principles, mechanisms, formulas, data tables).
  bodyKnowledge,
}

/// Generic, document-agnostic classifier that partitions document sections
/// and content blocks into structural document zones.
///
/// Ensures zero hardcoding for specific textbooks or manuals, scaling across
/// academic literature, technical specifications, and training materials.
class DocumentZoneClassifier {
  const DocumentZoneClassifier();

  static const instance = DocumentZoneClassifier();

  /// Returns true if the zone represents non-pedagogical document structure
  /// that should be excluded from flashcard synthesis.
  static bool isNonPedagogicalZone(DocumentZone zone) =>
      zone != DocumentZone.bodyKnowledge;

  // ---------------------------------------------------------------------------
  // ZONE A: FRONT MATTER & NAVIGATION REGEX PATTERNS
  // ---------------------------------------------------------------------------
  // ---------------------------------------------------------------------------
  // ZONE A: FRONT MATTER & NAVIGATION REGEX PATTERNS
  // ---------------------------------------------------------------------------
  static final _frontMatterRegex = RegExp(
    '^(?:'
    r'table\s+of\s+contents|brief\s+contents|contents|'
    r'(?:subject\s+|author\s+)?index(?:es|ices)?|'
    r'list\s+of\s+(?:figures|tables|illustrations|plates|boxes)|'
    'preface|foreword|acknowledg(?:e)?ments?|'
    r'0(?:\.\d+)*\s+.*|chapter\s+0\b.*|'
    r'how\s+to\s+(?:use|read)\s+this\s+book.*|about\s+this\s+book.*|'
    r'conventions?\s+used.*|typographic(?:al)?\s+conventions?.*'
    r')[\s\p{P}]*$',
    caseSensitive: false,
    unicode: true,
  );

  // ---------------------------------------------------------------------------
  // ZONE B: ADMINISTRATIVE, LEGAL, COMMUNITY & FEEDBACK PATTERNS
  // ---------------------------------------------------------------------------
  static final _adminRegex = RegExp(
    r'\b(?:'
    r'code\s+of\s+conduct|community\s+guidelines?|conduct\s+and\s+guidelines?|'
    r'slack(?:\s+guidelines?|\s+rules?|\s+channels?)?|discord(?:\s+guidelines?|\s+rules?|\s+channels?)?|'
    r'moderators?|user\s+groups?|kug\s+guidelines?|'
    r'license|licensing|copyright|all\s+rights\s+reserved|trademarks?|terms\s+of\s+(?:service|use)|'
    r'about\s+the\s+authors?|contributors?(?:\s+and\s+(?:acknowledgments?|reviewers?))?|reviewers?|'
    r'contributing(?:\s+guidelines?)?|'
    r'join\s+us(?:\s+on)?|documentation\s+survey|survey(?:\s+and|\s*&)?\s*feedback|stay\s+connected|'
    r'subscribe\s+to(?:\s+our)?\s+newsletter|'
    r'bill\s+to:|invoice(?:\s+details)?|payment\s+terms|statement\s+of\s+work'
    r')\b',
    caseSensitive: false,
  );

  // ---------------------------------------------------------------------------
  // ZONE C: EPHEMERAL LIFECYCLE & CHANGELOG PATTERNS
  // ---------------------------------------------------------------------------
  static final _lifecycleRegex = RegExp(
    r'\b(?:'
    r'what\s*s\s*new|release\s*notes?|changelog|version\s*history|'
    r'breaking\s*changes?(?:\s+and\s+deprecations?)?|deprecat(?:ed|ions?)?|'
    r'(?:upgrad(?:ing|e)|migrat(?:ing|ion)|compatibility)\s*guide|'
    r'v?\d+\.\d+(?:\.\d+)?\s*(?:release|notes?|highlights?|summary)|'
    r'incompatible\s*changes?|compiler\s*plugin|steps|highlights?'
    r')\b',
    caseSensitive: false,
  );

  // ---------------------------------------------------------------------------
  // ZONE D: FORMATIVE ASSESSMENT & EXERCISE PROMPTS PATTERNS
  // ---------------------------------------------------------------------------
  static final _assessmentRegex = RegExp(
    r'\b(?:'
    r'exercises?|practice(?:\s+problems?)?|problem\s*sets?|homework(?:s)?|'
    'drills?|assignments?|quiz(?:z?es)?|self-?tests?|questionnaires?|'
    r'review\s*questions?|hints?|tasks?|solutions?'
    r')\b',
    caseSensitive: false,
  );

  // ---------------------------------------------------------------------------
  // BLOCK CONTENT LEVEL EXCLUSION DIRECTIVES
  // ---------------------------------------------------------------------------
  static final _skipBlockContentRegex = RegExp(
    '(?:'
    r'copyright\s+(?:\(c\)|©)|\ball\s+rights\s+reserved\b|\blicensed\s+under\b|'
    r'\b(?:join\s+(?:us\s+on|our|the)|get\s+a\s+(?:slack|discord)\s+invite|follow\s+us\s+on|subscribe\s+to\s+(?:our|the))\b|'
    r'\b(?:fill\s+out\s+(?:our|this)\s+survey|provide\s+(?:your\s+)?feedback(?:\s+in|\s+directly)?|documentation\s+survey)\b|'
    r'\b(?:for\s+more\s+(?:information|details),?\s+see(?:\s+the)?\s+(?:changelog|release\s+notes?|what\s*s\s*new|documentation))\b|'
    r'\b(?:learn\s+more\s+in\s+the\s+(?:changelog|release\s+notes?|blog\s+post))\b|'
    r'\b(?:find\s+help\s+in\s+the\s+#\w+\s+channel|get\s+an\s+invite)\b|'
    r'(?://|#|/\*)\s*(?:write\s+your\s+code\s+here|todo:|implement\s+(?:your|solution|here))|'
    r"(?:what(?:'s|\s+is)\s+next\??\s*$)|"
    r'^(?:exercise|solution|problem|practice|drill|task|answer|hint)\s+\d+'
    ')',
    caseSensitive: false,
  );

  /// Classifies a section or header text into its canonical [DocumentZone].
  DocumentZone classifyHeading(String rawHeading) {
    final clean = rawHeading
        .replaceAll(RegExp("['’]"), '')
        .trim()
        .replaceAll(RegExp(r'^[#*_\-\s]+|[#*_\-\s]+$'), '')
        .trim();

    if (clean.isEmpty) return DocumentZone.bodyKnowledge;

    // 1. Zone A: Front Matter & Navigation
    if (_frontMatterRegex.hasMatch(clean)) {
      return DocumentZone.frontMatter;
    }

    // 2. Zone B: Administrative, Legal, Community & Governance
    if (_adminRegex.hasMatch(clean)) {
      return DocumentZone.administrative;
    }

    // 3. Zone C: Temporal Lifecycle, Changelogs & Deprecations
    if (_lifecycleRegex.hasMatch(clean)) {
      return DocumentZone.lifecycle;
    }

    // 4. Zone D: Formative Assessment, Practice Drills & Hints
    if (_assessmentRegex.hasMatch(clean)) {
      return DocumentZone.assessment;
    }

    // 5. Zone E: Default to Core Knowledge Body
    return DocumentZone.bodyKnowledge;
  }

  /// Determines if an individual content block should be skipped based on
  /// its inherited zone or embedded boilerplate directives.
  bool shouldSkipBlockContent(
    String text, {
    DocumentZone currentZone = DocumentZone.bodyKnowledge,
  }) {
    if (isNonPedagogicalZone(currentZone)) return true;

    final trimmed = text.trim();
    if (trimmed.isEmpty) return true;

    return _skipBlockContentRegex.hasMatch(trimmed);
  }
}
