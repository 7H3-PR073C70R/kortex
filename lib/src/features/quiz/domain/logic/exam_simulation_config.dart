import 'package:equatable/equatable.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';

/// Configuration specifying realistic durations and question counts for official CBT examinations.
class ExamSimulationConfig extends Equatable {
  const ExamSimulationConfig({
    required this.durationMinutes,
    required this.standardQuestionCount,
    required this.passingPercentage,
    required this.examDisplayName,
    this.isSingleSubject = true,
  });

  /// Preset factory for JAMB full simulation
  factory ExamSimulationConfig.jamb({bool isSingleSubject = false}) =>
      ExamSimulationConfig.forCategory(
        ExamCategory.jamb,
        isSingleSubject: isSingleSubject,
      );

  /// Preset factory for WAEC simulation
  factory ExamSimulationConfig.waec({bool isSingleSubject = true}) =>
      ExamSimulationConfig.forCategory(
        ExamCategory.waec,
        isSingleSubject: isSingleSubject,
      );

  /// Preset factory for NECO simulation
  factory ExamSimulationConfig.neco({bool isSingleSubject = true}) =>
      ExamSimulationConfig.forCategory(
        ExamCategory.neco,
        isSingleSubject: isSingleSubject,
      );

  /// Preset factory for SAT full simulation
  factory ExamSimulationConfig.sat({bool isSingleSubject = false}) =>
      ExamSimulationConfig.forCategory(
        ExamCategory.sat,
        isSingleSubject: isSingleSubject,
      );

  /// Resolves configuration directly from string names or titles
  factory ExamSimulationConfig.fromString(
    String? titleOrId, {
    bool isSingleSubject = true,
  }) {
    return ExamSimulationConfig.forCategory(
      parseCategoryFromTitle(titleOrId),
      isSingleSubject: isSingleSubject,
    );
  }

  /// Resolves the realistic CBT simulation configuration for a given [ExamCategory].
  factory ExamSimulationConfig.forCategory(
    ExamCategory category, {
    bool isSingleSubject = true,
  }) {
    switch (category) {
      case ExamCategory.jamb:
        return ExamSimulationConfig(
          durationMinutes: isSingleSubject ? 40 : 120,
          standardQuestionCount: isSingleSubject ? 40 : 180,
          passingPercentage: 50,
          examDisplayName: 'JAMB / UTME',
          isSingleSubject: isSingleSubject,
        );
      case ExamCategory.waec:
        return const ExamSimulationConfig(
          durationMinutes: 60,
          standardQuestionCount: 50,
          passingPercentage: 50,
          examDisplayName: 'WAEC / WASSCE',
        );
      case ExamCategory.neco:
        return const ExamSimulationConfig(
          durationMinutes: 60,
          standardQuestionCount: 60,
          passingPercentage: 50,
          examDisplayName: 'NECO / SSCE',
        );
      case ExamCategory.sat:
        return ExamSimulationConfig(
          durationMinutes: isSingleSubject ? 65 : 134,
          standardQuestionCount: isSingleSubject ? 27 : 54,
          passingPercentage: 60,
          examDisplayName: 'SAT',
          isSingleSubject: isSingleSubject,
        );
      case ExamCategory.toefl:
        return const ExamSimulationConfig(
          durationMinutes: 120,
          standardQuestionCount: 40,
          passingPercentage: 65,
          examDisplayName: 'TOEFL iBT',
        );
      case ExamCategory.ielts:
        return const ExamSimulationConfig(
          durationMinutes: 165,
          standardQuestionCount: 40,
          passingPercentage: 65,
          examDisplayName: 'IELTS',
        );
      case ExamCategory.medicine:
      case ExamCategory.law:
      case ExamCategory.engineering:
      case ExamCategory.business:
      case ExamCategory.computerScience:
      case ExamCategory.general:
        return ExamSimulationConfig(
          durationMinutes: 60,
          standardQuestionCount: 50,
          passingPercentage: 50,
          examDisplayName: category.displayName,
        );
    }
  }

  /// Standard allowed time in minutes for this examination paper.
  final int durationMinutes;

  /// Official or standard target question volume for this simulation.
  final int standardQuestionCount;

  /// Standard passing score percentage.
  final int passingPercentage;

  /// Canonical name of the examination.
  final String examDisplayName;

  /// Whether this simulation represents a single-subject paper or full multi-subject battery.
  final bool isSingleSubject;

  /// Aliases and subject scaling helpers
  int get totalQuestions => standardQuestionCount;
  String get examName => examDisplayName;
  int get singleSubjectDurationMinutes => isSingleSubject ? durationMinutes : 40;
  int get singleSubjectQuestions => isSingleSubject ? standardQuestionCount : 40;

  int getQuestionsForSubjectCount(int subjectCount) {
    if (subjectCount <= 1) {
      return isSingleSubject ? standardQuestionCount : 40;
    }
    return standardQuestionCount;
  }

  int getDurationMinutesForSubjectCount(int subjectCount) {
    if (subjectCount <= 1) {
      return isSingleSubject ? durationMinutes : 40;
    }
    return durationMinutes;
  }

  /// Parses an exam category from title or ID strings (e.g. "cbt_jamb_physics", "WAEC Biology 2023").
  static ExamCategory parseCategoryFromTitle(String? titleOrId) {
    if (titleOrId == null || titleOrId.isEmpty) return ExamCategory.general;
    final lower = titleOrId.toLowerCase();
    if (lower.contains('jamb') || lower.contains('utme')) return ExamCategory.jamb;
    if (lower.contains('waec') || lower.contains('wassce')) return ExamCategory.waec;
    if (lower.contains('neco') || lower.contains('ssce')) return ExamCategory.neco;
    if (lower.contains('sat')) return ExamCategory.sat;
    if (lower.contains('toefl')) return ExamCategory.toefl;
    if (lower.contains('ielts')) return ExamCategory.ielts;
    if (lower.contains('med') || lower.contains('mbbs')) return ExamCategory.medicine;
    if (lower.contains('law')) return ExamCategory.law;
    if (lower.contains('eng')) return ExamCategory.engineering;
    if (lower.contains('bus') || lower.contains('acc')) return ExamCategory.business;
    if (lower.contains('cs') || lower.contains('computer')) return ExamCategory.computerScience;
    return ExamCategory.general;
  }

  @override
  List<Object?> get props => [
        durationMinutes,
        standardQuestionCount,
        passingPercentage,
        examDisplayName,
        isSingleSubject,
      ];
}
