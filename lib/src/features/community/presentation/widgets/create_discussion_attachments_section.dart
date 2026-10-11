import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/audio_recording_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/community/presentation/widgets/voice_note_recorder_widget.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/voice_note_player_widget.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_sheet.dart';
import 'package:kortex/src/shared/widgets/app_multimodal_image.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Section handling image attachments, voice note recording, and player preview.
class CreateDiscussionAttachmentsSection extends StatelessWidget {
  const CreateDiscussionAttachmentsSection({
    required this.attachedImages,
    required this.onImagesChanged,
    required this.recordedVoiceNoteUrl,
    required this.voiceNoteDurationSeconds,
    required this.recordedVoiceNoteTranscript,
    required this.isRecordingVoice,
    required this.voiceRecordingDuration,
    required this.voiceRecorderController,
    required this.contentController,
    required this.onVoiceNoteRecorded,
    required this.onVoiceNoteDeleted,
    this.audioRecordingService,
    super.key,
  });

  final List<String> attachedImages;
  final ValueChanged<List<String>> onImagesChanged;
  final String? recordedVoiceNoteUrl;
  final int voiceNoteDurationSeconds;
  final String? recordedVoiceNoteTranscript;
  final ValueNotifier<bool> isRecordingVoice;
  final ValueNotifier<int> voiceRecordingDuration;
  final VoiceNoteRecorderController voiceRecorderController;
  final TextEditingController contentController;
  final void Function({
    required String audioUrl,
    required int durationSeconds,
    required String transcript,
  }) onVoiceNoteRecorded;
  final VoidCallback onVoiceNoteDeleted;
  final AudioRecordingService? audioRecordingService;

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    unawaited(HapticFeedback.lightImpact());
    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (photo != null && photo.path.isNotEmpty) {
        onImagesChanged([...attachedImages, photo.path]);
        if (context.mounted) {
          context.showSnackBar(message: 'Image attached ✨');
        }
      }
    } on Object catch (_) {
      if (context.mounted) {
        context.showSnackBar(message: 'Could not access photo library');
      }
    }
  }

  void _showImagePickerModal(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    unawaited(
      AppAdaptiveSheet.showActionMenu<void>(
        context: context,
        builder: (ctx) {
          final isDesktop = AppAdaptiveSheet.isDesktopOrWeb(ctx);
          return SafeArea(
            child: Container(
              decoration: isDesktop
                  ? BoxDecoration(
                      color: isDark
                          ? colors.surfaceSecondary
                          : colors.surfacePrimary,
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
              padding: const EdgeInsets.symmetric(
                vertical: 16,
                horizontal: 8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isDesktop)
                    Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: colors.textSecondary.withAlpha(60),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ListTile(
                    leading: Icon(
                      Icons.photo_library_rounded,
                      color: colors.primary,
                    ),
                    title: Text(
                      'Choose from Gallery',
                      style: typography.body.medium.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      unawaited(_pickImage(context, ImageSource.gallery));
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.camera_alt_rounded,
                      color: colors.primary,
                    ),
                    title: Text(
                      'Take a Photo',
                      style: typography.body.medium.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      unawaited(_pickImage(context, ImageSource.camera));
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MEDIA & AUDIO ATTACHMENTS',
          style: typography.caption.bold.copyWith(
            color: colors.textSecondary,
            fontSize: 10.5,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),

        // Action buttons row (Add Image & Voice Note STT)
        Row(
          children: [
            ShrinkableButton(
              onTap: () => _showImagePickerModal(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colors.primary.withAlpha(isDark ? 30 : 15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colors.primary.withAlpha(isDark ? 50 : 30),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_rounded,
                      size: 16,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Attach Image',
                      style: typography.caption.bold.copyWith(
                        color: colors.primary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            VoiceNoteRecorderWidget(
              compact: true,
              controller: contentController,
              recorderController: voiceRecorderController,
              onRecordingStateChanged: ({
                required isRecording,
                required isLocked,
                required durationSeconds,
                required transcript,
              }) {
                isRecordingVoice.value = isRecording;
                voiceRecordingDuration.value = durationSeconds;
              },
              onRecordingComplete: onVoiceNoteRecorded,
              onCancel: onVoiceNoteDeleted,
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Voice recording banner if active
        if (isRecordingVoice.value) ...[
          VoiceRecordingBannerWidget(
            durationSeconds: voiceRecordingDuration.value,
            transcriptText: recordedVoiceNoteTranscript ?? '',
            amplitudeStream: audioRecordingService?.amplitudeStream,
            onCancel: () => unawaited(voiceRecorderController.cancel()),
            onDone: () => unawaited(voiceRecorderController.finish()),
          ),
          const SizedBox(height: 10),
        ],

        // Voice note player preview if recorded
        if (recordedVoiceNoteUrl != null) ...[
          VoiceNotePlayerWidget(
            audioUrl: recordedVoiceNoteUrl!,
            durationSeconds: voiceNoteDurationSeconds > 0
                ? voiceNoteDurationSeconds
                : null,
            transcript: recordedVoiceNoteTranscript,
            showTranscript: false,
            onDelete: onVoiceNoteDeleted,
          ),
          const SizedBox(height: 10),
        ],

        // Image attachments thumbnails strip
        if (attachedImages.isNotEmpty) ...[
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: attachedImages.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (ctx, idx) {
                final path = attachedImages[idx];
                return Stack(
                  children: [
                    AppMultimodalImage(
                      imageUrl: path,
                      width: 84,
                      height: 84,
                      fit: BoxFit.cover,
                      borderRadius: BorderRadius.circular(12),
                      enableZoomOnTap: false,
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () {
                          onImagesChanged(
                            attachedImages.where((p) => p != path).toList(),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.black.withAlpha(160),
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            size: 12,
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
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

/// Live audio wave visualizer bar animation.
class LiveAudioWaveVisualizer extends StatefulWidget {
  const LiveAudioWaveVisualizer({required this.color, super.key});

  final Color color;

  @override
  State<LiveAudioWaveVisualizer> createState() =>
      _LiveAudioWaveVisualizerState();
}

class _LiveAudioWaveVisualizerState extends State<LiveAudioWaveVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
      // ignore: discarded_futures — TickerFuture from repeat() is intentionally not awaited per Flutter convention
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final val = _controller.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildBar(4 + val * 8),
            const SizedBox(width: 2),
            _buildBar(12 - val * 7),
            const SizedBox(width: 2),
            _buildBar(6 + val * 6),
          ],
        );
      },
    );
  }

  Widget _buildBar(double height) {
    return Container(
      width: 2.5,
      height: height.clamp(3, 14),
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
