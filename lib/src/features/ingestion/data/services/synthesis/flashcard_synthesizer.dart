import 'package:kortex/src/features/ingestion/data/services/synthesis/document_ast_extractor.dart';
import 'package:kortex/src/features/ingestion/data/services/synthesis/transition_parser_engine.dart';
import 'package:kortex/src/features/ingestion/domain/entities/pedagogical_card_schema.dart';

/// The pedagogical classification of the generated flashcard.
enum CognitiveQuestionType {
  causality,
  mechanism,
  stateTransition,
  svo,
  definition,
  ebnf,
  code,
  math,
  location,
  yieldResult,
}

/// A synthesized candidate pedagogical card before validation.
class PedagogicalCandidateCard {
  const PedagogicalCandidateCard({
    required this.front,
    required this.back,
    required this.type,
    required this.sourceTopic,
    this.source,
    this.assets = const [],
    this.frontLatex,
    this.backLatex,
    this.imageUrl,
    this.confidenceScore = 0.95,
  });

  final String front;
  final String back;
  final CognitiveQuestionType type;
  final String sourceTopic;
  final CardSource? source;
  final List<CardAsset> assets;
  final String? frontLatex;
  final String? backLatex;
  final String? imageUrl;
  final double confidenceScore;
}

/// Layer 3: Discourse & Relinking Synthesizer.
///
/// Converts [DocumentAst] and dependency parses into rich pedagogical questions,
/// resolves anaphora, anchors questions to document domain, and restores
/// verbatim code, math, and media artifacts.
class FlashcardSynthesizer {
  FlashcardSynthesizer({TransitionParserEngine? parser})
      : _parser = parser ?? TransitionParserEngine.instance;

  final TransitionParserEngine _parser;

  static const _anaphoraBlacklist = {
    'it', 'this', 'that', 'these', 'those', 'they', 'he', 'she',
    'there', 'here', 'which', 'who', 'its', 'their', 'such',
  };

  /// Synthesizes a list of candidate flashcards from the document AST.
  List<PedagogicalCandidateCard> synthesize(DocumentAst ast) {
    final cards = <PedagogicalCandidateCard>[];
    String? currentHeading;

    for (final node in ast.nodes) {
      if (node is HeadingNode) {
        currentHeading = node.title;
        continue;
      }

      if (node is DefinitionNode) {
        final card = _synthesizeDefinitionCard(node, ast.documentContext);
        if (card != null) cards.add(card);
        continue;
      }

      if (node is GrammarProductionNode) {
        cards.add(_synthesizeEbnfCard(node, ast.documentContext));
        continue;
      }

      if (node is CodeBlockNode) {
        final card = _synthesizeCodeCard(node, currentHeading, ast.documentContext);
        if (card != null) cards.add(card);
        continue;
      }

      if (node is MathBlockNode) {
        final card = _synthesizeMathCard(node, currentHeading, ast.documentContext);
        if (card != null) cards.add(card);
        continue;
      }

      if (node is ParagraphNode) {
        for (final sentence in node.sentences) {
          final sentenceCards = _synthesizeSentence(
            sentence: sentence,
            fullParagraph: node.rawText,
            headingContext: node.headingContext ?? currentHeading,
            documentContext: ast.documentContext,
          );
          cards.addAll(sentenceCards);
        }
        continue;
      }

      if (node is ListItemNode) {
        final itemCards = _synthesizeListItem(
          node: node,
          headingContext: node.headingContext ?? currentHeading,
          documentContext: ast.documentContext,
        );
        cards.addAll(itemCards);
        continue;
      }
    }

    // Relink all artifact placeholders in candidate cards
    return cards.map((c) => _relinkArtifacts(c, ast.registry)).toList();
  }

