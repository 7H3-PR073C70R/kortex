import 'package:flutter/material.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/board/course_overview_card.dart';

/// Helper utilities for grouping past questions by subject and mapping icons.
class BoardCourseGroupingHelper {
  const BoardCourseGroupingHelper._();

  static List<CourseSummary> groupQuestionsByCourse({
    required List<PastQuestionEntity> questions,
    required List<String> availableSubjects,
    required String selectedSubject,
    required String searchQuery,
  }) {
    final map = <String, List<PastQuestionEntity>>{};

    // Group questions by subject
    for (final q in questions) {
      map.putIfAbsent(q.subject, () => []).add(q);
    }

    // Ensure all known available subjects appear even if syncing questions
    for (final subj in availableSubjects) {
      if (subj != 'All' && !map.containsKey(subj)) {
        map[subj] = [];
      }
    }

    // Filter by selectedSubject if not 'All'
    final filteredEntries =
        map.entries.where((entry) {
          if (selectedSubject != 'All' &&
              !entry.key.toLowerCase().contains(
                    selectedSubject.toLowerCase(),
                  )) {
            return false;
          }
          if (searchQuery.isNotEmpty) {
            final query = searchQuery.toLowerCase();
            final matchSubject = entry.key.toLowerCase().contains(query);
            final matchTopic = entry.value.any(
              (q) =>
                  q.topic.toLowerCase().contains(query) ||
                  q.prompt.toLowerCase().contains(query),
            );
            return matchSubject || matchTopic;
          }
          return true;
        }).toList()
          ..sort((a, b) {
            final countCompare = b.value.length.compareTo(a.value.length);
            if (countCompare != 0) return countCompare;
            return a.key.compareTo(b.key);
          });

    return filteredEntries.map((e) {
      final qs = e.value;
      final years = qs.map((q) => q.year).toSet().toList()..sort();
      final yearRange = years.isEmpty
          ? 'All Years'
          : (years.length == 1
              ? '${years.first}'
              : '${years.first}–${years.last}');
      final answered = qs.where((q) => q.isAnswered).length;

      return CourseSummary(
        title: e.key,
        totalQuestions: qs.length,
        answeredQuestions: answered,
        yearRange: yearRange,
        iconData: getSubjectIcon(e.key),
        courseCode: qs.isNotEmpty ? qs.first.courseCode : null,
      );
    }).toList();
  }

  static IconData getSubjectIcon(String subject) {
    final lower = subject.toLowerCase();
    if (lower.contains('math') || lower.contains('calculus')) {
      return Icons.calculate_outlined;
    }
    if (lower.contains('physic')) return Icons.electric_bolt_outlined;
    if (lower.contains('chem')) return Icons.science_outlined;
    if (lower.contains('bio')) return Icons.biotech_outlined;
    if (lower.contains('english') || lower.contains('lit')) {
      return Icons.menu_book_rounded;
    }
    if (lower.contains('econ') ||
        lower.contains('acc') ||
        lower.contains('commerce')) {
      return Icons.trending_up_rounded;
    }
    if (lower.contains('gov') || lower.contains('civic')) {
      return Icons.account_balance_outlined;
    }
    if (lower.contains('comp') || lower.contains('cs')) {
      return Icons.terminal_rounded;
    }
    if (lower.contains('agric')) return Icons.agriculture_rounded;
    return Icons.school_outlined;
  }
}
