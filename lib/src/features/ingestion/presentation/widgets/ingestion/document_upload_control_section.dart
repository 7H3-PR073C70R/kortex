import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/features/ingestion/domain/entities/processing_status.dart';
import 'package:kortex/src/features/ingestion/domain/entities/synthesis_mode.dart';
import 'package:kortex/src/features/ingestion/presentation/bloc/ingestion_state.dart';
import 'package:kortex/src/features/ingestion/presentation/widgets/file_drop_zone_widget.dart';
import 'package:kortex/src/features/ingestion/presentation/widgets/ingestion/interrupted_upload_banner.dart';
import 'package:kortex/src/features/ingestion/presentation/widgets/synthesis_mode_toggle.dart';
import 'package:kortex/src/features/ingestion/presentation/widgets/upload_progress_card.dart';
import 'package:kortex/src/features/monetization/domain/services/subscription_guard.dart';

/// Control section containing the upload zone, synthesis mode switcher,
/// interrupted job alert, and active upload progress indicators.
class DocumentUploadControlSection extends StatelessWidget {
  const DocumentUploadControlSection({
    required this.state,
    required this.guard,
    required this.remainingQuota,
    required this.onUpdateQuota,
    required this.onModeSelected,
    required this.onFilePicked,
    required this.onCameraScanTap,
    required this.onDismissPendingJob,
    required this.onRetryProgress,
    required this.isDark,
    this.courseId,
    this.courseCode,
    this.courseTitle,
    super.key,
  });

  final IngestionState state;
  final SubscriptionGuard guard;
  final int remainingQuota;
  final ValueChanged<int> onUpdateQuota;
  final ValueChanged<SynthesisMode> onModeSelected;
  final void Function({
    required String filename,
    required String fileType,
    required Uint8List fileBytes,
  }) onFilePicked;
  final VoidCallback onCameraScanTap;
  final VoidCallback onDismissPendingJob;
  final VoidCallback onRetryProgress;
  final bool isDark;
  final String? courseId;
  final String? courseCode;
  final String? courseTitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (state.pendingInterruptedJob != null &&
            state.status == ProcessingStatus.idle) ...[
          InterruptedUploadBanner(
            job: state.pendingInterruptedJob!,
            onDismiss: onDismissPendingJob,
            isDark: isDark,
          ),
          const SizedBox(height: 16),
        ],

        // Synthesis mode toggle (Fast Local vs AI Smart)
        SynthesisModeToggle(
          currentMode: state.synthesisMode,
          isPro: guard.isPro,
          remainingAiSmartCount: guard.isPro ? remainingQuota : null,
          onModeSelected: (mode) async {
            if (mode == SynthesisMode.aiSmart) {
              if (!guard.isPro) {
                final upgraded = await guard.requirePro(
                  context,
                  featureName: 'AI Smart Gen',
                );
                if (!upgraded && !guard.isPro) {
                  return;
                }
                onUpdateQuota(guard.getRemainingAiSmartGenCount());
              }
              // Authoritative database check
              await guard.fetchAiSmartGenQuota();
              onUpdateQuota(guard.getRemainingAiSmartGenCount());

              if (!guard.canUseAiSmartGen()) {
                if (context.mounted) {
                  context.showSnackBar(
                    message:
                        'Daily AI Smart Gen cap reached (${SubscriptionGuard.proDailyAiSmartLimit}/${SubscriptionGuard.proDailyAiSmartLimit}). Switching to uncapped Fast Local synthesis.',
                  );
                }
                return;
              }
            }
            if (context.mounted) {
              onModeSelected(mode);
            }
          },
        ),
        const SizedBox(height: 16),

        // File drop zone
        FileDropZoneWidget(
          courseId: courseId,
          courseCode: courseCode,
          courseTitle: courseTitle,
          onFilePicked: ({
            required filename,
            required fileType,
            required fileBytes,
          }) async {
            var mode = state.synthesisMode;
            if (mode == SynthesisMode.aiSmart) {
              if (!guard.isPro) {
                final upgraded = await guard.requirePro(
                  context,
                  featureName: 'AI Smart Gen',
                );
                if (!upgraded && !guard.isPro) {
                  mode = SynthesisMode.fastLocal;
                  if (context.mounted) {
                    onModeSelected(SynthesisMode.fastLocal);
                  }
                }
              } else {
                await guard.fetchAiSmartGenQuota();
                if (!guard.canUseAiSmartGen()) {
                  mode = SynthesisMode.fastLocal;
                  if (context.mounted) {
                    onModeSelected(SynthesisMode.fastLocal);
                    context.showSnackBar(
                      message:
                          'Daily AI Smart Gen limit reached (${SubscriptionGuard.proDailyAiSmartLimit}/${SubscriptionGuard.proDailyAiSmartLimit}). Synthesizing with uncapped Fast Local mode.',
                    );
                  }
                }
              }
            }

            if (context.mounted) {
              onFilePicked(
                filename: filename,
                fileType: fileType,
                fileBytes: fileBytes,
              );
            }
          },
          onCameraScanTap: onCameraScanTap,
        ),
        const SizedBox(height: 20),

        // Progress card if active
        if (state.status != ProcessingStatus.idle)
          UploadProgressCard(
            filename: state.currentDocument?.filename ?? 'Selected Document',
            status: state.status,
            progress: state.uploadProgress,
            stageMessage: state.stageMessage,
            wasDeduplicated: state.wasDeduplicated,
            errorMessage: state.errorMessage,
            onRetry: onRetryProgress,
          )
              .animate()
              .fadeIn(duration: 400.ms)
              .slideY(
                begin: 0.1,
                end: 0,
                curve: Curves.easeOutCubic,
              ),
      ],
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(
          begin: 0.05,
          end: 0,
          curve: Curves.easeOutCubic,
        );
  }
}
