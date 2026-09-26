import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/onboarding_calibration/data/data_sources/curriculum_remote_data_source_impl.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio mockDio;
  late CurriculumRemoteDataSourceImpl dataSource;

  setUp(() {
    mockDio = MockDio();
    dataSource = CurriculumRemoteDataSourceImpl(mockDio);
  });

  group('CurriculumRemoteDataSourceImpl', () {
    test('fetchMetadataByCategory returns parsed models on successful Dio response', () async {
      when(
        () => mockDio.get<dynamic>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(),
          statusCode: 200,
          data: [
            {
              'id': 'test-id-1',
              'category': 'standardized_exam',
              'key': 'jamb',
              'display_name': 'JAMB / UTME',
              'metadata': {'subtitle': 'Test Subtitle'},
              'is_active': true,
            }
          ],
        ),
      );

      final result = await dataSource.fetchMetadataByCategory('standardized_exam');

      expect(result.length, equals(1));
      expect(result.first.key, equals('jamb'));
      expect(result.first.displayName, equals('JAMB / UTME'));
    });

    test('fetchMetadataByCategory returns empty list on Dio exception', () async {
      when(
        () => mockDio.get<dynamic>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(),
          error: 'Connection refused',
        ),
      );

      final result = await dataSource.fetchMetadataByCategory('standardized_exam');

      expect(result.isEmpty, isTrue);
    });

    test('fetchAllMetadata returns parsed models on successful Dio response', () async {
      when(
        () => mockDio.get<dynamic>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(),
          statusCode: 200,
          data: [
            {
              'id': 'exam-1',
              'category': 'standardized_exam',
              'key': 'sat',
              'display_name': 'College Board SAT',
            },
            {
              'id': 'track-1',
              'category': 'faculty_track',
              'key': 'cs',
              'display_name': 'Computer Science',
            },
          ],
        ),
      );

      final result = await dataSource.fetchAllMetadata();

      expect(result.length, equals(2));
      expect(result[0].key, equals('sat'));
      expect(result[1].key, equals('cs'));
    });

    test('fetchAllMetadata returns empty list on network error', () async {
      when(
        () => mockDio.get<dynamic>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(),
          error: 'Offline',
        ),
      );

      final result = await dataSource.fetchAllMetadata();

      expect(result.isEmpty, isTrue);
    });
  });
}
