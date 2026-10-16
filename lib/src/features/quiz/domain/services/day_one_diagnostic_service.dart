import 'dart:math' as math;

import 'package:kortex/src/core/utils/app_logger.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/logic/exam_question_selector.dart';
import 'package:kortex/src/features/quiz/domain/logic/exam_simulation_config.dart';
import 'package:kortex/src/features/quiz/domain/repositories/past_questions_repository.dart';

/// Service responsible for generating a rapid 10-minute / 15-question Day-One
/// diagnostic battery across a student's foundational exam subjects.
class DayOneDiagnosticService {
  const DayOneDiagnosticService({
    PastQuestionsRepository? pastQuestionsRepository,
  }) : _pastQuestionsRepository = pastQuestionsRepository;

  final PastQuestionsRepository? _pastQuestionsRepository;

  /// Default canonical subjects per examination category for Day-One calibration.
  static const Map<ExamCategory, List<String>> canonicalTrackSubjects = {
    ExamCategory.jamb: [
      'English Language',
      'Mathematics',
      'Biology',
      'Chemistry',
    ],
    ExamCategory.waec: [
      'English Language',
      'General Mathematics',
      'Biology',
      'Economics',
    ],
    ExamCategory.neco: [
      'English Language',
      'General Mathematics',
      'Civic Education',
      'Physics',
    ],
    ExamCategory.sat: [
      'Reading and Writing',
      'Math (No Calculator)',
      'Math (Calculator)',
    ],
    ExamCategory.general: [
      'English Language',
      'Quantitative Reasoning',
      'General Studies',
    ],
  };

  /// Generates exactly [totalQuestions] (default 15) balanced questions for [trackOrExamName].
  Future<List<QuizQuestionEntity>> generateDiagnosticQuestions({
    required String trackOrExamName,
    List<String> registeredSubjectNames = const [],
    int totalQuestions = 15,
  }) async {
    final category = ExamSimulationConfig.parseCategoryFromTitle(trackOrExamName);
    final targetSubjects = registeredSubjectNames.isNotEmpty
        ? registeredSubjectNames
        : (canonicalTrackSubjects[category] ?? canonicalTrackSubjects[ExamCategory.general]!);

    final subjectCount = math.max(1, targetSubjects.length);
    final basePerSubject = totalQuestions ~/ subjectCount;
    var remainder = totalQuestions % subjectCount;

    final resultQuestions = <QuizQuestionEntity>[];
    final repo = _pastQuestionsRepository;

    for (var i = 0; i < targetSubjects.length; i++) {
      final subject = targetSubjects[i];
      final countForSubject = basePerSubject + (remainder > 0 ? 1 : 0);
      if (remainder > 0) remainder--;

      if (countForSubject <= 0) continue;

      var fetchedQuestions = <PastQuestionEntity>[];

      if (repo != null) {
        try {
          final res = await repo.getPastQuestions(
            examCategory: category,
            subject: subject,
          );
          fetchedQuestions = res.fold(
            (f) => <PastQuestionEntity>[],
            (list) => list,
          );

          if (fetchedQuestions.isEmpty) {
            final fallbackRes = await repo.getPastQuestions(
              searchQuery: subject,
            );
            fetchedQuestions = fallbackRes.fold(
              (f) => <PastQuestionEntity>[],
              (list) => list,
            );
          }
        } on Object catch (e, st) {
          AppLogger.debug('DayOneDiagnosticService query warning: $e', error: e, stackTrace: st);
        }
      }

      if (fetchedQuestions.isNotEmpty) {
        final selected = ExamQuestionSelector.selectPastQuestions(
          pool: fetchedQuestions,
          count: countForSubject,
        );
        for (final pq in selected) {
          resultQuestions.add(QuizQuestionEntity.fromPastQuestion(pq));
        }
      } else {
        // Fallback to offline curated foundational questions for this subject
        final fallback = _getFoundationalFallbackQuestions(
          subject: subject,
          count: countForSubject,
        );
        resultQuestions.addAll(fallback);
      }
    }

    // Safety guard: if still short of totalQuestions, fill with general diagnostic questions
    if (resultQuestions.length < totalQuestions) {
      final needed = totalQuestions - resultQuestions.length;
      final generalFill = _getFoundationalFallbackQuestions(
        subject: 'General Knowledge',
        count: needed,
      );
      resultQuestions.addAll(generalFill);
    }

    return resultQuestions.take(totalQuestions).toList();
  }

