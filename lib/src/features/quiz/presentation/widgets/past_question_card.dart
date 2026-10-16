import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_hub_bloc.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_bloc.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/past_questions_event.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/latex_rich_viewer.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/past_question_card/question_action_buttons.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/past_question_card/question_explanation_box.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/past_question_card/question_header_badges.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/past_question_card/question_option_tile.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/past_question_card/theory_model_answer_widget.dart';
import 'package:kortex/src/shared/widgets/app_multimodal_image.dart';

/// Card rendering a single [PastQuestionEntity] with LaTeX rendering,
/// multimodal asset preview, multiple-choice or essay options, and peer actions.
class PastQuestionCard extends StatelessWidget {
  const PastQuestionCard({
    required this.question,
    required this.isInstantFeedback,
    this.onOptionSelected,
    this.onBookmarkToggle,
    this.onAskAi,
    this.pastQuestionsBloc,
    this.communityHubBloc,
    super.key,
  });

  final PastQuestionEntity question;
  final bool isInstantFeedback;
  final void Function(int optionIndex)? onOptionSelected;
  final VoidCallback? onBookmarkToggle;
  final VoidCallback? onAskAi;
  final PastQuestionsBloc? pastQuestionsBloc;
  final CommunityHubBloc? communityHubBloc;

  static const List<String> _optionLetters = ['A', 'B', 'C', 'D', 'E'];

  Widget _buildQuestionImage(String imagePath) {
    return AppMultimodalImage(
      imageUrl: imagePath,
      borderRadius: BorderRadius.circular(AppRadius.card),
    );
  }

  void _handleBookmarkToggle(BuildContext context) {
    if (onBookmarkToggle != null) {
      onBookmarkToggle!();
      return;
    }
    (pastQuestionsBloc ?? context.read<PastQuestionsBloc>()).add(
      ToggleBookmarkEvent(question.id),
    );
  }

  void _handleOptionTap(BuildContext context, int index) {
    if (onOptionSelected != null) {
      onOptionSelected!(index);
      return;
    }
    (pastQuestionsBloc ?? context.read<PastQuestionsBloc>()).add(
      SelectOptionEvent(
        questionId: question.id,
        optionIndex: index,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
        borderRadius: BorderRadius.circular(AppRadius.panel),
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
          QuestionHeaderBadges(
            question: question,
            onBookmarkToggle: () => _handleBookmarkToggle(context),
          ),
          const SizedBox(height: 12),

          // Reading Passage (if present)
          if (question.passage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.backgroundPrimary.withAlpha(isDark ? 100 : 40),
                borderRadius: BorderRadius.circular(AppRadius.card),
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
          if (question.latexFormula != null &&
              question.latexFormula!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            LatexFormulaBlock(
              formula: question.latexFormula!,
            ),
          ],
          if (question.imageUrl != null &&
              question.imageUrl!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: _buildQuestionImage(question.imageUrl!),
            ),
          ],
          const SizedBox(height: 14),

          // Theory Question View vs Multiple Choice Options
          if (question.isTheory) ...[
            TheoryModelAnswerWidget(
              explanation: question.explanation,
            ),
          ] else ...[
            // Multiple Choice Options
            ...question.options.asMap().entries.map((entry) {
              final idx = entry.key;
              final optionText = entry.value;
              final letter = idx < _optionLetters.length
                  ? _optionLetters[idx]
                  : '$idx';
              final isSelected = question.userSelectedOptionIndex == idx;
              final isCorrect = idx == question.correctOptionIndex;

              return QuestionOptionTile(
                letter: letter,
                optionText: optionText,
                isSelected: isSelected,
                isCorrect: isCorrect,
                isAnswered: question.isAnswered,
                isInstantFeedback: isInstantFeedback,
                onTap: () => _handleOptionTap(context, idx),
              );
            }),

            // Explanation Box (shown once answered for MCQ)
            if (question.isAnswered && isInstantFeedback) ...[
              const SizedBox(height: 12),
              QuestionExplanationBox(
                explanation: question.explanation,
              ),
            ],
          ],

          const SizedBox(height: 10),

          // Action Buttons: Discuss with Peers & Ask Syllabot AI
          QuestionActionButtons(
            question: question,
            communityHubBloc: communityHubBloc,
            onAskAi: onAskAi,
          ),
        ],
      ),
    );
  }
}
