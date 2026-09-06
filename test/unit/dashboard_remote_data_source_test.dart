import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/error/exceptions.dart';
import 'package:kortex/src/features/dashboard/data/client/dashboard_api_client.dart';
import 'package:kortex/src/features/dashboard/data/data_sources/dashboard_remote_data_source_impl.dart';
import 'package:mocktail/mocktail.dart';
import 'package:retrofit/retrofit.dart';

class MockDashboardApiClient extends Mock implements DashboardApiClient {}

void main() {
  group('DashboardRemoteDataSourceImpl.startMockExam', () {
    late MockDashboardApiClient mockClient;
    late DashboardRemoteDataSourceImpl dataSource;

    setUp(() {
      mockClient = MockDashboardApiClient();
      dataSource = DashboardRemoteDataSourceImpl(mockClient);
    });

    test('returns sessionId when server responds with valid sessionId', () async {
      when(
        () => mockClient.startMockExam(any()),
      ).thenAnswer(
        (_) async => HttpResponse(
          {'sessionId': 'valid-exam-session-789'},
          Response(
            requestOptions: RequestOptions(path: '/'),
            statusCode: 200,
          ),
        ),
      );

      final result = await dataSource.startMockExam(
        examId: 'exam-1',
        subject: 'Linear Algebra',
      );

      expect(result, equals('valid-exam-session-789'));
    });

    test('throws ServerException when response does not contain sessionId', () async {
      when(
        () => mockClient.startMockExam(any()),
      ).thenAnswer(
        (_) async => HttpResponse(
          {'error': 'Invalid request'},
          Response(
            requestOptions: RequestOptions(path: '/'),
            statusCode: 200,
          ),
        ),
      );

      expect(
        () => dataSource.startMockExam(
          examId: 'exam-1',
          subject: 'Linear Algebra',
        ),
        throwsA(isA<ServerException>()),
      );
    });

    test('propagates exception when client call throws DioException', () async {
      when(
        () => mockClient.startMockExam(any()),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/'),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      expect(
        () => dataSource.startMockExam(
          examId: 'exam-1',
          subject: 'Linear Algebra',
        ),
        throwsA(isA<DioException>()),
      );
    });
  });
}
