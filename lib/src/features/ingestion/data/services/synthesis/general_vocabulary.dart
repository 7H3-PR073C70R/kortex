/// Everyday English vocabulary that carries little study value on its own.
///
/// Used by the offline synthesizer to tell domain concepts ("glycolysis",
/// "StableRef", "suspending functions") apart from words any reader already
/// knows ("important", "check", "specified"). A word in this list can still be
/// part of a concept phrase ("relative paths"), but is never a concept alone.
class GeneralVocabulary {
  const GeneralVocabulary._();

  /// Articles, pronouns, prepositions, conjunctions, auxiliaries, determiners.
  static bool isFunctionWord(String word) =>
      _functionWords.contains(word.toLowerCase());

  /// Whether [word] (any inflection) is a common verb such as "use", "makes",
  /// "allowed" or "checking".
  static bool isCommonVerb(String word) {
    final lower = word.toLowerCase();
    return _verbs.contains(lower) || _lemmas(lower).any(_verbs.contains);
  }

  /// Whether [word] is a common verb in base or third-person form only
  /// ("check", "checks"), i.e. not a participle that can modify a noun.
  static bool isFiniteCommonVerb(String word) {
    final lower = word.toLowerCase();
    if (lower.endsWith('ing') || lower.endsWith('ed')) return false;
    if (_verbs.contains(lower)) return true;
    if (lower.endsWith('ies') && _verbs.contains('${lower.substring(0, lower.length - 3)}y')) return true;
    if (lower.endsWith('es') && _verbs.contains(lower.substring(0, lower.length - 2))) return true;
    return lower.endsWith('s') && _verbs.contains(lower.substring(0, lower.length - 1));
  }

  /// Whether [word] (any inflection) can act as a verb, including technical
  /// and scientific verbs that are also nouns ("map", "cache", "transport").
  ///
  /// Only for detecting whether a sentence has a predicate; unlike
  /// [isCommonVerb] it must not be used to split noun phrases.
  static bool looksLikeVerb(String word) {
    final lower = word.toLowerCase();
    if (isCommonVerb(lower)) return true;
    return _predicateVerbs.contains(lower) || _lemmas(lower).any(_predicateVerbs.contains);
  }

  /// Whether [word] is an adverb ("simultaneously", "often", "also").
  static bool isAdverb(String word) {
    final lower = word.toLowerCase();
    if (_adverbs.contains(lower)) return true;
    return lower.length > 5 && lower.endsWith('ly') && !_lyNouns.contains(lower);
  }

  /// Whether [word] is a common adjective ("important", "specific", "new").
  static bool isCommonAdjective(String word) =>
      _adjectives.contains(word.toLowerCase());

  /// Whether [word] is a generic noun ("thing", "way", "example", "developers").
  static bool isGenericNoun(String word) {
    final lower = word.toLowerCase();
    return _nouns.contains(lower) || _lemmas(lower).any(_nouns.contains);
  }

  /// Whether [word] is everyday vocabulary of any kind.
  static bool isGeneral(String word) {
    final lower = word.toLowerCase();
    return isFunctionWord(lower) ||
        isCommonVerb(lower) ||
        isAdverb(lower) ||
        isCommonAdjective(lower) ||
        isGenericNoun(lower);
  }

  /// Candidate dictionary forms for a possibly inflected [lower]-case word.
  static Iterable<String> _lemmas(String lower) sync* {
    final n = lower.length;
    if (n <= 3) return;
    if (lower.endsWith('ies')) yield '${lower.substring(0, n - 3)}y';
    if (lower.endsWith('es')) yield lower.substring(0, n - 2);
    if (lower.endsWith('s') && !lower.endsWith('ss')) yield lower.substring(0, n - 1);
    if (lower.endsWith('ied')) yield '${lower.substring(0, n - 3)}y';
    if (lower.endsWith('ed')) {
      yield lower.substring(0, n - 2);
      yield lower.substring(0, n - 1);
      if (n > 5 && lower[n - 3] == lower[n - 4]) yield lower.substring(0, n - 3);
    }
    if (lower.endsWith('ing') && n >= 5) {
      final stem = lower.substring(0, n - 3);
      yield stem;
      yield '${stem}e';
      if (stem.length > 2 && stem[stem.length - 1] == stem[stem.length - 2]) {
        yield stem.substring(0, stem.length - 1);
      }
    }
  }

  static const _lyNouns = {'family', 'assembly', 'anomaly', 'butterfly', 'monopoly', 'supply', 'reply', 'apply', 'rely', 'multiply', 'italy', 'july'};

