import 'package:flutter/material.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
import 'package:kortex/src/features/community/presentation/widgets/forum_media_attachment_card.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/voice_note_player_widget.dart';

/// Media attachments section for TrackForumPostCard displaying optional voice notes
/// and image attachment previews.
class PostCardMediaSection extends StatelessWidget {
  const PostCardMediaSection({
    required this.post,
    super.key,
  });

  final ForumPostEntity post;

  @override
  Widget build(BuildContext context) {
    final hasVoiceNote =
        post.voiceNoteUrl != null && post.voiceNoteUrl!.trim().isNotEmpty;
    final hasMedia = post.mediaUrls.isNotEmpty;

    if (!hasVoiceNote && !hasMedia) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasVoiceNote) ...[
          const SizedBox(height: 10),
          VoiceNotePlayerWidget(
            audioUrl: post.voiceNoteUrl!,
            postId: post.id,
            durationSeconds: post.voiceNoteDurationSeconds,
            transcript: post.voiceNoteTranscript,
            compact: true,
          ),
        ],
        if (hasMedia) ...[
          const SizedBox(height: 10),
          ForumPostMediaPreview(
            mediaUrls: post.mediaUrls,
            heroHeight: 140,
          ),
        ],
      ],
    );
  }
}
