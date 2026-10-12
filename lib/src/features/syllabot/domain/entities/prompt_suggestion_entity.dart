import 'package:equatable/equatable.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/entities/calibration_profile.dart';

/// Represents a quick-start prompt suggestion shown in Syllabot empty state.
class PromptSuggestionEntity extends Equatable {
  const PromptSuggestionEntity({
    required this.text,
    required this.icon,
    required this.category,
  });

  final String text;
  final String icon;
  final String category;

  @override
  List<Object?> get props => [text, icon, category];

  static List<PromptSuggestionEntity> forProfile(CalibrationProfile? profile) {
    if (profile == null) return defaults;

    // High School / Exam Tracks
    if (profile.focus == AcademicFocus.highSchool) {
      final exam = profile.highSchoolExam?.toLowerCase() ?? '';

      if (exam.contains('jamb') || exam.contains('utme')) {
        return const [
          PromptSuggestionEntity(
            text: "Solve electric field and Coulomb's law JAMB past question",
            icon: '⚡',
            category: 'JAMB Physics',
          ),
          PromptSuggestionEntity(
            text: 'Explain redox reactions and oxidation states for UTME',
            icon: '🧪',
            category: 'UTME Chemistry',
          ),
          PromptSuggestionEntity(
            text: 'Break down Mendelian genetics and Punnett squares',
            icon: '🧬',
            category: 'JAMB Biology',
          ),
          PromptSuggestionEntity(
            text:
                'Analyze antonyms and sentence interpretation for JAMB English',
            icon: '📖',
            category: 'JAMB English',
          ),
        ];
      }

      if (exam.contains('waec') || exam.contains('neco')) {
        return const [
          PromptSuggestionEntity(
            text:
                'Prove circle theorem: angle at center is twice circumference',
            icon: '📐',
            category: 'Mathematics',
          ),
          PromptSuggestionEntity(
            text:
                'Calculate terminal voltage and internal resistance of a cell',
            icon: '🔋',
            category: 'Physics',
          ),
          PromptSuggestionEntity(
            text: 'Balance organic esterification reaction mechanisms',
            icon: '🧪',
            category: 'Chemistry',
          ),
          PromptSuggestionEntity(
            text: 'Explain phototropism and auxin concentration in plants',
            icon: '🌿',
            category: 'Biology',
          ),
        ];
      }

      if (exam.contains('sat') || exam.contains('digital')) {
        return const [
          PromptSuggestionEntity(
            text: 'Solve system of non-linear equations for SAT Math module 2',
            icon: '📈',
            category: 'Digital SAT Math',
          ),
          PromptSuggestionEntity(
            text: 'Break down evidence-based reading passages & rhetoric craft',
            icon: '📚',
            category: 'SAT Reading',
          ),
          PromptSuggestionEntity(
            text: 'Master circle equations and trigonometric ratios for SAT',
            icon: '📐',
            category: 'SAT Geometry',
          ),
          PromptSuggestionEntity(
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
        PromptSuggestionEntity(
          text: 'Explain cellular respiration pathways and ATP yields',
          icon: '🧬',
          category: 'Biochemistry',
        ),
        PromptSuggestionEntity(
          text: 'Derive the Michaelis-Menten enzyme kinetics equation',
          icon: '🔬',
          category: 'Pharmacology',
        ),
        PromptSuggestionEntity(
          text: 'Differentiate Gram-positive and Gram-negative bacterial walls',
          icon: '🦠',
          category: 'Microbiology',
        ),
        PromptSuggestionEntity(
          text: 'Analyze cardiovascular action potentials and ion channels',
          icon: '❤️',
          category: 'Physiology',
        ),
      ];
    }

    if (field.contains('law') || field.contains('legal')) {
      return const [
        PromptSuggestionEntity(
          text:
              'Explain the doctrine of stare decisis with landmark precedents',
          icon: '⚖️',
          category: 'Jurisprudence',
        ),
        PromptSuggestionEntity(
          text: 'Analyze offer, acceptance, and consideration in contract law',
          icon: '📜',
          category: 'Contract Law',
        ),
        PromptSuggestionEntity(
          text: 'Distinguish between tort of negligence and strict liability',
          icon: '🏛️',
          category: 'Tort Law',
        ),
        PromptSuggestionEntity(
          text: 'Break down fundamental human rights in constitutional law',
          icon: '🛡️',
          category: 'Constitutional Law',
        ),
      ];
    }

    // Default University STEM
    return defaults;
  }

  static List<PromptSuggestionEntity> get defaults => const [
    PromptSuggestionEntity(
      text: "Derive the Euler-Lagrange equation from Hamilton's Principle",
      icon: '⚛️',
      category: 'Physics',
    ),
    PromptSuggestionEntity(
      text: "Explain Bayes' theorem with a medical diagnosis example",
      icon: '📊',
      category: 'Statistics',
    ),
    PromptSuggestionEntity(
      text: 'Solve the heat equation using separation of variables',
      icon: '🌡️',
      category: 'Mathematics',
    ),
    PromptSuggestionEntity(
      text: 'Explain the CAP theorem in distributed systems',
      icon: '💻',
      category: 'Computer Science',
    ),
  ];
}