  /// Curated offline fallback question bank for standard diagnostic subjects
  List<QuizQuestionEntity> _getFoundationalFallbackQuestions({
    required String subject,
    required int count,
  }) {
    if (count <= 0) return const [];
    final subLower = subject.toLowerCase();

    final List<QuizQuestionEntity> pool;
    if (subLower.contains('english') || subLower.contains('reading')) {
      pool = _englishDiagnosticPool;
    } else if (subLower.contains('math') || subLower.contains('quantitative')) {
      pool = _mathDiagnosticPool;
    } else if (subLower.contains('bio')) {
      pool = _biologyDiagnosticPool;
    } else if (subLower.contains('chem') || subLower.contains('phys')) {
      pool = _scienceDiagnosticPool;
    } else {
      pool = _generalDiagnosticPool;
    }

    final shuffled = List<QuizQuestionEntity>.from(pool)..shuffle();
    final result = <QuizQuestionEntity>[];
    var cycle = 0;
    while (result.length < count) {
      for (final q in shuffled) {
        if (result.length >= count) break;
        if (cycle == 0) {
          result.add(q);
        } else {
          result.add(
            QuizQuestionEntity(
              id: '${q.id}_c$cycle',
              prompt: q.prompt,
              type: q.type,
              options: q.options,
              correctAnswer: q.correctAnswer,
              explanation: q.explanation,
              subTopic: q.subTopic,
              latexFormula: q.latexFormula,
              imageUrl: q.imageUrl,
            ),
          );
        }
      }
      cycle++;
    }
    return result;
  }

  static final List<QuizQuestionEntity> _englishDiagnosticPool = [
    const QuizQuestionEntity(
      id: 'diag_eng_01',
      prompt: 'Choose the option opposite in meaning to the capitalized word: The minister delivered an IMPROMPTU speech at the summit.',
      type: QuizQuestionType.multipleChoice,
      options: ['Unprepared', 'Rehearsed', 'Passionate', 'Eloquent'],
      correctAnswer: 'Rehearsed',
      explanation: 'Impromptu means done without being planned or rehearsed. Its exact antonym is "Rehearsed".',
      subTopic: 'Lexis and Structure',
    ),
    const QuizQuestionEntity(
      id: 'diag_eng_02',
      prompt: 'Identify the sentence with correct subject-verb agreement:',
      type: QuizQuestionType.multipleChoice,
      options: [
        'Neither the teacher nor the students was present.',
        'Neither the teacher nor the students were present.',
        'Neither the students nor the teacher were present.',
        'Neither of the students are present.',
      ],
      correctAnswer: 'Neither the teacher nor the students were present.',
      explanation: 'When using "neither...nor", the verb agrees with the closer subject ("the students", which is plural, requiring "were").',
      subTopic: 'Concord',
    ),
    const QuizQuestionEntity(
      id: 'diag_eng_03',
      prompt: 'Select the option that best interprets the idiom: "He decided to bite the bullet and sit for the exam."',
      type: QuizQuestionType.multipleChoice,
      options: [
        'Engage in violence',
        'Face a difficult situation with courage',
        'Procrastinate indefinitely',
        'Make a careless error',
      ],
      correctAnswer: 'Face a difficult situation with courage',
      explanation: 'To "bite the bullet" means to face a tough situation bravely after enduring apprehension.',
      subTopic: 'Idioms and Figurative Expressions',
    ),
    const QuizQuestionEntity(
      id: 'diag_eng_04',
      prompt: 'Which word has the same vowel sound as the sound in "beat"?',
      type: QuizQuestionType.multipleChoice,
      options: ['Bake', 'Scene', 'Bed', 'Bite'],
      correctAnswer: 'Scene',
      explanation: '"Beat" has the long /i:/ sound, which matches the vowel sound in "Scene".',
      subTopic: 'Oral English',
    ),
  ];