  /// Synthesizes cards from a single prose sentence using transition parsing.
  List<PedagogicalCandidateCard> _synthesizeSentence({
    required String sentence,
    required String fullParagraph,
    required String? headingContext,
    required String documentContext,
  }) {
    final clean = sentence.trim();
    if (clean.length < 15) return [];

    final cards = <PedagogicalCandidateCard>[];
    final tree = _parser.parse(clean);

    // 1. Causality check (advcl with because / due to / since / as a result of)
    final causalityCard = _trySynthesizeCausality(
      tree: tree,
      sentence: clean,
      headingContext: headingContext,
      documentContext: documentContext,
    );
    if (causalityCard != null) {
      cards.add(causalityCard);
      return cards;
    }

    // 2. Mechanism check (prep with by / via / using / through)
    final mechanismCard = _trySynthesizeMechanism(
      tree: tree,
      sentence: clean,
      headingContext: headingContext,
      documentContext: documentContext,
    );
    if (mechanismCard != null) {
      cards.add(mechanismCard);
      return cards;
    }

    // 3. State Transition / Gerund Subject check (Calling X / When X is called)
    final stateCard = _trySynthesizeStateTransition(
      tree: tree,
      sentence: clean,
      headingContext: headingContext,
      documentContext: documentContext,
    );
    if (stateCard != null) {
      cards.add(stateCard);
      return cards;
    }

    // 4. Location check (takes place in / occurs in / located in)
    final locationCard = _trySynthesizeLocation(
      tree: tree,
      sentence: clean,
      headingContext: headingContext,
      documentContext: documentContext,
    );
    if (locationCard != null) {
      cards.add(locationCard);
      return cards;
    }

    // 5. Net Yield / Conversion check (splits X into Y / yields Z / produces W)
    final yieldCard = _trySynthesizeYield(
      tree: tree,
      sentence: clean,
      headingContext: headingContext,
      documentContext: documentContext,
    );
    if (yieldCard != null) {
      cards.add(yieldCard);
      return cards;
    }

    // 6. SVO Core Action check
    final svoCard = _trySynthesizeSvo(
      tree: tree,
      sentence: clean,
      headingContext: headingContext,
      documentContext: documentContext,
    );
    if (svoCard != null) {
      cards.add(svoCard);
      return cards;
    }

    return cards;
  }

  /// Synthesizes causality question: Why does Subject Verb Object?
  PedagogicalCandidateCard? _trySynthesizeCausality({
    required DependencyTree tree,
    required String sentence,
    required String? headingContext,
    required String documentContext,
  }) {
    final lower = sentence.toLowerCase();
    final markerMatch = RegExp(r'\b(because|due to|since|in order to|as a result of)\b').firstMatch(lower);
    if (markerMatch == null) return null;

    final marker = markerMatch.group(1)!;
    final markerIndex = lower.indexOf(marker);
    if (markerIndex <= 0) return null;

    final mainClause = sentence.substring(0, markerIndex).trim().replaceAll(RegExp(r'[,;]$'), '');
    if (mainClause.length < 8) return null;

    final mainTree = _parser.parse(mainClause);
    final subjectNode = _findSubject(mainTree);
    if (subjectNode == null) return null;

    var subjectText = subjectNode.getSubtreeSpanText();
    if (_isAnaphora(subjectText)) {
      if (headingContext == null || _isAnaphora(headingContext)) return null;
      subjectText = headingContext;
    }

    final root = mainTree.root;
    final verb = root.lemma;
    final dobj = root.findFirstChild('dobj')?.getSubtreeSpanText() ?? '';

    final contextPrefix = _resolveContextPrefix(subjectText, headingContext, documentContext);
    final isPlural = subjectNode.pos == 'NNS' || subjectNode.pos == 'VBP';
    final question = dobj.isNotEmpty
        ? '$contextPrefix${_conjugateInterrogative(subjectText, isPlural, verb, dobj, prefix: "Why does", pluralPrefix: "Why do")}?'
        : '$contextPrefix${_conjugateInterrogative(subjectText, isPlural, verb, "", prefix: "Why does", pluralPrefix: "Why do")}?';

    return PedagogicalCandidateCard(
      front: question,
      back: sentence,
      type: CognitiveQuestionType.causality,
      sourceTopic: headingContext ?? documentContext,
    );
  }

