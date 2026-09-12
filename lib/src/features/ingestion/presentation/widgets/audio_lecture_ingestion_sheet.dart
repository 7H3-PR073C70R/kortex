import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';

/// Interactive bottom sheet for uploading and transcribing audio lectures (ING-10).
class AudioLectureIngestionSheet extends HookWidget {
  const AudioLectureIngestionSheet({
    super.key,
    this.onTranscriptionCompleted,
    this.onGenerateCards,
  });

  final ValueChanged<String>? onTranscriptionCompleted;
  final ValueChanged<String>? onGenerateCards;

  static Future<void> show(
    BuildContext context, {
    ValueChanged<String>? onTranscriptionCompleted,
    ValueChanged<String>? onGenerateCards,
  }) {
    final colors = context.colors;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.transparent,
      builder: (_) => AudioLectureIngestionSheet(
        onTranscriptionCompleted: onTranscriptionCompleted,
        onGenerateCards: onGenerateCards,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final selectedFileName = useState<String?>('Physics_Lecture_14_Thermodynamics.mp3');
    final fileDuration = useState<String>('42:18 min');
    final fileSize = useState<String>('38.4 MB');

    final isUploading = useState<bool>(false);
    final uploadProgress = useState<double>(0.0);
    final currentChunk = useState<int>(0);
    final totalChunks = useState<int>(8);
    final transcriptionResult = useState<String>('');

    void startChunkedProcessing() {
      AppFeedback.light();
      isUploading.value = true;
      uploadProgress.value = 0.0;
      currentChunk.value = 0;
      transcriptionResult.value = '';

      var chunk = 0;
      Timer.periodic(const Duration(milliseconds: 300), (timer) {
        chunk++;
        if (chunk > totalChunks.value) {
          timer.cancel();
          isUploading.value = false;
          uploadProgress.value = 1.0;
          transcriptionResult.value =
              'Today we cover the First and Second Laws of Thermodynamics. '
              'The internal energy delta U equals Q minus W. In an adiabatic process, '
              'heat transfer Q is zero, meaning work done is at the expense of internal energy. '
              'Entropy S in an isolated system always tends toward maximum disorder.';
          onTranscriptionCompleted?.call(transcriptionResult.value);
          AppFeedback.correct();
        } else {
          currentChunk.value = chunk;
          uploadProgress.value = chunk / totalChunks.value;
        }
      });
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: colors.surfaceBorder.withAlpha(80)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.textSecondary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.mic_none_rounded, color: colors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Audio Lecture Ingestion',
                      style: typography.title2.bold.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    Text(
                      'Upload recorded lectures & voice memos to auto-generate flashcards',
                      style: typography.caption.regular.copyWith(color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // File Details Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.surfacePrimary,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.surfaceBorder.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                Icon(Icons.audio_file_rounded, color: colors.primary, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedFileName.value ?? 'No file selected',
                        style: typography.body.medium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${fileDuration.value} • ${fileSize.value}',
                        style: typography.caption.regular.copyWith(color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.folder_open_rounded),
                  color: colors.primary,
                  onPressed: () {
                    AppFeedback.selection();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Upload & Chunk Progress
          if (isUploading.value || uploadProgress.value > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isUploading.value
                      ? 'Chunked processing (${currentChunk.value}/${totalChunks.value})...'
                      : 'Transcription Ready (100%)',
                  style: typography.caption.regular.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isUploading.value ? colors.primary : colors.success,
                  ),
                ),
                Text(
                  '${(uploadProgress.value * 100).toInt()}%',
                  style: typography.caption.regular.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: uploadProgress.value,
              backgroundColor: colors.surfaceSecondary,
              valueColor: AlwaysStoppedAnimation<Color>(
                uploadProgress.value == 1.0 ? colors.success : colors.primary,
              ),
              borderRadius: BorderRadius.circular(6),
              minHeight: 6,
            ),
            const SizedBox(height: 16),
          ],
          // Transcribed Text Preview
          if (transcriptionResult.value.isNotEmpty) ...[
            Text(
              'Transcription Preview:',
              style: typography.caption.regular.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 120),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surfaceSecondary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: SingleChildScrollView(
                child: Text(
                  transcriptionResult.value,
                  style: typography.caption.regular.copyWith(
                    color: colors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          // Action Buttons
          if (transcriptionResult.value.isEmpty)
            AppButton(
              text: isUploading.value ? 'Transcribing Audio...' : 'Start Transcription',
              isLoading: isUploading.value,
              onPressed: isUploading.value ? null : startChunkedProcessing,
            )
          else
            AppButton(
              text: 'Generate Flashcards from Lecture',
              prefixIcon: const Icon(Icons.auto_awesome_rounded, size: 18, color: Colors.white),
              onPressed: () {
                AppFeedback.correct();
                onGenerateCards?.call(transcriptionResult.value);
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
    );
  }
}