  static final List<QuizQuestionEntity> _mathDiagnosticPool = [
    const QuizQuestionEntity(
      id: 'diag_mth_01',
      prompt: 'If 3x - 7 = 14 + x, find the value of x.',
      type: QuizQuestionType.multipleChoice,
      options: ['7', '10.5', '10', '12'],
      correctAnswer: '10.5',
      explanation: '3x - x = 14 + 7 => 2x = 21 => x = 10.5.',
      subTopic: 'Algebra',
    ),
    const QuizQuestionEntity(
      id: 'diag_mth_02',
      prompt: 'Find the quadratic equation whose roots are 2 and -3.',
      type: QuizQuestionType.multipleChoice,
      options: [
        'x² + x - 6 = 0',
        'x² - x - 6 = 0',
        'x² + 5x - 6 = 0',
        'x² - 5x + 6 = 0',
      ],
      correctAnswer: 'x² + x - 6 = 0',
      explanation: 'Formula: x² - (sum of roots)x + (product of roots) = 0. Sum = -1, Product = -6. Thus: x² + x - 6 = 0.',
      subTopic: 'Quadratic Equations',
    ),
    const QuizQuestionEntity(
      id: 'diag_mth_03',
      prompt: 'Evaluate log₁₀(1000) - log₁₀(10).',
      type: QuizQuestionType.multipleChoice,
      options: ['1', '2', '3', '100'],
      correctAnswer: '2',
      explanation: 'log₁₀(1000) = 3 and log₁₀(10) = 1. Therefore, 3 - 1 = 2.',
      subTopic: 'Logarithms',
    ),
    const QuizQuestionEntity(
      id: 'diag_mth_04',
      prompt: 'A bag contains 5 red and 7 blue marbles. If one marble is drawn at random, what is the probability it is red?',
      type: QuizQuestionType.multipleChoice,
      options: ['5/12', '7/12', '5/7', '1/5'],
      correctAnswer: '5/12',
      explanation: 'Total marbles = 5 + 7 = 12. P(Red) = 5/12.',
      subTopic: 'Probability',
    ),
  ];

  static final List<QuizQuestionEntity> _biologyDiagnosticPool = [
    const QuizQuestionEntity(
      id: 'diag_bio_01',
      prompt: 'Which organelle is universally known as the powerhouse of the eukaryotic cell?',
      type: QuizQuestionType.multipleChoice,
      options: ['Nucleus', 'Mitochondrion', 'Ribosome', 'Golgi apparatus'],
      correctAnswer: 'Mitochondrion',
      explanation: 'Mitochondria generate most of the chemical energy needed to power the cell (ATP).',
      subTopic: 'Cell Biology',
    ),
    const QuizQuestionEntity(
      id: 'diag_bio_02',
      prompt: 'In genetics, what is the expected phenotypic ratio of a monohybrid cross between two heterozygous individuals (Aa x Aa)?',
      type: QuizQuestionType.multipleChoice,
      options: ['1:1', '3:1', '9:3:3:1', '1:2:1'],
      correctAnswer: '3:1',
      explanation: 'A cross between Aa and Aa yields 1 AA, 2 Aa, and 1 aa, resulting in a 3:1 dominant-to-recessive phenotypic ratio.',
      subTopic: 'Genetics',
    ),
    const QuizQuestionEntity(
      id: 'diag_bio_03',
      prompt: 'Which enzyme in human saliva begins the digestion of dietary starch into maltose?',
      type: QuizQuestionType.multipleChoice,
      options: ['Pepsin', 'Ptyalin (Salivary Amylase)', 'Trypsin', 'Lipase'],
      correctAnswer: 'Ptyalin (Salivary Amylase)',
      explanation: 'Ptyalin (salivary amylase) catalyzes the hydrolysis of starch into maltose in the mouth.',
      subTopic: 'Nutrition and Digestion',
    ),
    const QuizQuestionEntity(
      id: 'diag_bio_04',
      prompt: 'In flowering plants, the process by which pollen grains are transferred from the anther to the stigma is called:',
      type: QuizQuestionType.multipleChoice,
      options: ['Fertilization', 'Pollination', 'Germination', 'Transpiration'],
      correctAnswer: 'Pollination',
      explanation: 'Pollination is the mechanical transfer of pollen from the male anther to the female stigma.',
      subTopic: 'Plant Reproduction',
    ),
  ];