  static const _functionWords = {
    'a', 'an', 'the', 'this', 'that', 'these', 'those', 'such',
    'i', 'me', 'my', 'mine', 'we', 'us', 'our', 'ours', 'you', 'your', 'yours',
    'he', 'him', 'his', 'she', 'her', 'hers', 'it', 'its', 'they', 'them',
    'their', 'theirs', 'one', 'ones', 'oneself', 'itself', 'themselves',
    'yourself', 'yourselves', 'ourselves', 'myself', 'himself', 'herself',
    'who', 'whom', 'whose', 'which', 'what', 'whatever', 'whichever', 'whoever',
    'where', 'when', 'why', 'how', 'whether', 'wherever', 'whenever', 'however',
    'and', 'or', 'but', 'nor', 'so', 'yet', 'for', 'if', 'then', 'else',
    'than', 'because', 'although', 'though', 'while', 'whereas', 'unless',
    'until', 'since', 'once', 'as', 'like', 'unlike',
    'of', 'in', 'on', 'at', 'by', 'to', 'from', 'with', 'without', 'within',
    'into', 'onto', 'upon', 'over', 'under', 'above', 'below', 'between',
    'among', 'through', 'throughout', 'during', 'before', 'after', 'about',
    'against', 'along', 'around', 'across', 'behind', 'beside', 'besides',
    'beyond', 'despite', 'except', 'inside', 'outside', 'per', 'via', 'toward',
    'towards', 'versus', 'vs', 'off', 'out', 'up', 'down', 'near',
    'is', 'are', 'was', 'were', 'be', 'been', 'being', 'am',
    'has', 'have', 'had', 'having', 'do', 'does', 'did', 'done', 'doing',
    'can', 'cannot', 'could', 'will', 'would', 'shall', 'should', 'may',
    'might', 'must', 'ought', 'need', 'needs',
    'all', 'any', 'each', 'every', 'either', 'neither', 'both', 'some', 'many',
    'much', 'more', 'most', 'few', 'fewer', 'less', 'least', 'several', 'other',
    'others', 'another', 'own', 'same', 'no', 'not', 'none', 'nothing',
    'something', 'anything', 'everything', 'someone', 'anyone', 'everyone',
    'nobody', 'somebody', 'anybody', 'everybody', 'somewhere', 'anywhere',
    'everywhere', 'nowhere', 'there', 'here', 'yes', 'okay', 'ok',
    'also', 'too', 'very', 'just', 'only', 'even', 'still', 'already', 'again',
    'ever', 'never', 'always', 'often', 'sometimes', 'usually', 'now', 'well',
    'thus', 'hence', 'therefore', 'moreover', 'furthermore', 'otherwise',
    'instead', 'rather', 'quite', 'almost', 'enough', 'perhaps', 'maybe',
    'etc', 'eg', 'ie', 
  };

  static const _adverbs = {
    'again', 'ago', 'ahead', 'alike', 'alone', 'along', 'already', 'also',
    'altogether', 'always', 'anyway', 'apart', 'around', 'away', 'back',
    'below', 'besides', 'down', 'else', 'elsewhere', 'enough', 'even', 'ever',
    'fast', 'first', 'forth', 'forward', 'further', 'hard', 'here', 'later',
    'least', 'less', 'likewise', 'meanwhile', 'more', 'most', 'much', 'never',
    'next', 'nonetheless', 'nevertheless', 'now', 'often', 'once', 'otherwise',
    'perhaps', 'quite', 'rather', 'regardless', 'second', 'so', 'soon', 'still',
    'then', 'there', 'thereby', 'therein', 'though', 'today', 'together', 'too',
    'twice', 'up', 'very', 'well', 'yet', 'instead', 'indeed', 'thus', 'hence',
    'similarly', 'additionally', 'currently', 'finally', 'firstly', 'lastly',
    'secondly', 'simply', 'basically', 'essentially', 'generally', 'typically',
    'usually', 'actually', 'really', 'probably', 'possibly', 'certainly',
    'clearly', 'obviously', 'especially', 'particularly', 'specifically',
    'mostly', 'mainly', 'merely', 'nearly', 'only', 'exactly', 'directly',
  };

