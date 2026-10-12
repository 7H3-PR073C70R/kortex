import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
import 'package:kortex/src/features/community/presentation/widgets/forum_media_attachment_card.dart';
import 'package:kortex/src/features/community/presentation/widgets/forum_thread_structured_body.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/latex_rich_viewer.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/voice_note_player_widget.dart';

/// Renders body content, LaTeX formulas, voice notes, and media attachments for a forum reply.
class ParentReplyContentBody extends StatelessWidget {
  const ParentReplyContentBody({
    required this.parentReply,
    this.onTranscriptUpdated,
    super.key,
  });

  final ForumReplyEntity parentReply;
  final void Function(String replyId, String newTranscript)?
  onTranscriptUpdated;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Body Text
        CleanFormattedText(
          text: parentReply.content,
          baseStyle: typography.body.regular.copyWith(
            color: colors.textPrimary,
            fontSize: 14,
            height: 1.45,
          ),
        ),

        // LaTeX Formula
        if (parentReply.latexContent != null &&
            parentReply.latexContent!.isNotEmpty) ...[
          const SizedBox(height: 6),
          LatexFormulaBlock(
            formula: parentReply.latexContent!,
            backgroundColor: isDark
                ? colors.surfacePrimary
                : colors.surfaceSecondary.withAlpha(120),
            borderColor: colors.surfaceBorder.withAlpha(isDark ? 30 : 20),
            textStyle: typography.caption.bold.copyWith(
              color: colors.primary,
              fontSize: 13,
            ),
          ),
        ],

        // Voice note if attached
        if (parentReply.voiceNoteUrl != null &&
            parentReply.voiceNoteUrl!.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          VoiceNotePlayerWidget(
            audioUrl: parentReply.voiceNoteUrl!,
            replyId: parentReply.id,
            durationSeconds: parentReply.voiceNoteDurationSeconds,
            transcript: parentReply.voiceNoteTranscript,
            compact: true,
            onTranscriptLoaded: (newTranscript) {
              onTranscriptUpdated?.call(parentReply.id, newTranscript);
            },
          ),
        ],

        // Media images if attached
        if (parentReply.mediaUrls.isNotEmpty) ...[
          const SizedBox(height: 4),
          ...parentReply.mediaUrls.asMap().entries.map(
            (entry) => ForumReplyAttachmentCard(
              imageUrl: entry.value,
              customFileName: extractAttachmentFileName(
                entry.value,
                index: entry.key,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