  static final List<QuizQuestionEntity> _scienceDiagnosticPool = [
    const QuizQuestionEntity(
      id: 'diag_sci_01',
      prompt: 'What is the SI unit of electric current?',
      type: QuizQuestionType.multipleChoice,
      options: ['Volt', 'Ampere', 'Ohm', 'Watt'],
      correctAnswer: 'Ampere',
      explanation: 'The SI base unit of electric current is the Ampere (A).',
      subTopic: 'Electricity',
    ),
    const QuizQuestionEntity(
      id: 'diag_sci_02',
      prompt: 'What is the pH of a neutral aqueous solution at 25°C?',
      type: QuizQuestionType.multipleChoice,
      options: ['0', '14', '7', '1'],
      correctAnswer: '7',
      explanation: 'A neutral aqueous solution has a pH of exactly 7 at 25°C.',
      subTopic: 'Acids and Bases',
    ),
    const QuizQuestionEntity(
      id: 'diag_sci_03',
      prompt: 'According to Newton’s Second Law of Motion, Force equals:',
      type: QuizQuestionType.multipleChoice,
      options: ['Mass × Velocity', 'Mass × Acceleration', 'Work ÷ Time', 'Pressure × Area'],
      correctAnswer: 'Mass × Acceleration',
      explanation: 'Newton’s Second Law states F = ma (Force = mass × acceleration).',
      subTopic: 'Mechanics',
    ),
    const QuizQuestionEntity(
      id: 'diag_sci_04',
      prompt: 'Which gas is evolved when dilute hydrochloric acid reacts with calcium carbonate?',
      type: QuizQuestionType.multipleChoice,
      options: ['Hydrogen', 'Oxygen', 'Carbon dioxide', 'Chlorine'],
      correctAnswer: 'Carbon dioxide',
      explanation: 'CaCO₃ + 2HCl → CaCl₂ + H₂O + CO₂ (carbon dioxide gas is released).',
      subTopic: 'Chemical Reactions',
    ),
  ];

  static final List<QuizQuestionEntity> _generalDiagnosticPool = [
    const QuizQuestionEntity(
      id: 'diag_gen_01',
      prompt: 'If all Zips are Zaps, and all Zaps are Zops, are all Zips definitely Zops?',
      type: QuizQuestionType.multipleChoice,
      options: ['Yes', 'No', 'Only on weekends', 'Cannot be determined'],
      correctAnswer: 'Yes',
      explanation: 'By the transitive law of formal logic, if A ⊆ B and B ⊆ C, then A ⊆ C.',
      subTopic: 'Deductive Reasoning',
    ),
    const QuizQuestionEntity(
      id: 'diag_gen_02',
      prompt: 'Complete the sequence: 2, 6, 12, 20, 30, ?',
      type: QuizQuestionType.multipleChoice,
      options: ['40', '42', '44', '36'],
      correctAnswer: '42',
      explanation: 'Differences: +4, +6, +8, +10, +12. 30 + 12 = 42.',
      subTopic: 'Number Sequences',
    ),
    const QuizQuestionEntity(
      id: 'diag_gen_03',
      prompt: 'Which of the following is an example of renewable energy?',
      type: QuizQuestionType.multipleChoice,
      options: ['Coal', 'Petroleum', 'Solar energy', 'Natural gas'],
      correctAnswer: 'Solar energy',
      explanation: 'Solar energy is naturally replenished and practically inexhaustible.',
      subTopic: 'Environmental Science',
    ),
  ];
}
