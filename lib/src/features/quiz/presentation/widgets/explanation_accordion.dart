import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_event.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_hub_bloc.dart';
import 'package:kortex/src/features/community/presentation/widgets/create_post_bottom_sheet.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/latex_rich_viewer.dart';
import 'package:kortex/src/l10n/l10n.dart';

class ExplanationAccordion extends StatefulWidget {
  const ExplanationAccordion({
    required this.explanation,
    this.latexFormula,
    this.questionPrompt,
    this.courseCode,
    this.subjectTag,
    super.key,
  });

  final String explanation;
  final String? latexFormula;
  final String? questionPrompt;
  final String? courseCode;
  final String? subjectTag;

  @override
  State<ExplanationAccordion> createState() => _ExplanationAccordionState();
}

class _ExplanationAccordionState extends State<ExplanationAccordion> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final colors = context.colors;
    final l10n = context.l10n;

    return Container(
      margin: const EdgeInsets.only(top: 20, bottom: 12),
      decoration: BoxDecoration(
        color: colors.surfacePrimary.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppRadius.panel),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _isExpanded = !_isExpanded),
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline_rounded,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          l10n.quizExplanationTitle,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _isExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: theme.colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),
                // Ask Syllabot AI Action Pill
                InkWell(
                  onTap: () {
                    final promptText = StringBuffer('Help me understand this past question step-by-step:\n\n');
                    if (widget.questionPrompt != null && widget.questionPrompt!.isNotEmpty) {
                      promptText.writeln('Question: ${widget.questionPrompt}');
                    }
                    if (widget.explanation.isNotEmpty) {
                      promptText.writeln('Explanation: ${widget.explanation}');
                    }
                    unawaited(context.router.push(SyllabotChatRoute(initialPrompt: promptText.toString())));
                  },
                  borderRadius: BorderRadius.circular(AppRadius.badge),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: colors.syllabotAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.badge),
                      border: Border.all(
                        color: colors.syllabotAccent.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          color: colors.syllabotAccent,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Ask Syllabot AI',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.syllabotAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Discuss with Cohort Action Pill
                InkWell(
                  onTap: () {
                    final tag = widget.subjectTag ?? widget.courseCode ?? 'General';
                    final buffer = StringBuffer();
                    if (widget.questionPrompt != null && widget.questionPrompt!.isNotEmpty) {
                      buffer
                        ..writeln(widget.questionPrompt!.replaceAll('**', ''))
                        ..writeln();
                    }
                    if (widget.explanation.isNotEmpty) {
                      buffer
                        ..writeln('Explanation: ${widget.explanation.replaceAll('**', '')}')
                        ..writeln();
                    }
                    buffer.writeln('Would like to discuss this question with peers!');

                    unawaited(
                      CreatePostBottomSheet.show(
                        context,
                        lockedTrack: widget.courseCode,
                        initialTitle: '[$tag] Past Question Discussion',
                        initialContent: buffer.toString().trim(),
                        initialLatex: widget.latexFormula,
                        initialSyllabusTag: tag,
                        initialIsQuestion: true,
                        contextBadge: 'Quiz Question • $tag',
                        onSubmit: ({
                          required title,
                          required content,
                          required track,
                          latexContent,
                          isQuestion = true,
                          syllabusTag = 'General',
                          isAnonymous = false,
                        }) {
                          if (locator.isRegistered<CommunityHubBloc>()) {
                            locator<CommunityHubBloc>().add(
                              CreateForumPostEvent(
                                title: title,
                                content: content,
                                track: track,
                                latexContent: latexContent,
                                isQuestion: true,
                                syllabusTag: syllabusTag,
                                isAnonymous: isAnonymous,
                              ),
                            );
                          }
                        },
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(AppRadius.badge),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.badge),
                      border: Border.all(
                        color: colors.primary.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.forum_rounded,
                          color: colors.primary,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Discuss with Cohort',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isExpanded) ...[
            Divider(height: 1, color: colors.surfaceBorder),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.latexFormula != null &&
                      widget.latexFormula!.trim().isNotEmpty) ...[
                    LatexFormulaBlock(
                      formula: widget.latexFormula!,
                    ),
                    const SizedBox(height: 12),
                  ],
                  LatexRichViewer(
                    text: widget.explanation,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