  /// Synthesizes mechanism question: How does Subject Verb Object?
  PedagogicalCandidateCard? _trySynthesizeMechanism({
    required DependencyTree tree,
    required String sentence,
    required String? headingContext,
    required String documentContext,
  }) {
    final lower = sentence.toLowerCase();
    final markerMatch = RegExp(r'\b(by|via|using|through)\b').firstMatch(lower);
    if (markerMatch == null) return null;

    final markerIndex = lower.indexOf(markerMatch.group(1)!);
    final mainClause = sentence.substring(0, markerIndex).trim().replaceAll(RegExp(r'[,;]$'), '');
    if (mainClause.length < 8) return null;

    final mainTree = _parser.parse(mainClause);
    final subjectNode = _findSubject(mainTree);
    if (subjectNode == null) return null;

    var subjectText = subjectNode.getSubtreeSpanText();
    if (_isAnaphora(subjectText)) {
      if (headingContext == null || _isAnaphora(headingContext)) return null;
      subjectText = headingContext;
    }

    final root = mainTree.root;
    final verb = root.lemma;
    final dobj = root.findFirstChild('dobj')?.getSubtreeSpanText() ?? '';

    final isPlural = subjectNode.pos == 'NNS' || subjectNode.pos == 'VBP';
    final contextPrefix = _resolveContextPrefix(subjectText, headingContext, documentContext);
    final question = dobj.isNotEmpty
        ? '$contextPrefix${_conjugateInterrogative(subjectText, isPlural, verb, dobj, prefix: "How does", pluralPrefix: "How do")}?'
        : '$contextPrefix${_conjugateInterrogative(subjectText, isPlural, verb, "", prefix: "How does", pluralPrefix: "How do")}?';

    return PedagogicalCandidateCard(
      front: question,
      back: sentence,
      type: CognitiveQuestionType.mechanism,
      sourceTopic: headingContext ?? documentContext,
    );
  }

  /// Synthesizes state transition question: What happens when Subject is called?
  PedagogicalCandidateCard? _trySynthesizeStateTransition({
    required DependencyTree tree,
    required String sentence,
    required String? headingContext,
    required String documentContext,
  }) {
    // Gerund subject (e.g. Calling dispose() cancels timers...)
    final gerundMatch = RegExp(r'^(?:Calling|Invoking|Executing|Triggering)\s+([a-zA-Z0-9_\.\(\)]+)', caseSensitive: false).firstMatch(sentence);
    if (gerundMatch != null) {
      final method = gerundMatch.group(1)!;
      final contextPrefix = _resolveContextPrefix(method, headingContext, documentContext);
      return PedagogicalCandidateCard(
        front: '${contextPrefix}What happens when $method is called?',
        back: sentence,
        type: CognitiveQuestionType.stateTransition,
        sourceTopic: headingContext ?? documentContext,
      );
    }

    // Subordinate clause with "When X is called/triggered..."
    final whenMatch = RegExp(r'^When\s+([A-Za-z0-9_\.\(\)\s]+?)\s+(?:is\s+called|is\s+triggered|occurs)', caseSensitive: false).firstMatch(sentence);
    if (whenMatch != null) {
      final trigger = whenMatch.group(1)!.trim();
      final contextPrefix = _resolveContextPrefix(trigger, headingContext, documentContext);
      return PedagogicalCandidateCard(
        front: '${contextPrefix}What happens when $trigger is called?',
        back: sentence,
        type: CognitiveQuestionType.stateTransition,
        sourceTopic: headingContext ?? documentContext,
      );
    }

    return null;
  }

  /// Synthesizes location question: Where does Process take place?
  PedagogicalCandidateCard? _trySynthesizeLocation({
    required DependencyTree tree,
    required String sentence,
    required String? headingContext,
    required String documentContext,
  }) {
    final lower = sentence.toLowerCase();
    if (!lower.contains('take place in') && !lower.contains('takes place in') && !lower.contains('occurs in')) {
      return null;
    }

    final subjectNode = _findSubject(tree);
    var subjectText = subjectNode?.getSubtreeSpanText() ?? '';

    if (_isAnaphora(subjectText) || subjectText.isEmpty) {
      if (headingContext == null || _isAnaphora(headingContext)) return null;
      subjectText = headingContext;
    }

    final contextPrefix = _resolveContextPrefix(subjectText, headingContext, documentContext);
    return PedagogicalCandidateCard(
      front: '${contextPrefix}Where does $subjectText take place?',
      back: sentence,
      type: CognitiveQuestionType.location,
      sourceTopic: headingContext ?? documentContext,
    );
  }

  /// Synthesizes yield/conversion question: What does Process split or yield?
  PedagogicalCandidateCard? _trySynthesizeYield({
    required DependencyTree tree,
    required String sentence,
    required String? headingContext,
    required String documentContext,
  }) {
    final root = tree.root;
    final lemma = root.lemma.toLowerCase();
    if (['split', 'convert', 'yield', 'produce', 'generate'].contains(lemma)) {
      final subjectNode = _findSubject(tree);
      if (subjectNode == null) return null;

      var subjectText = subjectNode.getSubtreeSpanText();
      if (_isAnaphora(subjectText)) {
        if (headingContext == null || _isAnaphora(headingContext)) return null;
        subjectText = headingContext;
      }

      final dobj = root.findFirstChild('dobj')?.getSubtreeSpanText() ?? '';
      if (dobj.isEmpty) return null;

      final contextPrefix = _resolveContextPrefix(subjectText, headingContext, documentContext);
      return PedagogicalCandidateCard(
        front: '${contextPrefix}What does $subjectText $lemma?',
        back: sentence,
        type: CognitiveQuestionType.yieldResult,
        sourceTopic: headingContext ?? documentContext,
      );
    }
    return null;
  }

