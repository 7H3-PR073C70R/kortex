/// Two-tier hybrid synthesis modes for document-to-flashcard generation.
enum SynthesisMode {
  /// Tier 1: Fast, client-side deterministic parsing without external
  /// API calls (Free).
  fastLocal,

  /// Tier 2: Conceptual, multi-paragraph AI synthesis with deep reasoning
  /// (Pro/Advanced).
  aiSmart,
}

extension SynthesisModeX on SynthesisMode {
  bool get isFastLocal => this == SynthesisMode.fastLocal;
  bool get isAiSmart => this == SynthesisMode.aiSmart;

  String get label {
    switch (this) {
      case SynthesisMode.fastLocal:
        return 'Fast Local Extraction';
      case SynthesisMode.aiSmart:
        return 'AI Smart Synthesis';
    }
  }

  String get subtitle {
    switch (this) {
      case SynthesisMode.fastLocal:
        return 'Offline, instant deterministic rule-based cards';
      case SynthesisMode.aiSmart:
        return 'Deep conceptual multi-step synthesis with diagrams';
    }
  }
}
