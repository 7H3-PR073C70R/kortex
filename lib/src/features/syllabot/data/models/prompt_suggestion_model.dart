import 'package:kortex/src/features/onboarding_calibration/domain/entities/calibration_profile.dart';

/// Represents a quick-start prompt suggestion shown in Syllabot empty state.
class PromptSuggestionModel {
  const PromptSuggestionModel({
    required this.text,
    required this.icon,
    required this.category,
  });

  final String text;
  final String icon;
  final String category;

  static List<PromptSuggestionModel> forProfile(CalibrationProfile? profile) {
    if (profile == null) return defaults;

    // High School / Exam Tracks
    if (profile.focus == AcademicFocus.highSchool) {
      final exam = profile.highSchoolExam?.toLowerCase() ?? '';

      if (exam.contains('jamb') || exam.contains('utme')) {
        return const [
          PromptSuggestionModel(
            text: 'Solve electric field and Coulomb\'s law JAMB past question',
            icon: '⚡',
            category: 'JAMB Physics',
          ),
          PromptSuggestionModel(
            text: 'Explain redox reactions and oxidation states for UTME',
            icon: '🧪',
            category: 'UTME Chemistry',
          ),
          PromptSuggestionModel(
            text: 'Break down Mendelian genetics and Punnett squares',
            icon: '🧬',
            category: 'JAMB Biology',
          ),
          PromptSuggestionModel(
            text:
                'Analyze antonyms and sentence interpretation for JAMB English',
            icon: '📖',
            category: 'JAMB English',
          ),
        ];
      }

      if (exam.contains('waec') || exam.contains('neco')) {
        return const [
          PromptSuggestionModel(
            text:
                'Prove circle theorem: angle at center is twice circumference',
            icon: '📐',
            category: 'WAEC Mathematics',
          ),
          PromptSuggestionModel(
            text:
                'Calculate terminal voltage and internal resistance of a cell',
            icon: '🔋',
            category: 'WAEC Physics',
          ),
          PromptSuggestionModel(
            text: 'Balance organic esterification reaction mechanisms',
            icon: '🧪',
            category: 'WAEC Chemistry',
          ),
          PromptSuggestionModel(
            text: 'Explain phototropism and auxin concentration in plants',
            icon: '🌿',
            category: 'WAEC Biology',
          ),
        ];
      }

      if (exam.contains('sat') || exam.contains('digital')) {
        return const [
          PromptSuggestionModel(
            text: 'Solve system of non-linear equations for SAT Math module 2',
            icon: '📈',
            category: 'Digital SAT Math',
          ),
          PromptSuggestionModel(
            text: 'Break down evidence-based reading passages & rhetoric craft',
            icon: '📚',
            category: 'SAT Reading',
          ),
          PromptSuggestionModel(
            text: 'Master circle equations and trigonometric ratios for SAT',
            icon: '📐',
            category: 'SAT Geometry',
          ),
          PromptSuggestionModel(
            text: 'Transition words and punctuation boundaries for SAT Writing',
            icon: '✏️',
            category: 'SAT Writing',
          ),
        ];
      }
    }

    // Higher Education Fields
    final field = profile.higherEdField?.toLowerCase() ?? '';

    if (field.contains('health') ||
        field.contains('med') ||
        field.contains('bio')) {
      return const [
        PromptSuggestionModel(
          text: 'Explain cellular respiration pathways and ATP yields',
          icon: '🧬',
          category: 'Biochemistry',
        ),
        PromptSuggestionModel(
          text: 'Derive the Michaelis-Menten enzyme kinetics equation',
          icon: '🔬',
          category: 'Pharmacology',
        ),
        PromptSuggestionModel(
          text: 'Differentiate Gram-positive and Gram-negative bacterial walls',
          icon: '🦠',
          category: 'Microbiology',
        ),
        PromptSuggestionModel(
          text: 'Analyze cardiovascular action potentials and ion channels',
          icon: '❤️',
          category: 'Physiology',
        ),
      ];
    }

    if (field.contains('law') || field.contains('legal')) {
      return const [
        PromptSuggestionModel(
          text:
              'Explain the doctrine of stare decisis with landmark precedents',
          icon: '⚖️',
          category: 'Jurisprudence',
        ),
        PromptSuggestionModel(
          text: 'Analyze offer, acceptance, and consideration in contract law',
          icon: '📜',
          category: 'Contract Law',
        ),
        PromptSuggestionModel(
          text: 'Distinguish between tort of negligence and strict liability',
          icon: '🏛️',
          category: 'Tort Law',
        ),
        PromptSuggestionModel(
          text: 'Break down fundamental human rights in constitutional law',
          icon: '🛡️',
          category: 'Constitutional Law',
        ),
      ];
    }

    // Default University STEM
    return defaults;
  }

  static List<PromptSuggestionModel> get defaults => const [
    PromptSuggestionModel(
      text: 'Derive the Euler-Lagrange equation from Hamilton\'s Principle',
      icon: '⚛️',
      category: 'Physics',
    ),
    PromptSuggestionModel(
      text: 'Explain Bayes\' theorem with a medical diagnosis example',
      icon: '📊',
      category: 'Statistics',
    ),
    PromptSuggestionModel(
      text: 'Solve the heat equation using separation of variables',
      icon: '🌡️',
      category: 'Mathematics',
    ),
    PromptSuggestionModel(
      text: 'Explain the CAP theorem in distributed systems',
      icon: '💻',
      category: 'Computer Science',
    ),
  ];
}
