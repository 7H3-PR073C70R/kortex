import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/extensions/repository_extension.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/quiz/data/models/quiz_question_model.dart';
import 'package:kortex/src/features/quiz/data/models/quiz_result_model.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_result_entity.dart';
import 'package:kortex/src/features/quiz/domain/repositories/quiz_repository.dart';

class QuizRepositoryImpl implements QuizRepository {
  const QuizRepositoryImpl();

  @override
  Future<Either<Failure, List<QuizQuestionEntity>>> generateQuizFromDeck({
    required String deckId,
    String? deckTitle,
    int questionCount = 10,
  }) {
    return Future<List<QuizQuestionEntity>>.sync(() {
      return _generateMockQuestions(count: questionCount);
    }).makeRequest();
  }

  @override
  Future<Either<Failure, List<QuizQuestionEntity>>> generateQuizFromDocument({
    required String documentId,
    int questionCount = 10,
  }) {
    return Future<List<QuizQuestionEntity>>.sync(() {
      return _generateMockQuestions(count: questionCount);
    }).makeRequest();
  }

  @override
  Future<Either<Failure, QuizResultEntity>> submitQuizAnswers({
    required String quizTitle,
    required List<QuizQuestionEntity> questions,
    required int durationSeconds,
  }) {
    return Future<QuizResultEntity>.sync(() {
      final total = questions.length;
      final correctCount = questions.where((q) => q.isCorrect).length;

      final topicGroups = <String, List<QuizQuestionEntity>>{};
      for (final q in questions) {
        topicGroups.putIfAbsent(q.subTopic, () => []).add(q);
      }

      final weaknesses = topicGroups.entries.map((entry) {
        final subTopic = entry.key;
        final qs = entry.value;
        final correctInTopic = qs.where((q) => q.isCorrect).length;
        return TopicWeakness(
          subTopic: subTopic,
          totalQuestions: qs.length,
          correctCount: correctInTopic,
        );
      }).toList();

      return QuizResultModel(
        id: 'quiz-res-${DateTime.now().millisecondsSinceEpoch}',
        quizTitle: quizTitle,
        totalQuestions: total,
        correctAnswers: correctCount,
        durationSeconds: durationSeconds,
        weaknesses: weaknesses,
        completedAt: DateTime.now(),
      );
    }).makeRequest();
  }

  List<QuizQuestionModel> _generateMockQuestions({
    required int count,
  }) {
    final list = <QuizQuestionModel>[
      const QuizQuestionModel(
        id: 'q-1',
        prompt:
            'What is the fundamental relationship between Gibbs free energy, '
            'enthalpy, and entropy?',
        type: QuizQuestionType.multipleChoice,
        options: [
          r'\Delta G = \Delta H - T\Delta S',
          r'\Delta G = \Delta H + T\Delta S',
          r'\Delta G = \frac{\Delta H}{T\Delta S}',
          r'\Delta G = T\Delta S - \Delta H',
        ],
        correctAnswer: r'\Delta G = \Delta H - T\Delta S',
        explanation:
            r'Gibbs free energy change \Delta G is given by '
            r'\Delta H - T\Delta S. A negative \Delta G indicates a '
            'spontaneous reaction.',
        subTopic: 'Chemical Thermodynamics',
        latexFormula: r'\Delta G = \Delta H - T\Delta S',
      ),
      const QuizQuestionModel(
        id: 'q-2',
        prompt:
            'According to Newton second law of motion, force is directly '
            'proportional to what?',
        type: QuizQuestionType.multipleChoice,
        options: [
          'Rate of change of momentum',
          'Velocity of the body',
          'Displacement per unit time',
          'Total mechanical energy',
        ],
        correctAnswer: 'Rate of change of momentum',
        explanation:
            r'Newton 2nd law: \vec{F} = \frac{d\vec{p}}{dt} = m\vec{a} '
            'for constant mass.',
        subTopic: 'Classical Mechanics',
        latexFormula: r'\vec{F} = m\vec{a}',
      ),
      const QuizQuestionModel(
        id: 'q-3',
        prompt:
            'True or False: In an adiabatic process, heat transfer into or '
            'out of the system is zero (Q = 0).',
        type: QuizQuestionType.trueFalse,
        options: ['True', 'False'],
        correctAnswer: 'True',
        explanation:
            'An adiabatic process occurs without transfer of heat or mass '
            'between a system and its surroundings (dQ = 0).',
        subTopic: 'Thermodynamic Processes',
      ),
      const QuizQuestionModel(
        id: 'q-4',
        prompt:
            'What is the derivative of f(x) = e^{2x} with respect to x?',
        type: QuizQuestionType.multipleChoice,
        options: [
          '2e^{2x}',
          'e^{2x}',
          '4e^{2x}',
          r'\frac{1}{2}e^{2x}',
        ],
        correctAnswer: '2e^{2x}',
        explanation:
            r'By the chain rule: \frac{d}{dx}[e^{u}] = e^{u}\frac{du}{dx}. '
            r'Thus \frac{d}{dx}[e^{2x}] = 2e^{2x}.',
        subTopic: 'Calculus & Derivatives',
        latexFormula: r'\frac{d}{dx}(e^{2x}) = 2e^{2x}',
      ),
    ];

    if (count <= list.length) {
      return list.sublist(0, count);
    }
    return list;
  }
}
