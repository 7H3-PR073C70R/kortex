import 'dart:convert';
import 'dart:io';

/// A token node in a dependency tree.
class DependencyNode {
  DependencyNode({
    required this.id,
    required this.form,
    required this.lemma,
    required this.pos,
    this.headId = 0,
    this.deprel = 'dep',
  }) : children = [];

  final int id;
  final String form;
  final String lemma;
  final String pos;
  int headId;
  String deprel;
  final List<DependencyNode> children;

  /// Whether this node represents the virtual ROOT.
  bool get isRoot => id == 0;

  /// Returns all children matching a specific dependency relation.
  List<DependencyNode> getChildrenByDeprel(String label) {
    return children.where((c) => c.deprel == label).toList();
  }

  /// Returns the first child matching a specific dependency relation.
  DependencyNode? findFirstChild(String label) {
    for (final c in children) {
      if (c.deprel == label) return c;
    }
    return null;
  }

  /// Returns all nodes in this subtree, sorted in linear token order.
  List<DependencyNode> getSubtreeTokens() {
    final result = <DependencyNode>[this];
    for (final c in children) {
      result.addAll(c.getSubtreeTokens());
    }
    result.sort((a, b) => a.id.compareTo(b.id));
    return result;
  }

  /// Reconstructs the continuous text span covered by this subtree.
  String getSubtreeSpanText() {
    return getSubtreeTokens().map((n) => n.form).join(' ');
  }

  @override
  String toString() => '$form/$pos ($deprel -> $headId)';
}

/// A complete dependency tree for a sentence.
class DependencyTree {
  DependencyTree({
    required this.nodes,
    required this.sentence,
  }) {
    _buildHierarchy();
  }

  final List<DependencyNode> nodes;
  final String sentence;

  late final DependencyNode rootNode;

  void _buildHierarchy() {
    final nodeMap = {for (final n in nodes) n.id: n};
    for (final n in nodes) {
      if (n.id == 0) continue;
      final parent = nodeMap[n.headId];
      if (parent != null && parent.id != n.id) {
        if (!parent.children.contains(n)) {
          parent.children.add(n);
        }
      }
    }

    final rootCandidates = nodes.where((n) => n.id != 0 && (n.headId == 0 || n.deprel == 'root')).toList();
    DependencyNode? foundRoot;
    for (final cand in rootCandidates) {
      if (cand.pos.startsWith('VB')) {
        foundRoot = cand;
        break;
      }
    }
    foundRoot ??= (rootCandidates.isNotEmpty ? rootCandidates.first : null);

    rootNode = foundRoot ??
        (nodes.length > 1 ? nodes[1] : DependencyNode(id: 0, form: 'ROOT', lemma: 'root', pos: 'ROOT'));
  }

  /// Returns the root predicate of the sentence.
  DependencyNode get root => rootNode;

  /// Finds all nodes across the tree with the given dependency relation.
  List<DependencyNode> findNodesByDeprel(String label) {
    return nodes.where((n) => n.deprel == label).toList();
  }

  /// Finds the first node with the given dependency relation.
  DependencyNode? findFirstNodeByDeprel(String label) {
    for (final n in nodes) {
      if (n.deprel == label) return n;
    }
    return null;
  }

  /// Extracts contiguous surface text for nodes between [startId] and [endId].
  String getSpanText(int startId, int endId) {
    final sub = nodes.where((n) => n.id >= startId && n.id <= endId).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    return sub.map((n) => n.form).join(' ');
  }
}

/// Averaged Perceptron transition classifier.
class AveragedPerceptron {
  AveragedPerceptron({
    required this.weights,
    required this.biases,
    required this.posLexicon,
  });

