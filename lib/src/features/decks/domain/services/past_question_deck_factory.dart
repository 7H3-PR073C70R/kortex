import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/dashboard/data/models/dashboard_feed_model.dart';
import 'package:kortex/src/features/decks/data/models/deck_model.dart';
import 'package:kortex/src/features/decks/data/models/flashcard_model.dart';
import 'package:kortex/src/features/quiz/data/data_sources/past_questions_local_data_source.dart';
import 'package:kortex/src/features/quiz/data/models/past_question_model.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';

class PastQuestionDeckFactory {
  PastQuestionDeckFactory({
    PastQuestionsLocalDataSource? pastQuestionsLocalDataSource,
  }) : _pastQuestionsDataSource = pastQuestionsLocalDataSource ??
            (locator.isRegistered<PastQuestionsLocalDataSource>()
                ? locator<PastQuestionsLocalDataSource>()
                : null);

  final PastQuestionsLocalDataSource? _pastQuestionsDataSource;

  static const String canonicalPrefix = 'canonical_deck_';

  bool isSecondaryTrack(String? track) {
    if (track == null || track.isEmpty) return false;
    final upper = track.toUpperCase();
    return upper.contains('WAEC') ||
        upper.contains('JAMB') ||
        upper.contains('UTME') ||
        upper.contains('NECO') ||
        upper.contains('SSCE');
  }

  ExamCategory resolveCategory(String? track) {
    final upper = (track ?? 'WAEC').toUpperCase();
    if (upper.contains('JAMB') || upper.contains('UTME')) {
      return ExamCategory.jamb;
    }
    if (upper.contains('NECO') || upper.contains('SSCE')) {
      return ExamCategory.neco;
    }
    return ExamCategory.waec;
  }

  /// Generates the canonical past question study decks for the last 2 previous years
  /// for each of the user's registered courses under WAEC, JAMB, or NECO tracks.
  Future<List<DeckModel>> generateCanonicalDecksForCourses({
    required List<CuratedCourseModel> courses,
    required String? track,
  }) async {
    if (!isSecondaryTrack(track)) return const [];
    if (courses.isEmpty) return const [];

    final category = resolveCategory(track);
    final results = <DeckModel>[];

    // Ensure local data source is initialized
    final ds = _pastQuestionsDataSource;
    if (ds != null && !ds.isInitialized) {
      await ds.initialize();
    }

    for (final course in courses) {
      final subjectName = course.title;
      final cleanCode = course.courseCode.replaceAll(RegExp('[^a-zA-Z0-9]'), '');

      // Query past questions for this course & subject
      final questions = await (ds?.getPastQuestions(
            examCategory: category,
            subject: subjectName,
            courseId: course.id,
            courseCode: course.courseCode,
            limit: 500,
          ) ??
          Future.value(<PastQuestionModel>[]));

      if (questions.isEmpty) continue;

      // Group questions by year
      final yearMap = <int, List<PastQuestionModel>>{};
      for (final q in questions) {
        yearMap.putIfAbsent(q.year, () => []).add(q);
      }

      // Sort descending to get the last 2 previous years
      final sortedYears = yearMap.keys.toList()..sort((a, b) => b.compareTo(a));
      final targetYears = sortedYears.take(2).toList();

      for (final year in targetYears) {
        final yearQuestions = yearMap[year] ?? [];
        if (yearQuestions.isEmpty) continue;

        final deckId =
            '$canonicalPrefix${category.code.toLowerCase()}_${cleanCode.toLowerCase()}_$year';

        results.add(
          DeckModel(
            id: deckId,
            title: '${category.code} $year ${course.title} Past Questions',
            description:
                'Official ${category.displayName} $year examination questions treated as active recall study deck.',
            subject: course.title,
            category: category.code,
            courseId: course.id,
            courseCode: course.courseCode,
            totalCards: yearQuestions.length,
            dueCards: yearQuestions.length,
            masteryRate: 0,
            lastStudied: DateTime.now(),
            cards: yearQuestions.map((q) => _questionToFlashcard(deckId, q)).toList(),
          ),
        );
      }
    }

    return results;
  }

