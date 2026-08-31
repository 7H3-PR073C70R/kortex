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
