import 'package:equatable/equatable.dart';
import 'package:kortex/src/features/dashboard/domain/entities/dashboard_feed_entity.dart';

enum CurateCoursesStatus {
  initial,
  loading,
  loaded,
  submitting,
  success,
  error,
}

class CurateCoursesState extends Equatable {
  const CurateCoursesState({
    this.status = CurateCoursesStatus.initial,
    this.catalogCourses = const [],
    this.customCourses = const [],
    this.selectedCourseIds = const {},
    this.searchQuery = '',
    this.selectedCategory = 'All',
    this.errorMessage,
  });

  final CurateCoursesStatus status;
  final List<CuratedCourseEntity> catalogCourses;
  final List<CuratedCourseEntity> customCourses;
  final Set<String> selectedCourseIds;
  final String searchQuery;
  final String selectedCategory;
  final String? errorMessage;

  bool get isLoading =>
      status == CurateCoursesStatus.loading ||
      status == CurateCoursesStatus.initial;
  bool get isSubmitting => status == CurateCoursesStatus.submitting;

  /// Combined courses (catalog + user custom additions)
  List<CuratedCourseEntity> get allCourses {
    final ids = <String>{};
    final combined = <CuratedCourseEntity>[];
    for (final c in customCourses) {
      if (ids.add(c.id)) combined.add(c);
    }
    for (final c in catalogCourses) {
      if (ids.add(c.id)) combined.add(c);
    }
    return combined;
  }

  /// Filtered by category and search term
  List<CuratedCourseEntity> get filteredCourses {
    final query = searchQuery.trim().toLowerCase();
    return allCourses.where((course) {
      final matchesCategory = selectedCategory == 'All' ||
          course.department.toLowerCase().contains(selectedCategory.toLowerCase()) ||
          course.title.toLowerCase().contains(selectedCategory.toLowerCase());

      if (!matchesCategory) return false;

      if (query.isEmpty) return true;

      final codeMatch = course.courseCode.toLowerCase().contains(query);
      final titleMatch = course.title.toLowerCase().contains(query);
      final deptMatch = course.department.toLowerCase().contains(query);
      return codeMatch || titleMatch || deptMatch;
    }).toList();
  }

  CurateCoursesState copyWith({
    CurateCoursesStatus? status,
    List<CuratedCourseEntity>? catalogCourses,
    List<CuratedCourseEntity>? customCourses,
    Set<String>? selectedCourseIds,
    String? searchQuery,
    String? selectedCategory,
    String? errorMessage,
  }) {
    return CurateCoursesState(
      status: status ?? this.status,
      catalogCourses: catalogCourses ?? this.catalogCourses,
      customCourses: customCourses ?? this.customCourses,
      selectedCourseIds: selectedCourseIds ?? this.selectedCourseIds,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    catalogCourses,
    customCourses,
    selectedCourseIds,
    searchQuery,
    selectedCategory,
    errorMessage,
  ];
}