  static const _verbs = {
    'accept', 'access', 'accomplish', 'account', 'achieve', 'act', 'adapt',
    'add', 'address', 'adjust', 'adopt', 'affect', 'agree', 'aim', 'allow',
    'alter', 'analyze', 'analyse', 'answer', 'appear', 'apply', 'approach',
    'argue', 'arise', 'arrange', 'ask', 'assess', 'assign', 'assist', 'assume',
    'attach', 'attempt', 'attend', 'avoid', 'base', 'become', 'begin', 'believe',
    'belong', 'benefit', 'bind', 'break', 'bring', 'build', 'call', 'care',
    'carry', 'catch', 'cause', 'change', 'check', 'choose', 'claim', 'clarify',
    'clean', 'clear', 'click', 'close', 'collect', 'combine', 'come', 'compare',
    'complete', 'concern', 'conclude', 'confirm', 'connect', 'consider',
    'consist', 'contain', 'continue', 'contribute', 'control', 'convert',
    'copy', 'correct', 'cost', 'count', 'cover', 'create', 'cut', 'deal',
    'decide', 'declare', 'decrease', 'define', 'delay', 'delete', 'deliver',
    'demonstrate', 'depend', 'derive', 'describe', 'design', 'determine',
    'develop', 'differ', 'discover', 'discuss', 'display', 'distinguish',
    'divide', 'drive', 'drop', 'earn', 'ease', 'emerge', 'emphasize', 'enable',
    'encourage', 'end', 'ensure', 'enter', 'establish', 'evaluate', 'examine',
    'exceed', 'exist', 'expand', 'expect', 'experience', 'explain', 'explore',
    'express', 'extend', 'face', 'fail', 'fall', 'feel', 'fill', 'find',
    'finish', 'fit', 'fix', 'focus', 'follow', 'forget', 'form', 'gain', 'get',
    'give', 'go', 'grow', 'guarantee', 'guide', 'handle', 'happen', 'hear',
    'help', 'hide', 'highlight', 'hold', 'hope', 'identify', 'ignore',
    'illustrate', 'imagine', 'implement', 'imply', 'improve', 'include',
    'increase', 'indicate', 'influence', 'inform', 'insert', 'install',
    'intend', 'introduce', 'investigate', 'involve', 'join', 'keep', 'know',
    'lack', 'last', 'lead', 'learn', 'leave', 'let', 'lie', 'limit', 'link',
    'list', 'listen', 'live', 'load', 'look', 'lose', 'love', 'maintain',
    'make', 'manage', 'mark', 'match', 'matter', 'mean', 'meet', 'mention',
    'miss', 'modify', 'move', 'name', 'note', 'notice', 'obtain', 'occur',
    'offer', 'open', 'operate', 'organize', 'own', 'pass', 'pay', 'perform',
    'pick', 'place', 'plan', 'play', 'point', 'prefer', 'prepare', 'present',
    'prevent', 'print', 'proceed', 'produce', 'promote', 'protect', 'prove',
    'provide', 'publish', 'pull', 'push', 'put', 'raise', 'reach', 'read',
    'realize', 'receive', 'recognize', 'recommend', 'reduce', 'refer',
    'reflect', 'regard', 'relate', 'release', 'rely', 'remain', 'remember',
    'remove', 'repeat', 'replace', 'report', 'represent', 'require', 'reset',
    'resolve', 'respond', 'rest', 'restrict', 'result', 'retain', 'return',
    'reveal', 'review', 'rise', 'run', 'save', 'say', 'see', 'seek', 'seem',
    'select', 'send', 'separate', 'serve', 'set', 'share', 'show', 'sign',
    'simplify', 'sit', 'solve', 'sort', 'speak', 'specify', 'spend', 'spread',
    'stand', 'start', 'state', 'stay', 'step', 'stop', 'store', 'strengthen',
    'struggle', 'study', 'submit', 'succeed', 'suffer', 'suggest', 'suit',
    'supply', 'support', 'suppose', 'surround', 'switch', 'take', 'talk',
    'teach', 'tell', 'tend', 'test', 'think', 'touch', 'track', 'treat', 'try',
    'turn', 'understand', 'update', 'use', 'utilize', 'vary', 'verify', 'view',
    'visit', 'wait', 'walk', 'want', 'watch', 'wish', 'wonder', 'work', 'worry',
    'write', 'yield',
  };

  static const _predicateVerbs = {
    'absorb', 'activate', 'allocate', 'assign', 'bind', 'cache', 'calculate',
    'call', 'catalyze', 'compile', 'comprise', 'compute', 'consume', 'convert',
    'decode', 'depolarize', 'dispatch', 'emit', 'encode', 'evaluate', 'execute',
    'expose', 'export', 'fetch', 'filter', 'flow', 'generate', 'hold', 'import',
    'inherit', 'inhibit', 'inject', 'invoke', 'launch', 'map', 'measure',
    'merge', 'notify', 'observe', 'override', 'oxidize', 'parse', 'persist',
    'propagate', 'query', 'register', 'regulate', 'render', 'reside', 'resume',
    'schedule', 'serialize', 'split', 'subscribe', 'suspend', 'synthesize',
    'throw', 'transform', 'transmit', 'transport', 'trigger', 'validate', 'wrap',
    'accelerate', 'bond', 'carry', 'catch', 'collapse', 'combine', 'decay',
    'decline', 'diffuse', 'emerge', 'enforce', 'exhibit', 'govern', 'hydrolyze',
    'interact', 'migrate', 'mutate', 'orbit', 'react', 'recycle', 'replicate',
    'reproduce', 'rotate', 'scale', 'secrete', 'sense', 'shift', 'shrink',
    'signal', 'store', 'translate', 'transcribe', 'travel', 'unwind', 'vibrate',
  };