  factory AveragedPerceptron.fromJson(Map<String, dynamic> json) {
    final rawWeights = json['weights'] as Map<String, dynamic>? ?? {};
    final parsedWeights = <String, Map<String, double>>{};

    for (final entry in rawWeights.entries) {
      if (entry.value is Map) {
        final innerMap = (entry.value as Map).map(
          (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
        );
        parsedWeights[entry.key] = innerMap;
      }
    }

    final rawBiases = json['biases'] as Map<String, dynamic>? ?? {};
    final parsedBiases = rawBiases.map(
      (k, v) => MapEntry(k, (v as num).toDouble()),
    );

    final rawLex = json['pos_lexicon'] as Map<String, dynamic>? ?? {};
    final parsedLex = rawLex.map((k, v) => MapEntry(k, v.toString()));

    return AveragedPerceptron(
      weights: parsedWeights,
      biases: parsedBiases,
      posLexicon: parsedLex,
    );
  }

  final Map<String, Map<String, double>> weights;
  final Map<String, double> biases;
  final Map<String, String> posLexicon;

  /// Scores candidate actions and returns the best valid one.
  String predict(List<String> features, Set<String> validActions) {
    var bestAction = validActions.first;
    var bestScore = -double.infinity;

    for (final action in validActions) {
      var score = biases[action] ?? 0.0;
      for (final f in features) {
        final fMap = weights[f];
        if (fMap != null) {
          score += fMap[action] ?? 0.0;
        }
      }
      if (score > bestScore) {
        bestScore = score;
        bestAction = action;
      }
    }

    return bestAction;
  }
}

/// Layer 2: Transition Parser Engine.
///
/// Implements an Arc-Standard Dependency Parser powered by a pre-compiled
/// Averaged Perceptron. Constructs a traversable [DependencyTree].
class TransitionParserEngine {
  TransitionParserEngine({AveragedPerceptron? model})
      : _model = model ?? _createDefaultModel();

  final AveragedPerceptron _model;

  static final TransitionParserEngine instance = TransitionParserEngine();

  /// Loads model weights from a JSON file path.
  static Future<TransitionParserEngine> loadFromFile(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      return TransitionParserEngine();
    }
    final content = await file.readAsString();
    final json = jsonDecode(content) as Map<String, dynamic>;
    return TransitionParserEngine(model: AveragedPerceptron.fromJson(json));
  }

  /// Parses an input sentence into a [DependencyTree].
  DependencyTree parse(String sentence) {
    final tokens = _tokenize(sentence);
    if (tokens.isEmpty) {
      return DependencyTree(nodes: [], sentence: sentence);
    }

    final nodes = <DependencyNode>[
      DependencyNode(id: 0, form: 'ROOT', lemma: 'root', pos: 'ROOT'),
    ];

    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      final pos = _tagPos(token, i, tokens);
      final lemma = _lemmatize(token, pos);
      nodes.add(
        DependencyNode(
          id: i + 1,
          form: token,
          lemma: lemma,
          pos: pos,
        ),
      );
    }

    // Arc-Standard parsing state
    final stack = <int>[0];
    final buffer = List<int>.generate(tokens.length, (i) => i + 1);
    final arcs = <int, (int, String)>{};

    var iterations = 0;
    final maxIterations = tokens.length * 4;

