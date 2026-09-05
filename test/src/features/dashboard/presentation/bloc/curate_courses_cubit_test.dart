import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/core/utils/use_case.dart';
import 'package:kortex/src/features/dashboard/domain/entities/dashboard_feed_entity.dart';
import 'package:kortex/src/features/dashboard/domain/use_cases/get_curated_courses_catalog_use_case.dart';
import 'package:kortex/src/features/dashboard/domain/use_cases/sync_user_courses_use_case.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/curate_courses_cubit.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/curate_courses_state.dart';
import 'package:mocktail/mocktail.dart';

class MockGetCuratedCoursesCatalogUseCase extends Mock
    implements GetCuratedCoursesCatalogUseCase {}

class MockSyncUserCoursesUseCase extends Mock
    implements SyncUserCoursesUseCase {}

void main() {
  late MockGetCuratedCoursesCatalogUseCase mockGetCatalogUseCase;
  late MockSyncUserCoursesUseCase mockSyncUseCase;

  final sampleCourses = [
    const CuratedCourseEntity(
      id: 'course_1',
      courseCode: 'CS 101',
      title: 'Introduction to Computer Science',
      department: 'Computer Science',
      totalMaterials: 10,
      hasActivePastPapers: true,
      iconName: 'code',
      colorHex: '#3B82F6',
    ),
    const CuratedCourseEntity(
      id: 'course_2',
      courseCode: 'ENG 101',
      title: 'Academic Writing & Literature',
      department: 'English & Literary Studies',
      totalMaterials: 12,
      hasActivePastPapers: false,
      iconName: 'menu_book',
      colorHex: '#EC4899',
    ),
  ];

  setUpAll(() {
    registerFallbackValue(const NoParams());
    registerFallbackValue(
      const SyncUserCoursesParams(courses: []),
    );
  });

  setUp(() {
    mockGetCatalogUseCase = MockGetCuratedCoursesCatalogUseCase();
    mockSyncUseCase = MockSyncUserCoursesUseCase();
  });

  group('CurateCoursesCubit Test Suite', () {
    test('initial state has correct defaults', () {
      final cubit = CurateCoursesCubit(
        getCatalogUseCase: mockGetCatalogUseCase,
        syncCoursesUseCase: mockSyncUseCase,
      );

      expect(cubit.state.status, equals(CurateCoursesStatus.initial));
      expect(cubit.state.catalogCourses, isEmpty);
      expect(cubit.state.selectedCourseIds, isEmpty);
      expect(cubit.state.searchQuery, isEmpty);
      expect(cubit.state.selectedCategory, equals('All'));
    });

    blocTest<CurateCoursesCubit, CurateCoursesState>(
      'loadCatalog emits loaded state with courses and pre-selected IDs',
      build: () {
        when(() => mockGetCatalogUseCase(any())).thenAnswer(
          (_) async => Right(sampleCourses),
        );
        return CurateCoursesCubit(
          getCatalogUseCase: mockGetCatalogUseCase,
          syncCoursesUseCase: mockSyncUseCase,
        );
      },
      act: (cubit) => cubit.loadCatalog(currentlyEnrolledIds: ['course_1']),
      expect: () => [
        const CurateCoursesState(status: CurateCoursesStatus.loading),
        CurateCoursesState(
          status: CurateCoursesStatus.loaded,
          catalogCourses: sampleCourses,
          selectedCourseIds: const {'course_1'},
        ),
      ],
      verify: (_) {
        verify(() => mockGetCatalogUseCase(any())).called(1);
      },
    );

    blocTest<CurateCoursesCubit, CurateCoursesState>(
      'loadCatalog emits error when usecase fails',
      build: () {
        when(() => mockGetCatalogUseCase(any())).thenAnswer(
          (_) async => const Left(ServerFailure(message: 'Failed to fetch')),
        );
        return CurateCoursesCubit(
          getCatalogUseCase: mockGetCatalogUseCase,
          syncCoursesUseCase: mockSyncUseCase,
        );
      },
      act: (cubit) => cubit.loadCatalog(),
      expect: () => [
        const CurateCoursesState(status: CurateCoursesStatus.loading),
        const CurateCoursesState(
          status: CurateCoursesStatus.error,
          errorMessage: 'Failed to fetch',
        ),
      ],
    );

    blocTest<CurateCoursesCubit, CurateCoursesState>(
      'setSearchQuery and selectCategory update filtering criteria',
      build: () => CurateCoursesCubit(
        getCatalogUseCase: mockGetCatalogUseCase,
        syncCoursesUseCase: mockSyncUseCase,
      ),
      act: (cubit) {
        cubit..setSearchQuery('CS')
        ..selectCategory('Engineering & Tech');
      },
      expect: () => [
        const CurateCoursesState(searchQuery: 'CS'),
        const CurateCoursesState(
          searchQuery: 'CS',
          selectedCategory: 'Engineering & Tech',
        ),
      ],
    );

    blocTest<CurateCoursesCubit, CurateCoursesState>(
      'toggleCourseSelection toggles selection on and off',
      build: () => CurateCoursesCubit(
        getCatalogUseCase: mockGetCatalogUseCase,
        syncCoursesUseCase: mockSyncUseCase,
      ),
      act: (cubit) {
        cubit..toggleCourseSelection('course_1')
        ..toggleCourseSelection('course_2')
        ..toggleCourseSelection('course_1');
      },
      expect: () => [
        const CurateCoursesState(selectedCourseIds: {'course_1'}),
        const CurateCoursesState(
          selectedCourseIds: {'course_1', 'course_2'},
        ),
        const CurateCoursesState(selectedCourseIds: {'course_2'}),
      ],
    );

    blocTest<CurateCoursesCubit, CurateCoursesState>(
      'addCustomCourse provisions a new course and selects it',
      build: () => CurateCoursesCubit(
        getCatalogUseCase: mockGetCatalogUseCase,
        syncCoursesUseCase: mockSyncUseCase,
      ),
      act: (cubit) => cubit.addCustomCourse(
        courseCode: 'law 201',
        title: 'Constitutional Law',
        department: 'Faculty of Law',
      ),
      verify: (cubit) {
        expect(cubit.state.customCourses, hasLength(1));
        final created = cubit.state.customCourses.first;
        expect(created.courseCode, equals('LAW 201'));
        expect(created.title, equals('Constitutional Law'));
        expect(created.department, equals('Faculty of Law'));
        expect(cubit.state.selectedCourseIds.contains(created.id), isTrue);
      },
    );

    blocTest<CurateCoursesCubit, CurateCoursesState>(
      'saveCuratedCourses successfully syncs selected courses and emits success',
      seed: () => CurateCoursesState(
        status: CurateCoursesStatus.loaded,
        catalogCourses: sampleCourses,
        selectedCourseIds: const {'course_1'},
      ),
      build: () {
        when(() => mockSyncUseCase(any())).thenAnswer(
          (_) async => const Right(null),
        );
        return CurateCoursesCubit(
          getCatalogUseCase: mockGetCatalogUseCase,
          syncCoursesUseCase: mockSyncUseCase,
        );
      },
      act: (cubit) => cubit.saveCuratedCourses(),
      expect: () => [
        CurateCoursesState(
          status: CurateCoursesStatus.submitting,
          catalogCourses: sampleCourses,
          selectedCourseIds: const {'course_1'},
        ),
        CurateCoursesState(
          status: CurateCoursesStatus.success,
          catalogCourses: sampleCourses,
          selectedCourseIds: const {'course_1'},
        ),
      ],
      verify: (_) {
        verify(() => mockSyncUseCase(any())).called(1);
      },
    );

    test('activeTrack strictly filters courses to target track and excludes other exam tracks', () {
      final mixedCatalog = [
        const CuratedCourseEntity(
          id: 'waec-mth',
          courseCode: 'MTH',
          title: 'Mathematics',
          department: 'WAEC - Core',
          totalMaterials: 20,
          hasActivePastPapers: true,
          iconName: 'calculate',
          colorHex: '#6366F1',
        ),
        const CuratedCourseEntity(
          id: 'jamb-mth',
          courseCode: 'MTH',
          title: 'Mathematics',
          department: 'JAMB - Core',
          totalMaterials: 20,
          hasActivePastPapers: true,
          iconName: 'calculate',
          colorHex: '#6366F1',
        ),
        const CuratedCourseEntity(
          id: 'neco-mth',
          courseCode: 'MTH',
          title: 'Mathematics',
          department: 'NECO - Core',
          totalMaterials: 20,
          hasActivePastPapers: true,
          iconName: 'calculate',
          colorHex: '#6366F1',
        ),
        const CuratedCourseEntity(
          id: 'waec-bio',
          courseCode: 'BIO',
          title: 'Biology',
          department: 'WAEC - Sciences',
          totalMaterials: 15,
          hasActivePastPapers: true,
          iconName: 'eco',
          colorHex: '#10B981',
        ),
        const CuratedCourseEntity(
          id: 'neco-bio',
          courseCode: 'BIO',
          title: 'Biology',
          department: 'NECO - Sciences',
          totalMaterials: 15,
          hasActivePastPapers: true,
          iconName: 'eco',
          colorHex: '#10B981',
        ),
        const CuratedCourseEntity(
          id: 'jamb-eng',
          courseCode: 'ENG',
          title: 'English Language',
          department: 'JAMB - Core',
          totalMaterials: 25,
          hasActivePastPapers: true,
          iconName: 'auto_stories',
          colorHex: '#F59E0B',
        ),
      ];

      final waecState = CurateCoursesState(
        status: CurateCoursesStatus.loaded,
        catalogCourses: mixedCatalog,
      );

      final waecCourses = waecState.filteredCourses;
      expect(waecCourses.length, equals(2));
      expect(waecCourses.every((c) => c.department.startsWith('WAEC')), isTrue);
      expect(waecCourses.any((c) => c.department.startsWith('JAMB')), isFalse);
      expect(waecCourses.any((c) => c.department.startsWith('NECO')), isFalse);

      final jambState = CurateCoursesState(
        status: CurateCoursesStatus.loaded,
        catalogCourses: mixedCatalog,
        activeTrack: 'JAMB',
      );

      final jambCourses = jambState.filteredCourses;
      expect(jambCourses.length, equals(2));
      expect(jambCourses.every((c) => c.department.startsWith('JAMB')), isTrue);
      expect(jambCourses.any((c) => c.department.startsWith('WAEC')), isFalse);
      expect(jambCourses.any((c) => c.department.startsWith('NECO')), isFalse);

      final necoState = CurateCoursesState(
        status: CurateCoursesStatus.loaded,
        catalogCourses: mixedCatalog,
        activeTrack: 'NECO',
      );

      final necoCourses = necoState.filteredCourses;
      expect(necoCourses.length, equals(2));
      expect(necoCourses.every((c) => c.department.startsWith('NECO')), isTrue);
      expect(necoCourses.any((c) => c.department.startsWith('WAEC')), isFalse);
      expect(necoCourses.any((c) => c.department.startsWith('JAMB')), isFalse);
    });
  });
}