  /// Synthesizes SVO action question: What does Subject Verb?
  PedagogicalCandidateCard? _trySynthesizeSvo({
    required DependencyTree tree,
    required String sentence,
    required String? headingContext,
    required String documentContext,
  }) {
    final root = tree.root;
    if (root.pos != 'VBZ' && root.pos != 'VBP' && root.pos != 'VBD') return null;

    final subjectNode = _findSubject(tree);
    final dobjNode = root.findFirstChild('dobj');
    if (subjectNode == null || dobjNode == null) return null;

    var subjectText = subjectNode.getSubtreeSpanText();
    if (_isAnaphora(subjectText)) {
      if (headingContext == null || _isAnaphora(headingContext)) return null;
      subjectText = headingContext;
    }

    // Reject auxiliary copulas
    if (['be', 'is', 'are', 'was', 'were', 'have', 'has'].contains(root.lemma)) {
      return null;
    }

    final isPlural = subjectNode.pos == 'NNS' || subjectNode.pos == 'VBP';
    final contextPrefix = _resolveContextPrefix(subjectText, headingContext, documentContext);
    final question = '$contextPrefix${_conjugateInterrogative(subjectText, isPlural, root.lemma, "", prefix: "What does", pluralPrefix: "What do")}?';

    return PedagogicalCandidateCard(
      front: question,
      back: sentence,
      type: CognitiveQuestionType.svo,
      sourceTopic: headingContext ?? documentContext,
    );
  }

  /// Synthesizes cards from bullet list items.
  List<PedagogicalCandidateCard> _synthesizeListItem({
    required ListItemNode node,
    required String? headingContext,
    required String documentContext,
  }) {
    final content = node.content.trim();
    if (content.length < 15) return [];

    // Check if the bullet item has an explicit sub-heading or bold term
    final colonMatch = RegExp(r'^([A-Z][A-Za-z0-9_\s\(\)\/\-]{1,50})\s*[:–—]\s*(.+)$').firstMatch(content);
    if (colonMatch != null) {
      final term = colonMatch.group(1)!.trim();
      final explanation = colonMatch.group(2)!.trim();
      if (explanation.length >= 15) {
        String front;
        if (headingContext != null &&
            !{'key terms', 'definitions', 'glossary'}.contains(headingContext.toLowerCase())) {
          final isAction = RegExp(
            r'^(?:implement|add|allow|build|develop|create|integrate|support|work|track|collaborate|write|maintain)\b',
            caseSensitive: false,
          ).hasMatch(explanation);
          if (isAction) {
            front = 'In "$headingContext", what does "$term" involve?';
          } else {
            front = 'In "$headingContext", what is $term?';
          }
        } else {
          front = 'What is $term?';
        }
        return [
          PedagogicalCandidateCard(
            front: front,
            back: node.rawText,
            type: CognitiveQuestionType.definition,
            sourceTopic: headingContext ?? documentContext,
          ),
        ];
      }
    }

    // Try normal sentence synthesis on bullet content
    return _synthesizeSentence(
      sentence: content,
      fullParagraph: node.rawText,
      headingContext: headingContext,
      documentContext: documentContext,
    );
  }

  /// Synthesizes a card for a glossary/definition node.
  PedagogicalCandidateCard? _synthesizeDefinitionCard(
    DefinitionNode node,
    String documentContext,
  ) {
    if (_isAnaphora(node.term)) return null;
    String front;
    if (node.headingContext != null &&
        !{'key terms', 'definitions', 'glossary'}.contains(node.headingContext!.toLowerCase())) {
      final isAction = RegExp(
        r'^(?:implement|add|allow|build|develop|create|integrate|support|work|track|collaborate|write|maintain)\b',
        caseSensitive: false,
      ).hasMatch(node.definition);
      if (isAction) {
        front = 'In "${node.headingContext}", what does "${node.term}" involve?';
      } else {
        front = 'In "${node.headingContext}", what is ${node.term}?';
      }
    } else {
      front = 'What is ${node.term}?';
    }
    return PedagogicalCandidateCard(
      front: front,
      back: node.rawText,
      type: CognitiveQuestionType.definition,
      sourceTopic: node.headingContext ?? documentContext,
    );
  }

