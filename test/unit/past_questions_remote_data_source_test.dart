import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/quiz/data/client/supabase_past_questions_client.dart';
import 'package:kortex/src/features/quiz/data/data_sources/past_questions_remote_data_source_impl.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:mocktail/mocktail.dart';

class MockSupabasePastQuestionsClient extends Mock
    implements SupabasePastQuestionsClient {}

void main() {
  group('PastQuestionsRemoteDataSourceImpl Test Suite', () {
    late MockSupabasePastQuestionsClient mockClient;
    late PastQuestionsRemoteDataSourceImpl dataSource;

    setUp(() {
      mockClient = MockSupabasePastQuestionsClient();
      dataSource = PastQuestionsRemoteDataSourceImpl(mockClient);
    });

    test('getPastQuestions returns questions from Supabase client', () async {
      when(
        () => mockClient.fetchPastQuestions(
          examType: any(named: 'examType'),
          subject: any(named: 'subject'),
          year: any(named: 'year'),
          searchQuery: any(named: 'searchQuery'),
        ),
      ).thenAnswer(
        (_) async => [
          {
            'id': 'pq-supabase-1',
            'exam_type': 'WAEC',
            'subject': 'Mathematics',
            'year': 2024,
            'question_number': 1,
            'prompt': 'Solve for x: 3x = 9',
            'options': ['1', '2', '3', '4'],
            'correct_option_index': 2,
            'correct_option_label': 'C',
            'explanation': 'x = 9/3 = 3',
            'topic': 'Algebra',
            'difficulty': 'Easy',
          },
        ],
      );

      final questions = await dataSource.getPastQuestions(
        examCategory: ExamCategory.waec,
        subject: 'Mathematics',
      );

      expect(questions.length, equals(1));
      expect(questions.first.id, equals('pq-supabase-1'));
      expect(questions.first.prompt, equals('Solve for x: 3x = 9'));
    });

    test('getPastQuestions falls back to seed cache when client throws error',
        () async {
      when(
        () => mockClient.fetchPastQuestions(
          examType: any(named: 'examType'),
          subject: any(named: 'subject'),
          year: any(named: 'year'),
          searchQuery: any(named: 'searchQuery'),
        ),
      ).thenThrow(Exception('Supabase network error'));

      final questions = await dataSource.getPastQuestions(
        examCategory: ExamCategory.waec,
      );

      expect(questions.isNotEmpty, isTrue);
      for (final q in questions) {
        expect(q.examType, equals(ExamCategory.waec));
      }
    });

    test('getAvailableSubjects returns sorted distinct subjects', () async {
      when(
        () => mockClient.fetchPastQuestions(
          examType: any(named: 'examType'),
        ),
      ).thenAnswer(
        (_) async => [
          {'subject': 'Physics'},
          {'subject': 'Chemistry'},
          {'subject': 'Physics'},
        ],
      );

      final subjects = await dataSource.getAvailableSubjects(ExamCategory.waec);
      expect(subjects, equals(['Chemistry', 'Physics']));
    });
  });
}