    while (buffer.isNotEmpty || stack.length > 1) {
      if (iterations++ > maxIterations) {
        // Fallback: attach remaining stack nodes to ROOT
        while (stack.length > 1) {
          final s0 = stack.removeLast();
          arcs[s0] = (stack.last, 'dep');
        }
        break;
      }

      final validActions = <String>{};
      if (buffer.isNotEmpty) {
        validActions.add('SHIFT');
      }

      final s0Node = nodes[stack.last];
      final s1Node = stack.length >= 2 ? nodes[stack[stack.length - 2]] : null;
      final b0Node = buffer.isNotEmpty ? nodes[buffer.first] : null;

      final canLeftArc = stack.length >= 2 && stack[stack.length - 2] != 0;
      final canRightArc = stack.length >= 2;

      if (canLeftArc && s1Node != null) {
        if ((s1Node.pos.startsWith('NN') || s1Node.pos == 'PRP') &&
            s0Node.pos.startsWith('VB')) {
          validActions.add('LEFT_ARC:nsubj');
        }
        if (s1Node.pos == 'DT') {
          validActions.add('LEFT_ARC:det');
        }
        if (s1Node.pos == 'JJ' || s1Node.pos == 'CD') {
          validActions.add('LEFT_ARC:amod');
        }
        if (s1Node.pos.startsWith('NN') && s0Node.pos.startsWith('NN')) {
          validActions.add('LEFT_ARC:compound');
        }
      }

      if (canRightArc && s1Node != null) {
        if (s1Node.id == 0) {
          // In Arc-Standard, ROOT cannot reduce until all buffer tokens are processed
          if (buffer.isEmpty) {
            validActions.add('RIGHT_ARC:root');
          }
        } else {
          if (s1Node.pos.startsWith('VB') &&
              (s0Node.pos.startsWith('NN') || s0Node.pos == 'PRP')) {
            if (b0Node == null || !b0Node.pos.startsWith('NN')) {
              validActions.add('RIGHT_ARC:dobj');
            }
          }
          if ((s1Node.pos.startsWith('VB') || s1Node.pos.startsWith('NN')) &&
              s0Node.pos == 'IN') {
            validActions.add('RIGHT_ARC:prep');
          }
          if (s1Node.pos == 'IN' &&
              (s0Node.pos.startsWith('NN') || s0Node.pos == 'VBG')) {
            validActions.add('RIGHT_ARC:pobj');
          }
          if (s1Node.pos.startsWith('VB') && s0Node.pos == 'VBG') {
            validActions.add('RIGHT_ARC:advcl');
          }
        }
      }

      if (validActions.isEmpty) {
        if (buffer.isNotEmpty) {
          validActions.add('SHIFT');
        } else if (stack.length >= 2) {
          validActions.add('RIGHT_ARC:root');
        } else {
          break;
        }
      }

      final features = _extractFeatures(s0Node, s1Node, b0Node);
      final action = _model.predict(features, validActions);

      if (action == 'SHIFT') {
        stack.add(buffer.removeAt(0));
      } else if (action.startsWith('LEFT_ARC:')) {
        final label = action.split(':').last;
        final s0 = stack.last;
        final s1 = stack[stack.length - 2];
        arcs[s1] = (s0, label);
        stack.removeAt(stack.length - 2);
      } else if (action.startsWith('RIGHT_ARC:')) {
        final label = action.split(':').last;
        final s0 = stack.removeLast();
        final s1 = stack.last;
        arcs[s0] = (s1, label);
      } else {
        // Fallback default
        if (buffer.isNotEmpty) {
          stack.add(buffer.removeAt(0));
        } else if (stack.length >= 2) {
          final s0 = stack.removeLast();
          arcs[s0] = (stack.last, 'dep');
        } else {
          break;
        }
      }
    }

    // Assign heads and relation labels
    for (final entry in arcs.entries) {
      final childId = entry.key;
      final (headId, label) = entry.value;
      if (childId > 0 && childId < nodes.length) {
        nodes[childId].headId = headId;
        nodes[childId].deprel = label;
      }
    }

