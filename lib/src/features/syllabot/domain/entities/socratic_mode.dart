/// Socratic reasoning mode selected by the student.
enum SocraticMode {
  stepByStep,
  directAnswer,
  examSim,
  deepResearch,
}

extension SocraticModeX on SocraticMode {
  String get nameString {
    switch (this) {
      case SocraticMode.stepByStep:
        return 'stepByStep';
      case SocraticMode.directAnswer:
        return 'directAnswer';
      case SocraticMode.examSim:
        return 'examSim';
      case SocraticMode.deepResearch:
        return 'deepResearch';
    }
  }

  String get label {
    switch (this) {
      case SocraticMode.stepByStep:
        return 'Step-by-Step Proof';
      case SocraticMode.directAnswer:
        return 'Direct Answer';
      case SocraticMode.examSim:
        return 'Exam Simulator';
      case SocraticMode.deepResearch:
        return 'Deep Research';
    }
  }

  String get description {
    switch (this) {
      case SocraticMode.stepByStep:
        return 'Walk through the problem step-by-step from first principles';
      case SocraticMode.directAnswer:
        return 'Get a concise, comprehensive answer immediately';
      case SocraticMode.examSim:
        return 'Simulate an exam scenario with mark breakdowns';
      case SocraticMode.deepResearch:
        return 'Explore deep theoretical proofs and edge cases';
    }
  }

  static SocraticMode fromString(String value) {
    switch (value) {
      case 'directAnswer':
        return SocraticMode.directAnswer;
      case 'examSim':
        return SocraticMode.examSim;
      case 'deepResearch':
        return SocraticMode.deepResearch;
      case 'stepByStep':
      default:
        return SocraticMode.stepByStep;
    }
  }
}
