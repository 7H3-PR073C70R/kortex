import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_event.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_hub_bloc.dart';
import 'package:kortex/src/features/community/presentation/widgets/create_post_bottom_sheet.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Action bar at bottom of `PastQuestionCard` offering "Discuss with Peers"
/// and "Ask Syllabot AI" interactions.
class QuestionActionButtons extends StatelessWidget {
  const QuestionActionButtons({
    required this.question,
    this.communityHubBloc,
    this.onAskAi,
    super.key,
  });

  final PastQuestionEntity question;
  final CommunityHubBloc? communityHubBloc;
  final VoidCallback? onAskAi;

  void _showDiscussWithPeersSheet(BuildContext context) {
    final tag = question.topic.isNotEmpty
        ? question.topic
        : (question.courseCode ?? question.subject);
    final examLabel =
        '${question.examType.displayName} ${question.year} • Q${question.questionNumber}';
    final buffer = StringBuffer()
      ..writeln(question.prompt.replaceAll('**', ''))
      ..writeln();
    if (question.options.isNotEmpty) {
      buffer.writeln('Options:');
      for (var i = 0; i < question.options.length; i++) {
        final label = String.fromCharCode(65 + i);
        buffer.writeln('$label. ${question.options[i]}');
      }
      buffer.writeln();
    }
    if (question.explanation.isNotEmpty) {
      buffer
        ..writeln('Explanation: ${question.explanation.replaceAll('**', '')}')
        ..writeln();
    }
    buffer.writeln('Would love some help or peer perspectives on this problem!');

    unawaited(
      CreatePostBottomSheet.show(
        context,
        lockedTrack: question.subject,
        initialTitle: '[$tag] $examLabel Discussion',
        initialContent: buffer.toString().trim(),
        initialLatex: question.latexFormula,
        initialSyllabusTag: tag,
        initialIsQuestion: true,
        contextBadge: '$examLabel • $tag',
        onSubmit: ({
          required title,
          required content,
          required track,
          latexContent,
          isQuestion = true,
          syllabusTag = 'General',
          isAnonymous = false,
        }) {
          final hubBloc = communityHubBloc ??
              (locator.isRegistered<CommunityHubBloc>()
                  ? locator<CommunityHubBloc>()
                  : null);
          if (hubBloc != null) {
            hubBloc.add(
              CreateForumPostEvent(
                title: title,
                content: content,
                track: track,
                latexContent: latexContent,
                isQuestion: isQuestion,
                syllabusTag: syllabusTag.isNotEmpty ? syllabusTag : tag,
                isAnonymous: isAnonymous,
              ),
            );
            context.showSnackBar(
              message: 'Posted to peer discussion forum!',
              type: SnackBarType.success,
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        PlatformHoverBuilder(
          builder: (context, isHovered, _) {
            return ShrinkableButton(
              onTap: () => _showDiscussWithPeersSheet(context),
              child: AnimatedContainer(
                duration: AppMotion.standard,
                curve: AppMotion.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: colors.primary.withAlpha(
                    isDark
                        ? (isHovered ? 50 : 30)
                        : (isHovered ? 30 : 18),
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.badge),
                  border: Border.all(
                    color: colors.primary.withAlpha(
                      isDark
                          ? (isHovered ? 120 : 70)
                          : (isHovered ? 70 : 40),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.forum_outlined,
                      color: colors.primary,
                      size: 15,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Discuss with Peers',
                      style: typography.caption.bold.copyWith(
                        color: colors.primary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 8),
        PlatformHoverBuilder(
          builder: (context, isHovered, _) {
            return ShrinkableButton(
              onTap: onAskAi ??
                  () {
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
              child: AnimatedContainer(
                duration: AppMotion.standard,
                curve: AppMotion.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: colors.syllabotAccent.withAlpha(
                    isDark
                        ? (isHovered ? 65 : 45)
                        : (isHovered ? 40 : 25),
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.badge),
                  border: Border.all(
                    color: colors.syllabotAccent.withAlpha(
                      isDark
                          ? (isHovered ? 130 : 90)
                          : (isHovered ? 80 : 50),
                    ),
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
            );
          },
        ),
      ],
    );
  }
}
