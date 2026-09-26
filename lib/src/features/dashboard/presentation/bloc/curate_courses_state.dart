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
    this.activeTrack = 'WAEC',
    this.errorMessage,
  });

  final CurateCoursesStatus status;
  final List<CuratedCourseEntity> catalogCourses;
  final List<CuratedCourseEntity> customCourses;
  final Set<String> selectedCourseIds;
  final String searchQuery;
  final String selectedCategory;
  final String activeTrack;
  final String? errorMessage;

  bool get isLoading =>
      status == CurateCoursesStatus.loading ||
      status == CurateCoursesStatus.initial;
  bool get isSubmitting => status == CurateCoursesStatus.submitting;

  /// Combined courses (catalog + user custom additions), strictly filtered to the user's active academic track.
  /// Combined courses (catalog + user custom additions), unified as single subjects regardless of track.
  List<CuratedCourseEntity> get allCourses {
    final ids = <String>{};
    final combined = <CuratedCourseEntity>[];
    for (final c in customCourses) {
      if (ids.add(c.id)) combined.add(c);
    }
    for (final c in catalogCourses) {
      if (ids.add(c.id)) combined.add(c);
    }

    // Deduplicate any duplicate course codes or identical subjects
    final seenKeys = <String>{};
    final deduplicated = <CuratedCourseEntity>[];
    for (final c in combined) {
      final normCode = c.courseCode.replaceAll(RegExp('[^A-Z0-9]'), '').toUpperCase();
      final normTitle = c.title.trim().toLowerCase();
      final key = normCode.isNotEmpty ? normCode : normTitle;
      if (seenKeys.add(key)) {
        deduplicated.add(c);
      }
    }

    return deduplicated;
  }

  /// Filtered by category and search term within active track's courses
  List<CuratedCourseEntity> get filteredCourses {
    final query = searchQuery.trim().toLowerCase();

    // Strictly search and browse within the track-filtered list to prevent cross-track pollution
    final sourceList = allCourses;

    return sourceList.where((course) {
      final deptLower = course.department.toLowerCase();
      final titleLower = course.title.toLowerCase();

      final matchesCategory =
          selectedCategory == 'All' ||
          deptLower.contains(selectedCategory.toLowerCase()) ||
          titleLower.contains(selectedCategory.toLowerCase());

      if (!matchesCategory) return false;

      if (query.isEmpty) return true;

      final codeMatch = course.courseCode.toLowerCase().contains(query);
      final titleMatch = titleLower.contains(query);
      final deptMatch = deptLower.contains(query);
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
    String? activeTrack,
    String? errorMessage,
  }) {
    return CurateCoursesState(
      status: status ?? this.status,
      catalogCourses: catalogCourses ?? this.catalogCourses,
      customCourses: customCourses ?? this.customCourses,
      selectedCourseIds: selectedCourseIds ?? this.selectedCourseIds,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      activeTrack: activeTrack ?? this.activeTrack,
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
    activeTrack,
    errorMessage,
  ];
}
