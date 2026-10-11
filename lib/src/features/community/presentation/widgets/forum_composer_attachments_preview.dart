import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/voice_note_player_widget.dart';
import 'package:kortex/src/shared/widgets/app_multimodal_image.dart';

/// Previews for media currently attached to the forum reply composer
/// (voice note player with delete action, and horizontal thumbnail carousel).
class ForumComposerAttachmentsPreview extends StatelessWidget {
  const ForumComposerAttachmentsPreview({
    required this.replyVoiceNoteUrl,
    required this.replyVoiceNoteDuration,
    required this.replyVoiceTranscript,
    required this.replyImages,
    required this.fallbackText,
    super.key,
  });

  final ValueNotifier<String?> replyVoiceNoteUrl;
  final ValueNotifier<int> replyVoiceNoteDuration;
  final ValueNotifier<String> replyVoiceTranscript;
  final ValueNotifier<List<String>> replyImages;
  final String fallbackText;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Reply Voice Note Preview if attached
        if (replyVoiceNoteUrl.value != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            child: VoiceNotePlayerWidget(
              audioUrl: replyVoiceNoteUrl.value!,
              durationSeconds: replyVoiceNoteDuration.value > 0
                  ? replyVoiceNoteDuration.value
                  : null,
              transcript: replyVoiceTranscript.value.trim().isNotEmpty
                  ? replyVoiceTranscript.value.trim()
                  : (fallbackText.isNotEmpty ? fallbackText : null),
              compact: true,
              showTranscript: false,
              onDelete: () {
                replyVoiceNoteUrl.value = null;
                replyVoiceNoteDuration.value = 0;
                replyVoiceTranscript.value = '';
              },
            ),
          ),
        ],

        // Reply Image Thumbnails Preview if attached
        if (replyImages.value.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            child: SizedBox(
              height: 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: replyImages.value.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(width: 8),
                itemBuilder: (ctx, idx) {
                  final path = replyImages.value[idx];
                  return Stack(
                    children: [
                      AppMultimodalImage(
                        imageUrl: path,
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                        borderRadius: BorderRadius.circular(8),
                        enableZoomOnTap: false,
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () {
                            replyImages.value = replyImages.value
                                .where((p) => p != path)
                                .toList();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colors.black.withAlpha(160),
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: 10,
                              color: colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ],
    );
  }
}
