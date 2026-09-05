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
  List<CuratedCourseEntity> get allCourses {
    final ids = <String>{};
    final combined = <CuratedCourseEntity>[];
    for (final c in customCourses) {
      if (ids.add(c.id)) combined.add(c);
    }
    for (final c in catalogCourses) {
      if (ids.add(c.id)) combined.add(c);
    }

    if (activeTrack.isEmpty || activeTrack == 'All') {
      return combined;
    }

    final trackUpper = activeTrack.toUpperCase();
    final isWaec = trackUpper.contains('WAEC') || trackUpper.contains('WASSCE');
    final isJamb = trackUpper.contains('JAMB') || trackUpper.contains('UTME');
    final isSat = trackUpper.contains('SAT');

    final trackFiltered = combined.where((c) {
      // Custom courses added by user are always shown
      if (c.id.startsWith('custom_')) return true;

      final deptUpper = c.department.toUpperCase();
      final codeUpper = c.courseCode.toUpperCase();
      final titleUpper = c.title.toUpperCase();

      if (isWaec) {
        final isJambCourse =
            deptUpper.contains('JAMB') || codeUpper.startsWith('J-');
        final isSatCourse =
            deptUpper.contains('SAT') || codeUpper.startsWith('SAT-');
        if (isJambCourse || isSatCourse) return false;
        return deptUpper.contains('WAEC') ||
            codeUpper.startsWith('W-') ||
            titleUpper.contains('WAEC');
      }

      if (isJamb) {
        final isWaecCourse =
            deptUpper.contains('WAEC') || codeUpper.startsWith('W-');
        final isSatCourse =
            deptUpper.contains('SAT') || codeUpper.startsWith('SAT-');
        if (isWaecCourse || isSatCourse) return false;
        return deptUpper.contains('JAMB') ||
            codeUpper.startsWith('J-') ||
            titleUpper.contains('JAMB');
      }

      if (isSat) {
        return deptUpper.contains('SAT') ||
            codeUpper.startsWith('SAT-') ||
            titleUpper.contains('SAT');
      }

      // Faculty / Department track (e.g. Computer Science, Medicine, Law)
      final isHighSchoolExam = deptUpper.contains('WAEC') ||
          deptUpper.contains('JAMB') ||
          deptUpper.contains('SAT') ||
          codeUpper.startsWith('W-') ||
          codeUpper.startsWith('J-') ||
          codeUpper.startsWith('SAT-');
      if (isHighSchoolExam) return false;

      final keyword = activeTrack.trim().toLowerCase();
      return deptUpper.contains(keyword) ||
          titleUpper.contains(keyword) ||
          codeUpper.contains(keyword);
    }).toList();

    return trackFiltered.isNotEmpty ? trackFiltered : combined;
  }

  /// Filtered by category and search term
  List<CuratedCourseEntity> get filteredCourses {
    final query = searchQuery.trim().toLowerCase();

    // If searching explicitly, search across all available courses.
    // When browsing categories without search, restrict strictly to active track's courses.
    final sourceList = query.isNotEmpty
        ? [
            ...customCourses,
            ...catalogCourses.where(
              (c) => !customCourses.any((x) => x.id == c.id),
            ),
          ]
        : allCourses;

    return sourceList.where((course) {
      final deptLower = course.department.toLowerCase();
      final titleLower = course.title.toLowerCase();

      final matchesCategory = selectedCategory == 'All' ||
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
