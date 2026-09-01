import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/quiz/data/services/past_questions_crawler_service.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';

void main() {
  group('PastQuestionsCrawlerService Unit Tests', () {
    late PastQuestionsCrawlerService crawler;

    setUp(() {
      crawler = PastQuestionsCrawlerService();
    });

    test('crawlAllPastQuestions indexes questions and marks completed',
        () async {
      expect(crawler.isCrawlingCompleted, isFalse);
      expect(crawler.totalIndexedQuestions, equals(0));

      final questions = await crawler.crawlAllPastQuestions();

      expect(crawler.isCrawlingCompleted, isTrue);
      expect(questions.isNotEmpty, isTrue);
      expect(crawler.totalIndexedQuestions, equals(questions.length));
    });

    test('crawlAllPastQuestions deduplicates using SHA-256 fingerprinting',
        () async {
      final questionsFirst = await crawler.crawlAllPastQuestions();
      final countFirst = crawler.totalIndexedQuestions;

      // Re-running returns cached deduplicated map
      final questionsSecond = await crawler.crawlAllPastQuestions();
      expect(questionsSecond.length, equals(countFirst));
      expect(questionsFirst.length, equals(questionsSecond.length));
    });

    test('queryQuestions filters by ExamCategory properly', () async {
      await crawler.crawlAllPastQuestions();

      final waecQuestions = crawler.queryQuestions(
        examCategory: ExamCategory.waec,
      );
      expect(waecQuestions.isNotEmpty, isTrue);
      for (final q in waecQuestions) {
        expect(q.examType, equals(ExamCategory.waec));
      }

      final satQuestions = crawler.queryQuestions(
        examCategory: ExamCategory.sat,
      );
      expect(satQuestions.isNotEmpty, isTrue);
      for (final q in satQuestions) {
        expect(q.examType, equals(ExamCategory.sat));
      }
    });

    test('queryQuestions filters by subject and year in chronological order',
        () async {
      await crawler.crawlAllPastQuestions();

      final mathQuestions = crawler.queryQuestions(
        examCategory: ExamCategory.waec,
        subject: 'Mathematics',
      );
      expect(mathQuestions.isNotEmpty, isTrue);

      // Verify descending year order
      for (var i = 0; i < mathQuestions.length - 1; i++) {
        expect(
          mathQuestions[i].year >= mathQuestions[i + 1].year,
          isTrue,
        );
      }
    });

    test('queryQuestions filters by search text', () async {
      await crawler.crawlAllPastQuestions();

      final searchResults = crawler.queryQuestions(
        searchQuery: 'logarithm',
      );
      expect(
        searchResults.any(
          (q) => q.prompt.contains('log') || q.topic.contains('Log'),
        ),
        isTrue,
      );
    });
  });
}
