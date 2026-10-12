import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/dashboard/data/models/dashboard_feed_model.dart';

/// Reusable searchable dropdown for registered courses and subjects in the assessment planner.
class AssessmentSearchableCourseDropdown extends StatefulWidget {
  const AssessmentSearchableCourseDropdown({
    required this.courses,
    required this.selectedCourse,
    required this.onCourseSelected,
    super.key,
  });

  final List<CuratedCourseModel> courses;
  final CuratedCourseModel? selectedCourse;
  final ValueChanged<CuratedCourseModel> onCourseSelected;

  @override
  State<AssessmentSearchableCourseDropdown> createState() =>
      _AssessmentSearchableCourseDropdownState();
}

class _AssessmentSearchableCourseDropdownState
    extends State<AssessmentSearchableCourseDropdown> {
  bool _isExpanded = false;
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  String _searchQuery = '';
  late final ScrollController _dropdownScrollController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
    _dropdownScrollController = ScrollController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _dropdownScrollController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    AppFeedback.selection();
    setState(() {
      _isExpanded = !_isExpanded;
      if (!_isExpanded) {
        _searchController.clear();
        _searchQuery = '';
      }
    });

    if (_isExpanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _searchFocusNode.requestFocus();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final filtered = widget.courses.where((c) {
      if (_searchQuery.isEmpty) return true;
      return c.courseCode.toLowerCase().contains(_searchQuery) ||
          c.title.toLowerCase().contains(_searchQuery);
    }).toList();

    return TapRegion(
      onTapOutside: (_) {
        if (_isExpanded) {
          setState(() {
            _isExpanded = false;
            _searchController.clear();
            _searchQuery = '';
          });
        }
      },
      child: AnimatedContainer(
        duration: AppMotion.snappy,
        curve: AppMotion.easeOutCubic,
        decoration: BoxDecoration(
          color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
          borderRadius: AppRadius.radiusCard,
          border: Border.all(
            color: _isExpanded
                ? colors.primary
                : colors.surfaceBorder.withAlpha(isDark ? 80 : 40),
            width: _isExpanded ? 1.5 : 1,
          ),
          boxShadow: _isExpanded
              ? [
                  BoxShadow(
                    color: colors.primary.withAlpha(isDark ? 35 : 15),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: _toggleExpanded,
              borderRadius: _isExpanded
                  ? const BorderRadius.vertical(
                      top: Radius.circular(AppRadius.card),
                    )
                  : AppRadius.radiusCard,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Row(
                  children: [
                    Icon(
                      Icons.school_rounded,
                      color: colors.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Registered Course / Subject',
                            style: typography.caption.regular.copyWith(
                              color: colors.textSecondary,
                              fontSize: 11.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.selectedCourse != null
                                ? '${widget.selectedCourse!.courseCode} - ${widget.selectedCourse!.title}'
                                : 'Select a course or subject',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: typography.body.medium.copyWith(
                              color: widget.selectedCourse != null
                                  ? colors.textPrimary
                                  : colors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0.0,
                      duration: AppMotion.snappy,
                      curve: AppMotion.easeOutCubic,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: colors.textSecondary,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isExpanded) ...[
              Divider(
                height: 1,
                color: colors.surfaceBorder.withAlpha(isDark ? 80 : 40),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  style: typography.body.regular.copyWith(
                    color: colors.textPrimary,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Search course code or subject...',
                    hintStyle: typography.footnote.regular.copyWith(
                      color: colors.textSecondary.withAlpha(150),
                      fontSize: 12.5,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: colors.textSecondary,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 30,
                              minHeight: 30,
                            ),
                          )
                        : null,
                    filled: true,
                    fillColor: isDark
                        ? colors.surfacePrimary.withAlpha(160)
                        : colors.surfaceSecondary.withAlpha(120),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.radiusPanel,
                      borderSide: BorderSide(
                        color: colors.surfaceBorder.withAlpha(isDark ? 60 : 30),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: AppRadius.radiusPanel,
                      borderSide: BorderSide(
                        color: colors.surfaceBorder.withAlpha(isDark ? 60 : 30),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: AppRadius.radiusPanel,
                      borderSide: BorderSide(
                        color: colors.primary,
                        width: 1.2,
                      ),
                    ),
                  ),
                  onChanged: (val) {
                    setState(() => _searchQuery = val.trim().toLowerCase());
                  },
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 230),
                child: filtered.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 20,
                          horizontal: 16,
                        ),
                        child: Center(
                          child: Text(
                            "No courses match '$_searchQuery'",
                            style: typography.footnote.regular.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      )
                    : Scrollbar(
                        controller: _dropdownScrollController,
                        thumbVisibility: filtered.length > 5,
                        child: ListView.builder(
                          controller: _dropdownScrollController,
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final course = filtered[index];
                            final isSelected = course.id ==
                                    widget.selectedCourse?.id ||
                                course.courseCode ==
                                    widget.selectedCourse?.courseCode;

                            return InkWell(
                              onTap: () {
                                AppFeedback.selection();
                                widget.onCourseSelected(course);
                                setState(() {
                                  _isExpanded = false;
                                  _searchController.clear();
                                  _searchQuery = '';
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? colors.primary
                                          .withAlpha(isDark ? 40 : 20)
                                      : Colors.transparent,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? colors.primary
                                            : (isDark
                                                ? colors.surfacePrimary
                                                : colors.surfaceSecondary),
                                        borderRadius: AppRadius.radiusBadge,
                                        border: Border.all(
                                          color: isSelected
                                              ? colors.primary
                                              : colors.surfaceBorder.withAlpha(
                                                  isDark ? 60 : 35,
                                                ),
                                        ),
                                      ),
                                      child: Text(
                                        course.courseCode,
                                        style:
                                            typography.caption.bold.copyWith(
                                          color: isSelected
                                              ? colors.white
                                              : colors.textPrimary,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        course.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style:
                                            typography.body.regular.copyWith(
                                          color: isSelected
                                              ? colors.primary
                                              : colors.textPrimary,
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      Icon(
                                        Icons.check_rounded,
                                        size: 18,
                                        color: colors.primary,
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
              const SizedBox(height: 4),
            ],
          ],
        ),
      ),
    );
  }
}
