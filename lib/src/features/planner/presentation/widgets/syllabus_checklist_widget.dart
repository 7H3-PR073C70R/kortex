import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/shared/widgets/app_badge.dart';

/// Topic item within the curriculum syllabus.
class SyllabusTopic {
  const SyllabusTopic({
    required this.id,
    required this.title,
    required this.subject,
    required this.weightPercent,
    this.isMastered = false,
    this.totalSubtopics = 5,
    this.completedSubtopics = 0,
  });

  final String id;
  final String title;
  final String subject;
  final int weightPercent;
  final bool isMastered;
  final int totalSubtopics;
  final int completedSubtopics;

  SyllabusTopic copyWith({
    String? id,
    String? title,
    String? subject,
    int? weightPercent,
    bool? isMastered,
    int? totalSubtopics,
    int? completedSubtopics,
  }) {
    return SyllabusTopic(
      id: id ?? this.id,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      weightPercent: weightPercent ?? this.weightPercent,
      isMastered: isMastered ?? this.isMastered,
      totalSubtopics: totalSubtopics ?? this.totalSubtopics,
      completedSubtopics: completedSubtopics ?? this.completedSubtopics,
    );
  }
}

/// Interactive checklist tracking curriculum syllabus topics mapped to exam papers (PLN-07).
class SyllabusChecklistWidget extends HookWidget {
  const SyllabusChecklistWidget({
    super.key,
    required this.topics,
    this.onTopicToggled,
  });

  final List<SyllabusTopic> topics;
  final void Function(SyllabusTopic topic, bool isMastered)? onTopicToggled;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    final topicList = useState<List<SyllabusTopic>>(topics);
    final subjects = useMemoized(() {
      final s = {'All', ...topics.map((t) => t.subject)};
      return s.toList();
    }, [topics]);

    final selectedSubject = useState<String>('All');

    final filteredTopics = topicList.value.where((t) {
      if (selectedSubject.value == 'All') return true;
      return t.subject == selectedSubject.value;
    }).toList();

    final totalMastered = topicList.value.where((t) => t.isMastered).length;
    final overallProgress = topicList.value.isEmpty
        ? 0.0
        : totalMastered / topicList.value.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress Summary Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surfacePrimary,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.surfaceBorder.withOpacity(0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Syllabus Topic Mastery',
                    style: typography.body.bold.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  Text(
                    '$totalMastered of ${topicList.value.length} Topics (${(overallProgress * 100).toInt()}%)',
                    style: typography.caption.regular.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: overallProgress,
                backgroundColor: colors.surfaceSecondary,
                valueColor: AlwaysStoppedAnimation<Color>(
                  overallProgress == 1.0 ? colors.success : colors.primary,
                ),
                borderRadius: BorderRadius.circular(6),
                minHeight: 8,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Subject Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: subjects.map((subject) {
              final isSelected = selectedSubject.value == subject;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(subject),
                  selected: isSelected,
                  onSelected: (_) {
                    AppFeedback.selection();
                    selectedSubject.value = subject;
                  },
                  backgroundColor: colors.surfacePrimary,
                  selectedColor: colors.primary.withOpacity(0.18),
                  labelStyle: typography.caption.regular.copyWith(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? colors.primary : colors.textPrimary,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: isSelected ? colors.primary : colors.surfaceBorder.withOpacity(0.5),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        // Topics List
        Expanded(
          child: ListView.builder(
            itemCount: filteredTopics.length,
            itemBuilder: (context, index) {
              final topic = filteredTopics[index];
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: colors.surfacePrimary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: topic.isMastered
                        ? colors.success.withOpacity(0.3)
                        : colors.surfaceBorder.withOpacity(0.5),
                  ),
                ),
                child: CheckboxListTile(
                  value: topic.isMastered,
                  activeColor: colors.success,
                  onChanged: (val) {
                    final nextVal = val ?? false;
                    AppFeedback.selection();
                    final nextList = topicList.value.map((t) {
                      if (t.id == topic.id) {
                        return t.copyWith(isMastered: nextVal);
                      }
                      return t;
                    }).toList();
                    topicList.value = nextList;
                    onTopicToggled?.call(topic, nextVal);
                  },
                  title: Text(
                    topic.title,
                    style: typography.body.medium.copyWith(
                      fontWeight: FontWeight.w600,
                      decoration: topic.isMastered ? TextDecoration.lineThrough : null,
                      color: topic.isMastered ? colors.textSecondary : colors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    '${topic.subject} • ${topic.weightPercent}% exam weight',
                    style: typography.caption.regular.copyWith(color: colors.textSecondary),
                  ),
                  secondary: AppBadge(
                    label: '${topic.weightPercent}%',
                    variant: topic.isMastered ? AppBadgeVariant.success : AppBadgeVariant.outline,
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