    return DependencyTree(nodes: nodes, sentence: sentence);
  }

  /// Extracts features for the current configuration.
  List<String> _extractFeatures(
    DependencyNode s0,
    DependencyNode? s1,
    DependencyNode? b0,
  ) {
    final features = <String>[
      's0_p:${s0.pos}',
      's0_w:${s0.lemma}',
    ];

    if (s1 != null) {
      features.addAll([
        's1_p:${s1.pos}',
        's1_w:${s1.lemma}',
        's1_p:${s1.pos},s0_p:${s0.pos}',
      ]);
    }

    if (b0 != null) {
      features.addAll([
        'b0_p:${b0.pos}',
        'b0_w:${b0.lemma}',
        's0_p:${s0.pos},b0_p:${b0.pos}',
      ]);
    }

    return features;
  }

  /// Tokenizes a sentence into lexical tokens.
  List<String> _tokenize(String sentence) {
    final normalized = sentence
        .replaceAll(RegExp(r"([.,!?;:\(\)\[\]\{\}'’“”])"), r' $1 ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (normalized.isEmpty) return [];
    return normalized.split(' ').where((t) => t.isNotEmpty).toList();
  }

  /// Tags Part of Speech for a token.
  String _tagPos(String token, int index, List<String> context) {
    final lower = token.toLowerCase();

    // Check pre-compiled POS lexicon
    final lex = _model.posLexicon[lower];
    if (lex != null) return lex;

    // Artifact placeholder tags
    if (token.startsWith('__CODE_REF_') ||
        token.startsWith('__MATH_REF_') ||
        token.startsWith('__IMG_REF_')) {
      return 'NNP';
    }

    // Punctuation
    if (RegExp(r'^[.,!?;:\(\)\[\]\{\}]$').hasMatch(token)) {
      return 'PUNCT';
    }

    // Numbers
    if (RegExp(r'^\d+(\.\d+)?$').hasMatch(token)) {
      return 'CD';
    }

    // Proper Nouns (capitalized and not first word)
    if (index > 0 && RegExp(r'^[A-Z][a-zA-Z0-9_]*$').hasMatch(token)) {
      return 'NNP';
    }

    // Morphological heuristics
    if (lower.endsWith('ing')) return 'VBG';
    if (lower.endsWith('ed')) return 'VBD';
    if (lower.endsWith('ly')) return 'RB';
    if (lower.endsWith('ous') || lower.endsWith('ive') || lower.endsWith('ful') || lower.endsWith('able')) {
      return 'JJ';
    }
    if (lower.endsWith('tion') || lower.endsWith('sion') || lower.endsWith('ment') || lower.endsWith('ness')) {
      return 'NN';
    }
    if (lower.endsWith('s') &&
        !lower.endsWith('ss') &&
        !lower.endsWith('is') &&
        !lower.endsWith('us') &&
        !lower.endsWith('as')) {
      // Third-person verb vs Plural noun heuristic
      if (index > 0) {
        final prev = context[index - 1].toLowerCase();
        if (['he', 'she', 'it'].contains(prev)) {
          return 'VBZ';
        }
      }
      return 'NNS';
    }

    return 'NN';
  }

  /// Lemmatizes regular English words.
  String _lemmatize(String token, String pos) {
    final lower = token.toLowerCase();
    if (pos == 'VBZ') {
      if (lower.endsWith('ies')) return '${lower.substring(0, lower.length - 3)}y';
      if (RegExp(r'(ss|sh|ch|x|z)es$').hasMatch(lower)) {
        return lower.substring(0, lower.length - 2);
      }
      if (lower.endsWith('s')) return lower.substring(0, lower.length - 1);
    }
    if (pos == 'NNS' && lower.endsWith('s')) {
      if (lower.endsWith('ies')) return '${lower.substring(0, lower.length - 3)}y';
      return lower.substring(0, lower.length - 1);
    }
    return lower;
  }

  static AveragedPerceptron _createDefaultModel() {
    return AveragedPerceptron(
      weights: {
        's0_p:DT': {'SHIFT': 3.0},
        's0_p:JJ': {'SHIFT': 2.5},
        's1_p:DT,s0_p:NN': {'LEFT_ARC:det': 4.0},
        's1_p:DT,s0_p:NNS': {'LEFT_ARC:det': 4.0},
        's1_p:DT,s0_p:NNP': {'LEFT_ARC:det': 4.0},
        's1_p:JJ,s0_p:NN': {'LEFT_ARC:amod': 3.5},
        's1_p:JJ,s0_p:NNS': {'LEFT_ARC:amod': 3.5},
        's1_p:NN,s0_p:NN': {'LEFT_ARC:compound': 3.0},
        's1_p:NN,s0_p:VBZ': {'LEFT_ARC:nsubj': 4.5},
        's1_p:NNS,s0_p:VBP': {'LEFT_ARC:nsubj': 4.5},
        's1_p:NNP,s0_p:VBZ': {'LEFT_ARC:nsubj': 4.5},
        's1_p:PRP,s0_p:VBZ': {'LEFT_ARC:nsubj': 4.5},
        's1_p:VBG,s0_p:VBZ': {'LEFT_ARC:nsubj': 4.0},
        's1_p:VBZ,s0_p:NN': {'RIGHT_ARC:dobj': 3.5},
        's1_p:VBZ,s0_p:NNS': {'RIGHT_ARC:dobj': 3.5},
        's1_p:VBP,s0_p:NN': {'RIGHT_ARC:dobj': 3.5},
        's1_p:VBP,s0_p:NNS': {'RIGHT_ARC:dobj': 3.5},
        's1_p:VBZ,s0_p:IN': {'RIGHT_ARC:prep': 3.0},
        's1_p:VBP,s0_p:IN': {'RIGHT_ARC:prep': 3.0},
        's1_p:VBN,s0_p:IN': {'RIGHT_ARC:prep': 3.0},
        's1_p:IN,s0_p:NN': {'RIGHT_ARC:pobj': 4.0},
        's1_p:IN,s0_p:NNS': {'RIGHT_ARC:pobj': 4.0},
        's1_p:IN,s0_p:NNP': {'RIGHT_ARC:pobj': 4.0},
        's1_p:IN,s0_p:VBG': {'RIGHT_ARC:pobj': 3.5},
        's0_w:because': {'RIGHT_ARC:advcl': 3.0},
        's0_w:when': {'RIGHT_ARC:advcl': 3.0},
        's1_p:ROOT,s0_p:VBZ': {'RIGHT_ARC:root': 5.0},
        's1_p:ROOT,s0_p:VBP': {'RIGHT_ARC:root': 5.0},
        's1_p:ROOT,s0_p:VBD': {'RIGHT_ARC:root': 5.0},
      },
      biases: {
        'SHIFT': 0.5,
        'RIGHT_ARC:root': 2.0,
        'LEFT_ARC:nsubj': 2.5,
        'LEFT_ARC:nsubjpass': 2.2,
        'RIGHT_ARC:dobj': 2.0,
        'RIGHT_ARC:prep': 1.8,
        'RIGHT_ARC:pobj': 2.2,
        'RIGHT_ARC:advcl': 1.9,
        'LEFT_ARC:det': 2.8,
        'LEFT_ARC:amod': 2.6,
        'LEFT_ARC:compound': 2.4,
        'RIGHT_ARC:cop': 2.0,
        'RIGHT_ARC:aux': 2.0,
      },
      posLexicon: {
        'is': 'VBZ',
        'are': 'VBP',
        'was': 'VBD',
        'were': 'VBD',
        'has': 'VBZ',
        'have': 'VBP',
        'had': 'VBD',
        'do': 'VBP',
        'does': 'VBZ',
        'did': 'VBD',
        'can': 'MD',
        'will': 'MD',
        'should': 'MD',
        'must': 'MD',
        'consume': 'VBP',
        'consumes': 'VBZ',
        'catalyze': 'VBP',
        'catalyzes': 'VBZ',
        'compile': 'VBP',
        'compiles': 'VBZ',
        'split': 'VBP',
        'splits': 'VBZ',
        'convert': 'VBP',
        'converts': 'VBZ',
        'produce': 'VBP',
        'produces': 'VBZ',
        'yield': 'VBP',
        'yields': 'VBZ',
        'cells': 'NNS',
        'code': 'NN',
        'compiler': 'NN',
        'state': 'NN',
        'timers': 'NNS',
        'streams': 'NNS',
        'manages': 'VBZ',
        'requires': 'VBZ',
        'allows': 'VBZ',
        'takes': 'VBZ',
        'occurs': 'VBZ',
        'cancels': 'VBZ',
        'closes': 'VBZ',
        'calling': 'VBG',
        'invoking': 'VBG',
        'using': 'VBG',
        'the': 'DT',
        'a': 'DT',
        'an': 'DT',
        'one': 'CD',
        'two': 'CD',
        'three': 'CD',
        'this': 'DT',
        'that': 'DT',
        'these': 'DT',
        'those': 'DT',
        'in': 'IN',
        'on': 'IN',
        'at': 'IN',
        'by': 'IN',
        'with': 'IN',
        'from': 'IN',
        'into': 'IN',
        'via': 'IN',
        'through': 'IN',
        'because': 'IN',
        'since': 'IN',
        'when': 'IN',
        'while': 'IN',
        'and': 'CC',
        'or': 'CC',
        'but': 'CC',
      },
    );
  }
}
