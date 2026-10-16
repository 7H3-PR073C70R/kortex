import 'dart:math';

import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';

/// Seeded, reproducible question selection engine that adaptively prioritizes:
/// 1. Unseen questions on topics with historical errors.
/// 2. Unseen questions across the question bank.
/// 3. Questions with historical errors (for retention reinforcement).
/// 4. Previously mastered/seen questions.
class ExamQuestionSelector {
  ExamQuestionSelector._();

  /// Selects up to [count] questions from [pool] prioritizing unseen questions and historical errors.
  /// If [seed] is provided, ordering within priority tiers is 100% deterministic and reproducible.
  static List<T> selectQuestions<T>({
    required List<T> pool,
    required int count,
    required String Function(T item) getId,
    required String Function(T item) getSubTopic,
    Set<String> seenQuestionIds = const {},
    Set<String> historicalErrorIds = const {},
    Set<String> weakSubtopics = const {},
    int? seed,
  }) {
    if (pool.isEmpty || count <= 0) return <T>[];
    if (pool.length <= count && seenQuestionIds.isEmpty && historicalErrorIds.isEmpty) {
      final list = List<T>.from(pool);
      final random = seed != null ? Random(seed) : Random();
      list.shuffle(random);
      return list;
    }

    final random = seed != null ? Random(seed) : Random();

    // 1. Partition into adaptive priority tiers:
    final tier1UnseenWeak = <T>[]; // Unseen on weak topics or failed previously
    final tier2UnseenGeneral = <T>[]; // Other unseen questions
    final tier3HistoricalErrors = <T>[]; // Seen, but had historical errors
    final tier4Mastered = <T>[]; // Seen and previously answered correctly

    for (final item in pool) {
      final id = getId(item);
      final subTopic = getSubTopic(item);
      final isSeen = seenQuestionIds.contains(id);
      final hasError = historicalErrorIds.contains(id);
      final isWeakTopic = weakSubtopics.contains(subTopic);

      if (!isSeen) {
        if (hasError || isWeakTopic) {
          tier1UnseenWeak.add(item);
        } else {
          tier2UnseenGeneral.add(item);
        }
      } else {
        if (hasError) {
          tier3HistoricalErrors.add(item);
        } else {
          tier4Mastered.add(item);
        }
      }
    }

    // Deterministically shuffle each tier using the provided seed
    tier1UnseenWeak.shuffle(random);
    tier2UnseenGeneral.shuffle(random);
    tier3HistoricalErrors.shuffle(random);
    tier4Mastered.shuffle(random);

    final result = <T>[];

    void takeFrom(List<T> source) {
      for (final item in source) {
        if (result.length >= count) return;
        result.add(item);
      }
    }

    takeFrom(tier1UnseenWeak);
    takeFrom(tier2UnseenGeneral);
    takeFrom(tier3HistoricalErrors);
    takeFrom(tier4Mastered);

    return result;
  }

  /// Convenience helper for [PastQuestionEntity].
  static List<PastQuestionEntity> selectPastQuestions({
    required List<PastQuestionEntity> pool,
    required int count,
    Set<String> seenQuestionIds = const {},
    Set<String> historicalErrorIds = const {},
    Set<String> weakSubtopics = const {},
    int? seed,
  }) {
    return selectQuestions<PastQuestionEntity>(
      pool: pool,
      count: count,
      getId: (q) => q.id,
      getSubTopic: (q) => q.topic,
      seenQuestionIds: seenQuestionIds,
      historicalErrorIds: historicalErrorIds,
      weakSubtopics: weakSubtopics,
      seed: seed,
    );
  }

  /// Convenience helper for [QuizQuestionEntity].
  static List<QuizQuestionEntity> selectQuizQuestions({
    required List<QuizQuestionEntity> pool,
    required int count,
    Set<String> seenQuestionIds = const {},
    Set<String> historicalErrorIds = const {},
    Set<String> weakSubtopics = const {},
    int? seed,
  }) {
    return selectQuestions<QuizQuestionEntity>(
      pool: pool,
      count: count,
      getId: (q) => q.id,
      getSubTopic: (q) => q.subTopic,
      seenQuestionIds: seenQuestionIds,
      historicalErrorIds: historicalErrorIds,
      weakSubtopics: weakSubtopics,
      seed: seed,
    );
  }
}
