import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:kortex/src/core/utils/use_case.dart';
import 'package:kortex/src/features/dashboard/domain/entities/dashboard_feed_entity.dart';
import 'package:kortex/src/features/dashboard/domain/use_cases/get_curated_courses_catalog_use_case.dart';
import 'package:kortex/src/features/dashboard/domain/use_cases/sync_user_courses_use_case.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/curate_courses_state.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_event.dart';

class CurateCoursesCubit extends Cubit<CurateCoursesState> {
  CurateCoursesCubit({
    required this.getCatalogUseCase,
    required this.syncCoursesUseCase,
    this.dashboardBloc,
  }) : super(const CurateCoursesState());

  final GetCuratedCoursesCatalogUseCase getCatalogUseCase;
  final SyncUserCoursesUseCase syncCoursesUseCase;
  final DashboardBloc? dashboardBloc;

  Future<void> loadCatalog({
    List<String> currentlyEnrolledIds = const [],
    String? userTrack,
  }) async {
    final track = (userTrack != null && userTrack.trim().isNotEmpty)
        ? userTrack.trim()
        : state.activeTrack;

    emit(
      state.copyWith(
        status: CurateCoursesStatus.loading,
        activeTrack: track,
      ),
    );

    final result = await getCatalogUseCase(const NoParams());
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: CurateCoursesStatus.error,
          errorMessage: failure.message ?? 'Failed to load course catalog.',
        ),
      ),
      (courses) {
        emit(
          state.copyWith(
            status: CurateCoursesStatus.loaded,
            catalogCourses: courses,
            selectedCourseIds: currentlyEnrolledIds.toSet(),
          ),
        );
      },
    );
  }

  void toggleCourseSelection(String courseId) {
    final updated = Set<String>.from(state.selectedCourseIds);
    if (updated.contains(courseId)) {
      updated.remove(courseId);
    } else {
      updated.add(courseId);
    }
    emit(state.copyWith(selectedCourseIds: updated));
  }

  void setSearchQuery(String query) {
    emit(state.copyWith(searchQuery: query));
  }

  void selectCategory(String category) {
    emit(state.copyWith(selectedCategory: category));
  }

  void addCustomCourse({
    required String courseCode,
    required String title,
    required String department,
  }) {
    final newId = 'custom_${DateTime.now().millisecondsSinceEpoch}';
    final customCourse = CuratedCourseEntity(
      id: newId,
      courseCode: courseCode.trim().toUpperCase(),
      title: title.trim(),
      department: department.trim().isEmpty ? 'General Studies' : department.trim(),
      totalMaterials: 1,
      hasActivePastPapers: false,
      iconName: 'school',
      colorHex: '#6366F1',
      syllabusCoverage: 0,
    );

    final updatedCustom = List<CuratedCourseEntity>.from(state.customCourses)
      ..insert(0, customCourse);
    final updatedSelected = Set<String>.from(state.selectedCourseIds)
      ..add(newId);

    emit(
      state.copyWith(
        customCourses: updatedCustom,
        selectedCourseIds: updatedSelected,
        searchQuery: '',
      ),
    );
  }

  Future<void> saveCuratedCourses() async {
    if (state.isSubmitting) return;
    emit(state.copyWith(status: CurateCoursesStatus.submitting));

    final coursesToSync = <Map<String, dynamic>>[];
    for (final course in state.allCourses) {
      if (state.selectedCourseIds.contains(course.id)) {
        coursesToSync.add({
          if (!course.id.startsWith('custom_')) 'id': course.id,
          'courseCode': course.courseCode,
          'title': course.title,
          'department': course.department,
          'totalMaterials': course.totalMaterials,
          'hasActivePastPapers': course.hasActivePastPapers,
          'iconName': course.iconName,
          'colorHex': course.colorHex,
          'syllabusCoverage': course.syllabusCoverage,
        });
      }
    }

    final result = await syncCoursesUseCase(
      SyncUserCoursesParams(courses: coursesToSync),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: CurateCoursesStatus.error,
          errorMessage: failure.message ?? 'Failed to save courses.',
        ),
      ),
      (_) {
        dashboardBloc?.add(const DashboardRefreshed());
        emit(state.copyWith(status: CurateCoursesStatus.success));
      },
    );
  }
}
