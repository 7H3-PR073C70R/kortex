import 'dart:math' as math;
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';

/// Difficulty tiers for the Millionaire ascent ladder.
enum MillionaireTierLevel {
  easy,
  medium,
  hard,
}

/// Intelligent Question Tiering Engine for Millionaire Mode:
/// Scales difficulty across the 12-rung ladder:
/// - Rungs 1–4 (Easy / Low Stakes): Quick dopamine wins (>85% retention / foundational concepts).
/// - Rungs 5–8 (Medium / Mid Stakes): Core curriculum comprehension (60%–85% retention).
/// - Rungs 9–12 (Hard / High Stakes): Challenging synthesis, trick questions, or high-decay items (<60% retention).
class MillionaireTieringEngine {
  const MillionaireTieringEngine();

  /// Arranges [questions] into an escalating 12-step ladder.
  /// If [retentionEvaluator] is provided, uses it to rank card retrievability.
  /// Otherwise, estimates cognitive load via prompt length, LaTeX formulas, and distractor complexity.
  List<QuizQuestionEntity> tierQuestions({
    required List<QuizQuestionEntity> questions,
    int targetCount = 12,
    double Function(QuizQuestionEntity question)? retentionEvaluator,
  }) {
    if (questions.isEmpty) return const [];
    if (questions.length <= targetCount) {
      // Sort existing questions by estimated difficulty
      final sorted = List<QuizQuestionEntity>.from(questions)
        ..sort((a, b) => _calculateDifficultyScore(a, retentionEvaluator)
            .compareTo(_calculateDifficultyScore(b, retentionEvaluator)));
      return sorted;
    }

    // Score all candidate questions (0.0 = easiest, 1.0 = hardest)
    final scored = questions.map((q) {
      final score = _calculateDifficultyScore(q, retentionEvaluator);
      return (question: q, score: score);
    }).toList()
      ..sort((a, b) => a.score.compareTo(b.score));

    // Desired distribution: 4 Easy, 4 Medium, 4 Hard
    final easyTarget = math.max(1, (targetCount / 3).round());
    final hardTarget = math.max(1, (targetCount / 3).round());
    final mediumTarget = targetCount - (easyTarget + hardTarget);

    final poolSize = scored.length;
    final easyBoundary = (poolSize * 0.35).floor();
    final hardBoundary = (poolSize * 0.65).ceil();

    final easyCandidates = scored.sublist(0, easyBoundary.clamp(1, poolSize));
    final mediumCandidates = scored.sublist(
      easyBoundary.clamp(0, poolSize),
      hardBoundary.clamp(0, poolSize),
    );
    final hardCandidates = scored.sublist(hardBoundary.clamp(0, poolSize));

    final selectedEasy = List.of(easyCandidates)..shuffle();
    final selectedMedium = List.of(
      mediumCandidates.isNotEmpty ? mediumCandidates : scored,
    )..shuffle();
    final selectedHard = List.of(
      hardCandidates.isNotEmpty ? hardCandidates : scored.reversed,
    )..shuffle();

    final ladder = <QuizQuestionEntity>[];
    final selectedIds = <String>{};

    void addFromCandidates(
      List<({QuizQuestionEntity question, double score})> source,
      int count,
    ) {
      for (final item in source) {
        if (ladder.length >= targetCount) break;
        if (!selectedIds.contains(item.question.id)) {
          selectedIds.add(item.question.id);
          ladder.add(item.question);
          if (ladder.length % (targetCount ~/ 3 == 0 ? 1 : targetCount ~/ 3) ==
              0) {
            if (ladder.length >= count) break;
          }
        }
      }
    }

    addFromCandidates(selectedEasy, easyTarget);
    addFromCandidates(selectedMedium, easyTarget + mediumTarget);
    addFromCandidates(selectedHard, targetCount);

    // Fallback: fill any remaining slots to reach targetCount
    if (ladder.length < targetCount) {
      for (final item in scored) {
        if (ladder.length >= targetCount) break;
        if (!selectedIds.contains(item.question.id)) {
          selectedIds.add(item.question.id);
          ladder.add(item.question);
        }
      }
    }

    return ladder;
  }

  /// Calculates a difficulty score between 0.0 (easiest) and 1.0 (hardest).
  double _calculateDifficultyScore(
    QuizQuestionEntity q,
    double Function(QuizQuestionEntity question)? retentionEvaluator,
  ) {
    if (retentionEvaluator != null) {
      final retention = retentionEvaluator(q).clamp(0.0, 1.0);
      // Invert: high retention -> easy (low score), low retention -> hard (high score)
      return (1.0 - retention).clamp(0.0, 1.0);
    }

    var score = 0.2; // Baseline

    // 1. Prompt complexity (length / density)
    if (q.prompt.length > 180) {
      score += 0.25;
    } else if (q.prompt.length > 90) {
      score += 0.15;
    }

    // 2. LaTeX formulas indicate advanced STEM problem solving
    if (q.latexFormula != null && q.latexFormula!.isNotEmpty) {
      score += 0.25;
    }

    // 3. Complex options (longer distractors)
    final avgOptionLength = q.options.isEmpty
        ? 0
        : q.options.fold<int>(0, (sum, opt) => sum + opt.length) /
            q.options.length;
    if (avgOptionLength > 40) {
      score += 0.2;
    } else if (avgOptionLength > 20) {
      score += 0.1;
    }

    return score.clamp(0.0, 1.0);
  }
}
