import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_sheet.dart';

class QuizForumQuestionSelectorSheet extends StatefulWidget {
  const QuizForumQuestionSelectorSheet({
    required this.questions,
    required this.missedQuestions,
    required this.onConfirm,
    super.key,
  });

  final List<QuizQuestionEntity> questions;
  final List<QuizQuestionEntity> missedQuestions;
  final ValueChanged<List<QuizQuestionEntity>> onConfirm;

  @override
  State<QuizForumQuestionSelectorSheet> createState() =>
      _QuizForumQuestionSelectorSheetState();
}

class _QuizForumQuestionSelectorSheetState
    extends State<QuizForumQuestionSelectorSheet> {
  bool _isMultipleMode = false;
  late int _selectedSingleIndex;
  late Set<int> _selectedMultipleIndices;

  @override
  void initState() {
    super.initState();
    final firstMissedIdx = widget.missedQuestions.isNotEmpty
        ? widget.questions.indexOf(widget.missedQuestions.first)
        : 0;
    _selectedSingleIndex = firstMissedIdx >= 0 ? firstMissedIdx : 0;

    _selectedMultipleIndices = <int>{};
    if (widget.missedQuestions.isNotEmpty) {
      for (final mq in widget.missedQuestions) {
        final idx = widget.questions.indexOf(mq);
        if (idx >= 0) _selectedMultipleIndices.add(idx);
      }
    }
    if (_selectedMultipleIndices.isEmpty && widget.questions.isNotEmpty) {
      _selectedMultipleIndices.add(0);
    }
  }

  void _selectAllMissed() {
    setState(() {
      _selectedMultipleIndices.clear();
      for (final mq in widget.missedQuestions) {
        final idx = widget.questions.indexOf(mq);
        if (idx >= 0) _selectedMultipleIndices.add(idx);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedMultipleIndices =
          List.generate(widget.questions.length, (i) => i).toSet();
    });
  }

  void _clearAll() {
    setState(() {
      _selectedMultipleIndices.clear();
    });
  }

  void _submit() {
    if (_isMultipleMode) {
      if (_selectedMultipleIndices.isEmpty) return;
      final sortedIndices = _selectedMultipleIndices.toList()..sort();
      final selectedList =
          sortedIndices.map((i) => widget.questions[i]).toList();
      widget.onConfirm(selectedList);
    } else {
      if (_selectedSingleIndex < 0 ||
          _selectedSingleIndex >= widget.questions.length) {
        return;
      }
      widget.onConfirm([widget.questions[_selectedSingleIndex]]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final isDesktop = AppAdaptiveSheet.isDesktopOrWeb(context);

    final selectedCount =
        _isMultipleMode ? _selectedMultipleIndices.length : 1;

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.of(context).size.height * (isDesktop ? 0.80 : 0.85),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: isDesktop
            ? BoxDecoration(
                color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
                borderRadius: BorderRadius.circular(AppRadius.dialog),
                border: Border.all(
                  color: colors.surfaceBorder.withValues(alpha: 0.5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  ),
                ],
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!isDesktop)
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: colors.textSecondary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ask Class for Help',
                        style: typography.headline.bold.copyWith(
                          color: colors.textPrimary,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Select question(s) to post to the study forum',
                        style: typography.caption.regular.copyWith(
                          color: colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close_rounded,
                    color: colors.textSecondary,
                    size: 20,
                  ),
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark
                    ? colors.surfaceTertiary.withValues(alpha: 0.5)
                    : colors.surfaceSecondary,
                borderRadius: AppRadius.radiusCard,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: QuizForumModeTab(
                      label: 'Single Question',
                      icon: Icons.filter_1_rounded,
                      isSelected: !_isMultipleMode,
                      onTap: () => setState(() => _isMultipleMode = false),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: QuizForumModeTab(
                      label: 'Multiple Questions',
                      icon: Icons.checklist_rounded,
                      isSelected: _isMultipleMode,
                      onTap: () => setState(() => _isMultipleMode = true),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_isMultipleMode) ...[
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (widget.missedQuestions.isNotEmpty)
                    ActionChip(
                      label: Text(
                        'Missed (${widget.missedQuestions.length})',
                        style: typography.caption.bold.copyWith(fontSize: 11),
                      ),
                      avatar: Icon(
                        Icons.highlight_off_rounded,
                        size: 14,
                        color: colors.error,
                      ),
                      backgroundColor: colors.error.withValues(alpha: 0.1),
                      side: BorderSide(
                        color: colors.error.withValues(alpha: 0.25),
                      ),
                      onPressed: _selectAllMissed,
                    ),
                  ActionChip(
                    label: Text(
                      'All (${widget.questions.length})',
                      style: typography.caption.bold.copyWith(fontSize: 11),
                    ),
                    backgroundColor: colors.primary.withValues(alpha: 0.1),
                    side: BorderSide(
                      color: colors.primary.withValues(alpha: 0.25),
                    ),
                    onPressed: _selectAll,
                  ),
                  ActionChip(
                    label: Text(
                      'Clear',
                      style: typography.caption.regular.copyWith(fontSize: 11),
                    ),
                    backgroundColor: Colors.transparent,
                    side: BorderSide(
                      color: colors.textSecondary.withValues(alpha: 0.2),
                    ),
                    onPressed: _clearAll,
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: widget.questions.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final q = widget.questions[index];
                  final isMissed = widget.missedQuestions.contains(q);
                  final isSelected = _isMultipleMode
                      ? _selectedMultipleIndices.contains(index)
                      : _selectedSingleIndex == index;

                  return InkWell(
                    onTap: () {
                      unawaited(HapticFeedback.selectionClick());
                      setState(() {
                        if (_isMultipleMode) {
                          if (isSelected) {
                            _selectedMultipleIndices.remove(index);
                          } else {
                            _selectedMultipleIndices.add(index);
                          }
                        } else {
                          _selectedSingleIndex = index;
                        }
                      });
                    },
                    borderRadius: AppRadius.radiusCard,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colors.primary
                                .withValues(alpha: isDark ? 0.18 : 0.08)
                            : (isDark
                                ? colors.surfaceTertiary.withValues(alpha: 0.3)
                                : colors.surfaceSecondary
                                    .withValues(alpha: 0.6)),
                        borderRadius: AppRadius.radiusCard,
                        border: Border.all(
                          color: isSelected
                              ? colors.primary
                              : colors.surfaceTertiary.withValues(alpha: 0.4),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isMultipleMode
                                ? (isSelected
                                    ? Icons.check_box_rounded
                                    : Icons.check_box_outline_blank_rounded)
                                : (isSelected
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_off_rounded),
                            color: isSelected
                                ? colors.primary
                                : colors.textSecondary.withValues(alpha: 0.6),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colors.primary
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Q${index + 1}',
                                        style: typography.caption.bold.copyWith(
                                          color: colors.primary,
                                          fontSize: 10.5,
                                        ),
                                      ),
                                    ),
                                    if (isMissed) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colors.error
                                              .withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Missed',
                                          style: typography.caption.bold.copyWith(
                                            color: colors.error,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                    ],
                                    if (q.subTopic.trim().isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          q.subTopic.trim(),
                                          style: typography.caption.regular
                                              .copyWith(
                                            color: colors.textSecondary,
                                            fontSize: 10.5,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  q.prompt.replaceAll('**', ''),
                                  style: typography.caption.bold.copyWith(
                                    color: colors.textPrimary,
                                    fontSize: 12,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: (_isMultipleMode && selectedCount == 0)
                    ? null
                    : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.radiusCard,
                  ),
                ),
                icon: const Icon(Icons.forum_rounded, size: 18),
                label: Text(
                  _isMultipleMode
                      ? 'Discuss $selectedCount Questions'
                      : 'Discuss Selected Question',
                  style: typography.subhead.bold.copyWith(
                    color: colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class QuizForumModeTab extends StatelessWidget {
  const QuizForumModeTab({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return InkWell(
      onTap: () {
        unawaited(HapticFeedback.lightImpact());
        onTap();
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? colors.surfacePrimary : colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? colors.primary : colors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: typography.caption.bold.copyWith(
                color: isSelected ? colors.textPrimary : colors.textSecondary,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