  /// Synthesizes an EBNF formal grammar production card.
  PedagogicalCandidateCard _synthesizeEbnfCard(
    GrammarProductionNode node,
    String documentContext,
  ) {
    final spec = node.specificationContext ?? documentContext;
    return PedagogicalCandidateCard(
      front: 'What is the syntax specification for ${node.nonTerminal} in $spec?',
      back: node.rawText,
      type: CognitiveQuestionType.ebnf,
      sourceTopic: spec,
    );
  }

  /// Synthesizes a card for a verbatim code block.
  PedagogicalCandidateCard? _synthesizeCodeCard(
    CodeBlockNode node,
    String? headingContext,
    String documentContext,
  ) {
    // Extract class or function identifier
    final classMatch = RegExp(r'\bclass\s+([A-Za-z0-9_]+)').firstMatch(node.code);
    final funcMatch = RegExp(r'\b(?:void|Future|Widget|int|String|bool)\s+([A-Za-z0-9_]+)\s*\(').firstMatch(node.code);

    final identifier = classMatch?.group(1) ?? funcMatch?.group(1);
    final subject = identifier ?? headingContext ?? 'the implementation';

    final langTag = node.language.isNotEmpty ? ' in ${node.language}' : '';
    return PedagogicalCandidateCard(
      front: 'What is the code structure of $subject$langTag?',
      back: node.code,
      type: CognitiveQuestionType.code,
      sourceTopic: headingContext ?? documentContext,
    );
  }

  /// Synthesizes a card for a LaTeX mathematical formula.
  PedagogicalCandidateCard? _synthesizeMathCard(
    MathBlockNode node,
    String? headingContext,
    String documentContext,
  ) {
    final subject = headingContext ?? 'the mathematical formulation';
    return PedagogicalCandidateCard(
      front: 'What is the mathematical formulation of $subject?',
      back: node.latex,
      type: CognitiveQuestionType.math,
      backLatex: node.latex,
      sourceTopic: headingContext ?? documentContext,
    );
  }

  /// Relinks all artifact placeholders in the card back to their verbatim representations.
  PedagogicalCandidateCard _relinkArtifacts(
    PedagogicalCandidateCard card,
    ArtifactRegistry registry,
  ) {
    final restoredBack = registry.restore(card.back);
    final restoredFront = registry.restore(card.front);

    return PedagogicalCandidateCard(
      front: restoredFront,
      back: restoredBack,
      type: card.type,
      sourceTopic: card.sourceTopic,
      frontLatex: card.frontLatex,
      backLatex: card.backLatex,
      imageUrl: card.imageUrl,
      confidenceScore: card.confidenceScore,
    );
  }

  /// Finds the primary nominal subject in a dependency tree.
  DependencyNode? _findSubject(DependencyTree tree) {
    final root = tree.root;
    final nsubj = root.findFirstChild('nsubj') ?? root.findFirstChild('nsubjpass');
    if (nsubj != null) return nsubj;

    return tree.findFirstNodeByDeprel('nsubj') ?? tree.findFirstNodeByDeprel('nsubjpass');
  }

  /// Checks if a phrase is an anaphoric pronoun.
  bool _isAnaphora(String text) {
    final clean = text.trim().toLowerCase();
    if (_anaphoraBlacklist.contains(clean)) return true;
    final firstWord = clean.split(' ').first;
    return _anaphoraBlacklist.contains(firstWord);
  }

  /// Conjugates question stem: Why does S V O vs Why do S V O.
  String _conjugateInterrogative(
    String subjectText,
    bool isPlural,
    String verbLemma,
    String objectText, {
    required String prefix,
    required String pluralPrefix,
  }) {
    final p = isPlural ? pluralPrefix : prefix;
    final oPart = objectText.isNotEmpty ? ' $objectText' : '';
    return '$p $subjectText $verbLemma$oPart';
  }

  /// Prepends domain anchor prefix if question needs contextual disambiguation.
  String _resolveContextPrefix(String subject, String? headingContext, String documentContext) {
    final lowerSubject = subject.toLowerCase();
    final lowerDoc = documentContext.toLowerCase();

    if (lowerSubject.contains(lowerDoc) || lowerDoc == 'general') {
      return '';
    }

    if (headingContext != null && lowerSubject.contains(headingContext.toLowerCase())) {
      return '';
    }

    return 'In $documentContext, ';
  }
}