  /// Converts a canonical deck ID back into flashcards by querying past questions.
  Future<List<FlashcardModel>> generateCardsForCanonicalDeck(String deckId) async {
    if (!deckId.startsWith(canonicalPrefix)) return const [];

    final parts = deckId.substring(canonicalPrefix.length).split('_');
    if (parts.length < 3) return const [];

    final examCode = parts[0];
    final courseCode = parts[1];
    final year = int.tryParse(parts[2]);

    final category = PastQuestionModel.parseExamCategory(examCode);

    final ds = _pastQuestionsDataSource;
    if (ds != null && !ds.isInitialized) {
      await ds.initialize();
    }

    final questions = await (ds?.getPastQuestions(
          examCategory: category,
          courseCode: courseCode,
          year: year,
          limit: 200,
        ) ??
        Future.value(<PastQuestionModel>[]));

    return questions.map((q) => _questionToFlashcard(deckId, q)).toList();
  }

  FlashcardModel _questionToFlashcard(String deckId, PastQuestionModel q) {
    return FlashcardModel(
      id: '${deckId}_q_${q.id}',
      deckId: deckId,
      front: _buildCardFront(q),
      back: _buildCardBack(q),
      imageUrl: q.imageUrl,
      frontLatex: q.latexFormula,
      sourceTopic: q.topic,
      nextDueDate: DateTime.now(),
    );
  }

  String _buildCardFront(PastQuestionModel q) {
    final prompt = q.prompt.trim();
    if (q.options.isEmpty) return prompt;

    final buffer = StringBuffer(prompt)..writeln('\n\n**Options:**');
    const letters = ['A', 'B', 'C', 'D', 'E'];
    for (var i = 0; i < q.options.length; i++) {
      final defaultLetter = i < letters.length ? letters[i] : '${i + 1}';
      final opt = q.options[i].trim();
      // Normalize option label: avoid duplicate like "A. A. option"
      final match = RegExp(r'^\s*(?:([A-Ea-e])[\.\)]|\(([A-Ea-e])\))\s*(.*)').firstMatch(opt);
      if (match != null) {
        final letter = (match.group(1) ?? match.group(2) ?? defaultLetter).toUpperCase();
        final content = match.group(3)?.trim() ?? '';
        buffer.writeln('• $letter. $content');
      } else {
        buffer.writeln('• $defaultLetter. $opt');
      }
    }
    return buffer.toString().trim();
  }

  String _buildCardBack(PastQuestionModel q) {
    final buffer = StringBuffer();

    // 1. Correct Answer
    if (q.options.isNotEmpty) {
      const letters = ['A', 'B', 'C', 'D', 'E'];
      var correctLabel = q.correctOptionLabel.trim();
      String? correctText;

      if (q.correctOptionIndex >= 0 && q.correctOptionIndex < q.options.length) {
        correctText = q.options[q.correctOptionIndex].trim();
        if (correctLabel.isEmpty && q.correctOptionIndex < letters.length) {
          correctLabel = letters[q.correctOptionIndex];
        }
      } else if (correctLabel.isNotEmpty) {
        final idx = letters.indexOf(correctLabel.toUpperCase());
        if (idx >= 0 && idx < q.options.length) {
          correctText = q.options[idx].trim();
        }
      }

      if (correctLabel.isNotEmpty) {
        if (correctText != null && correctText.isNotEmpty) {
          final cleanMatch = RegExp(r'^\s*(?:[A-Ea-e][\.\)]|\([A-Ea-e]\))\s*(.*)').firstMatch(correctText);
          final cleanContent = cleanMatch != null ? cleanMatch.group(1)?.trim() ?? '' : correctText;
          if (cleanContent.isNotEmpty) {
            buffer.writeln('**Correct Answer:** Option $correctLabel — $cleanContent');
          } else {
            buffer.writeln('**Correct Answer:** Option $correctLabel');
          }
        } else {
          buffer.writeln('**Correct Answer:** Option $correctLabel');
        }
      }
    } else if (q.correctOptionLabel.isNotEmpty) {
      buffer.writeln('**Correct Answer:** ${q.correctOptionLabel}');
    }

    // 2. Explanation
    if (q.explanation.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.writeln();
      buffer.writeln('**Explanation:**\n${q.explanation.trim()}');
    }

    return buffer.toString().trim();
  }
}
