import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/features/onboarding_calibration/data/data_sources/curriculum_remote_data_source.dart';
import 'package:kortex/src/features/onboarding_calibration/data/models/curriculum_metadata_model.dart';
import 'package:kortex/src/features/onboarding_calibration/data/repositories/curriculum_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

class MockCurriculumRemoteDataSource extends Mock
    implements CurriculumRemoteDataSource {}

void main() {
  late MockCurriculumRemoteDataSource mockRemoteDataSource;
  late CurriculumRepositoryImpl repository;

  setUp(() {
    mockRemoteDataSource = MockCurriculumRemoteDataSource();
    repository = CurriculumRepositoryImpl(mockRemoteDataSource);
  });

  group('CurriculumRepositoryImpl', () {
    const tModels = [
      CurriculumMetadataModel(
        id: '1',
        category: 'standardized_exam',
        key: 'jamb',
        displayName: 'JAMB / UTME',
        metadata: {'subtitle': 'UTME Exam'},
      ),
      CurriculumMetadataModel(
        id: '2',
        category: 'faculty_track',
        key: 'cs',
        displayName: 'Computer Science',
      ),
    ];

    test('getMetadataByCategory returns entities on success', () async {
      when(() => mockRemoteDataSource.fetchMetadataByCategory('standardized_exam'))
          .thenAnswer((_) async => [tModels.first]);

      final result = await repository.getMetadataByCategory('standardized_exam');

      expect(result.isRight, isTrue);
      result.fold(
        (_) => fail('Should have succeeded'),
        (entities) {
          expect(entities.length, equals(1));
          expect(entities.first.key, equals('jamb'));
          expect(entities.first.displayName, equals('JAMB / UTME'));
          expect(entities.first.subtitle, equals('UTME Exam'));
        },
      );
      verify(() => mockRemoteDataSource.fetchMetadataByCategory('standardized_exam'))
          .called(1);
    });

    test('getMetadataByCategory returns ServerFailure on error', () async {
      when(() => mockRemoteDataSource.fetchMetadataByCategory('standardized_exam'))
          .thenThrow(Exception('Network error'));

      final result = await repository.getMetadataByCategory('standardized_exam');

      expect(result.isLeft, isTrue);
      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (_) => fail('Should have failed'),
      );
    });

    test('getAllMetadata groups items by category on success', () async {
      when(() => mockRemoteDataSource.fetchAllMetadata())
          .thenAnswer((_) async => tModels);

      final result = await repository.getAllMetadata();

      expect(result.isRight, isTrue);
      result.fold(
        (_) => fail('Should have succeeded'),
        (grouped) {
          expect(grouped.containsKey('standardized_exam'), isTrue);
          expect(grouped.containsKey('faculty_track'), isTrue);
          expect(grouped['standardized_exam']!.length, equals(1));
          expect(grouped['faculty_track']!.length, equals(1));
        },
      );
      verify(() => mockRemoteDataSource.fetchAllMetadata()).called(1);
    });

    test('getAllMetadata returns ServerFailure on exception', () async {
      when(() => mockRemoteDataSource.fetchAllMetadata())
          .thenThrow(Exception('Timeout'));

      final result = await repository.getAllMetadata();

      expect(result.isLeft, isTrue);
      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (_) => fail('Should have failed'),
      );
    });
  });
}
