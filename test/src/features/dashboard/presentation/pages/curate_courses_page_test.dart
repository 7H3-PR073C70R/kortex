import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/dashboard/domain/entities/dashboard_feed_entity.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/curate_courses_cubit.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/curate_courses_state.dart';
import 'package:kortex/src/features/dashboard/presentation/pages/curate_courses_page.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/pump_app.dart';

class MockCurateCoursesCubit extends MockCubit<CurateCoursesState>
    implements CurateCoursesCubit {}

void main() {
  group('CurateCoursesPage Widget Tests', () {
    late MockCurateCoursesCubit mockCubit;

    const testCourses = [
      CuratedCourseEntity(
        id: 'c1',
        courseCode: 'MTH 101',
        title: 'General Mathematics',
        department: 'Sciences',
        totalMaterials: 4,
        hasActivePastPapers: true,
        iconName: 'math',
        colorHex: '#6366F1',
      ),
      CuratedCourseEntity(
        id: 'c2',
        courseCode: 'ENG 101',
        title: 'Use of English',
        department: 'Core',
        totalMaterials: 6,
        hasActivePastPapers: true,
        iconName: 'book',
        colorHex: '#10B981',
      ),
    ];

    setUp(() {
      mockCubit = MockCurateCoursesCubit();

      when(() => mockCubit.state).thenReturn(
        const CurateCoursesState(
          status: CurateCoursesStatus.loaded,
          catalogCourses: testCourses,
          selectedCourseIds: {'c1'},
        ),
      );
      when(() => mockCubit.loadCatalog(
            currentlyEnrolledIds: any(named: 'currentlyEnrolledIds'),
            userTrack: any(named: 'userTrack'),
          )).thenAnswer((_) async {});
    });

    testWidgets('renders search header, course select tiles, and save dock',
        (tester) async {
      await tester.pumpApp(
        CurateCoursesPage(
          userTrack: 'WAEC',
          curateCoursesCubit: mockCubit,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CurateCoursesSearchHeader), findsOneWidget);
      expect(find.text('Active Academic Track: WAEC'), findsOneWidget);
      expect(find.byType(CourseSelectTile), findsNWidgets(2));
      expect(find.text('MTH 101'), findsOneWidget);
      expect(find.text('ENG 101'), findsOneWidget);
      expect(find.byType(CurateCoursesSaveDock), findsOneWidget);
      expect(find.text('Save 1 Course'), findsOneWidget);
    });

    testWidgets('toggles course selection when tile tapped', (tester) async {
      when(() => mockCubit.toggleCourseSelection('c2')).thenReturn(null);

      await tester.pumpApp(
        CurateCoursesPage(
          userTrack: 'WAEC',
          curateCoursesCubit: mockCubit,
        ),
      );
      await tester.pumpAndSettle();

      final engTile = find.text('ENG 101');
      await tester.tap(engTile);
      await tester.pumpAndSettle();

      verify(() => mockCubit.toggleCourseSelection('c2')).called(1);
    });

    testWidgets('calls saveCuratedCourses when save dock button is tapped',
        (tester) async {
      when(() => mockCubit.saveCuratedCourses()).thenAnswer((_) async {});

      await tester.pumpApp(
        CurateCoursesPage(
          userTrack: 'WAEC',
          curateCoursesCubit: mockCubit,
        ),
      );
      await tester.pumpAndSettle();

      final saveButton = find.text('Save 1 Course');
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      verify(() => mockCubit.saveCuratedCourses()).called(1);
    });
  });
}
