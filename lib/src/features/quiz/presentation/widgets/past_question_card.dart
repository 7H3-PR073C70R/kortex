import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_bloc.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_event.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/latex_rich_viewer.dart';
import 'package:kortex/src/shared/widgets/app_multimodal_image.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class PastQuestionCard extends StatelessWidget {
  const PastQuestionCard({
    required this.question,
    required this.isInstantFeedback,
    this.onOptionSelected,
    this.onBookmarkToggle,
    this.onAskAi,
    super.key,
  });

  final PastQuestionEntity question;
  final bool isInstantFeedback;
  final void Function(int optionIndex)? onOptionSelected;
  final VoidCallback? onBookmarkToggle;
  final VoidCallback? onAskAi;

  Widget _buildQuestionImage(String imagePath) {
    return AppMultimodalImage(
      imageUrl: imagePath,
      borderRadius: BorderRadius.circular(10),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final optionLetters = ['A', 'B', 'C', 'D', 'E'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? colors.surfaceBorderHighlight : colors.surfaceBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.black.withAlpha(isDark ? 30 : 8),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Category, Badges, Subject, Year, Topic, Bookmark
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (question.isUserAdded)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary.withAlpha(isDark ? 45 : 20),
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(
                            color: colors.primary.withAlpha(70),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.person_outline_rounded,
                              size: 11,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'User Added',
                              style: typography.caption.bold.copyWith(
                                color: colors.primary,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (question.isTheory)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: colors.syllabotAccent.withAlpha(isDark ? 45 : 20),
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(
                            color: colors.syllabotAccent.withAlpha(70),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          'Theory / Essay',
                          style: typography.caption.bold.copyWith(
                            color: colors.syllabotAccent,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary.withAlpha(isDark ? 40 : 20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${question.subject} • ${question.year} • Q${question.questionNumber}',
                        style: typography.caption.bold.copyWith(
                          color: colors.primary,
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceSecondary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        question.topic,
                        style: typography.caption.medium.copyWith(
                          color: colors.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  question.isBookmarked
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_outline_rounded,
                  color: question.isBookmarked
                      ? colors.syllabotAccent
                      : colors.textSecondary,
                  size: 20,
                ),
                onPressed: () {
                  context.read<PastQuestionsBloc>().add(
                        ToggleBookmarkEvent(question.id),
                      );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Reading Passage (if present)
          if (question.passage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.backgroundPrimary.withAlpha(isDark ? 100 : 40),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colors.surfaceBorder.withAlpha(80),
                ),
              ),
              child: LatexRichViewer(
                text: question.passage!,
                style: typography.subhead.regular.copyWith(
                  color: colors.textSecondary,
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Question Prompt
          LatexRichViewer(
            text: question.prompt,
            style: typography.body.bold.copyWith(
              color: colors.textPrimary,
              height: 1.4,
            ),
          ),
          if (question.imageUrl != null && question.imageUrl!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _buildQuestionImage(question.imageUrl!),
            ),
          ],
          const SizedBox(height: 14),

          // Theory Question View vs Multiple Choice Options
          if (question.isTheory) ...[
            _TheoryModelAnswerWidget(
              explanation: question.explanation,
            ),
          ] else ...[
            // Multiple Choice Options
            ...question.options.asMap().entries.map((entry) {
              final idx = entry.key;
              final optionText = entry.value;
              final letter = idx < optionLetters.length
                  ? optionLetters[idx]
                  : '$idx';
              final isSelected = question.userSelectedOptionIndex == idx;
              final isCorrect = idx == question.correctOptionIndex;

              var optionBgColor = isDark
                  ? colors.backgroundPrimary
                  : colors.surfaceSecondary.withAlpha(50);
              var optionBorderColor = colors.surfaceBorder.withAlpha(90);
              var optionTextColor = colors.textPrimary;

              if (question.isAnswered && isInstantFeedback) {
                if (isCorrect) {
                  optionBgColor = colors.success.withAlpha(isDark ? 50 : 25);
                  optionBorderColor = colors.success.withAlpha(180);
                  optionTextColor = colors.success;
                } else if (isSelected) {
                  optionBgColor = colors.error.withAlpha(isDark ? 50 : 25);
                  optionBorderColor = colors.error.withAlpha(180);
                  optionTextColor = colors.error;
                }
              } else if (isSelected) {
                optionBgColor = colors.primary.withAlpha(isDark ? 50 : 25);
                optionBorderColor = colors.primary;
                optionTextColor = colors.primary;
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ShrinkableButton(
                  onTap: () {
                    unawaited(HapticFeedback.selectionClick());
                    context.read<PastQuestionsBloc>().add(
                          SelectOptionEvent(
                            questionId: question.id,
                            optionIndex: idx,
                          ),
                        );
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: optionBgColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: optionBorderColor, width: 1.2),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? colors.primary
                                : colors.surfaceSecondary,
                          ),
                          child: Center(
                            child: Text(
                              letter,
                              style: typography.caption.bold.copyWith(
                                color: isSelected
                                    ? colors.white
                                    : colors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: LatexRichViewer(
                            text: optionText,
                            style: typography.subhead.medium.copyWith(
                              color: optionTextColor,
                            ),
                          ),
                        ),
                        if (question.isAnswered && isInstantFeedback) ...[
                          if (isCorrect)
                            Icon(
                              Icons.check_circle_rounded,
                              color: colors.success,
                              size: 20,
                            )
                          else if (isSelected)
                            Icon(
                              Icons.cancel_rounded,
                              color: colors.error,
                              size: 20,
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),

            // Explanation Box (shown once answered for MCQ)
            if (question.isAnswered && isInstantFeedback) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.primary.withAlpha(isDark ? 30 : 15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colors.primary.withAlpha(isDark ? 70 : 40),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.lightbulb_rounded,
                          color: colors.syllabotAccent,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Explanation & Solution',
                          style: typography.footnote.bold.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LatexRichViewer(
                      text: question.explanation,
                      style: typography.footnote.regular.copyWith(
                        color: colors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],

          const SizedBox(height: 10),

          // Syllabot AI Explainer Action
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ShrinkableButton(
                onTap: () {
                  unawaited(
                    context.router.push(
                      SyllabotChatRoute(
                        initialPrompt:
                            'Explain this ${question.subject} question '
                            'step-by-step:\n"${question.prompt}"',
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: colors.syllabotAccent.withAlpha(isDark ? 45 : 25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colors.syllabotAccent.withAlpha(isDark ? 90 : 50),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        color: colors.syllabotAccent,
                        size: 15,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Ask Syllabot AI',
                        style: typography.caption.bold.copyWith(
                          color: colors.syllabotAccent,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TheoryModelAnswerWidget extends StatefulWidget {
  const _TheoryModelAnswerWidget({
    required this.explanation,
  });

  final String? explanation;

  @override
  State<_TheoryModelAnswerWidget> createState() => _TheoryModelAnswerWidgetState();
}

class _TheoryModelAnswerWidgetState extends State<_TheoryModelAnswerWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final explanation = widget.explanation;

    return Container(
      decoration: BoxDecoration(
        color: colors.primary.withAlpha(isDark ? 28 : 12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colors.primary.withAlpha(isDark ? 65 : 35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: colors.primary.withAlpha(isDark ? 50 : 25),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.menu_book_rounded,
                      color: colors.primary,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Model Solution & Verified Answer',
                          style: typography.subhead.bold.copyWith(
                            color: colors.primary,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          _isExpanded
                              ? 'Tap to hide model answer'
                              : 'Tap to view model solution and detailed reasoning',
                          style: typography.caption.medium.copyWith(
                            color: colors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: colors.primary,
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded) ...[
            Divider(
              height: 1,
              color: colors.primary.withAlpha(isDark ? 40 : 25),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: explanation != null && explanation.trim().isNotEmpty
                  ? LatexRichViewer(
                      text: explanation,
                      style: typography.body.regular.copyWith(
                        color: colors.textPrimary,
                        height: 1.5,
                      ),
                    )
                  : Text(
                      'No model solution or detailed explanation available for this question yet.',
                      style: typography.caption.medium.copyWith(
                        color: colors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
