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
    final isNeco = trackUpper.contains('NECO') || trackUpper.contains('SSCE');
    final isSat = trackUpper.contains('SAT');

    final trackFiltered = combined.where((c) {
      // Custom courses added by user are always shown
      if (c.id.startsWith('custom_')) return true;

      final deptUpper = c.department.toUpperCase();
      final idLower = c.id.toLowerCase();

      if (isWaec) {
        if (deptUpper.contains('JAMB') || idLower.startsWith('jamb-')) return false;
        if (deptUpper.contains('NECO') || idLower.startsWith('neco-')) return false;
        if (deptUpper.contains('SAT') || idLower.startsWith('sat-')) return false;
        return deptUpper.contains('WAEC') || idLower.startsWith('waec-');
      }

      if (isJamb) {
        if (deptUpper.contains('WAEC') || idLower.startsWith('waec-')) return false;
        if (deptUpper.contains('NECO') || idLower.startsWith('neco-')) return false;
        if (deptUpper.contains('SAT') || idLower.startsWith('sat-')) return false;
        return deptUpper.contains('JAMB') || idLower.startsWith('jamb-');
      }

      if (isNeco) {
        if (deptUpper.contains('WAEC') || idLower.startsWith('waec-')) return false;
        if (deptUpper.contains('JAMB') || idLower.startsWith('jamb-')) return false;
        if (deptUpper.contains('SAT') || idLower.startsWith('sat-')) return false;
        return deptUpper.contains('NECO') || idLower.startsWith('neco-');
      }

      if (isSat) {
        return deptUpper.contains('SAT') || idLower.startsWith('sat-');
      }

      // Higher Education / Polytechnic / Vocational / Post-Secondary tracks
      // (BSC, MSC, PhD, OND I/II, HND I/II, Vocational, Professional, etc.)
      final isHighSchoolExam = deptUpper.contains('WAEC') ||
          deptUpper.contains('JAMB') ||
          deptUpper.contains('NECO') ||
          deptUpper.contains('SAT') ||
          idLower.startsWith('waec-') ||
          idLower.startsWith('jamb-') ||
          idLower.startsWith('neco-') ||
          idLower.startsWith('sat-');
      return !isHighSchoolExam;
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
