import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/quiz/data/client/past_questions_api_client.dart';
import 'package:kortex/src/features/quiz/data/data_sources/past_questions_remote_data_source_impl.dart';
import 'package:kortex/src/features/quiz/data/models/past_question_model.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:mocktail/mocktail.dart';
import 'package:retrofit/retrofit.dart';

class MockPastQuestionsApiClient extends Mock
    implements PastQuestionsApiClient {}

void main() {
  group('PastQuestionsRemoteDataSourceImpl Test Suite', () {
    late MockPastQuestionsApiClient mockClient;
    late PastQuestionsRemoteDataSourceImpl dataSource;

    setUp(() {
      mockClient = MockPastQuestionsApiClient();
      dataSource = PastQuestionsRemoteDataSourceImpl(mockClient);
    });

    test('getPastQuestions returns questions from API client', () async {
      when(
        () => mockClient.fetchPastQuestions(any()),
      ).thenAnswer(
        (_) async => HttpResponse(
          [
            {
              'id': 'pq-1',
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
          Response(requestOptions: RequestOptions()),
        ),
      );

      final questions = await dataSource.getPastQuestions(
        examCategory: ExamCategory.waec,
        subject: 'Mathematics',
      );

      expect(questions.length, equals(1));
      expect(questions.first.id, equals('pq-1'));
      expect(questions.first.prompt, equals('Solve for x: 3x = 9'));
    });

    test(
      'getPastQuestions returns empty list safely when client throws error and seed cache is purged',
      () async {
        when(
          () => mockClient.fetchPastQuestions(any()),
        ).thenThrow(Exception('Network error'));

        final questions = await dataSource.getPastQuestions(
          examCategory: ExamCategory.waec,
        );

        expect(questions.isEmpty, isTrue);
      },
    );

    test('getAvailableSubjects returns sorted distinct subjects', () async {
      when(
        () => mockClient.fetchPastQuestions(any()),
      ).thenAnswer(
        (_) async => HttpResponse(
          [
            {'subject': 'Physics'},
            {'subject': 'Chemistry'},
            {'subject': 'Physics'},
          ],
          Response(requestOptions: RequestOptions()),
        ),
      );

      final subjects = await dataSource.getAvailableSubjects(ExamCategory.waec);
      expect(subjects, equals(['Chemistry', 'Physics']));
    });

    test(
      'savePastQuestions routes questions to submitQuestionSubmissions moderation queue',
      () async {
        List<dynamic>? capturedPayload;
        when(
          () => mockClient.submitQuestionSubmissions(any()),
        ).thenAnswer((invocation) async {
          capturedPayload = invocation.positionalArguments.first as List<dynamic>;
          return HttpResponse(
            {'status': 'success'},
            Response(requestOptions: RequestOptions()),
          );
        });

        const question = PastQuestionModel(
          id: 'pq_user_contributed_1',
          examType: ExamCategory.jamb,
          subject: 'Physics',
          year: 2024,
          questionNumber: 1,
          prompt: 'What is the SI unit of force?',
          options: ['Joule', 'Newton', 'Watt', 'Pascal'],
          correctOptionIndex: 1,
          correctOptionLabel: 'B',
          explanation: 'Force is measured in Newtons (N).',
          topic: 'Mechanics',
          isUserAdded: true,
        );

        await dataSource.savePastQuestions([question]);

        verify(() => mockClient.submitQuestionSubmissions(any())).called(1);
        expect(capturedPayload, isNotNull);
        expect(capturedPayload!.length, equals(1));
        final payloadItem = capturedPayload!.first as Map<String, dynamic>;
        expect(payloadItem['client_question_id'], equals('pq_user_contributed_1'));
        expect(payloadItem['exam_type'], equals('JAMB'));
        expect(payloadItem['subject'], equals('Physics'));
        expect(payloadItem['prompt'], equals('What is the SI unit of force?'));
        expect(payloadItem['options'], equals(['Joule', 'Newton', 'Watt', 'Pascal']));
        expect(payloadItem['metadata'], isNotNull);
      },
    );

    test(
      'savePastQuestions preserves questions in memory so user can access them locally even if remote call fails',
      () async {
        when(
          () => mockClient.submitQuestionSubmissions(any()),
        ).thenThrow(Exception('PostgREST write forbidden / RLS failure'));

        const question = PastQuestionModel(
          id: 'pq_user_local_1',
          examType: ExamCategory.jamb,
          subject: 'Chemistry',
          year: 2023,
          questionNumber: 5,
          prompt: 'What is the atomic number of Carbon?',
          options: ['4', '6', '8', '12'],
          correctOptionIndex: 1,
          correctOptionLabel: 'B',
          explanation: 'Carbon has atomic number 6.',
          topic: 'Atomic Structure',
          isUserAdded: true,
        );

        await dataSource.savePastQuestions([question]);

        // Mock remote fetch to fail, confirming in-memory presence
        when(
          () => mockClient.fetchPastQuestions(any()),
        ).thenThrow(Exception('Offline'));

        final results = await dataSource.getPastQuestions(
          examCategory: ExamCategory.jamb,
          subject: 'Chemistry',
        );

        expect(results.length, equals(1));
        expect(results.first.id, equals('pq_user_local_1'));
        expect(results.first.prompt, equals('What is the atomic number of Carbon?'));
      },
    );
  });
}