  static const _adjectives = {
    'able', 'actual', 'additional', 'advanced', 'available', 'aware', 'bad',
    'basic', 'beautiful', 'best', 'better', 'big', 'brief', 'broad', 'certain',
    'cheap', 'clean', 'clear', 'close', 'common', 'complete', 'complex',
    'considerable', 'correct', 'crucial', 'current', 'different', 'difficult',
    'direct', 'due', 'early', 'easy', 'easier', 'effective', 'efficient',
    'entire', 'equal', 'essential', 'exact', 'excellent', 'existing', 'extra',
    'fair', 'familiar', 'fast', 'final', 'fine', 'first', 'following',
    'former', 'free', 'frequent', 'full', 'fundamental', 'further', 'general',
    'given', 'good', 'great', 'greater', 'happy', 'hard', 'harder', 'helpful',
    'high', 'higher', 'huge', 'ideal', 'important', 'impossible', 'interesting',
    'key', 'large', 'larger', 'last', 'late', 'latest', 'least', 'left',
    'like', 'likely', 'little', 'long', 'longer', 'low', 'lower', 'main',
    'major', 'many', 'minor', 'modern', 'more', 'most', 'multiple', 'necessary',
    'new', 'newer', 'next', 'nice', 'normal', 'obvious', 'old', 'older',
    'open', 'optional', 'ordinary', 'original', 'other', 'overall',
    'particular', 'perfect', 'possible', 'potential', 'powerful', 'practical',
    'present', 'previous', 'primary', 'prior', 'proper', 'quick', 'rare',
    'ready', 'real', 'recent', 'regular', 'relevant', 'reliable', 'remaining',
    'required', 'responsible', 'right', 'rich', 'robust', 'same', 'secondary',
    'separate', 'serious', 'short', 'significant', 'similar', 'simple',
    'single', 'slow', 'small', 'smaller', 'smooth', 'special', 'specific',
    'specified', 'stable', 'standard', 'strong', 'subsequent', 'successful',
    'sufficient', 'suitable', 'sure', 'true', 'typical', 'unique', 'unknown',
    'unnecessary', 'useful', 'usual', 'valid', 'valuable', 'various', 'vast',
    'versatile', 'vital', 'whole', 'wide', 'wrong', 'well-known', 'well-defined',
    'well-structured', 'well-designed', 'up-to-date', 'built-in',
  };

  static const _nouns = {
    'ability', 'access', 'action', 'activity', 'addition', 'advantage',
    'aim', 'amount', 'answer', 'approach', 'area', 'article', 'aspect',
    'attention', 'author', 'background', 'balance', 'basis', 'benefit', 'bit',
    'book', 'case', 'cause', 'challenge', 'chance', 'change', 'chapter',
    'choice', 'concept', 'condition', 'consequence', 'context', 'course',
    'detail', 'developer', 'difference', 'difficulty', 'direction', 'effect',
    'effort', 'element', 'end', 'example', 'experience', 'extent', 'fact',
    'factor', 'feature', 'field', 'focus', 'form', 'goal', 'group', 'guide',
    'hand', 'help', 'idea', 'impact', 'importance', 'information', 'instance',
    'issue', 'item', 'journey', 'kind', 'knowledge', 'lack', 'level', 'life',
    'line', 'look', 'lot', 'manner', 'matter', 'means', 'meaning', 'method',
    'moment', 'need', 'note', 'number', 'option', 'order', 'outcome', 'part',
    'people', 'person', 'piece', 'place', 'point', 'portion', 'position',
    'possibility', 'practice', 'problem', 'purpose', 'quality', 'question',
    'range', 'rate', 'reader', 'reason', 'regard', 'result', 'role', 'rule',
    'scenario', 'section', 'sense', 'series', 'set', 'side', 'situation',
    'size', 'solution', 'sort', 'source', 'space', 'stage', 'start', 'step',
    'story', 'stuff', 'success', 'support', 'term', 'thing', 'time', 'tip',
    'topic', 'total', 'tutorial', 'type', 'understanding', 'use', 'user',
    'value', 'variety', 'version', 'view', 'way', 'word', 'work', 'world',
    'year', 'day', 'today', 'everything', 'anything', 'something', 'nothing',
  };
}
